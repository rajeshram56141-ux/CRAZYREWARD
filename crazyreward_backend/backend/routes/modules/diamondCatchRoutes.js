const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const User = require('../../admin/models/user');
const AppData = require('../../admin/models/appData');
const RewardHistory = require('../../admin/models/rewardHistory');
const cacheService = require('../../services/cacheService');
const { cryptoMiddleware } = require('../../admin/middlewares/cryptoMiddleware');
const antiReplayMiddleware = require('../../admin/middlewares/antiReplayMiddleware');

function parseNumberOrRange(input, defaultVal = 8) {
    if (typeof input === 'number' && !isNaN(input)) return input;
    const str = String(input || '').trim();
    if (!str) return defaultVal;

    const match = str.match(/^(\d+)\s*-\s*(\d+)$/);
    if (match) {
        const min = parseInt(match[1], 10);
        const max = parseInt(match[2], 10);
        if (min <= max) {
            return Math.floor(Math.random() * (max - min + 1)) + min;
        }
    }

    const num = parseInt(str, 10);
    return !isNaN(num) && num >= 0 ? num : defaultVal;
}

/**
 * Helper to get Super Offer / Diamond Catch config with Redis RAM caching (5 min TTL)
 */
async function getSuperOfferConfig() {
    try {
        const cached = await cacheService.get('diamondcatch:config');
        if (cached) return cached;
    } catch (_) {}

    await connectMongo();
    const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
    const superOfferConfig = appDataDoc?.config?.superOfferConfig || appDataDoc?.superOfferConfig || {};

    try {
        const ttl = cacheService.getTtl('global') || 300;
        await cacheService.set('diamondcatch:config', superOfferConfig, ttl);
    } catch (_) {}

    return superOfferConfig;
}

// 1. DIAMOND CATCH LIMITS VERIFICATION
router.post('/diamond-catch-verify', cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'Missing userId' });
        }

        await connectMongo();

        const superOfferConfig = await getSuperOfferConfig();

        const userDoc = await User.findOne({ userId });
        if (!userDoc) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const istNow = new Date(now.getTime() + istOffset);
        const startOfIstDay = new Date(Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate(), 0, 0, 0) - istOffset);
        const todayIstDateStr = istNow.toISOString().split('T')[0];

        let userGameDailyLimit = userDoc.gameDailyLimit;
        let gameInstallTriggerAt = userDoc.superOfferGameInstallTriggerAt;

        // Check if user is ALREADY assigned for TODAY (todayIstDateStr)
        const isGameAssignedToday = userDoc.gameAssignedDateStr === todayIstDateStr;
        let updateFields = {};

        if (!isGameAssignedToday) {
            // New Day! Assign fresh Game values from Global superOfferConfig
            userGameDailyLimit = parseNumberOrRange(superOfferConfig.gameDailyLimit);
            gameInstallTriggerAt = parseNumberOrRange(superOfferConfig.gameInstallTaskTriggerLimit);

            updateFields.gameDailyLimit = userGameDailyLimit;
            updateFields.superOfferGameInstallTriggerAt = gameInstallTriggerAt;
            updateFields.gameClaimsToday = 0;
            updateFields.gameAssignedAt = new Date();
            updateFields.gameAssignedDateStr = todayIstDateStr;

            // Sync in-memory userDoc immediately so fresh 0 claims are returned
            userDoc.gameDailyLimit = userGameDailyLimit;
            userDoc.superOfferGameInstallTriggerAt = gameInstallTriggerAt;
            userDoc.gameClaimsToday = 0;
            userDoc.gameAssignedAt = updateFields.gameAssignedAt;
            userDoc.gameAssignedDateStr = todayIstDateStr;
        } else {
            if (!userGameDailyLimit) {
                userGameDailyLimit = parseNumberOrRange(superOfferConfig.gameDailyLimit);
                updateFields.gameDailyLimit = userGameDailyLimit;
                userDoc.gameDailyLimit = userGameDailyLimit;
            }
            if (!gameInstallTriggerAt) {
                gameInstallTriggerAt = parseNumberOrRange(superOfferConfig.gameInstallTaskTriggerLimit);
                updateFields.superOfferGameInstallTriggerAt = gameInstallTriggerAt;
                userDoc.superOfferGameInstallTriggerAt = gameInstallTriggerAt;
            }
        }

        if (Object.keys(updateFields).length > 0) {
            await User.updateOne({ userId }, { $set: updateFields }).catch(() => { });
        }

        const gameDailyLimit = (userGameDailyLimit && Number(userGameDailyLimit) > 0)
            ? Number(userGameDailyLimit)
            : parseNumberOrRange(superOfferConfig.gameDailyLimit || '10-20', 10);

        let gameClaimsHistoryCount = await RewardHistory.countDocuments({
            userId,
            provider: { $in: ['Game Gems', 'App Install Gems'] },
            createdAt: { $gte: startOfIstDay }
        });

        const gameClaimsToday = isGameAssignedToday
            ? Math.max(Number(userDoc.gameClaimsToday || 0), gameClaimsHistoryCount)
            : gameClaimsHistoryCount;

        const isGameEligible = gameClaimsToday < gameDailyLimit;

        const installTaskEnabled = Boolean(superOfferConfig.installTask === true || superOfferConfig.installTask === 'true');
        const triggerClaimNum = Number(gameInstallTriggerAt || userDoc.superOfferGameInstallTriggerAt || 2);
        const gameInstallTask = installTaskEnabled && (gameClaimsToday + 1) === triggerClaimNum;

        return res.status(200).json({
            success: true,
            gameDailyLimit,
            gameClaimsToday,
            gameInstallTask,
            gameEligible: isGameEligible,
            serverTodayDateStr: todayIstDateStr,
            assignedDateStr: todayIstDateStr
        });
    } catch (err) {
        console.error('🔥 Error in diamond-catch-verify:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 2. CLAIM DIAMOND CATCH GEMS
router.post(['/reward/gems', '/claim-gems', '/gems'], cryptoMiddleware, antiReplayMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        let gems = req.body?.gems;
        let isInstall = req.body?.isInstall;
        let appName = req.body?.appName || req.headers['app-name'] || req.headers['x-app-name'];

        const isInstallClaim = Boolean(isInstall === true || isInstall === 'true');
        // 🛡️ Security Fix: Enforce strict server-side gem cap (1 gem for game catch, 2 for install task)
        const gemsToAdd = isInstallClaim ? 2 : 1;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'Missing userId' });
        }

        await connectMongo();

        const superOfferConfig = await getSuperOfferConfig();

        const userDoc = await User.findOne({ userId });
        if (!userDoc) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if (userDoc.isGuest === true || userDoc.isAnonymous === true) {
            return res.status(403).json({ success: false, message: 'Guest accounts cannot claim gems. Please log in with Google to continue!' });
        }

        // Check game daily limit
        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const istNow = new Date(now.getTime() + istOffset);
        const startOfIstDay = new Date(Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate(), 0, 0, 0) - istOffset);
        const todayIstDateStr = istNow.toISOString().split('T')[0];

        const isGameAssignedToday = userDoc.gameAssignedDateStr === todayIstDateStr;
        let userGameDailyLimit = userDoc.gameDailyLimit;
        let gameInstallTriggerAt = userDoc.superOfferGameInstallTriggerAt;
        let gameClaimsToday = 0;

        if (!isGameAssignedToday) {
            // New Day rollover directly in claim!
            userGameDailyLimit = parseNumberOrRange(superOfferConfig.gameDailyLimit);
            gameInstallTriggerAt = parseNumberOrRange(superOfferConfig.gameInstallTaskTriggerLimit);
            userDoc.gameDailyLimit = userGameDailyLimit;
            userDoc.superOfferGameInstallTriggerAt = gameInstallTriggerAt;
            userDoc.gameClaimsToday = 0;
            userDoc.gameAssignedAt = new Date();
            userDoc.gameAssignedDateStr = todayIstDateStr;
            gameClaimsToday = 0;
        } else {
            const gameClaimsHistoryCount = await RewardHistory.countDocuments({
                userId,
                provider: { $in: ['Game Gems', 'App Install Gems'] },
                createdAt: { $gte: startOfIstDay }
            });
            gameClaimsToday = userDoc.gameClaimsToday !== undefined && userDoc.gameClaimsToday !== null
                ? Math.max(Number(userDoc.gameClaimsToday), gameClaimsHistoryCount)
                : gameClaimsHistoryCount;
            if (!userGameDailyLimit) {
                userGameDailyLimit = parseNumberOrRange(superOfferConfig.gameDailyLimit);
            }
        }

        const rawGameLimit = superOfferConfig.gameDailyLimit || '10-20';
        const gameDailyLimit = (userGameDailyLimit && Number(userGameDailyLimit) > 0)
            ? Number(userGameDailyLimit)
            : parseNumberOrRange(rawGameLimit, 10);

        if (gameClaimsToday >= gameDailyLimit) {
            return res.status(400).json({
                success: false,
                limitReached: true,
                message: 'Today game limit over, come tomorrow!'
            });
        }

        let updateQuery = {};
        if (!isGameAssignedToday) {
            updateQuery = {
                $inc: { gems: gemsToAdd },
                $set: {
                    gameClaimsToday: 1,
                    gameDailyLimit: userGameDailyLimit,
                    superOfferGameInstallTriggerAt: gameInstallTriggerAt,
                    gameAssignedDateStr: todayIstDateStr,
                    gameAssignedAt: new Date(),
                    lastActiveAt: new Date()
                }
            };
        } else {
            updateQuery = {
                $inc: { gems: gemsToAdd, gameClaimsToday: 1 },
                $set: { lastActiveAt: new Date() }
            };
        }

        const user = await User.findOneAndUpdate(
            {
                userId,
                isGuest: { $ne: true },
                isAnonymous: { $ne: true },
                isBlocked: { $ne: true },
                account_deleted: { $ne: true }
            },
            updateQuery,
            { new: true }
        );

        if (!user) {
            return res.status(403).json({ success: false, message: 'Account restricted or guest' });
        }

        const gemOrderId = 'GEM_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);

        await RewardHistory.create({
            appName: appName || user.appName || '',
            userId,
            provider: isInstallClaim ? 'App Install Gems' : 'Game Gems',
            coins: 0,
            gems: gemsToAdd,
            rewardType: 'gem',
            orderId: gemOrderId,
            createdAt: new Date(),
            timestamp: new Date()
        });

        // Track Daily Challenge progress for Diamond Catch
        try {
            const { trackDailyChallengeProgress } = require('./dailyChallengeApiRoutes');
            trackDailyChallengeProgress(userId, 'diamond_catch', 1);
        } catch (_) {}

        // 🌐 Outgoing Postback Trigger for Diamond Catch Limit Completed (Case 2)
        if (user.gameClaimsToday >= gameDailyLimit) {
            if (user.publisherRef && user.publisherUid) {
                try {
                    const triggerOutgoingPostback = require('../../services/publisherPostbackService');
                    triggerOutgoingPostback({
                        user,
                        offerId: 'diamond_game_limit',
                        coins: 0,
                        eventId: ''
                    }).catch(err => console.error("⚠️ S2S Outgoing Postback error:", err.message));
                } catch (loadErr) {
                    console.error("⚠️ Failed to load publisherPostbackService:", loadErr.message);
                }
            }
        }

        console.log(`💎 [ClaimGems] Success: userId=${userId}, gemsToAdd=${gemsToAdd}, totalGems=${user.gems}, gameClaimsToday=${user.gameClaimsToday}`);

        return res.status(200).json({
            success: true,
            response: 'success',
            message: 'Gems claimed successfully',
            gems: user.gems || 0,
            coins: user.coins || 0,
            gameClaimsToday: user.gameClaimsToday || (gameClaimsToday + 1),
            gameDailyLimit: gameDailyLimit,
        });
    } catch (error) {
        console.error('🔥 Error in claim-gems:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

module.exports = router;
