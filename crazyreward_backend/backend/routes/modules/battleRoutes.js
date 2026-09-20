const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const cryptoMiddleware = require('../../admin/middlewares/cryptoMiddleware');
const antiReplayMiddleware = require('../../admin/middlewares/antiReplayMiddleware');

const BattleConfig = require('../../admin/models/battleConfig');
const QuizQuestion = require('../../admin/models/quizQuestion');
const BattleRoom = require('../../admin/models/battleRoom');
const BattleMatch = require('../../admin/models/battleMatch');
const BattleLeaderboard = require('../../admin/models/battleLeaderboard');
const User = require('../../admin/models/user');
const cacheService = require('../../services/cacheService');

// Helper to get active cycle ID (e.g. "cycle_2026_w32")
function getCurrentCycleId() {
    const now = new Date();
    const startOfYear = new Date(now.getFullYear(), 0, 1);
    const pastDays = Math.floor((now - startOfYear) / (24 * 60 * 60 * 1000));
    const weekNumber = Math.ceil((pastDays + startOfYear.getDay() + 1) / 7);
    return `cycle_${now.getFullYear()}_w${weekNumber}`;
}

// 1. Fetch Active Battle Rooms & Config
router.post('/active-rooms', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        let config = await BattleConfig.findOne({ key: 'battleConfig' }).lean();
        if (!config) {
            config = await BattleConfig.create({ key: 'battleConfig' });
        }

        const rooms = await BattleRoom.find({ status: 'Active' }).sort({ entryFeeCoins: 1 }).lean();

        return res.json({
            success: true,
            config: {
                isActive: config.isActive,
                cycleDays: config.cycleDays,
                platformCommissionFee: config.platformCommissionFee,
                freeRoomAdMandate: config.freeRoomAdMandate,
                nextPayoutTime: config.nextPayoutTime,
                rewardTiers: config.rewardTiers,
                terms: config.terms || []
            },
            rooms: rooms
        });
    } catch (e) {
        console.error('🔥 Error fetching battle rooms:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 2. Join Battle Room (Deducts entry fee / Verifies Ad Watch / Anti-Self-Match IP Check)
router.post('/join-room', cryptoMiddleware, antiReplayMiddleware, async (req, res) => {
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

        const room = await BattleRoom.findOne({ roomId, status: 'Active' });
        if (!room) {
            return res.status(404).json({ success: false, message: 'Battle room not found or closed' });
        }

        const config = await BattleConfig.findOne({ key: 'battleConfig' }).lean() || {};

        // Free room ad mandate check
        if (room.entryType === 'Free' && config.freeRoomAdMandate && !adVerifiedToken) {
            return res.status(400).json({
                success: false,
                requiresAd: true,
                message: 'Mandatory rewarded ad watch required before joining free room'
            });
        }

        // Fetch User and check coin balance for Paid rooms
        const user = await User.findOne({ $or: [{ userId }, { _id: userId }] });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User account not found' });
        }

        if (room.entryType === 'Paid') {
            if ((user.coins || 0) < room.entryFeeCoins) {
                return res.status(400).json({
                    success: false,
                    message: `Insufficient coin balance! Entry fee is ${room.entryFeeCoins} Coins.`
                });
            }

            // Deduct entry fee
            user.coins = Math.max(0, (user.coins || 0) - room.entryFeeCoins);
            await user.save();
        }

        // Anti-Cheat & Guest Separation: Prevent matching with same User ID, same Device ID, same IP address, and never match guest with real user!
        const isGuest = Boolean(user.isGuest === true || user.isAnonymous === true);
        const cleanDeviceId = String(deviceId || user.deviceId || '').trim();
        const matchQuery = {
            roomId: room.roomId,
            status: 'MATCHING',
            'player1.userId': { $ne: userId }
        };

        if (isGuest) {
            matchQuery.isGuestMatch = true;
            matchQuery['player1.isGuest'] = { $ne: false };
        } else {
            matchQuery.isGuestMatch = { $ne: true };
            matchQuery['player1.isGuest'] = { $ne: true };
        }

        if (cleanDeviceId && cleanDeviceId !== 'ai_bot_device') {
            matchQuery['player1.deviceId'] = { $ne: cleanDeviceId };
        }

        if (clientIp && clientIp !== '127.0.0.1' && clientIp !== '::1' && !clientIp.startsWith('127.')) {
            matchQuery['player1.ipAddress'] = { $ne: clientIp };
        }

        let match = await BattleMatch.findOne(matchQuery).sort({ createdAt: 1 });

        if (match) {
            // Pair as Player 2!
            match.player2 = {
                userId: userId,
                userName: user.name || user.email?.split('@')[0] || (isGuest ? 'Guest Player' : 'Player 2'),
                avatar: user.profilePic || '',
                ipAddress: clientIp,
                deviceId: deviceId,
                adVerified: !!adVerifiedToken,
                isGuest: isGuest,
                speedScore: 0,
                correctCount: 0,
                wrongCount: 0,
                skippedCount: 0,
                totalTimeTakenSec: 0,
                forfeited: false
            };
            match.status = 'IN_PROGRESS';
            await match.save();

            return res.json({
                success: true,
                matched: true,
                matchId: match.matchId,
                status: 'IN_PROGRESS',
                opponent: {
                    userId: match.player1.userId,
                    name: match.player1.userName,
                    avatar: match.player1.avatar
                }
            });
        } else {
            // Fetch Quiz Questions for this match (Redis Cached)
            const cacheKey = 'quiz:bank:active';
            let questions = await cacheService.get(cacheKey);
            if (!questions || !questions.length) {
                questions = await QuizQuestion.find({ active: true }).lean();
                if (!questions || !questions.length) {
                    questions = await QuizQuestion.find({}).lean();
                }
                if (questions && questions.length > 0) {
                    await cacheService.set(cacheKey, questions, cacheService.getTtl('global'));
                }
            }

            const selectedQuestions = (questions || []).slice(0, room.questionCount || 10);
            const questionIds = selectedQuestions.map(q => q.questionId);

            // Create new Matchmaker Entry as Player 1
            const newMatchId = `match_${Date.now()}_${Math.floor(Math.random() * 8999 + 1000)}`;
            const newMatch = await BattleMatch.create({
                matchId: newMatchId,
                roomId: room.roomId,
                title: room.title,
                isGuestMatch: isGuest,
                adType: room.adType || 'None',
                skipAdMatches: room.skipAdMatches || 0,
                player1: {
                    userId: userId,
                    userName: user.name || user.email?.split('@')[0] || (isGuest ? 'Guest Player' : 'Player 1'),
                    avatar: user.profilePic || '',
                    ipAddress: clientIp,
                    deviceId: deviceId,
                    adVerified: !!adVerifiedToken,
                    isGuest: isGuest,
                    speedScore: 0,
                    correctCount: 0,
                    wrongCount: 0,
                    skippedCount: 0,
                    totalTimeTakenSec: 0,
                    forfeited: false
                },
                questions: questionIds,
                status: 'MATCHING',
                platformFeeEarned: room.entryType === 'Paid' ? (room.entryFeeCoins * 2 * (room.platformCutPercent / 100)) : 0,
                netPrizeAwarded: room.entryType === 'Paid' ? room.netPrizePoolCoins : 0
            });

            return res.json({
                success: true,
                matched: false,
                matchId: newMatch.matchId,
                status: 'MATCHING'
            });
        }
    } catch (e) {
        console.error('🔥 Error joining battle room:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 3. Match Status Check & Question Fetch (Answers WITHOUT Answer Keys for Anti-Cheat)
router.post('/match-status', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const matchId = String(req.body?.matchId || '').trim();
        const userId = String(req.body?.userId || '').trim();

        const match = await BattleMatch.findOne({ matchId });
        if (!match) {
            return res.status(404).json({ success: false, message: 'Match not found' });
        }

        if (match.status === 'MATCHING') {
            return res.json({
                success: true,
                status: 'MATCHING',
                message: 'Searching for opponent...'
            });
        }

        // Fetch questions without correctIndex answer key (from Redis Cache or DB)
        const cacheKey = 'quiz:bank:active';
        let allQuestions = await cacheService.get(cacheKey);
        let questionsList = [];
        if (allQuestions && allQuestions.length > 0) {
            const qMap = new Map(allQuestions.map(q => [q.questionId, q]));
            questionsList = (match.questions || []).map(id => qMap.get(id)).filter(Boolean);
        }
        if (!questionsList || questionsList.length < (match.questions || []).length) {
            questionsList = await QuizQuestion.find({ questionId: { $in: match.questions } }).lean();
        }

        // Safe Shuffled Options without correctIndex
        const safeQuestions = questionsList.map(q => ({
            questionId: q.questionId,
            category: q.category,
            question: q.question,
            options: q.options, // 4 option strings
            timeLimitSec: q.timeLimitSec || 20
        }));

        const isPlayer1 = match.player1.userId === userId;
        const opponent = isPlayer1 ? match.player2 : match.player1;

        return res.json({
            success: true,
            status: match.status,
            matchId: match.matchId,
            questions: safeQuestions,
            opponent: opponent ? {
                userId: opponent.userId,
                name: opponent.userName,
                avatar: opponent.avatar,
                speedScore: opponent.speedScore
            } : null
        });
    } catch (e) {
        console.error('🔥 Error fetching match status:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

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

        const question = await QuizQuestion.findOne({ questionId });
        if (!question) {
            return res.status(404).json({ success: false, message: 'Question not found' });
        }

        // Anti-Cheat: Rapid Bot Click Validation (< 300 ms)
        if (timeTakenMs < 300) {
            return res.status(400).json({
                success: false,
                message: 'Bot speed click rejected by anti-cheat filter'
            });
        }

        const isCorrect = (selectedOptionIndex === question.correctIndex);
        const totalTimeLimitSec = question.timeLimitSec || 20;
        const timeTakenSec = timeTakenMs / 1000.0;
        const remainingTimeSec = Math.max(0, totalTimeLimitSec - timeTakenSec);

        // Speed Scoring Formula: Base 100 Pts + (Remaining Sec / Total Sec * 100)
        let pointsEarned = 0;
        if (isCorrect && timeTakenSec <= totalTimeLimitSec + 2) { // 2s grace margin
            const timeBonus = Math.round((remainingTimeSec / totalTimeLimitSec) * 100);
            pointsEarned = 100 + timeBonus;
        }

        // Update player score in match
        const isPlayer1 = match.player1.userId === userId;
        const player = isPlayer1 ? match.player1 : match.player2;

        if (player) {
            player.speedScore += pointsEarned;
            if (isCorrect) player.correctCount += 1;
            else if (selectedOptionIndex === -1) player.skippedCount += 1;
            else player.wrongCount += 1;
            player.totalTimeTakenSec += Math.round(timeTakenSec);
        }

        // Log Answer
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
            correctIndex: question.correctIndex,
            totalSpeedScore: player ? player.speedScore : 0
        });
    } catch (e) {
        console.error('🔥 Error submitting answer:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 5. Finish Match & Award Winner (Deducts Platform Cut %, Updates Weekly Leaderboard)
router.post('/finish-match', cryptoMiddleware, antiReplayMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const matchId = String(req.body?.matchId || '').trim();
        const userId = String(req.body?.userId || '').trim();

        const match = await BattleMatch.findOne({ matchId });
        if (!match) {
            return res.status(404).json({ success: false, message: 'Match not found' });
        }

        const p1 = match.player1;
        const p2 = match.player2;

        if (match.status !== 'COMPLETED') {
            match.status = 'COMPLETED';

            // Determine Winner based on Total Speed Score
            let winnerUid = '';
            if (p1 && p2) {
                if (p1.speedScore > p2.speedScore) winnerUid = p1.userId;
                else if (p2.speedScore > p1.speedScore) winnerUid = p2.userId;
                else winnerUid = p1.totalTimeTakenSec <= p2.totalTimeTakenSec ? p1.userId : p2.userId; // Tie-breaker by faster total time
            } else if (p1) {
                winnerUid = p1.userId;
            }

            match.winnerUserId = winnerUid;
            await match.save();

            // Award Winner Net Prize Coins for Paid Battles (Non-Guest Only)
            if (winnerUid && match.netPrizeAwarded > 0) {
                const winnerUser = await User.findOneAndUpdate(
                    {
                        $or: [{ userId: winnerUid }, { _id: winnerUid }],
                        isGuest: { $ne: true },
                        isAnonymous: { $ne: true }
                    },
                    {
                        $inc: { coins: match.netPrizeAwarded, totalCoins: match.netPrizeAwarded },
                        $set: { lastActiveAt: new Date() }
                    },
                    { new: true }
                );
                if (winnerUser) {
                    await RewardHistory.create({
                        appName: winnerUser.appName || '',
                        userId: winnerUser.userId,
                        provider: 'Battle Arena Win',
                        coins: match.netPrizeAwarded,
                        orderId: `battle_win_${match.matchId}`,
                        timestamp: new Date()
                    }).catch(() => {});
                }
            }

            // Update Weekly Leaderboard Cycle Standings (ONLY for Free entry matches & Non-Guest accounts!)
            const room = await BattleRoom.findOne({ roomId: match.roomId }).lean();
            if (room && room.entryType === 'Free') {
                const cycleId = getCurrentCycleId();
                if (winnerUid) {
                    const winnerObj = (p1 && p1.userId === winnerUid) ? p1 : p2;
                    if (winnerObj && !winnerObj.isGuest) {
                        await BattleLeaderboard.findOneAndUpdate(
                            { cycleId, userId: winnerUid },
                            {
                                $inc: { winsCount: 1, totalSpeedPoints: winnerObj ? winnerObj.speedScore : 0, totalMatchesPlayed: 1 },
                                $set: { userName: winnerObj ? winnerObj.userName : 'Player', avatar: winnerObj ? winnerObj.avatar : '', lastMatchAt: new Date() }
                            },
                            { upsert: true, new: true }
                        );
                    }
                }
            }

            // Track Daily Challenge progress for Battle Arena
            try {
                const { trackDailyChallengeProgress } = require('./dailyChallengeApiRoutes');
                if (p1 && p1.userId) trackDailyChallengeProgress(p1.userId, 'battle_arena', 1);
                if (p2 && p2.userId) trackDailyChallengeProgress(p2.userId, 'battle_arena', 1);
            } catch (_) { }
        }

        const isPlayer1 = match.player1.userId === userId;
        const myStats = isPlayer1 ? match.player1 : match.player2;
        const opponentStats = isPlayer1 ? match.player2 : match.player1;
        const isWinner = match.winnerUserId === userId;

        return res.json({
            success: true,
            isWinner,
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
            prizeAwarded: isWinner ? match.netPrizeAwarded : 0
        });
    } catch (e) {
        console.error('🔥 Error finishing battle match:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 6. Fetch Weekly Cycle Leaderboard with Equal-Rank Tie-Breaker Prize Split
router.post('/leaderboard', cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const cycleId = getCurrentCycleId();
        let config = await BattleConfig.findOne({ key: 'battleConfig' }).lean() || {};
        const rewardTiers = config.rewardTiers || [];

        // Sort users by Wins Count DESC, then totalSpeedPoints DESC
        const rawStandings = await BattleLeaderboard.find({ cycleId })
            .sort({ winsCount: -1, totalSpeedPoints: -1, lastMatchAt: 1 })
            .limit(100)
            .lean();

        // Assign ranks and calculate equal-rank tie splits
        let currentRank = 1;
        const standings = [];

        for (let i = 0; i < rawStandings.length; i++) {
            const item = rawStandings[i];

            // Check tie group with previous or next items
            const tiedGroup = rawStandings.filter(x => x.winsCount === item.winsCount && x.totalSpeedPoints === item.totalSpeedPoints);
            const isTied = tiedGroup.length > 1;

            // Find matching reward tier
            let tierCoins = 0;
            const tier = rewardTiers.find(t => currentRank >= t.rankStart && currentRank <= t.rankEnd);
            if (tier) {
                tierCoins = isTied ? Math.round(tier.coins / tiedGroup.length) : tier.coins;
            }

            standings.push({
                rank: currentRank,
                userId: item.userId,
                userName: item.userName,
                avatar: item.avatar,
                winsCount: item.winsCount,
                totalSpeedPoints: item.totalSpeedPoints,
                projectedPrizeCoins: tierCoins,
                isTied: isTied,
                tiedPlayerCount: tiedGroup.length
            });

            currentRank++;
        }

        return res.json({
            success: true,
            cycleId,
            nextPayoutTime: config.nextPayoutTime,
            standings
        });
    } catch (e) {
        console.error('🔥 Error fetching battle leaderboard:', e);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

module.exports = router;
