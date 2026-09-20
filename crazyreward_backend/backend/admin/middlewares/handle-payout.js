const crypto = require('crypto');
const axios = require('axios');
const PayoutHistory = require('../models/payoutHistory');
const PayoutRecord = require('../models/payoutRecord');
const { getOrInitFirebase } = require('./firebase-helper');
const { sendNotificationViaApi } = require('./send-notification-api');
const SuspiciousActivity = require('../models/suspiciousActivity');
const User = require('../models/user');
const AppData = require('../models/appData');
const connectMongo = require('./connectMongo');


const PAYOUT_API_URL = 'https://payment.appxo.in/user/api/payment-request.php';
const PAYOUT_API_TOKEN = process.env.PAYOUT_API_TOKEN || 'c8b7adb63c57eff39c4e604393ea635c3185f54b3ed9a2e7ae898bd3af12c002';
const WEBHOOK_SOURCE_HEADER = 'AppxoPayment';

function safeTrim(value) {
    return String(value || '').trim();
}

function resolvePaymentType(methodName, methodData, email) {
    const name = safeTrim(methodName).toLowerCase();

    if (name === 'upi') {
        return {
            type: 'UPI',
            type_id: safeTrim(methodData.upiId || methodData.upi_id || methodData.type_id),
            bene_name: safeTrim(methodData.name || methodData.bene_name),
        };
    }

    if (name === 'flipkart' || name === 'fp') {
        return { type: 'FP', type_id: safeTrim(methodData.email || email) };
    }

    if (name === 'amazon' || name === 'ar') {
        return { type: 'AR', type_id: safeTrim(methodData.email || email) };
    }

    if (name === 'googleplay' || name === 'google_play' || name === 'pr') {
        return { type: 'PR', type_id: safeTrim(methodData.email || email) };
    }

    // Recharge (General or Operator-Specific: Jio, Airtel, Vi, BSNL)
    if (name.startsWith('recharge') || name.includes('recharge') || name === 'phone' || name === 'jio' || name === 'airtel' || name === 'vi' || name === 'bsnl') {
        const rawNumber = safeTrim(methodData.mobileNumber || methodData.number || methodData.phone || methodData.type_id);
        
        let defaultOpcode = 'JIO';
        if (name.includes('airtel')) defaultOpcode = 'AIRTEL';
        else if (name.includes('vi') || name.includes('vodafone') || name.includes('idea')) defaultOpcode = 'VI';
        else if (name.includes('bsnl')) defaultOpcode = 'BSNL';
        else if (name.includes('jio')) defaultOpcode = 'JIO';

        const opcode = safeTrim(methodData.opcode || methodData.operator || defaultOpcode).toUpperCase();
        const state = safeTrim(methodData.state || methodData.circle || 'All India');
        const emailAddress = safeTrim(methodData.email_address || methodData.email || email || 'customer@gmail.com');

        return {
            type: 'RECHARGE',
            type_id: rawNumber,
            opcode: opcode,
            state: state,
            email_address: emailAddress,
        };
    }

    return null;
}

function encryptPayload(data, apiKey) {
    const key = Buffer.alloc(32);
    Buffer.from(apiKey, 'utf8').copy(key);

    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);

    let encrypted = cipher.update(JSON.stringify(data), 'utf8', 'base64');
    encrypted += cipher.final('base64');

    return Buffer.concat([iv, Buffer.from(encrypted, 'utf8')]).toString('base64');
}

function parseEventTime(value) {
    const raw = safeTrim(value);
    if (!raw) return null;

    // Appxo format: YYYY-MM-DD HH:mm:ss (assume local-time payload)
    const parsed = new Date(raw.replace(' ', 'T'));
    if (!Number.isNaN(parsed.getTime())) return parsed;

    const fallback = new Date(raw);
    if (!Number.isNaN(fallback.getTime())) return fallback;

    return null;
}

function normalizePostbackStatus(status) {
    const raw = safeTrim(status);
    const upper = raw.toUpperCase();

    if (upper === 'RECEIVED') return 'received';
    if (upper === 'SUCCESS') return 'success';
    if (upper === 'FAILED' || upper === 'REVERSED') return 'failed';

    return 'unknown';
}

function resolveImmediateStatus(apiResponse) {
    const apiStatus = safeTrim(apiResponse?.status).toLowerCase();
    const cfStatus = safeTrim(apiResponse?.cashfree_status).toUpperCase();

    if (apiStatus === 'error' || apiStatus === 'failed' || apiStatus === 'failure') return 'failed';

    if (safeTrim(apiResponse?.gift_code) || safeTrim(apiResponse?.gift_pin)) {
        return 'success';
    }

    // Direct Recharge success or API immediate success
    if (safeTrim(apiResponse?.opid) || (apiStatus === 'success' && !cfStatus)) {
        return 'success';
    }

    if (cfStatus === 'SUCCESS') return 'success';
    if (cfStatus === 'FAILED' || cfStatus === 'ERROR' || cfStatus === 'REVERSED') {
        return 'failed';
    }

    return 'inprogress';
}

function getNotification(status, customReason) {
    if (status === 'success') {
        return {
            title: 'Redeem Success',
            body: 'Your redeem has been processed successfully.',
        };
    }

    if (status === 'failed') {
        const reason = safeTrim(customReason);
        return {
            title: 'Redeem Declined',
            body: reason
                ? `Your redeem request has been declined. Reason: ${reason}. Coins have been refunded to your account.`
                : 'Your redeem request has been declined. Coins have been refunded to your account.',
        };
    }

    return {
        title: 'Redeem Inprogress',
        body: 'Your redeem is in progress. Please wait for some time.',
    };
}

async function sendPayoutNotification(userId, status, customReason) {
    try {
        const notification = getNotification(status, customReason);
        await sendNotificationViaApi({
            title: notification.title,
            body: notification.body,
            userId: safeTrim(userId),
            type: 'payment',
            data: {
                type: 'payment',
                status: status,
                ...(customReason ? { reason: customReason } : {}),
            }
        });
    } catch (err) {
        console.warn('⚠️ Notification API failed:', err?.message || err);
    }
}

async function resolvePayoutContextByOrderId(firebaseServices, orderId) {
    const normalizedOrderId = safeTrim(orderId);
    if (!normalizedOrderId) return null;

    await connectMongo();
    const record = await PayoutRecord.findOne({
        $or: [
            { orderId: normalizedOrderId },
            { apiOrderId: normalizedOrderId }
        ]
    }).lean();

    if (!record) return null;

    return {
        appName: record.appName,
        payoutRef: { id: record.orderId },
        payoutSnap: {
            id: record.orderId,
            data: () => record
        }
    };
}

async function handlePayoutRoute(_, res, { db, dbState, payoutRef, payoutData, orderId, FieldValue }) {
    const now = new Date();

    if (!PAYOUT_API_TOKEN) {
        try {
            await connectMongo();
            await PayoutRecord.updateOne({ orderId, status: 'processing_lock' }, { $set: { status: 'pending' } });
        } catch (_) {}
        return res.status(500).json({
            success: false,
            message: 'PAYOUT_API_TOKEN is missing',
        });
    }

    const methodName = safeTrim(payoutData.methodName);
    const methodData = payoutData[methodName] || {};
    const coins = Number(payoutData.coins) || 0;
    const amount = Number(payoutData.amount) || 0;
    const email = safeTrim(payoutData.email || methodData.email);
    const userId = safeTrim(payoutData.userId);

    if (!userId) {
        try {
            await connectMongo();
            await PayoutRecord.updateOne({ orderId, status: 'processing_lock' }, { $set: { status: 'pending' } });
        } catch (_) {}
        return res.status(400).json({
            success: false,
            message: 'User ID missing in payout record',
        });
    }

    const payment = resolvePaymentType(methodName, methodData, email);
    if (!payment || !payment.type_id) {
        try {
            await connectMongo();
            await PayoutRecord.updateOne({ orderId, status: 'processing_lock' }, { $set: { status: 'pending' } });
        } catch (_) {}
        return res.status(400).json({
            success: false,
            message: `Unsupported or incomplete payment method: "${methodName}"`,
        });
    }

    let activePayoutApiUrl = PAYOUT_API_URL;
    let activePayoutApiToken = PAYOUT_API_TOKEN;

    try {
        await connectMongo();
        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        if (appDataDoc?.config?.payoutApiUrl) {
            activePayoutApiUrl = String(appDataDoc.config.payoutApiUrl).trim();
        }
        if (appDataDoc?.config?.payoutApiToken) {
            activePayoutApiToken = String(appDataDoc.config.payoutApiToken).trim();
        }
    } catch (e) {
        console.warn('⚠️ Could not fetch AppData for dynamic payout API credentials, using fallback:', e.message);
    }

    const requestData = {
        api: activePayoutApiToken,
        amount: parseFloat(amount.toFixed(2)),
        type: payment.type,
        type_id: payment.type_id,
        comment: orderId,
        ...(payment.bene_name ? { bene_name: payment.bene_name } : {}),
        ...(payment.opcode ? { opcode: payment.opcode } : {}),
        ...(payment.state ? { state: payment.state } : {}),
        ...(payment.email_address ? { email_address: payment.email_address } : {}),
    };

    console.log('🎯 Outgoing Payout RequestData:', JSON.stringify(requestData));

    const encryptedPayload = encryptPayload(requestData, activePayoutApiToken);
    const authHeader = `Bearer ${Buffer.from(activePayoutApiToken).toString('base64')}`;

    let apiResponse;
    try {
        const { data } = await axios.post(
            activePayoutApiUrl,
            { data: encryptedPayload },
            {
                headers: {
                    Authorization: authHeader,
                    'Content-Type': 'application/json',
                },
                timeout: 30_000,
            },
        );

        apiResponse = data || {};
        console.log('🎯 Incoming Gateway Response:', JSON.stringify(apiResponse));
    } catch (apiErr) {
        console.error('❌ Payout API call failed:', apiErr?.response?.data || apiErr?.message || apiErr);

        if (apiErr?.response && apiErr?.response?.data) {
            apiResponse = apiErr.response.data;
            apiResponse.status = 'failed';
        } else {
            try {
                await connectMongo();
                await PayoutRecord.updateOne(
                    { orderId },
                    {
                        $set: {
                            status: 'failed',
                            message: safeTrim(apiErr?.message || 'Payout API unreachable.')
                        }
                    }
                );
            } catch (dbErr) {
                console.error('Failed to log API unreachable to MongoDB:', dbErr);
            }
            return res.status(502).json({
                success: false,
                message: 'Payout API unreachable. Please retry.',
            });
        }
    }

    const newStatus = resolveImmediateStatus(apiResponse);
    const apiOrderId = safeTrim(apiResponse.order_id || apiResponse.orderId || orderId);
    const transferId = safeTrim(apiResponse.cashfree_transfer_id || apiResponse.transfer_id || apiResponse.txid || apiResponse.opid);
    const giftCode = safeTrim(apiResponse.gift_code || apiResponse.opid || apiResponse.txid);
    const giftPin = safeTrim(apiResponse.gift_pin);

    const providerMsg = safeTrim(apiResponse.message || apiResponse.msg || apiResponse.error || apiResponse.description || apiResponse.reason || apiResponse.response_msg);
    const failureReason = newStatus === 'failed' ? (providerMsg || 'Gateway transaction declined') : '';

    const payoutUpdate = {
        status: newStatus,
        apiOrderId: apiOrderId || orderId,
        processTimestamp: now,
        ...(transferId ? { txnId: transferId } : {}),
        ...(giftCode ? { redeemCode: giftCode } : {}),
        ...(giftPin ? { giftPin: giftPin } : {}),
        ...(providerMsg ? { message: providerMsg } : {}),
        ...(failureReason ? { failureReason, rejectReason: failureReason } : {}),
        updatedAt: now
    };

    const historyUpdate = {
        orderId,
        userId,
        appName: payoutData.appName,
        methodName: methodName,
        coins: coins,
        amount: amount,
        symbol: payoutData.symbol || '₹',
        image: payoutData.image || '',
        status: newStatus,
        apiOrderId: apiOrderId || orderId,
        processTimestamp: now,
        ...(transferId ? { txnId: transferId } : {}),
        ...(giftCode ? { redeemCode: giftCode } : {}),
        ...(giftPin ? { giftPin: giftPin } : {}),
        ...(providerMsg ? { message: providerMsg } : {}),
        ...(failureReason ? { failureReason, rejectReason: failureReason } : {}),
        timestamp: payoutData.timestamp || now,
        updatedAt: now
    };

    // Update MongoDB PayoutRecord
    try {
        await connectMongo();
        await PayoutRecord.updateOne(
            { orderId },
            { $set: payoutUpdate }
        );

        if (newStatus === 'failed') {
            await User.updateOne({ userId }, { $inc: { coins: coins } });
        }

        await PayoutHistory.updateOne(
            { orderId },
            { $set: historyUpdate },
            { upsert: true }
        );
    } catch (mErr) {
        console.error('🔥 Failed to update PayoutRecord/History in MongoDB:', mErr);
    }

    await sendPayoutNotification(userId, newStatus, failureReason);

    return res.json({
        success: newStatus !== 'failed',
        status: newStatus,
        message: apiResponse.message || apiResponse.msg || (newStatus === 'inprogress' ? 'Payout request accepted.' : (newStatus === 'failed' ? 'Payout request failed.' : 'Payout processed.')),
        orderId: apiOrderId,
        txnId: transferId || undefined,
        giftCode: giftCode || undefined,
        giftPin: giftPin || undefined,
    });
}

async function handlePayoutPostback(req, res, { firebaseServices, FieldValue }) {
    const payload = req.body || {};
    const orderId = safeTrim(payload.order_id);
    const rawStatus = safeTrim(payload.status);
    const normalizedStatus = normalizePostbackStatus(rawStatus);

    if (!orderId) {
        return res.status(400).json({
            success: false,
            message: 'order_id is required',
        });
    }

    if (normalizedStatus === 'unknown') {
        return res.status(400).json({
            success: false,
            message: `Unsupported status: ${rawStatus || 'N/A'}`,
        });
    }

    // User request: RECEIVED should not trigger any state change.
    if (normalizedStatus === 'received') {
        return res.status(200).json({
            success: true,
            status: 'received',
            message: 'RECEIVED postback acknowledged (no action).',
        });
    }

    const ctx = await resolvePayoutContextByOrderId(firebaseServices, orderId);
    if (!ctx) {
        return res.status(404).json({
            success: false,
            message: 'Payout record not found for order_id',
            orderId,
        });
    }

    const { appName, db, firebase, payoutRef, payoutSnap } = ctx;
    const payoutData = payoutSnap.data() || {};
    const currentStatus = safeTrim(payoutData.status).toLowerCase();
    const finalStatus = normalizedStatus === 'success' ? 'success' : 'failed';
    const userId = safeTrim(payoutData.userId);
    const coins = Number(payoutData.coins) || 0;
    const email = safeTrim(payoutData.email || '');

    // 1. Header Spoofing check
    const source = safeTrim(req.headers['x-webhook-source']);
    if (source !== WEBHOOK_SOURCE_HEADER) {
        if (userId) {
            try {
                await connectMongo();
                await SuspiciousActivity.findOneAndUpdate(
                    { appName, userId },
                    {
                        $setOnInsert: { appName, userId, email, isBlocked: false },
                        $push: {
                            activities: {
                                type: 'payout_abuse',
                                details: `Spoofing attempt: Postback request hit with invalid header source '${source}' for order ${orderId}`,
                                coinValue: coins,
                                detectedAt: new Date(),
                            }
                        },
                        $set: { lastUpdated: new Date() }
                    },
                    { upsert: true }
                );
            } catch (err) {
                console.error('Failed to log suspicious activity (Header Spoofing):', err);
            }
        }
        return res.status(401).json({
            success: false,
            message: 'Invalid webhook source',
        });
    }

    // Idempotency guards.
    if (currentStatus === finalStatus) {
        return res.status(200).json({
            success: true,
            app: appName,
            status: finalStatus,
            message: `Already ${finalStatus}`,
        });
    }

    if (currentStatus === 'success' && finalStatus === 'failed') {
        if (userId) {
            try {
                await connectMongo();
                await SuspiciousActivity.findOneAndUpdate(
                    { appName, userId },
                    {
                        $setOnInsert: { appName, userId, email, isBlocked: false },
                        $push: {
                            activities: {
                                type: 'payout_abuse',
                                details: `Double Refund Attempt: Received 'failed' postback for order ${orderId} which was already successful`,
                                coinValue: coins,
                                detectedAt: new Date(),
                            }
                        },
                        $set: { lastUpdated: new Date() }
                    },
                    { upsert: true }
                );
            } catch (err) {
                console.error('Failed to log suspicious activity (Double Refund):', err);
            }
        }
        return res.status(200).json({
            success: true,
            app: appName,
            status: 'success',
            message: 'Ignored fail/reversed postback because payout already success.',
        });
    }

    if (currentStatus === 'failed' && finalStatus === 'success') {
        if (userId) {
            try {
                await connectMongo();
                await SuspiciousActivity.findOneAndUpdate(
                    { appName, userId },
                    {
                        $setOnInsert: { appName, userId, email, isBlocked: false },
                        $push: {
                            activities: {
                                type: 'payout_abuse',
                                details: `Time-Gap Bypass: Received 'success' postback for order ${orderId} which was already marked failed/refunded`,
                                coinValue: coins,
                                detectedAt: new Date(),
                            }
                        },
                        $set: { lastUpdated: new Date() }
                    },
                    { upsert: true }
                );
            } catch (err) {
                console.error('Failed to log suspicious activity (Time-Gap Bypass):', err);
            }
        }
        return res.status(200).json({
            success: true,
            app: appName,
            status: 'failed',
            message: 'Ignored success postback because payout already failed.',
        });
    }

    const now = new Date();
    const eventTime = parseEventTime(payload.event_time) || now;
    const transferMode = safeTrim(payload.transfer_mode).toUpperCase();
    const transferId = safeTrim(payload.transfer_id);
    const referenceId = safeTrim(payload.reference_id);
    const utr = safeTrim(payload.utr);
    const giftCode = safeTrim(payload.gift_code);
    const giftPin = safeTrim(payload.gift_pin);
    const amount = Number(payoutData.amount ?? payload.transfer_amount ?? payload.amount ?? 0) || 0;
    const postbackReason = safeTrim(payload.reason || payload.message || payload.error || payload.desc || payload.reject_reason || (rawStatus ? `Gateway status: ${rawStatus}` : ''));
    const failureReason = finalStatus === 'failed' ? (postbackReason || 'Gateway transaction declined') : '';

    const payoutUpdate = {
        status: finalStatus,
        provider: 'appxo',
        processTimestamp: eventTime,
        postbackStatus: rawStatus,
        transferMode: transferMode || null,
        txnId: transferId || referenceId || safeTrim(payoutData.txnId) || orderId,
        apiOrderId: safeTrim(payoutData.apiOrderId) || orderId,
        message: finalStatus === 'success'
            ? 'Payout completed from Appxo postback.'
            : (postbackReason ? `Redeem Failed: ${postbackReason}` : `Payout ${safeTrim(rawStatus).toUpperCase()} from Appxo postback.`),
        ...(failureReason ? { failureReason, rejectReason: failureReason } : {}),
        ...(utr ? { utr } : {}),
        ...(referenceId ? { referenceId } : {}),
        ...(giftCode ? { redeemCode: giftCode } : {}),
        ...(giftPin ? { giftPin: giftPin } : {}),
        apiPostbackRaw: payload,
    };

    // Update MongoDB PayoutRecord
    try {
        await connectMongo();
        await PayoutRecord.updateOne(
            { orderId },
            { $set: payoutUpdate }
        );
    } catch (mErr) {
        console.error('🔥 Failed to update PayoutRecord in MongoDB (postback):', mErr);
    }

    const shouldRefund = finalStatus === 'failed' && currentStatus !== 'failed' && currentStatus !== 'success';
    if (shouldRefund && userId) {
        try {
            await connectMongo();
            await User.updateOne(
                { userId },
                { $inc: { coins } }
            );
            console.log(`✅ Refunded ${coins} coins to MongoDB user ${userId} for failed payout ${payoutRef.id}`);
        } catch (rErr) {
            console.error('🔥 Failed to refund coins in MongoDB:', rErr);
        }
    }

    try {
        await PayoutHistory.updateOne(
            { orderId: payoutRef.id },
            {
                $set: {
                    status: finalStatus,
                    processTimestamp: eventTime,
                    txnId: payoutUpdate.txnId,
                    postbackStatus: rawStatus,
                    message: payoutUpdate.message,
                    ...(failureReason ? { failureReason, rejectReason: failureReason } : {}),
                    ...(utr ? { utr } : {}),
                    ...(referenceId ? { referenceId } : {}),
                    ...(giftCode ? { redeemCode: giftCode } : {}),
                    ...(giftPin ? { giftPin: giftPin } : {}),
                }
            },
            { upsert: true }
        );
    } catch (mErr) {
        console.error('🔥 Failed to update PayoutHistory in MongoDB (postback):', mErr);
    }

    await sendPayoutNotification(userId, finalStatus, failureReason);

    return res.status(200).json({
        success: true,
        app: appName,
        orderId,
        status: finalStatus,
        transferMode,
        message: finalStatus === 'success'
            ? 'Postback success processed.'
            : 'Postback failed/reversed processed with refund.',
    });
}

module.exports = {
    handlePayoutRoute,
    handlePayoutPostback,
    resolvePaymentType,
    resolveImmediateStatus,
    normalizePostbackStatus,
};
