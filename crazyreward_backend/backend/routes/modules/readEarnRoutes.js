const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const connectMongo = require('../../admin/middlewares/connectMongo');
const ReadEarn = require('../../admin/models/readEarn');
const ReadEarnLogs = require('../../admin/models/readEarnLogs');
const PendingReadEarnToken = require('../../admin/models/pendingReadEarnToken');
const { handleReadEarnPostback } = require('../../admin/middlewares/read-earn-postback');
const cryptoMiddleware = require('../../admin/middlewares/cryptoMiddleware');
const antiReplayMiddleware = require('../../admin/middlewares/antiReplayMiddleware');
const cacheService = require('../../services/cacheService');

// 1. Fetch Read & Earn Task URL
router.post(['/get-read-earn-url', '/url', '/fetch'], cryptoMiddleware, async (req, res) => {
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
        }).catch(() => {});

        let redirectionUrl = selectedUrl.url;
        if (redirectionUrl.includes('?')) {
            redirectionUrl += `&token=${token}`;
        } else {
            redirectionUrl += `?token=${token}`;
        }

        const coinsAmount = Number(selectedUrl.payout || selectedUrl.coins || 0);

        return res.status(200).json({
            success: true,
            redirectionUrl,
            coins: coinsAmount,
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

// 2. Read & Earn Task Postback
router.all(['/read-earn-postback', '/postback', '/verify'], cryptoMiddleware, antiReplayMiddleware, async (req, res) => {
    try {
        const query = { ...req.query, ...req.body };
        const userId = String(query.userId || query.user_id || req.headers['user-id'] || req.headers['x-user-id'] || '').trim();
        const appName = String(query.appName || query.app_name || '').trim();
        const offerId = String(query.offerId || query.offer_id || '').trim();

        if (!userId || !offerId) {
            return res.status(400).json({
                success: false,
                message: 'Missing required parameters (userId, offerId)'
            });
        }

        return handleReadEarnPostback({
            appName: appName.toLowerCase(),
            userId: userId,
            offerId: offerId,
            query: query,
            res: res,
        });
    } catch (err) {
        console.error('🔥 Error processing Read Earn postback:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error'
        });
    }
});

module.exports = router;
