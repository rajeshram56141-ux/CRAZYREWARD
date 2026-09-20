const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const DailyChallengeConfig = require('../../admin/models/dailyChallengeConfig');
const UserDailyChallenge = require('../../admin/models/userDailyChallenge');
const User = require('../../admin/models/user');
const RewardHistory = require('../../admin/models/rewardHistory');
const { cryptoMiddleware } = require('../../admin/middlewares/cryptoMiddleware');
const cacheService = require('../../services/cacheService');

/**
 * Helper to compute today's IST date string and next midnight IST timestamp
 */
function getIstTimeData() {
    const nowUtc = Date.now();
    const istOffsetMs = 5.5 * 60 * 60 * 1000;
    const nowIst = new Date(nowUtc + istOffsetMs);
    const todayDateStr = nowIst.toISOString().split('T')[0];

    // Compute next midnight in IST
    const tomorrowIst = new Date(nowIst);
    tomorrowIst.setUTCDate(tomorrowIst.getUTCDate() + 1);
    tomorrowIst.setUTCHours(0, 0, 0, 0);

    // Convert back to UTC epoch
    const nextMidnightUtc = new Date(tomorrowIst.getTime() - istOffsetMs);

    return {
        todayDateStr,
        nextResetTime: nextMidnightUtc.toISOString(),
        secondsRemaining: Math.max(0, Math.floor((nextMidnightUtc.getTime() - nowUtc) / 1000))
    };
}

/**
 * Global helper to auto-track user progress from other services / routes
 * @param {string} userId
 * @param {string} taskType
 * @param {number} increment
 */
async function trackDailyChallengeProgress(userId, taskType, increment = 1) {
    if (!userId || !taskType) return;
    try {
        await connectMongo();
        const { todayDateStr } = getIstTimeData();
        const incVal = Number(increment) || 1;

        // 1. Atomically increment task progress in MongoDB
        const incField = `taskProgress.${taskType}`;
        const updatedDoc = await UserDailyChallenge.findOneAndUpdate(
            { userId: String(userId).trim(), dateStr: todayDateStr },
            { $inc: { [incField]: incVal } },
            { new: true, upsert: true, setDefaultsOnInsert: true }
        );

        // 2. Fetch config to check if target reached
        let config = await cacheService.get('daily_challenge_config');
        if (!config) {
            config = await DailyChallengeConfig.findOne({ key: 'dailyChallengeConfig' }).lean();
            if (config) await cacheService.set('daily_challenge_config', config, cacheService.getTtl('global'));
        }

        if (config && Array.isArray(config.tasks)) {
            const taskRule = config.tasks.find(t => t.taskType === taskType && t.isActive !== false);
            let currentVal = 0;
            if (updatedDoc && updatedDoc.taskProgress) {
                if (typeof updatedDoc.taskProgress.get === 'function') {
                    currentVal = Number(updatedDoc.taskProgress.get(taskType)) || 0;
                } else if (typeof updatedDoc.taskProgress === 'object') {
                    currentVal = Number(updatedDoc.taskProgress[taskType]) || 0;
                }
            }
            if (taskRule && currentVal >= taskRule.targetCount) {
                await UserDailyChallenge.updateOne(
                    { userId: String(userId).trim(), dateStr: todayDateStr },
                    { $addToSet: { completedTasks: taskType } }
                );
            }
        }
    } catch (e) {
        console.error('❌ Error tracking daily challenge progress:', e);
    }
}

// 1. GET / STATUS OF TODAY'S DAILY CHALLENGE
router.post(['/daily-challenge/status', '/daily-challenge-status'], cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();

        const userId = String(req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId || '').trim();
        if (!userId) {
            return res.status(400).json({ success: false, message: 'Missing userId' });
        }

        const { todayDateStr, nextResetTime, secondsRemaining } = getIstTimeData();

        // 1. Fetch Config (Cached in Redis/Memory)
        let config = await cacheService.get('daily_challenge_config');
        if (!config) {
            config = await DailyChallengeConfig.findOne({ key: 'dailyChallengeConfig' }).lean();
            if (!config) {
                config = await DailyChallengeConfig.create({ key: 'dailyChallengeConfig' });
                config = config.toObject ? config.toObject() : config;
            }
            await cacheService.set('daily_challenge_config', config, cacheService.getTtl('global'));
        }

        const isChallengeActive = config.isActive !== false;
        const rewardCoins = Number(config.rewardCoins) || 500;
        const activeTasks = (config.tasks || []).filter(t => t.isActive !== false);
        activeTasks.sort((a, b) => (a.displayOrder || 0) - (b.displayOrder || 0));

        // 2. Fetch User Daily Progress
        let userChallenge = await UserDailyChallenge.findOne({ userId, dateStr: todayDateStr }).lean();
        if (!userChallenge) {
            userChallenge = {
                userId,
                dateStr: todayDateStr,
                taskProgress: {},
                completedTasks: [],
                claimedReward: false,
                rewardCoinsEarned: 0
            };
        }

        const rawProgress = userChallenge.taskProgress || {};

        // 3. Build Detailed Task Items List
        let completedCount = 0;
        const taskItems = activeTasks.map(task => {
            let currentCount = 0;
            if (rawProgress && typeof rawProgress === 'object') {
                if (rawProgress[task.taskType] !== undefined) {
                    currentCount = Number(rawProgress[task.taskType]) || 0;
                } else if (typeof rawProgress.get === 'function') {
                    currentCount = Number(rawProgress.get(task.taskType)) || 0;
                }
            }

            const isDone = currentCount >= task.targetCount;
            if (isDone) completedCount++;

            return {
                taskId: task.taskId,
                title: task.title,
                description: task.description || '',
                taskType: task.taskType,
                targetCount: task.targetCount,
                currentCount: Math.min(currentCount, task.targetCount),
                actualCount: currentCount,
                progressPercent: Math.min(1.0, task.targetCount > 0 ? (currentCount / task.targetCount) : 0),
                isCompleted: isDone,
                icon: task.icon || 'assets/icons/game.png'
            };
        });

        const totalTasksCount = activeTasks.length;
        const isAllCompleted = totalTasksCount > 0 && completedCount >= totalTasksCount;
        const claimedReward = Boolean(userChallenge.claimedReward);

        return res.json({
            success: true,
            data: {
                isActive: isChallengeActive,
                rewardCoins: rewardCoins,
                dateStr: todayDateStr,
                nextResetTime: nextResetTime,
                secondsRemaining: secondsRemaining,
                totalTasksCount: totalTasksCount,
                completedTasksCount: completedCount,
                overallProgressPercent: totalTasksCount > 0 ? (completedCount / totalTasksCount) : 0,
                isAllCompleted: isAllCompleted,
                claimedReward: claimedReward,
                canClaim: isAllCompleted && !claimedReward,
                tasks: taskItems
            }
        });
    } catch (err) {
        console.error('❌ Error fetching Daily Challenge status:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 2. CLAIM DAILY CHALLENGE REWARD
router.post(['/daily-challenge/claim', '/daily-challenge-claim'], cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();

        const userId = String(req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId || '').trim();
        if (!userId) {
            return res.status(400).json({ success: false, message: 'Missing userId' });
        }

        const { todayDateStr } = getIstTimeData();

        // 1. Fetch Config
        let config = await cacheService.get('daily_challenge_config');
        if (!config) {
            config = await DailyChallengeConfig.findOne({ key: 'dailyChallengeConfig' }).lean();
            if (config) await cacheService.set('daily_challenge_config', config, cacheService.getTtl('global'));
        }

        if (!config || config.isActive === false) {
            return res.status(400).json({ success: false, message: 'Daily Challenge is currently inactive' });
        }

        const rewardCoins = Number(config.rewardCoins) || 500;
        const activeTasks = (config.tasks || []).filter(t => t.isActive !== false);

        if (activeTasks.length === 0) {
            return res.status(400).json({ success: false, message: 'No active challenge tasks configured' });
        }

        // 2. Fetch User Record & Challenge Progress
        const userDoc = await User.findOne({ userId }).lean();
        if (userDoc && (userDoc.isGuest === true || userDoc.isAnonymous === true)) {
            return res.status(403).json({ success: false, message: 'Guest accounts cannot claim daily challenge rewards. Please log in with Google to continue!' });
        }

        let userChallenge = await UserDailyChallenge.findOne({ userId, dateStr: todayDateStr });
        if (!userChallenge) {
            return res.status(400).json({ success: false, message: 'You have not made any challenge progress today' });
        }

        if (userChallenge.claimedReward) {
            return res.status(400).json({ success: false, message: 'You have already claimed today\'s Daily Challenge reward!' });
        }

        // 3. Verify ALL active tasks are 100% completed
        const rawProgress = userChallenge.taskProgress || new Map();
        for (const task of activeTasks) {
            const currentCount = rawProgress instanceof Map
                ? (rawProgress.get(task.taskType) || 0)
                : (rawProgress[task.taskType] || 0);

            if (currentCount < task.targetCount) {
                return res.status(400).json({
                    success: false,
                    message: `Incomplete: You must complete "${task.title}" (${currentCount}/${task.targetCount}) first!`
                });
            }
        }

        // 4. Atomically mark claimed & credit coins
        userChallenge.claimedReward = true;
        userChallenge.claimedAt = new Date();
        userChallenge.rewardCoinsEarned = rewardCoins;
        await userChallenge.save();

        const mongoose = require('mongoose');
        let userQuery = { userId };
        if (mongoose.Types.ObjectId.isValid(userId)) {
            userQuery = { $or: [{ userId }, { _id: userId }] };
        }

        const updatedUser = await User.findOneAndUpdate(
            userQuery,
            { $inc: { coins: rewardCoins } },
            { new: true }
        );

        // Record in RewardHistory
        try {
            const orderId = `daily_challenge_${userId}_${todayDateStr}`;
            await RewardHistory.updateOne(
                { orderId },
                {
                    $setOnInsert: {
                        appName: req.appData?.appName || '',
                        userId,
                        provider: 'Daily Challenge',
                        coins: rewardCoins,
                        rewardType: 'coin',
                        orderId,
                        timestamp: new Date()
                    }
                },
                { upsert: true }
            );
        } catch (rhErr) {
            console.error('⚠️ Error logging RewardHistory for Daily Challenge:', rhErr);
        }

        return res.json({
            success: true,
            rewardCoins: rewardCoins,
            newBalance: updatedUser ? updatedUser.coins : 0,
            message: `🎉 Awesome! +${rewardCoins} Coins claimed successfully for completing Daily Challenge!`
        });
    } catch (err) {
        console.error('❌ Error claiming Daily Challenge reward:', err);
        return res.status(500).json({ success: false, message: 'Failed to claim reward. Please try again.' });
    }
});

module.exports = {
    router,
    trackDailyChallengeProgress
};
