const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const verifyAuthToken = require('../../admin/middlewares/verifyAuthToken');
const cryptoMiddleware = require('../../admin/middlewares/cryptoMiddleware');
const Giveaway = require('../../admin/models/giveaway');

const mongoose = require('mongoose');
const cacheService = require('../../services/cacheService');

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
    const hasDeviceHeaders = Boolean(userIdHeader && (deviceIdHeader || clientKey));
    const isAdmin = Boolean(req.cookies && (req.cookies.adminToken || req.cookies.admin));

    if (hasValidKey || hasToken || hasPayload || hasDeviceHeaders || isAdmin) {
        return next();
    }
    return res.status(401).json({ success: false, message: 'Unauthorized: Authentication required' });
};

// Get Active Giveaways List
router.all(['/list', '/get-giveaways'], clientAuthMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.query.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.body?.userId || '';

        const cacheKey = 'giveaways:raw_list';
        let giveawaysMongo = await cacheService.get(cacheKey);

        if (!giveawaysMongo) {
            const now = new Date();
            const rawDocs = await Giveaway.find({}).sort({ createdAt: -1 });

            // Auto-declare due giveaways on the fly if scheduled declaresAt has passed
            for (const g of rawDocs) {
                if (g.status !== 'declared' && g.status !== 'completed' && g.declaresAt && new Date(g.declaresAt) <= now) {
                    const participants = [
                        ...(g.joinedUsers || []),
                        ...(g.participants || []),
                        ...((g.joinedHistory || []).map(h => h && h.userId).filter(Boolean))
                    ].filter((v, i, a) => v && a.indexOf(v) === i);

                    if (participants.length > 0) {
                        const rewards = g.rewards || [];
                        const numRewards = Math.min(rewards.length, participants.length);
                        const assignedRanks = g.assignedRanks || [];
                        const priorityUsers = g.priorityUsers || [];

                        const rankToUserMap = {};
                        assignedRanks.forEach(ar => {
                            if (ar && ar.rank > 0 && ar.userId && participants.includes(ar.userId)) {
                                rankToUserMap[ar.rank] = ar.userId;
                            }
                        });

                        const winnersList = [];
                        const usedUserIds = new Set();

                        for (let r = 1; r <= numRewards; r++) {
                            if (rankToUserMap[r] && !usedUserIds.has(rankToUserMap[r])) {
                                const uid = rankToUserMap[r];
                                winnersList.push({ userId: uid, rank: r });
                                usedUserIds.add(uid);
                            }
                        }

                        const remainingParticipants = participants.filter(uid => !usedUserIds.has(uid));
                        const remainingPriority = remainingParticipants.filter(uid => priorityUsers.includes(uid));

                        for (let r = 1; r <= numRewards; r++) {
                            if (winnersList.some(w => w.rank === r)) continue;

                            let winnerId = null;
                            if (remainingPriority.length > 0) {
                                const idx = Math.floor(Math.random() * remainingPriority.length);
                                winnerId = remainingPriority[idx];
                                remainingPriority.splice(idx, 1);
                                const pos = remainingParticipants.indexOf(winnerId);
                                if (pos !== -1) remainingParticipants.splice(pos, 1);
                            } else if (remainingParticipants.length > 0) {
                                const idx = Math.floor(Math.random() * remainingParticipants.length);
                                winnerId = remainingParticipants[idx];
                                remainingParticipants.splice(idx, 1);
                            }

                            if (winnerId) {
                                winnersList.push({ userId: winnerId, rank: r });
                                usedUserIds.add(winnerId);
                            }
                        }

                        g.winners = winnersList.map(w => w.userId);
                        g.winnerRanks = winnersList;
                        g.status = 'declared';
                        g.declaredAt = g.declaresAt || now;
                        await g.save();
                    }
                }
            }

            giveawaysMongo = rawDocs.map(g => (g.toObject ? g.toObject() : g));
            await cacheService.set(cacheKey, giveawaysMongo, cacheService.getTtl('global'));
        }

        const giveaways = giveawaysMongo.map(g => {
            const joinedList = g.joinedUsers || g.participants || [];
            const isUserJoined = Boolean(userId && joinedList.includes(userId));
            return {
                ...g,
                id: g.giveawayId || g._id?.toString(),
                giveawayId: g.giveawayId || g._id?.toString(),
                bannerUrl: g.bannerUrl || g.image || '',
                image: g.image || g.bannerUrl || '',
                joinedCount: joinedList.length,
                joinedUsers: joinedList,
                participants: joinedList,
                joined: isUserJoined
            };
        });

        return res.json({ success: true, giveaways });
    } catch (err) {
        console.error('❌ Get giveaways error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch giveaways' });
    }
});

// Join Giveaway Entry
router.post(['/join', '/giveaways/join'], cryptoMiddleware, verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        let { giveawayId, id, userId } = req.body || {};
        giveawayId = giveawayId || id;
        userId = userId || req.userId || req.headers['user-id'] || req.headers['x-user-id'] || '';

        if (!giveawayId) {
            return res.status(400).json({ success: false, message: 'Giveaway ID required' });
        }
        if (!userId) {
            return res.status(400).json({ success: false, message: 'User ID required' });
        }

        const isObjectId = mongoose.Types.ObjectId.isValid(giveawayId);
        const query = isObjectId
            ? { $or: [{ _id: giveawayId }, { giveawayId: giveawayId }] }
            : { giveawayId: giveawayId };

        const User = require('../../admin/models/user');
        const user = await User.findOne({ userId }).lean();
        if (user && (user.isGuest === true || user.isAnonymous === true)) {
            return res.status(403).json({ success: false, message: 'Guest accounts cannot join giveaways. Please log in with Google to continue!' });
        }

        const giveaway = await Giveaway.findOne(query);
        if (!giveaway) {
            return res.status(404).json({ success: false, message: 'Giveaway not found' });
        }

        const joinedList = giveaway.joinedUsers || giveaway.participants || [];
        if (userId && joinedList.includes(userId)) {
            return res.status(400).json({ success: false, message: 'Already joined giveaway' });
        }

        if (userId) {
            if (!giveaway.joinedUsers) giveaway.joinedUsers = [];
            if (!giveaway.joinedUsers.includes(userId)) giveaway.joinedUsers.push(userId);

            if (!giveaway.participants) giveaway.participants = [];
            if (!giveaway.participants.includes(userId)) giveaway.participants.push(userId);

            if (!giveaway.joinedHistory) giveaway.joinedHistory = [];
            const existsInHistory = giveaway.joinedHistory.some(h => h && h.userId === userId);
            if (!existsInHistory) {
                giveaway.joinedHistory.push({ userId, joinedAt: new Date() });
            }

            giveaway.joinedCount = giveaway.joinedUsers.length;
            await giveaway.save();
            try { await cacheService.del('giveaways:raw_list'); } catch (_) {}
        }

        return res.json({ success: true, message: 'Joined giveaway successfully' });
    } catch (err) {
        console.error('❌ Join giveaway error:', err);
        return res.status(500).json({ success: false, message: 'Failed to join giveaway' });
    }
});

// Get Winners List for App
router.all(['/winners', '/giveaway-winners'], clientAuthMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const giveawayId = req.query.giveawayId || req.query.id || req.body?.giveawayId || '';
        if (!giveawayId) {
            return res.status(400).json({ success: false, message: 'giveawayId is required' });
        }

        const isObjectId = mongoose.Types.ObjectId.isValid(giveawayId);
        const query = isObjectId ? { $or: [{ _id: giveawayId }, { giveawayId: giveawayId }] } : { giveawayId: giveawayId };
        const giveaway = await Giveaway.findOne(query).lean();

        if (!giveaway) {
            return res.status(404).json({ success: false, message: 'Giveaway not found' });
        }

        const winnerIds = giveaway.winners || [];
        const User = require('../../admin/models/user');
        const dbUsers = await User.find({ userId: { $in: winnerIds } }).lean();

        const userMap = {};
        dbUsers.forEach(u => {
            userMap[u.userId] = {
                name: u.displayName || u.name || 'Winner',
                email: u.email || '',
                photoUrl: u.photoUrl || '',
            };
        });

        const winnerRankMap = {};
        if (Array.isArray(giveaway.winnerRanks)) {
            giveaway.winnerRanks.forEach(wr => {
                if (wr && wr.userId) winnerRankMap[wr.userId] = wr.rank;
            });
        }

        const winnerStatusesMap = giveaway.winnerStatuses ? (giveaway.winnerStatuses instanceof Map ? Object.fromEntries(giveaway.winnerStatuses) : giveaway.winnerStatuses) : {};

        const rewards = giveaway.rewards || [];
        const rewardByRank = {};
        rewards.forEach(rw => {
            if (rw) rewardByRank[rw.productRank || 1] = rw;
        });

        const winners = winnerIds.map((uid, index) => {
            const rank = winnerRankMap[uid] || (index + 1);
            const reward = rewardByRank[rank] || rewards[index] || {};
            const isAuto = reward.autoDistribute !== false;
            const coins = Number(reward.coins) || 0;
            const defaultStatus = isAuto ? 'claimed' : (coins > 0 ? 'pending' : 'requested');
            const currentStatus = winnerStatusesMap[uid] || defaultStatus;
            return {
                userId: uid,
                name: userMap[uid]?.name || 'Winner',
                photoUrl: userMap[uid]?.photoUrl || '',
                status: currentStatus,
                reward: {
                    productName: reward.productName || (coins > 0 ? `${coins} Coins` : 'Reward'),
                    productImage: reward.productImage || '',
                    productRank: rank,
                    coins: coins,
                    autoDistribute: isAuto,
                }
            };
        });

        return res.json({ success: true, winners });
    } catch (err) {
        console.error('❌ Get winners error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch winners' });
    }
});

// Claim Giveaway Reward (Manual claim if autoDistribute is off)
router.post(['/claim-reward', '/request-claim-reward'], cryptoMiddleware, verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        let { giveawayId, id, userId } = req.body || {};
        giveawayId = giveawayId || id;
        userId = userId || req.userId || req.headers['user-id'] || req.headers['x-user-id'] || '';

        if (!giveawayId || !userId) {
            return res.status(400).json({ success: false, message: 'giveawayId and userId required' });
        }

        const isObjectId = mongoose.Types.ObjectId.isValid(giveawayId);
        const query = isObjectId ? { $or: [{ _id: giveawayId }, { giveawayId: giveawayId }] } : { giveawayId: giveawayId };

        const User = require('../../admin/models/user');
        const user = await User.findOne({ userId }).lean();
        if (user && (user.isGuest === true || user.isAnonymous === true)) {
            return res.status(403).json({ success: false, message: 'Guest accounts cannot claim giveaway rewards. Please log in with Google to continue!' });
        }

        const giveaway = await Giveaway.findOne(query);

        if (!giveaway) {
            return res.status(404).json({ success: false, message: 'Giveaway not found' });
        }

        const winners = giveaway.winners || [];
        if (!winners.includes(userId)) {
            return res.status(400).json({ success: false, message: 'You are not a winner in this giveaway' });
        }

        const winnerStatusesMap = giveaway.winnerStatuses ? (giveaway.winnerStatuses instanceof Map ? Object.fromEntries(giveaway.winnerStatuses) : giveaway.winnerStatuses) : {};
        if (winnerStatusesMap[userId] === 'claimed') {
            return res.json({
                success: true,
                response: 'success',
                message: 'Reward has already been claimed!',
                coinsClaimed: 0,
            });
        }

        // Find user winner rank
        const winnerRanks = giveaway.winnerRanks || [];
        const match = winnerRanks.find(w => w && w.userId === userId);
        const rank = match ? match.rank : (winners.indexOf(userId) + 1);

        const rewards = giveaway.rewards || [];
        const reward = rewards.find(r => r && r.productRank === rank) || rewards[0] || {};
        const coins = Number(reward.coins) || 0;

        if (coins > 0) {
            const User = require('../../admin/models/user');
            await User.updateOne(
                { userId, isBlocked: { $ne: true }, account_deleted: { $ne: true }, isGuest: { $ne: true }, isAnonymous: { $ne: true } },
                { $inc: { coins: coins, totalCoins: coins, totalEarnedCoins: coins }, $set: { lastActiveAt: new Date() } }
            );

            const RewardHistory = require('../../admin/models/rewardHistory');
            await RewardHistory.create({
                appName: giveaway.appName || '',
                userId: userId,
                provider: `Giveaway Reward (${giveaway.title || 'Giveaway'})`,
                coins: coins,
                rewardType: 'coin',
                orderId: `gw_${giveaway.giveawayId || giveaway._id}_${userId}_${Date.now()}`,
                timestamp: new Date()
            }).catch(err => console.error('⚠️ RewardHistory create warning:', err));
        }

        if (!giveaway.winnerStatuses) giveaway.winnerStatuses = new Map();
        if (giveaway.winnerStatuses instanceof Map) {
            giveaway.winnerStatuses.set(userId, 'claimed');
        } else {
            giveaway.winnerStatuses[userId] = 'claimed';
        }
        giveaway.markModified('winnerStatuses');
        await giveaway.save();

        return res.json({
            success: true,
            response: 'success',
            message: `Reward claimed successfully! Added ${coins} coins.`,
            coinsClaimed: coins,
        });
    } catch (err) {
        console.error('❌ Claim giveaway reward error:', err);
        return res.status(500).json({ success: false, message: 'Failed to claim reward' });
    }
});

module.exports = router;
