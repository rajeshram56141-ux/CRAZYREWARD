const connectMongo = require('./connectMongo');
const ReadEarn = require('../models/readEarn');
const ReadEarnLogs = require('../models/readEarnLogs');
const UsedReadEarnToken = require('../models/usedReadEarnToken');
const PendingReadEarnToken = require('../models/pendingReadEarnToken');
const User = require('../models/user');
const RewardHistory = require('../models/rewardHistory');
const { DateTime } = require('luxon');

async function handleReadEarnPostback({
    appName = '',
    userId,
    offerId,
    query,
    res,
}) {
    try {
        await connectMongo();

        // 1. Config check
        let readEarnConfig = await ReadEarn.findOne({ enabled: { $ne: false } }).lean();
        if (!readEarnConfig) {
            readEarnConfig = await ReadEarn.findOne().lean();
        }

        if (!readEarnConfig) {
            return res.status(404).json({
                success: false,
                message: "Read Earn config not found",
            });
        }

        // 2. Offer check
        const offer = (readEarnConfig.urlsList || []).find(
            (u) => String(u._id) === String(offerId)
        );

        if (!offer) {
            return res.status(404).json({
                success: false,
                message: "Invalid Offer",
            });
        }

        // 3. Cryptographic Token Signature Validation
        let activeToken = query.token;
        let pendingRecord;

        if (activeToken) {
            pendingRecord = await PendingReadEarnToken.findOneAndDelete({ token: activeToken });
        } else {
            pendingRecord = await PendingReadEarnToken.findOneAndDelete(
                { userId: userId, offerId: offerId },
                { sort: { createdAt: -1 } }
            );
        }

        if (!pendingRecord) {
            if (activeToken) {
                const wasUsed = await UsedReadEarnToken.findOne({ token: activeToken });
                if (wasUsed) {
                    return res.status(409).json({
                        success: false,
                        message: "Token has already been used",
                    });
                }
            }
            return res.status(403).json({
                success: false,
                message: "Verification session not found or expired. Please start the task again.",
            });
        }

        if (!activeToken) {
            activeToken = pendingRecord.token;
        }

        // Expiry check: token is valid for 10 minutes (600,000 ms)
        const ageMs = Date.now() - pendingRecord.createdAt.getTime();
        if (ageMs > 600000) {
            return res.status(403).json({
                success: false,
                message: "Verification token expired",
            });
        }

        // Mark token as used to prevent replay attacks
        try {
            await UsedReadEarnToken.create({ token: activeToken });
        } catch (dbErr) {
            if (dbErr.code === 11000) {
                return res.status(409).json({
                    success: false,
                    message: "Token has already been used",
                });
            }
        }

        // 4. Calculate Coins directly from Admin payout without conversion
        const coins = Number(offer.payout || offer.coins || 0);

        // 5. Credit user coins in MongoDB User Wallet (Atomic $inc with guest & blocked protection)
        const user = await User.findOneAndUpdate(
            {
                userId,
                account_deleted: { $ne: true },
                blocked: { $ne: true },
                isBlocked: { $ne: true },
                isGuest: { $ne: true },
                isAnonymous: { $ne: true }
            },
            {
                $inc: { coins: coins, totalCoins: coins },
                $set: { lastActiveAt: new Date() }
            },
            { new: true }
        );

        if (!user) {
            return res.status(403).json({
                success: false,
                message: "User account is blocked, deleted, or a guest account",
            });
        }

            // Trigger S2S postback for generic event and specific article
            try {
                const triggerOutgoingPostback = require('../../services/publisherPostbackService');
                triggerOutgoingPostback({
                    user,
                    offerId: 'read_earn_complete',
                    coins,
                    eventId: 'read_earn_complete'
                });
                triggerOutgoingPostback({
                    user,
                    offerId: String(offerId),
                    coins,
                    eventId: String(offerId)
                });
            } catch (err) {
                console.error("⚠️ Failed to trigger S2S outgoing postback for Read Earn:", err.message);
            }

            // Log entry in RewardHistory
            const transId = `read_earn_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
            await RewardHistory.create({
                appName: user.appName || appName,
                userId: userId,
                provider: 'Read & Earn',
                coins: coins,
                rewardType: 'coin',
                orderId: transId,
                transId: transId,
                timestamp: new Date()
            }).catch(err => console.error("⚠️ RewardHistory create warning:", err.message));

            // Track Daily Challenge progress for Read & Earn
            try {
                const { trackDailyChallengeProgress } = require('../../routes/modules/dailyChallengeApiRoutes');
                trackDailyChallengeProgress(userId, 'read_and_earn', 1);
            } catch (_) {}

            // 🤝 Referral Commission & Joinee Bonus Trigger
            try {
                const { distributeTaskReferralCommission, checkAndUnlockTaskReferrerBonus } = require('../../services/referralCommissionService');
                checkAndUnlockTaskReferrerBonus(userId, 'read_earn').catch(e => console.error("⚠️ [ReadEarn] Ref bonus error:", e.message));
                distributeTaskReferralCommission(userId, coins, 'Read & Earn').catch(e => console.error("⚠️ [ReadEarn] Ref comm error:", e.message));
            } catch (refErr) {
                console.error("⚠️ [ReadEarn] Referral processing error:", refErr.message);
            }

        // 6. Log entry in ReadEarnLogs
        await ReadEarnLogs.create({
            appName: appName,
            userId: userId,
            offerId: offerId,
            url: offer.url,
            payout: coins,
            responseStatus: 200,
            payload: query,
        }).catch(err => console.error("⚠️ ReadEarnLogs create warning:", err.message));

        return res.status(200).json({
            success: true,
            message: "Postback accepted and coins credited successfully",
            coins: coins,
        });

    } catch (err) {
        console.error("🔥 Postback Error:", err);
        return res.status(500).json({
            success: false,
            message: "Internal Server Error",
        });
    }
}

module.exports = { handleReadEarnPostback };