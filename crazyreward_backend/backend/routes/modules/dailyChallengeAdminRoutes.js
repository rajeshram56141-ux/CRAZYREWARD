const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const adminAuth = require('../../admin/middlewares/adminAuth');
const DailyChallengeConfig = require('../../admin/models/dailyChallengeConfig');
const cacheService = require('../../services/cacheService');

const checkPermission = (...permKeys) => {
    const permList = permKeys.flat();
    return (req, res, next) => {
        const isJson = req.xhr || req.headers['content-type'] === 'application/json' || (req.headers.accept && req.headers.accept.includes('application/json'));
        if (!req.admin) {
            if (isJson) return res.status(401).json({ success: false, message: 'Unauthorized. Please login.' });
            return res.redirect('/login');
        }
        if (req.admin.role === 'superadmin') {
            return next();
        }
        if (req.admin.permissions && permList.some(k => req.admin.permissions[k] === true)) {
            return next();
        }
        if (isJson) return res.status(403).json({ success: false, message: 'Access Denied: Insufficient Permissions' });
        return res.status(403).render('error', { message: 'Access Denied: Insufficient Permissions' });
    };
};

// 1. GET Manage Daily Challenge Page
router.get('/manage-daily-challenge', adminAuth, checkPermission('dailyChallenge', 'dailyTasks', 'appConfig'), async (req, res) => {
    try {
        await connectMongo();

        let config = await DailyChallengeConfig.findOne({ key: 'dailyChallengeConfig' }).lean();
        if (!config) {
            config = await DailyChallengeConfig.create({ key: 'dailyChallengeConfig' });
            config = config.toObject ? config.toObject() : config;
        }

        // Sort tasks by displayOrder ascending
        if (config && config.tasks) {
            config.tasks.sort((a, b) => (a.displayOrder || 0) - (b.displayOrder || 0));
        }

        res.render('daily-challenge/manage', {
            config,
            admin: req.admin,
            activePage: 'daily-challenge',
            pageTitle: 'Daily Challenge Management'
        });
    } catch (err) {
        console.error('❌ Error loading Daily Challenge manage page:', err);
        res.status(500).render('error', { message: 'Internal Server Error loading Daily Challenge' });
    }
});

// 2. POST Update Overall Challenge Config
router.post('/admin/daily-challenge/update-config', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const { isActive, rewardCoins } = req.body;

        const updateData = {};
        if (typeof isActive !== 'undefined') {
            updateData.isActive = isActive === true || isActive === 'true' || isActive === 'on';
        }
        if (typeof rewardCoins !== 'undefined') {
            updateData.rewardCoins = Math.max(1, parseInt(rewardCoins, 10) || 500);
        }

        const config = await DailyChallengeConfig.findOneAndUpdate(
            { key: 'dailyChallengeConfig' },
            { $set: updateData },
            { new: true, upsert: true }
        );

        // Invalidate Redis cache
        await cacheService.del('daily_challenge_config');

        return res.json({
            success: true,
            message: 'Daily Challenge settings saved successfully!',
            config
        });
    } catch (err) {
        console.error('❌ Error updating Daily Challenge config:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to update settings: ' + (err.message || err)
        });
    }
});

const defaultIconMap = {
    play_games: 'assets/icons/plygames.png',
    super_offer: 'assets/icons/super.png',
    read_and_earn: 'assets/icons/readd.png',
    battle_arena: 'assets/icons/battles.png',
    daily_task: 'assets/icons/badge.png',
    watch_earn: 'assets/icons/watch video.png',
    watch_video: 'assets/icons/watch video.png',
    offerwall: 'assets/icons/pubscale-logo.png',
    survey: 'assets/icons/bitlabs-logo.png',
    daily_checkin: 'assets/icons/clock.png',
    diamond_catch: 'assets/icons/emoji.png',
    giveaway: 'assets/icons/givwy.png'
};

function resolveTaskIcon(taskType, icon) {
    if (icon && icon.trim() && icon !== 'assets/icons/game.png') {
        return icon.trim();
    }
    return defaultIconMap[taskType] || 'assets/icons/plygames.png';
}

// 3. POST Add New Sub-Task
router.post('/admin/daily-challenge/add-task', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const { title, description, taskType, targetCount, icon, displayOrder, isActive } = req.body;

        if (!title || !taskType) {
            return res.status(400).json({
                success: false,
                message: 'Title and Task Type are required.'
            });
        }

        const newTask = {
            taskId: new require('mongoose').Types.ObjectId().toString(),
            title: title.trim(),
            description: (description || '').trim(),
            taskType: taskType.trim(),
            targetCount: Math.max(1, parseInt(targetCount, 10) || 1),
            icon: resolveTaskIcon(taskType.trim(), icon),
            displayOrder: parseInt(displayOrder, 10) || 0,
            isActive: isActive !== false && isActive !== 'false'
        };

        const config = await DailyChallengeConfig.findOneAndUpdate(
            { key: 'dailyChallengeConfig' },
            { $push: { tasks: newTask } },
            { new: true, upsert: true }
        );

        // Invalidate Redis cache
        await cacheService.del('daily_challenge_config');

        return res.json({
            success: true,
            message: 'Task added successfully!',
            task: newTask,
            config
        });
    } catch (err) {
        console.error('❌ Error adding challenge task:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to add task: ' + (err.message || err)
        });
    }
});

// 4. POST Edit Existing Sub-Task
router.post('/admin/daily-challenge/edit-task', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const { taskId, title, description, taskType, targetCount, icon, displayOrder, isActive } = req.body;

        if (!taskId) {
            return res.status(400).json({
                success: false,
                message: 'Task ID is required.'
            });
        }

        const updateFields = {
            'tasks.$.title': title ? title.trim() : undefined,
            'tasks.$.description': typeof description !== 'undefined' ? description.trim() : undefined,
            'tasks.$.taskType': taskType ? taskType.trim() : undefined,
            'tasks.$.targetCount': typeof targetCount !== 'undefined' ? Math.max(1, parseInt(targetCount, 10) || 1) : undefined,
            'tasks.$.icon': icon && icon.trim() ? icon.trim() : (taskType ? resolveTaskIcon(taskType.trim(), '') : undefined),
            'tasks.$.displayOrder': typeof displayOrder !== 'undefined' ? parseInt(displayOrder, 10) : undefined,
            'tasks.$.isActive': typeof isActive !== 'undefined' ? (isActive === true || isActive === 'true' || isActive === 'on') : undefined
        };

        // Remove undefined fields
        Object.keys(updateFields).forEach(k => updateFields[k] === undefined && delete updateFields[k]);

        const config = await DailyChallengeConfig.findOneAndUpdate(
            { key: 'dailyChallengeConfig', 'tasks.taskId': taskId },
            { $set: updateFields },
            { new: true }
        );

        // Invalidate Redis cache
        await cacheService.del('daily_challenge_config');

        return res.json({
            success: true,
            message: 'Task updated successfully!',
            config
        });
    } catch (err) {
        console.error('❌ Error editing challenge task:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to update task: ' + (err.message || err)
        });
    }
});

// 5. POST Delete Sub-Task
router.post('/admin/daily-challenge/delete-task', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const { taskId } = req.body;
        if (!taskId) {
            return res.status(400).json({
                success: false,
                message: 'Task ID is required.'
            });
        }

        const config = await DailyChallengeConfig.findOneAndUpdate(
            { key: 'dailyChallengeConfig' },
            { $pull: { tasks: { taskId: taskId } } },
            { new: true }
        );

        // Invalidate Redis cache
        await cacheService.del('daily_challenge_config');

        return res.json({
            success: true,
            message: 'Task removed successfully!',
            config
        });
    } catch (err) {
        console.error('❌ Error deleting challenge task:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to delete task: ' + (err.message || err)
        });
    }
});

// 6. POST Reset Specific User's Daily Challenge Progress
router.post('/admin/daily-challenge/reset-user-progress', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const { userId, dateStr, resetAllDays } = req.body;
        if (!userId) {
            return res.status(400).json({
                success: false,
                message: 'User ID is required.'
            });
        }

        const UserDailyChallenge = require('../../admin/models/userDailyChallenge');

        const nowUtc = Date.now();
        const istOffsetMs = 5.5 * 60 * 60 * 1000;
        const todayDateStr = new Date(nowUtc + istOffsetMs).toISOString().split('T')[0];

        let filter = { userId: userId.trim() };
        if (!resetAllDays || resetAllDays === 'false') {
            filter.dateStr = dateStr || todayDateStr;
        }

        const deleteResult = await UserDailyChallenge.deleteMany(filter);

        return res.json({
            success: true,
            message: `Successfully reset Daily Challenge progress for user! (${deleteResult.deletedCount} record(s) reset)`,
            deletedCount: deleteResult.deletedCount
        });
    } catch (err) {
        console.error('❌ Error resetting user Daily Challenge:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to reset user daily challenge progress: ' + (err.message || err)
        });
    }
});

// 7. POST Mark Complete & Award Coins to Specific User
router.post('/admin/daily-challenge/force-complete-user', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const { userId, customCoins, dateStr } = req.body;
        if (!userId) {
            return res.status(400).json({
                success: false,
                message: 'User ID is required.'
            });
        }

        const UserDailyChallenge = require('../../admin/models/userDailyChallenge');
        const User = require('../../admin/models/user');
        const RewardHistory = require('../../admin/models/rewardHistory');

        const nowUtc = Date.now();
        const istOffsetMs = 5.5 * 60 * 60 * 1000;
        const todayDateStr = dateStr || new Date(nowUtc + istOffsetMs).toISOString().split('T')[0];

        // 1. Fetch config to know tasks & default rewardCoins
        let config = await DailyChallengeConfig.findOne({ key: 'dailyChallengeConfig' }).lean();
        const activeTasks = (config?.tasks || []).filter(t => t.isActive !== false);
        const rewardCoins = typeof customCoins !== 'undefined' && Number(customCoins) > 0
            ? Number(customCoins)
            : (Number(config?.rewardCoins) || 500);

        // 2. Prepare 100% completed progress map and task IDs
        const taskProgressMap = {};
        const completedTaskIds = [];
        activeTasks.forEach(task => {
            taskProgressMap[task.taskType] = task.targetCount;
            completedTaskIds.push(task.taskType);
        });

        // 3. Upsert UserDailyChallenge as 100% completed & claimed
        const updatedChallenge = await UserDailyChallenge.findOneAndUpdate(
            { userId: userId.trim(), dateStr: todayDateStr },
            {
                $set: {
                    taskProgress: taskProgressMap,
                    completedTasks: completedTaskIds,
                    claimedReward: true,
                    claimedAt: new Date(),
                    rewardCoinsEarned: rewardCoins
                }
            },
            { new: true, upsert: true }
        );

        // 4. Increment User wallet balance
        const cleanUid = userId.trim();
        const updatedUser = await User.findOneAndUpdate(
            { $or: [{ userId: cleanUid }, { firebaseUid: cleanUid }] },
            { $inc: { coins: rewardCoins, totalCoins: rewardCoins } },
            { new: true }
        );

        if (!updatedUser) {
            return res.status(404).json({
                success: false,
                message: `User with ID ${cleanUid} was not found in database.`
            });
        }

        // 5. Log in RewardHistory
        const orderId = `daily_challenge_${cleanUid}_${todayDateStr}`;
        try {
            await RewardHistory.updateOne(
                { orderId },
                {
                    $setOnInsert: {
                        appName: 'crazyreward',
                        userId: cleanUid,
                        provider: 'Daily Challenge',
                        coins: rewardCoins,
                        rewardType: 'coin',
                        orderId: orderId,
                        timestamp: new Date()
                    }
                },
                { upsert: true }
            );
        } catch (rhErr) {
            console.error('⚠️ Error inserting RewardHistory for Daily Challenge:', rhErr);
        }

        return res.json({
            success: true,
            message: `🎉 Successfully marked Daily Challenge complete! +${rewardCoins} Coins credited to user. (New Balance: ${updatedUser.coins})`,
            rewardCoins,
            newBalance: updatedUser.coins,
            challenge: updatedChallenge
        });
    } catch (err) {
        console.error('❌ Error force completing Daily Challenge:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to complete challenge: ' + (err.message || err)
        });
    }
});

module.exports = router;
