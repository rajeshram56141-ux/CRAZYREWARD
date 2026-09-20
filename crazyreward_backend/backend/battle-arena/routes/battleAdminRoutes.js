const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const adminAuth = require('../../admin/middlewares/adminAuth');

const BattleConfig = require('../models/battleConfig');
const QuizQuestion = require('../models/quizQuestion');
const BattleRoom = require('../models/battleRoom');
const BattleMatch = require('../models/battleMatch');
const BattleSession = require('../models/battleSession');
const BattleLeaderboard = require('../models/battleLeaderboard');
const User = require('../../admin/models/user');
const BattleBot = require('../../admin/models/battleBot');
const BattleLeaderboardHistory = require('../models/battleLeaderboardHistory');
const BattleHistory = require('../models/battleHistory');
const RewardHistory = require('../../admin/models/rewardHistory');
const { sendNotificationViaApi } = require('../../admin/middlewares/send-notification-api');
const cacheService = require('../../services/cacheService');

// Indian Standard Time (IST / Asia/Kolkata / UTC+05:30) helper functions
function toISTDateTimeLocal(date) {
    if (!date) return '';
    const d = new Date(date);
    if (isNaN(d.getTime())) return '';
    const istTime = new Date(d.getTime() + (5.5 * 60 * 60 * 1000));
    return istTime.toISOString().slice(0, 16);
}

function parseISTDate(dateStr) {
    if (!dateStr) return null;
    if (dateStr instanceof Date) return dateStr;
    const str = String(dateStr).trim();
    if (!str) return null;
    if (str.endsWith('Z') || str.includes('+')) {
        const d = new Date(str);
        return isNaN(d.getTime()) ? null : d;
    }
    const normalized = str.includes('T') ? str : str.replace(' ', 'T');
    const parts = normalized.split(':');
    const withSec = parts.length === 2 ? `${normalized}:00` : normalized;
    const d = new Date(`${withSec}+05:30`);
    return isNaN(d.getTime()) ? new Date(str) : d;
}

async function recalculateLeaderboardStandings(targetKey) {
    try {
        let configDoc = null;
        if (targetKey) {
            configDoc = await BattleConfig.findOne({ key: targetKey });
        }
        if (!configDoc) {
            configDoc = await BattleConfig.findOne({ key: { $ne: 'battleConfig' }, isActive: true });
        }
        if (!configDoc) {
            configDoc = await BattleConfig.findOne({ key: 'battleConfig', isActive: true });
        }

        if (!configDoc) {
            return;
        }

        const cycleId = configDoc.key;
        const startTime = configDoc.startTime ? new Date(configDoc.startTime) : new Date(0);
        const resultTime = configDoc.nextPayoutTime ? new Date(configDoc.nextPayoutTime) : new Date(Date.now() + 86400000 * 365);

        const completedMatches = await BattleMatch.find({
            entryType: 'Free',
            status: 'COMPLETED',
            createdAt: { $gte: startTime, $lte: resultTime }
        }).lean();

        await BattleLeaderboard.deleteMany({ cycleId });

        for (const match of completedMatches) {
            const sortedPlayers = match.players || [];
            const winnerUid = match.winnerUserId;

            for (const p of sortedPlayers) {
                if (!p || !p.userId) continue;
                const isWinner = p.userId === winnerUid;

                let userName = p.userName;
                let avatar = p.avatar;

                if (!p.userId.startsWith('bot_') && p.userId !== 'ai_bot_opponent') {
                    const u = await User.findOne({ userId: p.userId }).lean();
                    if (u) {
                        userName = u.displayName || u.name || u.username || 'Player';
                        avatar = u.photoUrl || u.avatar || '';
                    }
                }

                await BattleLeaderboard.findOneAndUpdate(
                    { cycleId, userId: p.userId },
                    {
                        $inc: {
                            winsCount: isWinner ? 1 : 0,
                            totalSpeedPoints: Number(p.speedScore) || 0,
                            totalMatchesPlayed: 1
                        },
                        $set: {
                            userName: userName || 'Player',
                            avatar: avatar || '',
                            lastMatchAt: match.createdAt || new Date()
                        }
                    },
                    { upsert: true, new: true }
                );
            }
        }
    } catch (e) {
        console.error('Error recalculating leaderboard standings:', e);
    }
}

async function autoSeedBattleArenaData() {
    try {
        let config = await BattleConfig.findOne({ key: 'battleConfig' });
        if (!config) {
            config = await BattleConfig.create({ key: 'battleConfig' });
        }

        // Clean up any default / auto-generated cycle configs from previous versions
        await BattleConfig.deleteMany({ key: { $in: ['battleConfig_1', 'battleConfig_7', 'battleConfig_30'] } });

        // If main battleConfig has the old default 5 tiers, clear them
        if (config && Array.isArray(config.rewardTiers) && config.rewardTiers.length === 5 && config.rewardTiers[0].coins === 5000 && !config.rewardTiers[0].customText) {
            config.rewardTiers = [];
            await config.save();
        }

        // If already seeded initially, do not re-seed when admin deletes rooms or questions
        if (config.initialSeeded) {
            return;
        }

        const questionCount = await QuizQuestion.countDocuments();
        if (questionCount === 0) {
            await QuizQuestion.insertMany([
                { questionId: 'q_1', gameTitle: 'Math Speed Clash', category: 'Math Speed', question: 'What is 15 + 27?', options: ['42', '40', '45', '38'], correctIndex: 0, timeLimitSec: 20 },
                { questionId: 'q_2', gameTitle: 'General Knowledge Arena', category: 'General Knowledge', question: 'What is the capital of France?', options: ['Berlin', 'London', 'Paris', 'Madrid'], correctIndex: 2, timeLimitSec: 20 },
                { questionId: 'q_3', gameTitle: 'Math Speed Clash', category: 'Math Speed', question: 'What is 12 x 8?', options: ['86', '96', '104', '88'], correctIndex: 1, timeLimitSec: 20 },
                { questionId: 'q_4', gameTitle: 'General Knowledge Arena', category: 'General Knowledge', question: 'Which planet is known as the Red Planet?', options: ['Venus', 'Mars', 'Jupiter', 'Saturn'], correctIndex: 1, timeLimitSec: 20 },
                { questionId: 'q_5', gameTitle: 'Math Speed Clash', category: 'Math Speed', question: 'What is 100 - 37?', options: ['63', '73', '53', '67'], correctIndex: 0, timeLimitSec: 20 },
                { questionId: 'q_6', gameTitle: 'Math Speed Clash', category: 'Math Speed', question: 'How many sides does a hexagon have?', options: ['5', '6', '7', '8'], correctIndex: 1, timeLimitSec: 20 },
                { questionId: 'q_7', gameTitle: 'Math Speed Clash', category: 'Math Speed', question: 'What is 7 x 7?', options: ['42', '48', '49', '56'], correctIndex: 2, timeLimitSec: 20 },
                { questionId: 'q_8', gameTitle: 'General Knowledge Arena', category: 'General Knowledge', question: 'Which gas do plants absorb during photosynthesis?', options: ['Oxygen', 'Carbon Dioxide', 'Nitrogen', 'Hydrogen'], correctIndex: 1, timeLimitSec: 20 },
                { questionId: 'q_9', gameTitle: 'Math Speed Clash', category: 'Math Speed', question: 'What is 144 / 12?', options: ['10', '11', '12', '14'], correctIndex: 2, timeLimitSec: 20 },
                { questionId: 'q_10', gameTitle: 'Math Speed Clash', category: 'Math Speed', question: 'What is the square root of 64?', options: ['6', '7', '8', '9'], correctIndex: 2, timeLimitSec: 20 }
            ]);
        }

        const roomCount = await BattleRoom.countDocuments();
        if (roomCount === 0) {
            await BattleRoom.insertMany([
                { roomId: 'room_1', title: '1v1 Math & Speed Clash', capacity: 2, entryType: 'Paid', entryFeeCoins: 100, platformCutPercent: 10, netPrizePoolCoins: 180, questionCount: 7, timePerQuestionSec: 20, category: 'Math Speed', assignedGameTitle: 'Math Speed Clash', badge: 'HOT', autoRepeatIntervalMinutes: 2, nextStartTime: new Date(Date.now() + 2 * 60 * 1000), status: 'Active' },
                { roomId: 'room_2', title: 'High Stakes Diamond Arena', capacity: 2, entryType: 'Paid', entryFeeCoins: 500, platformCutPercent: 10, netPrizePoolCoins: 900, questionCount: 7, timePerQuestionSec: 20, category: 'General Knowledge', assignedGameTitle: 'General Knowledge Arena', badge: 'PRO', autoRepeatIntervalMinutes: 5, nextStartTime: new Date(Date.now() + 5 * 60 * 1000), status: 'Active' },
                { roomId: 'room_3', title: 'Free Rewarded Battle', capacity: 2, entryType: 'Free', entryFeeCoins: 0, platformCutPercent: 0, netPrizePoolCoins: 50, questionCount: 7, timePerQuestionSec: 20, category: 'General Knowledge', assignedGameTitle: 'General Knowledge Arena', badge: 'FREE', autoRepeatIntervalMinutes: 2, nextStartTime: new Date(Date.now() + 2 * 60 * 1000), status: 'Active' }
            ]);
        }

        config.initialSeeded = true;
        await config.save();
    } catch (e) {
        console.error('Auto seed battle arena error:', e);
    }
}

// 1. Battle Config
router.get('/config', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        await autoSeedBattleArenaData();

        let dailyConfig = await BattleConfig.findOne({ key: 'battleConfig_1' }).lean() || {};
        let weeklyConfig = await BattleConfig.findOne({ key: 'battleConfig_7' }).lean() || {};
        let monthlyConfig = await BattleConfig.findOne({ key: 'battleConfig_30' }).lean() || {};

        let config = await BattleConfig.findOne({ key: 'battleConfig' }).lean();
        if (!config) {
            config = await BattleConfig.create({ key: 'battleConfig' });
            config = config.toObject ? config.toObject() : config;
        }

        const formatTimes = (c) => {
            if (c) {
                if (c.nextPayoutTime) {
                    c.nextPayoutTimeFormatted = toISTDateTimeLocal(c.nextPayoutTime);
                }
                if (c.startTime) {
                    c.startTimeFormatted = toISTDateTimeLocal(c.startTime);
                }
            }
        };

        formatTimes(dailyConfig);
        formatTimes(weeklyConfig);
        formatTimes(monthlyConfig);
        formatTimes(config);

        res.render('battle-arena/config', {
            admin: req.admin,
            config: config,
            dailyConfig: dailyConfig,
            weeklyConfig: weeklyConfig,
            monthlyConfig: monthlyConfig,
            activePage: 'battle-config'
        });
    } catch (err) {
        console.error('Battle config page error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/config/save', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const {
            isActive,
            botWinRate,
            cycleDays,
            platformCommissionFee,
            freeRoomAdMandate,
            battleInstallTaskCount,
            battleDailyLimit,
            antiCheatStrictMode,
            autoRewardProcess,
            startTime,
            nextPayoutTime,
            showWinnersOnly,
            tier_1,
            tier_2,
            tier_3,
            tier_4_10,
            tier_11_50,
            term_title,
            term_desc,
            rewardTiers,
            installTaskMb,
            installTaskUsageSeconds,
            correctPoints,
            wrongPoints,
            maxBonusPoints,
            allowBonusCoins,
            bonusUsagePercent,
            freeTermsJson,
            paidTermsJson
        } = req.body;

        let parsedRewardTiers = [];
        if (Array.isArray(rewardTiers) && rewardTiers.length > 0) {
            parsedRewardTiers = rewardTiers.map(t => {
                let rStart = 1, rEnd = 1;
                if (typeof t.range === 'string') {
                    const parts = t.range.split('-').map(p => parseInt(p.trim()));
                    if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
                        rStart = parts[0];
                        rEnd = parts[1];
                    } else if (parts.length === 1 && !isNaN(parts[0])) {
                        rStart = parts[0];
                        rEnd = parts[0];
                    }
                } else {
                    rStart = Number(t.rankStart) || 1;
                    rEnd = Number(t.rankEnd) || 1;
                }
                return {
                    rankStart: rStart,
                    rankEnd: rEnd,
                    coins: Number(t.coins) || 0,
                    iconUrl: t.iconUrl ? String(t.iconUrl).trim() : '',
                    customText: t.customText ? String(t.customText).trim() : ''
                };
            });
        }

        const updateData = {};
        if (parsedRewardTiers.length > 0) updateData.rewardTiers = parsedRewardTiers;
        if (typeof isActive !== 'undefined') updateData.isActive = isActive === true || isActive === 'true';
        if (typeof botWinRate !== 'undefined') updateData.botWinRate = Number(botWinRate) === 0 ? 0 : (Number(botWinRate) || 50);
        if (typeof cycleDays !== 'undefined') updateData.cycleDays = Number(cycleDays) || 7;
        if (typeof platformCommissionFee !== 'undefined') updateData.platformCommissionFee = Number(platformCommissionFee) || 10;
        if (typeof freeRoomAdMandate !== 'undefined') updateData.freeRoomAdMandate = freeRoomAdMandate === true || freeRoomAdMandate === 'true';
        if (typeof battleInstallTaskCount !== 'undefined') updateData.battleInstallTaskCount = String(battleInstallTaskCount).trim() || '0';
        if (typeof battleDailyLimit !== 'undefined') updateData.battleDailyLimit = String(battleDailyLimit).trim() || '0';
        if (typeof antiCheatStrictMode !== 'undefined') updateData.antiCheatStrictMode = antiCheatStrictMode === true || antiCheatStrictMode === 'true';
        if (typeof autoRewardProcess !== 'undefined') updateData.autoRewardProcess = autoRewardProcess === true || autoRewardProcess === 'true';
        if (startTime) updateData.startTime = parseISTDate(startTime);
        if (nextPayoutTime) updateData.nextPayoutTime = parseISTDate(nextPayoutTime);
        if (typeof showWinnersOnly !== 'undefined') updateData.showWinnersOnly = showWinnersOnly === true || showWinnersOnly === 'true';
        if (typeof installTaskMb !== 'undefined') updateData.installTaskMb = Number(installTaskMb) || 15;
        if (typeof installTaskUsageSeconds !== 'undefined') updateData.installTaskUsageSeconds = Number(installTaskUsageSeconds) || 30;
        if (typeof correctPoints !== 'undefined') updateData.correctPoints = Number(correctPoints) || 100;
        if (typeof wrongPoints !== 'undefined') updateData.wrongPoints = Number(wrongPoints) || -100;
        if (typeof maxBonusPoints !== 'undefined') updateData.maxBonusPoints = Number(maxBonusPoints) || 100;
        if (typeof allowBonusCoins !== 'undefined') updateData.allowBonusCoins = allowBonusCoins === true || allowBonusCoins === 'true';
        if (typeof bonusUsagePercent !== 'undefined') updateData.bonusUsagePercent = Math.max(0, Math.min(100, Number(bonusUsagePercent) || 0));
        if (typeof freeTermsJson !== 'undefined') {
            try {
                updateData.freeTerms = JSON.parse(freeTermsJson);
            } catch (e) {
                return res.status(400).json({ success: false, message: 'Invalid JSON format in Free Terms' });
            }
        }
        if (typeof paidTermsJson !== 'undefined') {
            try {
                updateData.paidTerms = JSON.parse(paidTermsJson);
            } catch (e) {
                return res.status(400).json({ success: false, message: 'Invalid JSON format in Paid Terms' });
            }
        }

        const targetKey = cycleDays ? `battleConfig_${cycleDays}` : 'battleConfig';
        const updatedConfig = await BattleConfig.findOneAndUpdate(
            { key: targetKey },
            updateData,
            { upsert: true, new: true }
        );

        if (!cycleDays) {
            await BattleConfig.findOneAndUpdate(
                { key: 'battleConfig' },
                updateData,
                { upsert: true, new: true }
            );
        }

        await cacheService.del('battle:active_rooms');

        if (req.xhr || (req.headers['accept'] && req.headers['accept'].includes('json')) || (req.headers['content-type'] && req.headers['content-type'].includes('json'))) {
            return res.json({ success: true, message: 'Config saved successfully', config: updatedConfig });
        }

        res.redirect('/admin/battle-arena/config?saved=1');
    } catch (err) {
        console.error('Battle config save error:', err);
        res.status(500).send('Internal Server Error');
    }
});

// 2. Battle Game (Quiz Bank)
router.get('/quiz-bank', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        await autoSeedBattleArenaData();
        const questions = await QuizQuestion.find().sort({ createdAt: -1 }).lean();
        res.render('battle-arena/quiz-bank', {
            admin: req.admin,
            questions: questions,
            activePage: 'battle-game'
        });
    } catch (err) {
        console.error('Battle quiz-bank error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/quiz-bank/add', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { gameTitle, category, question, opt1, opt2, opt3, opt4, correctIndex, timeLimitSec } = req.body;
        const questionId = `q_${Date.now()}_${Math.floor(Math.random() * 899 + 100)}`;

        await QuizQuestion.create({
            questionId,
            gameTitle: gameTitle || 'General Quiz Clash',
            category: category || 'General Knowledge',
            question,
            options: [opt1, opt2, opt3, opt4],
            correctIndex: Number(correctIndex) || 0,
            timeLimitSec: Number(timeLimitSec) || 20
        });

        try { await cacheService.delPattern('quiz:*'); } catch (_) {}

        res.redirect('/admin/battle-arena/quiz-bank');
    } catch (err) {
        console.error('Add quiz question error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/quiz-bank/bulk-upload', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const jsonStr = req.body.jsonContent || '[]';
        const parsed = JSON.parse(jsonStr);
        if (Array.isArray(parsed)) {
            for (const item of parsed) {
                const questionId = `q_${Date.now()}_${Math.floor(Math.random() * 8999 + 1000)}`;
                await QuizQuestion.create({
                    questionId,
                    gameTitle: item.gameTitle || 'General Quiz Clash',
                    category: item.category || 'General Knowledge',
                    question: item.question,
                    options: item.options || [],
                    correctIndex: Number(item.correctIndex) || 0,
                    timeLimitSec: Number(item.timeLimitSec) || 20
                });
            }
            try { await cacheService.delPattern('quiz:*'); } catch (_) {}
        }
        res.redirect('/admin/battle-arena/quiz-bank');
    } catch (err) {
        console.error('Bulk upload quiz error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.all('/quiz-bank/delete/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const id = req.params.id;
        if (id.startsWith('q_')) {
            await QuizQuestion.deleteOne({ questionId: id });
        } else {
            await QuizQuestion.findByIdAndDelete(id);
        }
        try { await cacheService.delPattern('quiz:*'); } catch (_) {}
        res.redirect('/admin/battle-arena/quiz-bank');
    } catch (err) {
        console.error('Delete quiz error:', err);
        res.redirect('/admin/battle-arena/quiz-bank');
    }
});

// 3. Battle Create (Rooms)
router.get('/rooms', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        await autoSeedBattleArenaData();

        const rooms = await BattleRoom.find().sort({ createdAt: -1 }).lean();
        const rawGames = await QuizQuestion.distinct('gameTitle');
        const availableGames = (rawGames && rawGames.length) ? rawGames : ['Math Speed Clash', 'General Knowledge Arena'];

        const activeRoomsCount = await BattleRoom.countDocuments({ status: 'Active' });
        const liveMatchesCount = await BattleMatch.countDocuments({ matchStatus: 'PLAYING' });

        const startOfDay = new Date();
        startOfDay.setHours(0, 0, 0, 0);
        const completedMatchesToday = await BattleMatch.countDocuments({ matchStatus: 'FINISHED', createdAt: { $gte: startOfDay } });

        const revAgg = await BattleMatch.aggregate([
            { $group: { _id: null, total: { $sum: '$platformFeeEarned' } } }
        ]);
        const totalRevenueCoins = (revAgg[0] && revAgg[0].total) ? revAgg[0].total : 0;

        res.render('battle-arena/rooms', {
            admin: req.admin,
            rooms: rooms,
            availableGames: availableGames,
            stats: {
                activeRoomsCount,
                liveMatchesCount,
                completedMatchesToday,
                totalRevenueCoins
            },
            activePage: 'battle-create'
        });
    } catch (err) {
        console.error('Battle rooms error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/rooms/create', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { title, subtitle, description, capacity, entryType, entryFeeCoins, platformCutPercent, questionCount, timePerQuestionSec, category, assignedGameTitle, autoRepeatIntervalMinutes, matchingTimeoutSec, enableAiBot, rankRewardsJson, adType, skipAdMatches } = req.body;

        let rankRewards = [];
        try {
            if (rankRewardsJson) {
                rankRewards = JSON.parse(rankRewardsJson);
            }
        } catch (e) {
            console.error('Failed to parse rankRewardsJson:', e);
        }

        let fee = Number(entryFeeCoins) || 100;
        let cut = Number(platformCutPercent) || 10;
        if (entryType === 'Free') {
            fee = 0;
            cut = 0;
        }
        const cap = Number(capacity) || 2;
        const totalCollected = fee * cap;
        let netPrize = entryType === 'Paid' ? Math.round(totalCollected * (1 - (cut / 100))) : 0;
        if (rankRewards && rankRewards.length > 0) {
            netPrize = rankRewards.reduce((sum, item) => sum + (Number(item.coins) || 0), 0);
        }
        const repeatIntervalMin = Number(autoRepeatIntervalMinutes) || 2;
        const nextStart = new Date(Date.now() + repeatIntervalMin * 60 * 1000);

        const roomSubtitle = String(subtitle || description || '1v1 Quiz Battle Clash').trim();

        const roomId = `room_${Date.now()}`;
        await BattleRoom.create({
            roomId,
            title,
            subtitle: roomSubtitle,
            capacity: cap,
            entryType: entryType || 'Paid',
            entryFeeCoins: fee,
            platformCutPercent: cut,
            netPrizePoolCoins: netPrize,
            rankRewards,
            questionCount: Number(questionCount) || 7,
            timePerQuestionSec: Number(timePerQuestionSec) || 20,
            category: category || 'General Knowledge',
            assignedGameTitle: assignedGameTitle || 'General Quiz Clash',
            autoRepeatIntervalMinutes: repeatIntervalMin,
            matchingTimeoutSec: Number(matchingTimeoutSec) || 35,
            enableAiBot: enableAiBot === 'true' || enableAiBot === true,
            adType: adType || 'None',
            skipAdMatches: Math.max(0, parseInt(skipAdMatches, 10) || 0),
            nextStartTime: nextStart
        });

        await cacheService.del('battle:active_rooms');

        res.redirect('/admin/battle-arena/rooms');
    } catch (err) {
        console.error('Create battle room error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/rooms/edit/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const id = req.params.id;
        const { title, subtitle, description, capacity, entryType, entryFeeCoins, editEntryFeeCoins, platformCutPercent, editPlatformCutPercent, questionCount, timePerQuestionSec, category, assignedGameTitle, autoRepeatIntervalMinutes, matchingTimeoutSec, enableAiBot, status, rankRewardsJson, adType, skipAdMatches } = req.body;

        let rankRewards = [];
        try {
            if (rankRewardsJson) {
                rankRewards = JSON.parse(rankRewardsJson);
            }
        } catch (e) {
            console.error('Failed to parse rankRewardsJson:', e);
        }

        const finalEntryFee = entryFeeCoins !== undefined ? entryFeeCoins : editEntryFeeCoins;
        const finalCut = platformCutPercent !== undefined ? platformCutPercent : editPlatformCutPercent;
        let fee = Number(finalEntryFee) || 100;
        let cut = Number(finalCut) || 10;
        if (entryType === 'Free') {
            fee = 0;
            cut = 0;
        }
        const cap = Number(capacity) || 2;
        const totalCollected = fee * cap;
        let netPrize = entryType === 'Paid' ? Math.round(totalCollected * (1 - (cut / 100))) : 0;
        if (rankRewards && rankRewards.length > 0) {
            netPrize = rankRewards.reduce((sum, item) => sum + (Number(item.coins) || 0), 0);
        }
        const repeatIntervalMin = Number(autoRepeatIntervalMinutes) || 2;

        const roomSubtitle = typeof subtitle === 'string' && subtitle.trim().length > 0
            ? subtitle.trim()
            : (typeof description === 'string' && description.trim().length > 0
                ? description.trim()
                : '1v1 Quiz Battle Clash');

        const updateData = {
            title,
            subtitle: roomSubtitle,
            capacity: cap,
            entryType: entryType || 'Paid',
            entryFeeCoins: fee,
            platformCutPercent: cut,
            netPrizePoolCoins: netPrize,
            rankRewards,
            questionCount: Number(questionCount) || 7,
            timePerQuestionSec: Number(timePerQuestionSec) || 20,
            category: category || 'General Knowledge',
            assignedGameTitle: assignedGameTitle || 'General Quiz Clash',
            autoRepeatIntervalMinutes: repeatIntervalMin,
            matchingTimeoutSec: Number(matchingTimeoutSec) || 35,
            enableAiBot: enableAiBot === 'true' || enableAiBot === true,
            adType: adType || 'None',
            skipAdMatches: Math.max(0, parseInt(skipAdMatches, 10) || 0),
            status: status || 'Active'
        };

        if (id.startsWith('room_')) {
            await BattleRoom.findOneAndUpdate({ roomId: id }, updateData);
        } else {
            await BattleRoom.findByIdAndUpdate(id, updateData);
        }

        await cacheService.del('battle:active_rooms');

        res.redirect('/admin/battle-arena/rooms');
    } catch (err) {
        console.error('Edit room error:', err);
        res.redirect('/admin/battle-arena/rooms');
    }
});

router.all('/rooms/delete/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const id = req.params.id;
        if (id.startsWith('room_')) {
            await BattleRoom.deleteOne({ roomId: id });
        } else {
            await BattleRoom.findByIdAndDelete(id);
        }

        await cacheService.del('battle:active_rooms');

        res.redirect('/admin/battle-arena/rooms');
    } catch (err) {
        console.error('Delete room error:', err);
        res.redirect('/admin/battle-arena/rooms');
    }
});



// 4.1 Delete Battle Match
router.post('/history/delete/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { id } = req.params;

        const mongoose = require('mongoose');
        const query = mongoose.Types.ObjectId.isValid(id)
            ? { $or: [{ _id: id }, { matchId: id }] }
            : { matchId: id };

        const result = await BattleMatch.deleteOne(query);
        if (result.deletedCount > 0) {
            return res.json({ success: true, message: 'Battle match deleted successfully' });
        }
        return res.status(404).json({ success: false, message: 'Match not found' });
    } catch (err) {
        console.error('Delete battle match error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

function getCurrentCycleId() {
    // Current date in IST (UTC+05:30)
    const now = new Date(Date.now() + (5.5 * 60 * 60 * 1000));
    const year = now.getUTCFullYear();
    const startOfYear = new Date(Date.UTC(year, 0, 1));
    const pastDays = Math.floor((now.getTime() - startOfYear.getTime()) / (24 * 60 * 60 * 1000));
    const weekNumber = Math.ceil((pastDays + startOfYear.getUTCDay() + 1) / 7);
    return `cycle_${year}_w${weekNumber}`;
}

// 5. Battle Leaderboard - Management
router.get('/leaderboard', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        
        const formatTimes = (c) => {
            if (c) {
                const days = Number(c.cycleDays) || 1;
                if (c.nextPayoutTime && !isNaN(new Date(c.nextPayoutTime).getTime())) {
                    c.nextPayoutTimeFormatted = toISTDateTimeLocal(c.nextPayoutTime);
                } else {
                    c.nextPayoutTimeFormatted = toISTDateTimeLocal(new Date(Date.now() + days * 24 * 60 * 60 * 1000));
                }
                if (c.startTime && !isNaN(new Date(c.startTime).getTime())) {
                    c.startTimeFormatted = toISTDateTimeLocal(c.startTime);
                } else {
                    c.startTimeFormatted = toISTDateTimeLocal(new Date(Date.now() - days * 24 * 60 * 60 * 1000));
                }
                c.autoReschedule = c.autoReschedule !== false;
                
                let durationStr = `${days} Days`;
                if (c.startTime && c.nextPayoutTime) {
                    const diffMs = new Date(c.nextPayoutTime).getTime() - new Date(c.startTime).getTime();
                    if (diffMs > 0) {
                        const totalHours = Math.round(diffMs / (1000 * 60 * 60));
                        if (totalHours >= 24) {
                            const d = Math.round(totalHours / 24);
                            durationStr = `${d} ${d === 1 ? 'Day' : 'Days'}`;
                        } else {
                            durationStr = `${totalHours} ${totalHours === 1 ? 'Hour' : 'Hours'}`;
                        }
                    }
                }
                c.durationStr = durationStr;
            }
            return c;
        };

        // All created leaderboards
        let allCycleConfigs = await BattleConfig.find({ key: { $ne: 'battleConfig' } }).sort({ createdAt: -1 }).lean();
        if (!allCycleConfigs) allCycleConfigs = [];
        allCycleConfigs = allCycleConfigs.map(c => formatTimes(c));

        // Determine currently active or selected leaderboard
        const selectedLbKey = String(req.query.lbId || '').trim();
        let activeLbConfig = selectedLbKey ? allCycleConfigs.find(c => c.key === selectedLbKey) : null;
        if (!activeLbConfig && allCycleConfigs.length > 0) {
            activeLbConfig = allCycleConfigs.find(c => c.isActive) || allCycleConfigs[0];
        }

        const currentCycleId = activeLbConfig ? activeLbConfig.key : '';
        let config = activeLbConfig || (await BattleConfig.findOne({ key: 'battleConfig' }).lean()) || {};

        // Fetch Standings for the selected leaderboard ID
        const isShowWinnersOnly = config.showWinnersOnly === true;
        const isPointsBased = config.rankingBasis === 'points';
        const queryFilter = { cycleId: currentCycleId };
        if (isShowWinnersOnly) {
            if (isPointsBased) {
                queryFilter.totalSpeedPoints = { $gt: 0 };
            } else {
                queryFilter.winsCount = { $gt: 0 };
            }
        }
        const sortOption = isPointsBased
            ? { totalSpeedPoints: -1, winsCount: -1, lastMatchAt: 1 }
            : { winsCount: -1, totalSpeedPoints: -1, lastMatchAt: 1 };

        const rawStandings = await BattleLeaderboard.find(queryFilter).sort(sortOption).lean();
        const userIds = rawStandings.map(s => s.userId);
        const users = await User.find({ userId: { $in: userIds } }, { userId: 1, isLeaderboardBanned: 1 }).lean();
        const banMap = {};
        users.forEach(u => {
            banMap[u.userId] = !!u.isLeaderboardBanned;
        });

        const standings = rawStandings.map(s => ({
            ...s,
            isBanned: !!banMap[s.userId]
        }));

        // Historical Records
        const history = await BattleLeaderboardHistory.find().sort({ periodEnd: -1 }).lean();

        res.render('battle-arena/leaderboard', {
            admin: req.admin,
            standings,
            history,
            config,
            activeLbConfig,
            allCycleConfigs,
            cycleId: currentCycleId,
            selectedLbId: currentCycleId,
            activePage: 'battle-leaderboard'
        });
    } catch (err) {
        console.error('Battle leaderboard error:', err);
        res.status(500).send('Internal Server Error');
    }
});

// 5.0 Save / Create Leaderboard Configuration
router.post('/leaderboard/cycle/save', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const {
            configKey,
            title,
            cycleType,
            rankingBasis,
            cycleDays,
            isActive,
            autoReschedule,
            autoRewardProcess,
            startTime,
            nextPayoutTime,
            showWinnersOnly,
            rewardTiersJson
        } = req.body;

        const parsedStartTime = parseISTDate(startTime);
        const parsedPayoutTime = parseISTDate(nextPayoutTime);

        let calculatedDays = Number(cycleDays) || 7;
        if (parsedStartTime && parsedPayoutTime) {
            const diffMs = parsedPayoutTime.getTime() - parsedStartTime.getTime();
            if (diffMs > 0) {
                calculatedDays = Math.max(1, Math.round(diffMs / (24 * 60 * 60 * 1000)));
            }
        }

        const cType = cycleType || (calculatedDays === 1 ? 'Daily' : (calculatedDays === 30 ? 'Monthly' : 'Weekly'));
        const lbTitle = (title || '').trim() || 'Leaderboard';

        let key = configKey ? String(configKey).trim() : '';
        if (!key || key === 'battleConfig') {
            key = `lb_${Date.now()}`;
        }

        const isCurrentlyActive = isActive === 'true' || isActive === true;

        // If this leaderboard is enabled, disable other leaderboards
        if (isCurrentlyActive) {
            await BattleConfig.updateMany({ key: { $ne: key } }, { $set: { isActive: false } });
        }

        let rewardTiers = [];
        if (rewardTiersJson) {
            try {
                const parsed = typeof rewardTiersJson === 'string' ? JSON.parse(rewardTiersJson) : rewardTiersJson;
                if (Array.isArray(parsed)) {
                    rewardTiers = parsed.map(t => {
                        let rankStart = 1, rankEnd = 1;
                        if (t.range !== undefined && String(t.range).includes('-')) {
                            const parts = String(t.range).split('-');
                            rankStart = parseInt(parts[0], 10) || 1;
                            rankEnd = parseInt(parts[1], 10) || rankStart;
                        } else if (t.range !== undefined) {
                            rankStart = parseInt(t.range, 10) || 1;
                            rankEnd = rankStart;
                        } else {
                            rankStart = parseInt(t.rankStart, 10) || 1;
                            rankEnd = parseInt(t.rankEnd !== undefined ? t.rankEnd : rankStart, 10) || rankStart;
                        }
                        return {
                            rankStart,
                            rankEnd,
                            coins: Number(t.coins) || 0,
                            iconUrl: t.iconUrl ? String(t.iconUrl).trim() : '',
                            customText: t.customText ? String(t.customText).trim() : ''
                        };
                    });
                }
            } catch (e) {
                console.error('Failed to parse rewardTiersJson:', e);
            }
        }

        const isAutoReschedule = autoReschedule === 'true' || autoReschedule === true || autoReschedule === undefined;

        const updateData = {
            key,
            leaderboardId: key,
            title: lbTitle,
            cycleType: cType,
            rankingBasis: (rankingBasis === 'points') ? 'points' : 'wins',
            cycleDays: calculatedDays,
            isActive: isCurrentlyActive,
            autoReschedule: isAutoReschedule,
            autoRewardProcess: autoRewardProcess === 'true' || autoRewardProcess === true,
            showWinnersOnly: showWinnersOnly === 'true' || showWinnersOnly === true,
            startTime: parsedStartTime || new Date(Date.now() - calculatedDays * 24 * 60 * 60 * 1000),
            nextPayoutTime: parsedPayoutTime || new Date(Date.now() + calculatedDays * 24 * 60 * 60 * 1000)
        };

        if (rewardTiers && rewardTiers.length > 0) {
            updateData.rewardTiers = rewardTiers;
        }

        const updated = await BattleConfig.findOneAndUpdate(
            { key },
            { $set: updateData },
            { upsert: true, new: true }
        );

        // Synchronize with global battleConfig if active
        if (isCurrentlyActive) {
            await BattleConfig.findOneAndUpdate(
                { key: 'battleConfig' },
                { $set: {
                    leaderboardId: key,
                    title: lbTitle,
                    isActive: true,
                    rewardTiers: updateData.rewardTiers || undefined,
                    nextPayoutTime: updateData.nextPayoutTime,
                    startTime: updateData.startTime,
                    autoReschedule: updateData.autoReschedule,
                    autoRewardProcess: updateData.autoRewardProcess,
                    showWinnersOnly: updateData.showWinnersOnly,
                    cycleDays: updateData.cycleDays,
                    cycleType: updateData.cycleType,
                    rankingBasis: updateData.rankingBasis
                } },
                { upsert: true }
            );
        }

        // Recalculate and sync standings strictly between the new startTime and nextPayoutTime
        await recalculateLeaderboardStandings(key);

        // Send Broadcast Notification if a brand new active leaderboard was created
        if (!configKey && isCurrentlyActive) {
            sendNotificationViaApi({
                title: '🔥 New Battle Tournament is Live!',
                body: `"${lbTitle}" has started! Play free battle games now to score points and win prize coins! 🪙`
            }).catch(e => console.error('New tournament notification error:', e.message));
        }

        await cacheService.delPattern('battle:leaderboard*');

        if (req.xhr || (req.headers['accept'] && req.headers['accept'].includes('json')) || (req.headers['content-type'] && req.headers['content-type'].includes('json'))) {
            return res.json({ success: true, message: 'Leaderboard saved successfully', config: updated });
        }

        res.redirect('/admin/battle-arena/leaderboard?tab=cycle-settings');
    } catch (err) {
        console.error('Save leaderboard error:', err);
        if (req.xhr || (req.headers['accept'] && req.headers['accept'].includes('json'))) {
            return res.status(500).json({ success: false, message: 'Internal Server Error' });
        }
        res.redirect('/admin/battle-arena/leaderboard?tab=cycle-settings');
    }
});

// 5.0.1 Delete Leaderboard Configuration
router.post('/leaderboard/cycle/delete/:key', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const key = req.params.key;
        if (key && key !== 'battleConfig') {
            await BattleConfig.deleteOne({ key });
            await BattleLeaderboard.deleteMany({ cycleId: key });
            const hasAnyActive = await BattleConfig.findOne({ key: { $ne: 'battleConfig' }, isActive: true });
            await BattleConfig.findOneAndUpdate(
                { key: 'battleConfig' },
                { $set: { isActive: !!hasAnyActive } }
            );
        }
        await cacheService.delPattern('battle:leaderboard*');
        res.redirect('/admin/battle-arena/leaderboard?tab=cycle-settings');
    } catch (err) {
        console.error('Delete leaderboard error:', err);
        res.redirect('/admin/battle-arena/leaderboard?tab=cycle-settings');
    }
});

// 5.0.1b Delete ALL Leaderboards and Standings
router.post('/leaderboard/cycle/delete-all', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        await BattleConfig.deleteMany({ key: { $ne: 'battleConfig' } });
        await BattleLeaderboard.deleteMany({});
        await BattleConfig.findOneAndUpdate(
            { key: 'battleConfig' },
            { $set: { isActive: false, rewardTiers: [] } }
        );
        await cacheService.delPattern('battle:leaderboard*');
        res.redirect('/admin/battle-arena/leaderboard?tab=cycle-settings');
    } catch (err) {
        console.error('Delete all leaderboards error:', err);
        res.redirect('/admin/battle-arena/leaderboard?tab=cycle-settings');
    }
});

// 5.0.1c Reset Standings for a Cycle
router.post('/leaderboard/standings/reset/:key', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const key = req.params.key;
        if (key) {
            await BattleLeaderboard.deleteMany({ cycleId: key });
        }
        await cacheService.delPattern('battle:leaderboard*');
        res.redirect('/admin/battle-arena/leaderboard');
    } catch (err) {
        console.error('Reset standings error:', err);
        res.redirect('/admin/battle-arena/leaderboard');
    }
});

// 5.0.2 Toggle Leaderboard Active Status
router.post('/leaderboard/cycle/toggle/:key', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const key = req.params.key;
        const config = await BattleConfig.findOne({ key });
        if (config) {
            const nextActive = !config.isActive;
            if (nextActive) {
                await BattleConfig.updateMany({ key: { $ne: key } }, { $set: { isActive: false } });
                config.isActive = true;
                await config.save();
                await BattleConfig.findOneAndUpdate(
                    { key: 'battleConfig' },
                    { $set: {
                        leaderboardId: key,
                        title: config.title,
                        isActive: true,
                        rewardTiers: config.rewardTiers,
                        nextPayoutTime: config.nextPayoutTime,
                        startTime: config.startTime,
                        autoReschedule: config.autoReschedule !== false,
                        autoRewardProcess: config.autoRewardProcess,
                        showWinnersOnly: config.showWinnersOnly,
                        cycleDays: config.cycleDays,
                        cycleType: config.cycleType
                    } },
                    { upsert: true }
                );
            } else {
                config.isActive = false;
                await config.save();
                const anyActive = await BattleConfig.findOne({ key: { $ne: 'battleConfig' }, isActive: true });
                await BattleConfig.findOneAndUpdate(
                    { key: 'battleConfig' },
                    { $set: { isActive: !!anyActive } }
                );
            }
        }
        res.redirect('/admin/battle-arena/leaderboard?tab=cycle-settings');
    } catch (err) {
        console.error('Toggle leaderboard error:', err);
        res.redirect('/admin/battle-arena/leaderboard?tab=cycle-settings');
    }
});

// 5.0.3 Fetch User Match History for a Leaderboard Cycle (Admin Popup)
router.get('/leaderboard/user-matches/:cycleId/:userId', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { cycleId, userId } = req.params;

        let startTime = null;
        let resultTime = null;
        let historySnapshotWinner = null;

        // 1. Check if cycleId matches historical records
        const history = await BattleLeaderboardHistory.findOne({ cycleId }).lean();
        const battleHist = await BattleHistory.findOne({ cycleId }).lean();

        if (battleHist && battleHist.startTime) {
            startTime = new Date(battleHist.startTime);
            resultTime = battleHist.nextPayoutTime ? new Date(battleHist.nextPayoutTime) : (battleHist.resultDeclaredAt ? new Date(battleHist.resultDeclaredAt) : new Date());
            if (battleHist.winners) {
                historySnapshotWinner = battleHist.winners.find(w => String(w.userId) === String(userId));
            }
        } else if (history && history.periodEnd) {
            resultTime = new Date(history.periodEnd);
            startTime = new Date(resultTime.getTime() - 7 * 86400000);
            if (history.standingsSnapshot) {
                historySnapshotWinner = history.standingsSnapshot.find(w => String(w.userId) === String(userId));
            }
        } else {
            const config = await BattleConfig.findOne({ key: cycleId }) || await BattleConfig.findOne({ key: 'battleConfig' });
            startTime = config && config.startTime ? new Date(config.startTime) : new Date(0);
            resultTime = config && config.nextPayoutTime ? new Date(config.nextPayoutTime) : new Date(Date.now() + 86400000 * 365);
        }

        const matchQuery = {
            entryType: 'Free',
            status: 'COMPLETED',
            'players.userId': userId
        };
        if (startTime && resultTime) {
            matchQuery.createdAt = { $gte: startTime, $lte: resultTime };
        }

        const matches = await BattleMatch.find(matchQuery).sort({ createdAt: -1 }).lean();

        const matchHistory = matches.map(m => {
            const myPlayer = (m.players || []).find(p => p.userId === userId);
            const opponent = (m.players || []).find(p => p.userId !== userId);
            const isWinner = m.winnerUserId === userId;
            const isTie = !m.winnerUserId;

            return {
                matchId: m.matchId,
                playedAt: m.createdAt,
                entryType: m.entryType,
                winnerUserId: m.winnerUserId,
                isWinner,
                isTie,
                myStats: {
                    score: myPlayer ? myPlayer.speedScore : 0,
                    timeSec: myPlayer ? myPlayer.totalTimeTakenSec : 0,
                    correct: myPlayer ? myPlayer.correctCount : 0,
                    wrong: myPlayer ? myPlayer.wrongCount : 0
                },
                opponentStats: {
                    name: opponent ? (opponent.userName || 'Opponent') : 'Opponent',
                    userId: opponent ? opponent.userId : '',
                    isBot: opponent ? (opponent.userId.startsWith('bot_') || opponent.userId === 'ai_bot_opponent') : false,
                    score: opponent ? opponent.speedScore : 0,
                    timeSec: opponent ? opponent.totalTimeTakenSec : 0
                }
            };
        });

        const user = await User.findOne({ userId }).lean();
        const standing = await BattleLeaderboard.findOne({ cycleId, userId }).lean();

        res.json({
            success: true,
            user: {
                userId,
                name: (historySnapshotWinner && historySnapshotWinner.userName) || (standing && standing.userName) || (user ? (user.displayName || user.name || user.username) : '') || 'Player',
                avatar: (historySnapshotWinner && historySnapshotWinner.avatar) || (standing && standing.avatar) || (user ? (user.photoUrl || user.avatar) : '') || '',
                email: user ? user.email : '',
                totalWins: (historySnapshotWinner && historySnapshotWinner.winsCount !== undefined) ? historySnapshotWinner.winsCount : (standing ? standing.winsCount : matchHistory.filter(m => m.isWinner).length),
                totalSpeedPoints: (historySnapshotWinner && historySnapshotWinner.totalSpeedPoints !== undefined) ? historySnapshotWinner.totalSpeedPoints : (standing ? standing.totalSpeedPoints : matchHistory.reduce((acc, m) => acc + (m.myStats.score || 0), 0)),
                totalMatchesPlayed: matchHistory.length
            },
            matches: matchHistory
        });
    } catch (err) {
        console.error('Error fetching user match history:', err);
        res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 5.1 Ban/Unban user from Leaderboard
router.post('/leaderboard/ban/:userId', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { userId } = req.params;
        const { ban } = req.body; // 'true' or 'false'

        const user = await User.findOne({ userId });
        if (user) {
            user.isLeaderboardBanned = (ban === 'true');
            await user.save();
        }
        res.redirect('/admin/battle-arena/leaderboard');
    } catch (err) {
        console.error('Leaderboard user ban error:', err);
        res.status(500).send('Internal Server Error');
    }
});

// 5.2 End Current Cycle Manually
router.post('/leaderboard/cycle/end-current', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        let activeLbConfig = await BattleConfig.findOne({ key: { $ne: 'battleConfig' }, isActive: true }).sort({ createdAt: -1 });
        if (!activeLbConfig) {
            activeLbConfig = await BattleConfig.findOne({ key: 'battleConfig', isActive: true });
        }
        if (!activeLbConfig) {
            activeLbConfig = await BattleConfig.findOne({ key: 'battleConfig' });
        }

        const config = activeLbConfig ? (activeLbConfig.toObject ? activeLbConfig.toObject() : activeLbConfig) : {};
        const currentCycleId = config.key || 'battleConfig';
        const historyCycleId = `${currentCycleId}_${Date.now()}`;
        const rewardTiers = config.rewardTiers || [];
        const isShowWinnersOnly = config.showWinnersOnly === true;
        const isAutoReward = config.autoRewardProcess === true;

        // Query standings for this cycle
        const queryFilter = { cycleId: currentCycleId };
        if (isShowWinnersOnly) {
            queryFilter.winsCount = { $gt: 0 };
        }
        const sortOption = isShowWinnersOnly
            ? { winsCount: -1, totalSpeedPoints: -1, lastMatchAt: 1 }
            : { totalSpeedPoints: -1, winsCount: -1, lastMatchAt: 1 };

        const rawStandings = await BattleLeaderboard.find(queryFilter).sort(sortOption).limit(100).lean();

        let topWinnerName = 'No Participants';
        let topWinnerAvatar = '';

        const standingsSnapshot = rawStandings.map((item, idx) => {
            const rank = idx + 1;
            if (rank === 1) {
                topWinnerName = item.userName || 'Player';
                topWinnerAvatar = item.avatar || '';
            }
            return {
                rank,
                userId: item.userId,
                userName: item.userName,
                avatar: item.avatar,
                winsCount: item.winsCount,
                totalSpeedPoints: item.totalSpeedPoints,
                projectedPrizeCoins: 0,
                isTied: false,
                tiedPlayerCount: 1
            };
        });

        // Compute prize coins according to reward tiers
        rewardTiers.forEach(tier => {
            const playersInTier = standingsSnapshot.filter(p => p.rank >= tier.rankStart && p.rank <= tier.rankEnd);
            if (playersInTier.length > 0) {
                const shareCoins = Math.floor(tier.coins / playersInTier.length);
                playersInTier.forEach(p => {
                    p.projectedPrizeCoins = shareCoins;
                    p.isTied = playersInTier.length > 1;
                    p.tiedPlayerCount = playersInTier.length;
                });
            }
        });

        const cycleDays = Number(config.cycleDays) || 7;
        const cycleTypeStr = (cycleDays === 1) ? 'Daily' : ((cycleDays === 30) ? 'Monthly' : 'Weekly');
        const lbTitle = config.title || `${cycleTypeStr} Leaderboard`;
        
        // Payout Status based on Auto Reward setting:
        // When Manual (autoRewardProcess: false) -> PENDING
        // When Automatic (autoRewardProcess: true) -> PROCESSED
        const payoutStatus = isAutoReward ? 'PROCESSED' : 'PENDING';
        const battleHistoryStatus = isAutoReward ? 'APPROVED' : 'PENDING';

        // 1. Create history cycle for Admin Dashboard
        await BattleLeaderboardHistory.create({
            cycleId: historyCycleId,
            periodEnd: new Date(),
            totalPlayers: rawStandings.length,
            topWinnerName,
            topWinnerAvatar,
            payoutStatus: payoutStatus,
            title: lbTitle,
            cycleType: cycleTypeStr,
            rankingBasis: config.rankingBasis || 'wins',
            showWinnersOnly: isShowWinnersOnly,
            standingsSnapshot
        });

        // 2. Create BattleHistory record for App History
        await BattleHistory.create({
            cycleId: historyCycleId,
            title: lbTitle,
            cycleType: cycleTypeStr,
            rankingBasis: config.rankingBasis || 'wins',
            cycleDays,
            showWinnersOnly: isShowWinnersOnly,
            status: battleHistoryStatus,
            resultDeclaredAt: isAutoReward ? new Date() : null,
            startTime: config.startTime,
            nextPayoutTime: config.nextPayoutTime || new Date(),
            autoRewarded: isAutoReward,
            winners: standingsSnapshot.map(s => ({
                userId: s.userId,
                userName: s.userName,
                avatar: s.avatar,
                rank: s.rank,
                winsCount: s.winsCount,
                totalSpeedPoints: s.totalSpeedPoints,
                coinsAwarded: s.projectedPrizeCoins
            }))
        });

        // 3. If Auto Reward is ON -> Distribute Coins immediately
        if (isAutoReward) {
            for (const w of standingsSnapshot) {
                if (w.userId && w.projectedPrizeCoins > 0) {
                    const user = await User.findOneAndUpdate(
                        { userId: w.userId },
                        { $inc: { coins: w.projectedPrizeCoins, totalCoins: w.projectedPrizeCoins } },
                        { new: true }
                    ).catch(err => console.error('Failed coin credit for winner:', err));

                    if (user) {
                        await RewardHistory.create({
                            appName: user.appName,
                            userId: w.userId,
                            provider: 'Battle Leaderboard Prize',
                            coins: w.projectedPrizeCoins,
                            rewardType: 'coin',
                            orderId: `leaderboard_${historyCycleId}_rank_${w.rank}_${Date.now()}`,
                            timestamp: new Date()
                        }).catch(err => console.error('Failed to log reward history for cycle end:', err));

                        // 👑 Send Winner Notification
                        sendNotificationViaApi({
                            title: '👑 You Won a Leaderboard Prize!',
                            body: `Congratulations! You secured Rank #${w.rank} in "${lbTitle}" and received 🪙 ${w.projectedPrizeCoins.toLocaleString()} Coins in your wallet!`,
                            userId: w.userId
                        }).catch(e => console.error('Winner notification error:', e.message));
                    }
                }
            }
        }

        // 🏆 Broadcast Results Declared Notification to All Players
        sendNotificationViaApi({
            title: '🏆 Tournament Results Declared!',
            body: `Results for "${lbTitle}" are now announced! Open Leaderboard to check winners and final scores.`
        }).catch(e => console.error('Results announced notification error:', e.message));

        // 4. Handle Auto Reschedule / Cycle Rollover
        const isAutoReschedule = config.autoReschedule !== false;
        const oldStart = config.startTime ? new Date(config.startTime) : new Date(Date.now() - cycleDays * 86400000);
        const oldPayout = config.nextPayoutTime ? new Date(config.nextPayoutTime) : new Date();
        let msPeriod = oldPayout.getTime() - oldStart.getTime();
        if (isNaN(msPeriod) || msPeriod <= 0) {
            msPeriod = cycleDays * 24 * 60 * 60 * 1000;
        }

        const newStartTime = new Date();
        const newPayoutTime = new Date(newStartTime.getTime() + msPeriod);

        if (activeLbConfig) {
            if (isAutoReschedule) {
                await BattleConfig.updateOne(
                    { _id: activeLbConfig._id },
                    { $set: { startTime: newStartTime, nextPayoutTime: newPayoutTime, isActive: true } }
                );
                await BattleLeaderboard.deleteMany({ cycleId: currentCycleId });

                await BattleConfig.findOneAndUpdate(
                    { key: 'battleConfig' },
                    { $set: {
                        startTime: newStartTime,
                        nextPayoutTime: newPayoutTime,
                        isActive: true
                    } }
                );

                // 🚀 Broadcast New Tournament Live Notification
                sendNotificationViaApi({
                    title: '🏆 New Battle Tournament is Live!',
                    body: `New tournament cycle for "${lbTitle}" has started! Play now to climb the ranks and win coins! 💰`
                }).catch(e => console.error('New cycle notification error:', e.message));
            } else {
                // If Auto Reschedule is OFF: completely DELETE the leaderboard configuration from MongoDB
                await BattleConfig.deleteMany({
                    $or: [
                        { _id: activeLbConfig._id },
                        { key: currentCycleId }
                    ]
                });
                await BattleLeaderboard.deleteMany({ cycleId: currentCycleId });

                // Check if any other active leaderboard exists
                const nextActive = await BattleConfig.findOne({ key: { $ne: 'battleConfig' }, isActive: true });
                if (nextActive) {
                    await BattleConfig.findOneAndUpdate(
                        { key: 'battleConfig' },
                        { $set: {
                            startTime: nextActive.startTime,
                            nextPayoutTime: nextActive.nextPayoutTime,
                            isActive: true,
                            autoReschedule: nextActive.autoReschedule !== false,
                            title: nextActive.title,
                            rewardTiers: nextActive.rewardTiers
                        } }
                    );
                } else {
                    await BattleConfig.findOneAndUpdate(
                        { key: 'battleConfig' },
                        { $set: { isActive: false } }
                    );
                }
            }
        }

        await cacheService.delPattern('battle:leaderboard*');
        res.redirect('/admin/battle-arena/leaderboard?tab=historical-records&msg=declared_success');
    } catch (err) {
        console.error('End current cycle error:', err);
        res.status(500).send('Internal Server Error');
    }
});

// 5.3 Process Payout for completed cycle
router.post('/leaderboard/payout/process/:cycleId', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { cycleId } = req.params;
        const history = await BattleLeaderboardHistory.findOne({ cycleId });

        if (!history) {
            return res.status(404).send('Leaderboard cycle history not found');
        }
        if (history.payoutStatus === 'PROCESSED') {
            return res.status(400).send('Payout already processed for this cycle');
        }

        // Distribute Coins to rank winners
        const snapshot = history.standingsSnapshot || [];
        for (const item of snapshot) {
            const coinsPrize = Number(item.projectedPrizeCoins || item.coinsAwarded || 0);
            if (coinsPrize > 0 && item.userId) {
                const user = await User.findOneAndUpdate(
                    { userId: item.userId },
                    { $inc: { coins: coinsPrize, totalCoins: coinsPrize } },
                    { new: true }
                );
                if (user) {
                    await RewardHistory.create({
                        appName: user.appName,
                        userId: user.userId,
                        provider: 'Battle Leaderboard Prize',
                        coins: coinsPrize,
                        rewardType: 'coin',
                        orderId: `leaderboard_${cycleId}_rank_${item.rank}_${Date.now()}`,
                        timestamp: new Date()
                    }).catch(err => console.error('Failed to log reward history for leaderboard payout:', err));

                    // 👑 Send Winner Notification
                    sendNotificationViaApi({
                        title: '👑 You Won a Leaderboard Prize!',
                        body: `Congratulations! You secured Rank #${item.rank} in "${history.title || 'Leaderboard'}" and received 🪙 ${coinsPrize.toLocaleString()} Coins in your wallet!`,
                        userId: item.userId
                    }).catch(e => console.error('Bulk payout notification error:', e.message));
                }
            }
        }

        // Mark cycle history and raw standings cycle records as processed
        history.payoutStatus = 'PROCESSED';
        history.payoutProcessedAt = new Date();
        await history.save();

        // Also update BattleHistory for app side
        await BattleHistory.updateOne(
            { cycleId },
            { $set: { status: 'APPROVED', resultDeclaredAt: new Date() } }
        );

        await BattleLeaderboard.updateMany(
            { cycleId },
            { $set: { payoutProcessed: true } }
        );

        res.redirect('/admin/battle-arena/leaderboard?tab=historical-records&msg=payout_success');
    } catch (err) {
        console.error('Process cycle payout error:', err);
        res.status(500).send('Internal Server Error');
    }
});

// 5.4 Process Payout for a single individual user in a cycle
router.post('/leaderboard/payout/single-user', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { cycleId, userId } = req.body;
        if (!cycleId || !userId) {
            return res.status(400).json({ success: false, message: 'Missing cycleId or userId' });
        }

        const history = await BattleLeaderboardHistory.findOne({ cycleId });
        if (!history) {
            return res.status(404).json({ success: false, message: 'Leaderboard cycle history not found' });
        }

        const snapshot = history.standingsSnapshot || [];
        const winner = snapshot.find(w => String(w.userId) === String(userId));
        if (!winner) {
            return res.status(404).json({ success: false, message: 'Winner record not found for user' });
        }

        if (winner.isPaid) {
            return res.status(400).json({ success: false, message: 'Payout already released for this user' });
        }

        const coinsPrize = Number(winner.projectedPrizeCoins || winner.coinsAwarded || 0);
        if (coinsPrize > 0) {
            const user = await User.findOneAndUpdate(
                { userId: winner.userId },
                { $inc: { coins: coinsPrize, totalCoins: coinsPrize } },
                { new: true }
            );

            if (user) {
                await RewardHistory.create({
                    appName: user.appName,
                    userId: user.userId,
                    provider: 'Battle Leaderboard Prize',
                    coins: coinsPrize,
                    rewardType: 'coin',
                    orderId: `leaderboard_${cycleId}_rank_${winner.rank}_${Date.now()}`,
                    timestamp: new Date()
                }).catch(err => console.error('Failed to log reward history for single user payout:', err));

                // 👑 Send Winner Notification
                sendNotificationViaApi({
                    title: '👑 You Won a Leaderboard Prize!',
                    body: `Congratulations! You secured Rank #${winner.rank} in "${history.title || 'Leaderboard'}" and received 🪙 ${coinsPrize.toLocaleString()} Coins in your wallet!`,
                    userId: winner.userId
                }).catch(e => console.error('Single user payout notification error:', e.message));
            }
        }

        // Mark this winner as paid
        winner.isPaid = true;
        winner.paidAt = new Date();

        // Check if all winners with coins > 0 are now paid
        const unpaidCount = snapshot.filter(w => (Number(w.projectedPrizeCoins || w.coinsAwarded || 0) > 0) && !w.isPaid).length;
        if (unpaidCount === 0) {
            history.payoutStatus = 'PROCESSED';
            history.payoutProcessedAt = new Date();
            await BattleHistory.updateOne(
                { cycleId },
                { $set: { status: 'APPROVED', resultDeclaredAt: new Date() } }
            );
        }

        history.markModified('standingsSnapshot');
        await history.save();

        return res.json({
            success: true,
            message: `Successfully released ${coinsPrize.toLocaleString()} Coins to ${winner.userName || winner.userId}!`,
            isPaid: true,
            allPaid: unpaidCount === 0
        });
    } catch (err) {
        console.error('Single user payout error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 6. Battle Bots Management
router.get('/bots', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const bots = await BattleBot.find().sort({ createdAt: -1 }).lean();
        res.render('battle-arena/bots', {
            admin: req.admin,
            bots: bots,
            activePage: 'battle-bots'
        });
    } catch (err) {
        console.error('Battle bots page error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/bots/add', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { name, avatar } = req.body;
        if (!name || !name.trim()) {
            return res.status(400).send('Bot name is required');
        }
        await BattleBot.create({
            name: String(name).trim(),
            avatar: String(avatar || '').trim(),
            isActive: true
        });
        res.redirect('/admin/battle-arena/bots');
    } catch (err) {
        console.error('Add battle bot error:', err);
        res.status(500).send('Internal Server Error');
    }
});

const multer = require('multer');
const upload = multer({ limits: { fileSize: 2 * 1024 * 1024 } }); // 2MB limit

router.post('/bots/upload-csv', adminAuth, upload.single('csvFile'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).send('No CSV file uploaded');
        }
        const fileContent = req.file.buffer.toString('utf-8');
        const lines = fileContent.split(/\r?\n/);
        const bots = [];

        let nameIdx = 0;
        let avatarIdx = 1;

        if (lines.length > 0) {
            const headers = lines[0].toLowerCase().split(',');
            nameIdx = headers.indexOf('name');
            avatarIdx = headers.indexOf('avatar');
            if (nameIdx === -1) nameIdx = 0;
            if (avatarIdx === -1) avatarIdx = 1;
        }

        for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;

            const cells = line.split(',');
            const name = cells[nameIdx] ? cells[nameIdx].replace(/^["']|["']$/g, '').trim() : '';
            const avatar = cells[avatarIdx] ? cells[avatarIdx].replace(/^["']|["']$/g, '').trim() : '';

            if (name) {
                bots.push({ name, avatar, isActive: true });
            }
        }

        if (bots.length > 0) {
            await connectMongo();
            await BattleBot.insertMany(bots);
        }

        res.redirect('/admin/battle-arena/bots');
    } catch (err) {
        console.error('Upload CSV bots error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/bots/delete/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        await BattleBot.findByIdAndDelete(req.params.id);
        res.redirect('/admin/battle-arena/bots');
    } catch (err) {
        console.error('Delete battle bot error:', err);
        res.status(500).send('Internal Server Error');
    }
});

// 7. Historical Records & Payout Approvals
router.get('/history', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const searchUser = String(req.query.search || '').trim();

        let query = {};
        if (searchUser) {
            query = {
                $or: [
                    { 'player1.userName': { $regex: searchUser, $options: 'i' } },
                    { 'player1.userId': searchUser },
                    { 'player2.userName': { $regex: searchUser, $options: 'i' } },
                    { 'player2.userId': searchUser },
                    { 'players.userName': { $regex: searchUser, $options: 'i' } },
                    { 'players.userId': searchUser },
                    { matchId: searchUser }
                ]
            };
        }

        const matches = await BattleMatch.find(query).sort({ createdAt: -1 }).limit(200).lean();

        res.render('battle-arena/history', {
            admin: req.admin,
            matches,
            searchQuery: searchUser,
            activePage: 'battle-history'
        });
    } catch (err) {
        console.error('Leaderboard history page error:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/history/approve', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { historyId } = req.body;
        const record = await BattleHistory.findById(historyId);
        if (!record) {
            return res.status(404).json({ success: false, message: 'Record not found' });
        }
        if (record.status === 'APPROVED') {
            return res.status(400).json({ success: false, message: 'Record already approved' });
        }

        const winners = record.winners || [];
        for (const w of winners) {
            if (w.userId && w.coinsAwarded > 0) {
                const user = await User.findOneAndUpdate(
                    { userId: w.userId },
                    { $inc: { totalCoins: w.coinsAwarded, coins: w.coinsAwarded } },
                    { new: true }
                );
                if (user) {
                    await RewardHistory.create({
                        appName: user.appName,
                        userId: w.userId,
                        provider: 'Battle Leaderboard Prize',
                        coins: w.coinsAwarded,
                        rewardType: 'coin',
                        orderId: `leaderboard_${record.cycleId}_rank_${w.rank}`,
                        timestamp: new Date()
                    });
                }
            }
        }

        record.status = 'APPROVED';
        record.resultDeclaredAt = new Date();
        record.autoRewarded = false;
        await record.save();

        return res.json({ success: true, message: 'Payout approved and coins credited to winners successfully!' });
    } catch (err) {
        console.error('Approve history payout error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

router.post('/history/reject', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { historyId } = req.body;
        const record = await BattleHistory.findById(historyId);
        if (!record) {
            return res.status(404).json({ success: false, message: 'Record not found' });
        }

        record.status = 'REJECTED';
        await record.save();

        return res.json({ success: true, message: 'Payout rejected successfully' });
    } catch (err) {
        console.error('Reject history payout error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

router.get('/sync-history-trigger', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const adminHistories = await BattleLeaderboardHistory.find().lean();
        for (const h of adminHistories) {
            const winners = (h.standingsSnapshot || []).map(s => ({
                userId: s.userId,
                userName: s.userName,
                avatar: s.avatar,
                rank: s.rank,
                winsCount: s.winsCount,
                totalSpeedPoints: s.totalSpeedPoints,
                coinsAwarded: s.projectedPrizeCoins || 0
            }));

            await BattleHistory.findOneAndUpdate(
                { cycleId: h.cycleId },
                {
                    cycleId: h.cycleId,
                    cycleType: 'Weekly',
                    cycleDays: 7,
                    status: 'APPROVED',
                    resultDeclaredAt: h.periodEnd || new Date(),
                    winners
                },
                { upsert: true, new: true }
            );

            for (const w of (h.standingsSnapshot || [])) {
                if (w.projectedPrizeCoins > 0) {
                    await User.findOneAndUpdate(
                        { userId: w.userId },
                        { $inc: { coins: w.projectedPrizeCoins } }
                    );
                }
            }
        }
        res.redirect('/admin/battle-arena/history');
    } catch (e) {
        console.error('Sync history trigger error:', e);
        res.status(500).send('Sync error: ' + e.message);
    }
});

module.exports = router;
