require('dotenv').config();
const axios = require('axios');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

function safeTrim(value) {
    return String(value || '').trim();
}

let cachedFirebaseApp = null;

function getFirebaseAdmin() {
    if (cachedFirebaseApp) return cachedFirebaseApp;
    try {
        if (admin.apps && admin.apps.length > 0) {
            cachedFirebaseApp = admin.app();
            return cachedFirebaseApp;
        }
    } catch (_) {}

    const candidatePaths = [
        path.join(__dirname, '../../serviceAccountKey.json'),
        path.join(__dirname, '../serviceAccountKey.json'),
        path.join(__dirname, '../../../serviceAccountKey.json'),
        path.join(process.cwd(), 'serviceAccountKey.json'),
        path.join(process.cwd(), 'backend/serviceAccountKey.json'),
    ];

    for (const keyPath of candidatePaths) {
        if (fs.existsSync(keyPath)) {
            try {
                const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
                cachedFirebaseApp = admin.initializeApp({
                    credential: admin.credential.cert(serviceAccount),
                });
                return cachedFirebaseApp;
            } catch (err) {
                console.warn('⚠️ Error initializing Firebase Admin from', keyPath, err.message);
            }
        }
    }
    return null;
}

async function sendFirebaseNotification({
    title,
    body,
    image,
    imageUrl,
    big_picture,
    large_icon,
    userId,
    data,
}) {
    try {
        const fbApp = getFirebaseAdmin();
        if (!fbApp) {
            console.warn('⚠️ Firebase Admin app could not be initialized (serviceAccountKey.json missing)');
            return { success: false, error: 'Firebase Admin not initialized' };
        }

        const safeTopic = userId 
            ? `user_${String(userId).trim().replace(/[^a-zA-Z0-9-_.~%]/g, '_')}`
            : 'all';

        const notifImage = safeTrim(image || imageUrl || big_picture || large_icon);

        const payloadData = {
            title: String(title || ''),
            body: String(body || ''),
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
        };

        if (notifImage) {
            payloadData.image = notifImage;
            payloadData.imageUrl = notifImage;
            payloadData.big_picture = notifImage;
            payloadData.large_icon = notifImage;
        }

        if (data && typeof data === 'object') {
            for (const [k, v] of Object.entries(data)) {
                if (v !== undefined && v !== null) {
                    payloadData[String(k)] = typeof v === 'object' ? JSON.stringify(v) : String(v);
                }
            }
        }

        const fcmMessage = {
            topic: safeTopic,
            notification: {
                title: String(title || ''),
                body: String(body || ''),
                ...(notifImage ? { imageUrl: notifImage } : {}),
            },
            data: payloadData,
            android: {
                priority: 'high',
                notification: {
                    title: String(title || ''),
                    body: String(body || ''),
                    channelId: 'crazyreward',
                    sound: 'default',
                    icon: 'logo',
                    color: '#6C5CE7',
                    ...(notifImage ? { imageUrl: notifImage } : {}),
                },
            },
        };

        const response = await admin.messaging().send(fcmMessage);
        return {
            success: true,
            target: safeTopic,
            messageId: response,
        };
    } catch (err) {
        console.warn('⚠️ Firebase FCM error:', err?.message || err);
        return {
            success: false,
            error: err?.message || 'FCM send failed',
        };
    }
}

async function sendOneSignalNotification({
    title,
    body,
    image,
    imageUrl,
    big_picture,
    large_icon,
    playerId,
    userId,
    data,
}) {
    let oneSignalAppId = safeTrim(process.env.ONESIGNAL_APP_ID);
    let oneSignalApiKey = safeTrim(process.env.ONESIGNAL_API_KEY);

    try {
        const AppData = require('../models/appData');
        const appDoc = await AppData.findOne({ key: 'appData' }).lean();
        if (appDoc?.oneSignalAppId || appDoc?.config?.oneSignalAppId) {
            oneSignalAppId = safeTrim(appDoc.oneSignalAppId || appDoc.config.oneSignalAppId);
        }
        if (appDoc?.oneSignalApiKey || appDoc?.config?.oneSignalApiKey) {
            oneSignalApiKey = safeTrim(appDoc.oneSignalApiKey || appDoc.config.oneSignalApiKey);
        }
    } catch (_) {}

    if (!oneSignalAppId || !oneSignalApiKey) {
        throw new Error('OneSignal env/appData keys missing');
    }

    const notifImage = safeTrim(image || imageUrl || big_picture || large_icon);

    const basePayload = {
        app_id: oneSignalAppId,
        headings: { en: title, hi: title },
        contents: { en: body, hi: body },
        existing_android_channel_id: 'crazyreward',
        small_icon: 'logo',
        priority: 10,
        data: {
            title: title,
            body: body,
            message: body,
            ...(data && typeof data === 'object' ? data : {}),
        },
    };

    if (notifImage) {
        basePayload.global_image = notifImage;
        basePayload.big_picture = notifImage;
        basePayload.chrome_web_image = notifImage;
        basePayload.ios_attachments = { id1: notifImage };
        basePayload.data.image = notifImage;
        basePayload.data.imageUrl = notifImage;
        basePayload.data.big_picture = notifImage;
    }

    const headers = {
        'Content-Type': 'application/json',
        'Authorization': `Key ${oneSignalApiKey}`,
    };

    // 1. Target by userId
    if (userId) {
        try {
            const aliasPayload = {
                ...basePayload,
                target_channel: 'push',
                include_aliases: {
                    external_id: [userId]
                }
            };
            const response = await axios.post(
                'https://api.onesignal.com/notifications',
                aliasPayload,
                { headers, timeout: 15_000 }
            );

            return {
                target: 'external_id',
                data: response?.data || null,
            };
        } catch (aliasErr) {
            const filterPayload = {
                ...basePayload,
                filters: [
                    { field: 'tag', key: 'userId', relation: '=', value: userId },
                ]
            };
            const fallbackRes = await axios.post(
                'https://api.onesignal.com/notifications',
                filterPayload,
                { headers, timeout: 15_000 }
            );
            return {
                target: 'tag',
                data: fallbackRes?.data || null,
            };
        }
    }

    // 2. Target by specific subscription/player ID
    if (playerId) {
        const playerPayload = {
            ...basePayload,
            include_subscription_ids: [playerId],
        };
        const response = await axios.post(
            'https://api.onesignal.com/notifications',
            playerPayload,
            { headers, timeout: 15_000 }
        );
        return {
            target: 'player_id',
            data: response?.data || null,
        };
    }

    // 3. Broadcast to all users
    const broadcastPayload = {
        ...basePayload,
        included_segments: ['Total Subscriptions', 'All'],
    };
    const response = await axios.post(
        'https://api.onesignal.com/notifications',
        broadcastPayload,
        { headers, timeout: 20_000 }
    );
    return {
        target: 'segment_all',
        data: response?.data || null,
    };
}

async function sendNotificationViaApi({
    title,
    heading,
    body,
    message,
    msg,
    image = '',
    imageUrl = '',
    big_picture = '',
    large_icon = '',
    token = '',
    playerId = '',
    userId = '',
    data = null,
    provider = '',
    type = '',
}) {
    const normalizedTitle = safeTrim(title || heading);
    const normalizedBody = safeTrim(body || message || msg);
    const normalizedUserId = safeTrim(userId);
    const normalizedPlayerId = safeTrim(playerId) || safeTrim(token);
    const normalizedImage = safeTrim(image || imageUrl || big_picture || large_icon);
    const selectedProvider = safeTrim(provider).toLowerCase() || 'onesignal';

    if (!normalizedTitle || !normalizedBody) {
        throw new Error('Notification title/body required');
    }

    // Determine notification category type for in-app targeted notification screen
    // STRICT RULE: Only assign category type if normalizedUserId is explicitly provided!
    // Broadcast notifications sent to all users must NEVER have an in-app category type.
    let notifType = '';
    if (normalizedUserId) {
        notifType = safeTrim(type || data?.type || '').toLowerCase();
        if (!notifType || notifType === 'broadcast') {
            const lowerTitle = normalizedTitle.toLowerCase();
            if (lowerTitle.includes('payment') || lowerTitle.includes('payout') || lowerTitle.includes('refund')) {
                notifType = 'payment';
            } else if (lowerTitle.includes('support') || lowerTitle.includes('ticket')) {
                notifType = 'support';
            } else if (lowerTitle.includes('promotion') || lowerTitle.includes('service')) {
                notifType = 'service';
            } else {
                notifType = 'personal';
            }
        }
    } else {
        notifType = 'broadcast';
    }

    const payloadData = {
        ...(data && typeof data === 'object' ? data : {}),
        type: notifType,
    };


    const results = {};

    // 1. Send via Firebase FCM
    if (selectedProvider === 'both' || selectedProvider === 'firebase') {
        const fbResult = await sendFirebaseNotification({
            title: normalizedTitle,
            body: normalizedBody,
            image: normalizedImage,
            userId: normalizedUserId,
            data: payloadData,
        });
        results.firebase = fbResult;
    }

    // 2. Send via OneSignal
    if (selectedProvider === 'both' || selectedProvider === 'onesignal') {
        try {
            const osResult = await sendOneSignalNotification({
                title: normalizedTitle,
                body: normalizedBody,
                image: normalizedImage,
                playerId: normalizedPlayerId,
                userId: normalizedUserId,
                data: payloadData,
            });
            results.onesignal = osResult;
        } catch (osErr) {
            console.warn('⚠️ OneSignal send error:', osErr?.response?.data || osErr?.message);
            results.onesignal = { success: false, error: osErr.message };
            if (selectedProvider === 'onesignal') {
                throw osErr;
            }
        }
    }

    const isSuccess = Boolean(
        results.firebase?.success || 
        results.onesignal?.data?.id || 
        results.onesignal?.data || 
        results.onesignal?.target
    );

    if (!isSuccess && (results.onesignal?.error || results.firebase?.error)) {
        throw new Error(results.onesignal?.error || results.firebase?.error || 'Failed to send notification');
    }

    return {
        success: isSuccess,
        provider: selectedProvider,
        ...results,
        data: results.onesignal?.data || results.firebase || null,
    };
}

// Support both: const sendNotificationViaApi = require(...) AND const { sendNotificationViaApi } = require(...)
sendNotificationViaApi.sendNotificationViaApi = sendNotificationViaApi;
sendNotificationViaApi.sendFirebaseNotification = sendFirebaseNotification;
sendNotificationViaApi.sendOneSignalNotification = sendOneSignalNotification;
module.exports = sendNotificationViaApi;