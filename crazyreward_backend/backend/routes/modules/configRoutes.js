const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const AppData = require('../../admin/models/appData');
const OffersSettings = require('../../admin/models/offersSettings');
const ReferralSettings = require('../../admin/models/referralSettings');
const cryptoMiddleware = require('../../admin/middlewares/cryptoMiddleware');
const cacheService = require('../../services/cacheService');
const { resolveOfferwallEnvFallbacks } = require('../../services/offerwallEnvService');
const BannerClickLogs = require('../../admin/models/bannerClickLogs');

function getClientIp(req) {
    const cfIp = req.headers['cf-connecting-ip'];
    if (cfIp) return cfIp.trim();
    const forwarded = req.headers['x-forwarded-for'];
    if (forwarded) return forwarded.split(',')[0].trim();
    const realIp = req.headers['x-real-ip'];
    if (realIp) return realIp.trim();
    return req.ip || req.socket?.remoteAddress || '';
}

// Get App Configurations API
router.post(['/app-data', '/get-app-data'], cryptoMiddleware, async (req, res) => {
    try {
        if (!req.rawPayload) {
            return res.status(400).json({ success: false, message: 'Encryption required' });
        }

        const cacheKey = 'global:appData';
        const cachedData = await cacheService.get(cacheKey);
        if (cachedData) {
            return res.json({
                success: true,
                ...cachedData
            });
        }

        await connectMongo();
        const [appDataDoc, offersDoc, referralDoc] = await Promise.all([
            AppData.findOne({ key: 'appData' }).lean(),
            OffersSettings.findOne({ key: 'offersSettings' }).lean(),
            ReferralSettings.findOne({ key: 'referralSettings' }).lean(),
        ]);

        const rawOffersSettings = offersDoc?.config || {};
        const resolvedOffersSettings = resolveOfferwallEnvFallbacks(rawOffersSettings);

        const resolvedOneSignalAppId = String(
            appDataDoc?.config?.oneSignalAppId ||
            appDataDoc?.oneSignalAppId ||
            process.env.ONESIGNAL_APP_ID ||
            ''
        ).trim();

        const appDataConfig = {
            ...(appDataDoc?.config || {}),
            conversionRate: Number(appDataDoc?.config?.conversionRate || appDataDoc?.conversionRate || 150),
            showCoinConversionRate: Boolean(appDataDoc?.config?.showCoinConversionRate ?? appDataDoc?.showCoinConversionRate ?? false),
            screenBanners: appDataDoc?.config?.screenBanners || {},
            oneSignalAppId: resolvedOneSignalAppId,
            apiKey: process.env.API_KEY || ''
        };

        const responsePayload = {
            appData: appDataConfig,
            offersSettings: resolvedOffersSettings,
            referralSettings: referralDoc?.config || {},
        };

        // Cache using dynamic admin global TTL setting (default: 300s)
        await cacheService.set(cacheKey, responsePayload, cacheService.getTtl('global'));

        return res.json({
            success: true,
            ...responsePayload
        });
    } catch (err) {
        console.error('❌ Error fetching app data:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch app data' });
    }
});

// Track Screen Banner Click
router.post(['/banner/click', '/api/banner/click'], async (req, res) => {
    try {
        await connectMongo();
        const { screenKey, clickUrl, userId } = req.body || {};
        if (!screenKey) {
            return res.status(400).json({ success: false, message: 'screenKey is required' });
        }

        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const istTime = new Date(now.getTime() + istOffset);
        const dateStr = istTime.toISOString().slice(0, 10); // 'YYYY-MM-DD'
        const clientIp = getClientIp(req);

        await BannerClickLogs.create({
            screenKey: String(screenKey).trim(),
            userId: String(userId || '').trim(),
            clickUrl: String(clickUrl || '').trim(),
            date: dateStr,
            ipAddress: clientIp,
        });

        return res.json({ success: true });
    } catch (err) {
        console.error('❌ Error recording banner click:', err);
        return res.status(500).json({ success: false, message: 'Failed to record click' });
    }
});

module.exports = router;
