const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const verifyAuthToken = require('../../admin/middlewares/verifyAuthToken');
const User = require('../../admin/models/user');
const ReferralSettings = require('../../admin/models/referralSettings');
const RewardHistory = require('../../admin/models/rewardHistory');
const PayoutRecord = require('../../admin/models/payoutRecord');

// Helper to aggregate task & payout stats for referred users
async function getReferredUsersTaskStats(referredUserIds = []) {
    if (!referredUserIds.length) {
        return { userWithdrawals: {}, userOffers: {}, userSurveys: {}, userSuperOffers: {} };
    }

    const [payoutAgg, rewardAgg] = await Promise.all([
        PayoutRecord.aggregate([
            {
                $match: {
                    userId: { $in: referredUserIds },
                    status: { $in: ['completed', 'success', 'successful'] }
                }
            },
            {
                $group: {
                    _id: '$userId',
                    count: { $sum: 1 }
                }
            }
        ]),
        RewardHistory.aggregate([
            {
                $match: {
                    userId: { $in: referredUserIds }
                }
            },
            {
                $project: {
                    userId: 1,
                    isSuperOffer: {
                        $cond: [{ $regexMatch: { input: '$provider', regex: /Super Offer/i } }, 1, 0]
                    },
                    isSurvey: {
                        $cond: [{ $regexMatch: { input: '$provider', regex: /Survey/i } }, 1, 0]
                    },
                    isOfferwall: {
                        $cond: [{
                            $regexMatch: {
                                input: '$provider',
                                regex: /Offerwall|AdGem|Tapjoy|OfferToro|Ayet|BitLabs|Monlix|CPALead|Wannads|Timewall|HangMyAds/i
                            }
                        }, 1, 0]
                    }
                }
            },
            {
                $group: {
                    _id: '$userId',
                    superOfferCount: { $sum: '$isSuperOffer' },
                    surveyCount: { $sum: '$isSurvey' },
                    offerwallCount: { $sum: '$isOfferwall' }
                }
            }
        ])
    ]);

    const userWithdrawals = {};
    for (const item of payoutAgg) {
        userWithdrawals[item._id] = item.count;
    }

    const userOffers = {};
    const userSurveys = {};
    const userSuperOffers = {};
    for (const item of rewardAgg) {
        userOffers[item._id] = item.offerwallCount || 0;
        userSurveys[item._id] = item.surveyCount || 0;
        userSuperOffers[item._id] = item.superOfferCount || 0;
    }

    return { userWithdrawals, userOffers, userSurveys, userSuperOffers };
}

function calculateMissionProgress(mission, referredUserIds = [], stats = {}) {
    const criteriaType = String(mission.criteriaType || 'direct');
    const reqCount = Number(mission.criteriaCount) > 0 ? Number(mission.criteriaCount) : 1;

    if (criteriaType === 'direct') {
        return referredUserIds.length;
    }

    let qualifiedCount = 0;
    for (const uid of referredUserIds) {
        if (criteriaType === 'withdrawal') {
            const count = stats.userWithdrawals[uid] || 0;
            if (count >= reqCount) qualifiedCount++;
        } else if (criteriaType === 'offerwall') {
            const count = stats.userOffers[uid] || 0;
            if (count >= reqCount) qualifiedCount++;
        } else if (criteriaType === 'survey') {
            const count = stats.userSurveys[uid] || 0;
            if (count >= reqCount) qualifiedCount++;
        } else if (criteriaType === 'super_offer') {
            const count = stats.userSuperOffers[uid] || 0;
            if (count >= reqCount) qualifiedCount++;
        }
    }
    return qualifiedCount;
}

// Get Referral Statistics & Missions
router.all('/stats', verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId || req.body?.userId;
        const user = await User.findOne({ userId })
            .select('userId referralCode referredBy claimedReferralMissions coins totalCoins')
            .lean();

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const refQuery = {
            referredBy: user.referralCode
                ? { $in: [user.referralCode, user.userId] }
                : user.userId,
            isGuest: { $ne: true },
            account_deleted: { $ne: true },
            isBlocked: { $ne: true }
        };

        const referredUsers = await User.find(refQuery)
            .select('userId displayName photoUrl createdAt coins')
            .sort({ createdAt: -1 })
            .lean();

        const referralSettingsDoc = await ReferralSettings.findOne({ key: 'referralSettings' }).lean();
        const refConfig = referralSettingsDoc?.config || {};
        const missionsEnabled = refConfig.missionsEnabled === true;
        const missionsSubtitle = refConfig.missionsSubtitle || refConfig.missionsDescription || '';
        const allMissions = Array.isArray(refConfig.missions) ? refConfig.missions : [];
        const activeMissions = allMissions.filter(m => m.enabled !== false);

        const referredUserIds = referredUsers.map(u => u.userId);
        const stats = await getReferredUsersTaskStats(referredUserIds);

        const missionsWithProgress = activeMissions.map(m => {
            const progress = calculateMissionProgress(m, referredUserIds, stats);
            return {
                ...m,
                criteriaType: m.criteriaType || 'direct',
                criteriaCount: Number(m.criteriaCount) || 1,
                progress: progress,
            };
        });

        return res.json({
            success: true,
            referralCode: user.referralCode,
            totalReferred: referredUsers.length,
            referredUsers,
            claimedMissions: user.claimedReferralMissions || [],
            missionsEnabled,
            missionsSubtitle,
            missions: missionsWithProgress,
            rewardMode: refConfig.rewardMode || 'all',
            allCommissionPercent: Number(refConfig.allCommissionPercent) || 10,
            referrerBonusCoins: Number(refConfig.referrerBonusCoins) || 0,
            referrerBonusCondition: refConfig.referrerBonusCondition || 'none',
        });
    } catch (err) {
        console.error('❌ Get referral stats error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch referral stats' });
    }
});

// Claim Referral Mission API
router.post('/claim-mission', verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId || req.body?.userId;
        const target = Number(req.body?.target);

        if (!userId || !Number.isFinite(target) || target <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid target or userId' });
        }

        const user = await User.findOne({ userId });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if (user.isBlocked) {
            return res.status(403).json({ success: false, message: 'Account is blocked' });
        }

        if (user.isGuest) {
            return res.status(400).json({ success: false, message: 'Guest accounts cannot claim referral rewards. Please sign in with Google.' });
        }

        // Check if already claimed
        const claimedList = Array.isArray(user.claimedReferralMissions) ? user.claimedReferralMissions : [];
        if (claimedList.includes(String(target))) {
            return res.status(400).json({ success: false, message: 'Mission already claimed' });
        }

        // Count genuine (non-guest) user referrals
        const refQuery = {
            referredBy: user.referralCode
                ? { $in: [user.referralCode, user.userId] }
                : user.userId,
            isGuest: { $ne: true },
            account_deleted: { $ne: true },
            isBlocked: { $ne: true }
        };

        // Check mission config from ReferralSettings
        const referralSettingsDoc = await ReferralSettings.findOne({ key: 'referralSettings' }).lean();
        const refConfig = referralSettingsDoc?.config || {};
        const missionsEnabled = refConfig.missionsEnabled === true;
        const allMissions = Array.isArray(refConfig.missions) ? refConfig.missions : [];
        
        const mission = allMissions.find(m => Number(m.target) === target);
        if (!mission || mission.enabled === false) {
            return res.status(400).json({ success: false, message: 'This mission is currently not active' });
        }

        const referredUserDocs = await User.find(refQuery).select('userId').lean();
        const referredUserIds = referredUserDocs.map(u => u.userId);
        const stats = await getReferredUsersTaskStats(referredUserIds);
        const progress = calculateMissionProgress(mission, referredUserIds, stats);

        if (progress < target) {
            return res.status(400).json({
                success: false,
                message: `You need ${target} qualified referrals to claim this mission. Current: ${progress}`
            });
        }

        const rewardCoins = Number(mission.reward) || 0;
        if (rewardCoins <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid reward configuration' });
        }

        // Update user coins and claimedReferralMissions
        const updatedUser = await User.findOneAndUpdate(
            { userId },
            {
                $inc: { coins: rewardCoins, totalCoins: rewardCoins },
                $addToSet: { claimedReferralMissions: String(target) }
            },
            { new: true }
        );

        // Record in RewardHistory
        await RewardHistory.create({
            appName: req.body?.appName || 'Crazyreward',
            userId: user.userId,
            provider: 'Referral Mission',
            rewardType: 'coin',
            coins: rewardCoins,
            transId: `ref_mission_${target}_${Date.now()}`,
            eventId: `Mission: Invite ${target} Friends`,
            timestamp: new Date()
        });

        return res.json({
            success: true,
            message: `Successfully claimed ${rewardCoins} coins!`,
            coinsEarned: rewardCoins,
            newBalance: updatedUser.coins,
            claimedMissions: updatedUser.claimedReferralMissions || [String(target)],
        });
    } catch (err) {
        console.error('❌ Claim referral mission error:', err);
        return res.status(500).json({ success: false, message: 'Failed to claim referral mission' });
    }
});

// Apply Referral Code API
router.post(['/apply', '/apply-code'], verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId || req.body?.userId;
        const inputCode = req.body?.referralCode || req.body?.code || req.body?.inputReferralCode;

        if (!inputCode || !String(inputCode).trim()) {
            return res.status(400).json({ success: false, message: 'Please enter a referral code' });
        }

        const user = await User.findOne({ userId });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if (user.isGuest || user.isAnonymous) {
            return res.status(400).json({ success: false, message: 'Guest accounts cannot apply referral codes. Please log in with Google to continue!' });
        }

        if (user.referred) {
            return res.status(400).json({ success: false, message: 'You have already applied a referral code!' });
        }

        const cleanCode = String(inputCode).trim();
        const escapedCode = cleanCode.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

        const referrer = await User.findOne({
            $or: [
                { referralCode: cleanCode },
                { referralCode: { $regex: new RegExp('^' + escapedCode + '$', 'i') } },
                { userId: cleanCode }
            ],
            isGuest: { $ne: true },
            isBlocked: { $ne: true },
            account_deleted: { $ne: true }
        });

        if (!referrer) {
            return res.status(400).json({ success: false, message: 'Invalid referral code! This code does not exist.' });
        }

        if (referrer.userId === userId) {
            return res.status(400).json({ success: false, message: 'You cannot use your own referral code.' });
        }

        // 🛡️ Same Device / GAID Self-Referral Prevention
        const userDeviceId = String(user.deviceId || req.headers['device-id'] || req.headers['x-device-id'] || '').trim();
        const userGaid = String(user.gaid || req.headers['gaid'] || req.headers['x-gaid'] || '').trim();
        const referrerDeviceId = String(referrer.deviceId || '').trim();
        const referrerGaid = String(referrer.gaid || '').trim();

        if (
            (userDeviceId && referrerDeviceId && userDeviceId === referrerDeviceId) ||
            (userGaid && referrerGaid && userGaid === referrerGaid)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Self-referral on the same device is not allowed!'
            });
        }

        // Circular Referral Loop Prevention:
        // You cannot use the referral code of someone you already referred or who is in your downline
        if (
            referrer.referredBy === user.userId ||
            (user.referralCode && referrer.referredBy === user.referralCode) ||
            (Array.isArray(referrer.upline) && (referrer.upline.includes(user.userId) || (user.referralCode && referrer.upline.includes(user.referralCode))))
        ) {
            return res.status(400).json({
                success: false,
                message: 'You cannot use the referral code of someone you referred!'
            });
        }

        const upline = [referrer.userId, ...(referrer.upline || [])].slice(0, 3);

        // Check if referral bonus is enabled in AppData config (signupBonusMode === 'referral_code')
        let referralBonusCoins = 0;
        try {
            const AppData = require('../../admin/models/appData');
            const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
            const config = appDataDoc?.config || {};
            if (config.signupBonusMode === 'referral_code' && Number(config.signupCoins) > 0) {
                referralBonusCoins = Number(config.signupCoins);
            }
        } catch (e) {
            console.error('Error fetching referral bonus config:', e);
        }

        // 🛡️ Atomic apply to prevent double-claiming on concurrent requests
        const claimResult = await User.findOneAndUpdate(
            {
                userId: user.userId,
                referred: { $ne: true },
                isGuest: { $ne: true },
                isAnonymous: { $ne: true }
            },
            {
                $set: {
                    referred: true,
                    referredBy: referrer.userId,
                    upline: upline,
                    referrerBonusClaimed: false,
                    lastActiveAt: new Date()
                }
            },
            { new: true }
        );

        if (!claimResult) {
            return res.status(400).json({
                success: false,
                message: 'Referral code already applied or account restricted'
            });
        }

        // Check Referrer Direct Joining Bonus from ReferralSettings
        try {
            const ReferralSettings = require('../../admin/models/referralSettings');
            const refDoc = await ReferralSettings.findOne({ key: 'referralSettings' }).lean();
            const refConfig = refDoc?.config || {};
            const refBonusCoins = Number(refConfig.referrerBonusCoins) || 0;
            const refCondition = refConfig.referrerBonusCondition || 'none';

            if (refCondition === 'none' && refBonusCoins > 0 && !referrer.isGuest && !referrer.isAnonymous) {
                // Instant bonus to direct referrer
                await User.updateOne(
                    { userId: referrer.userId },
                    { $inc: { coins: refBonusCoins, totalCoins: refBonusCoins } }
                );
                await User.updateOne({ userId: user.userId }, { $set: { referrerBonusClaimed: true } });

                await RewardHistory.create({
                    appName: referrer.appName || 'Crazyreward',
                    userId: referrer.userId,
                    provider: 'Referral Bonus',
                    coins: refBonusCoins,
                    rewardType: 'coin',
                    orderId: `ref_joinee_${Date.now()}_${referrer.userId}`,
                    eventId: `Friend joined: ${user.userId}`,
                    timestamp: new Date()
                }).catch(e => console.error('Error recording referrer joinee bonus:', e.message));

                console.log(`🎉 [ReferrerBonus-Instant] Credited ${refBonusCoins} instant coins to referrer ${referrer.userId} for joinee ${user.userId}`);
            }
        } catch (refBonusErr) {
            console.error('Error handling referrer joining bonus in apply:', refBonusErr.message);
        }

        let updatedBalance = claimResult.coins || 0;
        if (referralBonusCoins > 0) {
            const finalUser = await User.findOneAndUpdate(
                { userId: user.userId },
                { $inc: { coins: referralBonusCoins, bonusCoins: referralBonusCoins, totalCoins: referralBonusCoins } },
                { new: true }
            );
            if (finalUser) updatedBalance = finalUser.coins;

            await RewardHistory.create({
                appName: req.body?.appName || 'Crazyreward',
                userId: user.userId,
                provider: 'Referral Bonus',
                coins: referralBonusCoins,
                rewardType: 'coin',
                orderId: `ref_bonus_${Date.now()}_${user.userId}`,
                eventId: 'Referral Bonus Claim',
                timestamp: new Date()
            }).catch(e => console.error('Error recording referral bonus history:', e));
        }

        return res.json({
            success: true,
            message: referralBonusCoins > 0
                ? `Referral code applied! You received ${referralBonusCoins} bonus coins! 🎉`
                : 'Referral code applied successfully! 🎉',
            referred: true,
            referredBy: referrer.userId,
            bonusCoins: referralBonusCoins,
            newBalance: updatedBalance
        });
    } catch (err) {
        console.error('❌ Apply referral code error:', err);
        return res.status(500).json({ success: false, message: 'Failed to apply referral code' });
    }
});

module.exports = router;
