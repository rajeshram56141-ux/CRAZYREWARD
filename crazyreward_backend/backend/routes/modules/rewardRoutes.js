const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const verifyAuthToken = require('../../admin/middlewares/verifyAuthToken');
const cryptoMiddleware = require('../../admin/middlewares/cryptoMiddleware');
const antiReplayMiddleware = require('../../admin/middlewares/antiReplayMiddleware');
const rateLimiter = require('../../admin/middlewares/rateLimiter');
const promoRateLimiter = rateLimiter({
    windowMs: 60 * 1000,
    max: 10,
    keyPrefix: 'promo-limit',
    keyGenerator: (req) => req.userId || req.body?.userId || req.headers['user-id'] || 'global-promo'
});
const User = require('../../admin/models/user');
const AppData = require('../../admin/models/appData');
const RewardHistory = require('../../admin/models/rewardHistory');
const PromoCode = require('../../admin/models/promoCode');

// Helper: IST Date string
function getTodayIstDateStr() {
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);
    return istNow.toISOString().split('T')[0];
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
    const hasDeviceHeaders = Boolean(userIdHeader && (deviceIdHeader || (clientKey && clientKey === apiKey)));
    const isAdmin = Boolean(req.cookies && (req.cookies.adminToken || req.cookies.admin));

    if (hasValidKey || hasToken || hasPayload || hasDeviceHeaders || isAdmin) {
        return next();
    }
    return res.status(401).json({ success: false, message: 'Unauthorized: Authentication required' });
};

const superOfferRoutes = require('./superOfferRoutes');
router.use('/super-offer', superOfferRoutes);

// 1. Streak / Daily Check-in Reward API
router.post(['/streak', '/reward/streak'], cryptoMiddleware, antiReplayMiddleware, verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId || req.body?.userId;
        if (!userId) {
            return res.status(400).json({ success: false, message: 'User ID required' });
        }

        const user = await User.findOne({ userId });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if (user.isGuest || user.isAnonymous) {
            return res.status(403).json({ success: false, message: 'Guest accounts cannot claim daily bonus. Please log in with Google to continue!' });
        }

        const todayIstDateStr = getTodayIstDateStr();

        // Check if user already claimed streak today
        if (user.streakClaimed) {
            return res.status(400).json({ success: false, message: 'Daily check-in already claimed today' });
        }

        // Fetch streak coins config from AppData
        const appData = await AppData.findOne({ active: true }).lean() || await AppData.findOne().lean() || {};
        const rawConfig = appData.config || appData || {};
        const streakConfig = rawConfig.streakConfig || {};
        const baseCoins = Number(streakConfig.coins ?? rawConfig.streakCoins) || 10;

        const currentStreak = Number(user.streak || 1);
        const rewardCoins = currentStreak * baseCoins;

        // 🛡️ Atomic check-and-claim in MongoDB to prevent race conditions & double-claims
        const updatedUser = await User.findOneAndUpdate(
            {
                userId,
                streakClaimed: { $ne: true },
                isGuest: { $ne: true },
                isAnonymous: { $ne: true },
                isBlocked: { $ne: true }
            },
            {
                $inc: { coins: rewardCoins, totalCoins: rewardCoins },
                $set: {
                    streakClaimed: true,
                    streak: currentStreak,
                    lastStreakDateStr: todayIstDateStr,
                    lastActiveAt: new Date()
                }
            },
            { new: true }
        );

        if (!updatedUser) {
            return res.status(400).json({ success: false, message: 'Daily check-in already claimed today or account restricted' });
        }

        // Log Reward History
        const orderId = `streak_${userId}_${todayIstDateStr}`;
        await RewardHistory.updateOne(
            { orderId },
            {
                $setOnInsert: {
                    appName: appData.appName || '',
                    userId,
                    provider: 'Daily Check-in',
                    coins: rewardCoins,
                    orderId,
                    timestamp: new Date()
                }
            },
            { upsert: true }
        ).catch(() => {});

        // Track Daily Challenge for Daily Check-in
        const { trackDailyChallengeProgress } = require('./dailyChallengeApiRoutes');
        trackDailyChallengeProgress(userId, 'daily_checkin', 1);

        return res.json({
            success: true,
            message: `Successfully claimed ${rewardCoins} coins!`,
            coins: rewardCoins,
            userCoins: updatedUser.coins,
            streak: updatedUser.streak,
            streakClaimed: true
        });
    } catch (err) {
        console.error('❌ Error claiming streak reward:', err);
        return res.status(500).json({ success: false, message: 'Failed to claim daily check-in reward' });
    }
});





// 4. Promo Code Reward API
router.post(['/promo-code', '/reward/promo-code'], cryptoMiddleware, verifyAuthToken, promoRateLimiter, async (req, res) => {
    try {
        await connectMongo();
        const userId = String(req.userId || req.body?.userId || req.headers['x-user-id'] || req.headers['user-id'] || '').trim();
        const promoCodeInput = String(req.body?.code || req.body?.promoCode || '').trim().toUpperCase();

        if (!userId || !promoCodeInput) {
            return res.status(200).json({ success: false, message: 'Promo code required' });
        }

        let user = await User.findOne({ userId });
        if (!user) {
            user = await User.findOne({ $or: [{ userId }, { firebaseUid: userId }] });
        }
        if (!user) {
            return res.status(200).json({ success: false, message: 'User not found' });
        }

        if (user.isGuest || user.isAnonymous) {
            return res.status(200).json({ success: false, message: 'Guest accounts cannot redeem promo codes. Please log in with Google to continue!' });
        }

        const promoDoc = await PromoCode.findOne({ 
            code: { $regex: new RegExp(`^${promoCodeInput.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')}$`, 'i') }
        });

        if (!promoDoc) {
            return res.status(200).json({ success: false, message: 'Invalid promo code' });
        }

        const orderId = `promo_${promoCodeInput}_${userId}`;
        if (promoDoc.active === false) {
            return res.status(200).json({ success: false, message: 'Expired promo code' });
        }

        const maxRedemptions = Number(promoDoc.maxRedemptions !== undefined ? promoDoc.maxRedemptions : (promoDoc.maxUses || 0));

        // 🛡️ Atomic promo code lock & limit enforcement
        const promoLockQuery = {
            _id: promoDoc._id,
            active: { $ne: false },
            usedUsers: { $ne: userId }
        };
        if (maxRedemptions > 0) {
            promoLockQuery.$or = [
                { redeemedCount: { $lt: maxRedemptions } },
                { currentUses: { $lt: maxRedemptions } },
                { redeemedCount: { $exists: false } }
            ];
        }

        const updatedPromo = await PromoCode.findOneAndUpdate(
            promoLockQuery,
            {
                $addToSet: { usedUsers: userId },
                $inc: { redeemedCount: 1, currentUses: 1 }
            },
            { new: true }
        );

        if (!updatedPromo) {
            return res.status(200).json({ success: false, message: 'Promo code limit reached or already claimed' });
        }

        if (maxRedemptions > 0 && (updatedPromo.redeemedCount >= maxRedemptions || updatedPromo.currentUses >= maxRedemptions)) {
            await PromoCode.updateOne({ _id: promoDoc._id }, { $set: { active: false } }).catch(() => {});
        }

        const rewardCoins = Number(promoDoc.reward !== undefined ? promoDoc.reward : (promoDoc.coins || 0));

        // Credit user atomically
        const updatedUser = await User.findOneAndUpdate(
            { userId: user.userId },
            {
                $inc: { coins: rewardCoins, totalCoins: rewardCoins },
                $set: { lastActiveAt: new Date() }
            },
            { new: true }
        );

        await RewardHistory.create({
            appName: user.appName || '',
            userId,
            provider: 'Promo Code',
            coins: rewardCoins,
            orderId,
            timestamp: new Date()
        }).catch(() => {});

        return res.json({
            success: true,
            message: `Redeemed ${rewardCoins} coins with promo code ${promoCodeInput}!`,
            coins: rewardCoins,
            userCoins: updatedUser ? updatedUser.coins : (Number(user.coins) || 0) + rewardCoins
        });
    } catch (err) {
        console.error('❌ Error redeeming promo code:', err);
        return res.status(500).json({ success: false, message: 'Failed to redeem promo code' });
    }
});

// 4.1 Get Recent Promo Code Redemptions API (100% Real Database Records Only)
router.all(['/promo-code/recent', '/getRecentPromoRedemptions'], clientAuthMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const recentRecords = await RewardHistory.find({
            provider: { $regex: /promo/i }
        })
        .sort({ timestamp: -1, createdAt: -1 })
        .limit(20)
        .lean();

        if (recentRecords && recentRecords.length > 0) {
            const formatted = recentRecords.map((r, idx) => {
                const rawUid = String(r.userId || 'USER');
                let masked = rawUid.length > 8 
                    ? rawUid.substring(0, 4).toUpperCase() + '*****' + rawUid.substring(rawUid.length - 4).toUpperCase()
                    : rawUid.substring(0, 2).toUpperCase() + '*****' + rawUid.substring(rawUid.length - 2).toUpperCase();
                
                if (r.orderId && r.orderId.startsWith('promo_')) {
                    const parts = r.orderId.split('_');
                    if (parts.length >= 2) {
                        const codeName = parts[1];
                        masked = (codeName.length > 4 ? codeName.substring(0, 3) + '*****' + codeName.slice(-2) : codeName + '*****' + (1240 + idx)).toUpperCase();
                    }
                }

                return {
                    id: String(r._id || `promo_${idx}`),
                    code: masked,
                    coins: Number(r.coins) || 0,
                    timestamp: r.timestamp || r.createdAt || new Date(),
                };
            });
            return res.json({ success: true, data: formatted });
        }

        return res.json({ success: true, data: [] });
    } catch (err) {
        console.error('Error fetching recent redemptions:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

// 5. Get Reward History API
router.all(['/get-reward-history', '/history', '/reward/history'], clientAuthMiddleware, async (req, res) => {
    try {
        const userId = String(req.query?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.body?.userId || '').trim();
        const limit = Math.min(Number(req.query?.limit) || 150, 300);
        const skip = Number(req.query?.skip) || 0;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        await connectMongo();

        const history = await RewardHistory.find({
            $or: [
                { userId: userId },
                { userId: new RegExp(`^${userId}$`, 'i') }
            ],
            $and: [
                { rewardType: { $nin: ['gem', 'refund'] } },
                { coins: { $ne: 0 } },
                { provider: { $not: /refund/i } }
            ]
        })
            .sort({ timestamp: -1 })
            .skip(skip)
            .limit(limit)
            .lean();

        const formattedHistory = (history || []).map(item => {
            if (item.provider === 'Super Offer Step 1 Install' || item.provider === 'Super Offer Install') {
                return { ...item, provider: 'Super Offer Task' };
            }
            return item;
        });

        return res.status(200).json({ success: true, data: formattedHistory });
    } catch (err) {
        console.error('❌ Error getting reward history:', err);
        return res.status(500).json({ success: false, message: 'Failed to get reward history' });
    }
});

// 6. Social Follow Reward API
router.post(['/follow', '/reward/follow'], cryptoMiddleware, verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = String(req.userId || req.body?.userId || req.headers['x-user-id'] || req.headers['user-id'] || '').trim();
        const tag = String(req.body?.tag || '').trim().toLowerCase();

        if (!userId || !tag) {
            return res.status(200).json({ success: false, message: 'User ID and social tag required' });
        }

        let user = await User.findOne({ userId }).lean();
        if (!user) {
            user = await User.findOne({ $or: [{ userId }, { firebaseUid: userId }] }).lean();
        }
        if (!user) {
            return res.status(200).json({ success: false, message: 'User not found' });
        }

        if (user.isGuest === true || user.isAnonymous === true) {
            return res.status(200).json({ success: false, message: 'Guest accounts cannot claim social follow rewards. Please log in with Google to continue!' });
        }

        // Fetch followCoins config from AppData
        const appData = await AppData.findOne({ active: true }).lean() || await AppData.findOne().lean() || {};
        const rawConfig = appData.config || appData || {};
        const followCoins = Number(rawConfig.followCoins || appData.followCoins || 50);

        // 🛡️ Atomic Follow Reward Claim (Prevent Double Click and Guest Exploits)
        const updatedUser = await User.findOneAndUpdate(
            {
                userId: user.userId,
                socialFollowed: { $ne: tag },
                isGuest: { $ne: true },
                isAnonymous: { $ne: true }
            },
            {
                $addToSet: { socialFollowed: tag },
                $inc: { coins: followCoins, totalCoins: followCoins },
                $set: { lastActiveAt: new Date() }
            },
            { new: true }
        );

        if (!updatedUser) {
            return res.status(200).json({ success: false, message: 'Already followed or account restricted' });
        }

        const orderId = `follow_${tag}_${userId}`;
        await RewardHistory.create({
            appName: user.appName || '',
            userId,
            provider: `Follow ${tag.toUpperCase()}`,
            coins: followCoins,
            orderId,
            timestamp: new Date()
        }).catch(() => {});

        return res.json({
            success: true,
            message: `Earned ${followCoins} coins for following ${tag.toUpperCase()}!`,
            coins: followCoins,
            userCoins: updatedUser.coins
        });
    } catch (err) {
        console.error('❌ Error claiming follow reward:', err);
        return res.status(500).json({ success: false, message: 'Failed to claim follow reward' });
    }
});

module.exports = router;
