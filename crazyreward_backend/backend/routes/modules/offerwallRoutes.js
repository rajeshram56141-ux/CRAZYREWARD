const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const connectMongo = require('../../admin/middlewares/connectMongo');
const User = require('../../admin/models/user');
const RewardHistory = require('../../admin/models/rewardHistory');
const PostbackLogs = require('../../admin/models/postbackLogs');
const OffersSettings = require('../../admin/models/offersSettings');

/**
 * Verifies offerwall provider authenticity (Signature, Secret Key, or API Key)
 */
async function verifyOfferwallAuth(providerName, req) {
    try {
        await connectMongo();
        const query = { ...req.query, ...req.body };
        const offersDoc = await OffersSettings.findOne({ key: 'offersSettings' }).lean();
        const offersConfig = offersDoc?.config || {};

        // Find provider config (case-insensitive)
        const provKey = Object.keys(offersConfig).find(k => k.toLowerCase() === providerName.toLowerCase()) || providerName;
        const providerConfig = offersConfig[provKey] || {};

        const configuredSecret = String(
            providerConfig.secretKey ||
            providerConfig.secret ||
            providerConfig.key ||
            process.env[`OFFERWALL_${providerName.toUpperCase()}_KEY`] ||
            process.env.OFFERWALL_SECRET_KEY ||
            ''
        ).trim();

        const receivedSecret = String(
            query.secret ||
            query.secretKey ||
            query.key ||
            query.token ||
            req.headers['x-api-key'] ||
            req.headers['x-postback-secret'] ||
            ''
        ).trim();

        const receivedSignature = String(
            query.signature ||
            query.sig ||
            query.hash ||
            req.headers['x-signature'] ||
            ''
        ).trim();

        // If provider has configured secret, check secret or signature
        if (configuredSecret) {
            if (receivedSecret && receivedSecret === configuredSecret) {
                return true;
            }
            if (receivedSignature) {
                const uid = String(query.user_id || query.userId || query.subId || query.uid || query.sub_id || '').trim();
                const val = String(Math.trunc(Number(query.value || query.amount || query.val || query.reward || query.payout || query.coins || 0)));
                const tx = String(query.trans_id || query.token || query.tx || query.tx_id || query.transactionID || query.transaction_id || '').trim();

                const md5Sig1 = crypto.createHash('md5').update(`${configuredSecret}.${uid}.${val}.${tx}`).digest('hex');
                const md5Sig2 = crypto.createHash('md5').update(`${uid}:${tx}:${val}:${configuredSecret}`).digest('hex');
                const sha256Sig = crypto.createHash('sha256').update(`${configuredSecret}:${uid}:${tx}:${val}`).digest('hex');
                const hmacSig = crypto.createHmac('sha256', configuredSecret).update(`${uid}:${tx}:${val}`).digest('hex');

                if ([md5Sig1, md5Sig2, sha256Sig, hmacSig].some(s => s.toLowerCase() === receivedSignature.toLowerCase())) {
                    return true;
                }
            }
            return false;
        }

        // Global fallback API key
        const globalApiKey = String(process.env.API_KEY || '').trim();
        if (globalApiKey && receivedSecret === globalApiKey) {
            return true;
        }

        // If no secret configured and no auth provided, reject unauthorized postback
        return false;
    } catch (authErr) {
        console.error('🔥 Offerwall auth error:', authErr);
        return false;
    }
}

// Helper to credit user and log history
async function processOfferwallRecord({ appName = '', provider, userId, coins, transId, offerId, type = 'Offerwall' }) {
    if (!userId || !coins || coins <= 0) return false;

    await connectMongo();

    const cleanProvider = String(provider || 'Offerwall').trim();
    const orderId = transId ? `${cleanProvider.toLowerCase().replace(/\s+/g, '')}_${transId}` : `${cleanProvider.toLowerCase().replace(/\s+/g, '')}_${userId}_${Date.now()}`;

    // Prevent duplicate credits
    const existing = await RewardHistory.findOne({ orderId }).lean();
    if (existing) {
        console.log(`ℹ️ [${cleanProvider} Postback] Duplicate transaction ignored: ${orderId}`);
        return true;
    }

    // Atomic credit to prevent race conditions and enforce account safety
    const user = await User.findOneAndUpdate(
        {
            userId,
            account_deleted: { $ne: true },
            blocked: { $ne: true },
            isBlocked: { $ne: true },
            isGuest: { $ne: true },
            isAnonymous: { $ne: true }
        },
        {
            $inc: { coins: coins, totalCoins: coins },
            $set: { lastActiveAt: new Date() }
        },
        { new: true }
    );

    if (!user) {
        console.warn(`❌ [${cleanProvider} Postback] User not found, blocked, deleted, or guest: ${userId}`);
        return false;
    }

    // Log to RewardHistory
    await RewardHistory.create({
        appName: user.appName || appName,
        userId: userId,
        provider: `${cleanProvider} ${type}`,
        coins: coins,
        rewardType: 'coin',
        orderId: orderId,
        transId: transId || null,
        timestamp: new Date()
    }).catch(err => console.error('⚠️ RewardHistory create warning:', err));

    // 🌐 Outgoing S2S Postback Trigger for Generic Offerwall Completion (Case 2)
    if (user.publisherRef && user.publisherUid) {
        try {
            const triggerOutgoingPostback = require('../../services/publisherPostbackService');
            triggerOutgoingPostback({
                user,
                offerId: 'offerwall_task_complete',
                coins: coins,
                eventId: cleanProvider
            }).catch(err => console.error("⚠️ S2S Outgoing Postback error:", err.message));
        } catch (loadErr) {
            console.error("⚠️ Failed to load publisherPostbackService:", loadErr.message);
        }
    }

    // Log to PostbackLogs
    await PostbackLogs.create({
        appName: user.appName || appName,
        userId: userId,
        offerId: offerId || transId || `${cleanProvider.toLowerCase()}_offer`,
        provider: cleanProvider,
        coins: coins,
        status: 'completed',
        timestamp: new Date()
    }).catch(err => console.error('⚠️ PostbackLogs create warning:', err));

    // Send Push Notification
    try {
        const sendNotificationViaApi = require('../../admin/middlewares/send-notification-api');
        sendNotificationViaApi({
            title: 'Offerwall Reward Credited! 🎉',
            body: `You received +${coins} coins from ${cleanProvider}!`,
            userId: userId,
        }).catch(e => console.warn(`⚠️ [${cleanProvider}] Push error:`, e?.message || e));
    } catch (_) {}

    // Track Daily Challenge progress for Offerwalls
    try {
        const { trackDailyChallengeProgress } = require('./dailyChallengeApiRoutes');
        trackDailyChallengeProgress(userId, 'offerwall', 1);
        trackDailyChallengeProgress(userId, 'daily_task', 1);
    } catch (_) {}

    // 🤝 Referral Commission & Joinee Bonus Trigger
    try {
        const { distributeTaskReferralCommission, checkAndUnlockTaskReferrerBonus } = require('../../services/referralCommissionService');
        checkAndUnlockTaskReferrerBonus(userId, 'offerwall').catch(e => console.error(`⚠️ [${cleanProvider}] Ref bonus error:`, e.message));
        distributeTaskReferralCommission(userId, coins, cleanProvider || 'Offerwall').catch(e => console.error(`⚠️ [${cleanProvider}] Ref comm error:`, e.message));
    } catch (refErr) {
        console.error(`⚠️ [${cleanProvider}] Referral processing error:`, refErr.message);
    }

    console.log(`✅ [${cleanProvider} Postback] Successfully credited ${coins} coins to user ${userId}`);
    return true;
}

// 1. Pubscale Postback
router.all(['/pubscale', '/postback/pubscale'], async (req, res) => {
    const name = 'PubScale';
    try {
        const query = { ...req.query, ...req.body };
        const { user_id, userId, token, value, signature, type, offer_id, payout, reward } = query;

        const uid = String(user_id || userId || query.subId || '').trim();
        const transId = String(token || query.trans_id || query.tx_id || '').trim();
        const coins = Number(value || payout || reward || query.amount || 0);

        if (!uid || coins <= 0) {
            return res.status(400).send('0');
        }

        const isAuthorized = await verifyOfferwallAuth(name, req);
        if (!isAuthorized) {
            console.warn(`[PubScale Postback] Unauthorized postback attempt for user ${uid}`);
            return res.status(401).send('0');
        }

        const success = await processOfferwallRecord({
            provider: name,
            userId: uid,
            coins: coins,
            transId: transId,
            offerId: String(offer_id || '').trim(),
            type: 'Offerwall'
        });

        return res.status(success ? 200 : 400).send(success ? '1' : '0');
    } catch (err) {
        console.error('❌ PubScale Postback error:', err);
        return res.status(500).send('0');
    }
});

// 2. Bitlabs Postback
router.all(['/bitlabs', '/postback/bitlabs'], async (req, res) => {
    const name = 'BitLabs';
    try {
        const query = { ...req.query, ...req.body };
        const uid = String(query.uid || query.userId || query.sub_id || '').trim();
        const transId = String(query.tx || query.trans_id || '').trim();
        const coins = Number(query.val || query.reward || query.amount || 0);

        if (!uid || coins <= 0) {
            return res.status(400).send('0');
        }

        const isAuthorized = await verifyOfferwallAuth(name, req);
        if (!isAuthorized) {
            console.warn(`[BitLabs Postback] Unauthorized postback attempt for user ${uid}`);
            return res.status(401).send('0');
        }

        const success = await processOfferwallRecord({
            provider: name,
            userId: uid,
            coins: coins,
            transId: transId,
            offerId: String(query.offer_id || '').trim(),
            type: 'Survey'
        });

        return res.status(success ? 200 : 400).send(success ? '1' : '0');
    } catch (err) {
        console.error('❌ Bitlabs Postback error:', err);
        return res.status(500).send('0');
    }
});

// 3. CPX Research Postback
router.all(['/cpx', '/postback/cpx', '/cpxresearch'], async (req, res) => {
    const name = 'CPX Research';
    try {
        const query = { ...req.query, ...req.body };
        const uid = String(query.sub_id || query.userId || query.uid || '').trim();
        const transId = String(query.trans_id || query.tx_id || '').trim();
        const coins = Number(query.amount || query.reward || query.payout || 0);
        const status = String(query.status || '1').toLowerCase();

        if (!uid || coins <= 0 || status === '2' || status === 'rejected') {
            return res.status(200).send('1');
        }

        const isAuthorized = await verifyOfferwallAuth(name, req);
        if (!isAuthorized) {
            console.warn(`[CPX Postback] Unauthorized postback attempt for user ${uid}`);
            return res.status(401).send('0');
        }

        const success = await processOfferwallRecord({
            provider: name,
            userId: uid,
            coins: coins,
            transId: transId,
            offerId: String(query.offer_id || '').trim(),
            type: 'Survey'
        });

        return res.status(success ? 200 : 400).send(success ? '1' : '0');
    } catch (err) {
        console.error('❌ CPX Research Postback error:', err);
        return res.status(500).send('0');
    }
});

// 4. Timewall Postback
router.all(['/timewall', '/postback/timewall'], async (req, res) => {
    const name = 'Timewall';
    try {
        const query = { ...req.query, ...req.body };
        const uid = String(query.userID || query.userId || query.uid || '').trim();
        const transId = String(query.transactionID || query.transId || '').trim();
        const coins = Number(query.currencyAmount || query.revenue || query.amount || 0);

        if (!uid || coins <= 0) {
            return res.status(400).send('0');
        }

        const isAuthorized = await verifyOfferwallAuth(name, req);
        if (!isAuthorized) {
            console.warn(`[Timewall Postback] Unauthorized postback attempt for user ${uid}`);
            return res.status(401).send('0');
        }

        const success = await processOfferwallRecord({
            provider: name,
            userId: uid,
            coins: coins,
            transId: transId,
            offerId: String(query.offerId || '').trim(),
            type: 'Offerwall'
        });

        return res.status(success ? 200 : 400).send(success ? '1' : '0');
    } catch (err) {
        console.error('❌ Timewall Postback error:', err);
        return res.status(500).send('0');
    }
});

// 5. GrowDeck Postback
router.all(['/growdeck', '/postback/growdeck'], async (req, res) => {
    const name = 'GrowDeck';
    try {
        const query = { ...req.query, ...req.body };
        const uid = String(query.user_id || query.userId || query.uid || '').trim();
        const transId = String(query.trans_id || query.tx_id || query.transaction_id || '').trim();
        const coins = Number(query.reward || query.amount || query.payout || 0);

        if (!uid || coins <= 0) {
            return res.status(400).send('0');
        }

        const isAuthorized = await verifyOfferwallAuth(name, req);
        if (!isAuthorized) {
            console.warn(`[GrowDeck Postback] Unauthorized postback attempt for user ${uid}`);
            return res.status(401).send('0');
        }

        const success = await processOfferwallRecord({
            provider: name,
            userId: uid,
            coins: coins,
            transId: transId,
            offerId: String(query.offer_id || '').trim(),
            type: 'Offerwall'
        });

        return res.status(success ? 200 : 400).send(success ? '1' : '0');
    } catch (err) {
        console.error('❌ GrowDeck Postback error:', err);
        return res.status(500).send('0');
    }
});

// 6. Playtime Ads Postback
router.all(['/playtimeads', '/postback/playtimeads'], async (req, res) => {
    const name = 'Playtime Ads';
    try {
        const query = { ...req.query, ...req.body };
        const uid = String(query.userId || query.user_id || query.uid || '').trim();
        const transId = String(query.txId || query.trans_id || '').trim();
        const coins = Number(query.coins || query.amount || query.reward || 0);

        if (!uid || coins <= 0) {
            return res.status(400).send('0');
        }

        const isAuthorized = await verifyOfferwallAuth(name, req);
        if (!isAuthorized) {
            console.warn(`[Playtime Ads Postback] Unauthorized postback attempt for user ${uid}`);
            return res.status(401).send('0');
        }

        const success = await processOfferwallRecord({
            provider: name,
            userId: uid,
            coins: coins,
            transId: transId,
            offerId: String(query.offerId || '').trim(),
            type: 'Offerwall'
        });

        return res.status(success ? 200 : 400).send(success ? '1' : '0');
    } catch (err) {
        console.error('❌ Playtime Ads Postback error:', err);
        return res.status(500).send('0');
    }
});

// 7. Generic Dynamic Offerwall & Survey Postback Catch-All
router.all(['/postback/:provider', '/offerwall/:provider'], async (req, res) => {
    const rawProvider = req.params.provider || 'Offerwall';
    const providerName = rawProvider.charAt(0).toUpperCase() + rawProvider.slice(1);

    try {
        const query = { ...req.query, ...req.body };
        const uid = String(query.user_id || query.userId || query.subId || query.uid || query.sub_id || query.snuid || '').trim();
        const transId = String(query.trans_id || query.transaction_id || query.tx_id || query.txId || query.orderId || query.id || '').trim();
        const coins = Number(query.amount || query.payout || query.coins || query.reward || query.currency || 0);
        const status = String(query.status || query.statusCode || '1').toLowerCase();

        if (!uid || coins <= 0) {
            return res.status(400).send('0');
        }

        if (status === '0' || status === 'reversed' || status === 'cancel' || status === 'rejected') {
            console.warn(`⚠️ [${providerName} Postback] Ignored due to status=${status}`);
            return res.status(200).send('1');
        }

        const isAuthorized = await verifyOfferwallAuth(providerName, req);
        if (!isAuthorized) {
            console.warn(`[${providerName} Postback] Unauthorized postback attempt for user ${uid}`);
            return res.status(401).send('0');
        }

        const success = await processOfferwallRecord({
            provider: providerName,
            userId: uid,
            coins: coins,
            transId: transId,
            offerId: String(query.offer_id || query.offerId || '').trim(),
            type: 'Offerwall'
        });

        return res.status(success ? 200 : 400).send(success ? '1' : '0');
    } catch (err) {
        console.error(`❌ [${providerName} Postback] error:`, err);
        return res.status(500).send('0');
    }
});

module.exports = router;
