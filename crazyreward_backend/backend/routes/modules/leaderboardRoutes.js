const express = require('express');
const router = express.Router();
const { DateTime } = require('luxon');
const connectMongo = require('../../admin/middlewares/connectMongo');
const User = require('../../admin/models/user');
const RewardHistory = require('../../admin/models/rewardHistory');
const cacheService = require('../../services/cacheService');

// Helper to get active 24-hour cycle window (Rolling last 24 hours)
function getCycleStartDate() {
    return new Date(Date.now() - 24 * 60 * 60 * 1000);
}

// Security Middleware for Client APIs
const clientAuthMiddleware = (req, res, next) => {
    const clientKey = req.headers['x-api-key'];
    const authHeader = req.headers['authorization'];
    const userIdHeader = req.headers['x-user-id'] || req.headers['user-id'];
    const deviceIdHeader = req.headers['x-device-id'] || req.headers['device-id'];
    const apiKey = process.env.API_KEY;

    const hasValidKey = Boolean(clientKey && apiKey && clientKey === apiKey);
    const hasToken = Boolean(authHeader && authHeader.startsWith('Bearer '));
    const hasPayload = Boolean(req.rawPayload || req.body?.payload || req.isDecrypted);
    const hasDeviceHeaders = Boolean(userIdHeader && deviceIdHeader);
    const isAdmin = Boolean(req.cookies && (req.cookies.adminToken || req.cookies.admin));

    if (hasValidKey || hasToken || hasPayload || hasDeviceHeaders || isAdmin) {
        return next();
    }
    return res.status(401).json({ success: false, message: 'Unauthorized: Authentication required' });
};

// Get Leaderboard Top Users API (Daily 24h Cycle Window)
router.all('/top', clientAuthMiddleware, async (req, res) => {
    try {
        await connectMongo();

        const requestedType = (
            req.body?.docId ||
            req.body?.type ||
            req.query?.docId ||
            req.query?.type ||
            'coinsBased'
        ).toString().trim();

        const cacheKey = `leaderboard:coins:${requestedType}`;
        const cached = await cacheService.get(cacheKey);
        if (cached) {
            return res.json(cached);
        }

        const cycleStartDate = getCycleStartDate();
        const cycleStartISO = cycleStartDate.toISOString();

        // 1. Fetch Top Coins Earners in Current 24-Hour Cycle (RewardHistory)
        let topCoinsUsers = [];
        const seenCoinsUserIds = new Set();

        try {
            const coinRewards = await RewardHistory.aggregate([
                {
                    $match: {
                        userId: { $exists: true, $type: 'string', $ne: '' },
                        coins: { $gt: 0 },
                        $or: [
                            { timestamp: { $gte: cycleStartDate } },
                            { timestamp: { $gte: cycleStartISO } },
                            { createdAt: { $gte: cycleStartDate } },
                            { createdAt: { $gte: cycleStartISO } }
                        ]
                    }
                },
                {
                    $group: {
                        _id: "$userId",
                        totalCoins: { $sum: "$coins" }
                    }
                },
                {
                    $sort: { totalCoins: -1 }
                },
                {
                    $limit: 100
                }
            ]);

            if (coinRewards && coinRewards.length > 0) {
                const userIds = coinRewards.map(r => String(r._id).trim()).filter(Boolean);
                const users = await User.find({
                    userId: { $in: userIds },
                    isBlocked: { $ne: true },
                    account_deleted: { $ne: true },
                    isLeaderboardBanned: { $ne: true },
                    isGuest: { $ne: true },
                    isAnonymous: { $ne: true }
                }).select('userId displayName photoUrl coins totalCoins countryCode').lean();

                const userMap = {};
                users.forEach(u => {
                    if (u.userId) userMap[String(u.userId).trim()] = u;
                });

                coinRewards.forEach(r => {
                    const u = userMap[String(r._id).trim()];
                    if (u) {
                        seenCoinsUserIds.add(u.userId);
                        const userDisplayName = (u.displayName && u.displayName.trim().length > 0)
                            ? u.displayName.trim()
                            : 'Crazyreward User';
                        topCoinsUsers.push({
                            userId: u.userId,
                            displayName: userDisplayName,
                            name: userDisplayName,
                            photoUrl: u.photoUrl || '',
                            coins: r.totalCoins || 0,
                            totalCoins: r.totalCoins || 0,
                            totalReferrals: 0,
                            countryCode: u.countryCode || 'IN'
                        });
                    }
                });
            }
        } catch (coinAggErr) {
            console.error('⚠️ Coin 24h aggregation warning:', coinAggErr);
        }

        // Sort topCoinsUsers descending by totalCoins
        topCoinsUsers.sort((a, b) => (b.totalCoins || 0) - (a.totalCoins || 0));

        // 2. Fetch Top Referrers in Current 24-Hour Cycle
        let topReferralUsers = [];
        const seenReferralUserIds = new Set();

        try {
            const referralCounts = await User.aggregate([
                {
                    $match: {
                        referredBy: { $exists: true, $type: 'string', $ne: '' },
                        $or: [
                            { createdAt: { $gte: cycleStartDate } },
                            { createdAt: { $gte: cycleStartISO } }
                        ],
                        isGuest: { $ne: true },
                        isAnonymous: { $ne: true },
                        isBlocked: { $ne: true },
                        account_deleted: { $ne: true }
                    }
                },
                {
                    $group: {
                        _id: "$referredBy",
                        totalReferrals: { $sum: 1 }
                    }
                },
                {
                    $sort: { totalReferrals: -1 }
                },
                {
                    $limit: 100
                }
            ]);

            if (referralCounts && referralCounts.length > 0) {
                const referrerKeys = referralCounts.map(r => String(r._id).trim()).filter(Boolean);
                const referrers = await User.find({
                    $or: [
                        { userId: { $in: referrerKeys } },
                        { referralCode: { $in: referrerKeys } }
                    ],
                    isBlocked: { $ne: true },
                    account_deleted: { $ne: true },
                    isLeaderboardBanned: { $ne: true },
                    isGuest: { $ne: true },
                    isAnonymous: { $ne: true }
                })
                    .select('userId displayName photoUrl referralCode coins totalCoins countryCode')
                    .lean();

                const userLookup = {};
                referrers.forEach(u => {
                    if (u.userId) userLookup[String(u.userId).trim()] = u;
                    if (u.referralCode) userLookup[String(u.referralCode).trim()] = u;
                });

                referralCounts.forEach(r => {
                    const matchedUser = userLookup[String(r._id).trim()];
                    if (matchedUser && matchedUser.userId && !seenReferralUserIds.has(matchedUser.userId)) {
                        seenReferralUserIds.add(matchedUser.userId);
                        const userDisplayName = (matchedUser.displayName && matchedUser.displayName.trim().length > 0)
                            ? matchedUser.displayName.trim()
                            : 'Crazyreward User';

                        topReferralUsers.push({
                            userId: matchedUser.userId,
                            displayName: userDisplayName,
                            name: userDisplayName,
                            photoUrl: matchedUser.photoUrl || '',
                            coins: matchedUser.coins || 0,
                            totalCoins: 0,
                            totalReferrals: Number(r.totalReferrals) || 0,
                            countryCode: matchedUser.countryCode || 'IN'
                        });
                    }
                });
            }
        } catch (aggErr) {
            console.error('⚠️ Referral 24h aggregation warning:', aggErr);
        }

        // Sort topReferralUsers descending by totalReferrals
        topReferralUsers.sort((a, b) => (b.totalReferrals || 0) - (a.totalReferrals || 0));

        const isReferralRequest = requestedType === 'referralBased';
        const activeLeaderboard = isReferralRequest ? topReferralUsers : topCoinsUsers;

        const responsePayload = {
            success: true,
            leaderboard: activeLeaderboard,
            coinsLeaderboard: topCoinsUsers,
            referralLeaderboard: topReferralUsers,
            cycleStartTime: cycleStartDate.getTime()
        };

        await cacheService.set(cacheKey, responsePayload, cacheService.getTtl('leaderboard'));

        return res.json(responsePayload);
    } catch (err) {
        console.error('❌ Get leaderboard error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch leaderboard' });
    }
});

module.exports = router;
