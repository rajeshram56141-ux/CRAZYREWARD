const connectMongo = require('./connectMongo');
const DailyTask = require('../models/dailyTask');
const User = require('../models/user');
const RewardHistory = require('../models/rewardHistory');
const PostbackLog = require('../models/postbackLogs');

// Helper to get start of today in IST (Timezone-safe for UTC servers)
function getTodayStartIST() {
    const now = new Date();
    const istDateStr = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
    return new Date(`${istDateStr}T00:00:00+05:30`);
}

// Concurrency lock set to prevent duplicate rapid-fire taps
const activeWatchEarnRequests = new Set();

/**
 * 🎬 Dedicated Individual Watch & Earn Postback Handler
 * Completely separated from daily tasks / multi-event step tasks.
 */
async function handleWatchEarnPostback({
    appName,
    userId,
    offerId,
    userEmail = '',
    userGaid = '',
    query = {},
    res
}) {
    const cleanUserId = String(userId || '').trim();
    const cleanOfferId = String(offerId || '').trim();
    const cleanAppName = String(appName || 'crazyreward').toLowerCase().replace(/\s/g, '').trim();

    if (!cleanUserId || !cleanOfferId) {
        return res.status(400).json({
            success: false,
            message: 'User ID and Offer ID are required'
        });
    }

    const lockKey = `watchearn:${cleanUserId}:${cleanOfferId}`;
    if (activeWatchEarnRequests.has(lockKey)) {
        return res.status(429).json({
            success: false,
            message: 'Watch & Earn request already in progress'
        });
    }
    activeWatchEarnRequests.add(lockKey);

    try {
        await connectMongo();

        // 1. Fetch the video task
        const offerDoc = await DailyTask.findOne({ offerId: cleanOfferId });
        if (!offerDoc) {
            return res.status(404).json({
                success: false,
                message: 'Video task not found'
            });
        }

        if (offerDoc.enabled === false) {
            return res.status(400).json({
                success: false,
                message: 'This video task is currently inactive'
            });
        }

        const todayStart = getTodayStartIST();

        // 2. Global Daily Cap Limit Check
        if (offerDoc.dailyCapLimit !== null && offerDoc.dailyCapLimit !== undefined && offerDoc.dailyCapLimit > 0) {
            if (offerDoc.dailyCapCount >= offerDoc.dailyCapLimit) {
                console.warn(`[WatchEarn] Global daily cap reached for offer ${cleanOfferId} (${offerDoc.dailyCapCount}/${offerDoc.dailyCapLimit})`);
                return res.status(200).json({
                    success: false,
                    message: 'Daily limit reached for this video. Come back tomorrow!'
                });
            }
        }

        // 3. Global Lifetime Cap Limit Check
        if (offerDoc.lifetimeCapLimit !== null && offerDoc.lifetimeCapLimit !== undefined && offerDoc.lifetimeCapLimit > 0) {
            if (offerDoc.postbackCount >= offerDoc.lifetimeCapLimit) {
                console.warn(`[WatchEarn] Global lifetime cap reached for offer ${cleanOfferId} (${offerDoc.postbackCount}/${offerDoc.lifetimeCapLimit})`);
                return res.status(200).json({
                    success: false,
                    message: 'This video task limit has been reached.'
                });
            }
        }

        // 4. Per-User Daily Cap Check (STRICT ENFORCEMENT)
        // Count how many times THIS user has completed THIS video offer today
        const userCompletionsToday = await PostbackLog.countDocuments({
            userId: cleanUserId,
            offerId: cleanOfferId,
            completedAt: { $gte: todayStart }
        });

        console.log(`[WatchEarn] Checking Cap: user=${cleanUserId}, offer=${cleanOfferId}, completionsToday=${userCompletionsToday}, perUserDailyCap=${offerDoc.perUserDailyCap}`);

        if (offerDoc.perUserDailyCap !== null && offerDoc.perUserDailyCap !== undefined && offerDoc.perUserDailyCap > 0) {
            // User has a configured numeric cap (e.g. 2)
            if (userCompletionsToday >= offerDoc.perUserDailyCap) {
                console.warn(`[WatchEarn] User ${cleanUserId} exceeded perUserDailyCap (${userCompletionsToday} >= ${offerDoc.perUserDailyCap}) for offer ${cleanOfferId}`);
                return res.status(200).json({
                    success: false,
                    message: `You have completed your daily limit (${offerDoc.perUserDailyCap}/${offerDoc.perUserDailyCap}) for this video. Come back tomorrow!`
                });
            }
        } else {
            // Default: 1 completion allowed per day if dailyReset is ON
            if (offerDoc.dailyReset) {
                if (userCompletionsToday >= 1) {
                    return res.status(200).json({
                        success: false,
                        message: 'You have already completed this video today. Come back tomorrow!'
                    });
                }
            } else {
                // If dailyReset is OFF, check if user ever completed it
                const userLifetimeCompletions = await PostbackLog.countDocuments({
                    userId: cleanUserId,
                    offerId: cleanOfferId
                });
                if (userLifetimeCompletions >= 1) {
                    return res.status(200).json({
                        success: false,
                        message: 'You have already completed this video task.'
                    });
                }
            }
        }

        // 5. Coins calculation
        const coins = Number(offerDoc.coins || offerDoc.payout || 0);
        const transactionId = `${Date.now()}-${Math.floor(Math.random() * 1000)}`;

        // 6. Credit User Wallet in MongoDB (Atomic $inc with guest & blocked protection)
        const user = await User.findOneAndUpdate(
            {
                userId: cleanUserId,
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
                message: 'Guest accounts or restricted users cannot earn watch rewards. Please log in with Google to continue!'
            });
        }

        // 7. Create Dedicated RewardHistory entry
        await RewardHistory.create({
            appName: user.appName || cleanAppName,
            userId: cleanUserId,
            provider: 'Watch & Earn',
            coins: coins,
            rewardType: 'coin',
            orderId: `watch_earn_${transactionId}`,
            transId: transactionId,
            timestamp: new Date()
        }).catch(err => console.error("⚠️ [WatchEarn] RewardHistory error:", err.message));

        // 8. Create Dedicated PostbackLog entry
        await PostbackLog.create({
            appName: cleanAppName,
            userId: cleanUserId,
            txnId: transactionId,
            offerId: cleanOfferId,
            offerType: 'WatchEarn',
            payout: coins,
            responseStatus: 200,
            userEmail: userEmail || '',
            userGaid: userGaid || '',
            payload: query,
            completedAt: new Date()
        });

        // 9. Increment Task Global Counters in MongoDB
        await DailyTask.updateOne(
            { offerId: cleanOfferId },
            {
                $inc: {
                    postbackCount: 1,
                    dailyCapCount: 1,
                }
            }
        ).catch(err => console.error("⚠️ [WatchEarn] DailyTask counter error:", err.message));

        // 10. Clear Redis cache immediately so UI list removes or updates this task
        try {
            const cacheService = require('../../services/cacheService');
            await cacheService.delPattern('tasks:watchearn:*');
        } catch (_) {}

        // 11. Track Daily Challenge progress for watch_earn and watch_video
        try {
            const { trackDailyChallengeProgress } = require('../../routes/modules/dailyChallengeApiRoutes');
            trackDailyChallengeProgress(cleanUserId, 'watch_earn', 1);
            trackDailyChallengeProgress(cleanUserId, 'watch_video', 1);
        } catch (_) {}

        // 12. S2S Outgoing Postback (if publisher user)
        if (user.publisherRef && user.publisherUid) {
            try {
                const triggerOutgoingPostback = require('../../services/publisherPostbackService');
                triggerOutgoingPostback({
                    user,
                    offerId: cleanOfferId,
                    coins,
                    eventId: 'watch_video'
                }).catch(() => {});
            } catch (_) {}
        }

        // 13. 🤝 Referral Commission & Joinee Bonus Trigger
        try {
            const { distributeTaskReferralCommission, checkAndUnlockTaskReferrerBonus } = require('../../services/referralCommissionService');
            checkAndUnlockTaskReferrerBonus(cleanUserId, 'watch_earn').catch(e => console.error("⚠️ [WatchEarn] Ref bonus error:", e.message));
            distributeTaskReferralCommission(cleanUserId, coins, 'Watch & Earn').catch(e => console.error("⚠️ [WatchEarn] Ref comm error:", e.message));
        } catch (refErr) {
            console.error("⚠️ [WatchEarn] Referral processing error:", refErr.message);
        }

        console.log(`🎉 [WatchEarn] SUCCESS: Credited ${coins} coins to user ${cleanUserId} for offer "${offerDoc.offerName}". Total today: ${userCompletionsToday + 1}/${offerDoc.perUserDailyCap || 1}`);

        return res.status(200).json({
            success: true,
            message: 'Watch & Earn reward credited successfully!',
            coins: coins
        });

    } catch (err) {
        console.error('🔥 Error in handleWatchEarnPostback:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error during Watch & Earn postback.'
        });
    } finally {
        activeWatchEarnRequests.delete(lockKey);
    }
}

module.exports = { handleWatchEarnPostback };
