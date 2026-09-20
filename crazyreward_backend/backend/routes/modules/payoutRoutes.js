const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const verifyAuthToken = require('../../admin/middlewares/verifyAuthToken');
const antiReplayMiddleware = require('../../admin/middlewares/antiReplayMiddleware');
const { cryptoMiddleware } = require('../../admin/middlewares/cryptoMiddleware');
const { handlePayoutRoute } = require('../../admin/middlewares/handle-payout');
const WalletCatalog = require('../../admin/models/walletCatalog');
const PayoutRecord = require('../../admin/models/payoutRecord');
const User = require('../../admin/models/user');
const { DateTime } = require('luxon');
const AppData = require('../../admin/models/appData');
const UserDailyChallenge = require('../../admin/models/userDailyChallenge');
const RewardHistory = require('../../admin/models/rewardHistory');
const Giveaway = require('../../admin/models/giveaway');
const cacheService = require('../../services/cacheService');
let BattleMatch = null;
try {
    BattleMatch = require('../../battle-arena/models/battleMatch');
} catch (e) {
    // Battle arena optional
}

// Concurrency lock for payout requests to prevent race conditions & double-spend
const activePayoutRequests = new Set();

/**
 * Helper to validate Daily Max Payout and Redeem Check prerequisites
 */
async function validatePayoutEligibility(userId, user, appName) {
    try {
        if (!user || user.isGuest === true || user.isAnonymous === true) {
            return {
                eligible: false,
                message: 'Guest accounts cannot redeem coins. Please log in with Google to continue!'
            };
        }

        let appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        if (!appDataDoc && appName) {
            appDataDoc = await AppData.findOne({ appName }).lean();
        }
        const config = appDataDoc?.config || {};
        const dailyMaxPayout = Number(config.dailyMaxPayout !== undefined ? config.dailyMaxPayout : (appDataDoc?.dailyMaxPayout !== undefined ? appDataDoc.dailyMaxPayout : 1));
        const redeemCheck = config.redeemCheck || { enabled: false, rules: [] };

        // 1. Check Daily Max Payout
        const nowIst = DateTime.now().setZone('Asia/Kolkata');
        const startOfDayIst = nowIst.startOf('day').toJSDate();
        const todayIstDateStr = nowIst.toISODate(); // 'YYYY-MM-DD'

        if (dailyMaxPayout > 0) {
            // Count pending & successful payouts for today (pending and success both count against the limit; failed/rejected/reversed do NOT)
            const todayPayoutsCount = await PayoutRecord.countDocuments({
                userId,
                status: { 
                    $in: [
                        'pending', 'inprogress', 'processing',
                        'success', 'completed', 'processed',
                        'PENDING', 'INPROGRESS', 'PROCESSING',
                        'SUCCESS', 'COMPLETED', 'PROCESSED'
                    ] 
                },
                $or: [
                    { createdAt: { $gte: startOfDayIst } },
                    { timestamp: { $gte: startOfDayIst } }
                ]
            });

            if (todayPayoutsCount >= dailyMaxPayout) {
                return {
                    eligible: false,
                    message: `Daily payout limit of ${dailyMaxPayout} reached. Please try again tomorrow.`
                };
            }
        }

        // 2. Check Redeem Check (Task Prerequisites)
        if (redeemCheck && (redeemCheck.enabled === true || redeemCheck.enabled === 'true') && Array.isArray(redeemCheck.rules)) {
            const enabledRules = redeemCheck.rules.filter(r => r && (r.enabled === true || r.enabled === 'true'));
            if (enabledRules.length > 0) {
                // Fetch user's daily challenge record for today
                const userDailyChallenge = await UserDailyChallenge.findOne({ userId, dateStr: todayIstDateStr }).lean();
                let taskProgress = {};
                if (userDailyChallenge && userDailyChallenge.taskProgress) {
                    if (typeof userDailyChallenge.taskProgress.get === 'function') {
                        taskProgress = Object.fromEntries(userDailyChallenge.taskProgress);
                    } else if (typeof userDailyChallenge.taskProgress === 'object') {
                        taskProgress = userDailyChallenge.taskProgress;
                    }
                }

                // Fetch today's reward histories for this user
                const todayRewards = await RewardHistory.find({
                    userId,
                    createdAt: { $gte: startOfDayIst }
                }).lean();

                for (const rule of enabledRules) {
                    const taskKey = String(rule.taskKey || '').trim().toLowerCase();
                    const minCount = Math.max(1, Number(rule.minCount) || 1);
                    const defaultMsg = `Please complete ${rule.taskName || taskKey} before redeeming`;
                    const baseErrMsg = rule.errorMessage && rule.errorMessage.trim() ? rule.errorMessage.trim() : defaultMsg;

                    let currentCount = 0;

                    if (taskKey === 'super_offer') {
                        const udcCount = Number(taskProgress['super_offer']) || 0;
                        const userClaimsToday = (user.superOfferClaimsDateStr === todayIstDateStr) ? (Number(user.superOfferClaimsToday) || 0) : 0;
                        const rewardCount = todayRewards.filter(r => r.provider && r.provider.toLowerCase().includes('super offer')).length;
                        currentCount = Math.max(udcCount, userClaimsToday, rewardCount);
                    } else if (taskKey === 'daily_challenge' || taskKey === 'daily_task') {
                        const hasClaimed = userDailyChallenge && userDailyChallenge.claimedReward === true;
                        const completedTasksCount = (userDailyChallenge && Array.isArray(userDailyChallenge.completedTasks)) ? userDailyChallenge.completedTasks.length : 0;
                        const udcCount = Number(taskProgress['daily_task'] || taskProgress['daily_challenge']) || 0;
                        const rewardCount = todayRewards.filter(r => r.provider && r.provider.toLowerCase().includes('daily challenge')).length;
                        currentCount = hasClaimed ? minCount : Math.max(completedTasksCount, udcCount, rewardCount);
                    } else if (taskKey === 'battle_arena') {
                        const udcCount = Number(taskProgress['battle_arena']) || 0;
                        let matchCount = 0;
                        if (BattleMatch) {
                            matchCount = await BattleMatch.countDocuments({
                                $or: [
                                    { 'player1.userId': userId },
                                    { 'player2.userId': userId },
                                    { 'players.userId': userId }
                                ],
                                status: 'COMPLETED',
                                createdAt: { $gte: startOfDayIst }
                            }).catch(() => 0);
                        }
                        const rewardCount = todayRewards.filter(r => r.provider && r.provider.toLowerCase().includes('battle')).length;
                        currentCount = Math.max(udcCount, matchCount, rewardCount);
                    } else if (taskKey === 'read_and_earn' || taskKey === 'read_earn') {
                        const udcCount = Number(taskProgress['read_and_earn'] || taskProgress['read_earn']) || 0;
                        const rewardCount = todayRewards.filter(r => r.provider && /read/i.test(r.provider)).length;
                        currentCount = Math.max(udcCount, rewardCount);
                    } else if (taskKey === 'watch_earn' || taskKey === 'watch_video') {
                        const udcCount = Number(taskProgress['watch_earn'] || taskProgress['watch_video']) || 0;
                        const rewardCount = todayRewards.filter(r => r.provider && /watch/i.test(r.provider)).length;
                        currentCount = Math.max(udcCount, rewardCount);
                    } else if (taskKey === 'play_games') {
                        const udcCount = Number(taskProgress['play_games']) || 0;
                        const rewardCount = todayRewards.filter(r => r.provider && /play games/i.test(r.provider)).length;
                        currentCount = Math.max(udcCount, rewardCount);
                    } else if (taskKey === 'diamond_catch') {
                        const udcCount = Number(taskProgress['diamond_catch']) || 0;
                        const rewardCount = todayRewards.filter(r => r.provider && /game gems|app install gems|catch/i.test(r.provider)).length;
                        currentCount = Math.max(udcCount, rewardCount);
                    } else if (taskKey === 'giveaway') {
                        let giveawayCount = 0;
                        if (Giveaway) {
                            giveawayCount = await Giveaway.countDocuments({
                                $or: [
                                    { 'joinedHistory.userId': userId, 'joinedHistory.joinedAt': { $gte: startOfDayIst } },
                                    { joinedUsers: userId, updatedAt: { $gte: startOfDayIst } }
                                ]
                            }).catch(() => 0);
                        }
                        const rewardCount = todayRewards.filter(r => r.provider && /giveaway/i.test(r.provider)).length;
                        currentCount = Math.max(giveawayCount, rewardCount);
                    } else if (taskKey === 'offerwall') {
                        const udcCount = Number(taskProgress['offerwall']) || 0;
                        const rewardCount = todayRewards.filter(r => r.provider && /pubscale|bitlabs|timewall|cpx|monlix|wannads|offerwall/i.test(r.provider)).length;
                        currentCount = Math.max(udcCount, rewardCount);
                    } else if (taskKey === 'survey') {
                        const udcCount = Number(taskProgress['survey']) || 0;
                        const rewardCount = todayRewards.filter(r => r.provider && /survey|bitlabs|cpx/i.test(r.provider)).length;
                        currentCount = Math.max(udcCount, rewardCount);
                    } else if (taskKey === 'daily_checkin') {
                        const udcCount = Number(taskProgress['daily_checkin']) || 0;
                        const rewardCount = todayRewards.filter(r => r.provider && /daily check-in/i.test(r.provider)).length;
                        currentCount = Math.max(udcCount, rewardCount);
                    } else {
                        // Custom task: regex match in taskProgress or RewardHistory
                        const udcCount = Number(taskProgress[taskKey]) || 0;
                        const regex = new RegExp(taskKey.replace(/_/g, '.*'), 'i');
                        const rewardCount = todayRewards.filter(r => r.provider && regex.test(r.provider)).length;
                        currentCount = Math.max(udcCount, rewardCount);
                    }

                    if (currentCount < minCount) {
                        const remainingCount = Math.max(0, minCount - currentCount);
                        let finalMsg = baseErrMsg;
                        if (finalMsg.includes('{completed}') || finalMsg.includes('{remaining}') || finalMsg.includes('{minCount}')) {
                            finalMsg = finalMsg
                                .replace(/\{completed\}/g, currentCount)
                                .replace(/\{remaining\}/g, remainingCount)
                                .replace(/\{minCount\}/g, minCount);
                        } else {
                            const cleanMsg = baseErrMsg.replace(/\.+$/, '').trim();
                            finalMsg = `${cleanMsg} (${remainingCount} remaining)`;
                        }

                        return {
                            eligible: false,
                            isRedeemCheck: true,
                            taskKey,
                            taskName: rule.taskName || taskKey,
                            currentCount,
                            minCount,
                            remainingCount,
                            message: finalMsg
                        };
                    }
                }
            }
        }

        return { eligible: true };
    } catch (err) {
        console.error('🔥 Error validating payout eligibility:', err);
        return { eligible: true };
    }
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
    const hasDeviceHeaders = Boolean(userIdHeader && deviceIdHeader);
    const isAdmin = Boolean(req.cookies && (req.cookies.adminToken || req.cookies.admin));

    if (hasValidKey || hasToken || hasPayload || hasDeviceHeaders || isAdmin) {
        return next();
    }
    return res.status(401).json({ success: false, message: 'Unauthorized: Authentication required' });
};

// Get Wallet Methods Catalog
router.all(['/wallet-methods', '/get-wallet-methods'], cryptoMiddleware, clientAuthMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const appName = String(req.query.appName || req.body?.appName || '').trim();
        let countryResident = String(req.query.countryResident || req.body?.countryResident || 'IN').trim().toUpperCase();
        const methodId = String(req.query.methodId || req.query.id || req.body?.methodId || req.body?.id || '').trim();

        if (!countryResident || countryResident === 'UNKNOWN' || countryResident === 'NULL' || countryResident === 'UNDEFINED') {
            countryResident = 'IN';
        }
        if (countryResident === 'INDIA' || countryResident === 'IND') {
            countryResident = 'IN';
        }

        const cacheKey = `wallet:methods:${appName || 'all'}:${countryResident}:${methodId || 'all'}`;
        const cached = await cacheService.get(cacheKey);
        if (cached) {
            return res.json(cached);
        }

        const mongoQuery = {
            enabled: { $ne: false }
        };
        if (appName) {
            mongoQuery.appName = { $regex: new RegExp(`^${appName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') };
        }
        if (methodId) {
            mongoQuery.methodId = methodId;
        }

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
                    .filter(d => d.enabled !== false)
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

        const responsePayload = { success: true, methods: walletMethods, hideDenomination: hideDenomConfig };
        await cacheService.set(cacheKey, responsePayload, cacheService.getTtl('global'));
        return res.json(responsePayload);
    } catch (err) {
        console.error('❌ Get wallet methods error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch wallet methods' });
    }
});

// Get Payout History
router.all(['/history', '/payout-history'], verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId || req.body?.userId;
        const history = await PayoutRecord.find({ userId }).sort({ timestamp: -1 }).lean();
        return res.json({ success: true, history });
    } catch (err) {
        console.error('❌ Get payout history error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch payout history' });
    }
});

// Request Payout
router.post('/request', cryptoMiddleware, antiReplayMiddleware, verifyAuthToken, async (req, res) => {
    let coinsDeductedFlag = false;
    let coinsToRefund = 0;
    let targetUserId = null;
    let lockKey = null;

    try {
        await connectMongo();
        const userId = req.userId;
        targetUserId = userId;
        let { coinsRequired, amount, paymentMethod, paymentDetail, id, symbol, image, appName } = req.body;

        if (!userId) {
            return res.status(400).json({ success: false, response: 'error', message: 'Missing user authentication' });
        }

        lockKey = `payout_lock:${userId}`;
        if (activePayoutRequests.has(lockKey)) {
            return res.status(429).json({
                success: false,
                response: 'error',
                message: 'A withdrawal request is already being processed. Please wait a moment.'
            });
        }
        activePayoutRequests.add(lockKey);

        const user = await User.findOne({ userId });
        if (!user) {
            return res.status(404).json({ success: false, response: 'error', message: 'User not found' });
        }

        if (user.isGuest || user.isAnonymous) {
            return res.status(403).json({
                success: false,
                response: 'error',
                message: 'Guest accounts cannot redeem coins. Please log in with Google to continue!'
            });
        }

        if (user.payoutBlocked) {
            return res.status(403).json({
                success: false,
                response: 'error',
                message: user.payoutBlockReason || 'Redemptions are currently blocked for your account.'
            });
        }

        appName = String(appName || user.appName || '').trim();

        // 🛡️ Verify Daily Max Payout limit and Redeem Check prerequisites
        const eligibility = await validatePayoutEligibility(userId, user, appName);
        if (!eligibility.eligible) {
            return res.status(400).json({
                success: false,
                response: 'error',
                isRedeemCheck: eligibility.isRedeemCheck === true,
                message: eligibility.message,
                taskKey: eligibility.taskKey,
                taskName: eligibility.taskName,
                currentCount: eligibility.currentCount,
                minCount: eligibility.minCount,
                remainingCount: eligibility.remainingCount
            });
        }
        let catalogItem = null;

        // If denomination ID is passed, resolve coinsRequired & paymentMethod from WalletCatalog
        if (id) {
            catalogItem = await WalletCatalog.findOne({
                'denominations.denomId': id
            }).lean();

            if (catalogItem) {
                paymentMethod = paymentMethod || catalogItem.methodId;
                symbol = symbol || catalogItem.symbol || '';
                image = image || catalogItem.image || '';
                const denom = (catalogItem.denominations || []).find(d => d.denomId === id);
                if (denom) {
                    coinsRequired = coinsRequired || Number(denom.coins) || 0;
                    amount = amount || Number(denom.amount) || 0;
                }
            }
        }

        if (!catalogItem && paymentMethod) {
            catalogItem = await WalletCatalog.findOne({
                appName: appName,
                methodId: paymentMethod
            }).lean();
        }

        if (catalogItem && catalogItem.enabled === false) {
            return res.status(400).json({ success: false, response: 'error', message: 'This payout method is currently disabled' });
        }

        coinsRequired = Number(coinsRequired) || 0;
        amount = Number(amount) || 0;
        symbol = symbol || '';
        image = image || '';

        if (!coinsRequired || coinsRequired <= 0 || !paymentMethod) {
            return res.status(400).json({ success: false, response: 'error', message: 'Invalid payout details' });
        }

        // Extract payment detail if not provided in req.body
        if (!paymentDetail && user[paymentMethod]) {
            paymentDetail = user[paymentMethod];
        }

        const clientIp = req.headers['cf-connecting-ip'] ||
                         req.headers['x-forwarded-for']?.split(',')[0] ||
                         req.headers['x-real-ip'] ||
                         req.ip ||
                         req.socket?.remoteAddress ||
                         '';
        const cleanIp = String(clientIp).trim().replace(/^::ffff:/, '');

        // 🛡️ ATOMIC MongoDB deduction: Prevents concurrent double-spend / multi-tap exploit
        const deductedUser = await User.findOneAndUpdate(
            {
                userId,
                coins: { $gte: coinsRequired },
                isBlocked: { $ne: true },
                blocked: { $ne: true },
                payoutBlocked: { $ne: true },
                isGuest: { $ne: true },
                isAnonymous: { $ne: true }
            },
            {
                $inc: { coins: -coinsRequired },
                $set: { lastActiveAt: new Date(), ...(cleanIp ? { ipAddress: cleanIp } : {}) }
            },
            { new: true }
        );

        if (!deductedUser) {
            return res.status(400).json({
                success: false,
                response: 'error',
                message: 'Insufficient coins balance or account restricted'
            });
        }
        coinsDeductedFlag = true;
        coinsToRefund = coinsRequired;

        const orderId = `DP_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;
        const isAutoPayment = catalogItem && catalogItem.autoPayment === true;

        const payout = await PayoutRecord.create({
            orderId,
            userId,
            appName: appName,
            methodName: paymentMethod,
            coins: coinsRequired,
            amount: amount,
            symbol: symbol,
            image: image,
            status: isAutoPayment ? 'inprogress' : 'pending',
            autoPayment: isAutoPayment,
            methodDetails: typeof paymentDetail === 'object' ? paymentDetail : { email: paymentDetail || user.email, upiId: paymentDetail },
            email: user.email || (typeof paymentDetail === 'string' ? paymentDetail : paymentDetail?.email || ''),
            timestamp: new Date()
        });

        // 🌐 Outgoing Postback Trigger for First Withdraw/Redeem (Case 2)
        try {
            const previousPayouts = await PayoutRecord.countDocuments({ userId, orderId: { $ne: orderId }, status: { $in: ['success', 'completed', 'processed', 'SUCCESS', 'COMPLETED', 'PROCESSED'] } });
            if (previousPayouts === 0) {
                if (user.publisherRef && user.publisherUid) {
                    const triggerOutgoingPostback = require('../../services/publisherPostbackService');
                    triggerOutgoingPostback({
                        user,
                        offerId: 'first_withdraw',
                        coins: coinsRequired,
                        eventId: ''
                    }).catch(err => console.error("⚠️ S2S Outgoing Postback error:", err.message));
                }
            }
        } catch (postbackErr) {
            console.error("⚠️ Payout postback check failed:", postbackErr.message);
        }

        if (isAutoPayment) {
            const dummyRes = {
                status: (code) => ({ json: (d) => d }),
                json: (d) => d
            };
            try {
                const payoutDataForAuto = payout.toObject();
                payoutDataForAuto[paymentMethod] = payout.methodDetails;
                payoutDataForAuto.email = payout.email || user.email;

                await handlePayoutRoute(null, dummyRes, {
                    db: null,
                    dbState: { appName },
                    payoutRef: null,
                    payoutData: payoutDataForAuto,
                    orderId: payout.orderId,
                    FieldValue: null
                });

                const updatedPayout = await PayoutRecord.findOne({ orderId }).lean();
                if (updatedPayout) {
                    if (updatedPayout.status === 'failed') {
                        const freshUser = await User.findOne({ userId }).lean();
                        return res.json({
                            success: false,
                            response: 'error',
                            message: updatedPayout.message || 'Payout failed at provider gateway. Coins have been refunded.',
                            coins: freshUser ? freshUser.coins : user.coins + coinsRequired,
                            payout: updatedPayout
                        });
                    }

                    return res.json({
                        success: true,
                        response: 'success',
                        message: updatedPayout.status === 'success' ? 'Payout completed successfully' : 'Payout request submitted',
                        coins: user.coins,
                        payout: updatedPayout
                    });
                }
            } catch (autoErr) {
                console.error('🔥 Auto-payout execution error:', autoErr);
            }
        }

        // Send Push Notification
        try {
            const sendNotificationViaApi = require('../../admin/middlewares/send-notification-api');
            sendNotificationViaApi({
                title: 'Withdrawal Request Submitted! ⏳',
                body: `Your withdrawal request of ₹${amount} has been received and is under review.`,
                userId: userId,
            }).catch(e => console.warn('⚠️ Payout request push error:', e?.message || e));
        } catch (_) {}

        return res.json({
            success: true,
            response: 'success',
            message: 'Payout request submitted successfully',
            coins: deductedUser.coins,
            payout
        });
    } catch (err) {
        console.error('❌ Payout request error:', err);
        if (coinsDeductedFlag && targetUserId && coinsToRefund > 0) {
            await User.updateOne(
                { userId: targetUserId },
                { $inc: { coins: coinsToRefund } }
            ).catch(e => console.error('Failed to refund coins on error:', e));
        }
        return res.status(500).json({ success: false, response: 'error', message: err?.message || 'Failed to request payout' });
    } finally {
        if (lockKey) {
            activePayoutRequests.delete(lockKey);
        }
    }
});

module.exports = router;
