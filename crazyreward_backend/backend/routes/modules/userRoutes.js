const express = require('express');
const router = express.Router();
const connectMongo = require('../../admin/middlewares/connectMongo');
const verifyAuthToken = require('../../admin/middlewares/verifyAuthToken');
const cryptoMiddleware = require('../../admin/middlewares/cryptoMiddleware');
const rateLimiter = require('../../admin/middlewares/rateLimiter');
const syncRateLimiter = rateLimiter({
    windowMs: 60 * 1000,
    max: 5,
    keyPrefix: 'sync-limit',
    keyGenerator: (req) => req.ip || req.headers['x-forwarded-for'] || 'global-sync'
});
const User = require('../../admin/models/user');
const AppData = require('../../admin/models/appData');
const BattleConfig = require('../../admin/models/battleConfig');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Helper to load Server Public Key
function getServerPublicKey() {
    try {
        const pubKeyPath = path.join(__dirname, '../../keys/server_public.pem');
        if (fs.existsSync(pubKeyPath)) {
            return fs.readFileSync(pubKeyPath, 'utf8');
        }
    } catch (e) {
        console.error('Error reading Server Public Key:', e);
    }
    return '';
}

// Helper to generate and set user RSA keys
async function ensureUserKeys(user, deviceId) {
    if (user.clientPublicKey && user.clientPrivateKeyEncrypted) {
        // Already generated, decrypt backup private key to return
        const masterSecret = process.env.MASTER_API_KEY || '';
        const sessionKey = cryptoMiddleware.deriveSessionKey(user.userId, deviceId || user.deviceId || '');
        let decryptedPrivateKey = cryptoMiddleware.ChCrypto.decrypt(user.clientPrivateKeyEncrypted, sessionKey);

        // Fallback checks
        if (!decryptedPrivateKey) {
            decryptedPrivateKey = cryptoMiddleware.ChCrypto.decrypt(user.clientPrivateKeyEncrypted, masterSecret);
        }

        if (decryptedPrivateKey) {
            return {
                clientPrivateKey: decryptedPrivateKey,
                serverPublicKey: getServerPublicKey()
            };
        }
    }

    // Generate new key pair
    try {
        const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
            modulusLength: 2048,
            publicKeyEncoding: {
                type: 'spki',
                format: 'pem'
            },
            privateKeyEncoding: {
                type: 'pkcs8',
                format: 'pem'
            }
        });

        const sessionKey = cryptoMiddleware.deriveSessionKey(user.userId, deviceId || user.deviceId || '');
        const encryptedPrivateKey = cryptoMiddleware.ChCrypto.encrypt(privateKey, sessionKey);

        user.clientPublicKey = publicKey;
        user.clientPrivateKeyEncrypted = encryptedPrivateKey;
        await user.save();

        return {
            clientPrivateKey: privateKey,
            serverPublicKey: getServerPublicKey()
        };
    } catch (err) {
        console.error('Error generating client key pair:', err);
        return null;
    }
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

// Helper to safely extract client IP address (Cloudflare, Reverse Proxy, or Direct)
function getClientIp(req) {
    let ip = req.headers['cf-connecting-ip'] ||
        req.headers['x-forwarded-for']?.split(',')[0] ||
        req.headers['x-real-ip'] ||
        req.ip ||
        req.socket?.remoteAddress ||
        '';
    ip = String(ip).trim();
    if (ip.startsWith('::ffff:')) {
        ip = ip.substring(7);
    }
    return ip;
}

// User Sync API
router.post(['/sync', '/user-sync'], cryptoMiddleware, syncRateLimiter, verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId;
        const { email, name, photoUrl, deviceId, gaid, isGuest, deviceInfo, publisherRef, publisherUid } = req.body;

        let user = null;
        if (userId) {
            user = await User.findOne({ userId });
        }
        if (!user && email) {
            const cleanEmail = String(email).trim().toLowerCase();
            user = await User.findOne({
                $or: [
                    { email: cleanEmail },
                    { email: { $regex: new RegExp(`^${cleanEmail}$`, 'i') } },
                    { gmail: cleanEmail },
                    { gmail: { $regex: new RegExp(`^${cleanEmail}$`, 'i') } }
                ]
            });
            if (user && userId && !user.userId) {
                user.userId = userId;
                await user.save();
            }
        }
        if (user) {
            if (user.account_deleted) {
                return res.status(403).json({ success: false, isDeleted: true, message: 'Account is deleted' });
            }
            if (user.isBlocked || user.blocked) {
                return res.status(403).json({ success: false, isBlocked: true, message: 'Account is blocked' });
            }
            let updated = false;

            const clientIp = getClientIp(req);
            if (clientIp && user.ipAddress !== clientIp) {
                user.ipAddress = clientIp;
                updated = true;
            }

            const now = new Date();
            const istOffset = 5.5 * 60 * 60 * 1000;
            const todayIstDateStr = new Date(now.getTime() + istOffset).toISOString().split('T')[0];

            if (user.lastStreakDateStr && user.lastStreakDateStr !== todayIstDateStr) {
                const yesterdayObj = new Date(now.getTime() + istOffset - 24 * 60 * 60 * 1000);
                const yesterdayIstDateStr = yesterdayObj.toISOString().split('T')[0];

                if (user.lastStreakDateStr === yesterdayIstDateStr && user.streakClaimed) {
                    user.streak = Number(user.streak || 1) >= 7 ? 1 : Number(user.streak || 1) + 1;
                } else if (user.lastStreakDateStr !== yesterdayIstDateStr) {
                    user.streak = 1;
                }
                user.streakClaimed = false;
                updated = true;
            }

            // 1. Check Super Offer assigned date
            if (user.superOfferAssignedDateStr !== todayIstDateStr) {
                const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
                const superOfferConfig = appDataDoc?.config?.superOfferConfig || {};

                const limitType = superOfferConfig.limitType || 'hours';
                const userSuperOfferLimit = parseNumberOrRange(superOfferConfig.superOfferDailyLimit || superOfferConfig.dailyLimit);

                user.superOfferAssignType = limitType;
                user.superOfferLimit = userSuperOfferLimit;
                user.superOfferClaimsToday = 0;
                user.isSuperOfferUnlocked = false;
                user.superOfferUnlockedAt = null;
                user.superOfferAssignedAt = new Date();
                user.superOfferAssignedDateStr = todayIstDateStr;
                updated = true;
            }

            // 2. Check Diamond Catch assigned date
            if (user.gameAssignedDateStr !== todayIstDateStr) {
                const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
                const superOfferConfig = appDataDoc?.config?.superOfferConfig || {};

                const userGameDailyLimit = parseNumberOrRange(superOfferConfig.gameDailyLimit);
                const gameInstallTriggerAt = parseNumberOrRange(superOfferConfig.gameInstallTaskTriggerLimit);

                user.gameDailyLimit = userGameDailyLimit;
                user.superOfferGameInstallTriggerAt = gameInstallTriggerAt;
                user.gameClaimsToday = 0;
                user.gameAssignedAt = new Date();
                user.gameAssignedDateStr = todayIstDateStr;
                updated = true;
            }

            // 3. Check Battle Install Task assigned date
            if (user.battleInstallTaskAssignedDateStr !== todayIstDateStr) {
                const configDoc = await BattleConfig.findOne({ key: 'battleConfig' }).lean() || {};
                const assignedCount = parseNumberOrRange(configDoc.battleInstallTaskCount, 0);
                const dailyLimitRaw = parseNumberOrRange(configDoc.battleDailyLimit, 0);
                const dailyLimit = dailyLimitRaw === 0 ? -1 : dailyLimitRaw;
                user.battleInstallTaskNumber = assignedCount;
                user.battleInstallTaskCompletedToday = false;
                user.freeBattlesJoinedToday = 0;
                user.battlesJoinedToday = 0;
                user.battleDailyLimit = dailyLimit;
                user.battleInstallTaskAssignedDate = new Date();
                user.battleInstallTaskAssignedDateStr = todayIstDateStr;
                updated = true;
            }

            if (deviceId && user.deviceId !== deviceId) {
                user.deviceId = deviceId;
                updated = true;
            }
            if (gaid && user.gaid !== gaid) {
                user.gaid = gaid;
                updated = true;
            }
            if (publisherRef && user.publisherRef !== publisherRef) {
                user.publisherRef = publisherRef;
                updated = true;
            }
            if (publisherUid && user.publisherUid !== publisherUid) {
                user.publisherUid = publisherUid;
                updated = true;
            }
            if (user.isGuest && (isGuest === false || isGuest === 'false')) {
                user.isGuest = false;
                if (email && String(email).trim()) {
                    user.email = String(email).trim().toLowerCase();
                }
                if (name && (!user.displayName || user.displayName === 'Guest User')) {
                    user.displayName = name;
                }
                if (photoUrl) {
                    user.photoUrl = photoUrl;
                }
                updated = true;
            }
            if (deviceInfo) {
                if (deviceInfo.isRooted !== undefined) user.isRooted = !!deviceInfo.isRooted;
                if (deviceInfo.isEmulator !== undefined) user.isEmulator = !!deviceInfo.isEmulator;
                if (deviceInfo.isVpnActive !== undefined) user.isVpnActive = !!deviceInfo.isVpnActive;
                if (deviceInfo.isDeveloperOptions !== undefined) user.isDeveloperOptions = !!deviceInfo.isDeveloperOptions;
                if (deviceInfo.isMockLocation !== undefined) user.isMockLocation = !!deviceInfo.isMockLocation;
                if (deviceInfo.physicalDeviceId) user.physicalDeviceId = String(deviceInfo.physicalDeviceId);
                updated = true;
            }
            if (updated) {
                await user.save();
            }
            // Generate/load client keys for hybrid envelope encryption
            const keyInfo = await ensureUserKeys(user, deviceId);

            return res.json({
                success: true,
                exists: true,
                user,
                ...(keyInfo ? {
                    clientPrivateKey: keyInfo.clientPrivateKey,
                    serverPublicKey: keyInfo.serverPublicKey
                } : {})
            });
        }

        if (deviceId && !isGuest) {
            const deviceAccountsCount = await User.countDocuments({ deviceId, isGuest: false });
            if (deviceAccountsCount >= 1) {
                const existingAccounts = await User.find({ deviceId, isGuest: false }).select('email').lean();
                const emails = existingAccounts.map(u => u.email).filter(Boolean);
                return res.status(400).json({
                    success: false,
                    deviceLimitExceeded: true,
                    emails,
                    message: 'Device account limit exceeded'
                });
            }
        }

        return res.json({ success: true, exists: false });
    } catch (err) {
        console.error('❌ User sync error:', err);
        return res.status(500).json({ success: false, message: 'Failed to sync user data' });
    }
});

// Save User Details API
router.post(['/save-details', '/save-user-details'], cryptoMiddleware, verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId;
        const { name, email, photoUrl, mobileNo, gender, country, referralCode, inputReferralCode, deviceId, gaid, publisherRef, publisherUid } = req.body;
        const clientIp = getClientIp(req);

        let user = await User.findOne({ userId });

        if (!user) {
            const isGuestAccount = req.body.isGuest === true || req.body.isGuest === 'true';
            const userEmail = isGuestAccount ? '' : ((email && String(email).trim()) ? String(email).trim() : '');
            const finalReferralCode = referralCode || Math.random().toString(36).substring(2, 8).toUpperCase();

            // Fetch Welcome/Signup coins and Bonus Trigger Mode from AppData config
            let signupCoins = 0;
            let signupBonusMode = 'signup_direct';
            try {
                const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
                if (appDataDoc && appDataDoc.config) {
                    signupCoins = Number(appDataDoc.config.signupCoins) || 0;
                    if (appDataDoc.config.signupBonusMode) {
                        signupBonusMode = appDataDoc.config.signupBonusMode;
                    }
                }
            } catch (err) {
                console.error('Error fetching signupCoins config:', err);
            }

            let referredByVal = '';
            let referredVal = false;
            let uplineVal = [];

            if (inputReferralCode && String(inputReferralCode).trim() && !isGuestAccount) {
                const cleanInputCode = String(inputReferralCode).trim();
                const escapedCode = cleanInputCode.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                const referrer = await User.findOne({
                    $or: [
                        { referralCode: cleanInputCode },
                        { referralCode: { $regex: new RegExp('^' + escapedCode + '$', 'i') } },
                        { userId: cleanInputCode }
                    ],
                    isGuest: { $ne: true },
                    isBlocked: { $ne: true },
                    account_deleted: { $ne: true }
                });
                if (!referrer) {
                    return res.status(400).json({
                        success: false,
                        message: 'Invalid referral code! This referral code does not exist.'
                    });
                }
                if (referrer.userId === userId) {
                    return res.status(400).json({
                        success: false,
                        message: 'You cannot use your own referral code.'
                    });
                }
                // Circular Referral Loop Prevention:
                if (
                    referrer.referredBy === userId ||
                    (user && user.referralCode && referrer.referredBy === user.referralCode) ||
                    (Array.isArray(referrer.upline) && (referrer.upline.includes(userId) || (user && user.referralCode && referrer.upline.includes(user.referralCode))))
                ) {
                    return res.status(400).json({
                        success: false,
                        message: 'You cannot use the referral code of someone you referred!'
                    });
                }
                referredByVal = referrer.userId;
                referredVal = true;
                uplineVal = [referrer.userId, ...(referrer.upline || [])].slice(0, 3);
            }

            // Determine awarded bonus coins based on signupBonusMode:
            // Mode 'signup_direct': Direct signup bonus awarded to regular users upon registration.
            // Mode 'referral_code': Referral bonus awarded ONLY when registering via referral code / link.
            // NOTE: Guest accounts receive ZERO bonus coins (no signup bonus, no referral bonus).
            let signupCoinsToAward = 0;
            if (!isGuestAccount) {
                if (signupBonusMode === 'signup_direct') {
                    signupCoinsToAward = signupCoins;
                } else if (signupBonusMode === 'referral_code') {
                    if (referredVal === true) {
                        signupCoinsToAward = signupCoins;
                    }
                }
            }

            const initialCoins = isGuestAccount ? 0 : signupCoinsToAward;

            user = await User.create({
                userId,
                email: userEmail,
                displayName: name || '',
                photoUrl: photoUrl || '',
                mobileNo: mobileNo || '',
                gender: gender || 'Male',
                countryCode: country || 'IN',
                referralCode: finalReferralCode,
                referredBy: referredByVal,
                referred: referredVal,
                upline: uplineVal,
                deviceId: deviceId || '',
                gaid: gaid || '',
                ipAddress: clientIp,
                coins: initialCoins,
                bonusCoins: initialCoins,
                totalCoins: initialCoins,
                gems: 0,
                account_deleted: false,
                isBlocked: false,
                isGuest: isGuestAccount,
                streak: 1,
                streakClaimed: false,
                socialFollowed: [],
                source: '',
                publisherRef: publisherRef || '',
                publisherUid: publisherUid || '',
                firstLogin: new Date(),
                lastActiveAt: new Date(),
                createdAt: new Date()
            });

            // Write to Reward History and send push notification if signupCoinsToAward > 0 (Only non-guest accounts)
            if (!isGuestAccount && signupCoinsToAward > 0) {
                try {
                    const RewardHistory = require('../../admin/models/rewardHistory');
                    const signupOrderId = 'SIGNUP_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7);
                    await RewardHistory.create({
                        appName: 'Crazyreward',
                        userId,
                        provider: referredVal ? 'Referral Bonus' : 'Signup Bonus',
                        coins: signupCoinsToAward,
                        gems: 0,
                        rewardType: 'coin',
                        orderId: signupOrderId,
                        createdAt: new Date(),
                    });
                } catch (err) {
                    console.error('Error creating RewardHistory for signup bonus:', err);
                }

                try {
                    const { sendNotificationViaApi } = require('../../admin/middlewares/send-notification-api');
                    await sendNotificationViaApi({
                        title: referredVal ? 'Referral Bonus Received! 🎉' : 'Welcome Bonus Received! 🎉',
                        body: referredVal
                            ? `Congratulations! ${signupCoinsToAward} coins referral bonus added to your wallet.`
                            : `Welcome to Crazyreward! ${signupCoinsToAward} coins have been added to your wallet.`,
                        userId,
                    });
                } catch (err) {
                    console.error('Error sending welcome bonus notification:', err);
                }
            }
        } else {
            if (user.isGuest && (req.body.isGuest === false || req.body.isGuest === 'false')) {
                user.isGuest = false;
                if (email && String(email).trim()) {
                    user.email = String(email).trim().toLowerCase();
                }
            }
            if (name) user.displayName = name;
            if (mobileNo) user.mobileNo = mobileNo;
            if (gender) user.gender = gender;
            if (country) user.countryCode = country;
            if (deviceId) user.deviceId = deviceId;
            if (gaid) user.gaid = gaid;
            if (publisherRef) user.publisherRef = publisherRef;
            if (publisherUid) user.publisherUid = publisherUid;
            if (clientIp) user.ipAddress = clientIp;
            await user.save();
        }

        // Generate/load client keys for hybrid envelope encryption
        const keyInfo = await ensureUserKeys(user, deviceId);

        return res.json({
            success: true,
            user,
            ...(keyInfo ? {
                clientPrivateKey: keyInfo.clientPrivateKey,
                serverPublicKey: keyInfo.serverPublicKey
            } : {})
        });
    } catch (err) {
        console.error('❌ Save user details error:', err);
        return res.status(500).json({ success: false, message: 'Failed to save user details' });
    }
});

// User Profile API
router.all(['/profile', '/user-profile'], verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId || req.headers['user-id'] || req.headers['x-user-id'] || req.query.userId || req.body?.userId;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

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

        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const todayIstDateStr = new Date(now.getTime() + istOffset).toISOString().split('T')[0];

        if (user.lastStreakDateStr && user.lastStreakDateStr !== todayIstDateStr) {
            const yesterdayObj = new Date(now.getTime() + istOffset - 24 * 60 * 60 * 1000);
            const yesterdayIstDateStr = yesterdayObj.toISOString().split('T')[0];

            let newStreak = Number(user.streak || 1);
            if (user.lastStreakDateStr === yesterdayIstDateStr && user.streakClaimed) {
                newStreak = newStreak >= 7 ? 1 : newStreak + 1;
            } else if (user.lastStreakDateStr !== yesterdayIstDateStr) {
                newStreak = 1;
            }

            await User.updateOne(
                { userId: user.userId },
                { $set: { streak: newStreak, streakClaimed: false } }
            ).catch(() => { });

            user.streak = newStreak;
            user.streakClaimed = false;
        }

        let updatedProfile = false;
        let setFields = {};

        const clientIp = getClientIp(req);
        if (clientIp && user.ipAddress !== clientIp) {
            setFields.ipAddress = clientIp;
            user.ipAddress = clientIp;
            updatedProfile = true;
        }

        // 1. Check Super Offer assigned date
        if (user.superOfferAssignedDateStr !== todayIstDateStr) {
            const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
            const superOfferConfig = appDataDoc?.config?.superOfferConfig || {};

            const limitType = superOfferConfig.limitType || 'hours';
            const userSuperOfferLimit = parseNumberOrRange(superOfferConfig.superOfferDailyLimit || superOfferConfig.dailyLimit);

            setFields.superOfferAssignType = limitType;
            setFields.superOfferLimit = userSuperOfferLimit;
            setFields.superOfferClaimsToday = 0;
            setFields.isSuperOfferUnlocked = false;
            setFields.superOfferUnlockedAt = null;
            setFields.superOfferAssignedAt = new Date();
            setFields.superOfferAssignedDateStr = todayIstDateStr;
            updatedProfile = true;

            user.superOfferAssignType = limitType;
            user.superOfferLimit = userSuperOfferLimit;
            user.superOfferClaimsToday = 0;
            user.isSuperOfferUnlocked = false;
            user.superOfferUnlockedAt = null;
            user.superOfferAssignedAt = setFields.superOfferAssignedAt;
            user.superOfferAssignedDateStr = todayIstDateStr;
        }

        // 2. Check Diamond Catch assigned date
        if (user.gameAssignedDateStr !== todayIstDateStr) {
            const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
            const superOfferConfig = appDataDoc?.config?.superOfferConfig || {};

            const userGameDailyLimit = parseNumberOrRange(superOfferConfig.gameDailyLimit);
            const gameInstallTriggerAt = parseNumberOrRange(superOfferConfig.gameInstallTaskTriggerLimit);

            setFields.gameDailyLimit = userGameDailyLimit;
            setFields.superOfferGameInstallTriggerAt = gameInstallTriggerAt;
            setFields.gameClaimsToday = 0;
            setFields.gameAssignedAt = new Date();
            setFields.gameAssignedDateStr = todayIstDateStr;
            updatedProfile = true;

            user.gameDailyLimit = userGameDailyLimit;
            user.superOfferGameInstallTriggerAt = gameInstallTriggerAt;
            user.gameClaimsToday = 0;
            user.gameAssignedAt = setFields.gameAssignedAt;
            user.gameAssignedDateStr = todayIstDateStr;
        }

        // 3. Check Battle Install Task assigned date
        if (user.battleInstallTaskAssignedDateStr !== todayIstDateStr) {
            const configDoc = await BattleConfig.findOne({ key: 'battleConfig' }).lean() || {};
            const assignedCount = parseNumberOrRange(configDoc.battleInstallTaskCount, 0);
            const dailyLimitRaw = parseNumberOrRange(configDoc.battleDailyLimit, 0);
            const dailyLimit = dailyLimitRaw === 0 ? -1 : dailyLimitRaw;
            setFields.battleInstallTaskNumber = assignedCount;
            setFields.battleInstallTaskCompletedToday = false;
            setFields.freeBattlesJoinedToday = 0;
            setFields.battlesJoinedToday = 0;
            setFields.battleDailyLimit = dailyLimit;
            setFields.battleInstallTaskAssignedDate = new Date();
            setFields.battleInstallTaskAssignedDateStr = todayIstDateStr;
            updatedProfile = true;

            user.battleInstallTaskNumber = assignedCount;
            user.battleInstallTaskCompletedToday = false;
            user.freeBattlesJoinedToday = 0;
            user.battlesJoinedToday = 0;
            user.battleDailyLimit = dailyLimit;
            user.battleInstallTaskAssignedDate = setFields.battleInstallTaskAssignedDate;
            user.battleInstallTaskAssignedDateStr = todayIstDateStr;
        }

        if (updatedProfile) {
            await User.updateOne({ userId: user.userId }, { $set: setFields }).catch(() => { });
            for (const [k, v] of Object.entries(setFields)) {
                user[k] = v;
            }
        }

        if (user.bonusCoins == null || user.bonusCoins === 0) {
            try {
                const RewardHistory = require('../../admin/models/rewardHistory');
                const bonusHistory = await RewardHistory.find({
                    userId: user.userId,
                    provider: { $in: ['Signup Bonus', 'Referral Bonus'] }
                }).lean();
                if (bonusHistory && bonusHistory.length > 0) {
                    const totalHistoricBonus = bonusHistory.reduce((acc, h) => acc + (Number(h.coins) || 0), 0);
                    const currentCoins = Number(user.coins || 0);
                    const derivedBonus = Math.min(totalHistoricBonus, currentCoins);
                    if (derivedBonus > 0) {
                        user.bonusCoins = derivedBonus;
                        await User.updateOne({ userId: user.userId }, { $set: { bonusCoins: derivedBonus } }).catch(() => { });
                    }
                }
            } catch (_) { }
        }
        user.bonusCoins = Number(user.bonusCoins || 0);

        return res.json({ success: true, user });
    } catch (err) {
        console.error('❌ Get profile error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch profile' });
    }
});

// Update Profile API
router.post('/update-profile', verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId;
        const { mobileNo, displayName, photoUrl } = req.body;
        const clientIp = getClientIp(req);

        const updates = {};
        if (mobileNo !== undefined) updates.mobileNo = mobileNo;
        if (displayName !== undefined) updates.displayName = displayName;
        if (photoUrl !== undefined) updates.photoUrl = photoUrl;
        if (clientIp) updates.ipAddress = clientIp;

        const user = await User.findOneAndUpdate(
            { userId },
            { $set: updates },
            { new: true }
        ).lean();

        return res.json({ success: true, user });
    } catch (err) {
        console.error('❌ Update profile error:', err);
        return res.status(500).json({ success: false, message: 'Failed to update profile' });
    }
});

// Delete Account API
router.post('/delete-account', verifyAuthToken, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId;

        await User.findOneAndUpdate(
            { userId },
            { $set: { delete_requested: true, delete_requested_at: new Date() } }
        );

        return res.json({ success: true, message: 'Account deletion request submitted successfully' });
    } catch (err) {
        console.error('❌ Delete account error:', err);
        return res.status(500).json({ success: false, message: 'Failed to delete account' });
    }
});

// Complete Battle Install Task API
router.post('/complete-battle-install-task', verifyAuthToken, cryptoMiddleware, async (req, res) => {
    try {
        await connectMongo();
        const userId = req.userId;

        const user = await User.findOne({ userId });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const todayIstDateStr = new Date(Date.now() + 5.5 * 60 * 60 * 1000).toISOString().split('T')[0];

        // Ensure date matches today, otherwise reset first
        if (user.battleInstallTaskAssignedDateStr !== todayIstDateStr) {
            const configDoc = await BattleConfig.findOne({ key: 'battleConfig' }).lean() || {};
            const assignedCount = parseNumberOrRange(configDoc.battleInstallTaskCount, 0);
            const dailyLimitRaw = parseNumberOrRange(configDoc.battleDailyLimit, 0);
            const dailyLimit = dailyLimitRaw === 0 ? -1 : dailyLimitRaw;
            user.battleInstallTaskNumber = assignedCount;
            user.battleInstallTaskCompletedToday = false;
            user.freeBattlesJoinedToday = 0;
            user.battlesJoinedToday = 0;
            user.battleDailyLimit = dailyLimit;
            user.battleInstallTaskAssignedDate = new Date();
            user.battleInstallTaskAssignedDateStr = todayIstDateStr;
        }

        user.battleInstallTaskCompletedToday = true;

        await user.save();

        return res.json({ success: true, user });
    } catch (err) {
        console.error('❌ Complete battle install task error:', err);
        return res.status(500).json({ success: false, message: 'Failed to complete task' });
    }
});

// ---------------------------------------------------------
// USER IN-APP NOTIFICATIONS (Managed locally on user device)
// ---------------------------------------------------------
router.get('/notifications', async (req, res) => {
    return res.json({
        success: true,
        notifications: []
    });
});

router.post('/clear-notifications', async (req, res) => {
    return res.json({
        success: true,
        message: 'Notifications cleared successfully'
    });
});

module.exports = router;

