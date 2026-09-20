const fs = require('fs');
const path = require('path');
const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const User = require('../../admin/models/user');
const AppData = require('../../admin/models/appData');
const RewardHistory = require('../../admin/models/rewardHistory');
const ScreenshotProof = require('../../admin/models/screenshotProof');
const SuperOfferHistory = require('../../admin/models/superOfferHistory');
const { cryptoMiddleware } = require('../../admin/middlewares/cryptoMiddleware');

function isPlainObject(value) {
    return !!value && typeof value === 'object' && !Array.isArray(value);
}

function parseNumberOrRange(input, defaultVal = 8) {
    if (typeof input === 'number' && !isNaN(input)) return input;
    const str = String(input || '').trim();
    if (!str) return defaultVal;

    const match = str.match(/^(\d+)\s*-\s*(\d+)$/);
    if (match) {
        const min = parseInt(match[1], 10);
        const max = parseInt(match[2], 10);
        if (min <= max) {
            return Math.floor(Math.random() * (max - min + 1)) + min;
        }
    }

    const num = parseInt(str, 10);
    return !isNaN(num) && num >= 0 ? num : defaultVal;
}

// 1. SUPER OFFER VERIFICATION
router.post(['/super-offer-verify', '/verify'], cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        let appName = req.body?.appName;

        if (!userId) {
            return res.status(400).json({
                success: false,
                message: 'Missing userId'
            });
        }

        await connectMongo();

        let userDoc = await User.findOne({
            $or: [
                { userId: String(userId).trim() },
                { email: String(userId).trim() },
                { gmail: String(userId).trim() },
                { firebaseUid: String(userId).trim() }
            ]
        }).lean();
        if (!userDoc) {
            userDoc = { userId };
        }

        appName = String(appName || userDoc.appName || '').trim();
        let appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        if (!appDataDoc && appName) {
            appDataDoc = await AppData.findOne({ appName }).lean();
        }
        if (!appDataDoc) {
            appDataDoc = await AppData.findOne({}).lean();
        }

        const rawConfig = appDataDoc?.config || appDataDoc || {};
        const superOfferConfig = isPlainObject(rawConfig.superOfferConfig)
            ? rawConfig.superOfferConfig
            : (isPlainObject(appDataDoc?.superOfferConfig) ? appDataDoc.superOfferConfig : {});

        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const istNow = new Date(now.getTime() + istOffset);
        const startOfIstDay = new Date(Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate(), 0, 0, 0) - istOffset);
        const todayIstDateStr = istNow.toISOString().split('T')[0];

        let limitType = userDoc.superOfferAssignType;
        let userSuperOfferLimit = userDoc.superOfferLimit;
        // Check if user is ALREADY assigned for TODAY (todayIstDateStr)
        const isSuperOfferAssignedToday = userDoc.superOfferAssignedDateStr === todayIstDateStr;
        let updateFields = {};

        if (!isSuperOfferAssignedToday) {
            // New Day! Assign fresh Super Offer values from Global superOfferConfig
            limitType = superOfferConfig.limitType || 'hours';
            userSuperOfferLimit = limitType === 'daily'
                ? (parseNumberOrRange(superOfferConfig.superOfferDailyLimit || superOfferConfig.dailyLimit) || 1)
                : null;
            const assignedGapMinutes = limitType === 'hours'
                ? (parseNumberOrRange(superOfferConfig.gapMinutes || superOfferConfig.hoursGap) || 60)
                : null;

            updateFields.superOfferAssignType = limitType;
            updateFields.superOfferLimit = userSuperOfferLimit;
            updateFields.superOfferGapMinutes = assignedGapMinutes;
            updateFields.superOfferClaimsToday = 0;
            updateFields.superOfferClaimsDateStr = todayIstDateStr;
            updateFields.superOfferAssignedAt = new Date();
            updateFields.superOfferAssignedDateStr = todayIstDateStr;
            updateFields.isSuperOfferUnlocked = false;
            updateFields.superOfferUnlockedAt = null;

            // Update in-memory userDoc so this request immediately sees fresh values for today
            userDoc.superOfferClaimsToday = 0;
            userDoc.superOfferClaimsDateStr = todayIstDateStr;
            userDoc.superOfferAssignType = limitType;
            userDoc.superOfferLimit = userSuperOfferLimit;
            userDoc.superOfferGapMinutes = assignedGapMinutes;
            userDoc.isSuperOfferUnlocked = false;
            userDoc.superOfferUnlockedAt = null;
        } else {
            if (!limitType) {
                limitType = superOfferConfig.limitType || 'hours';
            }
            if (limitType === 'daily') {
                if (!userSuperOfferLimit) {
                    userSuperOfferLimit = parseNumberOrRange(superOfferConfig.superOfferDailyLimit || superOfferConfig.dailyLimit) || 1;
                }
            } else {
                userSuperOfferLimit = null;
                if (!userDoc.superOfferGapMinutes) {
                    userDoc.superOfferGapMinutes = parseNumberOrRange(superOfferConfig.gapMinutes || superOfferConfig.hoursGap) || 60;
                    updateFields.superOfferGapMinutes = userDoc.superOfferGapMinutes;
                }
            }
        }

        // If user unlocked on a previous date, reset to locked for the new day
        if (userDoc?.isSuperOfferUnlocked && userDoc?.superOfferUnlockedAt) {
            const unlockedDateStr = new Date(new Date(userDoc.superOfferUnlockedAt).getTime() + istOffset).toISOString().split('T')[0];
            if (unlockedDateStr !== todayIstDateStr) {
                userDoc.isSuperOfferUnlocked = false;
                userDoc.superOfferUnlockedAt = null;
                updateFields.isSuperOfferUnlocked = false;
                updateFields.superOfferUnlockedAt = null;
            }
        }

        if (Object.keys(updateFields).length > 0) {
            await User.updateOne({ _id: userDoc._id || undefined, userId: userDoc.userId || userId }, { $set: updateFields }).catch(() => { });
        }

        const gapMinutes = Number(userDoc.superOfferGapMinutes || superOfferConfig.gapMinutes || superOfferConfig.hoursGap || 60);
        const hoursGap = gapMinutes;
        const dailyLimit = userSuperOfferLimit || 10;

        let superOfferClaimsToday = 0;
        if (userDoc.superOfferClaimsDateStr === todayIstDateStr) {
            superOfferClaimsToday = Number(userDoc.superOfferClaimsToday) || 0;
        } else if (userDoc.superOfferClaimsToday !== undefined && userDoc.superOfferClaimsToday !== null && !userDoc.superOfferClaimsDateStr) {
            superOfferClaimsToday = Number(userDoc.superOfferClaimsToday) || 0;
        }

        let eligible = true;
        let lastClaimedAt = null;
        let isCurrentlyUnlocked = Boolean(userDoc?.isSuperOfferUnlocked);

        const isDailyLimitReached = dailyLimit > 0 && superOfferClaimsToday >= dailyLimit;

        if (limitType === 'daily') {
            if (isDailyLimitReached) {
                eligible = false;
                isCurrentlyUnlocked = false;
            }
        } else {
            // In Hours/Cooldown mode:
            // 1. If daily limit is reached for today, lock offer
            if (isDailyLimitReached) {
                eligible = false;
                isCurrentlyUnlocked = false;
            } else if (superOfferClaimsToday > 0) {
                // 2. Cooldown timer applies between claims today! (First claim of the day has no cooldown)
                // Subtract 5 seconds grace period to handle client-server clock drift
                const timeframe = new Date(Date.now() - gapMinutes * 60 * 1000 + 5000);
                const uidList = [String(userId).trim()];
                if (userDoc?.userId) uidList.push(String(userDoc.userId).trim());
                if (userDoc?.email) uidList.push(String(userDoc.email).trim());
                if (userDoc?.gmail) uidList.push(String(userDoc.gmail).trim());
                if (userDoc?.firebaseUid) uidList.push(String(userDoc.firebaseUid).trim());

                const recentClaimMongo = await RewardHistory.findOne({
                    userId: { $in: Array.from(new Set(uidList)) },
                    provider: { $in: ['Super Offer Task', 'Super Offer'] },
                    createdAt: { $gte: timeframe }
                }).lean();

                const userData = userDoc || {};
                const lastClaimTs = userData.lastSuperOfferClaim ? new Date(userData.lastSuperOfferClaim).getTime() : 0;
                const isRecentUserDoc = (Date.now() - lastClaimTs) < (gapMinutes * 60 * 1000 - 5000);

                if (recentClaimMongo || isRecentUserDoc) {
                    eligible = false;
                    isCurrentlyUnlocked = false;
                    lastClaimedAt = recentClaimMongo ? new Date(recentClaimMongo.createdAt).getTime() : lastClaimTs;
                }
            }
        }

        // If daily limit reached, user cannot be unlocked
        if (isDailyLimitReached) {
            isCurrentlyUnlocked = false;
        }

        // If user has an active unlocked offer in-progress and is not locked, keep them eligible and unlocked!
        if (isCurrentlyUnlocked) {
            eligible = true;
        }

        // Global values read live from superOfferConfig (no hardcoded 100/10 fallbacks)
        const reward = superOfferConfig.reward !== undefined && superOfferConfig.reward !== null ? Number(superOfferConfig.reward) : 0;
        const gemsRequired = superOfferConfig.gemsRequired !== undefined && superOfferConfig.gemsRequired !== null ? Number(superOfferConfig.gemsRequired) : 0;
        const adsRequired = typeof superOfferConfig.adsRequired === 'boolean' ? superOfferConfig.adsRequired : true;
        let installTask = typeof superOfferConfig.installTask === 'boolean' ? superOfferConfig.installTask : true;
        if (superOfferConfig.activeMethod === 1) {
            installTask = false;
        } else if (superOfferConfig.activeMethod && [2, 3, 4].includes(superOfferConfig.activeMethod)) {
            installTask = true;
        }

        const uidList = [String(userId).trim()];
        if (userDoc?.userId) uidList.push(String(userDoc.userId).trim());
        if (userDoc?.email) uidList.push(String(userDoc.email).trim());
        if (userDoc?.gmail) uidList.push(String(userDoc.gmail).trim());
        if (userDoc?.firebaseUid) uidList.push(String(userDoc.firebaseUid).trim());

        const completedSuperOffersCount = await RewardHistory.countDocuments({
            userId: { $in: Array.from(new Set(uidList)) },
            provider: { $in: ['Super Offer Task', 'Super Offer'] }
        });

        const activeMethod = superOfferConfig.activeMethod || (
            (!superOfferConfig.superOfferVerificationEnabled && !installTask) ? 1 :
            (!superOfferConfig.superOfferVerificationEnabled && installTask) ? 2 :
            (superOfferConfig.superOfferVerificationEnabled && !superOfferConfig.screenshotVerificationEnabled) ? 3 : 4
        );

        return res.status(200).json({
            success: true,
            eligible: eligible,
            isUnlocked: isCurrentlyUnlocked,
            dailyLimitReached: isDailyLimitReached,
            activeMethod: activeMethod,
            reward: reward,
            gemsRequired: gemsRequired,
            adsRequired: adsRequired,
            installTask: installTask,
            limitType: limitType,
            gapMinutes: gapMinutes,
            hoursGap: Math.floor(gapMinutes / 60),
            dailyLimit: dailyLimit,
            superOfferClaimsToday: superOfferClaimsToday,
            claimsToday: superOfferClaimsToday,
            claimsProgress: `${superOfferClaimsToday} / ${dailyLimit}`,
            lastClaimedAt: lastClaimedAt,
            completedSuperOffers: completedSuperOffersCount,
            superOfferConfig: {
                ...superOfferConfig,
                activeMethod: activeMethod
            },
            message: eligible ? 'User eligible for Super Offer' : 'Limit reached for Super Offer',
        });
    } catch (error) {
        console.error('🔥 Server Error in super-offer-verify:', error);
        return res.status(500).json({
            success: false,
            message: 'Internal server error',
            error: String(error?.stack || error?.message || error)
        });
    }
});



// 3. CLAIM SUPER OFFER (Coins Addition & Gems Deduction)
router.post(['/', '/reward/super-offer', '/claim-super-offer', '/claim', '/super-offer', '/reward'], cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        let coins = req.body?.coins;
        let gemsRequired = req.body?.gemsRequired;
        let appName = String(req.body?.appName || '').trim();
        let packageName = String(req.body?.packageName || '').trim();

        if (!userId) {
            return res.status(400).json({ success: false, message: 'Missing userId' });
        }

        await connectMongo();

        const user = await User.findOne({
            $or: [
                { userId: String(userId).trim() },
                { email: String(userId).trim() },
                { gmail: String(userId).trim() },
                { firebaseUid: String(userId).trim() }
            ]
        });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if (user.isGuest === true || user.isAnonymous === true) {
            return res.status(403).json({ success: false, message: 'Guest accounts cannot claim Super Offers. Please log in with Google to continue!' });
        }

        // Check Super Offer daily claims limit for user
        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const istNow = new Date(now.getTime() + istOffset);
        const todayIstDateStr = istNow.toISOString().split('T')[0];

        let superOfferClaimsToday = 0;
        if (user.superOfferClaimsDateStr === todayIstDateStr) {
            superOfferClaimsToday = Number(user.superOfferClaimsToday) || 0;
        } else if (user.superOfferClaimsToday !== undefined && user.superOfferClaimsToday !== null && !user.superOfferClaimsDateStr) {
            superOfferClaimsToday = Number(user.superOfferClaimsToday) || 0;
        }

        let appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        if (!appDataDoc) appDataDoc = await AppData.findOne({}).lean();
        const superOfferConfig = (appDataDoc && appDataDoc.config && appDataDoc.config.superOfferConfig)
            ? appDataDoc.config.superOfferConfig
            : (appDataDoc && appDataDoc.superOfferConfig ? appDataDoc.superOfferConfig : {});

        // 🛡️ Security Fix: Calculate Authoritative Server-Side Coins and Gems (Never trust client body)
        const configuredInstallCoins = Number(superOfferConfig.coins || superOfferConfig.installCoins || 0);
        const coinsToAdd = configuredInstallCoins > 0 ? configuredInstallCoins : (Number(coins) > 0 ? Math.min(Number(coins), 100) : 0);
        const configuredGemsRequired = Number(superOfferConfig.gemsRequired !== undefined ? superOfferConfig.gemsRequired : gemsRequired);
        const gemsToDeduct = Math.max(0, configuredGemsRequired);

        const limitType = user.superOfferAssignType || superOfferConfig.limitType || 'hours';
        const defaultDailyLimit = parseNumberOrRange(superOfferConfig.superOfferDailyLimit || superOfferConfig.dailyLimit) || 1;
        const superOfferLimit = Number(user.superOfferLimit) || defaultDailyLimit;

        if (limitType === 'daily' && superOfferClaimsToday >= superOfferLimit) {
            return res.status(400).json({
                success: false,
                limitReached: true,
                message: 'Today Super Offer claim limit reached! Come back tomorrow.'
            });
        }

        if (gemsToDeduct > 0) {
            if ((user.gems || 0) < gemsToDeduct) {
                return res.status(400).json({
                    success: false,
                    message: 'Insufficient gems balance',
                    gems: user.gems || 0,
                    gemsRequired: gemsToDeduct,
                });
            }
            user.gems = Math.max(0, (user.gems || 0) - gemsToDeduct);
        }

        const isVerificationEnabled = superOfferConfig.superOfferVerificationEnabled !== false;
        const activeMethod = Number(superOfferConfig.activeMethod || (superOfferConfig.screenshotVerificationEnabled === false ? 3 : 4));
        const isScreenshotEnabled = isVerificationEnabled && (activeMethod === 4) && (superOfferConfig.screenshotVerificationEnabled !== false);

        user.coins = (user.coins || 0) + coinsToAdd;
        user.totalCoins = (user.totalCoins || 0) + coinsToAdd;

        // In Method 4 (screenshot verification enabled), DO NOT trigger cooldown or daily limit on Step 1 Install!
        // Cooldown and daily limit must trigger only when screenshot proof is uploaded in /submit-screenshot.
        if (!isScreenshotEnabled) {
            user.superOfferClaimsToday = superOfferClaimsToday + 1;
            user.superOfferClaimsDateStr = todayIstDateStr;
            user.lastSuperOfferClaim = new Date();
        }

        const installTask = typeof superOfferConfig.installTask === 'boolean' ? superOfferConfig.installTask : true;
        const hasUsageSteps = Array.isArray(superOfferConfig.usageSteps) && superOfferConfig.usageSteps.length > 0;
        const hasNextSteps = installTask && isVerificationEnabled && (isScreenshotEnabled || hasUsageSteps);
        const isLimitReached = !isScreenshotEnabled && superOfferLimit > 0 && user.superOfferClaimsToday >= superOfferLimit;

        if (isLimitReached || !hasNextSteps) {
            user.isSuperOfferUnlocked = false;
            user.superOfferUnlockedAt = null;
        } else {
            user.isSuperOfferUnlocked = true;
        }
        user.lastActiveAt = new Date();
        await user.save();

        const superOfferOrderId = 'SO_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
        const normalizedUserId = String(user.userId || userId).trim();
        const offerAppName = String(appName || superOfferConfig.appName || packageName || 'Super Offer App').trim();

        const finalProvider = 'Super Offer Task';

        await RewardHistory.create({
            appName: offerAppName,
            userId: normalizedUserId,
            provider: finalProvider,
            coins: coinsToAdd,
            gems: gemsToDeduct > 0 ? -gemsToDeduct : 0,
            rewardType: 'coin',
            orderId: superOfferOrderId,
            timestamp: new Date(),
            createdAt: new Date(),
        });

        // Also ensure SuperOfferHistory document exists for User Activity tab with immutable configSnapshot
        try {
            const userEmail = user?.email || user?.gmail || '';
            const normalizedUid = String(user?.userId || userId).trim();

            const configSnapshot = {
                superOfferVerificationEnabled: isVerificationEnabled,
                verificationEnabled: isVerificationEnabled,
                screenshotVerificationEnabled: isScreenshotEnabled,
                reward: coinsToAdd,
                screenshotCoins: superOfferConfig.screenshotCoins || 576,
                initialUsageSeconds: superOfferConfig.initialUsageSeconds || 120,
                usageSteps: Array.isArray(superOfferConfig.usageSteps) ? superOfferConfig.usageSteps : [],
            };

            // Find existing in_progress history document created during unlock, or create new
            let historyDoc = await SuperOfferHistory.findOne({
                userId: normalizedUid,
                status: 'in_progress',
                stepNumber: 1
            }).sort({ createdAt: -1 });

            if (historyDoc) {
                historyDoc.packageName = packageName || superOfferConfig.packageName || 'Installed App';
                historyDoc.appName = offerAppName;
                historyDoc.status = 'completed';
                historyDoc.coins = coinsToAdd;
                historyDoc.usageMinutes = Number(req.body?.usageMinutes) || 2;
                historyDoc.installedAt = new Date();
                historyDoc.completedAt = new Date();
                historyDoc.isVerificationEnabled = isVerificationEnabled;
                if (!historyDoc.configSnapshot) {
                    historyDoc.configSnapshot = configSnapshot;
                }
                await historyDoc.save();
            } else {
                await SuperOfferHistory.create({
                    userId: normalizedUid,
                    userEmail,
                    packageName: packageName || superOfferConfig.packageName || 'Installed App',
                    appName: offerAppName,
                    stepNumber: 1,
                    stepName: 'Install App',
                    stepType: 'install',
                    status: 'completed',
                    isVerificationEnabled,
                    configSnapshot,
                    coins: coinsToAdd,
                    usageMinutes: Number(req.body?.usageMinutes) || 2,
                    installedAt: new Date(),
                    completedAt: new Date(),
                    createdAt: new Date(),
                });
            }

            // Invalidate Redis user super offer cache
            try {
                const cacheService = require('../../services/cacheService');
                if (cacheService && cacheService.del) {
                    await cacheService.del('so_user_' + normalizedUid);
                    await cacheService.del('user_data_' + normalizedUid);
                }
            } catch (_) {}
        } catch (soErr) {
            console.error('⚠️ Failed to auto-log SuperOfferHistory in claim:', soErr.message);
        }

        // Track Daily Challenge progress for Super Offer
        try {
            const { trackDailyChallengeProgress } = require('./dailyChallengeApiRoutes');
            trackDailyChallengeProgress(userId, 'super_offer', 1);
        } catch (_) {}

        // 🤝 Referral Commission & Joinee Bonus Trigger
        try {
            const { distributeTaskReferralCommission, checkAndUnlockTaskReferrerBonus } = require('../../services/referralCommissionService');
            checkAndUnlockTaskReferrerBonus(userId, 'super_offer').catch(e => console.error("⚠️ [SuperOffer] Ref bonus error:", e.message));
            distributeTaskReferralCommission(userId, coinsToAdd, 'Super Offer').catch(e => console.error("⚠️ [SuperOffer] Ref comm error:", e.message));
        } catch (refErr) {
            console.error("⚠️ [SuperOffer] Referral processing error:", refErr.message);
        }

        // 🌐 Outgoing Postback Trigger for Super Offer Claim (Case 2)
        if (user.publisherRef && user.publisherUid) {
            try {
                const triggerOutgoingPostback = require('../../services/publisherPostbackService');
                triggerOutgoingPostback({
                    user,
                    offerId: 'super_offer_claim',
                    coins: coinsToAdd,
                    eventId: ''
                }).catch(err => console.error("⚠️ S2S Outgoing Postback error:", err.message));
            } catch (loadErr) {
                console.error("⚠️ Failed to load publisherPostbackService:", loadErr.message);
            }
        }

        return res.status(200).json({
            success: true,
            response: 'success',
            message: 'Super Offer claimed successfully!',
            coins: user.coins,
            gems: user.gems,
        });
    } catch (error) {
        console.error('🔥 Error in claim-super-offer:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 4. LOG SUPER OFFER ACTIVITY (For A-Z History Tracking)
router.post('/log-activity', cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        const { packageName, appName, stepNumber, stepName, stepType, status, coins, usageMinutes, proofImageUrl, rejectionReason } = req.body || {};

        if (!userId || !packageName) {
            return res.status(400).json({ success: false, message: 'Missing userId or packageName' });
        }

        const user = await User.findOne({
            $or: [
                { userId: String(userId).trim() },
                { email: String(userId).trim() },
                { gmail: String(userId).trim() },
                { firebaseUid: String(userId).trim() }
            ]
        }).lean();
        const userEmail = user?.email || user?.gmail || '';

        const historyDoc = await SuperOfferHistory.create({
            userId: user?.userId || userId,
            userEmail,
            packageName,
            appName: appName || packageName,
            stepNumber: Number(stepNumber) || 1,
            stepName: stepName || 'Install App',
            stepType: stepType || 'install',
            status: status || 'completed',
            coins: Number(coins) || 0,
            usageMinutes: Number(usageMinutes) || 0,
            proofImageUrl: proofImageUrl || '',
            rejectionReason: rejectionReason || '',
            installedAt: stepType === 'install' ? new Date() : null,
            completedAt: status === 'completed' ? new Date() : null,
            removedAt: status === 'removed' ? new Date() : null,
            createdAt: new Date(),
        });

        if (status === 'uninstalled' || status === 'removed') {
            await User.updateOne(
                { $or: [
                    { userId: String(userId).trim() },
                    { email: String(userId).trim() },
                    { gmail: String(userId).trim() },
                    { firebaseUid: String(userId).trim() }
                ] },
                { $set: { isSuperOfferUnlocked: false, superOfferUnlockedAt: null } }
            );

            const trimmedUid = String(userId).trim();
            const uidList = [trimmedUid];
            if (user) {
                if (user.userId) uidList.push(String(user.userId).trim());
                if (user.email) uidList.push(user.email);
                if (user.gmail) uidList.push(user.gmail);
            }
            await ScreenshotProof.updateMany(
                {
                    userId: { $in: uidList },
                    $or: [
                        { offerId: 'super_offer_' + packageName },
                        { offerId: packageName }
                    ],
                    status: 'pending'
                },
                { $set: { status: status } }
            );
        }

        return res.status(200).json({ success: true, historyId: historyDoc._id });
    } catch (error) {
        console.error('🔥 Error in /super-offer/log-activity:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 5. SUBMIT SCREENSHOT PROOF FOR SUPER OFFER
router.post('/submit-screenshot', cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        const { packageName, appName, imageUrl, coins } = req.body || {};

        if (!userId || !imageUrl || !packageName) {
            return res.status(400).json({ success: false, message: 'Missing required fields' });
        }

        await connectMongo();

        const user = await User.findOne({ userId }).lean();
        const userEmail = user?.email || user?.gmail || '';

        let savedImageUrl = imageUrl;
        if (imageUrl && (imageUrl.startsWith('data:image/') || imageUrl.length > 500)) {
            try {
                const uploadDir = path.join(__dirname, '../../public/uploads/screenshots');
                if (!fs.existsSync(uploadDir)) {
                    fs.mkdirSync(uploadDir, { recursive: true });
                }
                const matches = imageUrl.match(/^data:image\/([a-zA-Z0-9]+);base64,(.+)$/);
                let ext = '.jpg';
                let buffer;
                if (matches) {
                    ext = '.' + matches[1];
                    buffer = Buffer.from(matches[2], 'base64');
                } else {
                    buffer = Buffer.from(imageUrl.replace(/^data:image\/[a-zA-Z0-9]+;base64,/, ''), 'base64');
                }
                const filename = `proof_so_${Date.now()}_${Math.random().toString(36).substring(2, 8)}${ext}`;
                const filePath = path.join(uploadDir, filename);
                fs.writeFileSync(filePath, buffer);
                savedImageUrl = `/uploads/screenshots/${filename}`;
            } catch (e) {
                console.error('⚠️ Error writing base64 image to disk:', e);
            }
        }

        // Save into ScreenshotProof model
        const proof = await ScreenshotProof.create({
            userId: String(userId).trim(),
            userEmail,
            appName: appName || packageName,
            offerId: 'super_offer_' + packageName,
            offerName: 'Super Offer: ' + (appName || packageName),
            eventName: 'Super Offer Screenshot',
            coins: Number(coins) || 0,
            imageUrl: savedImageUrl,
            status: 'pending',
            createdAt: new Date(),
        });

        const istOffset = 5.5 * 60 * 60 * 1000;
        const now = new Date();
        const istNow = new Date(now.getTime() + istOffset);
        const todayIstDateStr = istNow.toISOString().split('T')[0];

        const currentUser = await User.findOne({
            $or: [{ userId: String(userId).trim() }, { email: String(userId).trim() }]
        });
        let currentClaims = 0;
        if (currentUser) {
            if (currentUser.superOfferClaimsDateStr === todayIstDateStr) {
                currentClaims = Number(currentUser.superOfferClaimsToday) || 0;
            }
        }
        const updatedClaims = currentClaims + 1;

        // Update user state when screenshot is submitted: trigger cooldown timer & daily limit
        await User.updateOne(
            { $or: [{ userId: String(userId).trim() }, { email: String(userId).trim() }] },
            {
                $set: {
                    isSuperOfferUnlocked: false,
                    superOfferUnlockedAt: null,
                    lastActiveAt: new Date(),
                    lastSuperOfferClaim: new Date(),
                    superOfferClaimsToday: updatedClaims,
                    superOfferClaimsDateStr: todayIstDateStr
                }
            }
        );

        // Create a 0-coin RewardHistory record to start the cooldown timer immediately upon screenshot submit
        try {
            const superOfferOrderId = 'SO_PROOF_COOLDOWN_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
            await RewardHistory.create({
                appName: appName || packageName || 'Super Offer App',
                userId: String(userId).trim(),
                provider: 'Super Offer',
                coins: 0,
                gems: 0,
                rewardType: 'coin',
                orderId: superOfferOrderId,
                timestamp: new Date(),
                createdAt: new Date(),
            });
        } catch (e) {
            console.error('⚠️ Error creating proof submission RewardHistory log:', e);
        }
        try {
            const cacheService = require('../../services/cacheService');
            if (cacheService && cacheService.del) {
                await cacheService.del('so_user_' + String(userId).trim());
                await cacheService.del('user_data_' + String(userId).trim());
            }
        } catch (_) {}

        // Auto-approve logic if enabled
        try {
            const appDataDoc = await AppData.findOne({ key: 'appData' }).lean() || await AppData.findOne({}).lean();
            const superOfferConfig = appDataDoc?.config?.superOfferConfig || appDataDoc?.superOfferConfig || {};
            const isAutoApprove = superOfferConfig.screenshotApprovalType === 'auto';
            if (isAutoApprove) {
                const delayStr = superOfferConfig.screenshotAutoApproveDelay || '10-15';
                const parts = delayStr.split('-');
                const minDelay = parseInt(parts[0]) || 10;
                const maxDelay = parseInt(parts[1]) || minDelay;
                const delaySec = Math.floor(Math.random() * (maxDelay - minDelay + 1)) + minDelay;

                setTimeout(async () => {
                    try {
                        await connectMongo();
                        const activeProof = await ScreenshotProof.findById(proof._id);
                        if (!activeProof || activeProof.status !== 'pending') return;

                        let rewardCoins = Number(activeProof.coins) || 0;
                        if (rewardCoins <= 0) {
                            rewardCoins = Number(superOfferConfig.screenshotCoins) || Math.round((Number(superOfferConfig.reward) || 768) * 0.75);
                        }

                        activeProof.status = 'approved';
                        activeProof.coins = rewardCoins;
                        activeProof.reviewedAt = new Date();
                        activeProof.reviewedBy = 'system';
                        await activeProof.save();

                        // Credit coins to user
                        const user = await User.findOneAndUpdate(
                            {
                                $or: [
                                    { userId: activeProof.userId },
                                    { userId: String(activeProof.userId).trim() },
                                    ...(activeProof.userEmail ? [{ email: activeProof.userEmail }, { gmail: activeProof.userEmail }] : [])
                                ]
                            },
                            { $inc: { coins: rewardCoins, totalCoins: rewardCoins } },
                            { new: true }
                        );

                        if (user) {
                            // Check if there are usage steps configured
                            const configuredUsageSteps = Array.isArray(superOfferConfig.usageSteps) && superOfferConfig.usageSteps.length > 0
                                ? superOfferConfig.usageSteps
                                : [];
                            const finalProvider = 'Super Offer Proof';

                            await RewardHistory.create({
                                appName: activeProof.appName || user.appName || 'Super Offer',
                                userId: user.userId || activeProof.userId,
                                provider: finalProvider,
                                coins: rewardCoins,
                                gems: 0,
                                rewardType: 'coin',
                                orderId: 'SOP_AUTO_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6),
                                createdAt: new Date(),
                            });

                            // Invalidate Cache
                            try {
                                const cacheService = require('../../services/cacheService');
                                if (cacheService && cacheService.del) {
                                    await cacheService.del('so_user_' + String(user.userId).trim());
                                    await cacheService.del('user_data_' + String(user.userId).trim());
                                }
                            } catch (_) {}

                            // Send Notification
                            try {
                                const { sendNotificationViaApi } = require('../../admin/middlewares/send-notification-api');
                                if (typeof sendNotificationViaApi === 'function') {
                                    await sendNotificationViaApi({
                                        title: 'Super Offer Approved! 🎉',
                                        body: `Your Super Offer for ${activeProof.appName || 'Super Offer'} was approved! +${rewardCoins} Coins added to your wallet.`,
                                        userId: String(user.userId || activeProof.userId).trim(),
                                        data: {
                                            type: 'super_offer_approved',
                                            packageName: packageName
                                        }
                                    });
                                }
                            } catch (err) {
                                console.error('⚠️ Auto-approve sendNotification Error:', err);
                            }
                        }
                    } catch (err) {
                        console.error('🔥 Error in auto-approval timeout:', err);
                    }
                }, delaySec * 1000);
            }
        } catch (e) {
            console.error('⚠️ Error initializing auto-approve:', e);
        }

        return res.status(200).json({ success: true, message: 'Proof submitted successfully', proofId: proof._id, imageUrl: savedImageUrl });
    } catch (error) {
        console.error('🔥 Error in /super-offer/submit-screenshot:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 6. GET SUPER OFFER SCREENSHOT PROOF STATUS
router.post('/proof-status', cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        const { packageName } = req.body || {};

        if (!userId || !packageName) {
            return res.status(400).json({ success: false, message: 'Missing userId or packageName' });
        }

        await connectMongo();

        const proof = await ScreenshotProof.findOne({
            $or: [
                { userId: String(userId).trim(), offerId: 'super_offer_' + packageName },
                { userId: String(userId).trim(), offerId: packageName }
            ]
        }).sort({ createdAt: -1 }).lean();

        if (!proof) {
            return res.json({ success: true, status: 'none', proof: null });
        }

        return res.json({
            success: true,
            status: proof.status,
            proof: {
                id: proof._id,
                imageUrl: proof.imageUrl,
                status: proof.status,
                coins: proof.coins,
                rejectionReason: proof.rejectionReason || '',
                reviewedAt: proof.reviewedAt,
                createdAt: proof.createdAt,
            }
        });
    } catch (error) {
        console.error('🔥 Error in /super-offer/proof-status:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 7. GET ACTIVE / PENDING OFFERS FOR USER (For App Sync with DB Snapshot)
router.post('/user-pending-offers', cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        if (!userId) {
            return res.status(400).json({ success: false, message: 'Missing userId' });
        }

        await connectMongo();
        const trimmedUid = String(userId).trim();

        const user = await User.findOne({ $or: [{ userId: trimmedUid }, { email: trimmedUid }, { gmail: trimmedUid }] }).lean();
        const uidList = [trimmedUid];
        if (user) {
            if (user.userId) uidList.push(String(user.userId).trim());
            if (user.email) uidList.push(user.email);
            if (user.gmail) uidList.push(user.gmail);
        }

        const histories = await SuperOfferHistory.find({
            $or: [{ userId: { $in: uidList } }, { userEmail: { $in: uidList } }]
        }).sort({ createdAt: -1 }).lean();

        const proofs = await ScreenshotProof.find({
            $or: [{ userId: { $in: uidList } }, { userEmail: { $in: uidList } }]
        }).sort({ createdAt: -1 }).lean();

        // Group by package
        const appMap = new Map();
        histories.forEach(h => {
            const pkg = h.packageName || 'super_offer_app';
            const isInstall = h.stepType === 'install';
            if (!appMap.has(pkg)) {
                const isVerif = h.isVerificationEnabled === true;
                appMap.set(pkg, {
                    packageName: pkg,
                    appName: h.appName || pkg,
                    isVerificationEnabled: isVerif,
                    configSnapshot: h.configSnapshot || null,
                    coins: isInstall ? (Number(h.coins) || 0) : 0,
                    status: h.status || 'in_progress',
                    step1Claimed: isInstall && (h.status === 'completed' || h.status === 'in_progress'),
                    proofSubmitted: false,
                    proofStatus: 'not_submitted',
                    proofImageUrl: '',
                    rejectionReason: '',
                    installedAt: h.installedAt || h.createdAt,
                    savedAt: (h.createdAt ? new Date(h.createdAt).getTime() : Date.now()),
                });
            }
            const app = appMap.get(pkg);
            if (h.isVerificationEnabled === true) {
                app.isVerificationEnabled = true;
            }
            if (h.configSnapshot && (!app.configSnapshot || Object.keys(app.configSnapshot).length === 0)) {
                app.configSnapshot = h.configSnapshot;
            }
            if (isInstall) {
                if (h.status === 'completed' || h.status === 'in_progress') {
                    app.step1Claimed = true;
                }
                if (h.coins && Number(h.coins) > 0) {
                    app.coins = Number(h.coins);
                }
            }
            if (h.stepType === 'screenshot') {
                app.proofSubmitted = true;
                app.proofStatus = h.status;
                app.proofImageUrl = h.proofImageUrl || '';
                app.rejectionReason = h.rejectionReason || '';
            }
        });

        proofs.forEach(p => {
            const pkg = p.offerId ? p.offerId.replace('super_offer_', '') : p.appName || 'super_offer_app';
            if (appMap.has(pkg)) {
                const app = appMap.get(pkg);
                app.isVerificationEnabled = true;
                app.proofSubmitted = true;
                app.proofStatus = p.status;
                app.proofImageUrl = p.imageUrl || '';
                app.rejectionReason = p.rejectionReason || '';
                app.proofReviewedAt = p.reviewedAt || p.updatedAt || null;
                app.proofCreatedAt = p.createdAt || null;
            }
        });

        const appDataDoc = await AppData.findOne({}).lean().catch(() => null);
        const globalSuperOfferConfig = (appDataDoc && appDataDoc.config && appDataDoc.config.superOfferConfig)
            ? appDataDoc.config.superOfferConfig
            : (appDataDoc && appDataDoc.superOfferConfig ? appDataDoc.superOfferConfig : {});
        const liveSteps = (Array.isArray(globalSuperOfferConfig.usageSteps) && globalSuperOfferConfig.usageSteps.length > 0)
            ? globalSuperOfferConfig.usageSteps
            : [];

        const pendingOffers = [];
        const activePackages = [];

        appMap.forEach(app => {
            const snapshotReward = Number(app.configSnapshot?.reward) || 0;
            const globalReward = Number(globalSuperOfferConfig?.reward) || 0;
            const fallbackReward = snapshotReward > 0 ? snapshotReward : (globalReward > 0 ? globalReward : 5000);
            if (!app.coins || app.coins < 100) {
                app.coins = fallbackReward;
            }

            const configuredUsageSteps = (app.configSnapshot && Array.isArray(app.configSnapshot.usageSteps) && app.configSnapshot.usageSteps.length > 0)
                ? app.configSnapshot.usageSteps
                : (liveSteps.length > 0
                    ? liveSteps
                    : [
                        { stepNumber: 1, name: 'Use App', minutes: 5, coins: 500 },
                        { stepNumber: 2, name: 'Use App', minutes: 5, coins: 500 },
                        { stepNumber: 3, name: 'Use App', minutes: 5, coins: 500 }
                    ]);

            const activeMethod = (app.configSnapshot && app.configSnapshot.activeMethod) || globalSuperOfferConfig.activeMethod || (globalSuperOfferConfig.screenshotVerificationEnabled === false ? 3 : 4);
            const isScreenshotOn = (activeMethod === 4) && (globalSuperOfferConfig.screenshotVerificationEnabled !== false);
            const baseUsageOffset = isScreenshotOn ? 3 : 2;

            const hasUsageSteps = configuredUsageSteps.length > 0;
            let allUsageStepsDone = true;
            if (hasUsageSteps) {
                for (let i = 0; i < configuredUsageSteps.length; i++) {
                    const stepNum = i + baseUsageOffset;
                    const st = configuredUsageSteps[i];
                    const isDone = histories.some(h => {
                        const isSameApp = (h.packageName === app.packageName || h.appName === app.appName);
                        if (!isSameApp) return false;
                        const isStatusDone = (h.status === 'completed' || h.status === 'approved' || h.status === 'skipped');
                        if (!isStatusDone) return false;
                        if (h.stepName && st.name) {
                            return h.stepName.trim().toLowerCase() === st.name.trim().toLowerCase();
                        }
                        return h.stepNumber === stepNum;
                    });
                    if (!isDone) {
                        allUsageStepsDone = false;
                        break;
                    }
                }
            }

            const isScreenshotBypassed = !isScreenshotOn || globalSuperOfferConfig.screenshotVerificationEnabled === false || (app.configSnapshot && app.configSnapshot.screenshotVerificationEnabled === false);
            if (isScreenshotBypassed) {
                app.proofStatus = 'approved';
                app.proofSubmitted = true;
            }
            const isScreenshotApproved = isScreenshotBypassed || app.proofStatus === 'approved' || app.status === 'approved';
            const isFullyFinished = (hasUsageSteps ? (isScreenshotApproved && allUsageStepsDone) : isScreenshotApproved) || app.status === 'removed' || app.status === 'uninstalled';

            if (app.isVerificationEnabled && !isFullyFinished) {
                pendingOffers.push(app);
                activePackages.push(app.packageName);
            }
        });

        pendingOffers.sort((a, b) => {
            const timeA = new Date(a.installedAt || a.createdAt || a.savedAt || 0).getTime();
            const timeB = new Date(b.installedAt || b.createdAt || b.savedAt || 0).getTime();
            return timeB - timeA;
        });

        return res.json({
            success: true,
            packages: pendingOffers.map(o => o.packageName),
            offers: pendingOffers,
        });
    } catch (error) {
        console.error('🔥 Error in /super-offer/user-pending-offers:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 8. DEDUCT GEMS WHEN UNLOCKING SUPER OFFER
router.post('/deduct-gems', cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        let gemsRequired = Number(req.body?.gemsRequired) || 0;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'Missing userId' });
        }

        await connectMongo();
        const user = await User.findOne({
            $or: [
                { userId: String(userId).trim() },
                { email: String(userId).trim() },
                { gmail: String(userId).trim() }
            ]
        });

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if ((user.gems || 0) < gemsRequired) {
            return res.status(400).json({
                success: false,
                message: 'Insufficient gems balance',
                gems: user.gems || 0,
                gemsRequired: gemsRequired
            });
        }

        user.gems = Math.max(0, (user.gems || 0) - gemsRequired);
        user.isSuperOfferUnlocked = true;
        user.superOfferUnlockedAt = new Date();
        user.lastActiveAt = new Date();
        await user.save();

        const orderId = 'SO_DEDUCT_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
        const reqAppName = String(req.body?.appName || req.headers['app-name'] || '').trim().toLowerCase();
        const finalAppName = reqAppName || 'crazyreward';

        await RewardHistory.create({
            appName: finalAppName,
            userId: user.userId || userId,
            provider: 'Super Offer Unlock',
            coins: 0,
            gems: -gemsRequired,
            rewardType: 'gem',
            orderId: orderId,
            timestamp: new Date(),
            createdAt: new Date(),
        });

        // Build and save configSnapshot at UNLOCK time
        let configSnapshot = null;
        try {
            const appDataDoc = await AppData.findOne();
            const superOfferConfig = (appDataDoc && appDataDoc.config && appDataDoc.config.superOfferConfig)
                ? appDataDoc.config.superOfferConfig
                : (appDataDoc && appDataDoc.superOfferConfig ? appDataDoc.superOfferConfig : {});

            const isVerificationEnabled = superOfferConfig.superOfferVerificationEnabled !== false;
            const isScreenshotEnabled = isVerificationEnabled && (superOfferConfig.screenshotVerificationEnabled !== false);

            configSnapshot = {
                superOfferVerificationEnabled: isVerificationEnabled,
                verificationEnabled: isVerificationEnabled,
                screenshotVerificationEnabled: isScreenshotEnabled,
                reward: superOfferConfig.reward || 768,
                screenshotCoins: superOfferConfig.screenshotCoins || 576,
                initialUsageSeconds: superOfferConfig.initialUsageSeconds || 120,
                usageSteps: Array.isArray(superOfferConfig.usageSteps) ? superOfferConfig.usageSteps : [],
            };

            if (isVerificationEnabled) {
                const userEmail = user?.email || user?.gmail || '';
                const normalizedUid = String(user?.userId || userId).trim();

                let existingInProg = await SuperOfferHistory.findOne({
                    userId: normalizedUid,
                    status: 'in_progress',
                    stepNumber: 1
                });

                if (existingInProg) {
                    existingInProg.configSnapshot = configSnapshot;
                    existingInProg.isVerificationEnabled = isVerificationEnabled;
                    existingInProg.createdAt = new Date();
                    await existingInProg.save();
                } else {
                    await SuperOfferHistory.create({
                        userId: normalizedUid,
                        userEmail,
                        packageName: '',
                        appName: '',
                        stepNumber: 1,
                        stepName: 'Install App',
                        stepType: 'install',
                        status: 'in_progress',
                        isVerificationEnabled,
                        configSnapshot,
                        coins: 0,
                        usageMinutes: 0,
                        createdAt: new Date(),
                    });
                }
            }
        } catch (csErr) {
            console.error('Error creating in_progress history on unlock:', csErr);
        }

        console.log(`💎 [DeductGems] Deducted ${gemsRequired} gems from userId=${userId}. New gems balance: ${user.gems}`);

        return res.json({
            success: true,
            response: 'success',
            message: 'Gems deducted successfully',
            gems: user.gems,
            configSnapshot
        });
    } catch (error) {
        console.error('🔥 Error in /super-offer/deduct-gems:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 9. CLAIM SUPER OFFER USAGE STEP (Step 3, Step 4, etc.)
router.post('/claim-usage-step', cryptoMiddleware, async (req, res) => {
    try {
        let userId = req.body?.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query?.userId;
        const { packageName, appName, stepNumber, stepName, coins, usageMinutes } = req.body || {};

        if (!userId || !packageName) {
            return res.status(400).json({ success: false, message: 'Missing userId or packageName' });
        }

        await connectMongo();
        const user = await User.findOne({
            $or: [
                { userId: String(userId).trim() },
                { email: String(userId).trim() },
                { gmail: String(userId).trim() },
                { firebaseUid: String(userId).trim() }
            ]
        });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        if (user.isGuest === true || user.isAnonymous === true) {
            return res.status(403).json({ success: false, message: 'Guest accounts cannot claim Super Offers. Please log in with Google to continue!' });
        }

        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean() || await AppData.findOne({}).lean();
        const superOfferConfig = appDataDoc?.config?.superOfferConfig || appDataDoc?.superOfferConfig || {};
        const configuredUsageSteps = Array.isArray(superOfferConfig.usageSteps) && superOfferConfig.usageSteps.length > 0
            ? superOfferConfig.usageSteps
            : [];
        const totalUsageSteps = configuredUsageSteps.length;
        const isScreenshotOn = superOfferConfig.activeMethod ? (superOfferConfig.activeMethod === 4) : (superOfferConfig.screenshotVerificationEnabled !== false);
        const baseOffset = isScreenshotOn ? 2 : 1;
        const isFinalStep = Number(stepNumber) >= (totalUsageSteps + baseOffset);

        // 🛡️ Security Fix: Authoritative step coin lookup from DB config
        const stepIdx = (Number(stepNumber) || 3) - (isScreenshotOn ? 3 : 2);
        const matchedConfigStep = configuredUsageSteps[stepIdx] || configuredUsageSteps.find(s => s && s.stepNumber === Number(stepNumber));
        const configuredStepCoins = matchedConfigStep ? Number(matchedConfigStep.coins || matchedConfigStep.reward || 0) : 0;

        const stepStatus = req.body?.status === 'skipped' ? 'skipped' : 'completed';
        const coinsToAdd = stepStatus === 'skipped' ? 0 : (configuredStepCoins > 0 ? configuredStepCoins : Math.min(Number(coins) || 0, 50));

        if (coinsToAdd > 0) {
            user.coins = (Number(user.coins) || 0) + coinsToAdd;
            user.totalCoins = (Number(user.totalCoins) || 0) + coinsToAdd;
        }

        const finalProvider = 'Super Offer Usage';

        if (isFinalStep) {
            user.isSuperOfferUnlocked = false;
            user.superOfferUnlockedAt = null;
        }
        user.lastActiveAt = new Date();
        await user.save();

        if (coinsToAdd > 0) {
            const superOfferOrderId = 'SOU_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
            const normalizedUserId = String(user.userId || userId).trim();
            const offerAppName = String(appName || packageName || 'Super Offer App').trim();

            await RewardHistory.create({
                appName: offerAppName,
                userId: normalizedUserId,
                provider: finalProvider,
                coins: coinsToAdd,
                gems: 0,
                rewardType: 'coin',
                orderId: superOfferOrderId,
                timestamp: new Date(),
                createdAt: new Date(),
            });
        }

        const userEmail = user?.email || user?.gmail || '';
        const normalizedUid = String(user?.userId || userId).trim();

        await SuperOfferHistory.create({
            userId: normalizedUid,
            userEmail,
            packageName,
            appName: appName || packageName,
            stepNumber: Number(stepNumber) || 3,
            stepName: stepName || `Use App Step ${(Number(stepNumber) || 3) - 2}`,
            stepType: 'usage',
            status: stepStatus,
            coins: coinsToAdd,
            usageMinutes: Number(usageMinutes) || 0,
            isVerificationEnabled: true,
            completedAt: new Date(),
            createdAt: new Date(),
        });

        // Invalidate Redis cache
        try {
            const cacheService = require('../../services/cacheService');
            if (cacheService && cacheService.del) {
                await cacheService.del('so_user_' + normalizedUid);
                await cacheService.del('user_data_' + normalizedUid);
            }
        } catch (_) {}

        return res.json({
            success: true,
            coins: user.coins,
            message: `+${coinsToAdd} coins credited!`,
        });
    } catch (error) {
        console.error('🔥 Error in claim-usage-step:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

module.exports = router;
