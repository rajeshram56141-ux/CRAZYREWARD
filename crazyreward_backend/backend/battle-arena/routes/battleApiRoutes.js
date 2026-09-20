const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const cryptoMiddleware = require('../../admin/middlewares/cryptoMiddleware');

const BattleConfig = require('../models/battleConfig');
const QuizQuestion = require('../models/quizQuestion');
const BattleRoom = require('../models/battleRoom');
const BattleMatch = require('../models/battleMatch');
const BattleSession = require('../models/battleSession');
const BattleLeaderboard = require('../models/battleLeaderboard');
const BattleHistory = require('../models/battleHistory');
const BattleLeaderboardHistory = require('../models/battleLeaderboardHistory');
const User = require('../../admin/models/user');
const BattleBot = require('../../admin/models/battleBot');
const RewardHistory = require('../../admin/models/rewardHistory');
const { sendNotificationViaApi } = require('../../admin/middlewares/send-notification-api');
const cacheService = require('../../services/cacheService');

function getCurrentCycleId() {
    // Current date in IST (UTC+05:30)
    const now = new Date(Date.now() + (5.5 * 60 * 60 * 1000));
    const year = now.getUTCFullYear();
    const startOfYear = new Date(Date.UTC(year, 0, 1));
    const pastDays = Math.floor((now.getTime() - startOfYear.getTime()) / (24 * 60 * 60 * 1000));
    const weekNumber = Math.ceil((pastDays + startOfYear.getUTCDay() + 1) / 7);
    return `cycle_${year}_w${weekNumber}`;
}

async function predetermineBotAnswers(match, botShouldWin, botUserId = 'ai_bot_opponent') {
    try {
        const qCount = match.questions.length || 7;
        const botAnswers = [];
        let accumulatedTimeSec = 6; // Start after 6 seconds delay buffer for countdown + load time

        let correctCount = 0;
        if (botShouldWin) {
            correctCount = Math.floor(qCount * 0.7) + Math.floor(Math.random() * (qCount - Math.floor(qCount * 0.7) + 1)); // 5 to 7 correct
        } else {
            correctCount = Math.floor(Math.random() * Math.min(4, qCount)); // 0 to 3 correct
        }

        const questionStatuses = Array(qCount).fill('wrong');
        let assigned = 0;
        while (assigned < correctCount) {
            const idx = Math.floor(Math.random() * qCount);
            if (questionStatuses[idx] === 'wrong') {
                questionStatuses[idx] = 'correct';
                assigned++;
            }
        }

        // Randomly assign a few skips
        for (let i = 0; i < qCount; i++) {
            if (questionStatuses[i] === 'wrong' && Math.random() < 0.2) {
                questionStatuses[i] = 'skipped';
            }
        }

        for (let i = 0; i < qCount; i++) {
            const questionId = match.questions[i];
            const status = questionStatuses[i];
            let timeTakenSec = 0;
            let pointsEarned = 0;

            if (status === 'correct') {
                timeTakenSec = parseFloat((1.5 + Math.random() * 2).toFixed(2)); // 1.5 to 3.5 seconds
                const speedBonus = Math.max(0, Math.round((5 - timeTakenSec) * 20));
                pointsEarned = 100 + speedBonus;
            } else if (status === 'wrong') {
                timeTakenSec = parseFloat((2 + Math.random() * 2).toFixed(2)); // 2 to 4 seconds
                pointsEarned = -100;
            } else {
                timeTakenSec = 5; // skipped
                pointsEarned = 0;
            }

            accumulatedTimeSec += timeTakenSec;
            const startAnchor = match.gameStartedAt || match.createdAt || new Date();
            const submittedAt = new Date(new Date(startAnchor).getTime() + accumulatedTimeSec * 1000);

            botAnswers.push({
                questionId,
                userId: botUserId,
                selectedOptionIndex: status === 'correct' ? 0 : (status === 'skipped' ? -1 : 1),
                isCorrect: status === 'correct',
                timeTakenMs: Math.round(timeTakenSec * 1000),
                speedPointsEarned: pointsEarned,
                submittedAt
            });
        }
        return botAnswers;
    } catch (e) {
        console.error('Error predetermining bot answers:', e);
        return [];
    }
}

// 1. Fetch Active Battle Rooms & Config
router.post('/active-rooms', cryptoMiddleware, async (req, res) => {
    try {
        const cacheKey = 'battle:active_rooms';
        const cached = await cacheService.get(cacheKey);
        if (cached) {
            return res.json({
                success: true,
                ...cached
            });
        }

        await connectMongo();
        let config = await BattleConfig.findOne({ key: 'battleConfig' }).lean();
        if (!config) {
            config = await BattleConfig.create({ key: 'battleConfig' });
        }

        const rawRooms = await BattleRoom.find({ status: { $ne: 'Closed' } }).sort({ entryFeeCoins: 1 });
        const rooms = rawRooms.map(r => r.toObject ? r.toObject() : r);

        const responsePayload = {
            config: {
                isActive: config.isActive !== false,
                cycleDays: config.cycleDays || 7,
                platformCommissionFee: config.platformCommissionFee || 10,
                freeRoomAdMandate: config.freeRoomAdMandate !== false,
                nextPayoutTime: config.nextPayoutTime,
                rewardTiers: config.rewardTiers || [],
                terms: config.terms || [],
                installTaskMb: config.installTaskMb || 15,
                installTaskUsageSeconds: config.installTaskUsageSeconds || 30,
                freeTerms: config.freeTerms || [],
                paidTerms: config.paidTerms || []
            },
            rooms: rooms
        };

        const ttl = cacheService.getTtl('rooms');
        await cacheService.set(cacheKey, responsePayload, ttl);

        return res.json({
            success: true,
            ...responsePayload
        });
    } catch (e) {
        console.error('🔥 Error fetching battle rooms:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 1b. Fetch Fresh Room Details
router.post('/room-details', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const roomId = String(req.body?.roomId || '').trim();
        if (!roomId) {
            return res.status(400).json({ success: false, message: 'Room ID required' });
        }

        let room = await BattleRoom.findOne({ roomId });
        if (!room && roomId.length === 24) {
            room = await BattleRoom.findById(roomId);
        }
        if (!room) {
            return res.status(404).json({ success: false, message: 'Room not found' });
        }

        let config = await BattleConfig.findOne({ key: 'battleConfig' }).lean();

        return res.json({
            success: true,
            room: room.toObject ? room.toObject() : room,
            config: {
                isActive: config?.isActive !== false,
                cycleDays: config?.cycleDays || 7,
                platformCommissionFee: config?.platformCommissionFee || 10,
                freeRoomAdMandate: config?.freeRoomAdMandate !== false,
                nextPayoutTime: config?.nextPayoutTime,
                rewardTiers: config?.rewardTiers || [],
                terms: config?.terms || [],
                installTaskMb: config?.installTaskMb || 15,
                installTaskUsageSeconds: config?.installTaskUsageSeconds || 30,
                freeTerms: config?.freeTerms || [],
                paidTerms: config?.paidTerms || []
            }
        });
    } catch (e) {
        console.error('🔥 Error fetching fresh room details:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 2. Join Battle Room (Instant 1v1 Matchmaking)
router.post('/join-room', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const userId = String(req.body?.userId || req.headers['user-id'] || '').trim();
        const roomId = String(req.body?.roomId || '').trim();
        const deviceId = String(req.body?.deviceId || req.headers['device-id'] || req.headers['x-device-id'] || '').trim();
        const adVerifiedToken = String(req.body?.adVerifiedToken || '').trim();
        const rawIp = req.headers['cf-connecting-ip'] || req.headers['x-forwarded-for'] || req.ip || req.socket?.remoteAddress || '';
        const clientIp = String(rawIp).split(',')[0].trim() || '127.0.0.1';

        if (!userId || !roomId) {
            return res.status(400).json({ success: false, message: 'Missing userId or roomId' });
        }

        let room = await BattleRoom.findOne({ roomId });
        if (!room && roomId.length === 24) {
            room = await BattleRoom.findById(roomId);
        }
        if (!room) {
            return res.status(404).json({ success: false, message: 'Battle room not found or closed' });
        }

        if (room.entryType === 'Free' && room.adType && room.adType !== 'None' && adVerifiedToken !== 'WATCHED_AD') {
            return res.status(400).json({
                success: false,
                requiresAd: true,
                message: `Mandatory ${room.adType} ad watch required before joining free room`
            });
        }

        const mongoose = require('mongoose');
        let user = null;
        if (mongoose.Types.ObjectId.isValid(userId)) {
            user = await User.findOne({ $or: [{ userId: userId }, { _id: userId }] });
        } else {
            user = await User.findOne({ userId: userId });
        }
        if (!user) {
            return res.status(404).json({ success: false, message: 'User account not found' });
        }

        const isGuest = Boolean(user.isGuest === true || user.isAnonymous === true);
        const userName = user.displayName || user.name || user.username || user.email?.split('@')[0] || (isGuest ? 'Guest Player' : 'Player');
        const userAvatar = user.photoUrl || user.avatar || '';

        const entryFeeCoins = Number(room.entryFeeCoins || 0);
        const platformCutPercent = Number(room.platformCutPercent || 10);
        const netPrizePoolCoins = Number(room.netPrizePoolCoins || Math.round(entryFeeCoins * 2 * (1 - platformCutPercent / 100)));
        const platformFeeEarned = room.entryType === 'Paid' ? Math.round(entryFeeCoins * 2 * (platformCutPercent / 100)) : 0;

        const roomTimeoutSec = Number(room.matchingTimeoutSec || 35);

        // 1. Check if user is ALREADY in a WAITING match for this room BEFORE deducting fee coins!
        const myExistingWaiting = await BattleMatch.findOne({
            roomId: room.roomId,
            status: 'WAITING',
            $or: [
                { 'player1.userId': userId },
                { 'players.userId': userId }
            ]
        });

        if (myExistingWaiting) {
            return res.json({
                success: true,
                matchId: myExistingWaiting.matchId,
                status: 'WAITING',
                matchingTimeoutSec: roomTimeoutSec
            });
        }

        if (room.entryType === 'Free') {
            if (user.battleDailyLimit !== -1 && (user.freeBattlesJoinedToday || 0) >= user.battleDailyLimit) {
                return res.status(400).json({
                    success: false,
                    message: "Today's free battle limit over! Try tomorrow."
                });
            }
            user.freeBattlesJoinedToday = (user.freeBattlesJoinedToday || 0) + 1;
            await user.save();

            // Log free battle join as 1 ad impression for My Earnings Ads Mode
            try {
                const RewardHistory = require('../../admin/models/rewardHistory');
                await RewardHistory.create({
                    appName: user.appName || req.body?.appName || 'Crazyreward',
                    userId,
                    provider: 'Battle Free Join',
                    coins: 0,
                    gems: 0,
                    rewardType: 'coin',
                    orderId: 'BATTLE_FREE_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
                    createdAt: new Date(),
                    timestamp: new Date()
                });
            } catch (err) {
                console.error('⚠️ RewardHistory create error for free battle join:', err);
            }
        }

        // 2. Deduct entry fee if paid
        if (room.entryType === 'Paid') {
            const currentCoins = Number(user.coins || 0);

            // 2a. Fetch BattleConfig for bonus coins usage rules
            const battleConfigDoc = await BattleConfig.findOne({ key: 'battleConfig' }).lean() || {};
            const allowBonusCoins = battleConfigDoc.allowBonusCoins === true;
            const bonusUsagePercent = allowBonusCoins
                ? Math.max(0, Math.min(100, Number(battleConfigDoc.bonusUsagePercent || 0)))
                : 0;

            // 2b. Compute user's bonus and earned coins balance
            let userBonusCoins = Number(user.bonusCoins || 0);

            // Lazy sync for accounts created prior to bonusCoins schema field
            if (userBonusCoins === 0 && currentCoins > 0) {
                try {
                    const RewardHistory = require('../../admin/models/rewardHistory');
                    const legacyBonusHistory = await RewardHistory.find({
                        userId: user.userId,
                        provider: { $in: ['Signup Bonus', 'Referral Bonus'] }
                    }).lean();
                    if (legacyBonusHistory && legacyBonusHistory.length > 0) {
                        const totalHistoricBonus = legacyBonusHistory.reduce((acc, h) => acc + (Number(h.coins) || 0), 0);
                        if (totalHistoricBonus > 0) {
                            userBonusCoins = Math.min(totalHistoricBonus, currentCoins);
                            await User.updateOne({ userId: user.userId }, { $set: { bonusCoins: userBonusCoins } }).catch(() => { });
                            user.bonusCoins = userBonusCoins;
                        }
                    }
                } catch (_) { }
            }

            // Cap bonus coins to current wallet coins
            userBonusCoins = Math.min(userBonusCoins, currentCoins);
            const earnedCoins = Math.max(0, currentCoins - userBonusCoins);

            // Maximum bonus coins allowed for this specific entry fee based on admin config
            const maxBonusUsable = Math.floor(entryFeeCoins * (bonusUsagePercent / 100));
            // Actual bonus coins user can contribute
            const bonusContributed = Math.min(userBonusCoins, maxBonusUsable);
            // Minimum earned coins required from the user
            const minEarnedCoinsRequired = entryFeeCoins - bonusContributed;

            // Total coins check
            if (currentCoins < entryFeeCoins) {
                return res.status(400).json({
                    success: false,
                    message: `Insufficient coin balance! Entry fee is ${entryFeeCoins} Coins.`
                });
            }

            // Earned coins restriction check (Bonus coins cannot be used beyond allowed percentage)
            if (earnedCoins < minEarnedCoinsRequired) {
                return res.status(400).json({
                    success: false,
                    isBonusCoinRestriction: true,
                    bonusCoins: userBonusCoins,
                    earnedCoins: earnedCoins,
                    entryFeeCoins: entryFeeCoins,
                    allowedBonusPercent: bonusUsagePercent,
                    minEarnedCoinsRequired: minEarnedCoinsRequired,
                    message: allowBonusCoins && bonusUsagePercent > 0
                        ? `You have ${userBonusCoins} bonus coins. Only ${bonusUsagePercent}% can be paid via bonus coins. You need at least ${minEarnedCoinsRequired} earned coins to enter. Please collect more coins to play!`
                        : `You have ${userBonusCoins} bonus coins. Bonus coins cannot be used to enter Paid Battles. Please collect more coins to play!`
                });
            }

            // Deduct coins: bonus portion from bonusCoins, and total entry fee from total coins
            user.bonusCoins = Math.max(0, userBonusCoins - bonusContributed);
            user.coins = Math.max(0, currentCoins - entryFeeCoins);
            await user.save();

            // Log entry fee spending
            await RewardHistory.create({
                appName: user.appName || '',
                userId,
                provider: 'Battle Spend',
                coins: -entryFeeCoins,
                gems: 0,
                rewardType: 'coin',
                orderId: 'BATTLE_SPEND_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
                createdAt: new Date(),
            }).catch(err => console.error('⚠️ RewardHistory create warning:', err));
        }

        const targetCapacity = Number(room.capacity || 2);

        const playerObj = {
            userId,
            userName,
            avatar: userAvatar,
            ipAddress: clientIp,
            deviceId,
            adVerified: !!adVerifiedToken,
            isGuest: isGuest,
            speedScore: 0,
            correctCount: 0,
            wrongCount: 0,
            skippedCount: 0,
            totalTimeTakenSec: 0,
            forfeited: false,
            finished: false
        };

        // Track Daily Challenge progress for Battle Arena
        try {
            const { trackDailyChallengeProgress } = require('../../routes/modules/dailyChallengeApiRoutes');
            trackDailyChallengeProgress(userId, 'battle_arena', 1);
        } catch (_) { }

        // Atomically find a WAITING match that has vacancy (length < targetCapacity) AND push our playerObj in a single write operation!
        // Anti-Cheat: Strictly prevent matching with the same user, same device ID, or same IP address!
        const cleanDeviceId = String(deviceId || user.deviceId || '').trim();

        const matchExclusionFilter = {
            roomId: room.roomId,
            status: 'WAITING',
            'players.userId': { $ne: userId },
            'player1.userId': { $ne: userId },
            [`players.${targetCapacity - 1}`]: { $exists: false }
        };

        // Strict Separation: Guest users ONLY match with guest users; Real users ONLY match with real users!
        if (isGuest) {
            matchExclusionFilter.isGuestMatch = true;
            matchExclusionFilter['players.isGuest'] = { $ne: false };
        } else {
            matchExclusionFilter.isGuestMatch = { $ne: true };
            matchExclusionFilter['players.isGuest'] = { $ne: true };
        }

        if (cleanDeviceId && cleanDeviceId !== 'ai_bot_device') {
            matchExclusionFilter['players.deviceId'] = { $ne: cleanDeviceId };
            matchExclusionFilter['player1.deviceId'] = { $ne: cleanDeviceId };
        }

        if (clientIp && clientIp !== '127.0.0.1' && clientIp !== '::1' && !clientIp.startsWith('127.')) {
            matchExclusionFilter['players.ipAddress'] = { $ne: clientIp };
            matchExclusionFilter['player1.ipAddress'] = { $ne: clientIp };
        }

        const waitingMatch = await BattleMatch.findOneAndUpdate(
            matchExclusionFilter,
            {
                $push: { players: playerObj }
            },
            {
                new: true
            }
        );

        if (waitingMatch) {
            // For backward compatibility, set player2 if it's the second player
            if (waitingMatch.players.length === 2) {
                waitingMatch.player2 = playerObj;
            }

            // Check if capacity is reached
            if (waitingMatch.players.length >= targetCapacity) {
                waitingMatch.status = 'IN_PROGRESS';
                waitingMatch.gameStartedAt = new Date();
            }

            await waitingMatch.save();

            if (waitingMatch.status === 'IN_PROGRESS') {
                return res.json({
                    success: true,
                    matchId: waitingMatch.matchId,
                    status: 'IN_PROGRESS',
                    matchingTimeoutSec: 0
                });
            } else {
                return res.json({
                    success: true,
                    matchId: waitingMatch.matchId,
                    status: 'WAITING',
                    matchingTimeoutSec: roomTimeoutSec,
                    players: waitingMatch.players.map(p => ({
                        userId: p.userId,
                        name: p.userName,
                        avatar: p.avatar
                    })),
                    capacity: targetCapacity
                });
            }
        }

        // 3. Fetch Questions for a new match (Redis Cached Pool)
        const gameTitle = room.assignedGameTitle || 'General Quiz Clash';
        const cacheKey = `quiz:bank:${gameTitle}`;
        let availablePool = await cacheService.get(cacheKey);

        if (!availablePool || availablePool.length === 0) {
            availablePool = await QuizQuestion.find({
                gameTitle: gameTitle
            }).lean();

            if (!availablePool || availablePool.length === 0) {
                availablePool = await QuizQuestion.find({}).lean();
            }

            if (availablePool && availablePool.length > 0) {
                await cacheService.set(cacheKey, availablePool, cacheService.getTtl('global'));
            }
        }

        let questionIds = [];
        const targetPlaylistSize = 50;

        if (availablePool && availablePool.length > 0) {
            while (questionIds.length < targetPlaylistSize) {
                const poolCopy = [...availablePool];
                // Fisher-Yates shuffle
                for (let i = poolCopy.length - 1; i > 0; i--) {
                    const j = Math.floor(Math.random() * (i + 1));
                    [poolCopy[i], poolCopy[j]] = [poolCopy[j], poolCopy[i]];
                }
                // Avoid immediate consecutive duplicate when pool has > 1 question
                if (questionIds.length > 0 && poolCopy.length > 1 && questionIds[questionIds.length - 1] === poolCopy[0].questionId) {
                    [poolCopy[0], poolCopy[1]] = [poolCopy[1], poolCopy[0]];
                }
                for (const q of poolCopy) {
                    questionIds.push(q.questionId);
                    if (questionIds.length >= targetPlaylistSize) break;
                }
            }
        } else {
            const fallbackPool = ['q_1', 'q_2', 'q_3', 'q_4', 'q_5', 'q_6', 'q_7'];
            while (questionIds.length < targetPlaylistSize) {
                const shuffled = [...fallbackPool].sort(() => Math.random() - 0.5);
                questionIds.push(...shuffled);
            }
            questionIds = questionIds.slice(0, targetPlaylistSize);
        }

        // 4. Create a new WAITING BattleMatch
        const newMatchId = `match_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
        const newMatch = await BattleMatch.create({
            matchId: newMatchId,
            roomId: room.roomId,
            title: room.title,
            isGuestMatch: isGuest,

            // Snapshot configuration values onto the match document
            entryType: room.entryType || 'Paid',
            adType: room.adType || 'None',
            skipAdMatches: room.skipAdMatches || 0,
            entryFeeCoins: room.entryFeeCoins || 0,
            platformCutPercent: room.platformCutPercent || 0,
            timePerQuestionSec: room.timePerQuestionSec || 20,
            matchingTimeoutSec: roomTimeoutSec,
            enableAiBot: room.enableAiBot === true || room.enableAiBot === 'true',
            capacity: room.capacity || 2,
            rankRewards: room.rankRewards || [],

            player1: playerObj,
            player2: null,
            players: [playerObj], // Add the creator as the first item
            questions: questionIds,
            status: 'WAITING',
            platformFeeEarned,
            netPrizeAwarded: netPrizePoolCoins
        });

        return res.json({
            success: true,
            status: 'WAITING',
            matchId: newMatch.matchId,
            matchingTimeoutSec: roomTimeoutSec,
            players: newMatch.players.map(p => ({
                userId: p.userId,
                name: p.userName,
                avatar: p.avatar
            })),
            capacity: Number(room.capacity || 2)
        });
    } catch (e) {
        console.error('🔥 Error joining battle room:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 3. Match Status Check & Question Fetch
router.post('/match-status', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const matchId = String(req.body?.matchId || '').trim();
        const userId = String(req.body?.userId || '').trim();

        let match = await BattleMatch.findOne({ matchId });
        if (!match) {
            return res.status(404).json({ success: false, message: 'Match not found' });
        }

        if (match.status === 'IN_PROGRESS' || match.status === 'COMPLETED') {
            return returnMatchDetails(res, match, userId);
        }

        if (match.status === 'WAITING') {
            const room = await BattleRoom.findOne({ roomId: match.roomId }).lean();
            const roomTimeoutSec = Number(room ? (room.matchingTimeoutSec || 35) : (match.matchingTimeoutSec || 35));
            const enableAiBot = room
                ? (room.enableAiBot === true || room.enableAiBot === 'true')
                : (match.enableAiBot === true || match.enableAiBot === 'true');
            const targetCapacity = room ? Number(room.capacity || 2) : Number(match.capacity || 2);

            const now = new Date();
            const elapsedSec = Math.max(0, Math.floor((now - new Date(match.createdAt)) / 1000));

            if (enableAiBot) {
                // Determine how many players should be in the lobby at this elapsed time.
                // We add 1 bot every 3 seconds: expected = 1 (creator) + Math.floor(elapsedSec / 3)
                const expectedCount = Math.min(targetCapacity, 1 + Math.floor(elapsedSec / 3));

                if (match.players.length < expectedCount) {
                    // Lock the document state atomically using current array size to prevent concurrent duplicate bot pushes
                    const lockedMatch = await BattleMatch.findOneAndUpdate(
                        { matchId, status: 'WAITING', players: { $size: match.players.length } },
                        { $set: { updatedAt: new Date() } },
                        { new: true }
                    );

                    if (!lockedMatch) {
                        // Already updated by a concurrent request, fetch fresh status and continue
                        const freshMatch = await BattleMatch.findOne({ matchId });
                        return returnMatchDetails(res, freshMatch, userId);
                    }

                    match = lockedMatch;

                    const bots = await BattleBot.find({ isActive: true }).lean();
                    const botsToCreate = expectedCount - match.players.length;

                    for (let b = 0; b < botsToCreate; b++) {
                        const existingNames = match.players.map(p => p.userName);
                        const availableBots = bots.filter(bot => !existingNames.includes(bot.name));

                        if (availableBots.length === 0) {
                            break; // Stop adding bots since we ran out of unique ones!
                        }

                        const selectedBot = availableBots[Math.floor(Math.random() * availableBots.length)];
                        const newBotId = `bot_${selectedBot._id}`;
                        const botObj = {
                            userId: newBotId,
                            userName: selectedBot.name,
                            avatar: selectedBot.avatar || '',
                            deviceId: 'ai_bot_device',
                            ipAddress: '127.0.0.1',
                            adVerified: true,
                            isGuest: Boolean(match.isGuestMatch),
                            speedScore: 0,
                            correctCount: 0,
                            wrongCount: 0,
                            skippedCount: 0,
                            totalTimeTakenSec: 0,
                            forfeited: false,
                            finished: false
                        };

                        match.players.push(botObj);

                        // For legacy 1v1 match, also populate player2
                        if (match.players.length === 2 && targetCapacity === 2) {
                            match.player2 = botObj;
                        }
                    }

                    // Check if capacity is reached
                    if (match.players.length >= targetCapacity) {
                        match.status = 'IN_PROGRESS';
                        match.gameStartedAt = new Date();

                        // Pre-determine bot answers for all bot participants!
                        let config = await BattleConfig.findOne({ key: 'battleConfig' });
                        const botWinRate = config ? (config.botWinRate === 0 ? 0 : (config.botWinRate || 50)) : 50;

                        for (const p of match.players) {
                            if (p.userId.startsWith('bot_') || p.userId === 'ai_bot_opponent') {
                                const botShouldWin = (Math.random() * 100) < botWinRate;
                                const botLogs = await predetermineBotAnswers(match, botShouldWin, p.userId);
                                if (botLogs && botLogs.length > 0) {
                                    match.answerLogs.push(...botLogs);
                                }
                            }
                        }
                    }

                    await match.save();
                }
            }

            const isTimeout = req.body?.timeout === true || elapsedSec >= roomTimeoutSec;
            if (isTimeout && match.status === 'WAITING') {
                if (enableAiBot) {
                    // Try to atomically set the status to IN_PROGRESS to lock the match start!
                    const updatedMatch = await BattleMatch.findOneAndUpdate(
                        { matchId, status: 'WAITING' },
                        { $set: { status: 'IN_PROGRESS', gameStartedAt: new Date() } },
                        { new: true }
                    );

                    if (!updatedMatch) {
                        // Already processed by another concurrent request, return status details
                        const freshMatch = await BattleMatch.findOne({ matchId });
                        return returnMatchDetails(res, freshMatch, userId);
                    }

                    // Proceed with bots addition inside updatedMatch!
                    const bots = await BattleBot.find({ isActive: true }).lean();
                    const botsToCreate = targetCapacity - updatedMatch.players.length;

                    const existingNames = updatedMatch.players.map(p => p.userName);
                    const availableBots = bots.filter(bot => !existingNames.includes(bot.name));

                    if (availableBots.length >= botsToCreate) {
                        for (let b = 0; b < botsToCreate; b++) {
                            const selectedBot = availableBots[b];
                            const newBotId = `bot_${selectedBot._id}`;
                            const botObj = {
                                userId: newBotId,
                                userName: selectedBot.name,
                                avatar: selectedBot.avatar || '',
                                deviceId: 'ai_bot_device',
                                ipAddress: '127.0.0.1',
                                adVerified: true,
                                isGuest: Boolean(updatedMatch.isGuestMatch),
                                speedScore: 0,
                                correctCount: 0,
                                wrongCount: 0,
                                skippedCount: 0,
                                totalTimeTakenSec: 0,
                                forfeited: false,
                                finished: false
                            };

                            updatedMatch.players.push(botObj);
                            if (updatedMatch.players.length === 2 && targetCapacity === 2) {
                                updatedMatch.player2 = botObj;
                            }
                        }

                        // Pre-determine bot answers for all bot participants!
                        let config = await BattleConfig.findOne({ key: 'battleConfig' });
                        const botWinRate = config ? (config.botWinRate === 0 ? 0 : (config.botWinRate || 50)) : 50;

                        for (const p of updatedMatch.players) {
                            if (p.userId.startsWith('bot_') || p.userId === 'ai_bot_opponent') {
                                const botShouldWin = (Math.random() * 100) < botWinRate;
                                const botLogs = await predetermineBotAnswers(updatedMatch, botShouldWin, p.userId);
                                if (botLogs && botLogs.length > 0) {
                                    updatedMatch.answerLogs.push(...botLogs);
                                }
                            }
                        }

                        await updatedMatch.save();
                        return returnMatchDetails(res, updatedMatch, userId);
                    } else {
                        // Not enough unique bots available! Cancel match and refund!
                        updatedMatch.status = 'CANCELLED';
                        await updatedMatch.save();

                        const entryType = room ? room.entryType : (updatedMatch.entryType || 'Paid');
                        const entryFeeCoins = room ? room.entryFeeCoins : (updatedMatch.entryFeeCoins || 0);
                        if (entryType === 'Paid' && entryFeeCoins > 0) {
                            const playersToRefund = (updatedMatch.players && updatedMatch.players.length > 0) ? updatedMatch.players : [updatedMatch.player1];
                            for (const p of playersToRefund) {
                                if (p && p.userId && !p.userId.startsWith('bot_')) {
                                    const userToRefund = await User.findOne({ userId: p.userId });
                                    if (userToRefund) {
                                        userToRefund.coins = (userToRefund.coins || 0) + Number(entryFeeCoins);
                                        await userToRefund.save();

                                        await RewardHistory.create({
                                            appName: userToRefund.appName || '',
                                            userId: userToRefund.userId,
                                            provider: 'Battle Refund',
                                            coins: Number(entryFeeCoins),
                                            gems: 0,
                                            rewardType: 'coin',
                                            orderId: 'BATTLE_REFUND_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
                                            createdAt: new Date(),
                                        }).catch(err => console.error('⚠️ RewardHistory create warning:', err));
                                    }
                                }
                            }
                        }

                        return res.json({
                            success: false,
                            status: 'CANCELLED',
                            message: 'Not enough unique players found. Match cancelled and entry fee refunded!'
                        });
                    }
                } else {
                    // AI Bot is OFF! Atomically set status to CANCELLED to prevent concurrent refunds!
                    const updatedMatch = await BattleMatch.findOneAndUpdate(
                        { matchId, status: 'WAITING' },
                        { $set: { status: 'CANCELLED' } },
                        { new: true }
                    );

                    if (!updatedMatch) {
                        const freshMatch = await BattleMatch.findOne({ matchId });
                        return res.json({
                            success: false,
                            status: freshMatch ? freshMatch.status : 'CANCELLED',
                            message: 'Match was already updated or cancelled.'
                        });
                    }

                    const entryType = room ? room.entryType : (updatedMatch.entryType || 'Paid');
                    const entryFeeCoins = room ? room.entryFeeCoins : (updatedMatch.entryFeeCoins || 0);
                    if (entryType === 'Paid' && entryFeeCoins > 0) {
                        const playersToRefund = (updatedMatch.players && updatedMatch.players.length > 0) ? updatedMatch.players : [updatedMatch.player1];
                        for (const p of playersToRefund) {
                            if (p && p.userId) {
                                const userToRefund = await User.findOne({ userId: p.userId });
                                if (userToRefund) {
                                    userToRefund.coins = (userToRefund.coins || 0) + Number(entryFeeCoins);
                                    await userToRefund.save();

                                    // Log refund
                                    await RewardHistory.create({
                                        appName: userToRefund.appName || '',
                                        userId: userToRefund.userId,
                                        provider: 'Battle Refund',
                                        coins: Number(entryFeeCoins),
                                        gems: 0,
                                        rewardType: 'coin',
                                        orderId: 'BATTLE_REFUND_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
                                        createdAt: new Date(),
                                    }).catch(err => console.error('⚠️ RewardHistory create warning:', err));
                                }
                            }
                        }
                    }

                    return res.json({
                        success: false,
                        status: 'CANCELLED',
                        message: 'No opponent joined in time. Match cancelled and entry fee refunded!'
                    });
                }
            }

            const secondsRemaining = Math.max(0, roomTimeoutSec - elapsedSec);
            return res.json({
                success: true,
                status: 'WAITING',
                matchId: match.matchId,
                matchingTimeoutSec: secondsRemaining,
                message: 'Looking for an online opponent...',
                players: match.players.map(p => ({
                    userId: p.userId,
                    name: p.userName,
                    avatar: p.avatar
                })),
                capacity: room ? Number(room.capacity || 2) : 2
            });
        }

        if (match.status === 'CANCELLED') {
            return res.json({
                success: true,
                status: 'CANCELLED',
                message: 'Match was cancelled and entry coins refunded.'
            });
        }

        return res.status(400).json({ success: false, message: 'Invalid match status' });
    } catch (e) {
        console.error('🔥 Error fetching match status:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Helper to return formatted sub-match details with safe questions array
async function returnMatchDetails(res, match, userId) {
    const room = await BattleRoom.findOne({ roomId: match.roomId }).lean();

    // Fetch unique questions from Cache or DB
    const uniqueIds = [...new Set(match.questions || [])];
    const gameTitle = room?.assignedGameTitle || 'General Quiz Clash';
    let availablePool = await cacheService.get(`quiz:bank:${gameTitle}`);
    let questionsList = [];

    if (availablePool && availablePool.length > 0) {
        const poolMap = new Map(availablePool.map(q => [q.questionId, q]));
        questionsList = uniqueIds.map(id => poolMap.get(id)).filter(Boolean);
    }

    if (!questionsList || questionsList.length < uniqueIds.length) {
        questionsList = await QuizQuestion.find({ questionId: { $in: uniqueIds } }).lean();
    }

    const questionMap = new Map();
    questionsList.forEach(q => {
        questionMap.set(q.questionId, {
            questionId: q.questionId,
            category: q.category || 'General Knowledge',
            question: q.question || q.text || 'Sample Question',
            options: q.options || ['Option A', 'Option B', 'Option C', 'Option D'],
            timeLimitSec: q.timeLimitSec || 20
        });
    });

    // Build safeQuestions in the exact randomized sequence of match.questions
    let safeQuestions = [];
    if (match.questions && match.questions.length > 0) {
        for (const qId of match.questions) {
            const qObj = questionMap.get(qId);
            if (qObj) {
                safeQuestions.push(qObj);
            }
        }
    }

    if (safeQuestions.length === 0) {
        const fallbackPool = [
            { questionId: 'q_1', category: 'Math Speed', question: 'What is 15 + 27?', options: ['42', '40', '45', '38'], timeLimitSec: 20 },
            { questionId: 'q_2', category: 'Math Speed', question: 'What is 12 x 8?', options: ['86', '96', '104', '88'], timeLimitSec: 20 },
            { questionId: 'q_3', category: 'General Knowledge', question: 'Which planet is known as Red Planet?', options: ['Venus', 'Mars', 'Jupiter', 'Saturn'], timeLimitSec: 20 },
            { questionId: 'q_4', category: 'Math Speed', question: 'What is 100 - 37?', options: ['63', '73', '53', '67'], timeLimitSec: 20 },
            { questionId: 'q_5', category: 'Math Speed', question: 'How many sides does a hexagon have?', options: ['5', '6', '7', '8'], timeLimitSec: 20 },
            { questionId: 'q_6', category: 'Math Speed', question: 'What is 7 x 7?', options: ['42', '48', '49', '56'], timeLimitSec: 20 },
            { questionId: 'q_7', category: 'Math Speed', question: 'What is 144 / 12?', options: ['10', '11', '12', '14'], timeLimitSec: 20 }
        ];
        const shuffledFallback = [...fallbackPool].sort(() => Math.random() - 0.5);
        while (safeQuestions.length < 50) {
            safeQuestions.push(...shuffledFallback);
        }
        safeQuestions = safeQuestions.slice(0, 50);
    }

    // Determine the opponent to show in the client app
    let opponent = null;
    let oppScore = 0;

    if (match.players && match.players.length > 2) {
        // Multi-player match: cycle/rotate the opponent shown every 3 seconds!
        const otherPlayers = match.players.filter(p => p.userId !== userId);
        if (otherPlayers.length > 0) {
            const now = new Date();
            const startAnchor = match.gameStartedAt || match.createdAt || new Date();
            const matchDurationMs = (room ? (room.timePerQuestionSec || 20) : (match.timePerQuestionSec || 20)) * 1000;

            const processedPlayers = otherPlayers.map(p => {
                let currentScore = p.speedScore;
                if (p.userId.startsWith('bot_') || p.userId === 'ai_bot_opponent') {
                    currentScore = 0;
                    const botLogs = match.answerLogs
                        .filter(log => log.userId === p.userId && new Date(log.submittedAt) <= now && (new Date(log.submittedAt) - new Date(startAnchor)) <= matchDurationMs);
                    botLogs.forEach(log => {
                        currentScore = Math.max(0, currentScore + log.speedPointsEarned);
                    });
                }
                return {
                    ...p.toObject ? p.toObject() : p,
                    speedScore: currentScore
                };
            });

            // Sort by score descending to determine correct current ranks for label
            const sortedOthers = [...processedPlayers].sort((a, b) => b.speedScore - a.speedScore);
            const cycleIndex = Math.floor(Date.now() / 3000) % sortedOthers.length;
            opponent = sortedOthers[cycleIndex];
            oppScore = opponent.speedScore;
        }
    } else {
        // Legacy 1v1 match
        const isPlayer1 = !(match.player2 && match.player2.userId === userId);
        opponent = isPlayer1 ? match.player2 : match.player1;

        if (opponent) {
            const isBot = opponent.userId === 'ai_bot_opponent' || opponent.userId.startsWith('bot_');
            if (isBot) {
                const startAnchor = match.gameStartedAt || match.createdAt || new Date();
                const matchDurationMs = (room ? (room.timePerQuestionSec || 20) : (match.timePerQuestionSec || 20)) * 1000;
                const now = new Date();

                const botLogs = match.answerLogs
                    .filter(log => log.userId === opponent.userId && new Date(log.submittedAt) <= now && (new Date(log.submittedAt) - new Date(startAnchor)) <= matchDurationMs)
                    .sort((a, b) => new Date(a.submittedAt) - new Date(b.submittedAt));
                botLogs.forEach(log => {
                    oppScore = Math.max(0, oppScore + log.speedPointsEarned);
                });
            } else {
                oppScore = opponent.speedScore;
            }
        }
    }

    const startAnchor = match.gameStartedAt || match.createdAt || new Date();
    const elapsedSec = Math.max(0, Math.floor((new Date() - new Date(startAnchor)) / 1000));
    const totalMatchDurationSec = room ? (room.timePerQuestionSec || 20) : (match.timePerQuestionSec || 20);
    const matchDurationSec = Math.max(5, totalMatchDurationSec - elapsedSec);

    return res.json({
        success: true,
        status: match.status,
        matchId: match.matchId,
        matchDurationSec,
        questions: safeQuestions,
        opponent: opponent ? {
            userId: opponent.userId,
            name: opponent.userName, // Just original userName without rank label
            avatar: opponent.avatar,
            speedScore: oppScore
        } : null
    });
}

// 4. Submit Answer (Speed & Accuracy Calculation Engine: Base 100 Pts + Time Bonus)
router.post('/submit-answer', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const matchId = String(req.body?.matchId || '').trim();
        const userId = String(req.body?.userId || '').trim();
        const questionId = String(req.body?.questionId || '').trim();
        const selectedOptionIndex = Number(req.body?.selectedOptionIndex);
        const timeTakenMs = Number(req.body?.timeTakenMs || 0);

        const match = await BattleMatch.findOne({ matchId });
        if (!match) {
            return res.status(404).json({ success: false, message: 'Match not found' });
        }

        if (match.status !== 'IN_PROGRESS') {
            return res.status(400).json({ success: false, message: 'Match is not in progress or already completed' });
        }

        if (!match.questions.includes(questionId)) {
            return res.status(400).json({ success: false, message: 'Invalid question: this question does not belong to the match' });
        }

        const question = await QuizQuestion.findOne({ questionId });
        if (!question) {
            return res.status(404).json({ success: false, message: 'Question not found' });
        }

        if (timeTakenMs < 300) {
            return res.status(400).json({
                success: false,
                message: 'Bot speed click rejected by anti-cheat filter'
            });
        }

        const configDoc = await BattleConfig.findOne({ key: 'battleConfig' }).lean() || {};
        const correctPoints = typeof configDoc.correctPoints === 'number' ? configDoc.correctPoints : 100;
        const wrongPoints = typeof configDoc.wrongPoints === 'number' ? configDoc.wrongPoints : -100;
        const maxBonusPoints = typeof configDoc.maxBonusPoints === 'number' ? configDoc.maxBonusPoints : 100;

        const isCorrect = (selectedOptionIndex === question.correctIndex);
        const timeTakenSec = timeTakenMs / 1000.0;
        const totalTimeLimitSec = question.timeLimitSec || 10;
        const remainingTimeSec = Math.max(0, totalTimeLimitSec - timeTakenSec);

        // Find player in players array or fallback to legacy p1/p2
        let player = null;
        if (match.players && match.players.length > 0) {
            player = match.players.find(p => p.userId === userId);
        }
        if (!player) {
            const isPlayer1 = !(match.player2 && match.player2.userId === userId);
            player = isPlayer1 ? match.player1 : match.player2;
        }

        let speedBonus = 0;
        let streakBonus = 0;
        let pointsEarned = 0;

        if (isCorrect) {
            // Speed Bonus: Proportional to remaining time over the full question timer
            speedBonus = Math.round((remainingTimeSec / totalTimeLimitSec) * maxBonusPoints);
            if (speedBonus < 10 && remainingTimeSec > 0) speedBonus = 10; // minimum +10 speed bonus

            // Streak Bonus: +25 Pts per consecutive correct answer up to +100 max
            if (player) {
                player.streakCount = (player.streakCount || 0) + 1;
                if (player.streakCount >= 2) {
                    streakBonus = Math.min(100, (player.streakCount - 1) * 25);
                }
            }

            pointsEarned = correctPoints + speedBonus + streakBonus;
        } else {
            if (player) {
                player.streakCount = 0; // Reset streak on wrong or skipped answer
            }
            if (selectedOptionIndex === -1) {
                pointsEarned = 0; // Skipped question
            } else {
                pointsEarned = wrongPoints; // Wrong answer (-100)
            }
        }

        if (player) {
            player.speedScore = Math.max(0, player.speedScore + pointsEarned);
            if (isCorrect) player.correctCount += 1;
            else if (selectedOptionIndex === -1) player.skippedCount += 1;
            else player.wrongCount += 1;
            player.totalTimeTakenSec += Math.round(timeTakenSec);

            // Also sync back to legacy properties for safety (ONLY for 1v1 matches)
            if (match.player2) {
                if (match.player1 && match.player1.userId === userId) {
                    match.player1.speedScore = player.speedScore;
                    match.player1.correctCount = player.correctCount;
                    match.player1.wrongCount = player.wrongCount;
                    match.player1.skippedCount = player.skippedCount;
                    match.player1.totalTimeTakenSec = player.totalTimeTakenSec;
                    match.markModified('player1');
                }
                if (match.player2.userId === userId) {
                    match.player2.speedScore = player.speedScore;
                    match.player2.correctCount = player.correctCount;
                    match.player2.wrongCount = player.wrongCount;
                    match.player2.skippedCount = player.skippedCount;
                    match.player2.totalTimeTakenSec = player.totalTimeTakenSec;
                    match.markModified('player2');
                }
            }
            match.markModified('players');
        }

        match.answerLogs.push({
            questionId,
            userId,
            selectedOptionIndex,
            isCorrect,
            timeTakenMs,
            speedPointsEarned: pointsEarned
        });

        await match.save();

        return res.json({
            success: true,
            isCorrect,
            pointsEarned,
            speedBonus,
            streakBonus,
            correctIndex: question.correctIndex,
            totalSpeedScore: player ? player.speedScore : 0
        });
    } catch (e) {
        console.error('🔥 Error submitting answer:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 5. Finish Match & Award Winner (Deducts Platform Cut %, Updates Weekly Leaderboard)
router.post('/finish-match', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const matchId = String(req.body?.matchId || '').trim();
        const userId = String(req.body?.userId || '').trim();

        let match = await BattleMatch.findOne({ matchId });
        if (!match) {
            return res.status(404).json({ success: false, message: 'Match not found' });
        }

        const room = await BattleRoom.findOne({ roomId: match.roomId }).lean();

        // Mark player as finished atomically to avoid concurrent write overwrites
        const isPlayer1 = match.player1 && match.player1.userId === userId;
        const isPlayer2 = match.player2 && match.player2.userId === userId;

        const updateFields = {
            $set: {
                'players.$[elem].finished': true
            }
        };

        if (isPlayer1) {
            updateFields.$set['player1.finished'] = true;
        }
        if (isPlayer2) {
            updateFields.$set['player2.finished'] = true;
        }

        const updatedMatch = await BattleMatch.findOneAndUpdate(
            { matchId },
            updateFields,
            {
                arrayFilters: [{ 'elem.userId': userId }],
                new: true
            }
        );

        if (!updatedMatch) {
            return res.status(404).json({ success: false, message: 'Match not found or updated' });
        }

        match = updatedMatch;
        const p1 = match.player1;
        const p2 = match.player2;
        const player = (match.players && match.players.length > 0)
            ? match.players.find(p => p.userId === userId)
            : (isPlayer1 ? p1 : p2);

        const targetCapacity = room ? Number(room.capacity || 2) : Number(updatedMatch.capacity || 2);
        const qCount = updatedMatch.questions ? updatedMatch.questions.length : 7;

        const now = new Date();
        const startAnchor = updatedMatch.gameStartedAt || updatedMatch.createdAt || new Date();
        const timeLimitPerQuestion = room ? Number(room.timePerQuestionSec || 20) : Number(updatedMatch.timePerQuestionSec || 20);
        const maxMatchDurationMs = (timeLimitPerQuestion + 15) * 1000; // 15 seconds buffer

        const isMatchTimedOut = (now - new Date(startAnchor)) >= maxMatchDurationMs;

        let needsSave = false;
        if (updatedMatch.players && updatedMatch.players.length > 0) {
            for (let p of updatedMatch.players) {
                const isBot = p.userId.startsWith('bot_') || p.userId === 'ai_bot_opponent';
                const shouldForceFinish = isBot || (isMatchTimedOut && !p.finished);

                if (shouldForceFinish && !p.finished) {
                    p.finished = true;
                    needsSave = true;

                    if (isBot) {
                        const botLogs = updatedMatch.answerLogs
                            .filter(log => log.userId === p.userId && (new Date(log.submittedAt) - new Date(startAnchor)) <= (timeLimitPerQuestion * 1000))
                            .sort((a, b) => new Date(a.submittedAt) - new Date(b.submittedAt));

                        let botScore = 0;
                        let botCorrect = 0;
                        let botWrong = 0;
                        let botSkipped = 0;
                        let botTime = 0;

                        botLogs.forEach(log => {
                            botScore = Math.max(0, botScore + log.speedPointsEarned);
                            if (log.isCorrect) botCorrect++;
                            else if (log.selectedOptionIndex === -1) botSkipped++;
                            else botWrong++;
                            botTime += Math.round(log.timeTakenMs / 1000);
                        });

                        p.speedScore = botScore;
                        p.correctCount = botCorrect;
                        p.wrongCount = botWrong;
                        p.skippedCount = botSkipped;
                        p.totalTimeTakenSec = botTime;
                    }

                    // Also sync to legacy player2 if it's the bot or player in 1v1
                    if (updatedMatch.player2 && (updatedMatch.player2.userId === p.userId || p.userId === 'ai_bot_opponent')) {
                        updatedMatch.player2.finished = true;
                        if (isBot) {
                            updatedMatch.player2.speedScore = p.speedScore;
                            updatedMatch.player2.correctCount = p.correctCount;
                            updatedMatch.player2.wrongCount = p.wrongCount;
                            updatedMatch.player2.skippedCount = p.skippedCount;
                            updatedMatch.player2.totalTimeTakenSec = p.totalTimeTakenSec;
                        }
                        updatedMatch.markModified('player2');
                    }
                }
            }
            if (needsSave) {
                updatedMatch.markModified('players');
            }
        }

        if (updatedMatch.status !== 'COMPLETED') {
            // Check if status should become completed now
            let shouldComplete = false;
            if (targetCapacity > 2) {
                const allFinished = updatedMatch.players && updatedMatch.players.length >= targetCapacity && updatedMatch.players.every(p => p.finished);
                if (allFinished) {
                    shouldComplete = true;
                }
            } else if (updatedMatch.player2 && (updatedMatch.player2.userId === 'ai_bot_opponent' || updatedMatch.player2.userId.startsWith('bot_'))) {
                shouldComplete = true;
            } else {
                if (updatedMatch.player1 && updatedMatch.player2 && updatedMatch.player1.finished && updatedMatch.player2.finished) {
                    shouldComplete = true;
                }
            }

            if (shouldComplete) {
                // Save any pending bot force-finishes FIRST to preserve database values
                if (needsSave) {
                    await updatedMatch.save();
                }

                // Atomically update status to COMPLETED to ensure only ONE request distributes prizes!
                const completedMatch = await BattleMatch.findOneAndUpdate(
                    { matchId, status: { $ne: 'COMPLETED' } },
                    { $set: { status: 'COMPLETED' } },
                    { new: true }
                );

                if (completedMatch) {
                    // WE are the request that changed it to COMPLETED. Perform the reward distribution!
                    const participants = (completedMatch.players && completedMatch.players.length > 0)
                        ? completedMatch.players
                        : [completedMatch.player1, completedMatch.player2].filter(p => p !== null);

                    // Sort players based on speedScore descending, then timeTaken ascending
                    const sortedPlayers = [...participants].sort((a, b) => {
                        if (b.speedScore !== a.speedScore) {
                            return b.speedScore - a.speedScore;
                        }
                        return a.totalTimeTakenSec - b.totalTimeTakenSec;
                    });

                    const winnerObj = sortedPlayers[0];
                    const winnerUid = winnerObj ? winnerObj.userId : '';
                    completedMatch.winnerUserId = winnerUid;

                    const rankRewards = room ? (room.rankRewards || []) : (completedMatch.rankRewards || []);

                    const rewardUser = async (uid, rewardCoins, rankNum) => {
                        if (!uid || uid === 'ai_bot_opponent' || rewardCoins <= 0) return;
                        const mongoose = require('mongoose');
                        const hasValidObjectId = mongoose.Types.ObjectId.isValid(uid);
                        const user = await User.findOneAndUpdate(
                            hasValidObjectId
                                ? { $or: [{ userId: uid }, { _id: uid }], isBlocked: { $ne: true }, account_deleted: { $ne: true } }
                                : { userId: uid, isBlocked: { $ne: true }, account_deleted: { $ne: true } },
                            { $inc: { coins: rewardCoins, totalCoins: rewardCoins }, $set: { lastActiveAt: new Date() } },
                            { new: true }
                        );
                        if (user) {
                            await RewardHistory.create({
                                appName: user.appName || '',
                                userId: user.userId,
                                provider: `Battle Rank ${rankNum} Reward`,
                                coins: Number(rewardCoins),
                                gems: 0,
                                rewardType: 'coin',
                                orderId: 'BATTLE_RANK_REWARD_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
                                createdAt: new Date(),
                            }).catch(err => console.error('⚠️ RewardHistory create warning:', err));
                        }
                    };

                    if (rankRewards && rankRewards.length > 0) {
                        for (const r of rankRewards) {
                            const playerAtRank = sortedPlayers[r.rank - 1];
                            if (playerAtRank) {
                                await rewardUser(playerAtRank.userId, r.coins, r.rank);
                            }
                        }
                    } else {
                        if (winnerUid && winnerUid !== 'ai_bot_opponent' && completedMatch.netPrizeAwarded > 0) {
                            await rewardUser(winnerUid, completedMatch.netPrizeAwarded, 1);
                        }
                    }

                    const isFreeMatch = room ? (room.entryType === 'Free') : (completedMatch.entryType === 'Free');
                    if (isFreeMatch) {
                        let configDoc = await BattleConfig.findOne({ key: { $ne: 'battleConfig' }, isActive: true }).sort({ createdAt: -1 });
                        if (!configDoc) {
                            configDoc = await BattleConfig.findOne({ key: 'battleConfig', isActive: true });
                        }

                        if (configDoc && configDoc.isActive) {
                            const matchTime = completedMatch.updatedAt || completedMatch.createdAt || new Date();
                            const startTime = configDoc.startTime ? new Date(configDoc.startTime) : null;
                            const resultTime = configDoc.nextPayoutTime ? new Date(configDoc.nextPayoutTime) : null;

                            const isAfterStart = !startTime || isNaN(startTime.getTime()) || matchTime >= startTime;
                            const isBeforeEnd = !resultTime || isNaN(resultTime.getTime()) || matchTime <= resultTime;

                            if (isAfterStart && isBeforeEnd) {
                                const cycleId = configDoc.key;
                                for (const p of sortedPlayers) {
                                    if (!p || !p.userId) continue;
                                    const isWinner = p.userId === winnerUid;

                                    await BattleLeaderboard.findOneAndUpdate(
                                        { cycleId, userId: p.userId },
                                        {
                                            $inc: {
                                                winsCount: isWinner ? 1 : 0,
                                                totalSpeedPoints: Number(p.speedScore) || 0,
                                                totalMatchesPlayed: 1
                                            },
                                            $set: {
                                                userName: p.userName || 'Player',
                                                avatar: p.avatar || '',
                                                lastMatchAt: new Date()
                                            }
                                        },
                                        { upsert: true, new: true }
                                    );
                                }
                                // Invalidate leaderboard cache so next fetch gets updated standings
                                await cacheService.delPattern('battle:leaderboard*');
                            }
                        }
                    }

                    await completedMatch.save();

                    // 🌐 S2S Outgoing Postbacks for Match Completion (Case 2)
                    for (const playerInfo of participants) {
                        if (!playerInfo.userId || playerInfo.userId === 'ai_bot_opponent') continue;
                        (async () => {
                            const user = await User.findOne({ userId: playerInfo.userId });
                            if (user && user.publisherRef && user.publisherUid) {
                                try {
                                    const triggerOutgoingPostback = require('../../services/publisherPostbackService');
                                    triggerOutgoingPostback({
                                        user,
                                        offerId: 'battle_match_complete',
                                        coins: 0,
                                        eventId: ''
                                    }).catch(err => console.error("⚠️ S2S Outgoing Postback error:", err.message));
                                } catch (loadErr) {
                                    console.error("⚠️ Failed to load publisherPostbackService:", loadErr.message);
                                }
                            }
                        })().catch(err => console.error("⚠️ Match participant S2S lookup error:", err));
                    }

                    // Update our reference object so response gets correct state
                    updatedMatch.status = 'COMPLETED';
                    updatedMatch.winnerUserId = winnerUid;
                    updatedMatch.players = completedMatch.players;
                    updatedMatch.player1 = completedMatch.player1;
                    updatedMatch.player2 = completedMatch.player2;
                }
            } else {
                // If it needs bot force finishes saved but doesn't complete yet
                if (needsSave) {
                    await updatedMatch.save();
                }
            }
        }
        const entryFeeCoins = room ? (room.entryFeeCoins || 0) : 0;
        const rankRewards = room ? (room.rankRewards || []) : [];

        const myStats = player;
        let opponentStats = null;
        if (match.players && match.players.length > 2) {
            const otherPlayers = match.players.filter(p => p.userId !== userId);
            if (otherPlayers.length > 0) {
                opponentStats = otherPlayers.reduce((prev, curr) => (prev.speedScore > curr.speedScore) ? prev : curr);
            }
        } else {
            opponentStats = isPlayer1 ? p2 : p1;
        }

        const isWinner = match.winnerUserId === userId;

        if (match.status !== 'COMPLETED') {
            return res.json({
                success: true,
                status: 'WAITING_FOR_OPPONENT',
                matchId: match.matchId,
                message: 'Waiting for opponent to finish...'
            });
        }

        // Calculate prize awarded for this specific player based on their final rank
        let finalPrizeAwarded = 0;
        let myRank = 1;

        const participants = (match.players && match.players.length > 0) ? match.players : [p1, p2].filter(p => p !== null);
        const sorted = [...participants].sort((a, b) => {
            if (b.speedScore !== a.speedScore) return b.speedScore - a.speedScore;
            return a.totalTimeTakenSec - b.totalTimeTakenSec;
        });
        const userIndex = sorted.findIndex(p => p.userId === userId);
        if (userIndex !== -1) {
            myRank = userIndex + 1;
        }

        if (rankRewards && rankRewards.length > 0) {
            finalPrizeAwarded = rankRewards.find(r => r.rank === myRank)?.coins || 0;
        } else {
            finalPrizeAwarded = (myRank === 1) ? match.netPrizeAwarded : 0;
        }

        const playerDetailsList = sorted.map((p, index) => {
            const rankNum = index + 1;
            let prize = 0;
            if (rankRewards && rankRewards.length > 0) {
                prize = rankRewards.find(r => r.rank === rankNum)?.coins || 0;
            } else {
                prize = (rankNum === 1) ? match.netPrizeAwarded : 0;
            }
            return {
                userId: p.userId,
                name: p.userName,
                avatar: p.avatar,
                score: p.speedScore,
                correctCount: p.correctCount,
                wrongCount: p.wrongCount,
                skippedCount: p.skippedCount,
                totalTimeTakenSec: p.totalTimeTakenSec,
                finished: p.finished,
                isMe: (p.userId === userId),
                prizeAwarded: prize
            };
        });

        return res.json({
            success: true,
            status: 'COMPLETED',
            isWinner: (myRank === 1),
            matchId: match.matchId,
            myStats: myStats ? {
                name: myStats.userName,
                score: myStats.speedScore,
                correctCount: myStats.correctCount,
                wrongCount: myStats.wrongCount,
                skippedCount: myStats.skippedCount,
                totalTimeTakenSec: myStats.totalTimeTakenSec,
                avatar: myStats.avatar
            } : null,
            opponentStats: opponentStats ? {
                name: opponentStats.userName,
                score: opponentStats.speedScore,
                correctCount: opponentStats.correctCount,
                wrongCount: opponentStats.wrongCount,
                skippedCount: opponentStats.skippedCount,
                totalTimeTakenSec: opponentStats.totalTimeTakenSec,
                avatar: opponentStats.avatar
            } : null,
            players: playerDetailsList,
            prizeAwarded: finalPrizeAwarded,
            entryFeeCoins
        });
    } catch (e) {
        console.error('🔥 Error finishing battle match:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 6. Fetch Leaderboard with Equal-Rank Tie-Breaker Prize Split
router.post('/leaderboard', cryptoMiddleware, async (req, res) => {
    try {
        const cacheKey = 'battle:leaderboard:active';
        const cached = await cacheService.get(cacheKey);
        if (cached) {
            return res.json(cached);
        }

        await connectMongo();
        let configDoc = await BattleConfig.findOne({ key: { $ne: 'battleConfig' }, isActive: true }).sort({ createdAt: -1 });
        if (!configDoc) {
            configDoc = await BattleConfig.findOne({ key: 'battleConfig', isActive: true });
        }

        // If no active leaderboard configuration exists
        if (!configDoc || !configDoc.isActive) {
            return res.json({
                success: true,
                isActive: false,
                message: 'No active leaderboard at this time',
                title: 'Leaderboard',
                cycleId: null,
                cycleDays: 0,
                startTime: null,
                nextPayoutTime: null,
                showWinnersOnly: false,
                rewardTiers: [],
                standings: []
            });
        }

        let config = configDoc.toObject ? configDoc.toObject() : configDoc;
        const cycleId = config.key;

        // Check if Result Time (nextPayoutTime) has passed -> Auto Reschedule & Save History Record
        const now = new Date();
        if (config.nextPayoutTime && now >= new Date(config.nextPayoutTime)) {
            const oldStart = config.startTime ? new Date(config.startTime) : new Date(Date.now() - 7 * 86400000);
            const oldPayout = new Date(config.nextPayoutTime);
            let msPeriod = oldPayout.getTime() - oldStart.getTime();
            if (isNaN(msPeriod) || msPeriod <= 0) {
                msPeriod = (config.cycleDays || 7) * 24 * 60 * 60 * 1000;
            }

            const isAutoReschedule = config.autoReschedule !== false;
            const newStartTime = new Date(config.nextPayoutTime);
            const newResultTime = new Date(newStartTime.getTime() + msPeriod);

            let lockedConfig = null;
            if (isAutoReschedule) {
                lockedConfig = await BattleConfig.findOneAndUpdate(
                    { _id: configDoc._id, nextPayoutTime: config.nextPayoutTime },
                    { $set: { startTime: newStartTime, nextPayoutTime: newResultTime } },
                    { new: true }
                );
            } else {
                lockedConfig = await BattleConfig.findOneAndUpdate(
                    { _id: configDoc._id, nextPayoutTime: config.nextPayoutTime },
                    { $set: { isActive: false } },
                    { new: true }
                );
            }

            if (lockedConfig) {
                const cycleTypeStr = config.title || 'Leaderboard';
                const existingHistory = await BattleHistory.findOne({ cycleId, startTime: config.startTime });

                if (!existingHistory) {
                    const isPointsBased = config.rankingBasis === 'points';
                    const autoSortOption = isPointsBased
                        ? { totalSpeedPoints: -1, winsCount: -1, lastMatchAt: 1 }
                        : { winsCount: -1, totalSpeedPoints: -1, lastMatchAt: 1 };
                    const rawWinners = await BattleLeaderboard.find({ cycleId }).sort(autoSortOption).limit(50).lean();
                    const historyWinners = [];
                    const configTiers = config.rewardTiers || [];
                    rawWinners.forEach((item, idx) => {
                        const r = idx + 1;
                        const tier = configTiers.find(t => r >= t.rankStart && r <= t.rankEnd);
                        if (tier) {
                            const tierPlayers = rawWinners.filter((_, i) => (i + 1) >= tier.rankStart && (i + 1) <= tier.rankEnd);
                            const shareCoins = Math.floor(tier.coins / (tierPlayers.length || 1));
                            historyWinners.push({
                                userId: item.userId,
                                userName: item.userName,
                                avatar: item.avatar,
                                rank: r,
                                winsCount: item.winsCount,
                                totalSpeedPoints: item.totalSpeedPoints,
                                coinsAwarded: shareCoins
                            });
                        }
                    });

                    const isAuto = config.autoRewardProcess === true;
                    await BattleHistory.create({
                        cycleId,
                        title: cycleTypeStr,
                        cycleType: cycleTypeStr,
                        rankingBasis: config.rankingBasis || 'wins',
                        cycleDays: config.cycleDays || 7,
                        status: isAuto ? 'APPROVED' : 'PENDING',
                        resultDeclaredAt: isAuto ? new Date() : null,
                        startTime: config.startTime,
                        nextPayoutTime: config.nextPayoutTime,
                        winners: historyWinners,
                        autoRewarded: isAuto
                    });

                    await BattleLeaderboardHistory.create({
                        cycleId: `${cycleId}_${Date.now()}`,
                        periodEnd: new Date(),
                        totalPlayers: rawWinners.length,
                        topWinnerName: historyWinners.length > 0 ? (historyWinners[0].userName || 'Player') : 'No Participants',
                        topWinnerAvatar: historyWinners.length > 0 ? (historyWinners[0].avatar || '') : '',
                        payoutStatus: isAuto ? 'PROCESSED' : 'PENDING',
                        title: cycleTypeStr,
                        cycleType: cycleTypeStr,
                        rankingBasis: config.rankingBasis || 'wins',
                        showWinnersOnly: config.showWinnersOnly === true,
                        standingsSnapshot: historyWinners
                    });

                    if (isAuto && historyWinners.length > 0) {
                        for (const w of historyWinners) {
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
                                        orderId: `leaderboard_${cycleId}_rank_${w.rank}_${Date.now()}`,
                                        timestamp: new Date()
                                    }).catch(err => console.error('Failed to log reward history for auto reward:', err));

                                    // 👑 Send Winner Prize Notification
                                    sendNotificationViaApi({
                                        title: '👑 You Won a Leaderboard Prize!',
                                        body: `Congratulations! You secured Rank #${w.rank} in "${cycleTypeStr}" and received 🪙 ${w.coinsAwarded.toLocaleString()} Coins in your wallet!`,
                                        userId: w.userId
                                    }).catch(e => console.error('Auto winner notification error:', e.message));
                                }
                            }
                        }
                    }

                    // 🏆 Broadcast Results Declared Notification to All Players
                    sendNotificationViaApi({
                        title: '🏆 Tournament Results Declared!',
                        body: `Results for "${cycleTypeStr}" are now announced! Open Leaderboard to check winners and final scores.`
                    }).catch(e => console.error('Auto results declared notification error:', e.message));
                }

                if (isAutoReschedule) {
                    await BattleLeaderboard.deleteMany({ cycleId });
                    await BattleConfig.findOneAndUpdate(
                        { key: 'battleConfig' },
                        {
                            $set: {
                                isActive: lockedConfig.isActive,
                                startTime: lockedConfig.startTime,
                                nextPayoutTime: lockedConfig.nextPayoutTime,
                                autoReschedule: lockedConfig.autoReschedule
                            }
                        }
                    );

                    // 🚀 Broadcast New Cycle Live Notification
                    sendNotificationViaApi({
                        title: '🏆 New Battle Tournament is Live!',
                        body: `New tournament cycle for "${cycleTypeStr}" has started! Play now to climb the ranks and win coins! 💰`
                    }).catch(e => console.error('Auto new cycle notification error:', e.message));
                } else {
                    await BattleConfig.deleteMany({
                        $or: [
                            { _id: configDoc._id },
                            { key: cycleId }
                        ]
                    });
                    await BattleLeaderboard.deleteMany({ cycleId });

                    const nextActive = await BattleConfig.findOne({ key: { $ne: 'battleConfig' }, isActive: true });
                    if (nextActive) {
                        await BattleConfig.findOneAndUpdate(
                            { key: 'battleConfig' },
                            {
                                $set: {
                                    startTime: nextActive.startTime,
                                    nextPayoutTime: nextActive.nextPayoutTime,
                                    isActive: true,
                                    autoReschedule: nextActive.autoReschedule !== false,
                                    title: nextActive.title,
                                    rewardTiers: nextActive.rewardTiers
                                }
                            }
                        );
                    } else {
                        await BattleConfig.findOneAndUpdate(
                            { key: 'battleConfig' },
                            { $set: { isActive: false } }
                        );
                    }
                }

                config = lockedConfig.toObject ? lockedConfig.toObject() : lockedConfig;
            } else {
                const freshConfig = await BattleConfig.findOne({ _id: configDoc._id });
                if (freshConfig) {
                    config = freshConfig.toObject ? freshConfig.toObject() : freshConfig;
                }
            }
        }

        const rewardTiers = config.rewardTiers || [];
        const showWinnersOnly = config.showWinnersOnly === true;

        const bannedUsers = await User.find({ isLeaderboardBanned: true }, { userId: 1 }).lean();
        const bannedUserIds = bannedUsers.map(u => u.userId);

        const queryFilter = {
            cycleId,
            userId: { $nin: bannedUserIds }
        };

        const isPointsBased = config.rankingBasis === 'points';
        if (showWinnersOnly) {
            if (isPointsBased) {
                queryFilter.totalSpeedPoints = { $gt: 0 };
            } else {
                queryFilter.winsCount = { $gt: 0 };
            }
        }

        const sortOption = isPointsBased
            ? { totalSpeedPoints: -1, winsCount: -1, lastMatchAt: 1 }
            : { winsCount: -1, totalSpeedPoints: -1, lastMatchAt: 1 };

        const rawStandings = await BattleLeaderboard.find(queryFilter)
            .sort(sortOption)
            .limit(100)
            .lean();

        // Assign sequential ranks
        const standings = rawStandings.map((item, idx) => ({
            rank: idx + 1,
            userId: item.userId,
            userName: item.userName,
            avatar: item.avatar,
            winsCount: item.winsCount,
            totalSpeedPoints: item.totalSpeedPoints,
            projectedPrizeCoins: 0,
            isTied: false,
            tiedPlayerCount: 1
        }));

        // Divide tier reward coins equally among all players in that rank tier (single rank or range e.g. 2-5)
        rewardTiers.forEach(tier => {
            const playersInTier = standings.filter(p => p.rank >= tier.rankStart && p.rank <= tier.rankEnd);
            if (playersInTier.length > 0) {
                const shareCoins = Math.floor(tier.coins / playersInTier.length);
                playersInTier.forEach(p => {
                    p.projectedPrizeCoins = shareCoins;
                    p.isTied = playersInTier.length > 1;
                    p.tiedPlayerCount = playersInTier.length;
                });
            }
        });

        const responseData = {
            success: true,
            isActive: true,
            cycleId,
            title: config.title || 'Leaderboard',
            cycleDays: config.cycleDays || 7,
            startTime: config.startTime,
            nextPayoutTime: config.nextPayoutTime,
            rankingBasis: config.rankingBasis || 'points',
            showWinnersOnly,
            rewardTiers,
            standings
        };

        const ttl = cacheService.getTtl('leaderboard');
        await cacheService.set('battle:leaderboard:active', responseData, ttl);

        return res.json(responseData);
    } catch (e) {
        console.error('🔥 Error fetching battle leaderboard:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 7. Fetch Leaderboard History (All, Today, Yesterday - Max 30)
router.post('/leaderboard/history', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const filter = String(req.body?.filter || req.body?.tab || 'all').toLowerCase();

        let dateQuery = {};
        const nowUtc = new Date();
        const istOffsetMs = 5.5 * 60 * 60 * 1000;
        const nowIst = new Date(nowUtc.getTime() + istOffsetMs);

        // Start of today in IST
        const startOfTodayIst = new Date(Date.UTC(nowIst.getUTCFullYear(), nowIst.getUTCMonth(), nowIst.getUTCDate(), 0, 0, 0, 0) - istOffsetMs);
        const endOfTodayIst = new Date(Date.UTC(nowIst.getUTCFullYear(), nowIst.getUTCMonth(), nowIst.getUTCDate(), 23, 59, 59, 999) - istOffsetMs);

        // Start of yesterday in IST
        const startOfYesterdayIst = new Date(startOfTodayIst.getTime() - 24 * 60 * 60 * 1000);
        const endOfYesterdayIst = new Date(endOfTodayIst.getTime() - 24 * 60 * 60 * 1000);

        if (filter === 'today') {
            dateQuery = {
                $or: [
                    { createdAt: { $gte: startOfTodayIst, $lte: endOfTodayIst } },
                    { resultDeclaredAt: { $gte: startOfTodayIst, $lte: endOfTodayIst } }
                ]
            };
        } else if (filter === 'yesterday') {
            dateQuery = {
                $or: [
                    { createdAt: { $gte: startOfYesterdayIst, $lte: endOfYesterdayIst } },
                    { resultDeclaredAt: { $gte: startOfYesterdayIst, $lte: endOfYesterdayIst } }
                ]
            };
        }

        let records = await BattleHistory.find(dateQuery)
            .sort({ createdAt: -1 })
            .limit(30)
            .lean();

        if ((!records || records.length === 0) && filter === 'all') {
            const fallbackHistory = await BattleLeaderboardHistory.find(dateQuery)
                .sort({ createdAt: -1 })
                .limit(30)
                .lean();
            if (fallbackHistory && fallbackHistory.length > 0) {
                records = fallbackHistory.map(h => ({
                    _id: h._id,
                    cycleId: h.cycleId,
                    title: h.title || h.cycleId,
                    cycleType: h.cycleType,
                    showWinnersOnly: h.showWinnersOnly,
                    rankingBasis: h.rankingBasis,
                    status: h.status,
                    resultDeclaredAt: h.periodEnd,
                    createdAt: h.createdAt || h.periodEnd,
                    winners: (h.standingsSnapshot || []).map(s => ({
                        rank: s.rank,
                        userId: s.userId,
                        userName: s.userName,
                        avatar: s.avatar,
                        winsCount: s.winsCount,
                        totalSpeedPoints: s.totalSpeedPoints,
                        coinsAwarded: s.rewardCoins || 0
                    }))
                }));
            }
        }

        return res.json({
            success: true,
            records: (records || []).slice(0, 30).map(r => ({
                id: r._id,
                cycleId: r.cycleId,
                title: r.title || `Leaderboard Cycle`,
                cycleType: r.cycleType || 'Leaderboard',
                cycleDays: r.cycleDays || 1,
                rankingBasis: r.rankingBasis || 'points',
                showWinnersOnly: r.showWinnersOnly === true,
                status: r.status || (r.resultDeclaredAt ? 'APPROVED' : 'PENDING'), // 'PENDING', 'APPROVED', 'REJECTED'
                resultDeclaredAt: r.resultDeclaredAt ? new Date(r.resultDeclaredAt).toISOString() : null,
                createdAt: r.createdAt ? new Date(r.createdAt).toISOString() : null,
                nextPayoutTime: r.nextPayoutTime ? new Date(r.nextPayoutTime).toISOString() : null,
                winners: (r.winners || []).slice(0, 30)
            }))
        });
    } catch (e) {
        console.error('🔥 Error fetching leaderboard history:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 7. Fetch User's Match History (Joined, Completed, Cancelled)
router.post('/my-matches', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const userId = String(req.body?.userId || req.headers['user-id'] || '').trim();
        if (!userId) {
            return res.status(400).json({ success: false, message: 'Missing userId' });
        }

        // 1. Joined: matches that are WAITING where player is in players list or player1
        const joinedMatches = await BattleMatch.find({
            status: 'WAITING',
            $or: [
                { 'player1.userId': userId },
                { 'players.userId': userId }
            ]
        }).sort({ createdAt: -1 }).lean();

        // 2. Completed: matches where player is participant and status is COMPLETED
        const completedMatches = await BattleMatch.find({
            status: 'COMPLETED',
            $or: [
                { 'player1.userId': userId },
                { 'player2.userId': userId },
                { 'players.userId': userId }
            ]
        }).sort({ updatedAt: -1 }).limit(30).lean();

        // 3. Cancelled: matches where status is CANCELLED (or refunded)
        const cancelledMatches = await BattleMatch.find({
            status: 'CANCELLED',
            $or: [
                { 'player1.userId': userId },
                { 'player2.userId': userId },
                { 'players.userId': userId }
            ]
        }).sort({ updatedAt: -1 }).limit(30).lean();

        const roomCache = {};
        const getRoomEntryFee = async (roomId) => {
            if (roomCache[roomId] !== undefined) return roomCache[roomId];
            const room = await BattleRoom.findOne({ roomId }).lean();
            roomCache[roomId] = room ? (room.entryFeeCoins || 0) : 0;
            return roomCache[roomId];
        };

        const completedList = [];
        for (const m of (completedMatches || [])) {
            const entryFee = await getRoomEntryFee(m.roomId);
            completedList.push({
                matchId: m.matchId,
                roomId: m.roomId,
                title: m.title,
                player1: m.player1,
                player2: m.player2,
                winnerUserId: m.winnerUserId,
                netPrizeAwarded: m.netPrizeAwarded,
                entryFeeCoins: entryFee,
                status: m.status,
                updatedAt: m.updatedAt
            });
        }

        const cancelledList = [];
        for (const m of (cancelledMatches || [])) {
            const entryFee = await getRoomEntryFee(m.roomId);
            cancelledList.push({
                matchId: m.matchId,
                roomId: m.roomId,
                title: m.title,
                player1: m.player1,
                player2: m.player2,
                entryFeeCoins: entryFee,
                status: m.status,
                updatedAt: m.updatedAt
            });
        }

        return res.json({
            success: true,
            joined: (joinedMatches || []).map(m => ({
                sessionId: m.matchId,
                roomId: m.roomId,
                roomTitle: m.title,
                startTime: m.createdAt,
                endTime: new Date(new Date(m.createdAt).getTime() + 15000),
                secondsRemaining: Math.max(0, 15 - Math.floor((new Date() - new Date(m.createdAt)) / 1000)),
                waitingCount: 1,
                status: m.status
            })),
            completed: completedList,
            cancelled: cancelledList
        });
    } catch (e) {
        console.error('🔥 Error fetching my matches:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

module.exports = router;
