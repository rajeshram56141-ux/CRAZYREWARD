const express = require('express');
const crypto = require('crypto');
const { refreshDailyTask } = require('../admin/middlewares/autoMaintenanceJob');
const PostbackLogs = require('../admin/models/postbackLogs');
const ReadEarnLogs = require('../admin/models/readEarnLogs');
const DailyTask = require('../admin/models/dailyTask');
const PlayGames = require('../admin/models/playGames');
const ReadEarn = require('../admin/models/readEarn');
const PendingReadEarnToken = require('../admin/models/pendingReadEarnToken');
const GamePlayLogs = require('../admin/models/gamePlayLogs');
const PromotionRequest = require('../admin/models/promotionRequest');
const SupportRequest = require('../admin/models/supportRequest');
const PostbackErrorLog = require('../admin/models/postbackErrorLogs');
const User = require('../admin/models/user');
const AppData = require('../admin/models/appData');
const OffersSettings = require('../admin/models/offersSettings');
const ReferralSettings = require('../admin/models/referralSettings');
const RewardHistory = require('../admin/models/rewardHistory');
const PayoutHistory = require('../admin/models/payoutHistory');
const PayoutRecord = require('../admin/models/payoutRecord');
const WalletCatalog = require('../admin/models/walletCatalog');
const cron = require('node-cron');
const connectMongo = require('../admin/middlewares/connectMongo');
const cryptoMiddleware = require('../admin/middlewares/cryptoMiddleware');
const FirebaseService = require('../admin/models/firebaseService');
const { handleDailyTaskPostback } = require('../admin/middlewares/daily-task-postback');
const { handleReadEarnPostback } = require('../admin/middlewares/read-earn-postback');
const { getOrInitFirebase } = require('../admin/middlewares/firebase-helper');
const { Timestamp } = require('firebase-admin/firestore');
const { handlePayoutPostback, handlePayoutRoute } = require('../admin/middlewares/handle-payout');
const { FieldValue } = require('firebase-admin/firestore');
const { DateTime } = require('luxon');
const multer = require('multer');
const Tesseract = require('tesseract.js');
const ScreenshotProof = require('../admin/models/screenshotProof');
const fs = require('fs');
const path = require('path');
const upload = multer({ storage: multer.memoryStorage() });
const cacheService = require('../services/cacheService');

const router = express.Router();
const apiRoutes = require('./apiRoutes');

router.use('/api', apiRoutes);
router.use('/', apiRoutes);

const API_KEY = process.env.API_KEY;
const IST_TIMEZONE = 'Asia/Kolkata';
const APPDATA_DELAYED_KEYS = ['superOfferConfig'];

// Middleware: Secure App Auth (API Key, Bearer Token, or Encrypted Payload)
const middleware = (req, res, next) => {
    const clientKey = req.headers['x-api-key'];
    const authHeader = req.headers['authorization'];
    const userIdHeader = req.headers['x-user-id'] || req.headers['user-id'];
    const deviceIdHeader = req.headers['x-device-id'] || req.headers['device-id'];

    const hasValidApiKey = Boolean(clientKey && API_KEY && clientKey === API_KEY);
    const hasAuthToken = Boolean(authHeader && authHeader.startsWith('Bearer '));
    const hasEncryptedPayload = Boolean(req.rawPayload || req.body?.payload || req.isDecrypted);
    const hasAppDeviceHeaders = Boolean(userIdHeader && (deviceIdHeader || (clientKey && clientKey === API_KEY)));
    const isAdmin = Boolean(req.cookies && (req.cookies.adminToken || req.cookies.admin));

    if (hasValidApiKey || hasAuthToken || hasEncryptedPayload || hasAppDeviceHeaders || isAdmin) {
        return next();
    }

    return res.status(401).json({
        success: false,
        status: 'error',
        message: 'Unauthorized: Valid client authentication required'
    });
};

// API: GET USER PROFILE (MongoDB)
router.get('/user/profile', middleware, async (req, res) => {
    try {
        let userId = req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;

        const authHeader = req.headers['authorization'];
        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.split('Bearer ')[1];
            try {
                const decoded = jwt.decode(token);
                if (decoded && (decoded.user_id || decoded.uid || decoded.sub)) {
                    userId = decoded.user_id || decoded.uid || decoded.sub;
                }
            } catch (_) { }
        }

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        await connectMongo();

        let user = await User.findOne({ userId }).lean();
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if (user.account_deleted) {
            return res.status(403).json({ success: false, isDeleted: true, message: 'Account is deleted' });
        }

        if (user.isBlocked || user.blocked) {
            return res.status(403).json({ success: false, isBlocked: true, message: 'Account is blocked' });
        }

        return res.json({
            success: true,
            user: {
                userId: user.userId,
                email: user.email || '',
                displayName: user.displayName || user.name || '',
                name: user.displayName || user.name || '',
                photoUrl: user.photoUrl || '',
                mobileNo: user.mobileNo || '',
                coins: Number(user.coins || 0),
                bonusCoins: Number(user.bonusCoins || 0),
                gems: Number(user.gems || 0),
                referralCode: user.referralCode || '',
                streak: Number(user.streak || 1),
                streakClaimed: Boolean(user.streakClaimed),
                isBlocked: Boolean(user.isBlocked || user.blocked),
                account_deleted: Boolean(user.account_deleted),
                isGuest: Boolean(user.isGuest),
            }
        });
    } catch (err) {
        console.error('🔥 Error in GET /api/user/profile:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch user profile' });
    }
});

function isPlainObject(value) {
    return !!value && typeof value === 'object' && !Array.isArray(value);
}

function toDateOrNull(value) {
    if (!value) return null;
    if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
    if (typeof value?.toDate === 'function') {
        const parsed = value.toDate();
        return Number.isNaN(parsed.getTime()) ? null : parsed;
    }
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
}

async function applyAllPendingReadEarnLimits() {
    const dueConfigs = await ReadEarn.find({
        pendingLimits: { $ne: null },
        pendingLimitsApplyAt: { $lte: new Date() },
    }).exec();

    for (const config of dueConfigs) {
        const pendingLimit = Number(config.pendingLimits);
        if (!Number.isFinite(pendingLimit) || pendingLimit < 1) continue;
        config.limits = pendingLimit;
        config.pendingLimits = null;
        config.pendingLimitsApplyAt = null;
        await config.save();
    }

    if (dueConfigs.length) {
        console.log(`✅ Applied pending Read & Earn limits: ${dueConfigs.length}`);
    }
}

async function applyPendingAppDataForFirestore(firestore, appName = '') {
    await connectMongo();
    const appData = await AppData.findOne({ appName }).lean();
    return appData || {};
}

async function applyPendingAppDataForAllApps() {
    await connectMongo();
    const appDataList = await AppData.find({}).lean();
    return appDataList;
}

// Daily 12 AM (IST)
cron.schedule('0 0 * * *', async () => {
    console.log('⏰ Running scheduled tasks');

    if (process.env.NODE_ENV === 'debug') {
        console.log('⚠️ Skipping scheduled tasks in debug environment');
        return;
    }

    try {
        await connectMongo();

        await Promise.all([
            refreshDailyTask(),
            applyAllPendingReadEarnLimits(),
            applyPendingAppDataForAllApps(),
        ]);

        console.log('✅ All scheduled tasks completed successfully');
    } catch (err) {
        console.error('❌ Scheduled task failed:', err?.message || err);
    }
}, {
    timezone: IST_TIMEZONE,
});

// ====================== Get DAILY TASK/WATCH EARN OFFERS ====================

// Helper to get start of today in IST (Timezone-safe for UTC servers)
function getTodayStartIST() {
    const now = new Date();
    const istDateStr = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
    return new Date(`${istDateStr}T00:00:00+05:30`);
}

// Helper to calculate multi-event task completion state and cycles
function getMultiEventStatus(logs, events, todayStart) {
    const eventIds = events.map(e => e.eventId);
    const eventSet = new Set(eventIds);

    // Sort logs ascending by completedAt (first to last)
    const sortedLogs = [...logs]
        .filter(log => eventSet.has(log.eventId))
        .sort((a, b) => new Date(a.completedAt) - new Date(b.completedAt));

    let currentSet = new Set();
    let cycleCompletedAt = null;

    for (const log of sortedLogs) {
        currentSet.add(log.eventId);
        if (currentSet.size === eventIds.length) {
            cycleCompletedAt = log.completedAt;
            currentSet.clear();
        }
    }

    const activeCompletions = cycleCompletedAt
        ? sortedLogs.filter(log => new Date(log.completedAt) > new Date(cycleCompletedAt))
        : sortedLogs;

    const completedInActiveCycle = new Set(activeCompletions.map(log => log.eventId));

    let isFullyCompletedToday = false;
    if (cycleCompletedAt) {
        const cycleDate = new Date(cycleCompletedAt);
        if (cycleDate >= todayStart) {
            isFullyCompletedToday = true;
        }
    }

    return {
        completedInActiveCycle,
        isFullyCompletedToday,
    };
}

// API - GET DAILY TASK
router.post('/get-daily-task', cryptoMiddleware, middleware, async (req, res) => {
    try {
        await connectMongo();

        const { appName, userId, countryCode, offerType, includeCompleted } = req.body;

        if (!appName || !userId || !countryCode || !offerType) {
            return res.status(400).json({
                success: false,
                message: 'Missing params'
            });
        }

        if (offerType === 'WatchEarn') {
            return res.status(400).json({
                success: false,
                message: 'Invalid offerType for Daily Tasks. Use Watch & Earn APIs instead.'
            });
        }

        const formattedAppName = appName.toLowerCase().replace(/\s/g, '');
        const conversionRate = 100;

        // ✅ Fetch offers (Redis Cached)
        const cacheKey = `tasks:daily:${offerType || 'DailyTask'}`;
        let dbOffers = await cacheService.get(cacheKey);
        if (!dbOffers) {
            dbOffers = await DailyTask.find({ enabled: true, offerType: offerType }).lean();
            if (dbOffers && dbOffers.length > 0) {
                await cacheService.set(cacheKey, dbOffers, cacheService.getTtl('global'));
            }
        }

        if (!dbOffers.length) {
            return res.status(404).json({
                success: false,
                message: 'No offers found'
            });
        }

        // Get today's start time for daily reset logic
        const todayStart = getTodayStartIST();

        // ---------------- GET COMPLETED EVENT RECORDS ----------------
        // Get all postback logs for this user and these offers
        const allOfferIds = dbOffers.map(o => o.offerId);

        const postbackLogs = await PostbackLogs.find({
            appName: formattedAppName,
            userId,
            offerId: { $in: allOfferIds }
        }).lean();

        // Build a map of offerId -> eventId -> completion data
        // Format: { 'offer123': { 'event_1': { completedAt: Date, coins: 50 }, ... } }
        const completionMap = {};
        for (const log of postbackLogs) {
            if (!completionMap[log.offerId]) {
                completionMap[log.offerId] = {};
            }

            // For tasks WITHOUT events (old format) or with empty eventId
            if (!log.eventId || log.eventId === '') {
                completionMap[log.offerId]['__single__'] = {
                    completedAt: log.completedAt,
                    coins: Number(log.coins || log.payout || 0)
                };
            } else {
                // For multi-event tasks
                completionMap[log.offerId][log.eventId] = {
                    completedAt: log.completedAt,
                    coins: Number(log.coins || log.payout || 0)
                };
            }
        }

        // ---------------- FILTER & BUILD RESPONSE ----------------
        const response = [];

        for (const offer of dbOffers) {
            // 1. Enabled Check
            if (!offer.enabled) continue;

            // 2. Country check
            if (!(Array.isArray(offer.countries) &&
                (offer.countries.includes(countryCode) || offer.countries.includes('GLOBAL'))
            )) continue;

            // 3. Daily Cap Check
            if (offer.dailyCapLimit !== null && offer.dailyCapCount >= offer.dailyCapLimit) {
                continue;
            }

            // 4. Lifetime Cap Check
            if (offer.lifetimeCapLimit !== null && offer.postbackCount >= offer.lifetimeCapLimit) {
                continue;
            }

            // 4.5. Per User Daily Cap Check (Only for WatchEarn type tasks)
            if (offer.offerType === 'WatchEarn' && offer.perUserDailyCap !== null && offer.perUserDailyCap !== undefined && offer.perUserDailyCap > 0) {
                const completionsToday = postbackLogs.filter(log => {
                    if (log.offerId !== offer.offerId) return false;
                    const completedAt = new Date(log.completedAt);
                    return completedAt >= todayStart;
                }).length;
                if (completionsToday >= offer.perUserDailyCap) {
                    continue;
                }
            }

            const offerId = offer.offerId;
            const offerCompletion = completionMap[offerId] || {};
            const hasEvents = (offer.events && offer.events.length > 0) || (offer.dailyRewardEnabled && offer.dailyRewards && offer.dailyRewards.length > 0);
            const dailyReset = offer.dailyReset || false;

            // Build events with completion status
            let eventsWithStatus = [];
            let allEventsCompleted = true;

            if (offer.dailyRewardEnabled && offer.dailyRewards && offer.dailyRewards.length > 0) {
                // Find last completed daily step
                let lastCompletedAt = null;
                for (const key in offerCompletion) {
                    if (key.startsWith('day_')) {
                        const comp = offerCompletion[key];
                        if (comp && comp.completedAt) {
                            const date = new Date(comp.completedAt);
                            if (!lastCompletedAt || date > lastCompletedAt) {
                                lastCompletedAt = date;
                            }
                        }
                    }
                }

                // Check if the last completion was today in IST
                let isCompletedToday = false;
                if (lastCompletedAt) {
                    const offset = 5.5 * 60 * 60 * 1000;
                    const lastCompletedIST = new Date(lastCompletedAt.getTime() + (lastCompletedAt.getTimezoneOffset() * 60000) + offset);
                    lastCompletedIST.setHours(0, 0, 0, 0);

                    const todayStart = getTodayStartIST();
                    isCompletedToday = lastCompletedIST.getTime() === todayStart.getTime();
                }

                let foundActive = false;
                allEventsCompleted = true;

                // Sort dailyRewards by day ascending
                const sortedSteps = [...offer.dailyRewards].sort((a, b) => a.day - b.day);

                for (const step of sortedSteps) {
                    const stepEventId = `day_${step.day}`;
                    const stepCompletion = offerCompletion[stepEventId];
                    const isCompleted = !!stepCompletion;

                    let status = "locked";
                    if (isCompleted) {
                        status = "completed";
                    } else {
                        allEventsCompleted = false;
                        if (!foundActive) {
                            foundActive = true;
                            if (isCompletedToday) {
                                status = "locked"; // locked until tomorrow
                            } else {
                                status = "active";
                            }
                        } else {
                            status = "locked";
                        }
                    }

                    let eventRedirectionUrl = '';
                    if (offer.redirectionUrl && offer.redirectionUrl.trim() !== '') {
                        const domain = req.headers.host;
                        const masterSecret = process.env.MASTER_API_KEY || '';
                        const ChCrypto = cryptoMiddleware.ChCrypto;
                        const tokenData = JSON.stringify({
                            userId: String(userId || '').trim(),
                            offerId: String(offer.offerId || '').trim(),
                            appName: String(formattedAppName || '').trim(),
                            eventId: String(stepEventId || '').trim()
                        });
                        const encryptedToken = ChCrypto.encrypt(tokenData, masterSecret);
                        eventRedirectionUrl = `https://${domain}/redirect?t=${encodeURIComponent(encryptedToken)}`;
                    }

                    eventsWithStatus.push({
                        eventId: stepEventId,
                        name: `Day ${step.day}`,
                        timerDuration: step.timerDuration, // in seconds
                        coins: step.coins,
                        payout: step.payout,
                        completed: isCompleted,
                        completedAt: stepCompletion ? stepCompletion.completedAt : null,
                        status: status,
                        redirectionUrl: eventRedirectionUrl
                    });
                }
            } else if (offer.events && offer.events.length > 0) {
                // Multi-event task
                const logsForOffer = postbackLogs.filter(log => log.offerId === offerId);
                const { completedInActiveCycle, isFullyCompletedToday } = getMultiEventStatus(logsForOffer, offer.events, todayStart);

                for (const event of offer.events) {
                    let isCompleted = false;
                    const eventLogs = logsForOffer.filter(l => l.eventId === event.eventId);
                    const lastLog = eventLogs.sort((a, b) => new Date(b.completedAt) - new Date(a.completedAt))[0];

                    if (dailyReset) {
                        isCompleted = completedInActiveCycle.has(event.eventId) || isFullyCompletedToday;
                    } else {
                        isCompleted = !!lastLog;
                    }

                    if (!isCompleted) {
                        allEventsCompleted = false;
                    }

                    let eventRedirectionUrl = '';
                    if (offer.redirectionUrl && offer.redirectionUrl.trim() !== '') {
                        const domain = req.headers.host;
                        const masterSecret = process.env.MASTER_API_KEY || '';
                        const ChCrypto = cryptoMiddleware.ChCrypto;
                        const tokenData = JSON.stringify({
                            userId: String(userId || '').trim(),
                            offerId: String(offer.offerId || '').trim(),
                            appName: String(formattedAppName || '').trim(),
                            eventId: String(event.eventId || '').trim()
                        });
                        const encryptedToken = ChCrypto.encrypt(tokenData, masterSecret);
                        eventRedirectionUrl = `https://${domain}/redirect?t=${encodeURIComponent(encryptedToken)}`;
                    }

                    eventsWithStatus.push({
                        eventId: event.eventId,
                        name: event.name,
                        label: event.label || '',
                        coins: event.coins,
                        payout: event.payout,
                        completed: isCompleted,
                        completedAt: lastLog ? lastLog.completedAt : null,
                        status: isCompleted ? 'completed' : 'active',
                        redirectionUrl: eventRedirectionUrl
                    });
                }

                // Sort: incomplete events first, then completed
                eventsWithStatus.sort((a, b) => {
                    if (a.completed === b.completed) return 0;
                    return a.completed ? 1 : -1;
                });
            } else {
                // Single-event task (old format)
                const singleCompletion = offerCompletion['__single__'];
                let isCompleted = false;

                if (singleCompletion) {
                    if (offer.offerType === 'WatchEarn' && offer.perUserDailyCap !== null && offer.perUserDailyCap !== undefined && offer.perUserDailyCap > 0) {
                        const completionsToday = postbackLogs.filter(log => {
                            if (log.offerId !== offer.offerId) return false;
                            const completedAt = new Date(log.completedAt);
                            return completedAt >= todayStart;
                        }).length;
                        isCompleted = completionsToday >= offer.perUserDailyCap;
                    } else if (dailyReset) {
                        const completedAt = new Date(singleCompletion.completedAt);
                        isCompleted = completedAt >= todayStart;
                    } else {
                        isCompleted = true;
                    }
                }

                if (!isCompleted) {
                    allEventsCompleted = false;
                }

                let eventRedirectionUrl = '';
                if (offer.redirectionUrl && offer.redirectionUrl.trim() !== '') {
                    const domain = req.headers.host;
                    const masterSecret = process.env.MASTER_API_KEY || '';
                    const ChCrypto = cryptoMiddleware.ChCrypto;
                    const tokenData = JSON.stringify({
                        userId: String(userId || '').trim(),
                        offerId: String(offer.offerId || '').trim(),
                        appName: String(formattedAppName || '').trim(),
                        eventId: '__single__'
                    });
                    const encryptedToken = ChCrypto.encrypt(tokenData, masterSecret);
                    eventRedirectionUrl = `https://${domain}/redirect?t=${encodeURIComponent(encryptedToken)}`;
                }

                eventsWithStatus.push({
                    eventId: '__single__',
                    name: 'Complete Task',
                    coins: singleCompletion ? Number(singleCompletion.coins || 0) : Number(offer.coins || offer.payout || 0),
                    payout: offer.payout,
                    completed: isCompleted,
                    completedAt: singleCompletion ? singleCompletion.completedAt : null,
                    status: isCompleted ? 'completed' : 'active',
                    redirectionUrl: eventRedirectionUrl
                });
            }

            // Skip if ALL events completed (and no daily reset), unless includeCompleted is requested
            if (allEventsCompleted && !dailyReset && !includeCompleted) {
                continue;
            }

            // Build redirection URL
            let redirectionUrl = '';
            if (offer.redirectionUrl && offer.redirectionUrl.trim() !== '') {
                if (offer.offerType === 'WatchEarn') {
                    redirectionUrl = offer.redirectionUrl;
                } else {
                    const domain = req.headers.host;
                    const masterSecret = process.env.MASTER_API_KEY || '';
                    const ChCrypto = cryptoMiddleware.ChCrypto;
                    const tokenData = JSON.stringify({
                        userId: String(userId || '').trim(),
                        offerId: String(offer.offerId || '').trim(),
                        appName: String(formattedAppName || '').trim(),
                        eventId: ''
                    });
                    const encryptedToken = ChCrypto.encrypt(tokenData, masterSecret);
                    redirectionUrl = `https://${domain}/redirect?t=${encodeURIComponent(encryptedToken)}`;
                }
            }

            response.push({
                provider: offer.provider,
                imagePath: offer.imagePath,
                bannerPath: offer.bannerPath,
                offerId: offer.offerId,
                offerName: offer.offerName,
                offerDescription: offer.offerDescription,
                offerDisclaimer: offer.offerDisclaimer || [],
                offerType: offer.offerType,
                offerCategory: offer.offerCategory,
                trackingTime: offer.trackingTime || 0,
                coins: (() => {
                    const c = Number(offer.coins || offer.payout || 0);
                    if (c > 0) return c;
                    if (eventsWithStatus && eventsWithStatus.length > 0) {
                        const sum = eventsWithStatus.reduce((acc, ev) => acc + (Number(ev.coins) || 0), 0);
                        if (sum > 0) return sum;
                    }
                    return 0;
                })(),
                redirectionUrl: redirectionUrl,
                reelFormat: (offer.offerCategory.toLowerCase().includes('reel') || offer.offerCategory.toLowerCase().includes('short')) ?? false,
                color: offer.color || '#3F97FF',
                timestamp: offer.createdAt,
                // Multi-event support
                hasEvents: hasEvents,
                events: eventsWithStatus,
                dailyReset: dailyReset,
                // Package & Timer fields
                packageEnabled: offer.packageEnabled || false,
                packageName: offer.packageName || '',
                timerEnabled: offer.timerEnabled || false,
                timerDuration: offer.timerDuration || 0,
                dailyRewardEnabled: offer.dailyRewardEnabled || false,
                dailyRewards: offer.dailyRewards || [],
                watchTutorial: offer.watchTutorial || '',
                subDescription: offer.subDescription || '',
                videoVerificationEnabled: offer.videoVerificationEnabled || false,
                videoVerificationId: offer.videoVerificationId || '',
                perUserDailyCap: offer.perUserDailyCap || null,
                rating: offer.rating || '',
                downloads: offer.downloads || '',
                screenshotVerificationEnabled: offer.screenshotVerificationEnabled || false,
            });
        }

        // Sort by total payout (highest first)
        response.sort((a, b) => b.coins - a.coins);

        return res.status(200).json({
            success: true,
            totalOffers: response.length,
            offers: response
        });

    } catch (err) {
        console.error('🔥 Error fetching offers:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error'
        });
    }
});

// DAILY-TASK POSTBACK ROUTE
router.get('/redirect', async (req, res) => {
    try {
        let { t } = req.query;
        let userId, appName, offerId, eventId;

        if (t) {
            try {
                const masterSecret = process.env.MASTER_API_KEY || '';
                const ChCrypto = cryptoMiddleware.ChCrypto;
                // Normalize spaces back to '+' (handles query parsing behavior of '+' in URLs)
                const normalizedToken = String(t).replace(/ /g, '+');
                const decryptedStr = ChCrypto.decrypt(normalizedToken, masterSecret);
                if (decryptedStr) {
                    const parsed = JSON.parse(decryptedStr);
                    userId = parsed.userId;
                    appName = parsed.appName;
                    offerId = parsed.offerId;
                    eventId = parsed.eventId;
                }
            } catch (decErr) {
                console.error("Token decryption error:", decErr);
                return res.status(400).send('Invalid redirection token');
            }
        } else {
            // Fallback for legacy plain query parameters
            userId = req.query.userId;
            appName = req.query.appName;
            offerId = req.query.offerId;
            eventId = req.query.eventId || req.query.event_id || req.query.eventID || req.query.eventid || '';
        }

        if (!userId || !appName || !offerId) {
            return res.status(404).send('Offer not found');
        }

        userId = String(userId || '').trim();
        appName = String(appName || '').toLowerCase().replace(/\s/g, '').trim();
        offerId = String(offerId || '').trim();
        eventId = eventId ? String(eventId).trim() : '';

        await connectMongo();

        const offer = await DailyTask.findOne({
            offerId,
            enabled: true
        });

        if (!offer || !offer.redirectionUrl) {
            return res.status(404).send('Offer inactive or expired');
        }

        // Check if event is completed (for multi-event) or offer is completed (for single-event)
        let isCompleted = false;
        let isCompletedTodayInDailyReset = false;
        let isCompletedInActiveCycleInDailyReset = false;
        const dailyReset = offer.dailyReset || false;
        const todayStart = getTodayStartIST();
        let canonicalEventId = eventId;

        if (offer.events && offer.events.length > 0 && eventId) {
            // Find matched event case-insensitively
            const matchedEvent = offer.events.find(e => e.eventId.toLowerCase() === eventId.toLowerCase());
            canonicalEventId = matchedEvent ? matchedEvent.eventId : eventId;

            // Multi-event: check specific event completion
            const logs = await PostbackLogs.find({
                appName,
                userId,
                offerId
            }).lean();

            const { completedInActiveCycle, isFullyCompletedToday } = getMultiEventStatus(logs, offer.events, todayStart);

            if (dailyReset) {
                isCompleted = completedInActiveCycle.has(canonicalEventId) || isFullyCompletedToday;
                isCompletedTodayInDailyReset = isFullyCompletedToday;
                isCompletedInActiveCycleInDailyReset = completedInActiveCycle.has(canonicalEventId);
            } else {
                isCompleted = logs.some(log => log.eventId === canonicalEventId);
            }
        } else {
            // Single-event or no eventId: check old format
            const completion = await PostbackLogs.findOne({
                appName,
                userId,
                offerId
            }).sort({ completedAt: -1 }).lean();

            if (completion) {
                if (dailyReset) {
                    const completedAt = new Date(completion.completedAt);
                    isCompleted = completedAt >= todayStart;
                } else {
                    isCompleted = true;
                }
            }
        }

        console.log(
            `Redirect request → offerId:${offerId}, eventId:${eventId}, canonicalEventId:${canonicalEventId}, userId:${userId}, appName:${appName}, completed:${isCompleted}`
        );

        if (isCompleted) {
            if (dailyReset) {
                if (isCompletedTodayInDailyReset) {
                    return res.status(403).send('Event already completed today');
                } else if (isCompletedInActiveCycleInDailyReset) {
                    return res.status(403).send('All Events not completed');
                }
            } else {
                return res.status(403).send('Offer already completed');
            }
        }

        let finalRedirectionUrl = offer.redirectionUrl;
        if (finalRedirectionUrl && finalRedirectionUrl.includes('{user_id}')) {
            finalRedirectionUrl = finalRedirectionUrl.replace(/{user_id}/g, userId);
        }
        if (finalRedirectionUrl && finalRedirectionUrl.includes('{offer_id}')) {
            finalRedirectionUrl = finalRedirectionUrl.replace(/{offer_id}/g, offerId);
        }
        if (finalRedirectionUrl && finalRedirectionUrl.includes('{event_id}')) {
            finalRedirectionUrl = finalRedirectionUrl.replace(/{event_id}/g, canonicalEventId);
        }
        if (finalRedirectionUrl && finalRedirectionUrl.includes('{eventId}')) {
            finalRedirectionUrl = finalRedirectionUrl.replace(/{eventId}/g, canonicalEventId);
        }

        // Support for {gaid} or {GAID} placeholder by fetching it from Firestore
        if (finalRedirectionUrl && (finalRedirectionUrl.includes('{gaid}') || finalRedirectionUrl.includes('{GAID}'))) {
            let gaidVal = '';
            try {
                await connectMongo();
                const userDoc = await User.findOne({ userId }).lean();
                if (userDoc) {
                    gaidVal = userDoc.gaid || userDoc.GAID || '';
                }
            } catch (gaidErr) {
                console.error("Error fetching user GAID in redirect route:", gaidErr);
            }
            finalRedirectionUrl = finalRedirectionUrl.replace(/{gaid}/g, gaidVal).replace(/{GAID}/g, gaidVal);
        }
        console.log("➡️ REDIRECTING TO FINAL URL:", finalRedirectionUrl);
        return res.redirect(finalRedirectionUrl);

    } catch (err) {
        console.error("Redirect error:", err);
        return res.status(500).send('Server error');
    }
});

// ✅ Daily Task Postback (Supports GET and Encrypted POST)
router.all('/daily-task-postback', cryptoMiddleware, middleware, async (req, res) => {
    try {
        const userId = String(req.query?.userId || req.body?.userId || '').trim();
        const email = String(req.query?.email || req.body?.email || '').trim();
        const gaid = String(req.query?.gaid || req.body?.gaid || '').trim();
        const appName = String(req.query?.appName || req.body?.appName || '').trim();
        const offerId = String(req.body?.offerId || req.query?.offerId || '').trim();
        const eventId = String(req.query?.eventId || req.query?.event_id || req.query?.eventID || req.query?.eventid || req.body?.eventId || req.body?.event_id || '').trim();

        if (!userId || !appName || !offerId) {
            console.warn(`❌ Missing parameters in postback`);
            return res.status(400).json({
                success: false,
                message: 'Missing parameters'
            });
        }

        const offerCheck = await DailyTask.findOne({ offerId: offerId.trim() }).lean();
        if (offerCheck && offerCheck.offerType === 'WatchEarn') {
            console.warn(`❌ Attempt to postback WatchEarn offer ${offerId} via daily-task endpoint`);
            return res.status(400).json({
                success: false,
                message: 'Invalid endpoint for Watch & Earn postback.'
            });
        }

        return handleDailyTaskPostback({
            appName: appName.toLowerCase().replace(/\s/g, '').trim(),
            userId: userId.trim(),
            offerId: offerId.trim(),
            userEmail: email ? email.trim() : '',
            query: { ...req.query, ...req.body },
            res: res,
            userGaid: gaid ? gaid.trim() : '',
            eventId: eventId ? eventId.trim() : '',
        });
    } catch (err) {
        console.error('🔥 Error in /daily-task-postback:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// ✅ Daily Task OCR & Video URL Verification
router.post('/daily-task-verify-ocr', middleware, upload.single('screenshot'), async (req, res) => {
    try {
        const { userId, email, gaid, appName, offerId, videoUrl, eventId } = req.body;

        if (!userId || !appName || !offerId || !videoUrl) {
            console.warn(`❌ Missing parameters in OCR verification`);
            return res.status(400).json({
                success: false,
                message: 'Missing parameters (userId, appName, offerId, and videoUrl are required).'
            });
        }

        if (!req.file) {
            console.warn(`❌ Missing screenshot file in OCR verification`);
            return res.status(400).json({
                success: false,
                message: 'Screenshot file is required.'
            });
        }

        await connectMongo();

        // 1. Fetch the daily task
        const offerDoc = await DailyTask.findOne({ offerId: offerId.trim() });
        if (!offerDoc) {
            return res.status(404).json({
                success: false,
                message: 'Task/Offer not found.'
            });
        }

        if (!offerDoc.enabled) {
            return res.status(400).json({
                success: false,
                message: 'This task is currently inactive.'
            });
        }

        // Helper to get start of today in IST (Timezone-safe for UTC servers)
        const getTodayStartIST = () => {
            const now = new Date();
            const istDateStr = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
            return new Date(`${istDateStr}T00:00:00+05:30`);
        };

        // 2. Duplicate / Cap pre-check before OCR
        const todayStart = getTodayStartIST();

        if (offerDoc.offerType === 'WatchEarn') {
            if (offerDoc.perUserDailyCap !== null && offerDoc.perUserDailyCap !== undefined && offerDoc.perUserDailyCap > 0) {
                const userCompletionsToday = await PostbackLogs.countDocuments({
                    userId: userId.trim(),
                    offerId: offerId.trim(),
                    completedAt: { $gte: todayStart }
                });
                if (userCompletionsToday >= offerDoc.perUserDailyCap) {
                    return res.status(200).json({
                        success: false,
                        message: `Daily limit reached (${offerDoc.perUserDailyCap}/${offerDoc.perUserDailyCap}) for this video. Come back tomorrow!`
                    });
                }
            } else {
                const userCompletionsToday = await PostbackLogs.countDocuments({
                    userId: userId.trim(),
                    offerId: offerId.trim(),
                    completedAt: { $gte: todayStart }
                });
                if (offerDoc.dailyReset && userCompletionsToday >= 1) {
                    return res.status(200).json({
                        success: false,
                        message: 'You have already completed this video today. Come back tomorrow!'
                    });
                } else if (!offerDoc.dailyReset) {
                    const lifetimeComps = await PostbackLogs.countDocuments({
                        userId: userId.trim(),
                        offerId: offerId.trim(),
                    });
                    if (lifetimeComps >= 1) {
                        return res.status(200).json({
                            success: false,
                            message: 'You have already completed this video task.'
                        });
                    }
                }
            }
        } else {
            const existingCompletion = await PostbackLogs.findOne({
                appName,
                userId,
                offerId,
            }).sort({ completedAt: -1 });

            if (existingCompletion) {
                if (offerDoc.dailyReset) {
                    const completedAt = new Date(existingCompletion.completedAt);
                    if (completedAt >= todayStart) {
                        return res.status(200).json({
                            success: false,
                            message: 'Task already completed today. Come back tomorrow!'
                        });
                    }
                } else {
                    return res.status(200).json({
                        success: false,
                        message: 'Task already completed.'
                    });
                }
            }
        }

        // 3. Verify Video URL (Universal & Flexible)
        const trimmedVideoUrl = (videoUrl || '').trim();
        const verificationId = (offerDoc.videoVerificationId || '').trim();

        const extractVideoId = (url) => {
            if (!url) return '';
            const match = url.match(/(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([\w-]{8,15})/i);
            return match ? match[1] : '';
        };

        if (verificationId) {
            const inputYtId = extractVideoId(trimmedVideoUrl);
            const targetYtId = extractVideoId(verificationId) || extractVideoId(offerDoc.redirectionUrl);

            const isUrlMatch = 
                (inputYtId && targetYtId && inputYtId.toLowerCase() === targetYtId.toLowerCase()) ||
                trimmedVideoUrl.toLowerCase().includes(verificationId.toLowerCase()) ||
                (targetYtId && trimmedVideoUrl.toLowerCase().includes(targetYtId.toLowerCase())) ||
                (offerDoc.redirectionUrl && trimmedVideoUrl.toLowerCase().includes(offerDoc.redirectionUrl.toLowerCase().trim()));

            if (!isUrlMatch) {
                console.warn(`[OCR] Video URL mismatch: input="${trimmedVideoUrl}", target="${verificationId}"`);
                return res.status(200).json({
                    success: false,
                    message: 'Wrong video URL. Please paste the correct video link.'
                });
            }
        }

        // 4. Run Universal OCR Verification
        console.log(`[OCR] Running Universal OCR check for offer "${offerDoc.offerName}"...`);
        let ocrText = '';
        try {
            const { data } = await Tesseract.recognize(req.file.buffer, 'eng');
            ocrText = data.text || '';
        } catch (ocrError) {
            console.error('OCR Processing error:', ocrError);
            return res.status(500).json({
                success: false,
                message: 'Server failed to process screenshot image. Please try again.'
            });
        }

        const cleanText = (str) => (str || '')
            .toLowerCase()
            .replace(/[’'"`]/g, '')
            .replace(/[^a-z0-9]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();

        const normalizedOcr = cleanText(ocrText);
        const cleanTitle = (offerDoc.offerName || '')
            .replace(/\s*\((?:copy|clone)\)\s*/gi, '')
            .trim();
        const normalizedOfferName = cleanText(cleanTitle);

        let isMatch = false;

        // Tier 1: Direct full or partial title match
        if (normalizedOfferName.length > 0 && normalizedOcr.includes(normalizedOfferName)) {
            isMatch = true;
            console.log(`[OCR] Exact full title matched!`);
        }

        // Title significant words analysis
        const stopWords = new Set([
            'the', 'and', 'a', 'an', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 
            'is', 'it', 'or', 'as', 'from', 'this', 'that', 'ft', 'feat', 'video', 'watch', 's'
        ]);
        const offerWords = normalizedOfferName.split(' ').filter(w => w.length >= 2 && !stopWords.has(w));

        // Tier 2: 2-word phrase from title
        if (!isMatch && offerWords.length >= 2) {
            for (let i = 0; i <= offerWords.length - 2; i++) {
                const phrase2 = `${offerWords[i]} ${offerWords[i+1]}`;
                if (phrase2.length >= 5 && normalizedOcr.includes(phrase2)) {
                    isMatch = true;
                    console.log(`[OCR] Matched 2-word title phrase: "${phrase2}"`);
                    break;
                }
            }
        }

        // Tier 3: Direct offer title words presence check (No generic markers)
        if (!isMatch && offerWords.length > 0) {
            const ocrWordSet = new Set(normalizedOcr.split(' '));
            const ocrString = ` ${normalizedOcr} `;

            const wordExistsInOcr = (target) => {
                if (ocrWordSet.has(target)) return true;
                if (target.length >= 4 && ocrString.includes(target)) return true;
                return false;
            };

            const matchedWords = offerWords.filter(word => word.length >= 3 && wordExistsInOcr(word));
            const requiredMatches = offerWords.length <= 2 ? 1 : 2;
            if (matchedWords.length >= requiredMatches) {
                isMatch = true;
                console.log(`[OCR] Matched title words (${matchedWords.length}/${requiredMatches}): ${matchedWords.join(', ')}`);
            }
        }

        if (!isMatch) {
            console.warn(`[OCR] Matching failed. Extracted OCR text was: "${ocrText.substring(0, 250).replace(/\n/g, ' ')}..."`);
            return res.status(200).json({
                success: false,
                message: 'Wrong screenshot. Screenshot must show the correct video title.'
            });
        }

        console.log('[OCR] Verification successful! Proceeding with postback reward.');

        // 5. Trigger postback (dedicated WatchEarn engine if WatchEarn offer)
        const mockQuery = {
            userId: userId.trim(),
            email: email ? email.trim() : '',
            gaid: gaid ? gaid.trim() : '',
            appName: appName.trim(),
            offerId: offerId.trim(),
            eventId: eventId ? eventId.trim() : '',
        };

        if (offerDoc.offerType === 'WatchEarn') {
            const { handleWatchEarnPostback } = require('../admin/middlewares/watch-earn-postback');
            return handleWatchEarnPostback({
                appName: appName.toLowerCase().replace(/\s/g, '').trim(),
                userId: userId.trim(),
                offerId: offerId.trim(),
                userEmail: email ? email.trim() : '',
                userGaid: gaid ? gaid.trim() : '',
                query: mockQuery,
                res: res,
            });
        }

        return handleDailyTaskPostback({
            appName: appName.toLowerCase().replace(/\s/g, '').trim(),
            userId: userId.trim(),
            offerId: offerId.trim(),
            userEmail: email ? email.trim() : '',
            query: mockQuery,
            res: res,
            userGaid: gaid ? gaid.trim() : '',
            eventId: eventId ? eventId.trim() : '',
        });

    } catch (err) {
        console.error("OCR Verification route error:", err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error during verification.'
        });
    }
});

// ✅ External CPA Advertiser Postback (Direct Advertisers)
router.get('/cpa-postback', async (req, res) => {
    const { userId, appName, offerId, secret } = req.query;
    const eventId = req.query.eventId || req.query.event_id || req.query.eventID || req.query.eventid || '';

    console.log("CPA Postback Received:", req.query);

    if (!userId || !appName || !offerId) {
        console.warn(`❌ Missing parameters in CPA postback`);
        return res.status(400).send('0');
    }

    if (!secret) {
        console.warn(`❌ Missing secret key in CPA postback`);
        return res.status(401).send('0');
    }

    // Verify offerId and secret key
    try {
        await connectMongo();

        const offer = await DailyTask.findOne({ offerId: offerId.trim() }).lean();

        if (!offer) {
            console.warn(`❌ Offer not found: ${offerId}`);
            return res.status(404).send('0');
        }

        // Check task-specific secret key
        const taskSecret = offer.secretKey;
        if (!taskSecret || secret !== taskSecret) {
            console.warn(`❌ Invalid secret key for offer: ${offerId}`);
            return res.status(401).send('0');
        }

        // Success - proceed with postback
        return handleDailyTaskPostback({
            appName: appName.toLowerCase().replace(/\s/g, '').trim(),
            userId: userId.trim(),
            offerId: offerId.trim(),
            userEmail: '',
            query: req.query,
            res: res,
            userGaid: '',
            eventId: eventId ? eventId.trim() : '',
        });
    } catch (error) {
        console.error("❌ CPA Postback execution error:", error);
        return res.status(500).send('0');
    }
});

// Fetch Game (Encrypted via cryptoMiddleware)
router.post('/get-games', cryptoMiddleware, middleware, async (req, res) => {
    try {
        if (!req.rawPayload) {
            return res.status(400).json({ success: false, message: 'Encryption required' });
        }
        await connectMongo();

        const userId = req.headers['x-user-id'];

        let games = await cacheService.get('games:all_enabled');
        if (!games) {
            games = await PlayGames.find({ enabled: { $ne: false } }).lean();
            if (games && games.length > 0) {
                await cacheService.set('games:all_enabled', games, cacheService.getTtl('global'));
            }
        }

        if (!games.length) {
            return res.status(404).json({
                success: false,
                message: 'No games found'
            });
        }

        // Helper function to get IST date key
        const getISTDayKey = () => {
            return DateTime.now().setZone(IST_TIMEZONE).toFormat('yyyy-MM-dd');
        };

        // Filter games based on user limits
        const filteredGames = [];
        const dayKey = getISTDayKey();

        for (const game of games) {
            let skipGame = false;

            // If userId is provided, check limits
            if (userId) {
                const offerId = game._id;

                // Check lifetime limit (0 = block all, -1 = unlimited, >0 = check count)
                if (game.maxPlaysPerUser === 0) {
                    skipGame = true;
                } else if (game.maxPlaysPerUser > 0) {
                    const totalPlays = await GamePlayLogs.countDocuments({
                        offerId,
                        userId
                    });
                    if (totalPlays >= game.maxPlaysPerUser) {
                        skipGame = true;
                    }
                }

                // Check daily limit (if dailyEnabled is true)
                if (!skipGame && game.dailyEnabled && game.maxPlaysPerDay > 0) {
                    const todayPlays = await GamePlayLogs.countDocuments({
                        offerId,
                        userId,
                        dayKey
                    });
                    if (todayPlays >= game.maxPlaysPerDay) {
                        skipGame = true;
                    }
                }
            }

            if (!skipGame) {
                filteredGames.push({
                    imagePath: game.imagePath,
                    offerName: game.offerName,
                    category: game.category || '',
                    trackingTime: game.trackingTime || 0,
                    coins: Number(game.coins || game.payout || 0),
                    redirectionUrl: game.redirectionUrl,
                    offerId: String(game._id),
                    maxPlaysPerUser: game.maxPlaysPerUser ?? -1,
                    dailyEnabled: game.dailyEnabled ?? false,
                    maxPlaysPerDay: game.maxPlaysPerDay ?? 1,
                });
            }
        }

        return res.status(200).json({
            success: true,
            totalGames: filteredGames.length,
            games: filteredGames
        });
    } catch (err) {
        console.error('🔥 Error fetching games:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error'
        });
    }
});

// Record game play - validate limits and save play log (Encrypted via cryptoMiddleware)
router.post('/record-game-play', cryptoMiddleware, middleware, async (req, res) => {
    try {
        if (!req.rawPayload) {
            return res.status(400).json({ success: false, message: 'Encryption required' });
        }
        await connectMongo();

        const userId = String(req.headers['x-user-id'] || req.headers['user-id'] || req.body?.userId || '').trim();
        const offerId = String(req.body?.offerId || req.query?.offerId || '').trim();

        if (!userId || !offerId) {
            return res.status(400).json({
                success: false,
                message: 'Missing userId or offerId'
            });
        }

        // Get game details
        const game = await PlayGames.findById(offerId).lean();
        if (!game || game.enabled === false) {
            return res.status(404).json({
                success: false,
                message: 'Game not found or disabled'
            });
        }

        const dayKey = DateTime.now().setZone(IST_TIMEZONE).toFormat('yyyy-MM-dd');

        // Check lifetime limit (0 = block all, -1 = unlimited, >0 = check count)
        if (game.maxPlaysPerUser === 0) {
            return res.status(200).json({
                success: false,
                message: 'The game currently not available'
            });
        } else if (game.maxPlaysPerUser > 0) {
            const totalPlays = await GamePlayLogs.countDocuments({
                offerId: game._id,
                userId
            });
            if (totalPlays >= game.maxPlaysPerUser) {
                return res.status(200).json({
                    success: false,
                    message: 'The game currently not available'
                });
            }
        }

        // Check daily limit
        if (game.dailyEnabled && game.maxPlaysPerDay > 0) {
            const todayPlays = await GamePlayLogs.countDocuments({
                offerId: game._id,
                userId,
                dayKey
            });
            if (todayPlays >= game.maxPlaysPerDay) {
                return res.status(200).json({
                    success: false,
                    message: 'Play tomorrow'
                });
            }
        }

        // Record the play
        await GamePlayLogs.create({
            offerId: game._id,
            userId,
            dayKey
        });

        // Credit user wallet in MongoDB directly (Atomic $inc)
        const coins = Number(game.coins !== undefined ? game.coins : (game.payout || 0));
        if (coins > 0) {
            const User = require('../admin/models/user');
            const RewardHistory = require('../admin/models/rewardHistory');

            let user = await User.findOneAndUpdate(
                {
                    $or: [{ userId: userId }, { firebaseUid: userId }],
                    isGuest: { $ne: true },
                    isAnonymous: { $ne: true },
                    isBlocked: { $ne: true },
                    blocked: { $ne: true }
                },
                { $inc: { coins: coins, totalCoins: coins } },
                { new: true }
            );

            if (user) {
                console.log(`✅ [PlayGames] Credited ${coins} coins to user ${userId}. New balance: ${user.coins}`);

                // Trigger S2S postback for generic event and specific game
                try {
                    const triggerOutgoingPostback = require('../services/publisherPostbackService');
                    triggerOutgoingPostback({
                        user,
                        offerId: 'play_games_complete',
                        coins,
                        eventId: 'play_games_complete'
                    });
                    triggerOutgoingPostback({
                        user,
                        offerId: String(offerId),
                        coins,
                        eventId: String(offerId)
                    });
                } catch (err) {
                    console.error("⚠️ Failed to trigger S2S outgoing postback for Play Games:", err.message);
                }

                const transId = `play_game_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
                await RewardHistory.create({
                    appName: user.appName || '',
                    userId: userId,
                    provider: 'Play Games',
                    coins: coins,
                    rewardType: 'coin',
                    orderId: transId,
                    transId: transId,
                    timestamp: new Date()
                }).catch(err => console.error("⚠️ RewardHistory create warning:", err.message));

                // Track Daily Challenge progress for Play Games
                try {
                    const { trackDailyChallengeProgress } = require('./modules/dailyChallengeApiRoutes');
                    trackDailyChallengeProgress(userId, 'play_games', 1);
                } catch (_) {}

                // 🤝 Referral Commission & Joinee Bonus Trigger
                try {
                    const { distributeTaskReferralCommission, checkAndUnlockTaskReferrerBonus } = require('../services/referralCommissionService');
                    checkAndUnlockTaskReferrerBonus(userId, 'play_games').catch(e => console.error("⚠️ [PlayGames] Ref bonus error:", e.message));
                    distributeTaskReferralCommission(userId, coins, 'Play Games').catch(e => console.error("⚠️ [PlayGames] Ref comm error:", e.message));
                } catch (refErr) {
                    console.error("⚠️ [PlayGames] Referral processing error:", refErr.message);
                }
            } else {
                console.error(`🔥 [PlayGames] User not found in MongoDB for userId: ${userId}`);
            }
        }

        // Calculate remaining plays
        let remainingLifetime = -1;
        let remainingToday = -1;

        if (game.maxPlaysPerUser > 0) {
            const totalPlays = await GamePlayLogs.countDocuments({
                offerId: game._id,
                userId
            });
            remainingLifetime = Math.max(0, game.maxPlaysPerUser - totalPlays);
        }

        if (game.dailyEnabled) {
            const todayPlays = await GamePlayLogs.countDocuments({
                offerId: game._id,
                userId,
                dayKey
            });
            remainingToday = Math.max(0, game.maxPlaysPerDay - todayPlays);
        }

        return res.status(200).json({
            success: true,
            message: 'Game play recorded',
            remainingLifetime,
            remainingToday
        });
    } catch (err) {
        console.error('🔥 Error recording game play:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error'
        });
    }
});

router.post(['/get-read-earn-url', '/api/get-read-earn-url'], cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();

        const appName = String(req.query?.appName || req.body?.appName || '').trim();
        const userId = String(req.query?.userId || req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || '').trim();

        if (!userId) {
            return res.status(400).json({
                success: false,
                message: 'Missing userId parameter'
            });
        }

        const cacheKey = 'readearn:config';
        let readEarnConfig = await cacheService.get(cacheKey);

        if (!readEarnConfig) {
            readEarnConfig = await ReadEarn.findOne({ enabled: { $ne: false } }).sort({ updatedAt: -1 }).lean().exec();
            if (!readEarnConfig) {
                readEarnConfig = await ReadEarn.findOne().sort({ updatedAt: -1 }).lean().exec();
            }
            if (readEarnConfig) {
                await cacheService.set(cacheKey, readEarnConfig, cacheService.getTtl('global'));
            }
        }

        if (!readEarnConfig) {
            return res.status(404).json({
                success: false,
                message: 'No Read Earn offers available'
            });
        }

        const limits = Number(readEarnConfig.limits) || 9999;
        const urlsList = Array.isArray(readEarnConfig.urlsList) ? readEarnConfig.urlsList : [];

        const completedCount = await ReadEarnLogs.countDocuments({
            userId: userId,
            createdAt: { $gte: new Date(Date.now() - 24 * 60 * 60 * 1000) }
        }).catch(() => 0);

        const enabledUrls = urlsList.filter(urlObj => urlObj.enabled !== false);

        if (!enabledUrls.length) {
            return res.status(404).json({
                success: false,
                message: 'No enabled Read Earn URLs available'
            });
        }

        // Randomly select one URL from the enabled list
        const randomIndex = Math.floor(Math.random() * enabledUrls.length);
        const selectedUrl = enabledUrls[randomIndex];

        // Generate secure token
        const READ_EARN_SECRET = process.env.READ_EARN_SECRET || 'read_earn_secure_secret_key_2026';
        const timestamp = Date.now();
        const dataToSign = `${userId}:${String(selectedUrl._id).trim()}:${timestamp}`;
        const signature = crypto.createHmac('sha256', READ_EARN_SECRET)
            .update(dataToSign)
            .digest('hex');
        const token = `${timestamp}.${signature}`;

        // Save verification token as pending in database
        await PendingReadEarnToken.create({
            userId: userId,
            offerId: String(selectedUrl._id).trim(),
            token: token
        }).catch(() => { });

        let redirectionUrl = selectedUrl.url;
        if (redirectionUrl.includes('?')) {
            redirectionUrl += `&token=${token}`;
        } else {
            redirectionUrl += `?token=${token}`;
        }

        return res.status(200).json({
            success: true,
            redirectionUrl,
            coins: Math.floor(Number(selectedUrl.payout || 0) * 100),
            trackingTime: selectedUrl.trackingTime || 60,
            offerId: String(selectedUrl._id),
            verificationEnabled: selectedUrl.verificationEnabled || false,
            verificationTitle: selectedUrl.verificationTitle || '',
            verificationDomain: selectedUrl.verificationDomain || '',
            completedCount,
            limits,
        });
    } catch (err) {
        console.error('🔥 Error fetching Read Earn URL:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error'
        });
    }
});

// Read Earn Postback (Supports GET and Encrypted POST)
router.all('/read-earn-postback', cryptoMiddleware, middleware, async (req, res) => {
    try {
        const userId = String(req.query?.userId || req.body?.userId || '').trim();
        const appName = String(req.query?.appName || req.body?.appName || '').trim();
        const offerId = String(req.body?.offerId || req.query?.offerId || '').trim();

        if (!userId || !appName || !offerId) {
            return res.status(400).json({
                success: false,
                message: 'Missing parameters'
            });
        }

        return handleReadEarnPostback({
            appName: appName.toLowerCase().trim(),
            userId: userId.trim(),
            offerId: offerId.trim(),
            query: { ...req.query, ...req.body },
            res: res,
        });
    } catch (err) {
        console.error('🔥 Error in /read-earn-postback:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.post('/payout-postback', async (req, res) => {
    try {
        const firebaseServices = await FirebaseService.find({});

        console.log(req.body);

        return handlePayoutPostback(req, res, {
            firebaseServices,
            FieldValue,
        });

    } catch (err) {
        console.error('❌ Postback error:', err);
        return res.status(500).json({
            success: false,
            message: 'Postback processing failed',
        });
    }
});

// API: Trigger Payout from Firebase (to use server's static IP)
router.post('/trigger-payout', middleware, async (req, res) => {
    try {
        const { orderId, appName } = req.body;

        if (!orderId || !appName) {
            return res.status(400).json({
                success: false,
                message: 'orderId and appName are required',
            });
        }

        // Get Firebase service for this app
        const serviceDoc = await FirebaseService.findOne({ appName }).lean();
        if (!serviceDoc) {
            return res.status(404).json({
                success: false,
                message: 'App configuration not found',
            });
        }

        await connectMongo();
        let payoutData = await PayoutRecord.findOne({ orderId }).lean();
        if (!payoutData) {
            payoutData = await PayoutRecord.findOne({ apiOrderId: orderId }).lean();
            if (!payoutData) {
                return res.status(404).json({
                    success: false,
                    message: 'Payout record not found',
                });
            }
        }

        if (payoutData.status === 'successful' || payoutData.status === 'failed') {
            return res.json({
                success: true,
                status: payoutData.status,
                message: 'Payout already processed',
            });
        }

        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean() || await AppData.findOne({ appName }).lean();
        const dailyMaxPayout = Number(appDataDoc?.config?.dailyMaxPayout !== undefined ? appDataDoc.config.dailyMaxPayout : (appDataDoc?.dailyMaxPayout !== undefined ? appDataDoc.dailyMaxPayout : 1));

        // Count non-failed payouts for this user since start of today in MongoDB
        const nowInKolkata = DateTime.now().setZone('Asia/Kolkata');
        const startTime = nowInKolkata.set({
            hour: 0,
            minute: 0,
            second: 0,
            millisecond: 0,
        }).toJSDate();

        const todayPayoutsCount = await PayoutRecord.countDocuments({
            appName,
            userId: payoutData.userId,
            status: { 
                $in: [
                    'pending', 'inprogress', 'processing',
                    'success', 'completed', 'processed',
                    'PENDING', 'INPROGRESS', 'PROCESSING',
                    'SUCCESS', 'COMPLETED', 'PROCESSED'
                ] 
            },
            $or: [
                { createdAt: { $gte: startTime } },
                { timestamp: { $gte: startTime } }
            ]
        });

        if (todayPayoutsCount > dailyMaxPayout) {
            // Update the payout status to failed in MongoDB!
            await PayoutRecord.updateOne(
                { orderId: payoutData.orderId },
                { $set: { status: 'failed', message: `Daily payout limit of ${dailyMaxPayout} reached.` } }
            );

            return res.status(400).json({
                success: false,
                status: 'failed',
                message: `Daily payout limit of ${dailyMaxPayout} reached. Please try again tomorrow.`,
            });
        }

        console.log(`🎯 Processing payout: ${orderId}`);

        const payoutRef = { id: payoutData.orderId };

        return await handlePayoutRoute(req, res, {
            db,
            dbState: { FieldValue },
            payoutRef,
            payoutData,
            orderId: payoutData.orderId,
            FieldValue,
        });

    } catch (err) {
        console.error('❌ Trigger payout error:', err);
        return res.status(500).json({
            success: false,
            message: 'Payout processing failed',
        });
    }
});

// API: GET SERVER TIME
router.all('/getServerTime', middleware, (req, res) => {
    try {
        const now = DateTime.now().setZone('Asia/Kolkata');
        const serverTime = now.toMillis();

        const getDailyResetTime = () => {
            const todayReset = now.set({
                hour: 20,
                minute: 0,
                second: 0,
                millisecond: 0,
            });
            const nextReset = now < todayReset ? todayReset : todayReset.plus({ days: 1 });
            return nextReset.toMillis() - serverTime;
        };

        const leaderboardTimeLeft = getDailyResetTime();

        res.json({
            status: 'success',
            serverTime,
            leaderboardTimeLeft,
        });
    } catch (error) {
        res.status(500).json({
            status: 'failure',
            reason: error.toString()
        });
    }
});



// Submit Promotion Request
router.post('/submit-promotion-request', middleware, async (req, res) => {
    try {
        const { userId, email, promotionType, title, description, link, phoneNumber, budget, campaignType } = req.body;
        if (!userId || !email || !promotionType || !title || !description) {
            return res.status(400).json({ success: false, message: 'Missing required fields' });
        }

        const newPromo = new PromotionRequest({
            userId,
            email,
            promotionType,
            title,
            description,
            link: link || '',
            phoneNumber: phoneNumber || '',
            budget: budget || '',
            campaignType: campaignType || ''
        });

        await newPromo.save();
        return res.status(200).json({ success: true, message: 'Promotion request submitted successfully', data: newPromo });
    } catch (err) {
        console.error('🔥 Error submitting promotion request:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Get Promotion Requests
router.get('/get-promotion-requests', middleware, async (req, res) => {
    try {
        const { userId } = req.query;
        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        const requests = await PromotionRequest.find({ userId }).sort({ createdAt: -1 });
        return res.status(200).json({ success: true, data: requests });
    } catch (err) {
        console.error('🔥 Error fetching promotion requests:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Submit Support Ticket / Contact Request
router.post('/submit-support-request', middleware, async (req, res) => {
    try {
        const { userId, email, subject, message, screenshot } = req.body;
        if (!userId || !email || !subject || !message) {
            return res.status(400).json({ success: false, message: 'Missing required fields' });
        }

        const newTicket = new SupportRequest({
            userId,
            email,
            subject,
            message,
            screenshot: screenshot || ''
        });

        await newTicket.save();
        return res.status(200).json({ success: true, message: 'Support ticket raised successfully', data: newTicket });
    } catch (err) {
        console.error('🔥 Error submitting support request:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Get Support Tickets
router.get('/get-support-requests', middleware, async (req, res) => {
    try {
        const { userId } = req.query;
        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        const tickets = await SupportRequest.find({ userId }).sort({ createdAt: -1 });
        return res.status(200).json({ success: true, data: tickets });
    } catch (err) {
        console.error('🔥 Error fetching support requests:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Server-to-Server log postback error
router.post('/api/log-postback-error', async (req, res) => {
    try {
        const apiKey = req.headers['x-api-key'];
        if (!apiKey || apiKey !== process.env.API_KEY) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }

        const { provider, errorType, incomingIP, details } = req.body || {};
        if (!provider || !errorType) {
            return res.status(400).json({ success: false, message: 'Missing provider or errorType' });
        }

        const newLog = new PostbackErrorLog({
            provider,
            errorType,
            incomingIP: incomingIP || '',
            details: details || {},
            timestamp: new Date()
        });

        await newLog.save();
        return res.status(200).json({ success: true, message: 'Postback error logged successfully' });
    } catch (err) {
        console.error('🔥 Error logging postback error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Server-to-Server log user reward
router.post('/api/log-reward', async (req, res) => {
    try {
        const apiKey = req.headers['x-api-key'];
        if (!apiKey || apiKey !== process.env.API_KEY) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }

        const { appName, userId, provider, coins, orderId, offerId, transId, eventId } = req.body || {};
        if (!appName || !userId || !provider || !coins || !orderId) {
            return res.status(400).json({ success: false, message: 'Missing required reward log fields' });
        }

        // Avoid duplicates
        const exists = await RewardHistory.findOne({ orderId }).lean();
        if (exists) {
            return res.status(200).json({ success: true, message: 'Reward already logged' });
        }

        const newReward = new RewardHistory({
            appName,
            userId,
            provider,
            coins: Number(coins),
            orderId,
            offerId: offerId || null,
            transId: transId || null,
            eventId: eventId || null,
            timestamp: new Date()
        });

        await newReward.save();
        return res.status(200).json({ success: true, message: 'Reward logged successfully' });
    } catch (err) {
        console.error('🔥 Error logging user reward:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Get User Reward History (Paginated)
router.get(['/api/get-reward-history', '/get-reward-history'], middleware, async (req, res) => {
    try {
        const userId = String(req.query?.userId || req.headers['user-id'] || req.headers['x-user-id'] || '').trim();
        const limit = Math.min(Number(req.query?.limit) || 150, 300);
        const skip = Number(req.query?.skip) || 0;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

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
        console.error('🔥 Error fetching user reward history:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// ✅ Get Daily Task Completed History with Rich Offer Details
router.all(['/api/get-daily-task-history', '/get-daily-task-history'], middleware, async (req, res) => {
    try {
        const userId = String(req.body?.userId || req.query?.userId || req.headers['user-id'] || req.headers['x-user-id'] || '').trim();
        const appName = String(req.body?.appName || req.query?.appName || 'crazyreward').trim();
        const limit = Math.min(Number(req.body?.limit || req.query?.limit) || 100, 200);
        const skip = Number(req.body?.skip || req.query?.skip) || 0;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        await connectMongo();

        const formattedAppName = appName.toLowerCase().replace(/\s/g, '');

        // Fetch completed postback logs for this user
        const logs = await PostbackLogs.find({
            $or: [
                { userId: userId },
                { userId: new RegExp(`^${userId}$`, 'i') }
            ]
        })
            .sort({ completedAt: -1, createdAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean();

        if (!logs.length) {
            return res.status(200).json({
                success: true,
                data: [],
                totalCompleted: 0,
                totalCoinsEarned: 0
            });
        }

        // Fetch corresponding DailyTask offers
        const offerIds = [...new Set(logs.map(l => l.offerId).filter(Boolean))];
        const tasks = await DailyTask.find({ offerId: { $in: offerIds } }).lean();
        const taskMap = new Map();
        tasks.forEach(t => taskMap.set(t.offerId, t));

        let totalCoins = 0;
        const history = logs.map(log => {
            const task = taskMap.get(log.offerId);
            const coinsEarned = Number(log.coins || log.payout || task?.coins || 0);
            totalCoins += coinsEarned;

            // Determine event/step name if multi-event
            let stepTitle = 'Completed';
            if (log.eventId && log.eventId !== '__single__') {
                if (task?.events && task.events.length > 0) {
                    const matchedEvent = task.events.find(e => e.eventId.toLowerCase() === log.eventId.toLowerCase());
                    if (matchedEvent) {
                        stepTitle = matchedEvent.name || matchedEvent.label || log.eventId;
                    }
                } else if (task?.dailyRewards && task.dailyRewards.length > 0) {
                    const matchedReward = task.dailyRewards.find(r => `day_${r.day}`.toLowerCase() === log.eventId.toLowerCase());
                    if (matchedReward) {
                        stepTitle = `Day ${matchedReward.day} Reward`;
                    }
                } else {
                    stepTitle = log.eventId;
                }
            }

            return {
                id: log._id ? log._id.toString() : log.txnId,
                offerId: log.offerId,
                offerName: task?.offerName || log.offerId,
                offerCategory: task?.offerCategory || 'Daily Task',
                imagePath: task?.imagePath || '',
                bannerPath: task?.bannerPath || '',
                coins: coinsEarned,
                completedAt: log.completedAt || log.createdAt || new Date(),
                eventId: log.eventId || '',
                stepName: stepTitle,
                txnId: log.txnId,
                status: 'Completed',
                color: task?.color || '#3F97FF'
            };
        });

        return res.status(200).json({
            success: true,
            data: history,
            totalCompleted: history.length,
            totalCoinsEarned: totalCoins
        });
    } catch (err) {
        console.error('🔥 Error fetching daily task history:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Server-to-Server log user payout request
router.post('/api/log-payout', async (req, res) => {
    try {
        const apiKey = req.headers['x-api-key'];
        if (!apiKey || apiKey !== process.env.API_KEY) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }

        const {
            appName, userId, orderId, coins, amount, symbol, image,
            status, methodName, methodDetails, redeemUrl, redeemCode
        } = req.body || {};

        if (!appName || !userId || !orderId || !coins || !methodName) {
            return res.status(400).json({ success: false, message: 'Missing required payout log fields' });
        }

        // Check if duplicate
        const exists = await PayoutHistory.findOne({ orderId }).lean();
        if (exists) {
            return res.status(200).json({ success: true, message: 'Payout request already logged' });
        }

        const newPayout = new PayoutHistory({
            appName,
            userId,
            orderId,
            coins: Number(coins),
            amount: Number(amount || 0),
            symbol: symbol || '',
            image: image || '',
            status: status || 'pending',
            methodName,
            methodDetails: methodDetails || {},
            redeemUrl: redeemUrl || '',
            redeemCode: redeemCode || '',
            timestamp: new Date()
        });

        await newPayout.save();
        return res.status(200).json({ success: true, message: 'Payout request logged successfully' });
    } catch (err) {
        console.error('🔥 Error logging user payout:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Server-to-Server / Admin update payout status
router.post('/api/update-payout-status', async (req, res) => {
    try {
        const apiKey = req.headers['x-api-key'];
        const isAuthorized = (apiKey && apiKey === process.env.API_KEY) || req.session?.userId;
        if (!isAuthorized) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }

        const { orderId, status, txnId, redeemUrl, redeemCode, message } = req.body || {};
        if (!orderId || !status) {
            return res.status(400).json({ success: false, message: 'Missing orderId or status' });
        }

        const updateFields = {
            status,
            processTimestamp: new Date()
        };

        if (txnId !== undefined) updateFields.txnId = txnId;
        if (redeemUrl !== undefined) updateFields.redeemUrl = redeemUrl;
        if (redeemCode !== undefined) updateFields.redeemCode = redeemCode;
        if (message !== undefined) updateFields.message = message;

        const result = await PayoutHistory.findOneAndUpdate(
            { orderId },
            { $set: updateFields },
            { new: true }
        );

        if (!result) {
            return res.status(404).json({ success: false, message: 'Payout history record not found' });
        }

        return res.status(200).json({ success: true, message: 'Payout status updated successfully' });
    } catch (err) {
        console.error('🔥 Error updating payout status:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Get User Payout History (Paginated)
router.all('/api/get-payout-history', cryptoMiddleware, middleware, async (req, res) => {
    try {
        const userId = req.headers['x-user-id'] || req.body?.userId || req.query?.userId;
        const limit = req.body?.limit || req.query?.limit || 150;
        const skip = req.body?.skip || req.query?.skip || 0;
        const excludeFailed = req.query?.excludeFailed === 'true' || req.body?.excludeFailed === true;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        await connectMongo();

        const query = {
            userId: String(userId).trim()
        };
        if (excludeFailed) {
            query.status = { $nin: ['failed', 'rejected', 'refund', 'refunded'] };
        }

        const records = await PayoutRecord.find(query)
            .sort({ timestamp: -1, createdAt: -1 })
            .skip(Number(skip))
            .limit(Number(limit))
            .lean();

        let history = records;
        if (!history || history.length === 0) {
            history = await PayoutHistory.find(query)
                .sort({ timestamp: -1, createdAt: -1 })
                .skip(Number(skip))
                .limit(Number(limit))
                .lean();
        }

        return res.status(200).json({ success: true, data: history });
    } catch (err) {
        console.error('🔥 Error fetching user payout history:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Server-to-Server log payoutRecord request (MongoDB)
router.post('/api/log-payout-record', async (req, res) => {
    try {
        const apiKey = req.headers['x-api-key'];
        if (!apiKey || apiKey !== process.env.API_KEY) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }

        const {
            appName, userId, orderId, coins, amount, symbol, image,
            status, txnId, methodName, methodDetails, redeemUrl, redeemCode, email, autoPayment
        } = req.body || {};

        if (!appName || !userId || !orderId || !coins || !methodName) {
            return res.status(400).json({ success: false, message: 'Missing required payoutRecord fields' });
        }

        // Check if duplicate
        const exists = await PayoutRecord.findOne({ orderId }).lean();
        if (exists) {
            return res.status(200).json({ success: true, message: 'PayoutRecord already logged' });
        }

        const newRecord = new PayoutRecord({
            appName,
            userId,
            orderId,
            coins: Number(coins),
            amount: Number(amount || 0),
            symbol: symbol || '₹',
            image: image || '',
            status: status || 'pending',
            txnId: txnId || '',
            methodName,
            methodDetails: methodDetails || {},
            redeemUrl: redeemUrl || '',
            redeemCode: redeemCode || '',
            email: email || '',
            autoPayment: autoPayment || false,
            timestamp: new Date()
        });

        await newRecord.save();
        return res.status(200).json({ success: true, message: 'PayoutRecord logged successfully' });
    } catch (err) {
        console.error('🔥 Error logging PayoutRecord:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Server-to-Server update payoutRecord status
router.post('/api/update-payout-record-status', async (req, res) => {
    try {
        const apiKey = req.headers['x-api-key'];
        if (!apiKey || apiKey !== process.env.API_KEY) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }

        const { orderId, status, txnId, redeemCode, message, provider, apiOrderId, giftPin } = req.body || {};
        if (!orderId || !status) {
            return res.status(400).json({ success: false, message: 'Missing orderId or status' });
        }

        const updateFields = {
            status,
            processTimestamp: new Date()
        };

        if (txnId !== undefined) updateFields.txnId = txnId;
        if (redeemCode !== undefined) updateFields.redeemCode = redeemCode;
        if (message !== undefined) updateFields.message = message;
        if (provider !== undefined) updateFields.provider = provider;
        if (apiOrderId !== undefined) updateFields.apiOrderId = apiOrderId;
        if (giftPin !== undefined) updateFields.giftPin = giftPin;

        const result = await PayoutRecord.findOneAndUpdate(
            { orderId },
            { $set: updateFields },
            { new: true }
        );

        if (!result) {
            return res.status(404).json({ success: false, message: 'PayoutRecord not found' });
        }

        return res.status(200).json({ success: true, message: 'PayoutRecord updated successfully' });
    } catch (err) {
        console.error('🔥 Error updating PayoutRecord:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Fetch active wallet catalog options for app client (MongoDB)
router.all(['/api/get-wallet-methods', '/get-wallet-methods'], cryptoMiddleware, middleware, async (req, res) => {
    try {
        const appName = String(req.query.appName || req.body?.appName || '').trim();
        let countryResident = String(req.query.countryResident || req.body?.countryResident || 'IN').trim().toUpperCase();
        const methodId = String(req.query.methodId || req.query.id || req.body?.methodId || req.body?.id || '').trim();

        if (!countryResident || countryResident === 'UNKNOWN' || countryResident === 'NULL' || countryResident === 'UNDEFINED') {
            countryResident = 'IN';
        }
        if (countryResident === 'INDIA' || countryResident === 'IND') {
            countryResident = 'IN';
        }

        await connectMongo();

        const mongoQuery = {
            enabled: { $ne: false }
        };
        if (appName) {
            mongoQuery.appName = { $regex: new RegExp(`^${appName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') };
        }
        if (methodId) {
            mongoQuery.methodId = methodId;
        }

        // Fetch methods for the app
        const rawMethods = await WalletCatalog.find(mongoQuery).lean();

        const walletMethods = [];

        for (const method of rawMethods) {
            // Check country match if restricted
            const allowedCountries = Array.isArray(method.country)
                ? method.country.map(c => c.toUpperCase())
                : [];
            if (allowedCountries.length > 0 && !allowedCountries.includes('GLOBAL') && !allowedCountries.includes(countryResident)) {
                continue;
            }

            // Exclude countries filter
            const exCountries = Array.isArray(method.ex_country)
                ? method.ex_country.map(c => c.toUpperCase())
                : [];
            if (exCountries.includes(countryResident)) {
                continue;
            }

            // Filter enabled denominations & sort by amount
            const enabledDenoms = Array.isArray(method.denominations)
                ? method.denominations
                    .filter(d => d.enabled)
                    .map(d => ({
                        id: d.denomId,
                        amount: Number(d.amount) || 0,
                        coins: Number(d.coins) || 0,
                        enabled: true,
                        subtitle: d.subtitle || ''
                    }))
                    .sort((a, b) => a.amount - b.amount)
                : [];

            walletMethods.push({
                id: method.methodId,
                title: method.title || method.methodId,
                enabled: true,
                autoPayment: !!method.autoPayment,
                image: method.image || '',
                rank: Number(method.rank) || 0,
                symbol: method.symbol || '₹',
                validators: Array.isArray(method.validators) ? method.validators : [],
                hints: method.hints || {},
                denominations: enabledDenoms
            });
        }

        // Sort by rank, then id
        walletMethods.sort((a, b) => a.rank - b.rank || a.id.localeCompare(b.id));

        let appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        const hideDenomConfig = appDataDoc?.config?.hideDenomination || { enabled: false };

        return res.status(200).json({
            success: true,
            methods: walletMethods,
            hideDenomination: hideDenomConfig
        });
    } catch (err) {
        console.error('🔥 Error fetching wallet methods:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// =================== SCREENSHOT PROOF UPLOAD & STATUS ==========================
router.post('/app/submit-task-screenshot', middleware, upload.single('screenshot'), async (req, res) => {
    try {
        await connectMongo();
        const { userId, userEmail, appName, offerId, offerName, eventId, eventName, coins } = req.body;

        if (!userId || !offerId || !req.file) {
            return res.status(400).json({
                success: false,
                message: 'Missing required fields or screenshot file'
            });
        }

        // Save file to public/uploads/screenshots/
        const uploadDir = path.join(__dirname, '../public/uploads/screenshots');
        if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
        }

        const ext = path.extname(req.file.originalname) || '.jpg';
        const filename = `proof_${Date.now()}_${Math.random().toString(36).substring(2, 8)}${ext}`;
        const filePath = path.join(uploadDir, filename);

        fs.writeFileSync(filePath, req.file.buffer);

        const imageUrl = `/uploads/screenshots/${filename}`;

        // Create or update pending proof record
        const proof = await ScreenshotProof.create({
            userId: String(userId).trim(),
            userEmail: userEmail ? String(userEmail).trim() : '',
            appName: appName ? String(appName).trim() : 'crazyreward',
            offerId: String(offerId).trim(),
            offerName: offerName ? String(offerName).trim() : '',
            eventId: eventId ? String(eventId).trim() : '',
            eventName: eventName ? String(eventName).trim() : '',
            coins: Number(coins) || 0,
            imageUrl: imageUrl,
            status: 'pending',
        });

        return res.status(200).json({
            success: true,
            message: 'Screenshot submitted successfully for verification!',
            proofId: proof._id,
            imageUrl: imageUrl,
            status: 'pending'
        });
    } catch (err) {
        console.error('🔥 Error submitting task screenshot:', err);
        return res.status(500).json({ success: false, message: 'Server error uploading screenshot' });
    }
});

router.post('/app/get-task-screenshot-status', middleware, async (req, res) => {
    try {
        await connectMongo();
        const { userId, offerId, eventId } = req.body;
        if (!userId || !offerId) {
            return res.status(400).json({ success: false, message: 'Missing userId or offerId' });
        }

        const query = { userId: String(userId).trim(), offerId: String(offerId).trim() };
        if (eventId) query.eventId = String(eventId).trim();

        const latestProof = await ScreenshotProof.findOne(query).sort({ createdAt: -1 }).lean();

        if (!latestProof) {
            return res.json({ success: true, status: 'none', proof: null });
        }

        return res.json({
            success: true,
            status: latestProof.status,
            proof: {
                id: latestProof._id,
                imageUrl: latestProof.imageUrl,
                status: latestProof.status,
                rejectionReason: latestProof.rejectionReason || '',
                createdAt: latestProof.createdAt,
            }
        });
    } catch (err) {
        console.error('🔥 Error fetching screenshot status:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
