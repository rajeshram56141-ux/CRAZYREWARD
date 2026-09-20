const express = require('express');
const router = express.Router();
const multer = require('multer');
const Tesseract = require('tesseract.js');
const connectMongo = require('../../admin/middlewares/connectMongo');
const DailyTask = require('../../admin/models/dailyTask');
const PostbackLogs = require('../../admin/models/postbackLogs');
const User = require('../../admin/models/user');
const RewardHistory = require('../../admin/models/rewardHistory');
const cryptoMiddleware = require('../../admin/middlewares/cryptoMiddleware');
const antiReplayMiddleware = require('../../admin/middlewares/antiReplayMiddleware');
const cacheService = require('../../services/cacheService');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// Helper to get start of today in IST (Timezone-safe for UTC servers)
function getTodayStartIST() {
    const now = new Date();
    const istDateStr = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
    return new Date(`${istDateStr}T00:00:00+05:30`);
}

const { handleWatchEarnPostback } = require('../../admin/middlewares/watch-earn-postback');

// Route 1: Get Watch and Earn Tasks (decrypted & encrypted payload wrapper)
router.post('/get-watch-earn-tasks', cryptoMiddleware, async (req, res) => {
    try {
        console.log('🔒 [WatchEarn Request] Raw Encrypted Payload: ', req.rawPayload);
        console.log('🔓 [WatchEarn Request] Decrypted Body: ', req.body);
        
        await connectMongo();

        const { appName, userId, countryCode } = req.body;

        if (!appName || !userId || !countryCode) {
            return res.status(400).json({
                success: false,
                message: 'Missing params'
            });
        }

        const formattedAppName = appName.toLowerCase().replace(/\s/g, '');
        const isForceRefresh = Boolean(req.body?.refresh === true || req.body?.forceRefresh === true);

        // Fetch WatchEarn tasks (Redis Cached for high performance)
        const cacheKey = `tasks:watchearn:${formattedAppName || 'all'}`;
        let dbOffers = isForceRefresh ? null : await cacheService.get(cacheKey);

        if (!dbOffers || !Array.isArray(dbOffers) || dbOffers.length === 0) {
            dbOffers = await DailyTask.find({ enabled: true, offerType: 'WatchEarn' })
                .sort({ order: 1, updatedAt: -1, createdAt: -1 })
                .lean();
            if (dbOffers && dbOffers.length > 0) {
                await cacheService.set(cacheKey, dbOffers, cacheService.getTtl('global'));
            }
        }

        if (!dbOffers.length) {
            return res.status(200).json({
                success: true,
                offers: []
            });
        }

        const todayStart = getTodayStartIST();

        const allOfferIds = dbOffers.map(o => o.offerId);

        const postbackLogs = await PostbackLogs.find({
            userId,
            offerId: { $in: allOfferIds }
        }).lean();

        const completionMap = {};
        for (const log of postbackLogs) {
            if (!completionMap[log.offerId]) {
                completionMap[log.offerId] = {};
            }
            if (!log.eventId || log.eventId === '') {
                completionMap[log.offerId]['__single__'] = {
                    completedAt: log.completedAt,
                    coins: Number(log.coins || log.payout || 0)
                };
            } else {
                completionMap[log.offerId][log.eventId] = {
                    completedAt: log.completedAt,
                    coins: Number(log.coins || log.payout || 0)
                };
            }
        }

        const responseList = [];

        for (const offer of dbOffers) {
            // Country check
            if (!(Array.isArray(offer.countries) &&
                (offer.countries.includes(countryCode) || offer.countries.includes('GLOBAL'))
            )) continue;

            // Daily Cap Check
            if (offer.dailyCapLimit !== null && offer.dailyCapCount >= offer.dailyCapLimit) {
                continue;
            }

            // Lifetime Cap Check
            if (offer.lifetimeCapLimit !== null && offer.postbackCount >= offer.lifetimeCapLimit) {
                continue;
            }

            // Per User Daily Cap Check (Strict Filtering)
            if (offer.perUserDailyCap !== null && offer.perUserDailyCap !== undefined && offer.perUserDailyCap > 0) {
                const completionsToday = postbackLogs.filter(log => {
                    if (log.offerId !== offer.offerId) return false;
                    const completedAt = new Date(log.completedAt);
                    return completedAt >= todayStart;
                }).length;

                if (completionsToday >= offer.perUserDailyCap) {
                    continue; // Reached cap (e.g. 2/2) -> HIDE FROM LIST!
                }
            } else {
                // If no perUserDailyCap set (default: 1 completion allowed)
                const completionsToday = postbackLogs.filter(log => {
                    if (log.offerId !== offer.offerId) return false;
                    const completedAt = new Date(log.completedAt);
                    return completedAt >= todayStart;
                }).length;

                if (offer.dailyReset) {
                    if (completionsToday >= 1) {
                        continue; // Already completed today -> HIDE FROM LIST!
                    }
                } else {
                    const lifetimeCompletions = postbackLogs.filter(log => log.offerId === offer.offerId).length;
                    if (lifetimeCompletions >= 1) {
                        continue; // Lifetime offer completed -> HIDE FROM LIST!
                    }
                }
            }

            responseList.push({
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
                coins: Number(offer.coins || offer.payout || 0),
                redirectionUrl: offer.redirectionUrl || '',
                reelFormat: (offer.offerCategory.toLowerCase().includes('reel') || offer.offerCategory.toLowerCase().includes('short')) ?? false,
                color: offer.color || '#3F97FF',
                timestamp: offer.createdAt,
                videoVerificationEnabled: offer.videoVerificationEnabled || false,
                videoVerificationId: offer.videoVerificationId || '',
                perUserDailyCap: offer.perUserDailyCap,
                rating: offer.rating || '',
                downloads: offer.downloads || '',
                screenshotVerificationEnabled: offer.screenshotVerificationEnabled || false
            });
        }

        return res.json({
            success: true,
            offers: responseList
        });
    } catch (err) {
        console.error('🔥 Error in /get-watch-earn-tasks:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// Route 2: Individual Dedicated Watch & Earn Postback (POST, encrypted wrapper)
router.post('/watch-earn-postback', cryptoMiddleware, antiReplayMiddleware, async (req, res) => {
    try {
        console.log('🔒 [WatchEarn Postback] Raw Encrypted Payload: ', req.rawPayload);
        console.log('🔓 [WatchEarn Postback] Decrypted Body: ', req.body);

        const userId = String(req.body?.userId || '').trim();
        const email = String(req.body?.email || '').trim();
        const gaid = String(req.body?.gaid || '').trim();
        const appName = String(req.body?.appName || '').trim();
        const offerId = String(req.body?.offerId || '').trim();

        if (!userId || !appName || !offerId) {
            console.warn(`❌ Missing parameters in watch-earn postback`);
            return res.status(400).json({
                success: false,
                message: 'Missing parameters'
            });
        }

        return handleWatchEarnPostback({
            appName: appName.toLowerCase().replace(/\s/g, '').trim(),
            userId: userId.trim(),
            offerId: offerId.trim(),
            userEmail: email ? email.trim() : '',
            userGaid: gaid ? gaid.trim() : '',
            query: { ...req.body },
            res: res,
        });
    } catch (err) {
        console.error('🔥 Error in /watch-earn-postback:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// Route 3: Individual Dedicated Watch & Earn OCR Verification
router.post('/watch-video-verify-ocr', upload.single('screenshot'), async (req, res) => {
    try {
        const { userId, email, gaid, appName, offerId, videoUrl } = req.body;

        if (!userId || !appName || !offerId || !videoUrl) {
            return res.status(400).json({
                success: false,
                message: 'Missing parameters (userId, appName, offerId, and videoUrl are required).'
            });
        }

        if (!req.file) {
            return res.status(400).json({
                success: false,
                message: 'Screenshot file is required.'
            });
        }

        await connectMongo();

        const offerDoc = await DailyTask.findOne({ offerId: offerId.trim() });
        if (!offerDoc) {
            return res.status(404).json({ success: false, message: 'Video task not found.' });
        }

        if (!offerDoc.enabled) {
            return res.status(400).json({ success: false, message: 'This video task is currently inactive.' });
        }

        // Verify Video URL
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
                return res.status(200).json({
                    success: false,
                    message: 'Wrong video URL. Please paste the correct video link.'
                });
            }
        }

        // OCR Recognition
        console.log(`[WatchEarn OCR] Running check for offer "${offerDoc.offerName}"...`);
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

        // Tier 1: Direct full title match
        if (normalizedOfferName.length > 0 && normalizedOcr.includes(normalizedOfferName)) {
            isMatch = true;
            console.log(`[WatchEarn OCR] Exact full title matched!`);
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
                    console.log(`[WatchEarn OCR] Matched 2-word title phrase: "${phrase2}"`);
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
                console.log(`[WatchEarn OCR] Matched title words (${matchedWords.length}/${requiredMatches}): ${matchedWords.join(', ')}`);
            }
        }

        if (!isMatch) {
            console.warn(`[WatchEarn OCR] Matching failed. Extracted text: "${ocrText.substring(0, 250).replace(/\n/g, ' ')}..."`);
            return res.status(200).json({
                success: false,
                message: 'Wrong screenshot. Screenshot must show the correct video title.'
            });
        }

        // Trigger Dedicated Watch & Earn Postback
        return handleWatchEarnPostback({
            appName: appName.toLowerCase().replace(/\s/g, '').trim(),
            userId: userId.trim(),
            offerId: offerId.trim(),
            userEmail: email ? email.trim() : '',
            userGaid: gaid ? gaid.trim() : '',
            query: { ...req.body },
            res: res
        });

    } catch (err) {
        console.error("WatchEarn OCR route error:", err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error during Watch & Earn verification.'
        });
    }
});

// Attach helper for external consumers
router.handleWatchEarnPostback = handleWatchEarnPostback;

module.exports = router;

