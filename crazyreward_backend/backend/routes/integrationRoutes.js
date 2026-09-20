const express = require('express');
const router = express.Router();
const connectMongo = require('../admin/middlewares/connectMongo');
const DeveloperApiKey = require('../admin/models/developerApiKey');

const crypto = require('crypto');
const User = require('../admin/models/user');
const PayoutRecord = require('../admin/models/payoutRecord');
const RewardHistory = require('../admin/models/rewardHistory');
const PostbackLogs = require('../admin/models/postbackLogs');
const ScreenshotProof = require('../admin/models/screenshotProof');
const BattleMatch = require('../battle-arena/models/battleMatch');
const DailyTask = require('../admin/models/dailyTask');
const ReadEarn = require('../admin/models/readEarn');
const Giveaway = require('../admin/models/giveaway');
const PromoCode = require('../admin/models/promoCode');
const cacheService = require('../services/cacheService');

// Security key check middleware
function validateApiKey(requiredScope) {
    return async (req, res, next) => {
        try {
            const apiKey = req.headers['x-api-key'] || req.query.api_key || req.headers['authorization']?.replace(/^Bearer\s+/i, '');
            if (!apiKey) {
                return res.status(401).json({ 
                    success: false, 
                    message: 'API Key is missing. Pass it in x-api-key header, Authorization header, or api_key query parameter.' 
                });
            }

            await connectMongo();
            const keyDoc = await DeveloperApiKey.findOne({ apiKey, isActive: true });
            if (!keyDoc) {
                return res.status(401).json({ success: false, message: 'Invalid, inactive or revoked API Key.' });
            }

            const scopes = Array.isArray(keyDoc.scopes) ? keyDoc.scopes : [];
            const isAuthorized = scopes.includes(requiredScope) ||
                (requiredScope.startsWith('tasks_') && (scopes.includes('tasks_manage') || scopes.includes('*')));

            if (!isAuthorized) {
                return res.status(403).json({ 
                    success: false, 
                    message: `Access denied. Active API key does not have the '${requiredScope}' permission scope.` 
                });
            }

            req.apiKeyDoc = keyDoc;
            next();
        } catch (err) {
            console.error('❌ Integration API Auth Error:', err);
            return res.status(500).json({ success: false, message: 'Internal Server Error' });
        }
    };
}

// 1. App Overview & Analytics aggregates
router.get('/app-analytics', async (req, res, next) => {
    const middleware = await validateApiKey('app_analytics');
    return middleware(req, res, next);
}, async (req, res) => {
    try {
        const totalUsers = await User.countDocuments();
        
        const startOfToday = new Date();
        startOfToday.setHours(0,0,0,0);
        const activeToday = await User.countDocuments({ lastActiveAt: { $gte: startOfToday } });
        const usersToday = await User.countDocuments({ firstLogin: { $gte: startOfToday } });

        const balanceAggregation = await User.aggregate([
            { $group: { _id: null, totalCoins: { $sum: "$coins" }, totalGems: { $sum: "$gems" } } }
        ]);
        const coinsCirculation = balanceAggregation[0]?.totalCoins || 0;
        const gemsCirculation = balanceAggregation[0]?.totalGems || 0;

        const totalPayoutsCount = await PayoutRecord.countDocuments();
        const pendingPayoutsCount = await PayoutRecord.countDocuments({ status: 'pending' });

        const payoutsAggregation = await PayoutRecord.aggregate([
            { $group: { _id: "$status", count: { $sum: 1 }, totalAmount: { $sum: "$amount" } } }
        ]);

        return res.json({
            success: true,
            timestamp: new Date(),
            summary: {
                totalUsers,
                usersRegisteredToday: usersToday,
                activeUsersToday: activeToday,
                coinsInCirculation: coinsCirculation,
                gemsInCirculation: gemsCirculation,
                payoutsTotalCount: totalPayoutsCount,
                payoutsPendingCount: pendingPayoutsCount,
                payoutsSummaryList: payoutsAggregation.map(item => ({
                    status: item._id,
                    count: item.count,
                    totalValue: item.totalAmount
                }))
            }
        });
    } catch (err) {
        console.error('❌ app-analytics API error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 2. User Accounts Profiles
router.get('/user-data', async (req, res, next) => {
    const middleware = await validateApiKey('user_data');
    return middleware(req, res, next);
}, async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 50, 200);
        const page = Math.max(parseInt(req.query.page) || 1, 1);
        const skip = (page - 1) * limit;

        const query = {};
        if (req.query.userId) query.uid = req.query.userId;
        if (req.query.gaid) query.gaid = req.query.gaid;
        if (req.query.isBlocked) query.isBlocked = req.query.isBlocked === 'true';

        const usersList = await User.find(query)
            .select('uid name email coins gems isBlocked isGuest firstLogin lastActiveAt physicalDeviceId physicalDeviceName source publisherRef publisherUid gaid')
            .skip(skip)
            .limit(limit)
            .sort({ firstLogin: -1 })
            .lean();

        const totalCount = await User.countDocuments(query);

        return res.json({
            success: true,
            page,
            limit,
            total: totalCount,
            data: usersList
        });
    } catch (err) {
        console.error('❌ user-data API error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 3. Redemptions/Payouts history logs
router.get('/payout-history', async (req, res, next) => {
    const middleware = await validateApiKey('payout_history');
    return middleware(req, res, next);
}, async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 50, 200);
        const page = Math.max(parseInt(req.query.page) || 1, 1);
        const skip = (page - 1) * limit;

        const query = {};
        if (req.query.userId) query.userId = req.query.userId;
        if (req.query.status) query.status = req.query.status;

        const payoutsList = await PayoutRecord.find(query)
            .skip(skip)
            .limit(limit)
            .sort({ timestamp: -1 })
            .lean();

        const totalCount = await PayoutRecord.countDocuments(query);

        return res.json({
            success: true,
            page,
            limit,
            total: totalCount,
            data: payoutsList
        });
    } catch (err) {
        console.error('❌ payout-history API error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 4. Reward history coin logs
router.get('/reward-history', async (req, res, next) => {
    const middleware = await validateApiKey('reward_history');
    return middleware(req, res, next);
}, async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 50, 200);
        const page = Math.max(parseInt(req.query.page) || 1, 1);
        const skip = (page - 1) * limit;

        const query = {};
        if (req.query.userId) query.userId = req.query.userId;
        if (req.query.provider) query.provider = req.query.provider;

        const rewardsList = await RewardHistory.find(query)
            .skip(skip)
            .limit(limit)
            .sort({ timestamp: -1 })
            .lean();

        const totalCount = await RewardHistory.countDocuments(query);

        return res.json({
            success: true,
            page,
            limit,
            total: totalCount,
            data: rewardsList
        });
    } catch (err) {
        console.error('❌ reward-history API error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 5. Offerwall postback completion logs
router.get('/offerwall-history', async (req, res, next) => {
    const middleware = await validateApiKey('offerwall_history');
    return middleware(req, res, next);
}, async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 50, 200);
        const page = Math.max(parseInt(req.query.page) || 1, 1);
        const skip = (page - 1) * limit;

        const query = {};
        if (req.query.userId) query.userId = req.query.userId;
        if (req.query.offerId) query.offerId = req.query.offerId;

        const postbackLogsList = await PostbackLogs.find(query)
            .skip(skip)
            .limit(limit)
            .sort({ completedAt: -1 })
            .lean();

        const totalCount = await PostbackLogs.countDocuments(query);

        return res.json({
            success: true,
            page,
            limit,
            total: totalCount,
            data: postbackLogsList
        });
    } catch (err) {
        console.error('❌ offerwall-history API error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 6. Super Offer screenshot proofs history
router.get('/super-offer-history', async (req, res, next) => {
    const middleware = await validateApiKey('super_offer_history');
    return middleware(req, res, next);
}, async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 50, 200);
        const page = Math.max(parseInt(req.query.page) || 1, 1);
        const skip = (page - 1) * limit;

        const query = {};
        if (req.query.userId) query.userId = req.query.userId;
        if (req.query.status) query.status = req.query.status;

        const proofs = await ScreenshotProof.find(query)
            .skip(skip)
            .limit(limit)
            .sort({ createdAt: -1 })
            .lean();

        const totalCount = await ScreenshotProof.countDocuments(query);

        return res.json({
            success: true,
            page,
            limit,
            total: totalCount,
            data: proofs
        });
    } catch (err) {
        console.error('❌ super-offer-history API error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 7. Battle Arena matches & leaderboard statistics
router.get('/battle-arena-stats', async (req, res, next) => {
    const middleware = await validateApiKey('battle_arena_stats');
    return middleware(req, res, next);
}, async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit) || 50, 200);
        const page = Math.max(parseInt(req.query.page) || 1, 1);
        const skip = (page - 1) * limit;

        const query = {};
        if (req.query.status) query.status = req.query.status;

        const matches = await BattleMatch.find(query)
            .skip(skip)
            .limit(limit)
            .sort({ createdAt: -1 })
            .lean();

        const totalCount = await BattleMatch.countDocuments(query);

        return res.json({
            success: true,
            page,
            limit,
            total: totalCount,
            data: matches
        });
    } catch (err) {
        console.error('❌ battle-arena-stats API error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// =========================================================================
// 8. TASKS CRUD API (Fetch, Create, Edit, Delete)
// =========================================================================

// 8.1 Fetch Tasks (GET /api/integrations/tasks or /api/tasks)
router.get('/tasks', validateApiKey('tasks_read'), async (req, res) => {
    try {
        const page = Math.max(parseInt(req.query.page) || 1, 1);
        const limit = Math.min(Math.max(parseInt(req.query.limit) || 20, 1), 100);
        const skip = (page - 1) * limit;

        const query = {};
        if (req.query.offerType) {
            query.offerType = req.query.offerType;
        }
        if (req.query.offerCategory) {
            query.offerCategory = req.query.offerCategory;
        }
        if (req.query.provider) {
            query.provider = req.query.provider;
        }
        if (req.query.country) {
            query.countries = { $in: [req.query.country.toUpperCase(), 'ALL'] };
        }
        if (req.query.search || req.query.q) {
            const term = String(req.query.search || req.query.q).trim();
            query.$or = [
                { offerName: { $regex: term, $options: 'i' } },
                { offerId: { $regex: term, $options: 'i' } },
                { provider: { $regex: term, $options: 'i' } }
            ];
        }

        const [tasks, total] = await Promise.all([
            DailyTask.find(query).skip(skip).limit(limit).sort({ createdAt: -1 }).lean(),
            DailyTask.countDocuments(query)
        ]);

        return res.json({
            success: true,
            page,
            limit,
            total,
            totalPages: Math.ceil(total / limit),
            data: tasks
        });
    } catch (err) {
        console.error('❌ Error fetching tasks via API:', err);
        return res.status(500).json({ success: false, message: err.message || 'Internal Server Error' });
    }
});

// 8.2 Get Single Task Details (GET /api/integrations/tasks/:id)
router.get('/tasks/:id', validateApiKey('tasks_read'), async (req, res) => {
    try {
        const id = req.params.id;
        const task = await DailyTask.findOne({
            $or: [
                { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null },
                { offerId: id }
            ]
        }).lean();

        if (!task) {
            return res.status(404).json({ success: false, message: 'Task not found' });
        }

        return res.json({ success: true, data: task });
    } catch (err) {
        console.error('❌ Error fetching task details via API:', err);
        return res.status(500).json({ success: false, message: err.message || 'Internal Server Error' });
    }
});

// 8.3 Add New Task (POST /api/integrations/tasks)
router.post('/tasks', validateApiKey('tasks_create'), async (req, res) => {
    try {
        const b = req.body || {};

        if (!b.offerName || String(b.offerName).trim() === '') {
            return res.status(400).json({ success: false, message: 'Field offerName is required' });
        }
        if (!b.imagePath || String(b.imagePath).trim() === '') {
            return res.status(400).json({ success: false, message: 'Field imagePath is required' });
        }

        // Parse offerDescription
        let desc = [];
        if (Array.isArray(b.offerDescription)) {
            desc = b.offerDescription.map(s => String(s || '').trim()).filter(Boolean);
        } else if (typeof b.offerDescription === 'string') {
            desc = b.offerDescription.split(/[\n,]+/).map(s => s.trim()).filter(Boolean);
        }
        if (desc.length === 0) {
            desc = ['Complete the required instructions in the app', 'Submit proof to receive coins'];
        }

        // Parse countries
        let countries = ['ALL'];
        if (Array.isArray(b.countries) && b.countries.length > 0) {
            countries = b.countries.map(c => String(c).trim().toUpperCase()).filter(Boolean);
        } else if (typeof b.countries === 'string' && b.countries.trim()) {
            countries = b.countries.split(/[\n,]+/).map(c => c.trim().toUpperCase()).filter(Boolean);
        }

        // Auto generate offerId if omitted
        let offerId = String(b.offerId || '').trim();
        if (!offerId) {
            offerId = 'dt_' + Date.now() + '_' + crypto.randomBytes(3).toString('hex');
        }

        // Generate secretKey
        const secretKey = 'dp_sec_' + crypto.randomBytes(16).toString('hex');

        const newTask = new DailyTask({
            offerId,
            offerName: String(b.offerName).trim(),
            provider: String(b.provider || 'DailyTask').trim(),
            offerType: String(b.offerType || 'DailyTask').trim(),
            offerCategory: String(b.offerCategory || 'App').trim(),
            imagePath: String(b.imagePath).trim(),
            bannerPath: String(b.bannerPath || '').trim(),
            clickUrl: String(b.clickUrl || '').trim(),
            coins: Number(b.coins) || 0,
            payout: Number(b.payout) || 0,
            offerDescription: desc,
            offerDisclaimer: Array.isArray(b.offerDisclaimer) ? b.offerDisclaimer : (b.offerDisclaimer ? [b.offerDisclaimer] : []),
            subDescription: String(b.subDescription || '').trim(),
            countries,
            trackingTime: Number(b.trackingTime) || 0,
            dailyCapLimit: Number(b.dailyCapLimit) || 0,
            lifetimeCapLimit: Number(b.lifetimeCapLimit) || 0,
            dailyCapCount: 0,
            postbackCount: 0,
            packageName: String(b.packageName || '').trim(),
            packageEnabled: b.packageEnabled === true || b.packageEnabled === 'true',
            dailyReset: b.dailyReset === true || b.dailyReset === 'true',
            screenshotVerificationEnabled: b.screenshotVerificationEnabled === true || b.screenshotVerificationEnabled === 'true',
            events: Array.isArray(b.events) ? b.events : [],
            color: String(b.color || '#2563eb').trim(),
            rating: String(b.rating || '4.5').trim(),
            downloads: String(b.downloads || '10K+').trim(),
            watchTutorial: String(b.watchTutorial || '').trim(),
            secretKey: b.secretKey || secretKey
        });

        await newTask.save();
        try { await cacheService.delPattern('tasks:*'); } catch (_) {}
        try { await cacheService.del('global:appData'); } catch (_) {}

        return res.status(201).json({
            success: true,
            message: 'Task created successfully',
            data: newTask
        });
    } catch (err) {
        console.error('❌ Error creating task via API:', err);
        if (err && err.code === 11000) {
            return res.status(409).json({ success: false, message: 'An offer with this offerId already exists.' });
        }
        return res.status(500).json({ success: false, message: err.message || 'Internal Server Error' });
    }
});

// 8.4 Edit Task (PUT /api/integrations/tasks/:id or PATCH)
router.put('/tasks/:id', validateApiKey('tasks_update'), async (req, res) => {
    try {
        const id = req.params.id;
        const b = req.body || {};

        const filter = {
            $or: [
                { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null },
                { offerId: id }
            ]
        };

        const existing = await DailyTask.findOne(filter);
        if (!existing) {
            return res.status(404).json({ success: false, message: 'Task not found' });
        }

        if (b.offerName !== undefined) existing.offerName = String(b.offerName).trim();
        if (b.provider !== undefined) existing.provider = String(b.provider).trim();
        if (b.offerType !== undefined) existing.offerType = String(b.offerType).trim();
        if (b.offerCategory !== undefined) existing.offerCategory = String(b.offerCategory).trim();
        if (b.imagePath !== undefined) existing.imagePath = String(b.imagePath).trim();
        if (b.bannerPath !== undefined) existing.bannerPath = String(b.bannerPath).trim();
        if (b.clickUrl !== undefined) existing.clickUrl = String(b.clickUrl).trim();
        if (b.coins !== undefined) existing.coins = Number(b.coins) || 0;
        if (b.payout !== undefined) existing.payout = Number(b.payout) || 0;
        if (b.trackingTime !== undefined) existing.trackingTime = Number(b.trackingTime) || 0;
        if (b.dailyCapLimit !== undefined) existing.dailyCapLimit = Number(b.dailyCapLimit) || 0;
        if (b.lifetimeCapLimit !== undefined) existing.lifetimeCapLimit = Number(b.lifetimeCapLimit) || 0;
        if (b.subDescription !== undefined) existing.subDescription = String(b.subDescription).trim();
        if (b.rating !== undefined) existing.rating = String(b.rating).trim();
        if (b.downloads !== undefined) existing.downloads = String(b.downloads).trim();
        if (b.watchTutorial !== undefined) existing.watchTutorial = String(b.watchTutorial).trim();
        if (b.color !== undefined) existing.color = String(b.color).trim();
        if (b.packageName !== undefined) existing.packageName = String(b.packageName).trim();
        if (b.packageEnabled !== undefined) existing.packageEnabled = b.packageEnabled === true || b.packageEnabled === 'true';
        if (b.dailyReset !== undefined) existing.dailyReset = b.dailyReset === true || b.dailyReset === 'true';
        if (b.screenshotVerificationEnabled !== undefined) existing.screenshotVerificationEnabled = b.screenshotVerificationEnabled === true || b.screenshotVerificationEnabled === 'true';

        if (b.offerDescription !== undefined) {
            if (Array.isArray(b.offerDescription)) {
                existing.offerDescription = b.offerDescription.map(s => String(s || '').trim()).filter(Boolean);
            } else if (typeof b.offerDescription === 'string') {
                existing.offerDescription = b.offerDescription.split(/[\n,]+/).map(s => s.trim()).filter(Boolean);
            }
        }
        if (b.offerDisclaimer !== undefined) {
            existing.offerDisclaimer = Array.isArray(b.offerDisclaimer) ? b.offerDisclaimer : (b.offerDisclaimer ? [b.offerDisclaimer] : []);
        }
        if (b.countries !== undefined) {
            if (Array.isArray(b.countries)) {
                existing.countries = b.countries.map(c => String(c).trim().toUpperCase()).filter(Boolean);
            } else if (typeof b.countries === 'string') {
                existing.countries = b.countries.split(/[\n,]+/).map(c => c.trim().toUpperCase()).filter(Boolean);
            }
        }
        if (b.events !== undefined && Array.isArray(b.events)) {
            existing.events = b.events;
        }

        await existing.save();
        try { await cacheService.delPattern('tasks:*'); } catch (_) {}
        try { await cacheService.del('global:appData'); } catch (_) {}

        return res.json({
            success: true,
            message: 'Task updated successfully',
            data: existing
        });
    } catch (err) {
        console.error('❌ Error updating task via API:', err);
        return res.status(500).json({ success: false, message: err.message || 'Internal Server Error' });
    }
});

// Support PATCH as well
router.patch('/tasks/:id', validateApiKey('tasks_update'), async (req, res) => {
    const middleware = validateApiKey('tasks_update');
    return middleware(req, res, () => {
        // Forward to put handler
        req.method = 'PUT';
        return router.handle(req, res);
    });
});

// 8.5 Delete Task (DELETE /api/integrations/tasks/:id)
router.delete('/tasks/:id', validateApiKey('tasks_delete'), async (req, res) => {
    try {
        const id = req.params.id;
        const filter = {
            $or: [
                { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null },
                { offerId: id }
            ]
        };

        const deleted = await DailyTask.findOneAndDelete(filter);
        if (!deleted) {
            return res.status(404).json({ success: false, message: 'Task not found' });
        }

        try { await cacheService.delPattern('tasks:*'); } catch (_) {}
        try { await cacheService.del('global:appData'); } catch (_) {}

        return res.json({
            success: true,
            message: 'Task deleted successfully',
            deletedOfferId: deleted.offerId
        });
    } catch (err) {
        console.error('❌ Error deleting task via API:', err);
        return res.status(500).json({ success: false, message: err.message || 'Internal Server Error' });
    }
});

// =========================================================================
// 9. READ & EARN ARTICLES API
// =========================================================================
router.get('/read-earn', validateApiKey('read_earn_manage'), async (req, res) => {
    try {
        const doc = await ReadEarn.findOne().lean();
        return res.json({
            success: true,
            limits: doc?.limits || 0,
            enabled: doc?.enabled !== false,
            data: doc?.urlsList || []
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

router.post('/read-earn', validateApiKey('read_earn_manage'), async (req, res) => {
    try {
        const { url, payout, trackingTime, verificationEnabled, verificationTitle, verificationDomain } = req.body;
        if (!url) return res.status(400).json({ success: false, message: 'URL is required' });

        let doc = await ReadEarn.findOne();
        if (!doc) doc = new ReadEarn({ limits: 10, urlsList: [] });

        doc.urlsList.push({
            url: String(url).trim(),
            payout: Number(payout) || 0,
            trackingTime: Number(trackingTime) || 0,
            verificationEnabled: verificationEnabled === true || verificationEnabled === 'true',
            verificationTitle: String(verificationTitle || '').trim(),
            verificationDomain: String(verificationDomain || '').trim()
        });

        await doc.save();
        try { await cacheService.del('global:appData'); } catch (_) {}
        return res.status(201).json({ success: true, message: 'Article URL added', data: doc.urlsList[doc.urlsList.length - 1] });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

router.delete('/read-earn/:id', validateApiKey('read_earn_manage'), async (req, res) => {
    try {
        const doc = await ReadEarn.findOne();
        if (!doc) return res.status(404).json({ success: false, message: 'ReadEarn config not found' });
        doc.urlsList = doc.urlsList.filter(u => u._id.toString() !== req.params.id);
        await doc.save();
        try { await cacheService.del('global:appData'); } catch (_) {}
        return res.json({ success: true, message: 'Article removed' });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// =========================================================================
// 10. GIVEAWAYS API
// =========================================================================
router.get('/giveaways', validateApiKey('giveaways_manage'), async (req, res) => {
    try {
        const giveaways = await Giveaway.find().sort({ createdAt: -1 }).lean();
        return res.json({ success: true, data: giveaways });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

router.post('/giveaways', validateApiKey('giveaways_manage'), async (req, res) => {
    try {
        const b = req.body;
        if (!b.title) return res.status(400).json({ success: false, message: 'Title is required' });

        const giveaway = new Giveaway({
            giveawayId: b.giveawayId || 'gw_' + Date.now() + '_' + crypto.randomBytes(3).toString('hex'),
            title: String(b.title).trim(),
            description: String(b.description || '').trim(),
            image: String(b.image || '').trim(),
            prizeCoins: Number(b.prizeCoins) || 100,
            totalSlots: Number(b.totalSlots) || 100,
            endDate: b.endDate ? new Date(b.endDate) : new Date(Date.now() + 86400000 * 7),
            status: 'active'
        });
        await giveaway.save();
        return res.status(201).json({ success: true, message: 'Giveaway created', data: giveaway });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

router.delete('/giveaways/:id', validateApiKey('giveaways_manage'), async (req, res) => {
    try {
        const id = req.params.id;
        await Giveaway.findOneAndDelete({
            $or: [
                { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null },
                { giveawayId: id }
            ]
        });
        return res.json({ success: true, message: 'Giveaway deleted' });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// =========================================================================
// 11. PROMO CODES API
// =========================================================================
router.get('/promo-codes', validateApiKey('promo_codes_manage'), async (req, res) => {
    try {
        const codes = await PromoCode.find().sort({ createdAt: -1 }).lean();
        return res.json({ success: true, data: codes });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

router.post('/promo-codes', validateApiKey('promo_codes_manage'), async (req, res) => {
    try {
        const { code, reward, coins, maxRedemptions } = req.body;
        if (!code) return res.status(400).json({ success: false, message: 'Code is required' });
        const rewardCoins = Number(reward || coins) || 0;
        const promo = new PromoCode({
            code: String(code).trim().toUpperCase(),
            reward: rewardCoins,
            maxRedemptions: Number(maxRedemptions) || 100,
            active: true
        });
        await promo.save();
        return res.status(201).json({ success: true, message: 'Promo code created', data: promo });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

router.delete('/promo-codes/:id', validateApiKey('promo_codes_manage'), async (req, res) => {
    try {
        const id = req.params.id;
        await PromoCode.findOneAndDelete({
            $or: [
                { _id: id.match(/^[0-9a-fA-F]{24}$/) ? id : null },
                { code: String(id).toUpperCase() }
            ]
        });
        return res.json({ success: true, message: 'Promo code deleted' });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

module.exports = router;
