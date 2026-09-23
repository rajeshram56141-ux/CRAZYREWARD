const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const cron = require('node-cron');
const jwt = require('jsonwebtoken');
const Admin = require('../admin/models/admin');
const adminAuth = require('../admin/middlewares/adminAuth');
const connectMongo = require('../admin/middlewares/connectMongo');
const { getOrInitFirebase } = require('../admin/middlewares/firebase-helper');
const DailyTask = require('../admin/models/dailyTask');
const PostbackLogs = require('../admin/models/postbackLogs');
const FirebaseService = require('../admin/models/firebaseService');
const dailyTask = require('../admin/models/dailyTask');
const PlayGames = require('../admin/models/playGames');
const ReadEarn = require('../admin/models/readEarn');
const cacheService = require('../services/cacheService');
const ReadEarnLogs = require('../admin/models/readEarnLogs');
const PayoutHistory = require('../admin/models/payoutHistory');
const PayoutRecord = require('../admin/models/payoutRecord');
const WalletCatalog = require('../admin/models/walletCatalog');
const RewardHistory = require('../admin/models/rewardHistory');
const { default: axios } = require('axios');
const { DateTime } = require('luxon');
const { FieldValue, AggregateField } = require('firebase-admin/firestore');
const { handlePayoutRoute, handlePayoutPostback } = require('../admin/middlewares/handle-payout');
const { sendNotificationViaApi } = require('../admin/middlewares/send-notification-api');
const BlockedHistory = require('../admin/models/blockedHistory');
const SuspiciousActivity = require('../admin/models/suspiciousActivity');
const DailyTaskCategory = require('../admin/models/dailyTaskCategory');
const DailyEarningSummary = require('../admin/models/dailyEarningSummary');
const ScreenshotProof = require('../admin/models/screenshotProof');
const Promoter = require('../admin/models/promoter');
const AppData = require('../admin/models/appData');
const OffersSettings = require('../admin/models/offersSettings');
const ReferralSettings = require('../admin/models/referralSettings');
const PromotionRequest = require('../admin/models/promotionRequest');
const SupportRequest = require('../admin/models/supportRequest');
const User = require('../admin/models/user');
const RewardRecord = require('../admin/models/rewardRecord');
const OfferwallRecord = require('../admin/models/offerwallRecord');
const Giveaway = require('../admin/models/giveaway');
const Leaderboard = require('../admin/models/leaderboard');
const SuperOfferHistory = require('../admin/models/superOfferHistory');
const BannerClickLogs = require('../admin/models/bannerClickLogs');
const crypto = require('crypto');
const { resolveOfferwallEnvFallbacks } = require('../services/offerwallEnvService');

// Helper to generate unique secret key
function generateSecretKey() {
    return crypto.randomBytes(16).toString('hex');
}

const router = express.Router();

const checkPermission = (...permissions) => {
    const permList = permissions.flat();
    return (req, res, next) => {
        const isJson = req.xhr || req.headers['content-type'] === 'application/json' || (req.headers.accept && req.headers.accept.includes('application/json'));
        if (!req.admin) {
            if (isJson) return res.status(401).json({ success: false, message: 'Unauthorized. Please login.' });
            return res.redirect('/login');
        }
        if (req.admin.role === 'superadmin') {
            return next();
        }
        if (req.admin.permissions) {
            const hasAnyPerm = permList.some(p => req.admin.permissions[p] === true);
            if (hasAnyPerm) {
                return next();
            }
        }
        if (isJson) {
            return res.status(403).json({ success: false, message: `Access denied: missing '${permList.join(' or ')}' permission.` });
        }
        return res.status(403).send(`
            <html>
            <head>
                <title>Access Denied</title>
                <link rel="stylesheet" href="/css/admin.css">
            </head>
            <body style="display:flex; align-items:center; justify-content:center; height:100vh; background:#f8fafc; font-family:sans-serif; margin:0;">
                <div style="text-align:center; padding:40px; background:#fff; border:1px solid #e2e8f0; border-radius:16px; box-shadow:0 4px 12px rgba(15,23,42,0.03); max-width:400px;">
                    <div style="font-size:48px; margin-bottom:16px;">🚫</div>
                    <h2 style="margin:0 0 10px; color:#0f172a; font-size:20px; font-weight:700;">Access Denied</h2>
                    <p style="margin:0 0 20px; color:#64748b; font-size:14px; line-height:1.5;">You do not have permission to access the <strong>${permList.join(' / ')}</strong> section.</p>
                    <a href="/" class="btn-primary" style="display:inline-block; text-decoration:none; padding:10px 20px; border-radius:8px; font-size:14px; font-weight:600; color:#fff; background:#2563eb;">Back to Home</a>
                </div>
            </body>
            </html>
        `);
    };
};

const checkSuperAdmin = (req, res, next) => {
    if (!req.admin) {
        return res.redirect('/login');
    }
    if (req.admin.role === 'superadmin') {
        return next();
    }
    return res.status(403).send('Forbidden: Access is restricted to Super Admins only.');
};
const DASHBOARD_STATS_CACHE_TTL_MS = 60 * 1000;
const dashboardStatsCache = new Map();
const IST_TIMEZONE = 'Asia/Kolkata';
const APPDATA_DELAYED_KEYS = ['superOfferConfig'];
const APPDATA_INSTANT_SUB_KEYS = {};

function toIsoDate(value) {
    if (!value) return null;
    if (typeof value?.toDate === 'function') return value.toDate().toISOString();
    const date = value instanceof Date ? value : new Date(value);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function getTodayBounds() {
    const zone = 'Asia/Kolkata';
    const start = DateTime.now().setZone(zone).startOf('day').toJSDate();
    const end = DateTime.now().setZone(zone).endOf('day').toJSDate();
    return { start, end };
}

function buildDailyBuckets(start, end, maxDays = 31) {
    if (!(start instanceof Date) || Number.isNaN(start.getTime())) return [];
    if (!(end instanceof Date) || Number.isNaN(end.getTime())) return [];
    if (end < start) return [];

    const dayMs = 24 * 60 * 60 * 1000;
    const totalDays = Math.floor((end.getTime() - start.getTime()) / dayMs) + 1;
    if (totalDays <= 0 || totalDays > maxDays) return [];

    const list = [];
    for (let i = 0; i < totalDays; i++) {
        const dayStart = new Date(start.getTime() + (i * dayMs));
        dayStart.setHours(0, 0, 0, 0);
        const dayEnd = new Date(dayStart);
        dayEnd.setHours(23, 59, 59, 999);

        list.push({
            start: dayStart,
            end: dayEnd,
            label: dayStart.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' }),
        });
    }

    return list;
}

function getDashboardCache(cacheKey) {
    const cached = dashboardStatsCache.get(cacheKey);
    if (!cached) return null;
    if ((Date.now() - cached.ts) > DASHBOARD_STATS_CACHE_TTL_MS) {
        dashboardStatsCache.delete(cacheKey);
        return null;
    }
    return cached.payload;
}

function setDashboardCache(cacheKey, payload) {
    dashboardStatsCache.set(cacheKey, {
        ts: Date.now(),
        payload,
    });
}

function getNextIstMidnightUtcDate(fromDate = new Date()) {
    return DateTime
        .fromJSDate(fromDate, { zone: IST_TIMEZONE })
        .plus({ days: 1 })
        .startOf('day')
        .toUTC()
        .toJSDate();
}

function toDateOrNull(value) {
    if (!value) return null;
    if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
    if (typeof value?.toDate === 'function') {
        const date = value.toDate();
        return Number.isNaN(date.getTime()) ? null : date;
    }
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function stableStringify(value) {
    if (Array.isArray(value)) {
        return `[${value.map((item) => stableStringify(item)).join(',')}]`;
    }
    if (value && typeof value === 'object') {
        const keys = Object.keys(value).sort();
        return `{${keys.map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(',')}}`;
    }
    return JSON.stringify(value);
}

function areConfigsEqual(a, b) {
    return stableStringify(a) === stableStringify(b);
}

function normalizeRewardList(rewards) {
    if (!Array.isArray(rewards) || rewards.length === 0) {
        return { ok: false, message: 'Rewards must be a non-empty array' };
    }

    const normalized = [];
    for (let i = 0; i < rewards.length; i++) {
        const reward = rewards[i] || {};
        const productName = String(reward.productName || '').trim();
        const productImage = String(reward.productImage || '').trim();
        const productRank = Number(reward.productRank);
        const autoDistribute = reward.autoDistribute === true || reward.autoDistribute === 'true';
        const coins = reward.coins != null && reward.coins !== '' ? Number(reward.coins) : null;

        if (!productName || !productImage || !Number.isFinite(productRank) || productRank < 1) {
            return {
                ok: false,
                message: `Invalid reward at index ${i + 1}. productName, productImage and productRank(>=1) are required`
            };
        }

        if (coins !== null && (!Number.isFinite(coins) || coins < 0)) {
            return {
                ok: false,
                message: `Invalid coins at index ${i + 1}. coins must be a non-negative number`
            };
        }

        normalized.push({
            productName,
            productImage,
            productRank,
            autoDistribute,
            ...(coins !== null ? { coins } : {}),
        });
    }

    return { ok: true, data: normalized };
}

function pickFirebaseService(firebaseServices, appName) {
    if (appName) {
        return firebaseServices.find(service => service.appName === appName) || null;
    }
    return firebaseServices.find(service => service.prioritized) || firebaseServices[0] || null;
}

async function getAppConversionRate() {
    try {
        const cached = await cacheService.get('global:appData');
        const cachedRate = Number(cached?.appData?.conversionRate);
        if (Number.isFinite(cachedRate) && cachedRate > 0) {
            return cachedRate;
        }
        await connectMongo();
        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        const rate = Number(appDataDoc?.config?.conversionRate);
        if (Number.isFinite(rate) && rate > 0) {
            return rate;
        }
    } catch (e) {
        console.error('Error fetching conversionRate from appData:', e);
    }
    return 150;
}

function calculateHotOffersCoins({ payout, conversionRate = 150 }) {
    const payoutNum = Number(payout);
    const rateNum = Number(conversionRate);

    if (!Number.isFinite(payoutNum) || payoutNum <= 0) return 0;
    if (!Number.isFinite(rateNum) || rateNum <= 0) return 0;

    return Math.max(0, Math.floor(payoutNum * rateNum));
}

function normalizeBooleanInput(value) {
    if (typeof value === 'boolean') return value;
    if (value === 'true' || value === '1' || value === 1) return true;
    if (value === 'false' || value === '0' || value === 0) return false;
    return null;
}

async function resolveUserFromIdentifier({ email, userId }) {
    await connectMongo();
    const normalizedEmail = String(email || '').trim().toLowerCase();
    const normalizedUserId = String(userId || '').trim();

    if (normalizedUserId) {
        const user = await User.findOne({ userId: normalizedUserId }).lean();
        if (user) return { exists: true, data: () => user, id: user.userId };
    }

    if (normalizedEmail) {
        const user = await User.findOne({
            $or: [{ email: normalizedEmail }, { userId: normalizedEmail }]
        }).lean();
        if (user) return { exists: true, data: () => user, id: user.userId };
    }

    return null;
}

function normalizeStringArrayInput(value) {
    if (Array.isArray(value)) {
        return value.map((item) => String(item || '').trim()).filter(Boolean);
    }
    if (typeof value === 'string') {
        return value
            .split(',')
            .map((item) => item.trim())
            .filter(Boolean);
    }
    return [];
}

function normalizeWalletMethodUpdates(body = {}) {
    const updates = {};
    const has = (key) => Object.prototype.hasOwnProperty.call(body, key);

    if (has('enabled')) {
        const enabled = normalizeBooleanInput(body.enabled);
        if (enabled === null) return { ok: false, message: 'enabled must be boolean' };
        updates.enabled = enabled;
    }

    if (has('autoPayment')) {
        const autoPayment = normalizeBooleanInput(body.autoPayment);
        if (autoPayment === null) return { ok: false, message: 'autoPayment must be boolean' };
        updates.autoPayment = autoPayment;
    }

    if (has('title')) {
        const title = String(body.title || '').trim();
        if (!title) return { ok: false, message: 'title cannot be empty' };
        updates.title = title;
    }

    if (has('image')) {
        updates.image = String(body.image || '').trim();
    }

    if (has('symbol')) {
        updates.symbol = String(body.symbol || '').trim();
    }

    if (has('rank')) {
        const rank = Number(body.rank);
        if (!Number.isFinite(rank) || rank < 0) return { ok: false, message: 'rank must be a number >= 0' };
        updates.rank = Math.trunc(rank);
    }

    if (has('country')) {
        updates.country = normalizeStringArrayInput(body.country);
    }

    if (has('ex_country')) {
        updates.ex_country = normalizeStringArrayInput(body.ex_country);
    }

    if (has('validators')) {
        updates.validators = normalizeStringArrayInput(body.validators);
    }

    if (has('hints')) {
        if (typeof body.hints === 'object' && body.hints !== null) {
            const cleanHints = {};
            for (const [k, v] of Object.entries(body.hints)) {
                cleanHints[String(k).trim()] = String(v).trim();
            }
            updates.hints = cleanHints;
        } else if (typeof body.hints === 'string') {
            try {
                const parsed = JSON.parse(body.hints);
                if (typeof parsed === 'object' && parsed !== null) {
                    const cleanHints = {};
                    for (const [k, v] of Object.entries(parsed)) {
                        cleanHints[String(k).trim()] = String(v).trim();
                    }
                    updates.hints = cleanHints;
                }
            } catch (e) {
                // ignore
            }
        }
    }

    return { ok: true, updates };
}

function mapDenominationDoc(doc) {
    const data = doc.data() || {};
    return {
        id: doc.id,
        amount: Number(data.amount) || 0,
        coins: Number(data.coins) || 0,
        enabled: !!data.enabled,
    };
}

function isPlainObject(value) {
    return !!value && typeof value === 'object' && !Array.isArray(value);
}

function toNonNegativeNumber(value, fieldName) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0) {
        return { ok: false, message: `${fieldName} must be a number >= 0` };
    }
    return { ok: true, value: parsed };
}

function hasObjectFields(value) {
    return isPlainObject(value) && Object.keys(value).length > 0;
}

function splitConfigByApplyMode(configKey, value) {
    if (!isPlainObject(value)) {
        return { immediate: null, delayed: null };
    }

    const immediateKeys = APPDATA_INSTANT_SUB_KEYS[configKey] || [];
    if (!immediateKeys.length) {
        return { immediate: null, delayed: value };
    }

    const immediate = {};
    const delayed = {};

    for (const [childKey, childValue] of Object.entries(value)) {
        if (immediateKeys.includes(childKey)) {
            immediate[childKey] = childValue;
        } else {
            delayed[childKey] = childValue;
        }
    }

    return {
        immediate: hasObjectFields(immediate) ? immediate : null,
        delayed: hasObjectFields(delayed) ? delayed : null,
    };
}

function sanitizePendingConfigValue(configKey, value) {
    return splitConfigByApplyMode(configKey, value).delayed;
}

function serializeFirestoreValue(value) {
    if (value instanceof Date) {
        return toIsoDate(value);
    }
    if (value && typeof value?.toDate === 'function') {
        return toIsoDate(value);
    }
    if (Array.isArray(value)) {
        return value.map(serializeFirestoreValue);
    }
    if (isPlainObject(value)) {
        const out = {};
        for (const [key, item] of Object.entries(value)) {
            out[key] = serializeFirestoreValue(item);
        }
        return out;
    }
    return value;
}

function normalizeAppDataPayload(payload = {}) {
    if (!isPlainObject(payload)) {
        return { ok: false, message: 'appData must be an object' };
    }

    const updates = {};
    const has = (key) => Object.prototype.hasOwnProperty.call(payload, key);

    if (has('conversionRate')) {
        const parsed = toNonNegativeNumber(payload.conversionRate, 'conversionRate');
        if (!parsed.ok) return parsed;
        updates.conversionRate = parsed.value > 0 ? Math.trunc(parsed.value) : 150;
    }

    if (has('showCoinConversionRate')) {
        updates.showCoinConversionRate = Boolean(payload.showCoinConversionRate === true || payload.showCoinConversionRate === 'true');
    }

    if (has('earningConfig')) {
        if (!isPlainObject(payload.earningConfig)) {
            return { ok: false, message: 'earningConfig must be an object' };
        }
        const earningConfig = {};
        const ec = payload.earningConfig;
        const hasEc = (key) => Object.prototype.hasOwnProperty.call(ec, key);

        if (hasEc('adEcpm')) {
            const parsed = toNonNegativeNumber(ec.adEcpm, 'earningConfig.adEcpm');
            if (!parsed.ok) return parsed;
            earningConfig.adEcpm = parsed.value;
        }

        if (hasEc('offerwallRate')) {
            const parsed = toNonNegativeNumber(ec.offerwallRate, 'earningConfig.offerwallRate');
            if (!parsed.ok) return parsed;
            earningConfig.offerwallRate = Math.trunc(parsed.value);
        }

        if (hasEc('readEarnEcpm')) {
            const parsed = toNonNegativeNumber(ec.readEarnEcpm, 'earningConfig.readEarnEcpm');
            if (!parsed.ok) return parsed;
            earningConfig.readEarnEcpm = parsed.value;
        }

        updates.earningConfig = earningConfig;
    }

    if (has('playtimeConfig')) {
        if (!isPlainObject(payload.playtimeConfig)) {
            return { ok: false, message: 'playtimeConfig must be an object' };
        }

        const playtimeConfig = {};
        const p = payload.playtimeConfig;
        const hasP = (key) => Object.prototype.hasOwnProperty.call(p, key);

        if (hasP('enabled')) {
            const enabled = normalizeBooleanInput(p.enabled);
            if (enabled === null) return { ok: false, message: 'playtimeConfig.enabled must be boolean' };
            playtimeConfig.enabled = enabled;
        }

        if (hasP('offerwallName')) {
            playtimeConfig.offerwallName = String(p.offerwallName || '').trim();
        }

        if (hasP('title')) {
            playtimeConfig.title = String(p.title || '').trim();
        }

        if (hasP('subtitle')) {
            playtimeConfig.subtitle = String(p.subtitle || '').trim();
        }

        updates.playtimeConfig = playtimeConfig;
    }

    if (has('followCoins')) {
        const parsed = toNonNegativeNumber(payload.followCoins, 'followCoins');
        if (!parsed.ok) return parsed;
        updates.followCoins = parsed.value;
    }

    if (has('dailyMaxPayout')) {
        const parsed = toNonNegativeNumber(payload.dailyMaxPayout, 'dailyMaxPayout');
        if (!parsed.ok) return parsed;
        updates.dailyMaxPayout = parsed.value;
    }

    if (has('signupBonusMode')) {
        const mode = String(payload.signupBonusMode || 'signup_direct').trim();
        updates.signupBonusMode = ['signup_direct', 'referral_code'].includes(mode) ? mode : 'signup_direct';
    }

    if (has('signupCoins')) {
        const parsed = toNonNegativeNumber(payload.signupCoins, 'signupCoins');
        if (!parsed.ok) return parsed;
        updates.signupCoins = parsed.value;
    }
    if (has('gameRewardedAds')) {
        const gameRewardedAds = normalizeBooleanInput(payload.gameRewardedAds);
        if (gameRewardedAds === null) return { ok: false, message: 'gameRewardedAds must be boolean' };
        updates.gameRewardedAds = gameRewardedAds;
    }

    if (has('shareText')) {
        updates.shareText = String(payload.shareText || '').trim();
    }

    if (has('adsConfig')) {
        if (!isPlainObject(payload.adsConfig)) {
            return { ok: false, message: 'adsConfig must be an object' };
        }
        const adsConfig = {};
        const a = payload.adsConfig;
        const hasA = (key) => Object.prototype.hasOwnProperty.call(a, key);

        if (hasA('interstitialKey')) adsConfig.interstitialKey = String(a.interstitialKey || '').trim();
        if (hasA('rewardedKey')) adsConfig.rewardedKey = String(a.rewardedKey || '').trim();
        if (hasA('nativeKey')) adsConfig.nativeKey = String(a.nativeKey || '').trim();
        if (hasA('bannerKey')) adsConfig.bannerKey = String(a.bannerKey || '').trim();
        if (hasA('enabled')) {
            const enabled = normalizeBooleanInput(a.enabled);
            adsConfig.enabled = enabled !== null ? enabled : true;
        }
        if (hasA('homeNativeEnabled')) {
            const homeNative = normalizeBooleanInput(a.homeNativeEnabled);
            adsConfig.homeNativeEnabled = homeNative !== null ? homeNative : true;
        }
        if (hasA('superOfferNativeEnabled')) {
            const superOfferNative = normalizeBooleanInput(a.superOfferNativeEnabled);
            adsConfig.superOfferNativeEnabled = superOfferNative !== null ? superOfferNative : true;
        }
        if (hasA('dailyChallengeNativeEnabled')) {
            const dailyChallengeNative = normalizeBooleanInput(a.dailyChallengeNativeEnabled);
            adsConfig.dailyChallengeNativeEnabled = dailyChallengeNative !== null ? dailyChallengeNative : true;
        }
        if (hasA('playGamesNativeEnabled')) {
            const playGamesNative = normalizeBooleanInput(a.playGamesNativeEnabled);
            adsConfig.playGamesNativeEnabled = playGamesNative !== null ? playGamesNative : true;
        }
        if (hasA('watchVideoNativeEnabled')) {
            const watchVideoNative = normalizeBooleanInput(a.watchVideoNativeEnabled);
            adsConfig.watchVideoNativeEnabled = watchVideoNative !== null ? watchVideoNative : true;
        }

        updates.adsConfig = adsConfig;
    }

    if (has('payoutApiUrl')) {
        updates.payoutApiUrl = String(payload.payoutApiUrl || '').trim();
    }

    if (has('payoutApiToken')) {
        updates.payoutApiToken = String(payload.payoutApiToken || '').trim();
    }

    if (has('oneSignalAppId')) {
        updates.oneSignalAppId = String(payload.oneSignalAppId || '').trim();
    }

    if (has('oneSignalApiKey')) {
        updates.oneSignalApiKey = String(payload.oneSignalApiKey || '').trim();
    }

    if (has('streakCoins')) {
        const parsed = toNonNegativeNumber(payload.streakCoins, 'streakCoins');
        if (!parsed.ok) return parsed;
        updates.streakConfig = {
            ...(isPlainObject(updates.streakConfig) ? updates.streakConfig : {}),
            coins: Math.trunc(parsed.value),
        };
    }

    if (has('streakConfig')) {
        if (!isPlainObject(payload.streakConfig)) {
            return { ok: false, message: 'streakConfig must be an object' };
        }

        const streakConfig = isPlainObject(updates.streakConfig) ? updates.streakConfig : {};
        const s = payload.streakConfig;
        const hasS = (key) => Object.prototype.hasOwnProperty.call(s, key);

        if (hasS('coins')) {
            const parsed = toNonNegativeNumber(s.coins, 'streakConfig.coins');
            if (!parsed.ok) return parsed;
            streakConfig.coins = Math.trunc(parsed.value);
        }

        if (hasS('rewardedAds')) {
            const rewardedAds = normalizeBooleanInput(s.rewardedAds);
            if (rewardedAds === null) return { ok: false, message: 'streakConfig.rewardedAds must be boolean' };
            streakConfig.rewardedAds = rewardedAds;
        }

        updates.streakConfig = streakConfig;
    }

    if (has('maintenanceConfig')) {
        if (!isPlainObject(payload.maintenanceConfig)) {
            return { ok: false, message: 'maintenanceConfig must be an object' };
        }

        const maintenanceConfig = {};
        const m = payload.maintenanceConfig;
        const hasM = (key) => Object.prototype.hasOwnProperty.call(m, key);

        if (hasM('enabled')) {
            const enabled = normalizeBooleanInput(m.enabled);
            if (enabled === null) return { ok: false, message: 'maintenanceConfig.enabled must be boolean' };
            maintenanceConfig.enabled = enabled;
        }

        if (hasM('completedAt')) {
            if (m.completedAt === '' || m.completedAt === null) {
                maintenanceConfig.completedAt = null;
            } else {
                const date = new Date(m.completedAt);
                if (Number.isNaN(date.getTime())) {
                    return { ok: false, message: 'maintenanceConfig.completedAt must be a valid date' };
                }
                maintenanceConfig.completedAt = date;
            }
        }

        if (hasM('excludedUserIds')) {
            if (Array.isArray(m.excludedUserIds)) {
                maintenanceConfig.excludedUserIds = m.excludedUserIds
                    .map(x => String(x || '').trim())
                    .filter(Boolean);
            } else if (typeof m.excludedUserIds === 'string') {
                maintenanceConfig.excludedUserIds = m.excludedUserIds
                    .split(/[\n,]+/)
                    .map(x => x.trim())
                    .filter(Boolean);
            } else {
                maintenanceConfig.excludedUserIds = [];
            }
        }

        updates.maintenanceConfig = maintenanceConfig;
    }





    if (has('superOfferConfig')) {
        if (!isPlainObject(payload.superOfferConfig)) {
            return { ok: false, message: 'superOfferConfig must be an object' };
        }

        const superOfferConfig = {};
        const s = payload.superOfferConfig;
        const hasS = (key) => Object.prototype.hasOwnProperty.call(s, key);

        if (hasS('reward')) {
            const parsed = toNonNegativeNumber(s.reward, 'superOfferConfig.reward');
            if (!parsed.ok) return parsed;
            superOfferConfig.reward = Math.trunc(parsed.value);
        }

        if (hasS('gemsRequired')) {
            const parsed = toNonNegativeNumber(s.gemsRequired, 'superOfferConfig.gemsRequired');
            if (!parsed.ok) return parsed;
            superOfferConfig.gemsRequired = Math.trunc(parsed.value);
        }

        if (hasS('hoursGap') || hasS('gapMinutes')) {
            const rawGap = String(s.gapMinutes || s.hoursGap || '60').trim();
            superOfferConfig.hoursGap = rawGap;
            superOfferConfig.gapMinutes = rawGap;
        }

        if (hasS('limitType')) {
            superOfferConfig.limitType = String(s.limitType || 'hours').trim();
        }

        if (hasS('dailyLimit')) {
            superOfferConfig.dailyLimit = String(s.dailyLimit || '10').trim();
        }

        if (hasS('superOfferDailyLimit')) {
            superOfferConfig.superOfferDailyLimit = String(s.superOfferDailyLimit || '10').trim();
        }

        if (hasS('gameDailyLimit')) {
            superOfferConfig.gameDailyLimit = String(s.gameDailyLimit || '10-20').trim();
        }

        if (hasS('dailyGemsForInstall')) {
            const parsed = toNonNegativeNumber(s.dailyGemsForInstall, 'superOfferConfig.dailyGemsForInstall');
            if (!parsed.ok) return parsed;
            superOfferConfig.dailyGemsForInstall = Math.trunc(parsed.value);
        }

        if (hasS('gameGems')) {
            const parsed = toNonNegativeNumber(s.gameGems, 'superOfferConfig.gameGems');
            if (!parsed.ok) return parsed;
            superOfferConfig.gameGems = Math.trunc(parsed.value);
        }

        if (hasS('installGems')) {
            const parsed = toNonNegativeNumber(s.installGems, 'superOfferConfig.installGems');
            if (!parsed.ok) return parsed;
            superOfferConfig.installGems = Math.trunc(parsed.value);
        }

        if (hasS('adsRequired')) {
            const adsRequired = normalizeBooleanInput(s.adsRequired);
            if (adsRequired === null) return { ok: false, message: 'superOfferConfig.adsRequired must be boolean' };
            superOfferConfig.adsRequired = adsRequired;
        }

        if (hasS('initialUsageSeconds')) {
            const parsed = toNonNegativeNumber(s.initialUsageSeconds, 'superOfferConfig.initialUsageSeconds');
            if (parsed.ok) superOfferConfig.initialUsageSeconds = Math.max(10, Math.trunc(parsed.value));
        }

        if (hasS('installTask')) {
            const installTask = normalizeBooleanInput(s.installTask);
            if (installTask === null) return { ok: false, message: 'superOfferConfig.installTask must be boolean' };
            superOfferConfig.installTask = installTask;
        }

        if (hasS('gameInstallTaskTriggerLimit')) {
            superOfferConfig.gameInstallTaskTriggerLimit = String(s.gameInstallTaskTriggerLimit || '10-20').trim();
        }

        if (hasS('adType')) {
            superOfferConfig.adType = String(s.adType || 'rewarded').trim().toLowerCase();
        }

        if (hasS('installTaskMb')) {
            const parsed = toNonNegativeNumber(s.installTaskMb, 'superOfferConfig.installTaskMb');
            if (!parsed.ok) return parsed;
            superOfferConfig.installTaskMb = Math.trunc(parsed.value);
        }

        if (hasS('tutorialUrl')) {
            superOfferConfig.tutorialUrl = String(s.tutorialUrl || '').trim();
        }

        if (hasS('howToPlay')) {
            if (Array.isArray(s.howToPlay)) {
                superOfferConfig.howToPlay = s.howToPlay.map(item => String(item || '').trim()).filter(Boolean);
            } else if (typeof s.howToPlay === 'string') {
                superOfferConfig.howToPlay = s.howToPlay.split('\n').map(item => item.trim()).filter(Boolean);
            }
        }

        if (hasS('targetScores')) {
            if (Array.isArray(s.targetScores)) {
                superOfferConfig.targetScores = s.targetScores.map(item => parseInt(item)).filter(n => !isNaN(n) && n > 0);
            } else if (typeof s.targetScores === 'string') {
                superOfferConfig.targetScores = s.targetScores.split(',').map(item => parseInt(item.trim())).filter(n => !isNaN(n) && n > 0);
            }
            if (!superOfferConfig.targetScores || superOfferConfig.targetScores.length === 0) {
                superOfferConfig.targetScores = [10, 20, 30];
            }
        }
        if (hasS('superOfferVerificationEnabled')) {
            const superOfferVerificationEnabled = normalizeBooleanInput(s.superOfferVerificationEnabled);
            superOfferConfig.superOfferVerificationEnabled = superOfferVerificationEnabled !== null ? superOfferVerificationEnabled : true;
        }

        if (hasS('screenshotVerificationEnabled')) {
            const screenshotVerificationEnabled = normalizeBooleanInput(s.screenshotVerificationEnabled);
            superOfferConfig.screenshotVerificationEnabled = screenshotVerificationEnabled !== null ? screenshotVerificationEnabled : true;
        }

        if (hasS('activeMethod')) {
            const m = parseInt(s.activeMethod);
            if ([1, 2, 3, 4].includes(m)) {
                superOfferConfig.activeMethod = m;
                if (m === 1) {
                    superOfferConfig.installTask = false;
                    superOfferConfig.superOfferVerificationEnabled = false;
                    superOfferConfig.screenshotVerificationEnabled = false;
                } else if (m === 2) {
                    superOfferConfig.installTask = true;
                    superOfferConfig.superOfferVerificationEnabled = false;
                    superOfferConfig.screenshotVerificationEnabled = false;
                } else if (m === 3) {
                    superOfferConfig.installTask = true;
                    superOfferConfig.superOfferVerificationEnabled = true;
                    superOfferConfig.screenshotVerificationEnabled = false;
                } else if (m === 4) {
                    superOfferConfig.installTask = true;
                    superOfferConfig.superOfferVerificationEnabled = true;
                    superOfferConfig.screenshotVerificationEnabled = true;
                }
            }
        } else {
            // Infer activeMethod if not explicitly passed
            if (!superOfferConfig.superOfferVerificationEnabled && !superOfferConfig.installTask) {
                superOfferConfig.activeMethod = 1;
            } else if (!superOfferConfig.superOfferVerificationEnabled && superOfferConfig.installTask) {
                superOfferConfig.activeMethod = 2;
            } else if (superOfferConfig.superOfferVerificationEnabled && !superOfferConfig.screenshotVerificationEnabled) {
                superOfferConfig.activeMethod = 3;
            } else {
                superOfferConfig.activeMethod = 4;
            }
        }

        if (hasS('screenshotApprovalType')) {
            superOfferConfig.screenshotApprovalType = String(s.screenshotApprovalType || 'manual').trim();
        }

        if (hasS('screenshotAutoApproveDelay')) {
            superOfferConfig.screenshotAutoApproveDelay = String(s.screenshotAutoApproveDelay || '10-15').trim();
        }

        if (hasS('screenshotCoins')) {
            const parsed = toNonNegativeNumber(s.screenshotCoins, 'superOfferConfig.screenshotCoins');
            if (parsed.ok) superOfferConfig.screenshotCoins = Math.trunc(parsed.value);
        }

        if (hasS('usageSteps')) {
            if (Array.isArray(s.usageSteps)) {
                superOfferConfig.usageSteps = s.usageSteps.map((step, idx) => {
                    const sec = parseInt(step.cooldownSeconds !== undefined ? step.cooldownSeconds : step.hoursGap) || 0;
                    const usageSec = parseInt(step.usageSeconds !== undefined ? step.usageSeconds : (parseInt(step.minutes) ? parseInt(step.minutes) * 60 : 300)) || 300;
                    const mins = usageSec >= 60 ? Math.round(usageSec / 60) : Math.ceil(usageSec / 60);
                    return {
                        stepNumber: idx + 1,
                        name: String(step.name || `Use App Step ${idx + 1}`).trim(),
                        minutes: mins,
                        usageSeconds: usageSec,
                        coins: parseInt(step.coins) || 0,
                        cooldownSeconds: sec,
                        hoursGap: sec,
                    };
                }).filter(st => (st.usageSeconds > 0 || st.minutes > 0) || st.coins > 0);
            }
        }

        updates.superOfferConfig = superOfferConfig;
    }

    if (has('updateConfig')) {
        if (!isPlainObject(payload.updateConfig)) {
            return { ok: false, message: 'updateConfig must be an object' };
        }

        const updateConfig = {};
        const u = payload.updateConfig;
        const hasU = (key) => Object.prototype.hasOwnProperty.call(u, key);

        if (hasU('currentBuildNumber')) {
            const parsed = toNonNegativeNumber(u.currentBuildNumber, 'updateConfig.currentBuildNumber');
            if (!parsed.ok) return parsed;
            updateConfig.currentBuildNumber = Math.trunc(parsed.value);
        }

        if (hasU('currentVersion')) {
            updateConfig.currentVersion = String(u.currentVersion || '').trim();
        }

        if (hasU('message')) {
            updateConfig.message = String(u.message || '').trim();
        }

        updates.updateConfig = updateConfig;
    }

    if (has('urlConfig')) {
        if (!isPlainObject(payload.urlConfig)) {
            return { ok: false, message: 'urlConfig must be an object' };
        }

        const urlConfig = {};
        for (const [rawKey, rawValue] of Object.entries(payload.urlConfig)) {
            const key = String(rawKey || '').trim();
            if (!key) {
                return { ok: false, message: 'urlConfig keys cannot be empty' };
            }
            urlConfig[key] = rawValue === null || rawValue === undefined
                ? ''
                : String(rawValue).trim();
        }

        updates.urlConfig = urlConfig;
    }

    if (has('welcomePopup')) {
        if (!isPlainObject(payload.welcomePopup)) {
            return { ok: false, message: 'welcomePopup must be an object' };
        }

        const welcomePopup = {};
        const wp = payload.welcomePopup;
        const hasWp = (key) => Object.prototype.hasOwnProperty.call(wp, key);

        if (hasWp('enabled')) {
            const enabled = normalizeBooleanInput(wp.enabled);
            if (enabled === null) return { ok: false, message: 'welcomePopup.enabled must be boolean' };
            welcomePopup.enabled = enabled;
        }

        if (hasWp('imageUrl')) {
            welcomePopup.imageUrl = String(wp.imageUrl || '').trim();
        }

        if (hasWp('title')) {
            welcomePopup.title = String(wp.title || '').trim();
        }

        if (hasWp('message')) {
            welcomePopup.message = String(wp.message || '').trim();
        }

        if (hasWp('buttonName')) {
            welcomePopup.buttonName = String(wp.buttonName || '').trim();
        }

        if (hasWp('buttonClickUrl')) {
            welcomePopup.buttonClickUrl = String(wp.buttonClickUrl || '').trim();
        }

        if (hasWp('cap')) {
            const parsed = toNonNegativeNumber(wp.cap, 'welcomePopup.cap');
            if (!parsed.ok) return parsed;
            welcomePopup.cap = Math.trunc(parsed.value);
        }

        updates.welcomePopup = welcomePopup;
    }

    if (has('howToUseConfig')) {
        if (!isPlainObject(payload.howToUseConfig)) {
            return { ok: false, message: 'howToUseConfig must be an object' };
        }

        const howToUseConfig = {};
        const h = payload.howToUseConfig;

        const validKeys = [
            'dailyTask', 'dailyChallenge', 'battleArena', 'hotOffer', 'giveaway', 'offerwall', 'survey',
            'playGames', 'readEarn', 'watchEarn', 'playWin',
            'promoCode', 'referral', 'leaderboard', 'aToZ'
        ];

        for (const key of validKeys) {
            if (Object.prototype.hasOwnProperty.call(h, key)) {
                const item = h[key];
                if (isPlainObject(item)) {
                    const entry = {};
                    entry.enabled = normalizeBooleanInput(item.enabled) === true;
                    entry.title = String(item.title || '').trim();
                    entry.tutorialUrl = String(item.tutorialUrl || '').trim();

                    if (Array.isArray(item.steps)) {
                        entry.steps = item.steps.map(step => String(step || '').trim()).filter(Boolean);
                    } else if (typeof item.steps === 'string') {
                        entry.steps = item.steps.split('\n').map(step => step.trim()).filter(Boolean);
                    } else {
                        entry.steps = [];
                    }
                    howToUseConfig[key] = entry;
                }
            }
        }

        updates.howToUseConfig = howToUseConfig;
    }

    if (has('homeBanners')) {
        if (!Array.isArray(payload.homeBanners)) {
            return { ok: false, message: 'homeBanners must be an array' };
        }

        const homeBanners = [];
        for (const item of payload.homeBanners) {
            if (isPlainObject(item)) {
                homeBanners.push({
                    imageUrl: String(item.imageUrl || '').trim(),
                    clickUrl: String(item.clickUrl || '').trim(),
                    enabled: normalizeBooleanInput(item.enabled) !== false,
                });
            }
        }

        updates.homeBanners = homeBanners;
    }

    if (has('screenBanners')) {
        if (!isPlainObject(payload.screenBanners)) {
            return { ok: false, message: 'screenBanners must be an object' };
        }

        const screenBanners = {};
        for (const [screenKey, item] of Object.entries(payload.screenBanners)) {
            if (isPlainObject(item)) {
                screenBanners[screenKey] = {
                    imageUrl: String(item.imageUrl || '').trim(),
                    clickUrl: String(item.clickUrl || '').trim(),
                    enabled: normalizeBooleanInput(item.enabled) !== false,
                };
            }
        }

        updates.screenBanners = screenBanners;
    }

    return { ok: true, updates };
}

function normalizeOffersSettingsPayload(payload = {}) {
    if (!isPlainObject(payload)) {
        return { ok: false, message: 'offersSettings must be an object' };
    }

    const normalized = {};

    for (const [provider, raw] of Object.entries(payload)) {
        if (!isPlainObject(raw)) continue;

        const enabled = normalizeBooleanInput(raw.enabled);
        if (enabled === null) {
            return { ok: false, message: `${provider}.enabled must be boolean` };
        }

        const rank = Number(raw.rank);

        if (!Number.isFinite(rank) || rank < 0) {
            return { ok: false, message: `${provider}.rank must be number >= 0` };
        }

        const appId = String(raw.appId || '').trim();
        const secretKey = String(raw.secretKey || '').trim();
        const token = String(raw.token || '').trim();
        const appKey = String(raw.appKey || '').trim();
        const url = String(raw.url || '').trim();
        const customName = String(raw.customName || '').trim();
        const iconUrl = String(raw.iconUrl || '').trim();
        const category = String(raw.category || '').trim();

        normalized[provider] = {
            enabled,
            rank: Math.trunc(rank),
            appId,
            secretKey,
            token,
            appKey,
            url,
            customName,
            iconUrl,
            category,
        };
    }

    return { ok: true, offersSettings: normalized };
}

function normalizeReferralSettingsPayload(payload = {}) {
    if (!isPlainObject(payload)) {
        return { ok: false, message: 'referralSettings must be an object' };
    }

    const levels = ['firstLevel', 'secondLevel', 'thirdLevel'];
    const normalized = {};

    for (const level of levels) {
        const levelValue = payload[level];
        if (!isPlainObject(levelValue)) {
            normalized[level] = {};
            continue;
        }

        normalized[level] = {};
        for (const [category, value] of Object.entries(levelValue)) {
            const num = Number(value);
            if (!Number.isFinite(num) || num < 0) {
                return { ok: false, message: `${level}.${category} must be number >= 0` };
            }
            normalized[level][category] = num;
        }
    }

    // Referral Bonus, Levels Mode & Missions Normalization
    normalized.rewardMode = ['all', 'taskWise'].includes(payload.rewardMode) ? payload.rewardMode : 'all';
    normalized.allCommissionPercent = Number.isFinite(Number(payload.allCommissionPercent))
        ? Math.max(0, Math.min(100, Number(payload.allCommissionPercent)))
        : 10;
    normalized.referrerBonusCoins = Number.isFinite(Number(payload.referrerBonusCoins))
        ? Math.max(0, Math.round(Number(payload.referrerBonusCoins)))
        : 0;
    normalized.referrerBonusCondition = ['none', 'any_task', 'super_offer', 'daily_task', 'watch_earn', 'read_earn', 'play_games', 'offerwall'].includes(payload.referrerBonusCondition)
        ? payload.referrerBonusCondition
        : 'none';
    normalized.referredRewardEnabled = payload.referredRewardEnabled === true;
    normalized.referredRewardCoins = Number(payload.referredRewardCoins) >= 0 ? Number(payload.referredRewardCoins) : 0;
    normalized.missionsEnabled = payload.missionsEnabled === true;
    normalized.missionsSubtitle = typeof payload.missionsSubtitle === 'string'
        ? payload.missionsSubtitle.trim()
        : (typeof payload.missionsDescription === 'string' ? payload.missionsDescription.trim() : '');
    normalized.missions = [];
    if (Array.isArray(payload.missions)) {
        for (const m of payload.missions) {
            const target = Number(m.target);
            const reward = Number(m.reward);
            const enabled = m.enabled !== false;
            const title = String(m.title || `Invite ${target} Friends`).trim();
            const criteriaType = ['direct', 'withdrawal', 'offerwall', 'survey', 'super_offer'].includes(m.criteriaType)
                ? m.criteriaType
                : 'direct';
            const criteriaCount = Number(m.criteriaCount) > 0 ? Math.max(1, Math.round(Number(m.criteriaCount))) : 1;

            if (Number.isFinite(target) && target > 0 && Number.isFinite(reward) && reward >= 0) {
                normalized.missions.push({
                    id: String(m.id || `mission_${target}_${criteriaType}`),
                    target,
                    reward,
                    criteriaType,
                    criteriaCount: criteriaType === 'direct' ? 1 : criteriaCount,
                    enabled,
                    title
                });
            }
        }
        normalized.missions.sort((a, b) => a.target - b.target);
    }

    return { ok: true, referralSettings: normalized };
}

async function getFirestoreForApp(req, selectedApp) {
    const appName = String(selectedApp || '').trim();
    if (!appName) {
        return { ok: false, status: 400, message: 'App not selected' };
    }

    const selectedService =
        (Array.isArray(req.firebaseServices) ? req.firebaseServices : []).find(s => s.appName === appName)
        || await FirebaseService.findOne({ appName });

    const serviceAccount = selectedService?.serviceAccount;
    if (!serviceAccount) {
        return { ok: false, status: 404, message: 'Service account not found' };
    }

    try {
        const firebase = getOrInitFirebase(appName, serviceAccount);
        return {
            ok: true,
            appName,
            db: firebase.firestore(),
            firebase,
        };
    } catch (err) {
        console.warn('⚠️ Firestore API disabled/unavailable, using MongoDB mode:', err.message);
        return {
            ok: false,
            status: 500,
            message: 'Firestore API disabled, MongoDB mode active.',
        };
    }
}

// LOGIN
router.get('/login', (_, res) => {
    res.render('login');
});

router.post('/login', async (req, res) => {
    try {
        await connectMongo();
        const { email, password } = req.body;

        const admin = await Admin.findOne({ email });
        if (!admin) return res.json({
            success: false,
            message: 'Invalid email or password'
        });

        const match = await bcrypt.compare(password, admin.password);
        if (!match) return res.json({
            success: false,
            message: 'Invalid email or password'
        });

        const token = jwt.sign({ id: admin._id }, process.env.JWT_SECRET, { expiresIn: '30d' });
        res.cookie('adminToken', token, { httpOnly: true, maxAge: 30 * 24 * 60 * 60 * 1000 });
        res.json({
            success: true,
            message: 'Login successful',
            redirectUrl: '/'
        });
    } catch (err) {
        console.log(err);
        return res.json({
            success: false,
            message: 'Internal server error'
        });
    }
});

// DASHBOARD
router.get('/', adminAuth, (req, res) => {
    const { name, email } = req.admin;
    const firebaseServices = req.firebaseServices;

    const activeApp = firebaseServices.find(app => app.prioritized) || firebaseServices[0];

    if (activeApp?.appName && activeApp?.serviceAccount) {
        getOrInitFirebase(activeApp.appName, activeApp.serviceAccount);
    }

    res.render('dashboard', {
        name,
        email,
        photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
        firebaseServices,
    });
});

// LOGOUT
router.get('/logout', (_, res) => {
    res.clearCookie('adminToken');
    res.redirect('/login');
});

// ADMIN MANAGER LIST
router.get('/admin-manager', adminAuth, checkSuperAdmin, async (req, res) => {
    try {
        await connectMongo();
        const admins = await Admin.find({}).sort({ createdAt: -1 });
        const { name, email } = req.admin;
        res.render('admin-manager', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices: req.firebaseServices,
            admins
        });
    } catch (err) {
        console.error('Error rendering admin manager:', err);
        res.status(500).send('Internal Server Error');
    }
});

// ADD ADMIN
router.post('/admin-manager/add', adminAuth, checkSuperAdmin, async (req, res) => {
    try {
        await connectMongo();
        const { name, email, password, role, permissions } = req.body;

        if (!name || !email || !password) {
            return res.json({ success: false, message: 'All fields are required.' });
        }
        if (password.length < 6) {
            return res.json({ success: false, message: 'Password must be at least 6 characters.' });
        }

        const existing = await Admin.findOne({ email });
        if (existing) {
            return res.json({ success: false, message: 'Admin with this email already exists.' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        const newAdmin = new Admin({
            name,
            email,
            password: hashedPassword,
            role,
            permissions: role === 'superadmin' ? {} : permissions
        });

        await newAdmin.save();
        res.json({ success: true, message: 'Admin added successfully.' });
    } catch (err) {
        console.error('Error adding admin:', err);
        res.json({ success: false, message: 'Internal server error.' });
    }
});

// EDIT ADMIN
router.post('/admin-manager/edit/:id', adminAuth, checkSuperAdmin, async (req, res) => {
    try {
        await connectMongo();
        const { name, password, role, permissions } = req.body;
        const adminId = req.params.id;

        const admin = await Admin.findById(adminId);
        if (!admin) {
            return res.json({ success: false, message: 'Admin not found.' });
        }

        admin.name = name;
        admin.role = role;
        admin.permissions = role === 'superadmin' ? {} : permissions;

        if (password) {
            if (password.length < 6) {
                return res.json({ success: false, message: 'Password must be at least 6 characters.' });
            }
            admin.password = await bcrypt.hash(password, 10);
        }

        await admin.save();
        res.json({ success: true, message: 'Admin updated successfully.' });
    } catch (err) {
        console.error('Error editing admin:', err);
        res.json({ success: false, message: 'Internal server error.' });
    }
});

// DELETE ADMIN
router.post('/admin-manager/delete/:id', adminAuth, checkSuperAdmin, async (req, res) => {
    try {
        await connectMongo();
        const adminId = req.params.id;

        // Prevent self deletion
        if (String(adminId) === String(req.admin._id)) {
            return res.json({ success: false, message: 'You cannot delete yourself.' });
        }

        const deleted = await Admin.findByIdAndDelete(adminId);
        if (!deleted) {
            return res.json({ success: false, message: 'Admin not found.' });
        }

        res.json({ success: true, message: 'Admin deleted successfully.' });
    } catch (err) {
        console.error('Error deleting admin:', err);
        res.json({ success: false, message: 'Internal server error.' });
    }
});

// USER ACTIVITY PAGE
router.get('/user-activity', adminAuth, checkPermission('userActivity'), async (req, res) => {
    const { name, email } = req.admin;
    const firebaseServices = req.firebaseServices;

    res.render('user-activity', {
        name,
        email,
        photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
        firebaseServices,
    });
});

// UNUSUAL ACTIVITY PAGE
router.get('/unusual-activity', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    const { name, email } = req.admin;
    const firebaseServices = req.firebaseServices;

    res.render('unusual-activity', {
        name,
        email,
        photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
    });
});

const { getRedisStatus, flushRedisCache, deleteRedisKey } = require('../admin/middlewares/antiReplayMiddleware');
const RedisConfig = require('../admin/models/redisConfig');

// REDIS MANAGEMENT PAGE
router.get(['/redis-manage', '/admin/redis-manage'], adminAuth, async (req, res) => {
    const { name, email } = req.admin;
    await connectMongo();
    let redisConfig = await RedisConfig.findOne({ key: 'redisConfig' }).lean();
    if (!redisConfig) {
        redisConfig = {
            isEnabled: cacheService.isRedisActive(),
            globalTtlSeconds: cacheService.getTtl('global'),
            leaderboardTtlSeconds: cacheService.getTtl('leaderboard')
        };
    }
    const status = await getRedisStatus();
    res.render('redis-manage', {
        name,
        email,
        admin: req.admin,
        photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
        redisConfig,
        isRedisActive: cacheService.isRedisActive(),
        initialKeys: status.keys || [],
        initialKeysCount: status.keysCount || 0
    });
});

// REDIS STATUS API
router.get(['/api/admin/redis-status', '/redis-status', '/admin/redis-status'], adminAuth, async (req, res) => {
    try {
        const status = await getRedisStatus();
        res.json({ success: true, ...status });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

// REDIS KEY VALUE INSPECTOR API
router.get(['/api/admin/redis-key-value', '/redis-key-value', '/admin/redis-key-value'], adminAuth, async (req, res) => {
    try {
        const key = req.query?.key;
        if (!key) {
            return res.status(400).json({ success: false, message: 'Missing key parameter' });
        }

        const redisClient = cacheService.getClient();
        if (!redisClient) {
            return res.json({
                success: true,
                key,
                type: 'MEMORY',
                ttl: -1,
                value: 'In-Memory fallback active. Value not directly readable.'
            });
        }

        const [type, ttl] = await Promise.all([
            redisClient.type(key).catch(() => 'string'),
            redisClient.ttl(key).catch(() => -1)
        ]);

        let rawVal = null;
        if (type === 'string') {
            rawVal = await redisClient.get(key);
        } else if (type === 'zset') {
            rawVal = await redisClient.zrevrange(key, 0, 99, 'WITHSCORES');
        } else if (type === 'hash') {
            rawVal = await redisClient.hgetall(key);
        } else if (type === 'set') {
            rawVal = await redisClient.smembers(key);
        } else if (type === 'list') {
            rawVal = await redisClient.lrange(key, 0, 99);
        } else {
            rawVal = await redisClient.get(key).catch(() => '');
        }

        return res.json({
            success: true,
            key,
            type: (type || 'string').toUpperCase(),
            ttl: ttl !== undefined ? Number(ttl) : -1,
            value: rawVal
        });
    } catch (e) {
        console.error('❌ Error inspecting Redis key:', e);
        return res.status(500).json({ success: false, message: e.message });
    }
});

// REDIS TOGGLE API (ON/OFF Switch)
router.post(['/api/admin/redis-toggle', '/redis-toggle', '/admin/redis-toggle'], adminAuth, async (req, res) => {
    try {
        const fs = require('fs');
        const path = require('path');
        const { enabled } = req.body;
        const isEnabled = enabled === true || enabled === 'true' || enabled === 1;

        // Toggle in runtime cacheService
        cacheService.toggleRedis(isEnabled);

        // Persist in Mongo
        await connectMongo();
        const configDoc = await RedisConfig.findOneAndUpdate(
            { key: 'redisConfig' },
            { $set: { isEnabled, updatedAt: new Date() } },
            { new: true, upsert: true }
        );

        // Persist in .env file
        try {
            const envPath = path.resolve(__dirname, '../../.env');
            if (fs.existsSync(envPath)) {
                let envContent = fs.readFileSync(envPath, 'utf8');
                if (envContent.includes('REDIS_ENABLED=')) {
                    envContent = envContent.replace(/REDIS_ENABLED=.*/g, `REDIS_ENABLED=${isEnabled ? 'true' : 'false'}`);
                } else {
                    envContent += `\nREDIS_ENABLED=${isEnabled ? 'true' : 'false'}\n`;
                }
                fs.writeFileSync(envPath, envContent, 'utf8');
            }
        } catch (envErr) {
            console.warn('⚠️ Could not update .env file:', envErr.message);
        }

        const status = await getRedisStatus();

        res.json({
            success: true,
            message: isEnabled ? 'Redis enabled successfully!' : 'Redis disabled (switched to In-Memory fallback)',
            isRedisActive: cacheService.isRedisActive(),
            config: cacheService.getConfig(),
            keysCount: status.keysCount || 0,
            keys: status.keys || []
        });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

// REDIS CONFIG UPDATE API (TTL & Settings)
router.post(['/api/admin/redis-config', '/redis-config', '/admin/redis-config'], adminAuth, async (req, res) => {
    try {
        const {
            isEnabled,
            globalTtlSeconds,
            leaderboardTtlSeconds
        } = req.body;

        await connectMongo();
        const updateData = { updatedAt: new Date() };

        if (typeof isEnabled !== 'undefined') {
            updateData.isEnabled = isEnabled === true || isEnabled === 'true';
            cacheService.toggleRedis(updateData.isEnabled);
        }
        if (typeof globalTtlSeconds !== 'undefined') {
            updateData.globalTtlSeconds = Math.max(5, parseInt(globalTtlSeconds, 10) || 300);
        }
        if (typeof leaderboardTtlSeconds !== 'undefined') {
            updateData.leaderboardTtlSeconds = Math.max(5, parseInt(leaderboardTtlSeconds, 10) || 60);
        }

        const configDoc = await RedisConfig.findOneAndUpdate(
            { key: 'redisConfig' },
            { $set: updateData },
            { new: true, upsert: true }
        );

        cacheService.updateConfig(configDoc.toObject ? configDoc.toObject() : configDoc);
        const status = await getRedisStatus();

        res.json({
            success: true,
            message: 'Redis TTL settings updated successfully!',
            config: cacheService.getConfig(),
            keysCount: status.keysCount || 0,
            keys: status.keys || []
        });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

// REDIS FLUSH/RESET API
router.post(['/api/admin/redis-flush', '/redis-flush', '/admin/redis-flush'], adminAuth, async (req, res) => {
    try {
        await flushRedisCache();
        res.json({ success: true, message: 'Crazyreward Redis & RAM cache reset successfully' });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

// REDIS DELETE SINGLE KEY API
router.post(['/api/admin/redis-delete-key', '/redis-delete-key', '/admin/redis-delete-key'], adminAuth, async (req, res) => {
    try {
        const { key } = req.body;
        if (key) {
            await deleteRedisKey(key);
        }
        res.json({ success: true, message: 'Key deleted' });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

// CONFIRM PAYMENTS PAGE
router.get('/confirm-payments', adminAuth, checkPermission('payouts'), (req, res) => {
    const { name, email } = req.admin;
    const firebaseServices = req.firebaseServices;

    res.render('payout/manage', {
        name,
        email,
        photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
        firebaseServices,
    });
});

// PENDING PAYOUT REQUESTS
router.post('/pending-payout-requests', adminAuth, checkPermission('payouts'), async (req, res) => {
    try {
        const selectedApp = String(req.body?.selectedApp || '').trim();
        const dbState = await getFirestoreForApp(req, selectedApp);

        if (!dbState.ok) {
            return res.status(dbState.status).json({
                success: false,
                message: dbState.message,
            });
        }

        await connectMongo();
        const records = await PayoutRecord.find({
            status: { $in: ['pending', 'inprogress', 'in_progress'] }
        }).sort({ timestamp: 1, createdAt: 1 }).lean();

        const requests = records.map((data) => {
            const methodName = String(data.methodName || '').trim();
            const methodPayload = data.methodDetails || {};

            return {
                id: data.orderId,
                status: String(data.status || ''),
                orderId: String(data.orderId || ''),
                txnId: String(data.txnId || ''),
                userId: String(data.userId || ''),
                email: String(data.email || ''),
                methodName,
                amount: Number(data.amount ?? 0) || 0,
                coins: Number(data.coins ?? 0) || 0,
                methodData: methodPayload,
                timestamp: toIsoDate(data.timestamp || data.createdAt),
                processTimestamp: toIsoDate(data.processTimestamp),
            };
        }).sort((a, b) => {
            const ta = a.timestamp ? new Date(a.timestamp).getTime() : 0;
            const tb = b.timestamp ? new Date(b.timestamp).getTime() : 0;
            return ta - tb;
        });

        return res.json({
            success: true,
            app: dbState.appName,
            count: requests.length,
            requests,
        });
    } catch (err) {
        console.error('❌ Pending payout fetch error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch pending payout requests',
        });
    }
});

// APPXO PAYOUT POSTBACK
router.post('/payout-postback', async (req, res) => {
    try {
        await connectMongo();

        const firebaseServices = await FirebaseService.find(
            {},
            { _id: 0, appName: 1, serviceAccount: 1 },
        );

        return handlePayoutPostback(req, res, {
            firebaseServices,
            FieldValue,
        });
    } catch (err) {
        console.error('❌ Payout postback error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to process payout postback',
        });
    }
});

// HANDLE PAYOUT ACTIONS (REJECT ACTIVE, PROCEED PENDING)
router.post('/handle-payout', adminAuth, checkPermission('payouts'), async (req, res) => {
    try {
        const requestedUserId = String(req.body?.userId || '').trim();
        const orderId = String(req.body?.orderId || '').trim();
        const action = String(req.body?.action || '').trim().toLowerCase();
        const app = String(req.body?.app || req.body?.selectedApp || '').trim();

        if (!orderId || !app || !['proceed', 'reject', 'mark_success', 'success', 'delete'].includes(action)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid parameters',
            });
        }

        const dbState = await getFirestoreForApp(req, app);
        if (!dbState.ok) {
            return res.status(dbState.status).json({
                success: false,
                message: dbState.message,
            });
        }

        const db = dbState.db;
        const now = new Date();

        await connectMongo();
        const payoutData = await PayoutRecord.findOne({ orderId }).lean();

        if (!payoutData) {
            return res.status(404).json({
                success: false,
                message: 'Payout record not found',
            });
        }

        if (action === 'delete') {
            await PayoutRecord.deleteOne({ orderId });
            try {
                await PayoutHistory.deleteOne({ orderId });
            } catch (delErr) {
                console.warn('⚠️ Could not delete PayoutHistory:', delErr?.message);
            }
            return res.json({
                success: true,
                status: 'deleted',
                message: 'Payout request deleted successfully.',
            });
        }

        // 🛡️ Atomic Status Lock to completely prevent Double Refund / Race Conditions
        const lockedPayout = await PayoutRecord.findOneAndUpdate(
            { orderId, status: { $regex: /^pending$/i } },
            { $set: { status: 'processing_lock' } },
            { new: true }
        );

        if (!lockedPayout) {
            return res.status(400).json({
                success: false,
                message: 'Payment request is already processed or currently processing.',
            });
        }

        if (action === 'proceed') {
            return handlePayoutRoute(req, res, { db, dbState, payoutRef: null, payoutData: lockedPayout, orderId, FieldValue });
        }

        const userId = requestedUserId || String(payoutData.userId || '').trim();
        if (!userId) {
            return res.status(400).json({
                success: false,
                message: 'User ID missing for payout request',
            });
        }

        const redeemCode = String(req.body?.redeemCode || req.body?.code || req.body?.giftCode || '').trim();
        const refId = String(req.body?.refId || req.body?.referenceId || req.body?.txnId || '').trim();

        if (action === 'mark_success' || action === 'success') {
            const updateFields = { status: 'success', processTimestamp: now };
            if (redeemCode) {
                updateFields.redeemCode = redeemCode;
                updateFields.giftCode = redeemCode;
            }
            if (refId) {
                updateFields.refId = refId;
                updateFields.referenceId = refId;
                updateFields.txnId = refId;
            }

            try {
                await PayoutRecord.updateOne(
                    { orderId },
                    { $set: updateFields }
                );
            } catch (mErr) {
                console.error('🔥 Failed to update PayoutRecord in MongoDB:', mErr);
            }

            try {
                await PayoutHistory.updateOne(
                    { orderId },
                    { $set: updateFields }
                );
            } catch (mErr) {
                console.error('🔥 Failed to update PayoutHistory in MongoDB:', mErr);
            }

            try {
                let notifyBody = `Your payout request of ₹${payoutData.amount || ''} has been completed!`;
                if (redeemCode && refId) {
                    notifyBody = `Your payout request of ₹${payoutData.amount || ''} is completed! Code: ${redeemCode} | Ref ID: ${refId}`;
                } else if (redeemCode) {
                    notifyBody = `Your payout request of ₹${payoutData.amount || ''} is completed! Code: ${redeemCode}`;
                } else if (refId) {
                    notifyBody = `Your payout request of ₹${payoutData.amount || ''} is completed! Ref ID: ${refId}`;
                }

                await sendNotificationViaApi({
                    title: 'Redeem Successful',
                    body: notifyBody,
                    userId: userId,
                    type: 'payment',
                });
            } catch (notifyErr) {
                console.warn('⚠️ Success notification failed:', notifyErr?.message || notifyErr);
            }

            return res.json({
                success: true,
                status: 'success',
                message: 'Payout marked as completed successfully!',
            });
        }

        await connectMongo();
        const userSnap = await User.findOne({ userId }).lean();

        if (!userSnap) {
            return res.status(404).json({
                success: false,
                message: 'User not found',
            });
        }

        const rejectReason = String(req.body?.reason || req.body?.rejectReason || '').trim();
        const refundCoinsRaw = Number(payoutData.coins);
        const refundCoins = Number.isFinite(refundCoinsRaw) ? refundCoinsRaw : 0;

        if (refundCoins > 0) {
            await User.updateOne({ userId }, { $inc: { coins: refundCoins } });
        }

        const failureMessage = rejectReason ? `Redeem Failed: ${rejectReason}` : 'Redeem Failed';

        try {
            await PayoutRecord.updateOne(
                { orderId },
                {
                    $set: {
                        status: 'failed',
                        message: failureMessage,
                        rejectReason: rejectReason || '',
                        failureReason: rejectReason || '',
                        processTimestamp: now,
                    }
                }
            );
        } catch (mErr) {
            console.error('🔥 Failed to update PayoutRecord in MongoDB:', mErr);
        }

        try {
            await PayoutHistory.updateOne(
                { orderId },
                {
                    $set: {
                        status: 'failed',
                        message: failureMessage,
                        rejectReason: rejectReason || '',
                        failureReason: rejectReason || '',
                        processTimestamp: now,
                    }
                }
            );
        } catch (mErr) {
            console.error('🔥 Failed to update PayoutHistory in MongoDB:', mErr);
        }

        try {
            const notifyBody = rejectReason
                ? `Redeem Declined: ${rejectReason}. Coins refunded.`
                : 'Redeem Declined. Refund has been issued.';

            await sendNotificationViaApi({
                title: 'Redeem Declined',
                body: notifyBody,
                userId: userId,
                type: 'payment',
                data: {
                    type: 'payment',
                    status: 'failed',
                    reason: rejectReason || '',
                }
            });
        } catch (notifyErr) {
            console.warn('⚠️ Rejection notification failed:', notifyErr?.message || notifyErr);
        }

        return res.json({
            success: true,
            status: 'failed',
            message: rejectReason
                ? `Payout rejected (${rejectReason}) and coins refunded successfully.`
                : 'Payout rejected and coins refunded successfully.',
        });
    } catch (err) {
        console.error('❌ Handle payout error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to handle payout request',
        });
    }
});

cron.schedule('*/1 * * * *', async () => {
    console.log('⏰ Running auto payout job...');

    try {
        await connectMongo();

        const firebaseServices = await FirebaseService.find(
            {},
            { _id: 0, appName: 1, serviceAccount: 1 }
        );

        for (const service of firebaseServices) {
            const { appName, serviceAccount } = service;

            if (!appName || !serviceAccount) continue;

            const firebase = getOrInitFirebase(appName, serviceAccount);
            const db = firebase.firestore();

            try {
                await connectMongo();
                const autoMethodsDocs = await WalletCatalog.find({
                    appName,
                    autoPayment: true
                }).select('methodId').lean();

                const autoMethods = autoMethodsDocs.map(doc => doc.methodId);
                if (!autoMethods.length) continue;

                const payoutSnap = await PayoutRecord.find({
                    appName,
                    status: 'pending',
                    methodName: { $in: autoMethods }
                }).limit(5).lean();

                for (const doc of payoutSnap) {
                    let statusCode = null;

                    const dummyRes = {
                        status: (code) => {
                            statusCode = code;
                            return dummyRes;
                        },
                        send: (data) => {
                            console.log('res.send:', data);
                        },
                        json: (data) => {
                            console.log('res.json:', data);
                        },
                        redirect: (url) => {
                            console.log('res.redirect:', url);
                        }
                    };

                    try {
                        await handlePayoutRoute(null, dummyRes, {
                            db,
                            dbState: { appName, firebase },
                            payoutRef: null,
                            payoutData: doc,
                            orderId: doc.orderId,
                            FieldValue,
                        });

                        console.log(`✅ Payout processed: ${appName} - ${doc.orderId}`);

                    } catch (err) {
                        console.error(
                            `❌ Payout error: ${appName} - ${doc.id}`,
                            err
                        );
                    }
                }

            } catch (err) {
                console.error(`❌ Error processing ${appName}:`, err);
            }
        }

        console.log('🏁 Auto payout job finished');

    } catch (err) {
        console.error('🔥 Auto payout cron error:', err);
    }
});

// Unusual Activity Detection Cron (runs every hour at :30)
cron.schedule('30 * * * *', async () => {
    console.log('⏰ Starting unusual activity scan...');

    if (process.env.NODE_ENV === 'debug') {
        console.log('⚠️ Skipping unusual activity scan in debug mode');
        return;
    }

    try {
        await connectMongo();

        const firebaseServices = await FirebaseService.find(
            {},
            { _id: 0, appName: 1, serviceAccount: 1 }
        );

        const todayStart = getTodayStartIST();
        const todayKey = DateTime.now().setZone('Asia/Kolkata').toFormat('yyyy-MM-dd');

        for (const service of firebaseServices) {
            const { appName, serviceAccount } = service;
            if (!appName || !serviceAccount) continue;

            try {
                await connectMongo();
                const appDataDoc = await AppData.findOne({ appName }).lean();
                const appData = appDataDoc || {};

                // a) Read & Earn logs (last 24h)
                const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
                const readEarnUsers = await ReadEarnLogs.distinct('userId', {
                    appName,
                    createdAt: { $gte: twentyFourHoursAgo }
                });
                readEarnUsers.forEach(id => activeUserIds.add(id));

                // b) Watch & Earn / Daily Task completions (today)
                const postbackUsers = await PostbackLogs.distinct('userId', {
                    appName,
                    completedAt: { $gte: todayStart }
                });
                postbackUsers.forEach(id => activeUserIds.add(id));

                // c) Game Play logs (today)
                let gamePlayUsers = [];
                try {
                    gamePlayUsers = await GamePlayLogs.distinct('userId', {
                        dayKey: todayKey
                    });
                } catch (e) { }
                gamePlayUsers.forEach(id => activeUserIds.add(id));



                // e) Users with withdrawals today
                try {
                    const withdrawalsMongo = await PayoutRecord.find({
                        appName,
                        status: 'success',
                        createdAt: { $gte: todayStart }
                    }).lean();
                    withdrawalsMongo.forEach(doc => {
                        if (doc.userId) activeUserIds.add(doc.userId);
                    });
                } catch (wErr) { }


                const candidateIds = Array.from(activeUserIds).filter(Boolean);
                console.log(`Scanning ${candidateIds.length} active/potential abusers for app: ${appName}`);

                // Load static configurations once outside the user loop
                const games = await PlayGames.find({ enabled: true }).lean();
                const tasks = await DailyTask.find({ offerType: 'DailyTask' }).select('offerId offerName dailyReset').lean();
                const taskMap = {};
                for (const task of tasks) {
                    taskMap[task.offerId] = task;
                }
                const readEarnConfig = await ReadEarn.findOne({}).sort({ updatedAt: -1 }).lean();
                const readEarnLimit = readEarnConfig ? (readEarnConfig.limits || 5) : 5;

                let userDocsMap = {};
                if (candidateIds.length > 0) {
                    try {
                        const usersList = await User.find({ userId: { $in: candidateIds } }).lean();
                        usersList.forEach(u => {
                            userDocsMap[u.userId] = u;
                        });
                    } catch (fsErr) {
                        console.error("Error fetching user documents in bulk:", fsErr);
                    }
                }

                // Get currently flagged suspicious userIds to avoid redundant findOneAndDelete operations
                const existingSuspicious = await SuspiciousActivity.distinct('userId', { appName });
                const existingSuspiciousSet = new Set(existingSuspicious);

                // Bulk query and count successful payouts for today in MongoDB
                const payoutCounts = {};
                if (candidateIds.length > 0) {
                    try {
                        const agg = await PayoutRecord.aggregate([
                            {
                                $match: {
                                    appName,
                                    userId: { $in: candidateIds },
                                    status: 'success',
                                    createdAt: { $gte: todayStart }
                                }
                            },
                            {
                                $group: {
                                    _id: '$userId',
                                    count: { $sum: 1 }
                                }
                            }
                        ]);
                        for (const item of agg) {
                            payoutCounts[item._id] = item.count;
                        }
                    } catch (mErr) {
                        console.error('🔥 Failed to aggregate PayoutRecord counts in MongoDB:', mErr);
                    }
                }


                // Cache game play logs, read logs and postback logs for candidates in bulk to reduce DB queries!
                const bulkWatchEarnLogs = await PostbackLogs.find({
                    appName,
                    userId: { $in: candidateIds },
                    offerType: 'WatchEarn',
                    completedAt: { $gte: todayStart }
                }).lean();

                const bulkDailyTaskLogs = await PostbackLogs.find({
                    appName,
                    userId: { $in: candidateIds },
                    offerType: 'DailyTask'
                }).sort({ completedAt: -1 }).lean();

                const bulkReadEarnLogs = await ReadEarnLogs.find({
                    appName,
                    userId: { $in: candidateIds },
                    createdAt: { $gte: twentyFourHoursAgo }
                }).lean();

                let bulkGamePlayLogs = [];
                try {
                    bulkGamePlayLogs = await GamePlayLogs.find({
                        userId: { $in: candidateIds }
                    }).lean();
                } catch (err) { }

                for (const userId of candidateIds) {
                    const userData = userDocsMap[userId];
                    if (!userData) continue;

                    const email = userData.email || '';
                    const allActivities = [];



                    // 3. Watch & Earn - Same offer multiple times today
                    const watchEarnLogs = bulkWatchEarnLogs.filter(log => log.userId === userId);
                    const watchEarnCounts = {};
                    for (const log of watchEarnLogs) {
                        if (!watchEarnCounts[log.offerId]) {
                            watchEarnCounts[log.offerId] = {
                                count: 0,
                                offerName: log.payload?.offerName || log.offerId,
                                payoutSum: 0
                            };
                        }
                        watchEarnCounts[log.offerId].count++;
                        watchEarnCounts[log.offerId].payoutSum += (Number(log.payout) || 1);
                    }
                    for (const [offerId, data] of Object.entries(watchEarnCounts)) {
                        if (data.count > 1) {
                            allActivities.push({
                                type: 'watch_earn',
                                details: `Watch & Earn offer '${data.offerName}' completed ${data.count} times today`,
                                coinValue: Math.round(data.payoutSum * 100),
                                detectedAt: new Date(),
                            });
                        }
                    }

                    // 4. Daily Task Exploit
                    const dailyTaskLogs = bulkDailyTaskLogs.filter(log => log.userId === userId);
                    const completionMap = {};
                    for (const log of dailyTaskLogs) {
                        const key = log.eventId ? `${log.offerId}:${log.eventId}` : log.offerId;
                        if (!completionMap[key]) {
                            completionMap[key] = {
                                offerId: log.offerId,
                                offerName: taskMap[log.offerId]?.offerName || log.offerId,
                                dailyReset: taskMap[log.offerId]?.dailyReset || false,
                                count: 0,
                                lastCompletedAt: null,
                                payoutSum: 0
                            };
                        }
                        completionMap[key].count++;
                        completionMap[key].payoutSum += (Number(log.payout) || 1);
                        if (!completionMap[key].lastCompletedAt || log.completedAt > completionMap[key].lastCompletedAt) {
                            completionMap[key].lastCompletedAt = log.completedAt;
                        }
                    }
                    for (const [key, data] of Object.entries(completionMap)) {
                        const isOneTimeTask = data.dailyReset === false;
                        const completedMultipleTimes = data.count > 1;
                        const completedToday = data.lastCompletedAt && data.lastCompletedAt >= todayStart;

                        if (isOneTimeTask && completedMultipleTimes) {
                            allActivities.push({
                                type: 'daily_task',
                                details: `One-time task '${data.offerName}' completed ${data.count} times`,
                                coinValue: Math.round(data.payoutSum * 100),
                                detectedAt: new Date(),
                            });
                        } else if (completedToday && completedMultipleTimes) {
                            allActivities.push({
                                type: 'daily_task',
                                details: `Task '${data.offerName}' completed ${data.count} times today`,
                                coinValue: Math.round(data.payoutSum * 100),
                                detectedAt: new Date(),
                            });
                        }
                    }

                    // 5. Play Games Exploit
                    for (const game of games) {
                        const gameId = String(game._id);
                        const userPlayLogs = bulkGamePlayLogs.filter(log => log.userId === userId && log.offerId === gameId);

                        if (game.maxPlaysPerUser > 0 && userPlayLogs.length > game.maxPlaysPerUser) {
                            allActivities.push({
                                type: 'play_games',
                                details: `Game '${game.offerName}': ${userPlayLogs.length} plays (lifetime limit: ${game.maxPlaysPerUser})`,
                                coinValue: userPlayLogs.length * (game.payout || 0) * 100,
                                detectedAt: new Date(),
                            });
                        }

                        if (game.dailyEnabled && game.maxPlaysPerDay > 0) {
                            const todayLogs = userPlayLogs.filter(log => log.dayKey === todayKey);
                            if (todayLogs.length > game.maxPlaysPerDay) {
                                allActivities.push({
                                    type: 'play_games',
                                    details: `Game '${game.offerName}': ${todayLogs.length} plays today (daily limit: ${game.maxPlaysPerDay})`,
                                    coinValue: todayLogs.length * (game.payout || 0) * 100,
                                    detectedAt: new Date(),
                                });
                            }
                        }
                    }

                    // 6. Read & Earn Exploit
                    const userReadLogs = bulkReadEarnLogs.filter(log => log.userId === userId);
                    const readLogs = userReadLogs.length;
                    if (readLogs > readEarnLimit) {
                        const totalCoins = userReadLogs.reduce((sum, log) => sum + Math.round((Number(log.payout) || 1) * 100), 0);
                        allActivities.push({
                            type: 'read_earn',
                            details: `Completed ${readLogs} Read & Earn offers in 24h (limit: ${readEarnLimit})`,
                            coinValue: totalCoins,
                            detectedAt: new Date(),
                        });
                    }

                    // 7. Withdrawal Exploit
                    const dailyMaxPayout = appData.dailyMaxPayout !== undefined ? appData.dailyMaxPayout : 1;
                    const count = payoutCounts[userId] || 0;
                    if (count > dailyMaxPayout) {
                        allActivities.push({
                            type: 'withdrawal',
                            details: `${count} successful withdrawals today (limit: ${dailyMaxPayout})`,
                            coinValue: 0,
                            detectedAt: new Date(),
                        });
                    }

                    if (allActivities.length > 0) {
                        await SuspiciousActivity.findOneAndUpdate(
                            { appName, userId },
                            {
                                appName,
                                userId,
                                email,
                                activities: allActivities,
                                lastUpdated: new Date(),
                                isBlocked: userData.blocked || false,
                            },
                            { upsert: true, returnDocument: 'after' }
                        );
                    } else if (existingSuspiciousSet.has(userId)) {
                        await SuspiciousActivity.findOneAndDelete({ appName, userId });
                    }
                }

                console.log(`✅ Scan completed for app: ${appName}`);
            } catch (err) {
                console.error(`❌ Error scanning app ${appName}:`, err);
            }
        }

        console.log('⏰ All unusual activity scans completed');
    } catch (err) {
        console.error('❌ Unusual activity scan failed:', err);
    }
}, {
    timezone: 'Asia/Kolkata',
});

// Recalculate and update coins leaderboard in Firestore
async function updateLeaderboards() {
    console.log('🏆 Recalculating Leaderboard (Coins) for all apps...');
    try {
        await connectMongo();
        const services = await FirebaseService.find({}).lean();
        for (const service of services) {
            const { appName, serviceAccount } = service;
            if (!appName || !serviceAccount) continue;

            const firebase = getOrInitFirebase(appName, serviceAccount);
            const db = firebase.firestore();

            // 1. Calculate Daily IST Window (starts at 8:00 PM / 20:00 IST)
            const now = DateTime.now().setZone('Asia/Kolkata');
            let start = now.set({
                hour: 20,
                minute: 0,
                second: 0,
                millisecond: 0,
            });

            if (now < start) start = start.minus({ days: 1 });
            const startDate = start.toJSDate();

            // 2. Query MongoDB RewardHistory for sum of coins
            const results = await RewardHistory.aggregate([
                {
                    $match: {
                        appName,
                        timestamp: { $gte: startDate }
                    }
                },
                {
                    $group: {
                        _id: "$userId",
                        totalCoins: { $sum: "$coins" }
                    }
                },
                {
                    $sort: { totalCoins: -1 }
                },
                {
                    $limit: 20
                }
            ]);

            const userIds = results.map(r => r._id);
            const users = await User.find({ userId: { $in: userIds } }).lean();
            const usersMap = {};
            users.forEach(u => { usersMap[u.userId] = u; });

            const toppers = results.map(row => {
                const u = usersMap[row._id] || {};
                return {
                    userId: row._id,
                    name: u.displayName || u.name || 'User',
                    photoUrl: u.photoUrl || '',
                    totalCoins: row.totalCoins || 0,
                    totalReferrals: 0
                };
            });

            await Leaderboard.findOneAndUpdate(
                { type: 'coins' },
                { toppers, updatedAt: new Date() },
                { upsert: true }
            );

            console.log(`✅ Updated coins leaderboard for ${appName} with ${toppers.length} toppers in MongoDB.`);
        }
    } catch (err) {
        console.error('🔥 Leaderboard update failed:', err);
    }
}

// Scheduled leaderboard updates (runs every 15 minutes)
cron.schedule('*/15 * * * *', async () => {
    try {
        await updateLeaderboards();
    } catch (err) {
        console.error('🔥 Leaderboard cron error:', err);
    }
});

// Run leaderboard update immediately on server load
updateLeaderboards().catch(err => {
    console.error('🔥 Initial leaderboard generation failed:', err);
});

// =================== Promo Code Management =================================

// Create Promo Code API
router.post('/createPromoCode', adminAuth, checkPermission('promoCodes'), async (req, res) => {
    try {
        const { appName, code, reward, maxRedemptions, } = req.body;

        if (!appName || !code || !reward || !maxRedemptions) {
            return res.status(400).json({
                success: false,
                message: 'Missing required fields: appName, code, reward, maxRedemptions'
            });
        }

        await connectMongo();
        const PromoCode = require('../admin/models/promoCode');
        const codeId = code.toUpperCase();

        const existingCode = await PromoCode.findOne({ appName, code: codeId });
        if (existingCode) {
            return res.status(409).json({
                success: false,
                message: `Promo code ${codeId} already exists`
            });
        }

        const promoData = await PromoCode.create({
            appName,
            code: codeId,
            reward: Number(reward),
            maxRedemptions: Number(maxRedemptions),
            redeemedCount: 0,
            active: true,
        });

        return res.status(200).json({
            success: true,
            message: `Promo code ${codeId} created successfully`,
            data: promoData
        });

    } catch (error) {
        console.error('🔥 Error creating promo code:', error);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error'
        });
    }
});

router.get('/promo-codes', adminAuth, checkPermission('promoCodes'), async (req, res) => {
    const firebaseServices = await FirebaseService.find().sort({ displayName: 1 });

    res.render('promo/manage', {
        firebaseServices,
        photo: req.user?.photo || '👤'
    });
});

router.post('/getPromoCodes', adminAuth, checkPermission('promoCodes'), async (req, res) => {
    try {
        const { appName } = req.body;
        await connectMongo();
        const PromoCode = require('../admin/models/promoCode');

        const promosDocs = await PromoCode.find({ appName }).sort({ createdAt: -1 }).lean();

        const promos = promosDocs.map(d => ({
            id: d._id.toString(),
            code: d.code,
            reward: d.reward,
            maxRedemptions: d.maxRedemptions,
            redeemedCount: d.redeemedCount || 0,
            active: d.active,
            createdAt: d.createdAt,
        }));

        res.json({ success: true, promos });
    } catch (err) {
        res.status(500).json({ success: false });
    }
});

router.post('/updatePromoCode', adminAuth, checkPermission('promoCodes'), async (req, res) => {
    try {
        const { appName, code, reward, maxRedemptions, active } = req.body;
        await connectMongo();
        const PromoCode = require('../admin/models/promoCode');

        await PromoCode.updateOne(
            { appName, code: String(code).toUpperCase() },
            {
                $set: {
                    reward: Number(reward),
                    maxRedemptions: Number(maxRedemptions),
                    active: !!active,
                }
            }
        );

        res.json({ success: true, message: 'Promo updated' });
    } catch {
        res.status(500).json({ success: false });
    }
});

router.post('/deletePromoCode', adminAuth, checkPermission('promoCodes'), async (req, res) => {
    try {
        const { appName, code } = req.body;
        await connectMongo();
        const PromoCode = require('../admin/models/promoCode');

        await PromoCode.deleteOne({ appName, code: String(code).toUpperCase() });

        res.json({ success: true });
    } catch {
        res.status(500).json({ success: false });
    }
});

router.post('/bulkDeletePromoCodes', adminAuth, checkPermission('promoCodes'), async (req, res) => {
    try {
        const { appName, codes } = req.body;
        if (!appName || !Array.isArray(codes) || !codes.length) {
            return res.status(400).json({ success: false, message: 'Invalid appName or codes' });
        }
        await connectMongo();
        const PromoCode = require('../admin/models/promoCode');
        const formattedCodes = codes.map(c => String(c).toUpperCase());
        const result = await PromoCode.deleteMany({ appName, code: { $in: formattedCodes } });
        res.json({ success: true, count: result.deletedCount });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
});


// =================== DAILY TASK MANAGEMENT ==========================
router.get('/add-daily-task', adminAuth, checkPermission('dailyTasks'), async (_, res) => {
    let countries = [];

    // Helper to normalize country list from either API shape
    const normalizeCountries = (list) => {
        if (!Array.isArray(list)) return [];
        return list.map(c => {
            if (c.cca2) {
                // restcountries.com v3 shape
                return {
                    code: c.cca2,
                    name: c.name?.common,
                    flag: c.flags?.svg || c.flags?.png,
                };
            }
            if (c.iso2) {
                // countriesnow.space shape
                return {
                    code: c.iso2,
                    name: c.name,
                    flag: c.flag,
                };
            }
            return null;
        })
            .filter(c => c && c.code && c.name && c.flag)
            .sort((a, b) => a.name.localeCompare(b.name));
    };

    // Try restcountries.com first
    try {
        const response = await axios.get('https://restcountries.com/v3.1/all?fields=name,cca2,flags', { timeout: 5000 });
        countries = normalizeCountries(response?.data);
        if (countries.length === 0) {
            console.warn('restcountries returned empty/invalid, trying fallback...');
            throw new Error('empty');
        }
    } catch (err) {
        // Fallback to countriesnow.space
        try {
            console.warn('restcountries failed, using countriesnow.space fallback');
            const fb = await axios.get('https://countriesnow.space/api/v0.1/countries/flag/images', { timeout: 5000 });
            countries = normalizeCountries(fb?.data?.data);
            if (countries.length === 0) {
                console.warn('Fallback also returned empty, continuing with empty list');
            }
        } catch (fbErr) {
            console.error('Country API fallback also failed:', fbErr.message || fbErr);
        }
    }

    try {
        await connectMongo();

        // Seed default categories if none exist
        const count = await DailyTaskCategory.countDocuments();
        if (count === 0) {
            const defaults = [
                "Multi Task",
                "Youtube Video",
                "Youtube Shorts",
                "Instagram Reels",
                "Install",
                "Register",
                "Other"
            ];
            await DailyTaskCategory.insertMany(defaults.map(name => ({ name })));
        }

        const categories = await DailyTaskCategory.find().sort({ name: 1 }).lean();

        return res.render('daily-task/add', { countries, categories, isWatchEarnPage: false });
    } catch (err) {
        console.error('Error loading add-daily-task page:', err.message || err);
        return res.render('daily-task/add', { countries, categories: [], isWatchEarnPage: false });
    }
});

router.get('/add-watch-earn', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    let countries = [];

    const normalizeCountries = (list) => {
        if (!Array.isArray(list)) return [];
        return list.map(c => {
            if (c.cca2) {
                return {
                    code: c.cca2,
                    name: c.name?.common,
                    flag: c.flags?.svg || c.flags?.png,
                };
            }
            if (c.iso2) {
                return {
                    code: c.iso2,
                    name: c.name,
                    flag: c.flag,
                };
            }
            return null;
        })
            .filter(c => c && c.code && c.name && c.flag)
            .sort((a, b) => a.name.localeCompare(b.name));
    };

    try {
        const response = await axios.get('https://restcountries.com/v3.1/all?fields=name,cca2,flags', { timeout: 5000 });
        countries = normalizeCountries(response?.data);
        if (countries.length === 0) {
            throw new Error('empty');
        }
    } catch (err) {
        try {
            const fb = await axios.get('https://countriesnow.space/api/v0.1/countries/flag/images', { timeout: 5000 });
            countries = normalizeCountries(fb?.data?.data);
        } catch (fbErr) {
            console.error('Country API fallback failed:', fbErr.message || fbErr);
        }
    }

    try {
        await connectMongo();

        const count = await DailyTaskCategory.countDocuments();
        if (count === 0) {
            const defaults = [
                "Multi Task",
                "Youtube Video",
                "Youtube Shorts",
                "Instagram Reels",
                "Install",
                "Register",
                "Other"
            ];
            await DailyTaskCategory.insertMany(defaults.map(name => ({ name })));
        }

        const categories = await DailyTaskCategory.find().sort({ name: 1 }).lean();

        return res.render('watch-earn/add', { countries, categories, isWatchEarnPage: true });
    } catch (err) {
        console.error('Error loading add-watch-earn page:', err.message || err);
        return res.render('watch-earn/add', { countries, categories: [], isWatchEarnPage: true });
    }
});

router.post('/add-daily-task', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const offerData = req.body || {};

        // Helper to normalize field that can be array or comma string
        const normalizeArrayField = (v) => {
            if (!v) return [];
            if (Array.isArray(v)) return v.map(x => String(x).trim()).filter(Boolean);
            if (typeof v === 'string') return v.split(',').map(x => String(x).trim()).filter(Boolean);
            return [];
        };

        // Parse & normalize inputs
        const countries = normalizeArrayField(offerData.countries);

        // Basic validation
        if (!countries || countries.length === 0) {
            return res.status(400).json({
                success: false,
                message: `❌ Please provide at least one country in 'countries'.`
            });
        }

        // normalize string OR array → array
        const normalizeStringArray = (v) => {
            if (!v) return [];

            if (Array.isArray(v))
                return v.map(x => String(x).trim()).filter(Boolean);

            if (typeof v === 'string')
                return v
                    .split(',')
                    .map(x => String(x).trim())
                    .filter(Boolean);

            return [];
        };

        // Numeric validations
        const payout = Number(offerData.payout);
        if (Number.isNaN(payout) || payout <= 0) {
            return res.status(400).json({
                success: false,
                message: '❌ Invalid payout. Must be a number > 0.'
            });
        }

        const trackingTime = offerData.trackingTime ? Number(offerData.trackingTime) : 0;

        const dailyCapLimit = (offerData.dailyCapLimit === null || offerData.dailyCapLimit === undefined || offerData.dailyCapLimit === '')
            ? null : Number(offerData.dailyCapLimit);
        if (dailyCapLimit !== null && (Number.isNaN(dailyCapLimit) || dailyCapLimit < 0)) {
            return res.status(400).json({
                success: false,
                message: '❌ Invalid dailyCapLimit. Must be null or a number >= 0.'
            });
        }

        const lifetimeCapLimit = (offerData.lifetimeCapLimit === null || offerData.lifetimeCapLimit === undefined || offerData.lifetimeCapLimit === '')
            ? null : Number(offerData.lifetimeCapLimit);
        if (lifetimeCapLimit !== null && (Number.isNaN(lifetimeCapLimit) || lifetimeCapLimit < 0)) {
            return res.status(400).json({
                success: false,
                message: '❌ Invalid lifetimeCapLimit. Must be null or a number >= 0.'
            });
        }

        // boolean fields
        const enabled = (offerData.enabled === true || offerData.enabled === 'true' || offerData.enabled === 1 || offerData.enabled === '1');
        const dailyReset = (offerData.dailyReset === true || offerData.dailyReset === 'true' || offerData.dailyReset === 1 || offerData.dailyReset === '1');
        const offerDescription =
            normalizeStringArray(offerData.offerDescription);

        // Parse events array
        let events = [];
        if (offerData.events && Array.isArray(offerData.events)) {
            events = offerData.events.map((e, index) => {
                const eventId = e.eventId || `event_${index + 1}`;
                const coins = Number(e.coins) || Number(e.payout) || 0;
                return {
                    eventId: String(eventId).trim(),
                    name: String(e.name || `Event ${index + 1}`).trim(),
                    label: String(e.label || '').trim(),
                    coins: coins,
                    payout: coins,
                };
            }).filter(e => e.coins > 0);
        }

        if (!offerDescription.length) {
            return res.status(400).json({
                success: false,
                message: '❌ Offer description must contain at least one line.'
            });
        }

        const offerDisclaimer =
            normalizeStringArray(offerData.offerDisclaimer);


        // Parse & validate package/timer fields
        const packageEnabled = (offerData.packageEnabled === true || offerData.packageEnabled === 'true' || offerData.packageEnabled === 1 || offerData.packageEnabled === '1');
        const packageName = packageEnabled ? String(offerData.packageName || '').trim() : '';
        const timerEnabled = (offerData.timerEnabled === true || offerData.timerEnabled === 'true' || offerData.timerEnabled === 1 || offerData.timerEnabled === '1');

        const dailyRewardEnabled = timerEnabled && (offerData.dailyRewardEnabled === true || offerData.dailyRewardEnabled === 'true' || offerData.dailyRewardEnabled === 1 || offerData.dailyRewardEnabled === '1');
        const timerDuration = (timerEnabled && !dailyRewardEnabled) ? Number(offerData.timerDuration || 0) : 0;

        if (packageEnabled && !packageName) {
            return res.status(400).json({
                success: false,
                message: '❌ Package Name / App Package ID is required when Package verification is ON.'
            });
        }

        if (timerEnabled && !dailyRewardEnabled && (Number.isNaN(timerDuration) || timerDuration <= 0)) {
            return res.status(400).json({
                success: false,
                message: '❌ Timer Duration must be a positive number when Timer is ON.'
            });
        }

        // Parse and validate dailyRewards if dailyRewardEnabled is ON
        let dailyRewards = [];
        if (dailyRewardEnabled) {
            if (offerData.dailyRewards && Array.isArray(offerData.dailyRewards)) {
                dailyRewards = offerData.dailyRewards.map((step, index) => {
                    const day = Number(step.day) || (index + 1);
                    const duration = Number(step.timerDuration) || 0;
                    const coins = Number(step.coins) || 0;
                    const payout = coins / 100;
                    return { day, timerDuration: duration, coins, payout };
                });
            }
            if (dailyRewards.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: '❌ Please add at least one step for Daily Reward Mode.'
                });
            }
            for (const r of dailyRewards) {
                if (r.timerDuration <= 0 || r.coins <= 0) {
                    return res.status(400).json({
                        success: false,
                        message: '❌ Duration and Coins for all Daily Steps must be greater than zero.'
                    });
                }
            }
        }

        const multiEventEnabled = (offerData.multiEventEnabled === true || offerData.multiEventEnabled === 'true' || offerData.multiEventEnabled === 1 || offerData.multiEventEnabled === '1');
        const redirectionUrl = offerData.redirectionUrl ? String(offerData.redirectionUrl).trim() : '';
        const isRedirOptional = packageEnabled || multiEventEnabled;
        if (!isRedirOptional && !redirectionUrl) {
            return res.status(400).json({
                success: false,
                message: '❌ Redirection URL is required.'
            });
        }

        const videoVerificationEnabled = offerData.offerType === 'WatchEarn' && (offerData.videoVerificationEnabled === true || offerData.videoVerificationEnabled === 'true' || offerData.videoVerificationEnabled === 1 || offerData.videoVerificationEnabled === '1');
        const videoVerificationId = offerData.offerType === 'WatchEarn' ? String(offerData.videoVerificationId || '').trim() : '';

        const perUserDailyCap = offerData.offerType === 'WatchEarn' && (offerData.perUserDailyCap !== null && offerData.perUserDailyCap !== undefined && offerData.perUserDailyCap !== '')
            ? Number(offerData.perUserDailyCap) : null;
        if (perUserDailyCap !== null && (Number.isNaN(perUserDailyCap) || perUserDailyCap < 0)) {
            return res.status(400).json({
                success: false,
                message: '❌ Invalid perUserDailyCap. Must be null or a number >= 0.'
            });
        }

        // Build new offer object
        // Calculate total coins from events if present, or daily rewards if dailyRewardEnabled, otherwise use direct payout/coins
        let totalCoins = Number(offerData.coins || payout || 0);
        if (multiEventEnabled && events.length > 0) {
            totalCoins = events.reduce((sum, e) => sum + (Number(e.coins) || 0), 0);
        } else if (dailyRewardEnabled && dailyRewards.length > 0) {
            totalCoins = dailyRewards.reduce((sum, e) => sum + (Number(e.coins || e.payout) || 0), 0);
        }

        const newOfferPayload = {
            imagePath: offerData.imagePath,
            bannerPath: offerData.bannerPath,
            offerId: offerData.offerId,
            provider: offerData.provider,
            offerName: offerData.offerName,
            offerDescription: offerDescription,
            offerDisclaimer: offerDisclaimer,
            offerType: offerData.offerType,
            offerCategory: offerData.offerCategory,
            coins: totalCoins,
            payout: totalCoins,
            redirectionUrl: redirectionUrl,
            packageEnabled: packageEnabled,
            packageName: packageName,
            timerEnabled: timerEnabled,
            timerDuration: timerDuration,
            dailyRewardEnabled: dailyRewardEnabled,
            dailyRewards: dailyRewards,
            videoVerificationEnabled: videoVerificationEnabled,
            videoVerificationId: videoVerificationId,
            perUserDailyCap: perUserDailyCap,
            enabled: !!enabled,
            countries: countries,
            dailyCapLimit: dailyCapLimit,
            lifetimeCapLimit: lifetimeCapLimit,
            trackingTime: trackingTime,
            dailyCapCount: 0,
            postbackCount: 0,
            color: offerData.color,
            watchTutorial: offerData.watchTutorial ? String(offerData.watchTutorial).trim() : '',
            subDescription: offerData.subDescription ? String(offerData.subDescription).trim() : '',
            rating: offerData.rating ? String(offerData.rating).trim() : '',
            downloads: offerData.downloads ? String(offerData.downloads).trim() : '',
            // Multi-event support
            events: multiEventEnabled ? events : [],
            dailyReset: multiEventEnabled ? dailyReset : false,
            screenshotVerificationEnabled: (offerData.screenshotVerificationEnabled === true || offerData.screenshotVerificationEnabled === 'true' || offerData.screenshotVerificationEnabled === '1'),
            // Per-task secret key for postback authentication
            secretKey: generateSecretKey(),
        };

        // Optional: check required string fields presence
        const requiredStrings = ['imagePath', 'offerId', 'provider', 'offerName', 'offerType', 'offerCategory'];
        for (const key of requiredStrings) {
            if (!newOfferPayload[key] || String(newOfferPayload[key]).trim() === '') {
                return res.status(400).json({
                    success: false,
                    message: `❌ Missing required field: ${key}`
                });
            }
        }

        const newOffer = new DailyTask(newOfferPayload);
        await newOffer.save();
        try { await cacheService.delPattern('tasks:*'); } catch (_) { }

        return res.json({
            success: true,
            message: '✅ Offer added successfully!'
        });
    } catch (err) {
        console.error('🔥 Error saving offer:', err);

        // handle duplicate key error on offerId (E11000)
        if (err && err.code === 11000) {
            const dupKey = err.keyValue ? Object.keys(err.keyValue)[0] : 'offerId';
            return res.status(409).json({
                success: false,
                message: `❌ Duplicate ${dupKey} - an offer with this identifier already exists.`
            });
        }

        return res.status(500).json({
            success: false,
            message: '❌ Failed to add offer. Please try again.'
        });
    }
});

router.get('/manage-daily-task', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        // Seed default categories if none exist
        const count = await DailyTaskCategory.countDocuments();
        if (count === 0) {
            const defaults = [
                "Multi Task",
                "Youtube Video",
                "Youtube Shorts",
                "Instagram Reels",
                "Install",
                "Register",
                "Other"
            ];
            await DailyTaskCategory.insertMany(defaults.map(name => ({ name })));
        }

        const [offers, categories, appDataDoc] = await Promise.all([
            DailyTask.find({ offerType: { $ne: 'WatchEarn' } }).sort({ createdAt: -1 }).lean(),
            DailyTaskCategory.find().sort({ name: 1 }).lean(),
            AppData.findOne({ key: 'appData' }).lean()
        ]);
        const dailyTaskTitle = appDataDoc?.config?.dailyTaskTitle || 'Daily Task';
        res.render('daily-task/manage', { offers, categories, dailyTaskTitle, isWatchEarnPage: false, activePage: 'daily-tasks' });
    } catch (err) {
        console.error('get manage-daily-task error', err);
        res.render('daily-task/manage', {
            offers: [],
            categories: [],
            dailyTaskTitle: 'Daily Task',
            error: err.message,
            isWatchEarnPage: false,
            activePage: 'daily-tasks'
        });
    }
});

router.get('/manage-watch-earn', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const count = await DailyTaskCategory.countDocuments();
        if (count === 0) {
            const defaults = [
                "Multi Task",
                "Youtube Video",
                "Youtube Shorts",
                "Instagram Reels",
                "Install",
                "Register",
                "Other"
            ];
            await DailyTaskCategory.insertMany(defaults.map(name => ({ name })));
        }

        const offers = await DailyTask.find({ offerType: 'WatchEarn' }).sort({ createdAt: -1 }).lean();
        const categories = await DailyTaskCategory.find().sort({ name: 1 }).lean();
        res.render('watch-earn/manage', { offers, categories, isWatchEarnPage: true, activePage: 'watch-earn' });
    } catch (err) {
        console.error('get manage-watch-earn error', err);
        res.render('watch-earn/manage', {
            offers: [],
            categories: [],
            error: err.message,
            isWatchEarnPage: true,
            activePage: 'watch-earn'
        });
    }
});

router.patch('/daily-task/:id', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();
        const id = req.params.id;
        const body = req.body || {};

        const updates = {};
        const has = (k) => Object.prototype.hasOwnProperty.call(body, k);

        // --- Standard Fields ---
        if (has('imagePath')) {
            const v = String(body.imagePath || '').trim();
            if (!v) return res.status(400).json({ success: false, message: 'imagePath cannot be empty' });
            updates.imagePath = v;
        }

        // bannerPath (optional, can be empty string)
        if (has('bannerPath')) {
            updates.bannerPath = String(body.bannerPath || '').trim();
        }

        if (has('offerName')) {
            const v = String(body.offerName || '').trim();
            if (!v) return res.status(400).json({ success: false, message: 'offerName cannot be empty' });
            updates.offerName = v;
        }

        if (has('rating')) {
            updates.rating = String(body.rating || '').trim();
        }

        if (has('downloads')) {
            updates.downloads = String(body.downloads || '').trim();
        }

        if (has('screenshotVerificationEnabled')) {
            updates.screenshotVerificationEnabled = (body.screenshotVerificationEnabled === true || body.screenshotVerificationEnabled === 'true' || body.screenshotVerificationEnabled === '1');
        }

        if (has('color')) {
            updates.color = String(body.color || '').trim();
        }

        if (has('offerDescription')) {

            let desc = body.offerDescription;

            // Normalize: string OR array → array
            if (Array.isArray(desc)) {
                desc = desc.map(d => String(d).trim()).filter(Boolean);
            } else if (typeof desc === 'string') {
                desc = desc
                    .split(',')
                    .map(d => d.trim())
                    .filter(Boolean);
            } else {
                desc = [];
            }

            if (!desc.length) {
                return res.status(400).json({
                    success: false,
                    message: 'Description must contain at least one step'
                });
            }

            updates.offerDescription = desc;
        }

        if (has('offerDisclaimer')) {
            let disclaimer = body.offerDisclaimer;
            if (Array.isArray(disclaimer)) {
                disclaimer = disclaimer.map(d => String(d).trim()).filter(Boolean);
            } else if (typeof disclaimer === 'string') {
                disclaimer = disclaimer
                    .split(',')
                    .map(d => d.trim())
                    .filter(Boolean);
            } else {
                disclaimer = [];
            }
            updates.offerDisclaimer = disclaimer;
        }

        if (has('offerCategory')) {
            const cat = String(body.offerCategory || '').trim();
            if (!cat) return res.status(400).json({ success: false, message: 'offerCategory cannot be empty' });
            updates.offerCategory = cat;
        }

        if (has('payout')) {
            const p = Number(body.payout);
            if (Number.isNaN(p) || p < 0) return res.status(400).json({ success: false, message: 'payout must be a non-negative number' });
            updates.payout = p;
        }

        if (has('trackingTime')) {
            const t = Number(body.trackingTime);
            if (Number.isNaN(t) || t < 0) return res.status(400).json({ success: false, message: 'trackingTime must be a non-negative number' });
            updates.trackingTime = t;
        }

        if (has('redirectionUrl')) {
            updates.redirectionUrl = String(body.redirectionUrl || '').trim();
        }

        if (has('packageEnabled')) {
            updates.packageEnabled = (body.packageEnabled === true || body.packageEnabled === 'true' || body.packageEnabled === '1');
        }

        if (has('packageName')) {
            updates.packageName = String(body.packageName || '').trim();
        }

        if (has('timerEnabled')) {
            updates.timerEnabled = (body.timerEnabled === true || body.timerEnabled === 'true' || body.timerEnabled === '1');
        }

        if (has('timerDuration')) {
            const td = Number(body.timerDuration);
            if (Number.isNaN(td) || td < 0) return res.status(400).json({ success: false, message: 'timerDuration must be a non-negative number' });
            updates.timerDuration = td;
        }

        if (has('dailyRewardEnabled')) {
            updates.dailyRewardEnabled = (body.dailyRewardEnabled === true || body.dailyRewardEnabled === 'true' || body.dailyRewardEnabled === '1');
        }

        if (has('watchTutorial')) {
            updates.watchTutorial = String(body.watchTutorial || '').trim();
        }

        if (has('subDescription')) {
            updates.subDescription = String(body.subDescription || '').trim();
        }

        if (has('videoVerificationEnabled')) {
            updates.videoVerificationEnabled = (body.videoVerificationEnabled === true || body.videoVerificationEnabled === 'true' || body.videoVerificationEnabled === '1');
        }

        if (has('videoVerificationId')) {
            updates.videoVerificationId = String(body.videoVerificationId || '').trim();
        }

        if (has('perUserDailyCap')) {
            if (body.perUserDailyCap === null || body.perUserDailyCap === '') {
                updates.perUserDailyCap = null;
            } else {
                const p = Number(body.perUserDailyCap);
                if (Number.isNaN(p) || p < 0) return res.status(400).json({ success: false, message: 'perUserDailyCap must be a non-negative number' });
                updates.perUserDailyCap = p;
            }
        }

        if (has('dailyRewards')) {
            let dailyRewards = [];
            if (Array.isArray(body.dailyRewards)) {
                dailyRewards = body.dailyRewards.map((step, index) => {
                    const day = Number(step.day) || (index + 1);
                    const duration = Number(step.timerDuration) || 0;
                    const coins = Number(step.coins) || 0;
                    const payout = coins / 100;
                    return { day, timerDuration: duration, coins, payout };
                });
            }
            updates.dailyRewards = dailyRewards;
        }

        // Validate final combined state
        const currentTask = await DailyTask.findById(id);
        if (!currentTask) {
            return res.status(404).json({ success: false, message: 'Daily task not found' });
        }

        const finalPackageEnabled = has('packageEnabled') ? updates.packageEnabled : currentTask.packageEnabled;
        const finalPackageName = has('packageName') ? updates.packageName : currentTask.packageName;
        const finalTimerEnabled = has('timerEnabled') ? updates.timerEnabled : currentTask.timerEnabled;
        const finalDailyRewardEnabled = has('dailyRewardEnabled') ? updates.dailyRewardEnabled : currentTask.dailyRewardEnabled;
        const finalDailyRewards = has('dailyRewards') ? updates.dailyRewards : (currentTask.dailyRewards || []);

        let finalTimerDuration = has('timerDuration') ? updates.timerDuration : currentTask.timerDuration;
        if (finalTimerEnabled && finalDailyRewardEnabled) {
            updates.timerDuration = 0;
            finalTimerDuration = 0;
        }

        const finalMultiEventEnabled = has('multiEventEnabled') ? (body.multiEventEnabled === true || body.multiEventEnabled === 'true' || body.multiEventEnabled === '1') : (Array.isArray(currentTask.events) && currentTask.events.length > 0);
        const finalRedirectionUrl = has('redirectionUrl') ? updates.redirectionUrl : currentTask.redirectionUrl;

        if (finalPackageEnabled && (!finalPackageName || finalPackageName.trim() === '')) {
            return res.status(400).json({ success: false, message: 'Package Name / App Package ID is required when Package verification is ON.' });
        }
        if (finalTimerEnabled && !finalDailyRewardEnabled && (Number.isNaN(finalTimerDuration) || finalTimerDuration <= 0)) {
            return res.status(400).json({ success: false, message: 'Timer Duration must be a positive number when Timer is ON.' });
        }
        if (finalTimerEnabled && finalDailyRewardEnabled) {
            if (finalDailyRewards.length === 0) {
                return res.status(400).json({ success: false, message: '❌ Please add at least one step for Daily Reward Mode.' });
            }
            for (const r of finalDailyRewards) {
                if (r.timerDuration <= 0 || r.coins <= 0) {
                    return res.status(400).json({ success: false, message: '❌ Duration and Coins for all Daily Steps must be greater than zero.' });
                }
            }
        }

        const isRedirOptional = finalPackageEnabled || finalMultiEventEnabled;
        if (!isRedirOptional && (!finalRedirectionUrl || finalRedirectionUrl.trim() === '')) {
            return res.status(400).json({ success: false, message: 'Redirection URL is required.' });
        }

        // --- Caps (Daily & Lifetime) ---
        if (has('dailyCapLimit')) {
            if (body.dailyCapLimit === null || body.dailyCapLimit === '') {
                updates.dailyCapLimit = null;
            } else {
                const d = Number(body.dailyCapLimit);
                if (Number.isNaN(d) || d < 0) return res.status(400).json({ success: false, message: 'dailyCapLimit must be a non-negative number' });
                updates.dailyCapLimit = d;
            }
        }

        if (has('lifetimeCapLimit')) {
            if (body.lifetimeCapLimit === null || body.lifetimeCapLimit === '') {
                updates.lifetimeCapLimit = null;
            } else {
                const l = Number(body.lifetimeCapLimit);
                if (Number.isNaN(l) || l < 0) return res.status(400).json({ success: false, message: 'lifetimeCapLimit must be a non-negative number' });
                updates.lifetimeCapLimit = l;
            }
        }

        // --- Status & Priority ---
        if (has('enabled')) {
            updates.enabled = (body.enabled === true || body.enabled === 'true' || body.enabled === '1');
        }

        if (has('prioritized')) {
            updates.prioritized = (body.prioritized === true || body.prioritized === 'true' || body.prioritized === '1');
        }

        if (has('rating')) {
            updates.rating = String(body.rating || '').trim();
        }
        if (has('downloads')) {
            updates.downloads = String(body.downloads || '').trim();
        }

        // --- Multi-event support ---
        if (has('dailyReset')) {
            updates.dailyReset = (body.dailyReset === true || body.dailyReset === 'true' || body.dailyReset === '1');
        }

        // --- Secret Key update/regenerate ---
        if (has('regenerateSecret') && body.regenerateSecret === true) {
            updates.secretKey = generateSecretKey();
        } else if (has('secretKey') && body.secretKey && body.secretKey.trim() !== '') {
            updates.secretKey = String(body.secretKey).trim();
        }

        if (has('events')) {
            let events = [];
            if (Array.isArray(body.events)) {
                events = body.events.map((e, index) => {
                    const eventId = e.eventId || `event_${index + 1}`;
                    const coins = Number(e.coins) || Number(e.payout) || 0;
                    return {
                        eventId: String(eventId).trim(),
                        name: String(e.name || `Event ${index + 1}`).trim(),
                        label: String(e.label || '').trim(),
                        coins: coins,
                        payout: coins,
                    };
                }).filter(e => e.coins > 0);
            }
            updates.events = events;
        }

        // Recalculate total coins/payout from events or daily rewards, or fallback to body.payout if directly updated
        const finalEvents = has('events') ? updates.events : (currentTask.events || []);
        if (finalMultiEventEnabled && finalEvents.length > 0) {
            const sumCoins = finalEvents.reduce((sum, e) => sum + (Number(e.coins) || 0), 0);
            updates.coins = sumCoins;
            updates.payout = sumCoins;
        } else if (finalDailyRewardEnabled && finalDailyRewards.length > 0) {
            const sumCoins = finalDailyRewards.reduce((sum, e) => sum + (Number(e.coins || e.payout) || 0), 0);
            updates.coins = sumCoins;
            updates.payout = sumCoins;
        } else if (has('payout') || has('coins')) {
            const val = Number(body.coins || body.payout || 0);
            updates.coins = val;
            updates.payout = val;
        }

        if (Object.keys(updates).length === 0) {
            return res.status(400).json({
                success: false,
                message: 'No valid fields to update'
            });
        }

        // --- Mongoose Fix: Using returnDocument instead of new ---
        const updated = await DailyTask.findByIdAndUpdate(
            id,
            { $set: updates },
            {
                returnDocument: 'after', // Fixes the deprecation warning
                runValidators: true
            }
        ).lean().exec();

        if (!updated) {
            return res.status(404).json({
                success: false,
                message: 'Offer not found'
            });
        }

        try { await cacheService.delPattern('tasks:*'); } catch (_) { }

        return res.json({
            success: true,
            message: 'Offer updated successfully',
            offer: updated
        });
    } catch (err) {
        console.error('🔥 Error updating daily task:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error'
        });
    }
});

router.delete('/daily-task/:id', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const deleted = await DailyTask.findByIdAndDelete(req.params.id).lean().exec();
        if (!deleted) {
            return res.status(404).json({
                success: false,
                message: 'Daily task not found',
            });
        }

        try { await cacheService.delPattern('tasks:*'); } catch (_) { }

        return res.json({
            success: true,
            message: 'Daily task deleted successfully',
        });
    } catch (err) {
        console.error('🔥 Error deleting daily task:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error',
        });
    }
});

router.get('/admin/screenshot-proofs', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();
        const status = req.query.status || 'pending';
        const offerId = req.query.offerId;
        const searchUserId = String(req.query.userId || '').trim();
        const start = req.query.start;
        const end = req.query.end;

        const query = {};
        if (status !== 'all') query.status = status;
        if (offerId) query.offerId = String(offerId).trim();
        if (searchUserId) query.userId = { $regex: searchUserId, $options: 'i' };

        if (start && end) {
            const startDate = new Date(`${String(start).trim()}T00:00:00.000+05:30`);
            const endDate = new Date(`${String(end).trim()}T23:59:59.999+05:30`);
            if (!Number.isNaN(startDate.getTime()) && !Number.isNaN(endDate.getTime())) {
                query.createdAt = { $gte: startDate, $lte: endDate };
            }
        }

        const proofs = await ScreenshotProof.find(query).sort({ createdAt: -1 }).lean();
        return res.json({ success: true, proofs });
    } catch (err) {
        console.error('🔥 Error fetching screenshot proofs:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

router.get('/admin/task-completed-conversions', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();
        const offerId = req.query.offerId;
        const searchUserId = String(req.query.userId || '').trim();
        const start = req.query.start;
        const end = req.query.end;

        const query = {};
        if (offerId) query.offerId = String(offerId).trim();
        if (searchUserId) query.userId = { $regex: searchUserId, $options: 'i' };

        if (start && end) {
            const startDate = new Date(`${String(start).trim()}T00:00:00.000+05:30`);
            const endDate = new Date(`${String(end).trim()}T23:59:59.999+05:30`);
            if (!Number.isNaN(startDate.getTime()) && !Number.isNaN(endDate.getTime())) {
                query.createdAt = { $gte: startDate, $lte: endDate };
            }
        }

        const logs = await PostbackLogs.find(query).sort({ createdAt: -1 }).limit(500).lean();
        return res.json({ success: true, logs });
    } catch (err) {
        console.error('🔥 Error fetching task completed conversions:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

router.post('/admin/approve-task-screenshot/:id', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();
        const proofId = req.params.id;
        const proof = await ScreenshotProof.findById(proofId);
        if (!proof) return res.status(404).json({ success: false, message: 'Proof not found' });

        // Fallback coins lookup if proof.coins is 0
        let rewardCoins = Number(proof.coins) || 0;
        if (!rewardCoins) {
            const task = await DailyTask.findOne({ offerId: proof.offerId }).lean();
            if (task) {
                rewardCoins = Number(task.coins) || Number(task.payout) || 0;
            }
        }
        if (!rewardCoins) {
            const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
            const superOfferConfig = appDataDoc?.config?.superOfferConfig || {};
            rewardCoins = Number(superOfferConfig.screenshotCoins) || Math.round((Number(superOfferConfig.reward) || 768) * 0.75);
        }

        // Mark as approved
        proof.status = 'approved';
        proof.coins = rewardCoins;
        proof.reviewedAt = new Date();
        proof.reviewedBy = req.admin?.username || 'admin';
        await proof.save();

        const User = require('../admin/models/user');
        const formattedAppName = (proof.appName || 'crazyreward').toLowerCase().replace(/\s/g, '');

        if (rewardCoins > 0) {
            // Credit user wallet balance ($inc coins and totalCoins)
            await User.findOneAndUpdate(
                { $or: [{ userId: proof.userId }, { userId: String(proof.userId).trim() }, { email: proof.userEmail }] },
                { $inc: { coins: rewardCoins, totalCoins: rewardCoins } },
                { new: true }
            );
        }

        // Check if PostbackLogs entry already exists for this proof
        const existingLog = await PostbackLogs.findOne({
            appName: formattedAppName,
            userId: proof.userId,
            offerId: proof.offerId
        });

        if (!existingLog) {
            // Create PostbackLogs record with lowercased formatted appName so mobile app identifies task as COMPLETED!
            await PostbackLogs.create({
                appName: formattedAppName,
                userId: proof.userId,
                txnId: `proof_${proof._id}_${Date.now()}`,
                offerId: proof.offerId,
                eventId: proof.eventId || '',
                coins: rewardCoins,
                payout: rewardCoins,
                responseStatus: 200,
                payload: { source: 'ADMIN_SCREENSHOT_APPROVAL', proofId: String(proof._id) },
                userEmail: proof.userEmail || '',
                completedAt: new Date(),
            });
        }

        // Log Reward History
        if (rewardCoins > 0) {
            try {
                const RewardHistory = require('../admin/models/rewardHistory');
                await RewardHistory.create({
                    userId: proof.userId,
                    type: 'DAILY_TASK',
                    title: `Task Approved: ${proof.offerName || 'Daily Task'}`,
                    coins: rewardCoins,
                    status: 'SUCCESS',
                    remark: 'Screenshot verification approved by admin',
                });
            } catch (_) { }
        }

        // Send Push Notification
        try {
            const { sendNotificationViaApi } = require('../admin/middlewares/send-notification-api');
            if (typeof sendNotificationViaApi === 'function') {
                await sendNotificationViaApi({
                    title: 'Offer Reward Credited!',
                    body: `Your verification for "${proof.offerName || 'Daily Task'}" was approved! ${rewardCoins} coins credited to your wallet.`,
                    userId: proof.userId
                });
            }
        } catch (pushErr) {
            console.error('⚠️ Push notification error approving proof:', pushErr.message);
        }

        return res.json({ success: true, message: `Task proof approved & ${rewardCoins} coins credited successfully!` });
    } catch (err) {
        console.error('🔥 Error approving screenshot proof:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

router.post('/admin/reject-task-screenshot/:id', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();
        const proofId = req.params.id;
        const reason = req.body?.reason || 'Invalid proof submission';
        const mode = req.body?.mode || 'normal'; // 'normal' (allow re-upload) or 'final' (mark completed with 0 coins)

        const proof = await ScreenshotProof.findById(proofId);
        if (!proof) return res.status(404).json({ success: false, message: 'Proof not found' });

        const isFinal = mode === 'final';
        proof.status = isFinal ? 'rejected_final' : 'rejected';
        proof.rejectionReason = reason;
        proof.reviewedAt = new Date();
        proof.reviewedBy = req.admin?.username || 'admin';
        await proof.save();

        const formattedAppName = (proof.appName || 'crazyreward').toLowerCase().replace(/\s/g, '');

        if (isFinal) {
            // Create PostbackLogs entry with 0 coins so task is marked COMPLETED on app side without rewarding coins
            const existingLog = await PostbackLogs.findOne({
                appName: formattedAppName,
                userId: proof.userId,
                offerId: proof.offerId
            });

            if (!existingLog) {
                await PostbackLogs.create({
                    appName: formattedAppName,
                    userId: proof.userId,
                    txnId: `proof_reject_${proof._id}_${Date.now()}`,
                    offerId: proof.offerId,
                    eventId: proof.eventId || '',
                    coins: 0,
                    payout: 0,
                    responseStatus: 200,
                    payload: { source: 'ADMIN_PROOF_REJECT_FINAL', proofId: String(proof._id), reason: reason, status: 'rejected_final' },
                    userEmail: proof.userEmail || '',
                    completedAt: new Date(),
                });
            }
        }

        // Send Push Notification
        try {
            const { sendNotificationViaApi } = require('../admin/middlewares/send-notification-api');
            if (typeof sendNotificationViaApi === 'function') {
                await sendNotificationViaApi({
                    title: isFinal ? 'Offer Verification Rejected' : 'Offer Proof Needs Re-upload',
                    body: isFinal
                        ? `Your verification for "${proof.offerName || 'Daily Task'}" was permanently rejected. Reason: ${reason}`
                        : `Your verification for "${proof.offerName || 'Daily Task'}" was rejected. Reason: ${reason}. Please submit a valid proof.`,
                    userId: proof.userId
                });
            }
        } catch (pushErr) {
            console.error('⚠️ Push notification error rejecting proof:', pushErr.message);
        }

        return res.json({
            success: true,
            message: isFinal ? 'Task marked as permanently rejected (0 Coins).' : 'Proof rejected (User allowed to re-upload).'
        });
    } catch (err) {
        console.error('🔥 Error rejecting screenshot proof:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

// =================== DAILY TASK CATEGORIES ==========================
router.get('/daily-task-categories', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();
        const categories = await DailyTaskCategory.find().sort({ name: 1 }).lean();
        res.json({ success: true, categories });
    } catch (err) {
        console.error('Error fetching categories:', err);
        res.status(500).json({ success: false, message: 'Internal server error: ' + err.message });
    }
});

router.post('/daily-task-categories', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();
        const { name } = req.body || {};
        if (!name || !name.trim()) {
            return res.status(400).json({ success: false, message: 'Category name is required' });
        }
        const trimmedName = name.trim();

        // Case-insensitive check
        const existing = await DailyTaskCategory.findOne({ name: { $regex: new RegExp(`^${trimmedName}$`, 'i') } });
        if (existing) {
            return res.status(400).json({ success: false, message: 'Category already exists' });
        }

        const newCategory = new DailyTaskCategory({ name: trimmedName });
        await newCategory.save();
        res.json({ success: true, category: newCategory });
    } catch (err) {
        console.error('Error adding category:', err);
        res.status(500).json({ success: false, message: 'Internal server error: ' + err.message });
    }
});

router.delete('/daily-task-categories/:id', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();
        const id = req.params.id;
        const deleted = await DailyTaskCategory.findByIdAndDelete(id);
        if (!deleted) {
            return res.status(404).json({ success: false, message: 'Category not found' });
        }
        res.json({ success: true, message: 'Category deleted successfully' });
    } catch (err) {
        console.error('Error deleting category:', err);
        res.status(500).json({ success: false, message: 'Internal server error: ' + err.message });
    }
});

router.post('/daily-task-stats', adminAuth, checkPermission('dailyTasks'), async (req, res) => {
    try {
        await connectMongo();

        const { offerIds, start, end } = req.body || {};
        if (!start || !end) {
            return res.status(400).json({
                success: false,
                message: 'start and end date are required',
            });
        }

        const startDate = new Date(`${String(start).trim()}T00:00:00.000+05:30`);
        const endDate = new Date(`${String(end).trim()}T23:59:59.999+05:30`);
        if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime()) || startDate > endDate) {
            return res.status(400).json({
                success: false,
                message: 'Invalid date range',
            });
        }

        const normalizedOfferIds = Array.isArray(offerIds)
            ? offerIds.map((id) => String(id || '').trim()).filter(Boolean)
            : [];

        if (!normalizedOfferIds.length) {
            return res.status(400).json({
                success: false,
                message: 'offerIds are required',
            });
        }

        const matchStage = {
            offerId: { $in: normalizedOfferIds },
            createdAt: { $gte: startDate, $lte: endDate },
        };

        const graphPipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        $dateToString: {
                            format: '%Y-%m-%d',
                            date: '$createdAt',
                            timezone: IST_TIMEZONE,
                        },
                    },
                    totalCount: { $sum: 1 },
                    totalPayout: {
                        $sum: {
                            $convert: {
                                input: '$payout',
                                to: 'double',
                                onError: 0,
                                onNull: 0,
                            },
                        },
                    },
                },
            },
            { $sort: { _id: 1 } },
            {
                $project: {
                    date: '$_id',
                    count: '$totalCount',
                    payout: '$totalPayout',
                    _id: 0,
                },
            },
        ];

        const csvPipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        oid: '$offerId',
                        date: {
                            $dateToString: {
                                format: '%Y-%m-%d',
                                date: '$createdAt',
                                timezone: IST_TIMEZONE,
                            },
                        },
                    },
                    count: { $sum: 1 },
                    payout: {
                        $sum: {
                            $convert: {
                                input: '$payout',
                                to: 'double',
                                onError: 0,
                                onNull: 0,
                            },
                        },
                    },
                },
            },
            { $sort: { '_id.date': 1 } },
            {
                $project: {
                    offerId: '$_id.oid',
                    date: '$_id.date',
                    count: 1,
                    payout: 1,
                    _id: 0,
                },
            },
        ];

        const [graphData, csvData] = await Promise.all([
            PostbackLogs.aggregate(graphPipeline),
            PostbackLogs.aggregate(csvPipeline),
        ]);

        const totals = graphData.reduce((acc, item) => {
            acc.count += Number(item.count) || 0;
            acc.payout += Number(item.payout) || 0;
            return acc;
        }, { count: 0, payout: 0 });

        return res.json({
            success: true,
            graphData,
            csvData,
            totals,
        });

    } catch (err) {
        console.error('daily-task-stats error', err);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error',
        });
    }
});

// =================== PLAY GAMES MANAGEMENT ==========================
router.get('/play-games', adminAuth, checkPermission('games'), async (req, res) => {
    try {
        await connectMongo();
        const games = await PlayGames.find({}).sort({ createdAt: -1 }).lean().exec();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};
        return res.render('play-games/manage', {
            games,
            firebaseServices,
            activeAppName: activeApp.appName || '',
            activePage: 'games',
        });
    } catch (err) {
        console.error('🔥 Error loading play games page:', err);
        return res.status(500).send('Internal server error');
    }
});

router.post('/play-games', adminAuth, checkPermission('games'), async (req, res) => {
    try {
        await connectMongo();
        const body = req.body || {};

        const payload = {
            imagePath: String(body.imagePath || '').trim(),
            offerName: String(body.offerName || '').trim(),
            category: String(body.category || '').trim(),
            trackingTime: body.trackingTime === '' || body.trackingTime === null || body.trackingTime === undefined ? 0 : Number(body.trackingTime),
            payout: Number(body.payout),
            redirectionUrl: String(body.redirectionUrl || '').trim(),
            enabled: (body.enabled === true || body.enabled === 'true' || body.enabled === '1'),
            maxPlaysPerUser: body.maxPlaysPerUser === '' || body.maxPlaysPerUser === null || body.maxPlaysPerUser === undefined ? -1 : Number(body.maxPlaysPerUser),
            dailyEnabled: (body.dailyEnabled === true || body.dailyEnabled === 'true' || body.dailyEnabled === '1'),
            maxPlaysPerDay: body.maxPlaysPerDay === '' || body.maxPlaysPerDay === null || body.maxPlaysPerDay === undefined ? 1 : Number(body.maxPlaysPerDay),
        };

        if (!payload.imagePath || !payload.offerName || !payload.category || !payload.redirectionUrl) {
            return res.status(400).json({
                success: false,
                message: 'imagePath, offerName, category and redirectionUrl are required'
            });
        }
        if (Number.isNaN(payload.payout) || payload.payout < 0) {
            return res.status(400).json({ success: false, message: 'payout must be a non-negative number' });
        }
        if (Number.isNaN(payload.trackingTime) || payload.trackingTime < 0) {
            return res.status(400).json({ success: false, message: 'trackingTime must be a non-negative number' });
        }
        if (Number.isNaN(payload.maxPlaysPerUser) || payload.maxPlaysPerUser < 0) {
            return res.status(400).json({ success: false, message: 'maxPlaysPerUser must be 0 (block) or >= 1 (limit), -1 = unlimited' });
        }
        if (Number.isNaN(payload.maxPlaysPerDay) || payload.maxPlaysPerDay < 1) {
            return res.status(400).json({ success: false, message: 'maxPlaysPerDay must be >= 1' });
        }

        const created = await PlayGames.create(payload);
        try { await cacheService.del('games:all_enabled'); } catch (_) { }
        return res.json({ success: true, message: 'Game added successfully', game: created });
    } catch (err) {
        if (err && err.code === 11000) {
            return res.status(409).json({ success: false, message: 'This redirectionUrl already exists' });
        }
        console.error('🔥 Error adding play game:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.patch('/play-games/:id', adminAuth, checkPermission('games'), async (req, res) => {
    try {
        await connectMongo();
        const body = req.body || {};
        const updates = {};
        const has = (k) => Object.prototype.hasOwnProperty.call(body, k);

        if (has('imagePath')) {
            const v = String(body.imagePath || '').trim();
            if (!v) return res.status(400).json({ success: false, message: 'imagePath cannot be empty' });
            updates.imagePath = v;
        }

        if (has('offerName')) {
            const v = String(body.offerName || '').trim();
            if (!v) return res.status(400).json({ success: false, message: 'offerName cannot be empty' });
            updates.offerName = v;
        }

        if (has('category')) {
            const v = String(body.category || '').trim();
            if (!v) return res.status(400).json({ success: false, message: 'category cannot be empty' });
            updates.category = v;
        }

        if (has('redirectionUrl')) {
            const v = String(body.redirectionUrl || '').trim();
            if (!v) return res.status(400).json({ success: false, message: 'redirectionUrl cannot be empty' });
            updates.redirectionUrl = v;
        }

        if (has('payout')) {
            const n = Number(body.payout);
            if (Number.isNaN(n) || n < 0) return res.status(400).json({ success: false, message: 'payout must be a non-negative number' });
            updates.payout = n;
        }

        if (has('trackingTime')) {
            const n = Number(body.trackingTime);
            if (Number.isNaN(n) || n < 0) return res.status(400).json({ success: false, message: 'trackingTime must be a non-negative number' });
            updates.trackingTime = n;
        }

        if (has('enabled')) {
            updates.enabled = (body.enabled === true || body.enabled === 'true' || body.enabled === '1');
        }

        if (has('maxPlaysPerUser')) {
            const n = Number(body.maxPlaysPerUser);
            if (Number.isNaN(n) || n < 0) return res.status(400).json({ success: false, message: 'maxPlaysPerUser must be 0 (block) or >= 1' });
            updates.maxPlaysPerUser = n;
        }

        if (has('dailyEnabled')) {
            updates.dailyEnabled = (body.dailyEnabled === true || body.dailyEnabled === 'true' || body.dailyEnabled === '1');
        }

        if (has('maxPlaysPerDay')) {
            const n = Number(body.maxPlaysPerDay);
            if (Number.isNaN(n) || n < 1) return res.status(400).json({ success: false, message: 'maxPlaysPerDay must be >= 1' });
            updates.maxPlaysPerDay = n;
        }

        if (!Object.keys(updates).length) {
            return res.status(400).json({ success: false, message: 'No valid fields to update' });
        }

        const updated = await PlayGames.findByIdAndUpdate(
            req.params.id,
            { $set: updates },
            { returnDocument: 'after', runValidators: true }
        ).lean().exec();

        if (!updated) return res.status(404).json({ success: false, message: 'Game not found' });
        try { await cacheService.del('games:all_enabled'); } catch (_) { }
        return res.json({ success: true, message: 'Game updated successfully', game: updated });
    } catch (err) {
        if (err && err.code === 11000) {
            return res.status(409).json({ success: false, message: 'This redirectionUrl already exists' });
        }
        console.error('🔥 Error updating play game:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.delete('/play-games/:id', adminAuth, checkPermission('games'), async (req, res) => {
    try {
        await connectMongo();

        const deleted = await PlayGames.findByIdAndDelete(req.params.id).lean().exec();
        if (!deleted) {
            return res.status(404).json({
                success: false,
                message: 'Game not found',
            });
        }

        try { await cacheService.del('games:all_enabled'); } catch (_) { }
        return res.json({
            success: true,
            message: 'Game deleted successfully',
        });
    } catch (err) {
        console.error('🔥 Error deleting play game:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error',
        });
    }
});

// =================== READ EARN MANAGEMENT ==========================
router.get('/read-earn', adminAuth, checkPermission('readEarn'), async (req, res) => {
    try {
        await connectMongo();
        let configDoc = await ReadEarn.findOne({}).sort({ updatedAt: -1 }).exec();

        if (configDoc) {
            const pendingLimit = Number(configDoc.pendingLimits);
            const applyAt = toDateOrNull(configDoc.pendingLimitsApplyAt);
            if (Number.isFinite(pendingLimit) && pendingLimit > 0 && applyAt && applyAt <= new Date()) {
                configDoc.limits = pendingLimit;
                configDoc.pendingLimits = null;
                configDoc.pendingLimitsApplyAt = null;
                await configDoc.save();
            }
        }

        // Get start of today in IST timezone relative to UTC
        const now = new Date();
        const todayStr = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' }); // YYYY-MM-DD
        const startOfToday = new Date(`${todayStr}T00:00:00.000+05:30`);

        const [allTimeCount, todayCount, top5Grouped] = await Promise.all([
            ReadEarnLogs.countDocuments({}),
            ReadEarnLogs.countDocuments({ createdAt: { $gte: startOfToday } }),
            ReadEarnLogs.aggregate([
                { $group: { _id: '$url', count: { $sum: 1 } } },
                { $sort: { count: -1 } },
                { $limit: 5 }
            ])
        ]);

        const topUrls = top5Grouped.map(item => ({
            url: item._id,
            count: item.count
        }));

        let config = configDoc?.toObject ? configDoc.toObject() : null;
        if (config && Array.isArray(config.urlsList) && config.urlsList.length > 0) {
            const urls = config.urlsList.map(item => String(item.url || '').trim()).filter(Boolean);
            const logCounts = await ReadEarnLogs.aggregate([
                { $match: { url: { $in: urls } } },
                { $group: { _id: '$url', count: { $sum: 1 } } }
            ]);
            const clickMap = {};
            logCounts.forEach(item => {
                clickMap[String(item._id).trim()] = item.count;
            });
            config.urlsList = config.urlsList.map(item => ({
                ...item,
                clicks: clickMap[String(item.url || '').trim()] || 0
            }));
        }

        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        return res.render('read-earn/manage', {
            config: config || null,
            firebaseServices,
            activeAppName: activeApp.appName || '',
            activePage: 'read-earn',
            stats: {
                totalUrls: config?.urlsList?.length || 0,
                totalClicks: allTimeCount || 0,
                todayClicks: todayCount || 0,
                topUrls: topUrls || []
            }
        });
    } catch (err) {
        console.error('🔥 Error loading read earn page:', err);
        return res.status(500).send('Internal server error');
    }
});

router.post('/read-earn/save', adminAuth, checkPermission('readEarn'), async (req, res) => {
    try {
        await connectMongo();
        const body = req.body || {};

        // Log payload to file for debugging
        const fs = require('fs');
        try {
            fs.writeFileSync('scratch/save_payload.json', JSON.stringify(body, null, 2));
        } catch (e) {
            console.error("Failed to write save_payload.json:", e);
        }

        const limits = Number(body.limits);
        const enabled = (body.enabled === true || body.enabled === 'true' || body.enabled === '1');
        const urlsListRaw = Array.isArray(body.urlsList) ? body.urlsList : [];

        if (Number.isNaN(limits) || limits < 1) {
            return res.status(400).json({
                success: false,
                message: 'limits must be a number >= 1'
            });
        }

        const urlsList = urlsListRaw
            .map(item => {
                const doc = {
                    url: String(item?.url || '').trim(),
                    payout: Number(item?.payout),
                    trackingTime: item?.trackingTime === '' || item?.trackingTime === null || item?.trackingTime === undefined
                        ? 0
                        : Number(item?.trackingTime),
                    enabled: (item?.enabled === true || item?.enabled === 'true' || item?.enabled === '1'),
                    verificationEnabled: (item?.verificationEnabled === true || item?.verificationEnabled === 'true' || item?.verificationEnabled === '1'),
                    verificationTitle: String(item?.verificationTitle || '').trim(),
                    verificationDomain: String(item?.verificationDomain || '').trim(),
                };
                if (item?.id && mongoose.Types.ObjectId.isValid(item.id)) {
                    doc._id = new mongoose.Types.ObjectId(item.id);
                }
                return doc;
            })
            .filter(item => item.url);

        if (!urlsList.length) {
            return res.status(400).json({
                success: false,
                message: 'At least one URL is required'
            });
        }

        for (const item of urlsList) {
            if (Number.isNaN(item.payout) || item.payout < 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Each payout must be a number >= 0'
                });
            }
            if (Number.isNaN(item.trackingTime) || item.trackingTime < 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Each trackingTime must be a number >= 0'
                });
            }
        }

        const existing = await ReadEarn.findOne({}).sort({ updatedAt: -1 }).exec();
        const now = new Date();
        const nextApplyAt = getNextIstMidnightUtcDate(now);
        let updated;
        let pendingLimitScheduled = false;

        if (!existing) {
            updated = await ReadEarn.create({
                limits,
                urlsList,
                enabled,
            });
        } else {
            existing.urlsList = urlsList;
            existing.markModified('urlsList');
            existing.enabled = enabled;

            const currentLimit = Number(existing.limits) || 0;
            const pendingLimit = Number(existing.pendingLimits);
            const hasPendingLimit = Number.isFinite(pendingLimit) && pendingLimit > 0;

            if (limits !== currentLimit) {
                if (!hasPendingLimit || pendingLimit !== limits) {
                    existing.pendingLimits = limits;
                    existing.pendingLimitsApplyAt = nextApplyAt;
                    pendingLimitScheduled = true;
                }
            }

            updated = await existing.save();
        }

        try { await cacheService.del('readearn:config'); } catch (_) { }

        const payload = updated?.toObject ? updated.toObject() : updated;
        const pendingDate = toDateOrNull(payload?.pendingLimitsApplyAt);
        const pendingActive = Number.isFinite(Number(payload?.pendingLimits)) && Number(payload?.pendingLimits) > 0;
        const pendingLimitLabel = pendingDate
            ? DateTime.fromJSDate(pendingDate).setZone(IST_TIMEZONE).toFormat('dd LLL yyyy, hh:mm a')
            : null;

        return res.json({
            success: true,
            message: pendingLimitScheduled
                ? `Read & Earn config saved. New daily limit will apply on ${pendingLimitLabel} IST`
                : 'Read & Earn config saved',
            config: payload,
            pendingLimit: pendingActive ? Number(payload.pendingLimits) : null,
            pendingApplyAt: pendingDate ? pendingDate.toISOString() : null,
        });
    } catch (err) {
        console.error('🔥 Error saving read earn config:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error'
        });
    }
});

router.post('/read-earn-stats', adminAuth, checkPermission('readEarn'), async (req, res) => {
    try {
        await connectMongo();

        const { offerIds, start, end } = req.body || {};
        if (!start || !end) {
            return res.status(400).json({
                success: false,
                message: 'start and end date are required',
            });
        }

        const startDate = new Date(`${String(start).trim()}T00:00:00.000+05:30`);
        const endDate = new Date(`${String(end).trim()}T23:59:59.999+05:30`);

        if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime()) || startDate > endDate) {
            return res.status(400).json({
                success: false,
                message: 'Invalid date range',
            });
        }

        const normalizedOfferIds = Array.isArray(offerIds)
            ? offerIds.map((id) => String(id || '').trim()).filter(Boolean)
            : [];

        const matchStage = {
            createdAt: { $gte: startDate, $lte: endDate },
        };

        if (normalizedOfferIds.length) {
            matchStage.offerId = { $in: normalizedOfferIds };
        }

        const graphPipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        $dateToString: {
                            format: '%Y-%m-%d',
                            date: '$createdAt',
                            timezone: IST_TIMEZONE,
                        },
                    },
                    totalCount: { $sum: 1 },
                    totalPayout: {
                        $sum: {
                            $convert: {
                                input: '$payout',
                                to: 'double',
                                onError: 0,
                                onNull: 0,
                            },
                        },
                    },
                    urls: { $addToSet: '$url' }
                },
            },
            { $sort: { _id: 1 } },
            {
                $project: {
                    date: '$_id',
                    count: '$totalCount',
                    payout: '$totalPayout',
                    urls: 1,
                    _id: 0,
                },
            },
        ];

        const csvPipeline = [
            { $match: matchStage },
            {
                $group: {
                    _id: {
                        offerId: '$offerId',
                        date: {
                            $dateToString: {
                                format: '%Y-%m-%d',
                                date: '$createdAt',
                                timezone: IST_TIMEZONE,
                            },
                        },
                    },
                    count: { $sum: 1 },
                    payout: {
                        $sum: {
                            $convert: {
                                input: '$payout',
                                to: 'double',
                                onError: 0,
                                onNull: 0,
                            },
                        },
                    },
                    urls: { $addToSet: '$url' }
                },
            },
            { $sort: { '_id.date': 1 } },
            {
                $project: {
                    offerId: '$_id.offerId',
                    date: '$_id.date',
                    count: 1,
                    payout: 1,
                    urls: 1,
                    _id: 0,
                },
            },
        ];

        const [graphData, csvData] = await Promise.all([
            ReadEarnLogs.aggregate(graphPipeline),
            ReadEarnLogs.aggregate(csvPipeline),
        ]);

        const totals = graphData.reduce((acc, item) => {
            acc.count += Number(item.count) || 0;
            acc.payout += Number(item.payout) || 0;
            return acc;
        }, { count: 0, payout: 0 });

        return res.json({
            success: true,
            graphData,
            csvData,
            totals,
        });
    } catch (err) {
        console.error('read-earn-stats error', err);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error',
        });
    }
});

router.delete('/read-earn/url/:urlId', adminAuth, checkPermission('readEarn'), async (req, res) => {
    try {
        await connectMongo();
        const urlId = String(req.params.urlId || '').trim();

        if (!urlId) {
            return res.status(400).json({
                success: false,
                message: 'urlId is required',
            });
        }

        const config = await ReadEarn.findOne({}).sort({ updatedAt: -1 }).exec();
        if (!config) {
            return res.status(404).json({
                success: false,
                message: 'Read & Earn config not found',
            });
        }

        const before = config.urlsList.length;
        config.urlsList = config.urlsList.filter((item) => String(item?._id || '') !== urlId);

        if (config.urlsList.length === before) {
            return res.status(404).json({
                success: false,
                message: 'URL row not found',
            });
        }

        await config.save();
        try { await cacheService.del('readearn:config'); } catch (_) { }

        return res.json({
            success: true,
            message: 'URL deleted successfully',
        });
    } catch (err) {
        console.error('🔥 Error deleting read earn URL:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error',
        });
    }
});

router.post('/read-earn/urls/bulk-delete', adminAuth, checkPermission('readEarn'), async (req, res) => {
    try {
        await connectMongo();
        const { ids } = req.body || {};

        if (!Array.isArray(ids) || ids.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'ids array is required',
            });
        }

        const config = await ReadEarn.findOne({}).sort({ updatedAt: -1 }).exec();
        if (!config) {
            return res.status(404).json({
                success: false,
                message: 'Read & Earn config not found',
            });
        }

        const before = config.urlsList.length;
        const stringIds = ids.map(id => String(id).trim());
        config.urlsList = config.urlsList.filter((item) => !stringIds.includes(String(item?._id || '')));

        if (config.urlsList.length === before) {
            return res.status(404).json({
                success: false,
                message: 'No matching URL rows found to delete',
            });
        }

        await config.save();
        try { await cacheService.del('readearn:config'); } catch (_) { }

        return res.json({
            success: true,
            message: `${before - config.urlsList.length} URLs deleted successfully`,
        });
    } catch (err) {
        console.error('🔥 Error bulk deleting read earn URLs:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error',
        });
    }
});


// =========================== GIVEAWAY MANAGEMENT =============================
router.get('/add-giveaway', adminAuth, checkPermission('giveaways'), (req, res) => {
    const firebaseServices = req.firebaseServices || [];
    const activeApp = pickFirebaseService(firebaseServices);

    res.render('giveaway/add', {
        firebaseServices,
        activeAppName: activeApp?.appName || '',
    });
});

router.get('/manage-giveaway', adminAuth, checkPermission('giveaways'), async (req, res) => {
    try {
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        await connectMongo();
        const giveawaysMongo = await Giveaway.find({}).sort({ createdAt: -1 }).lean();

        const giveaways = giveawaysMongo.map((data) => {
            return {
                id: data.giveawayId || data._id.toString(),
                _id: data._id.toString(),
                giveawayId: data.giveawayId || data._id.toString(),
                title: String(data.title || ''),
                description: String(data.description || ''),
                bannerUrl: String(data.image || data.bannerUrl || ''),
                totalSlots: Number(data.totalSlots || 0),
                joinedCount: Array.isArray(data.joinedUsers || data.participants) ? (data.joinedUsers || data.participants).length : 0,
                status: String(data.status || 'active'),
                createdAt: toIsoDate(data.createdAt),
                endDate: toIsoDate(data.endDate),
                declaresAt: toIsoDate(data.declaresAt || data.endDate || data.createdAt),
                declaredAt: toIsoDate(data.declaredAt),
            };
        });

        return res.render('giveaway/manage', {
            firebaseServices,
            activeAppName: activeApp.appName || '',
            activePage: 'giveaways',
            giveaways,
        });
    } catch (error) {
        console.error('🔥 Error loading giveaways:', error);
        return res.render('giveaway/manage', {
            firebaseServices: req.firebaseServices || [],
            activeAppName: '',
            giveaways: [],
        });
    }
});

router.patch('/giveaway/:id/winner-status', adminAuth, checkPermission('giveaways'), async (req, res) => {
    try {
        const { id } = req.params;
        const body = req.body || {};
        const userId = String(body.userId || '').trim();
        const status = String(body.status || '').trim();

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        await connectMongo();
        const isObjectId = mongoose.Types.ObjectId.isValid(id);
        const query = isObjectId ? { $or: [{ _id: id }, { giveawayId: id }] } : { giveawayId: id };
        const giveaway = await Giveaway.findOne(query);
        if (!giveaway) {
            return res.status(404).json({ success: false, message: 'Giveaway not found' });
        }

        if (!giveaway.winnerStatuses) giveaway.winnerStatuses = new Map();
        if (giveaway.winnerStatuses instanceof Map) {
            giveaway.winnerStatuses.set(userId, status);
        } else {
            giveaway.winnerStatuses[userId] = status;
        }
        giveaway.markModified('winnerStatuses');

        // If status changed to claimed manually by admin, credit coins if coins > 0
        if (status === 'claimed') {
            const winnerRanks = giveaway.winnerRanks || [];
            const match = winnerRanks.find(w => w && w.userId === userId);
            const rank = match ? match.rank : 1;
            const rewards = giveaway.rewards || [];
            const reward = rewards.find(r => r && r.productRank === rank) || rewards[0] || {};
            const coins = Number(reward.coins) || 0;
            if (coins > 0) {
                await User.updateOne({ userId }, { $inc: { coins: coins, totalEarnedCoins: coins } });
            }
        }

        await giveaway.save();
        try { await cacheService.del('giveaways:raw_list'); } catch (_) { }
        return res.json({ success: true, message: 'Winner status updated successfully' });
    } catch (error) {
        console.error('🔥 Error updating winner status:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.patch('/giveaway/:id/member-priority', adminAuth, checkPermission('giveaways'), async (req, res) => {
    try {
        const { id } = req.params;
        const body = req.body || {};
        const userId = String(body.userId || '').trim();
        const prioritized = (body.prioritized === true || body.prioritized === 'true' || body.prioritized === 1);
        const rank = parseInt(body.rank || 0) || 0;

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        await connectMongo();
        const isObjectId = mongoose.Types.ObjectId.isValid(id);
        const query = isObjectId ? { $or: [{ _id: id }, { giveawayId: id }] } : { giveawayId: id };
        const giveaway = await Giveaway.findOne(query);
        if (!giveaway) {
            return res.status(404).json({ success: false, message: 'Giveaway not found' });
        }

        if (!giveaway.priorityUsers) giveaway.priorityUsers = [];
        if (prioritized) {
            if (!giveaway.priorityUsers.includes(userId)) {
                giveaway.priorityUsers.push(userId);
            }
        } else {
            giveaway.priorityUsers = giveaway.priorityUsers.filter(u => u !== userId);
        }

        if (!giveaway.assignedRanks) giveaway.assignedRanks = [];
        giveaway.assignedRanks = giveaway.assignedRanks.filter(r => r.userId !== userId && (rank === 0 || r.rank !== rank));
        if (rank > 0) {
            giveaway.assignedRanks.push({ userId, rank });
        }

        await giveaway.save();
        try { await cacheService.del('giveaways:raw_list'); } catch (_) { }
        return res.json({ success: true, message: 'Member priority and rank updated successfully' });
    } catch (error) {
        console.error('🔥 Error updating member priority:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.get(['/giveaway/:id/details', '/admin/giveaway/:id/details'], adminAuth, checkPermission('giveaways'), async (req, res) => {
    try {
        const { id } = req.params;
        await connectMongo();
        const isObjectId = mongoose.Types.ObjectId.isValid(id);
        const query = isObjectId ? { $or: [{ _id: id }, { giveawayId: id }] } : { giveawayId: id };
        const giveaway = await Giveaway.findOne(query).lean();

        if (!giveaway) {
            return res.status(404).json({ success: false, message: 'Giveaway not found' });
        }

        const participantIds = giveaway.joinedUsers || giveaway.participants || [];
        const winnerIds = giveaway.winners || [];

        const allUserIds = Array.from(new Set([...participantIds, ...winnerIds]));
        const dbUsers = await User.find({ userId: { $in: allUserIds } }).lean();

        const userMap = {};
        dbUsers.forEach(u => {
            userMap[u.userId] = {
                name: u.displayName || u.name || '',
                email: u.email || '',
                photoUrl: u.photoUrl || '',
            };
        });

        const joinedAtMap = {};
        if (Array.isArray(giveaway.joinedHistory)) {
            giveaway.joinedHistory.forEach(h => {
                if (h && h.userId) joinedAtMap[h.userId] = h.joinedAt;
            });
        }
        const prioritySet = new Set(giveaway.priorityUsers || []);
        const assignedRankMap = {};
        if (Array.isArray(giveaway.assignedRanks)) {
            giveaway.assignedRanks.forEach(ar => {
                if (ar && ar.userId) assignedRankMap[ar.userId] = ar.rank;
            });
        }
        const winnerRankMap = {};
        if (Array.isArray(giveaway.winnerRanks)) {
            giveaway.winnerRanks.forEach(wr => {
                if (wr && wr.userId) winnerRankMap[wr.userId] = wr.rank;
            });
        }

        const winnerStatusesMap = giveaway.winnerStatuses ? (giveaway.winnerStatuses instanceof Map ? Object.fromEntries(giveaway.winnerStatuses) : giveaway.winnerStatuses) : {};

        const rewards = giveaway.rewards || [];
        const rewardByRank = {};
        rewards.forEach(rw => {
            if (rw) rewardByRank[rw.productRank || 1] = rw;
        });

        const participants = participantIds.map(uid => ({
            userId: uid,
            name: userMap[uid]?.name || '',
            email: userMap[uid]?.email || '',
            photoUrl: userMap[uid]?.photoUrl || '',
            joinedAt: toIsoDate(joinedAtMap[uid] || giveaway.updatedAt || giveaway.createdAt || new Date()),
            prioritized: prioritySet.has(uid),
            assignedRank: assignedRankMap[uid] || 0,
        }));

        const winners = winnerIds.map((uid, index) => {
            const rank = winnerRankMap[uid] || assignedRankMap[uid] || (index + 1);
            const reward = rewardByRank[rank] || rewards[index] || {};
            const isAuto = reward.autoDistribute !== false;
            const currentStatus = winnerStatusesMap[uid] || (isAuto ? 'claimed' : 'requested');
            return {
                userId: uid,
                name: userMap[uid]?.name || '',
                email: userMap[uid]?.email || '',
                photoUrl: userMap[uid]?.photoUrl || '',
                joinedAt: toIsoDate(joinedAtMap[uid] || giveaway.updatedAt || giveaway.createdAt || new Date()),
                declaredAt: toIsoDate(giveaway.declaredAt || giveaway.declaresAt || giveaway.updatedAt || new Date()),
                prioritized: prioritySet.has(uid),
                rank: rank,
                rewardName: reward.productName || 'Reward',
                rewardImage: reward.productImage || '',
                status: currentStatus,
            };
        });

        return res.json({
            success: true,
            data: {
                id: giveaway.giveawayId || giveaway._id.toString(),
                _id: giveaway._id.toString(),
                giveawayId: giveaway.giveawayId || giveaway._id.toString(),
                title: String(giveaway.title || ''),
                description: String(giveaway.description || ''),
                bannerUrl: String(giveaway.image || giveaway.bannerUrl || ''),
                totalSlots: Number(giveaway.totalSlots || 0),
                joinedCount: participantIds.length,
                status: String(giveaway.status || 'active'),
                createdAt: toIsoDate(giveaway.createdAt),
                startsAt: toIsoDate(giveaway.startsAt || giveaway.createdAt),
                endDate: toIsoDate(giveaway.endDate),
                declaresAt: toIsoDate(giveaway.declaresAt || giveaway.endDate),
                declaredAt: toIsoDate(giveaway.declaredAt || (giveaway.status === 'declared' || giveaway.status === 'completed' ? giveaway.updatedAt : null)),
                rewards: giveaway.rewards || [],
                participants,
                winners,
            }
        });
    } catch (error) {
        console.error('🔥 Error loading giveaway details:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.post(['/giveaway/:id/declare', '/admin/giveaway/:id/declare'], adminAuth, checkPermission('giveaways'), async (req, res) => {
    try {
        const { id } = req.params;
        await connectMongo();

        const isObjectId = mongoose.Types.ObjectId.isValid(id);
        const query = isObjectId ? { $or: [{ _id: id }, { giveawayId: id }] } : { giveawayId: id };

        let giveaway = await Giveaway.findOne(query);
        if (!giveaway && isObjectId) {
            giveaway = await Giveaway.findById(id).catch(() => null);
        }
        if (!giveaway) {
            giveaway = await Giveaway.findOne({ giveawayId: id }).catch(() => null);
        }

        if (!giveaway) {
            return res.status(404).json({ success: false, message: 'Giveaway not found' });
        }

        const participants = [
            ...(giveaway.joinedUsers || []),
            ...(giveaway.participants || []),
            ...((giveaway.joinedHistory || []).map(h => h && h.userId).filter(Boolean)),
            ...((giveaway.assignedRanks || []).map(r => r && r.userId).filter(Boolean)),
            ...(giveaway.priorityUsers || [])
        ].filter((v, i, a) => v && a.indexOf(v) === i);

        if (participants.length === 0) {
            await Giveaway.updateOne(
                { _id: giveaway._id },
                {
                    $set: {
                        winners: [],
                        winnerRanks: [],
                        status: 'declared',
                        declaresAt: new Date(),
                        declaredAt: new Date(),
                    }
                }
            );
            return res.json({ success: true, message: 'Giveaway marked as declared (0 participants)', winners: [] });
        }

        const rewards = Array.isArray(giveaway.rewards) && giveaway.rewards.length > 0
            ? giveaway.rewards
            : [{ productRank: 1, productName: 'Grand Prize', coins: giveaway.prizeCoins || 100 }];

        const numRewards = Math.min(rewards.length, participants.length);
        const assignedRanks = giveaway.assignedRanks || [];
        const priorityUsers = giveaway.priorityUsers || [];

        // Build map for explicit assigned ranks: rankNumber -> userId
        const rankToUserMap = {};
        assignedRanks.forEach(ar => {
            if (ar && ar.rank > 0 && ar.userId && participants.includes(ar.userId)) {
                rankToUserMap[ar.rank] = ar.userId;
            }
        });

        const winnersList = [];
        const usedUserIds = new Set();

        // 1. Assign explicit assigned rank users first
        for (let r = 1; r <= numRewards; r++) {
            if (rankToUserMap[r] && !usedUserIds.has(rankToUserMap[r])) {
                const uid = rankToUserMap[r];
                winnersList.push({ userId: uid, rank: r });
                usedUserIds.add(uid);
            }
        }

        // 2. Fill unassigned ranks with remaining priority users first, then remaining genuine participants
        const remainingParticipants = participants.filter(uid => !usedUserIds.has(uid));
        const remainingPriority = remainingParticipants.filter(uid => priorityUsers.includes(uid));

        for (let r = 1; r <= numRewards; r++) {
            if (winnersList.some(w => w.rank === r)) continue;

            let winnerId = null;
            if (remainingPriority.length > 0) {
                const idx = Math.floor(Math.random() * remainingPriority.length);
                winnerId = remainingPriority[idx];
                remainingPriority.splice(idx, 1);
                const pos = remainingParticipants.indexOf(winnerId);
                if (pos !== -1) remainingParticipants.splice(pos, 1);
            } else if (remainingParticipants.length > 0) {
                const idx = Math.floor(Math.random() * remainingParticipants.length);
                winnerId = remainingParticipants[idx];
                remainingParticipants.splice(idx, 1);
            }

            if (winnerId) {
                winnersList.push({ userId: winnerId, rank: r });
                usedUserIds.add(winnerId);
            }
        }

        const winnerStatusesMap = {};
        for (const w of winnersList) {
            const reward = (giveaway.rewards || []).find(r => r && r.productRank === w.rank) || (giveaway.rewards || [])[0] || {};
            const coins = Number(reward.coins) || (w.rank === 1 ? (giveaway.prizeCoins || 0) : 0);
            const isAuto = reward.autoDistribute !== false;

            if (isAuto && coins > 0) {
                // Auto result ON & Coins reward: credit coins immediately, log history, send push notification
                await User.updateOne({ userId: w.userId }, { $inc: { coins: coins, totalEarnedCoins: coins } }).catch(() => { });
                await RewardHistory.create({
                    appName: giveaway.appName || '',
                    userId: w.userId,
                    provider: `Giveaway Reward (${giveaway.title || 'Giveaway'})`,
                    coins: coins,
                    rewardType: 'coin',
                    orderId: `gw_${giveaway.giveawayId || giveaway._id}_${w.userId}_${Date.now()}`,
                    timestamp: new Date()
                }).catch(err => console.error('⚠️ RewardHistory create warning:', err));

                winnerStatusesMap[w.userId] = 'claimed';

                // Send OneSignal push notification
                try {
                    const { sendNotificationViaApi } = require('../admin/middlewares/send-notification-api');
                    if (typeof sendNotificationViaApi === 'function') {
                        await sendNotificationViaApi({
                            title: '🎉 Giveaway Winner!',
                            body: `Congratulations! You won ${coins} coins in ${giveaway.title || 'Giveaway'}! Coins have been credited to your wallet.`,
                            userId: w.userId
                        });
                    }
                } catch (pushErr) {
                    console.error('⚠️ OneSignal push notification error:', pushErr.message);
                }
            } else if (!isAuto && coins > 0) {
                // Auto result OFF & Coins reward: Winner must manually claim in app -> status 'pending'
                winnerStatusesMap[w.userId] = 'pending';
            } else {
                // Physical product / item: status 'requested' (admin manually updates)
                winnerStatusesMap[w.userId] = 'requested';
            }
        }

        const now = new Date();
        await Giveaway.updateOne(
            { _id: giveaway._id },
            {
                $set: {
                    winners: winnersList.map(w => w.userId),
                    winnerRanks: winnersList,
                    winnerStatuses: winnerStatusesMap,
                    status: 'declared',
                    declaresAt: now,
                    declaredAt: now,
                    endDate: now,
                }
            }
        );

        const winnerId = winnersList[0]?.userId || '';
        return res.json({ success: true, message: 'Giveaway winners declared successfully!', winnerId, winners: winnersList });
    } catch (error) {
        console.error('🔥 Error declaring giveaway:', error);
        return res.status(500).json({ success: false, message: 'Internal server error: ' + (error.message || error) });
    }
});

router.patch('/giveaway/:id', adminAuth, checkPermission('giveaways'), async (req, res) => {
    try {
        const { id } = req.params;
        const body = req.body || {};
        await connectMongo();

        const updates = {};
        if (body.appName) updates.appName = String(body.appName).trim();
        if (body.title) updates.title = String(body.title).trim();
        if (body.description) updates.description = String(body.description).trim();
        if (body.bannerUrl || body.image) {
            const url = String(body.bannerUrl || body.image).trim();
            updates.bannerUrl = url;
            updates.image = url;
        }
        if (body.totalSlots !== undefined && body.totalSlots !== null) updates.totalSlots = Number(body.totalSlots);
        if (body.rewards) updates.rewards = body.rewards;
        if (body.startsAt || body.createdAt) {
            const startDate = new Date(body.startsAt || body.createdAt);
            if (!isNaN(startDate.getTime())) {
                updates.startsAt = startDate;
                updates.createdAt = startDate;
            }
        }
        if (body.declaresAt || body.endDate) {
            const endDate = new Date(body.declaresAt || body.endDate);
            if (!isNaN(endDate.getTime())) {
                updates.declaresAt = endDate;
                updates.endDate = endDate;
            }
        }
        if (body.status) updates.status = String(body.status).trim();

        const isObjectId = mongoose.Types.ObjectId.isValid(id);
        const query = isObjectId ? { $or: [{ _id: id }, { giveawayId: id }] } : { giveawayId: id };
        await Giveaway.findOneAndUpdate(query, { $set: updates }, { new: true });
        return res.json({ success: true, message: 'Giveaway updated successfully' });
    } catch (error) {
        console.error('🔥 Error updating giveaway:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.delete('/giveaway/:id', adminAuth, checkPermission('giveaways'), async (req, res) => {
    try {
        const { id } = req.params;
        await connectMongo();

        const isObjectId = mongoose.Types.ObjectId.isValid(id);
        const query = isObjectId ? { $or: [{ _id: id }, { giveawayId: id }] } : { giveawayId: id };
        await Giveaway.findOneAndDelete(query);
        return res.json({
            success: true,
            message: 'Giveaway deleted successfully',
        });
    } catch (error) {
        console.error('🔥 Error deleting giveaway:', error);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.post('/createGiveaway', adminAuth, checkPermission('giveaways'), async (req, res) => {
    try {
        const { appName, title, description, bannerUrl, totalSlots, rewards, startsAt, declaresAt } = req.body;

        if (!appName || !title || !description || !bannerUrl || !totalSlots || !rewards || !startsAt || !declaresAt) {
            return res.status(400).json({
                success: false,
                message: 'Missing required fields: appName, title, description, bannerUrl, totalSlots, rewards, startsAt, declaresAt'
            });
        }

        await connectMongo();

        const prizeCoins = Array.isArray(rewards) ? rewards.reduce((acc, r) => acc + (Number(r.coins) || 0), 0) : 100;
        const giveawayDoc = await Giveaway.create({
            giveawayId: 'gw_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
            appName: appName || '',
            title,
            description,
            image: bannerUrl,
            bannerUrl: bannerUrl,
            prizeCoins: prizeCoins || 100,
            totalSlots: Number(totalSlots),
            joinedUsers: [],
            participants: [],
            winners: [],
            status: 'active',
            startsAt: new Date(startsAt),
            declaresAt: new Date(declaresAt),
            endDate: new Date(declaresAt),
            rewards: rewards || []
        });

        try { await cacheService.del('giveaways:raw_list'); } catch (_) { }

        return res.status(200).json({
            success: true,
            message: 'Giveaway created successfully',
            data: giveawayDoc,
        });
    } catch (error) {
        console.error('🔥 Error creating giveaway:', error?.message);
        return res.status(500).json({
            success: false,
            message: upstreamMessage || error?.message || 'Internal server error while creating giveaway'
        });
    }
});

// ADD APP BONUS
router.post('/add-app-bonus', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const email = String(body.email || '').trim();
        const userId = String(body.userId || '').trim();
        const payout = Number(body.payout);

        if (!email && !userId) {
            return res.status(400).json({ success: false, message: 'email or userId is required' });
        }
        if (!Number.isFinite(payout) || payout <= 0) {
            return res.status(400).json({ success: false, message: 'payout must be a number > 0' });
        }

        await connectMongo();
        const conversionRate = await getAppConversionRate();
        const coins = Math.round(payout * conversionRate);

        const query = { $or: [] };
        if (userId) query.$or.push({ userId });
        if (email) query.$or.push({ email: email.toLowerCase() });

        const user = await User.findOne(query);
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        user.coins = (Number(user.coins) || 0) + coins;
        user.totalCoins = (Number(user.totalCoins) || 0) + coins;
        await user.save();

        const appName = user.appName || req.body.appName || '';
        const orderId = `BONUS_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;

        await RewardHistory.create({
            appName: appName,
            orderId: orderId,
            userId: user.userId,
            userName: user.displayName || user.name || 'User',
            email: user.email || '',
            coins,
            provider: 'Admin Bonus',
            offerName: 'Bonus Credit',
            timestamp: new Date(),
        }).catch(err => console.error('⚠️ RewardHistory create warning:', err));

        // Send OneSignal push notification
        try {
            const sendNotificationViaApi = require('../admin/middlewares/send-notification-api');
            await sendNotificationViaApi({
                userId: user.userId,
                title: '💰 Bonus Added!',
                body: `🎉 Added +${coins} coins to your account!`,
            });
        } catch (pushErr) {
            console.error('⚠️ OneSignal push error:', pushErr?.message || pushErr);
        }

        return res.json({
            success: true,
            message: `App bonus of ${coins} coins credited successfully`,
            data: { coins }
        });
    } catch (err) {
        console.error('❌ App bonus error:', err);
        return res.status(500).json({ success: false, message: 'Failed to add app bonus' });
    }
});

// DEDUCT USER COINS
router.post('/deduct-user-coins', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const email = String(body.email || '').trim();
        const userId = String(body.userId || '').trim();
        const payout = Number(body.payout);

        if (!email && !userId) {
            return res.status(400).json({ success: false, message: 'email or userId is required' });
        }
        if (!Number.isFinite(payout) || payout <= 0) {
            return res.status(400).json({ success: false, message: 'payout must be a number > 0' });
        }

        await connectMongo();
        const conversionRate = await getAppConversionRate();
        const coins = Math.round(payout * conversionRate);

        const query = { $or: [] };
        if (userId) query.$or.push({ userId });
        if (email) query.$or.push({ email: email.toLowerCase() });

        const user = await User.findOne(query);
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const currentCoins = Number(user.coins) || 0;
        if (currentCoins < coins) {
            return res.status(400).json({ success: false, message: `Insufficient wallet balance (${currentCoins} coins available)` });
        }

        user.coins = Math.max(0, currentCoins - coins);
        await user.save();

        const appName = user.appName || req.body.appName || '';
        const orderId = `DEDUCT_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;

        await RewardHistory.create({
            appName: appName,
            orderId: orderId,
            userId: user.userId,
            userName: user.displayName || user.name || 'User',
            email: user.email || '',
            coins: -coins,
            provider: 'Deducted By Admin',
            offerName: 'Admin Coins Deduction',
            timestamp: new Date(),
        }).catch(err => console.error('⚠️ RewardHistory create warning:', err));

        // Send OneSignal push notification
        try {
            const sendNotificationViaApi = require('../admin/middlewares/send-notification-api');
            await sendNotificationViaApi({
                userId: user.userId,
                title: '📉 Coins Deducted',
                body: `⚠️ Deducted ${coins} coins from your account.`,
            });
        } catch (pushErr) {
            console.error('⚠️ OneSignal push error:', pushErr?.message || pushErr);
        }

        return res.json({
            success: true,
            message: `Deducted ${coins} coins successfully`,
            data: { coins, afterCoins: user.coins }
        });
    } catch (err) {
        console.error('❌ Deduct user coins error:', err);
        return res.status(500).json({ success: false, message: 'Failed to deduct coins' });
    }
});

// FULL ACCOUNT DOC DELETE
router.post('/delete-user-account', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const email = String(body.email || '').trim();
        const userId = String(body.userId || '').trim();

        if (!email && !userId) {
            return res.status(400).json({ success: false, message: 'email or userId is required' });
        }

        await connectMongo();
        const deleteQuery = { $or: [] };
        if (userId) deleteQuery.$or.push({ userId });
        if (email) deleteQuery.$or.push({ email: email.toLowerCase() });

        const result = await User.deleteOne(deleteQuery);
        if (result.deletedCount === 0) {
            return res.status(404).json({ success: false, message: 'User not found in MongoDB' });
        }

        return res.json({
            success: true,
            message: `User account document deleted successfully (${userId || email})`,
        });
    } catch (err) {
        console.error('🔥 Error deleting user account:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to delete account document',
        });
    }
});

// Reusable helper for full A-to-Z data wipe across MongoDB, Redis, and Firebase
async function executeUserFullWipe({ userId, email, selectedApp }) {
    await connectMongo();

    // 0. If email is not provided, fetch it from MongoDB User document before deletion
    if (!email) {
        try {
            const userDoc = await User.findOne({ userId }).select('email gmail').lean();
            if (userDoc) {
                email = userDoc.email || userDoc.gmail || '';
            }
        } catch (_) {}
    }

    // Safe delete helper so one failing collection cleanup never breaks the entire wipe operation
    const safeDelete = async (model, query) => {
        if (!model) return 0;
        try {
            const res = await model.deleteMany(query);
            return res.deletedCount || 0;
        } catch (e) {
            console.warn(`[WipeData Warning] Cleanup error:`, e.message);
            return 0;
        }
    };

    // 1. Delete main User document
    const userQuery = {
        $or: [
            { userId },
            ...(email ? [{ email }, { gmail: email }] : [{ email: userId }, { gmail: userId }])
        ]
    };
    await User.deleteMany(userQuery);

    // 2. Load all secondary models safely
    let PostbackErrorLogs, UserDailyChallenge, BattleHistory, BattleLeaderboard, BattleLeaderboardHistory, BattleMatch, BattleRoom, BattleSession, GamePlayLogs, PendingReadEarnToken, UsedReadEarnToken;
    try { PostbackErrorLogs = require('../admin/models/postbackErrorLogs'); } catch (_) { }
    try { UserDailyChallenge = require('../admin/models/userDailyChallenge'); } catch (_) { }
    try { BattleHistory = require('../battle-arena/models/battleHistory'); } catch (_) { try { BattleHistory = require('../admin/models/battleHistory'); } catch (_) { } }
    try { BattleLeaderboard = require('../battle-arena/models/battleLeaderboard'); } catch (_) { try { BattleLeaderboard = require('../admin/models/battleLeaderboard'); } catch (_) { } }
    try { BattleLeaderboardHistory = require('../battle-arena/models/battleLeaderboardHistory'); } catch (_) { try { BattleLeaderboardHistory = require('../admin/models/battleLeaderboardHistory'); } catch (_) { } }
    try { BattleMatch = require('../battle-arena/models/battleMatch'); } catch (_) { try { BattleMatch = require('../admin/models/battleMatch'); } catch (_) { } }
    try { BattleRoom = require('../battle-arena/models/battleRoom'); } catch (_) { try { BattleRoom = require('../admin/models/battleRoom'); } catch (_) { } }
    try { BattleSession = require('../battle-arena/models/battleSession'); } catch (_) { }
    try { GamePlayLogs = require('../admin/models/gamePlayLogs'); } catch (_) { }
    try { PendingReadEarnToken = require('../admin/models/pendingReadEarnToken'); } catch (_) { }
    try { UsedReadEarnToken = require('../admin/models/usedReadEarnToken'); } catch (_) { }

    // 3. Delete related transaction, offer, and activity records in parallel safely
    const uidMatch = { $or: [{ userId }, { userEmail: userId }, ...(email ? [{ userEmail: email }, { email }] : [])] };

    await Promise.all([
        safeDelete(RewardHistory, uidMatch),
        safeDelete(RewardRecord, uidMatch),
        safeDelete(PayoutHistory, uidMatch),
        safeDelete(PayoutRecord, uidMatch),
        safeDelete(BlockedHistory, uidMatch),
        safeDelete(SuspiciousActivity, uidMatch),
        safeDelete(ReadEarnLogs, { userId }),
        safeDelete(OfferwallRecord, { userId }),
        safeDelete(SupportRequest, uidMatch),
        safeDelete(PromotionRequest, uidMatch),
        safeDelete(Promoter, uidMatch),
        safeDelete(PostbackLogs, { userId }),
        safeDelete(PostbackErrorLogs, { userId }),
        safeDelete(SuperOfferHistory, uidMatch),
        safeDelete(ScreenshotProof, uidMatch),
        safeDelete(UserDailyChallenge, { userId }),
        safeDelete(DailyEarningSummary, { userId }),
        safeDelete(Leaderboard, { userId }),
        safeDelete(BattleHistory, { userId }),
        safeDelete(BattleLeaderboard, { userId }),
        safeDelete(BattleLeaderboardHistory, { userId }),
        safeDelete(BattleSession, { userId }),
        safeDelete(GamePlayLogs, { userId }),
        safeDelete(PendingReadEarnToken, { userId }),
        safeDelete(UsedReadEarnToken, { userId }),
        safeDelete(BattleRoom, { "players.userId": userId }),
        safeDelete(BattleMatch, {
            $or: [
                { "player1.userId": userId },
                { "player2.userId": userId },
                { "players.userId": userId }
            ]
        })
    ]);

    // 4. Invalidate all Redis user cache entries
    try {
        if (cacheService && cacheService.del) {
            await cacheService.del('user_data_' + userId);
            await cacheService.del('so_user_' + userId);
            if (email) {
                await cacheService.del('user_data_' + email);
                await cacheService.del('so_user_' + email);
            }
        }
    } catch (_) { }

    // 5. Pull user from giveaways
    try {
        await Giveaway.updateMany(
            {},
            {
                $pull: {
                    joinedHistory: { userId },
                    assignedRanks: { userId },
                    winnerRanks: { userId }
                }
            }
        );
    } catch (giveawayErr) {
        console.warn('[WipeData Warning] Giveaway pull error:', giveawayErr.message);
    }

    // 6. Delete Firebase Auth user if Firebase Service Account exists
    let firebaseDeleted = false;
    try {
        if (selectedApp) {
            try {
                const serviceDoc = await FirebaseService.findOne({ appName: selectedApp.toLowerCase() }).lean();
                if (serviceDoc && serviceDoc.serviceAccount) {
                    const adminApp = getOrInitFirebase(serviceDoc.appName || selectedApp, serviceDoc.serviceAccount);
                    if (adminApp) {
                        await adminApp.auth().deleteUser(userId);
                        firebaseDeleted = true;
                        console.log(`[Firebase] User ${userId} auth deleted from ${serviceDoc.appName}`);
                    }
                }
            } catch (err) {
                console.warn(`[Firebase] Failed deleting from selected app ${selectedApp}:`, err.message);
            }
        }

        if (!firebaseDeleted) {
            const allServices = await FirebaseService.find().lean();
            if (allServices && allServices.length > 0) {
                for (const sDoc of allServices) {
                    try {
                        if (sDoc.serviceAccount) {
                            const adminApp = getOrInitFirebase(sDoc.appName || 'default', sDoc.serviceAccount);
                            if (adminApp) {
                                await adminApp.auth().deleteUser(userId);
                                firebaseDeleted = true;
                                console.log(`[Firebase] User ${userId} auth deleted from ${sDoc.appName}`);
                                break;
                            }
                        }
                    } catch (_) {}
                }
            }
        }

        if (!firebaseDeleted) {
            const admin = require('firebase-admin');
            const defaultApp = admin.apps && admin.apps.length ? admin.app() : null;
            if (defaultApp) {
                await defaultApp.auth().deleteUser(userId);
                firebaseDeleted = true;
                console.log(`[Firebase] User ${userId} auth deleted from default app.`);
            }
        }
    } catch (firebaseErr) {
        console.error('⚠️ Firebase auth user deletion error:', firebaseErr.message);
    }

    return { success: true, firebaseDeleted };
}

// WIPE ALL USER DATA
router.post('/wipe-user-data', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const email = String(body.email || '').trim();
        const userId = String(body.userId || '').trim();
        const selectedApp = String(body.selectedApp || body.appName || '').trim();

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required for wiping data' });
        }

        const wipeRes = await executeUserFullWipe({ userId, email, selectedApp });

        return res.json({
            success: true,
            message: `User account (${userId}) and all associated data wiped successfully!${wipeRes.firebaseDeleted ? ' Firebase Auth account deleted.' : ''}`,
        });
    } catch (err) {
        console.error('🔥 Error wiping user data:', err);
        return res.status(500).json({
            success: false,
            message: `Error wiping user data: ${err.message || 'Server error'}`,
        });
    }
});

// BULK ACCOUNT DOC DELETE
router.post('/bulk-delete-users', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const userIds = body.userIds;

        if (!Array.isArray(userIds) || userIds.length === 0) {
            return res.status(400).json({ success: false, message: 'userIds array is required' });
        }

        await connectMongo();
        const result = await User.deleteMany({ userId: { $in: userIds } });

        return res.json({
            success: true,
            message: `Successfully deleted ${result.deletedCount} user accounts`,
        });
    } catch (err) {
        console.error('🔥 Error bulk deleting user accounts:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to bulk delete account documents',
        });
    }
});

// BLOCK USER
router.post('/block-user', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const email = String(body.email || '').trim();
        const userId = String(body.userId || '').trim();
        const reason = String(body.reason || '').trim();
        const block = normalizeBooleanInput(body.block);

        if (block === null) {
            return res.status(400).json({ success: false, message: `Invalid 'block' value. Must be boolean.` });
        }
        if (!email && !userId) {
            return res.status(400).json({ success: false, message: 'email or userId is required' });
        }

        await connectMongo();
        const query = { $or: [] };
        if (userId) query.$or.push({ userId });
        if (email) query.$or.push({ email: email.toLowerCase() });

        const user = await User.findOne(query);
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found in MongoDB' });
        }

        user.isBlocked = block;
        user.blocked = block;
        user.blockReason = block ? (reason || 'Blocked by admin') : '';
        user.blockUpdatedAt = new Date();
        await user.save();

        const stateText = block ? 'blocked' : 'unblocked';
        return res.json({ success: true, message: `Account ${stateText} successfully` });
    } catch (err) {
        console.error('❌ Block user Account error:', err);
        return res.status(500).json({ success: false, message: 'Failed to block/unblock account' });
    }
});

// BLOCK PAYOUT
router.post('/block-payout', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const email = String(body.email || '').trim();
        const userId = String(body.userId || '').trim();
        const reason = String(body.reason || '').trim();
        const block = normalizeBooleanInput(body.block);

        if (block === null) {
            return res.status(400).json({ success: false, message: `Invalid 'block' value. Must be boolean.` });
        }
        if (!email && !userId) {
            return res.status(400).json({ success: false, message: 'email or userId is required' });
        }

        await connectMongo();
        const query = { $or: [] };
        if (userId) query.$or.push({ userId });
        if (email) query.$or.push({ email: email.toLowerCase() });

        const user = await User.findOne(query);
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found in MongoDB' });
        }

        user.payoutBlocked = block;
        user.payoutBlockReason = block ? (reason || 'Payout blocked by admin') : '';
        user.payoutBlockUpdatedAt = new Date();
        await user.save();

        const stateText = block ? 'blocked' : 'unblocked';
        return res.json({ success: true, message: `Payouts ${stateText} successfully` });
    } catch (err) {
        console.error('❌ Block user payout error:', err);
        return res.status(500).json({ success: false, message: 'Failed to block/unblock payouts' });
    }
});

// TOGGLE ACCOUNT DELETED
router.post('/toggle-account-deleted', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const email = String(body.email || '').trim();
        const userId = String(body.userId || '').trim();
        const reason = String(body.reason || '').trim();
        const accountDeleted = normalizeBooleanInput(body.account_deleted);

        if (accountDeleted === null) {
            return res.status(400).json({ success: false, message: `Invalid 'account_deleted' value. Must be boolean.` });
        }
        if (!email && !userId) {
            return res.status(400).json({ success: false, message: 'email or userId is required' });
        }

        await connectMongo();
        const query = { $or: [] };
        if (userId) query.$or.push({ userId });
        if (email) query.$or.push({ email: email.toLowerCase() });

        const user = await User.findOne(query);
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found in MongoDB' });
        }

        user.account_deleted = accountDeleted;
        user.accountDeletedReason = accountDeleted ? (reason || 'Account deleted flag set by admin') : '';
        user.accountDeletedUpdatedAt = new Date();
        await user.save();

        return res.json({
            success: true,
            message: `account_deleted updated to ${accountDeleted ? 'true' : 'false'} successfully`
        });
    } catch (err) {
        console.error('❌ Toggle account_deleted error:', err);
        return res.status(500).json({ success: false, message: 'Failed to update account_deleted' });
    }
});

// MANAGE WALLET FULL PAGE VIEW
router.get('/manage-wallet', adminAuth, checkPermission('wallet'), async (req, res) => {
    try {
        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        const rawMethods = await WalletCatalog.find({ appName: activeApp.appName }).lean();
        const methods = rawMethods.map((method) => {
            const denominations = Array.isArray(method.denominations)
                ? method.denominations.map((d) => ({
                    id: d.denomId,
                    amount: Number(d.amount) || 0,
                    coins: Number(d.coins) || 0,
                    enabled: !!d.enabled,
                    subtitle: d.subtitle || ''
                })).sort((a, b) => a.amount - b.amount)
                : [];
            return {
                id: method.methodId,
                title: method.title || '',
                image: method.image || '',
                symbol: method.symbol || '',
                country: method.country || [],
                ex_country: method.ex_country || [],
                rank: Number(method.rank) || 0,
                enabled: !!method.enabled,
                autoPayment: !!method.autoPayment,
                validators: method.validators || [],
                hints: method.hints || {},
                denominations
            };
        }).sort((a, b) => a.rank - b.rank);

        const defaultRedeemRules = [
            { taskKey: 'super_offer', taskName: 'Super Offer', icon: 'assets/icons/super.png', minCount: 1, errorMessage: 'Please complete super offer for redeem', enabled: true },
            { taskKey: 'daily_challenge', taskName: 'Daily Challenge / Daily Task', icon: 'assets/icons/badge.png', minCount: 1, errorMessage: 'Please complete daily task before redeeming', enabled: false },
            { taskKey: 'battle_arena', taskName: 'Battle Arena (Matches)', icon: 'assets/icons/battles.png', minCount: 1, errorMessage: 'Please play at least 1 match in Battle Arena before redeeming', enabled: false },
            { taskKey: 'read_and_earn', taskName: 'Read & Earn', icon: 'assets/icons/readd.png', minCount: 1, errorMessage: 'Please complete Read & Earn task before redeeming', enabled: false },
            { taskKey: 'watch_earn', taskName: 'Watch & Earn', icon: 'assets/icons/watch video.png', minCount: 1, errorMessage: 'Please complete Watch & Earn task before redeeming', enabled: false },
            { taskKey: 'play_games', taskName: 'Play Games', icon: 'assets/icons/plygames.png', minCount: 1, errorMessage: 'Please play games before redeeming', enabled: false },
            { taskKey: 'diamond_catch', taskName: 'Diamond Catch', icon: 'assets/icons/emoji.png', minCount: 1, errorMessage: 'Please play Diamond Catch game before redeeming', enabled: false },
            { taskKey: 'giveaway', taskName: 'Giveaway Entry', icon: 'assets/icons/givwy.png', minCount: 1, errorMessage: "Please join today's giveaway before redeeming", enabled: false },
            { taskKey: 'offerwall', taskName: 'Offerwall Task', icon: 'assets/icons/pubscale-logo.png', minCount: 1, errorMessage: 'Please complete at least 1 offerwall task before redeeming', enabled: false },
            { taskKey: 'survey', taskName: 'Surveys', icon: 'assets/icons/bitlabs-logo.png', minCount: 1, errorMessage: 'Please complete at least 1 survey before redeeming', enabled: false },
            { taskKey: 'daily_checkin', taskName: 'Daily Check-in', icon: 'assets/icons/clock.png', minCount: 1, errorMessage: 'Please claim daily check-in before redeeming', enabled: false }
        ];

        let appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        if (!appDataDoc) appDataDoc = await AppData.findOne({ appName: activeApp.appName }).lean() || {};
        const config = appDataDoc?.config || {};
        const dailyMaxPayout = Number(config.dailyMaxPayout !== undefined ? config.dailyMaxPayout : (appDataDoc?.dailyMaxPayout !== undefined ? appDataDoc.dailyMaxPayout : 1));

        const savedRedeemCheck = config.redeemCheck || {};
        // If admin has saved rules before, respect their saved list directly so deleted tasks stay deleted
        let rulesToRender;
        if (savedRedeemCheck && Array.isArray(savedRedeemCheck.rules)) {
            rulesToRender = savedRedeemCheck.rules;
        } else {
            // First time load: populate with standard defaults
            rulesToRender = defaultRedeemRules;
        }

        const savedHideDenom = config.hideDenomination || {};
        const hideDenomination = {
            enabled: savedHideDenom.enabled !== undefined ? !!savedHideDenom.enabled : false,
            thresholdPercent: Number(savedHideDenom.thresholdPercent) || 99,
            hideCount: Math.max(1, parseInt(savedHideDenom.hideCount, 10) || 1),
            hideMode: savedHideDenom.hideMode === 'out_of_stock' ? 'out_of_stock' : 'hide',
            redeemCondition: savedHideDenom.redeemCondition || 'always',
            targetRedeemCount: Math.max(0, parseInt(savedHideDenom.targetRedeemCount !== undefined ? savedHideDenom.targetRedeemCount : 1, 10) || 0)
        };

        const redeemCheck = {
            enabled: savedRedeemCheck.enabled !== undefined ? !!savedRedeemCheck.enabled : true,
            rules: rulesToRender
        };

        return res.render('wallet/manage', {
            firebaseServices,
            activeAppName: activeApp.appName || '',
            activePage: 'manage-wallet',
            methods,
            dailyMaxPayout,
            redeemCheck,
            hideDenomination,
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A'
        });
    } catch (err) {
        console.error('🔥 Error loading wallet manager page:', err);
        return res.status(500).send('Internal server error');
    }
});

// WALLET: SAVE DAILY MAX PAYOUT & REDEEM CHECK SETTINGS
router.post('/manage-wallet/save-settings', adminAuth, checkPermission('wallet'), async (req, res) => {
    try {
        await connectMongo();
        const { dailyMaxPayout, redeemCheck, hideDenomination } = req.body;

        const parsedDailyMax = Math.max(0, parseInt(dailyMaxPayout, 10) || 0);

        const cleanRedeemCheck = {
            enabled: Boolean(redeemCheck && (redeemCheck.enabled === true || redeemCheck.enabled === 'true')),
            rules: Array.isArray(redeemCheck?.rules)
                ? redeemCheck.rules.map(r => ({
                    taskKey: String(r.taskKey || '').trim(),
                    taskName: String(r.taskName || r.taskKey || '').trim(),
                    icon: String(r.icon || '').trim(),
                    minCount: Math.max(1, parseInt(r.minCount, 10) || 1),
                    errorMessage: String(r.errorMessage || '').trim() || `Please complete ${r.taskName || r.taskKey} before redeeming`,
                    enabled: Boolean(r.enabled === true || r.enabled === 'true')
                })).filter(r => r.taskKey)
                : []
        };

        const cleanHideDenomination = {
            enabled: Boolean(hideDenomination && (hideDenomination.enabled === true || hideDenomination.enabled === 'true')),
            thresholdPercent: Math.min(100, Math.max(1, parseFloat(hideDenomination?.thresholdPercent) || 99)),
            hideCount: Math.max(1, parseInt(hideDenomination?.hideCount, 10) || 1),
            hideMode: hideDenomination?.hideMode === 'out_of_stock' ? 'out_of_stock' : 'hide',
            redeemCondition: ['always', 'exact_redeems', 'max_redeems', 'min_redeems'].includes(hideDenomination?.redeemCondition)
                ? hideDenomination.redeemCondition
                : 'always',
            targetRedeemCount: Math.max(0, parseInt(hideDenomination?.targetRedeemCount, 10) || 0)
        };

        let appDataDoc = await AppData.findOne({ key: 'appData' });
        const existingConfig = appDataDoc?.config || {};
        const updatedConfig = {
            ...existingConfig,
            dailyMaxPayout: parsedDailyMax,
            redeemCheck: cleanRedeemCheck,
            hideDenomination: cleanHideDenomination
        };

        await AppData.findOneAndUpdate(
            { key: 'appData' },
            {
                config: updatedConfig,
                dailyMaxPayout: parsedDailyMax,
                updatedAt: new Date()
            },
            { upsert: true }
        );

        await cacheService.del('global:appData');
        try { await cacheService.delPattern('wallet:methods:*'); } catch (_) { }
        try { await cacheService.delPattern('wallet:*'); } catch (_) { }

        return res.json({
            success: true,
            message: 'Payout limits & Redeem Check rules saved successfully',
            dailyMaxPayout: parsedDailyMax,
            redeemCheck: cleanRedeemCheck,
            hideDenomination: cleanHideDenomination
        });
    } catch (err) {
        console.error('🔥 Error saving wallet payout settings:', err);
        return res.status(500).json({ success: false, message: 'Failed to save settings: ' + err.message });
    }
});

// WALLET CATALOG: GET METHODS + DENOMINATIONS
router.get('/wallet-catalog', adminAuth, checkPermission('wallet'), async (req, res) => {
    try {
        const selectedApp = String(req.query.app || req.query.selectedApp || '').trim();
        if (!selectedApp) {
            return res.status(400).json({ success: false, message: 'App not selected' });
        }

        await connectMongo();
        const rawMethods = await WalletCatalog.find({ appName: selectedApp }).lean();

        const methods = rawMethods.map((method) => {
            const denominations = Array.isArray(method.denominations)
                ? method.denominations
                    .map((d) => ({
                        id: d.denomId,
                        amount: Number(d.amount) || 0,
                        coins: Number(d.coins) || 0,
                        enabled: !!d.enabled,
                        subtitle: d.subtitle || ''
                    }))
                    .sort((a, b) => a.amount - b.amount)
                : [];

            return {
                id: method.methodId,
                enabled: !!method.enabled,
                symbol: String(method.symbol || '₹'),
                country: Array.isArray(method.country) ? method.country : [],
                ex_country: Array.isArray(method.ex_country) ? method.ex_country : [],
                title: String(method.title || method.methodId),
                rank: Number(method.rank) || 0,
                image: String(method.image || ''),
                validators: Array.isArray(method.validators) ? method.validators : [],
                hints: typeof method.hints === 'object' && method.hints !== null ? method.hints : {},
                autoPayment: !!method.autoPayment,
                denominations,
            };
        });

        methods.sort((a, b) => a.rank - b.rank || a.id.localeCompare(b.id));

        return res.json({
            success: true,
            app: selectedApp,
            methods,
        });
    } catch (err) {
        console.error('❌ Wallet catalog fetch error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch wallet catalog',
        });
    }
});

// WALLET CATALOG: UPDATE METHOD CONFIG
router.post('/wallet-catalog/method', adminAuth, checkPermission('wallet'), async (req, res) => {
    try {
        const body = req.body || {};
        const selectedApp = String(body.selectedApp || '').trim();
        const methodId = String(body.methodId || '').trim();

        if (!selectedApp) {
            return res.status(400).json({ success: false, message: 'App not selected' });
        }

        if (!methodId) {
            return res.status(400).json({ success: false, message: 'methodId is required' });
        }

        const normalized = normalizeWalletMethodUpdates(body);
        if (!normalized.ok) {
            return res.status(400).json({ success: false, message: normalized.message });
        }

        if (!Object.keys(normalized.updates).length) {
            return res.status(400).json({ success: false, message: 'No valid fields to update' });
        }

        await connectMongo();

        let methodDoc = await WalletCatalog.findOne({ appName: selectedApp, methodId });
        if (!methodDoc) {
            methodDoc = await WalletCatalog.findOne({
                appName: { $regex: new RegExp(`^${selectedApp.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') },
                methodId: { $regex: new RegExp(`^${methodId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') }
            });
        }

        if (!methodDoc) {
            const defaultUpdates = {
                appName: selectedApp,
                methodId,
                title: methodId,
                enabled: true,
                autoPayment: false,
                image: '',
                rank: 0,
                country: ['GLOBAL'],
                ex_country: [],
                validators: [],
                denominations: []
            };
            const newMethod = new WalletCatalog({
                ...defaultUpdates,
                ...normalized.updates
            });
            await newMethod.save();
        } else {
            await WalletCatalog.updateOne(
                { _id: methodDoc._id },
                { $set: normalized.updates }
            );
        }

        try { await cacheService.delPattern('wallet:methods:*'); } catch (_) { }

        return res.json({
            success: true,
            message: `${methodId} updated successfully`,
        });
    } catch (err) {
        console.error('❌ Wallet method update error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to update wallet method',
        });
    }
});

// WALLET CATALOG: DELETE METHOD
router.post('/wallet-catalog/method/delete', adminAuth, checkPermission('wallet'), async (req, res) => {
    try {
        const body = req.body || {};
        const selectedApp = String(body.selectedApp || '').trim();
        const methodId = String(body.methodId || '').trim();

        if (!selectedApp) {
            return res.status(400).json({ success: false, message: 'App not selected' });
        }

        if (!methodId) {
            return res.status(400).json({ success: false, message: 'methodId is required' });
        }

        await connectMongo();
        await WalletCatalog.deleteOne({ appName: selectedApp, methodId });
        try { await cacheService.delPattern('wallet:methods:*'); } catch (_) { }

        return res.json({
            success: true,
            message: `${methodId} deleted successfully`,
        });
    } catch (err) {
        console.error('❌ Wallet method delete error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to delete wallet method',
        });
    }
});

// WALLET CATALOG: DUPLICATE METHOD
router.post('/wallet-catalog/method/duplicate', adminAuth, checkPermission('wallet'), async (req, res) => {
    try {
        const body = req.body || {};
        const selectedApp = String(body.selectedApp || '').trim();
        const sourceMethodId = String(body.sourceMethodId || '').trim();
        const targetMethodId = String(body.targetMethodId || '').trim();

        if (!selectedApp) {
            return res.status(400).json({ success: false, message: 'App not selected' });
        }
        if (!sourceMethodId || !targetMethodId) {
            return res.status(400).json({ success: false, message: 'sourceMethodId and targetMethodId are required' });
        }

        await connectMongo();

        const sourceDoc = await WalletCatalog.findOne({ appName: selectedApp, methodId: sourceMethodId }).lean();
        if (!sourceDoc) {
            return res.status(404).json({ success: false, message: 'Source method not found' });
        }

        const targetDoc = await WalletCatalog.findOne({ appName: selectedApp, methodId: targetMethodId });
        if (targetDoc) {
            return res.status(400).json({ success: false, message: `Target method ${targetMethodId} already exists` });
        }

        const newMethod = new WalletCatalog({
            ...sourceDoc,
            _id: undefined,
            appName: selectedApp,
            methodId: targetMethodId,
            title: `${sourceDoc.title || sourceMethodId} (Copy)`,
            denominations: (sourceDoc.denominations || []).map(d => ({
                denomId: `${targetMethodId}_${d.denomId.split('_').slice(1).join('_') || d.amount}`,
                amount: d.amount,
                coins: d.coins,
                enabled: d.enabled
            }))
        });

        await newMethod.save();
        try { await cacheService.delPattern('wallet:methods:*'); } catch (_) { }

        return res.json({
            success: true,
            message: `Method ${sourceMethodId} duplicated to ${targetMethodId} successfully`,
        });
    } catch (err) {
        console.error('❌ Wallet method duplicate error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to duplicate wallet method',
        });
    }
});

// WALLET CATALOG: SAVE ALL DENOMINATIONS
router.post('/wallet-catalog/denominations/save-all', adminAuth, checkPermission('wallet'), async (req, res) => {
    try {
        const body = req.body || {};
        const selectedApp = String(body.selectedApp || '').trim();
        const methodId = String(body.methodId || '').trim();
        const denominations = Array.isArray(body.denominations) ? body.denominations : [];

        if (!selectedApp) {
            return res.status(400).json({ success: false, message: 'App not selected' });
        }

        if (!methodId) {
            return res.status(400).json({ success: false, message: 'methodId is required' });
        }

        await connectMongo();

        const methodDoc = await WalletCatalog.findOne({ appName: selectedApp, methodId });
        if (!methodDoc) {
            return res.status(404).json({ success: false, message: 'Wallet method not found' });
        }

        const existingDenoms = methodDoc.denominations || [];
        const denomsMap = {};
        for (const d of existingDenoms) {
            denomsMap[d.denomId] = d;
        }

        for (const item of denominations) {
            const amount = Number(item.amount);
            const coins = Number(item.coins);
            const enabled = normalizeBooleanInput(item.enabled);
            const oldDenominationId = String(item.oldDenominationId || '').trim();

            if (!Number.isFinite(amount) || amount <= 0) {
                return res.status(400).json({ success: false, message: 'amount must be a number > 0' });
            }

            if (!Number.isFinite(coins) || coins <= 0) {
                return res.status(400).json({ success: false, message: 'coins must be a number > 0' });
            }

            if (enabled === null) {
                return res.status(400).json({ success: false, message: 'enabled must be boolean' });
            }

            const parsedAmount = Math.trunc(amount);
            const parsedCoins = Math.trunc(coins);
            const denominationId = `${methodId}_${parsedAmount}`;

            if (oldDenominationId && oldDenominationId !== denominationId) {
                delete denomsMap[oldDenominationId];
            }

            denomsMap[denominationId] = {
                denomId: denominationId,
                amount: parsedAmount,
                coins: parsedCoins,
                enabled,
                subtitle: item.subtitle ? String(item.subtitle).trim() : ''
            };
        }

        methodDoc.denominations = Object.values(denomsMap);
        await methodDoc.save();

        return res.json({
            success: true,
            message: 'All denominations saved successfully',
        });
    } catch (err) {
        console.error('❌ Wallet save-all denominations error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to save all denominations',
        });
    }
});

// WALLET CATALOG: ADD/UPDATE/DELETE DENOMINATION
router.post('/wallet-catalog/denomination', adminAuth, checkPermission('wallet'), async (req, res) => {
    try {
        const body = req.body || {};
        const selectedApp = String(body.selectedApp || '').trim();
        const methodId = String(body.methodId || '').trim();
        const oldDenominationId = String(body.oldDenominationId || body.oldId || '').trim();
        const customDenominationId = String(body.denominationId || '').trim();
        const isDelete = body.delete === true || body.action === 'delete';

        if (!selectedApp) {
            return res.status(400).json({ success: false, message: 'App not selected' });
        }

        if (!methodId) {
            return res.status(400).json({ success: false, message: 'methodId is required' });
        }

        await connectMongo();

        let methodDoc = await WalletCatalog.findOne({ appName: selectedApp, methodId });
        if (!methodDoc) {
            methodDoc = await WalletCatalog.findOne({
                appName: { $regex: new RegExp(`^${selectedApp}$`, 'i') },
                methodId: { $regex: new RegExp(`^${methodId}$`, 'i') }
            });
        }

        if (!methodDoc) {
            methodDoc = new WalletCatalog({
                appName: selectedApp,
                methodId,
                title: methodId,
                enabled: true,
                autoPayment: false,
                image: '',
                rank: 0,
                country: ['GLOBAL'],
                ex_country: [],
                validators: [],
                denominations: []
            });
            await methodDoc.save();
        }

        if (isDelete) {
            if (!oldDenominationId) {
                return res.status(400).json({ success: false, message: 'Denomination ID is required to delete' });
            }
            methodDoc.denominations = (methodDoc.denominations || []).filter(
                d => d.denomId !== oldDenominationId
            );
            await methodDoc.save();
            return res.json({
                success: true,
                message: 'Denomination deleted successfully'
            });
        }

        const amount = Number(body.amount);
        const coins = Number(body.coins);
        const enabled = body.enabled !== false && String(body.enabled) !== 'false';

        if (!Number.isFinite(amount) || amount <= 0) {
            return res.status(400).json({ success: false, message: 'Amount must be a number > 0' });
        }

        if (!Number.isFinite(coins) || coins <= 0) {
            return res.status(400).json({ success: false, message: 'Coins must be a number > 0' });
        }

        const parsedAmount = Math.trunc(amount);
        const parsedCoins = Math.trunc(coins);
        const denominationId = customDenominationId || `${methodDoc.methodId}_${parsedAmount}`;

        let updatedDenominations = (methodDoc.denominations || []).filter(
            d => d.denomId !== denominationId && (!oldDenominationId || d.denomId !== oldDenominationId)
        );

        updatedDenominations.push({
            denomId: denominationId,
            amount: parsedAmount,
            coins: parsedCoins,
            enabled,
            subtitle: body.subtitle ? String(body.subtitle).trim() : ''
        });

        updatedDenominations.sort((a, b) => a.amount - b.amount);

        methodDoc.denominations = updatedDenominations;
        await methodDoc.save();
        try { await cacheService.delPattern('wallet:methods:*'); } catch (_) { }

        return res.json({
            success: true,
            message: 'Denomination saved successfully',
            denominationId,
            denominations: updatedDenominations
        });
    } catch (err) {
        console.error('❌ Wallet denomination update error:', err);
        return res.status(500).json({
            success: false,
            message: err.message || 'Failed to save denomination',
        });
    }
});

// API INTEGRATIONS HUB PAGE & KEY CRUD
router.get('/api-integrations', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const DeveloperApiKey = require('../admin/models/developerApiKey');
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        const apiKeys = await DeveloperApiKey.find({}).sort({ createdAt: -1 }).lean();

        res.render('api-integrations/manage', {
            firebaseServices,
            activeAppName: activeApp.appName,
            activePage: 'api-integrations',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin,
            apiKeys: apiKeys || []
        });
    } catch (err) {
        console.error('❌ Error rendering API Integrations:', err);
        res.status(500).send('Internal Server Error');
    }
});

router.post('/api-integrations/key/add', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const crypto = require('crypto');
        const DeveloperApiKey = require('../admin/models/developerApiKey');
        const { name, scopes } = req.body;

        if (!name) {
            return res.status(400).json({ success: false, message: 'Name is required' });
        }

        const validScopes = [
            'tasks_read', 'tasks_create', 'tasks_update', 'tasks_delete', 'tasks_manage',
            'read_earn_manage', 'giveaways_manage', 'promo_codes_manage',
            'app_analytics', 'user_data', 'payout_history', 'reward_history',
            'offerwall_history', 'super_offer_history', 'battle_arena_stats'
        ];
        let rawScopes = Array.isArray(scopes) ? scopes : (scopes ? [scopes] : []);
        if (rawScopes.includes('tasks_manage')) {
            rawScopes = [...new Set([...rawScopes, 'tasks_read', 'tasks_create', 'tasks_update', 'tasks_delete'])];
        }
        const filteredScopes = rawScopes.filter(s => validScopes.includes(s));

        const secureKey = 'op_sec_' + crypto.randomBytes(24).toString('hex');

        const newKey = new DeveloperApiKey({
            name: name.trim(),
            apiKey: secureKey,
            scopes: filteredScopes,
            isActive: true
        });
        await newKey.save();

        return res.json({ success: true, message: 'API Key generated successfully' });
    } catch (err) {
        console.error('❌ Error generating developer API key:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

router.post('/api-integrations/key/delete/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const DeveloperApiKey = require('../admin/models/developerApiKey');
        const { id } = req.params;

        await DeveloperApiKey.findByIdAndDelete(id);
        return res.json({ success: true, message: 'API Key deleted successfully' });
    } catch (err) {
        console.error('❌ Error deleting developer API key:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

router.post('/api-integrations/key/toggle/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const DeveloperApiKey = require('../admin/models/developerApiKey');
        const { id } = req.params;

        const keyDoc = await DeveloperApiKey.findById(id);
        if (!keyDoc) {
            return res.status(404).json({ success: false, message: 'API Key not found' });
        }

        keyDoc.isActive = !keyDoc.isActive;
        await keyDoc.save();

        return res.json({ success: true, message: 'API Key status updated', isActive: keyDoc.isActive });
    } catch (err) {
        console.error('❌ Error toggling API key:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// CPA & DIRECT ADVERTISER POSTBACK DOCUMENTATION PAGE
router.get(['/cpa-docs', '/cpa-postback-docs'], adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};
        const DailyTask = require('../admin/models/dailyTask');
        const dailyTasks = await DailyTask.find({ offerType: { $ne: 'WatchEarn' } }).select('offerId offerName secretKey events packageEnabled timerEnabled payout createdAt').sort({ createdAt: -1 }).lean();

        // Load Offerwall & Survey configurations
        const offersDoc = await OffersSettings.findOne({ key: 'offersSettings' }).lean();
        const rawOffers = offersDoc?.config || {};
        const resolvedOffers = resolveOfferwallEnvFallbacks(rawOffers);

        // Determine public API / Postback base URL (Default: https://crazyreward.zodplaygames.com)
        let baseUrl = 'https://crazyreward.zodplaygames.com';
        if (process.env.PUBLIC_API_URL) {
            baseUrl = process.env.PUBLIC_API_URL;
        } else if (req.query.baseUrl) {
            baseUrl = req.query.baseUrl;
        }

        res.render('cpa-docs/index', {
            firebaseServices,
            activeAppName: activeApp.appName || 'crazyreward',
            activePage: 'cpa-docs',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin,
            dailyTasks: dailyTasks || [],
            offersSettings: resolvedOffers || {},
            baseUrl: baseUrl
        });
    } catch (err) {
        console.error('❌ Error rendering CPA Docs:', err);
        res.status(500).send('Internal Server Error');
    }
});

// CPA POSTBACK HANDLER (Direct Advertisers & Live Tester)
router.all('/cpa-postback', async (req, res) => {
    const params = { ...req.query, ...req.body };
    const userId = String(params.userId || params.user_id || params.subId || params.sub_id || '').trim();
    const appName = String(params.appName || params.app_name || params.app || 'crazyreward').trim();
    const offerId = String(params.offerId || params.offer_id || '').trim();
    const secret = String(params.secret || params.secretKey || params.secret_key || '').trim();
    const eventId = String(params.eventId || params.event_id || params.eventID || params.eventid || '').trim();

    console.log("CPA Postback Received in adminRoutes:", { userId, appName, offerId, secret, eventId });

    if (!userId || !offerId) {
        return res.status(400).send('0');
    }
    if (!secret) {
        return res.status(401).send('0');
    }

    try {
        await connectMongo();
        const DailyTask = require('../admin/models/dailyTask');
        const { handleDailyTaskPostback } = require('../admin/middlewares/daily-task-postback');

        const offer = await DailyTask.findOne({ offerId }).lean();
        if (!offer) {
            console.warn(`❌ Offer not found in CPA postback: ${offerId}`);
            return res.status(404).send('0');
        }

        const taskSecret = offer.secretKey;
        if (!taskSecret || secret !== taskSecret) {
            console.warn(`❌ Invalid secret key for offer: ${offerId}`);
            return res.status(401).send('0');
        }

        return handleDailyTaskPostback({
            appName: appName.toLowerCase().replace(/\s/g, '').trim(),
            userId: userId,
            offerId: offerId,
            userEmail: '',
            query: params,
            res: res,
            userGaid: '',
            eventId: eventId,
        });
    } catch (error) {
        console.error("❌ CPA Postback execution error in adminRoutes:", error);
        return res.status(500).send('0');
    }
});

// S2S DEVELOPER SETTINGS PAGE (Callbacks & Postbacks)
router.get('/s2s-postbacks', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        const IncomingPromo = require('../admin/models/incomingPromo');
        const PublisherPostback = require('../admin/models/publisherPostback');
        const DailyTask = require('../admin/models/dailyTask');
        const ReadEarn = require('../admin/models/readEarn');
        const PlayGames = require('../admin/models/playGames');

        // Fetch configurations
        const [incomingPromos, publisherPostbacks, dailyTasks, readEarnDocs, playGamesDocs] = await Promise.all([
            IncomingPromo.find({}).lean(),
            PublisherPostback.find({}).lean(),
            DailyTask.find({ offerType: { $ne: 'WatchEarn' } }).select('offerId offerName').lean(),
            ReadEarn.find({}).lean(),
            PlayGames.find({}).select('_id name title').lean()
        ]);

        const readEarnTasks = [];
        (readEarnDocs || []).forEach(doc => {
            if (doc.urlsList && Array.isArray(doc.urlsList)) {
                doc.urlsList.forEach(item => {
                    readEarnTasks.push({
                        offerId: String(item._id),
                        offerName: `Read: ${item.url}`
                    });
                });
            }
        });

        const playGamesTasks = (playGamesDocs || []).map(g => ({
            offerId: String(g._id),
            offerName: `Play: ${g.title || g.name || 'Unnamed Game'}`
        }));

        res.render('s2s-postbacks/manage', {
            firebaseServices,
            activeAppName: activeApp.appName,
            activePage: 's2s-postbacks',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin,
            incomingPromos: incomingPromos || [],
            publisherPostbacks: publisherPostbacks || [],
            dailyTasks: dailyTasks || [],
            readEarnTasks,
            playGamesTasks,
            ownPackageId: process.env.PACKAGE_NAME || 'com.crazyreward.games'
        });
    } catch (err) {
        console.error('❌ Error rendering S2S Settings:', err);
        res.status(500).send('Internal Server Error');
    }
});

// Outgoing Publisher Callback (Case 2) APIs
router.post('/s2s-postbacks/publisher/add', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const PublisherPostback = require('../admin/models/publisherPostback');
        const { referCode, postbackUrl, secretKey, assignedTasks, packageId } = req.body;

        if (!referCode || !postbackUrl || !secretKey) {
            return res.status(400).json({ success: false, message: 'Missing parameters' });
        }

        const tasks = Array.isArray(assignedTasks) ? assignedTasks : (assignedTasks ? [assignedTasks] : []);

        await PublisherPostback.findOneAndUpdate(
            { referCode: referCode.trim() },
            {
                referCode: referCode.trim(),
                postbackUrl: postbackUrl.trim(),
                secretKey: secretKey.trim(),
                packageId: packageId ? packageId.trim() : '',
                assignedTasks: tasks,
                isActive: true
            },
            { upsert: true, new: true }
        );

        return res.json({ success: true, message: 'Publisher Callback saved successfully' });
    } catch (err) {
        console.error('❌ Error saving Publisher Postback:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

router.post('/s2s-postbacks/publisher/delete/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const PublisherPostback = require('../admin/models/publisherPostback');
        await PublisherPostback.findByIdAndDelete(req.params.id);
        return res.json({ success: true, message: 'Publisher Callback deleted successfully' });
    } catch (err) {
        console.error('❌ Error deleting Publisher Postback:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// Outgoing Publisher Callback (Case 2) Test Execution API
router.post('/s2s-postbacks/publisher/test', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const PublisherPostback = require('../admin/models/publisherPostback');
        const axios = require('axios');
        const crypto = require('crypto');
        const { id, userId, offerId, coins } = req.body;

        if (!id || !userId || !offerId) {
            return res.status(400).json({ success: false, message: 'Missing test parameters' });
        }

        const publisher = await PublisherPostback.findById(id);
        if (!publisher) {
            return res.status(404).json({ success: false, message: 'Publisher configuration not found' });
        }

        const testCoins = Number(coins || 100);
        const subEventId = '';

        // Generate SHA256 signature
        const rawString = `${publisher.secretKey}:${userId}:${offerId}:${testCoins}:${subEventId}`;
        const signature = crypto.createHash('sha256').update(rawString).digest('hex');

        // Build callback URL
        const connector = publisher.postbackUrl.includes('?') ? '&' : '?';
        const finalUrl = `${publisher.postbackUrl}${connector}user_id=${userId}&offer_id=${offerId}&coins=${testCoins}&eventId=${subEventId}&sig=${signature}&refer_code=${publisher.referCode}`;

        console.log(`📡 Triggering test S2S postback: ${finalUrl}`);

        let responseStatus = 0;
        let responseData = '';
        try {
            const apiRes = await axios.get(finalUrl, { timeout: 8000 });
            responseStatus = apiRes.status;
            responseData = typeof apiRes.data === 'object' ? JSON.stringify(apiRes.data) : String(apiRes.data);
        } catch (apiErr) {
            responseStatus = apiErr.response ? apiErr.response.status : 500;
            responseData = apiErr.response && apiErr.response.data
                ? (typeof apiErr.response.data === 'object' ? JSON.stringify(apiErr.response.data) : String(apiErr.response.data))
                : apiErr.message;
        }

        return res.json({
            success: true,
            url: finalUrl,
            status: responseStatus,
            response: responseData
        });
    } catch (err) {
        console.error('❌ Error executing publisher S2S test:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error: ' + err.message });
    }
});

// Incoming Promo Callback (Case 1) APIs
router.post('/s2s-postbacks/promo/add', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const IncomingPromo = require('../admin/models/incomingPromo');
        const { trackerCode, secretKey, offerId, eventId, coins, packageId } = req.body;

        if (!trackerCode || !secretKey || !offerId || !eventId || !coins) {
            return res.status(400).json({ success: false, message: 'Missing parameters' });
        }

        const promo = await IncomingPromo.findOne({ trackerCode: trackerCode.trim() });
        const newEvent = { eventId: eventId.trim(), coins: Number(coins) };

        if (promo) {
            promo.events = promo.events.filter(e => e.eventId !== eventId.trim());
            promo.events.push(newEvent);
            promo.secretKey = secretKey.trim();
            promo.offerId = offerId.trim();
            promo.packageId = packageId ? packageId.trim() : '';
            await promo.save();
        } else {
            await IncomingPromo.create({
                trackerCode: trackerCode.trim(),
                secretKey: secretKey.trim(),
                offerId: offerId.trim(),
                packageId: packageId ? packageId.trim() : '',
                events: [newEvent],
                isActive: true
            });
        }

        return res.json({ success: true, message: 'Incoming Promo Callback saved successfully' });
    } catch (err) {
        console.error('❌ Error saving Incoming Promo:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

router.post('/s2s-postbacks/promo/delete/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const IncomingPromo = require('../admin/models/incomingPromo');
        await IncomingPromo.findByIdAndDelete(req.params.id);
        return res.json({ success: true, message: 'Incoming Promo deleted successfully' });
    } catch (err) {
        console.error('❌ Error deleting Incoming Promo:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// SUPER OFFER PAGE
router.get('/super-offer', adminAuth, checkPermission('superOffer', 'dailyTasks', 'appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        const superOfferConfig = appDataDoc?.config?.superOfferConfig || {};

        res.render('super-offer/manage', {
            config: superOfferConfig,
            activePage: 'super-offer',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Error rendering Super Offer Page:', err);
        res.status(500).send('Internal Server Error');
    }
});

// GET SUPER OFFER PENDING PROOFS
router.get('/admin/super-offer/pending-proofs', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const search = String(req.query.search || '').trim();
        const status = String(req.query.status || 'pending').trim();

        const query = {
            $or: [
                { offerId: { $regex: '^super_offer_', $options: 'i' } },
                { eventName: 'Super Offer Screenshot' },
                { offerName: { $regex: 'Super Offer', $options: 'i' } }
            ]
        };

        if (status && status !== 'all') {
            query.status = status;
        }

        if (search) {
            query.$and = [
                {
                    $or: [
                        { userId: { $regex: search, $options: 'i' } },
                        { appName: { $regex: search, $options: 'i' } },
                        { userEmail: { $regex: search, $options: 'i' } }
                    ]
                }
            ];
        }

        const proofs = await ScreenshotProof.find(query).sort({ createdAt: -1 }).limit(200).lean();
        return res.json({ success: true, proofs });
    } catch (err) {
        console.error('🔥 Error fetching super offer pending proofs:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

// APPROVE SUPER OFFER SCREENSHOT PROOF
router.post('/admin/super-offer/approve-proof/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const proofId = req.params.id;
        const proof = await ScreenshotProof.findById(proofId);
        if (!proof) return res.status(404).json({ success: false, message: 'Proof not found' });

        let rewardCoins = Number(proof.coins) || 0;
        if (rewardCoins <= 0) {
            const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
            const superOfferConfig = appDataDoc?.config?.superOfferConfig || {};
            rewardCoins = Number(superOfferConfig.screenshotCoins) || Math.round((Number(superOfferConfig.reward) || 768) * 0.75);
        }

        proof.status = 'approved';
        proof.coins = rewardCoins;
        proof.reviewedAt = new Date();
        proof.reviewedBy = req.admin?.username || 'admin';
        await proof.save();

        // 1. Credit Coins in MongoDB User atomically
        const user = await User.findOneAndUpdate(
            {
                $or: [
                    { userId: proof.userId },
                    { userId: String(proof.userId).trim() },
                    ...(proof.userEmail ? [{ email: proof.userEmail }, { gmail: proof.userEmail }] : [])
                ]
            },
            { $inc: { coins: rewardCoins, totalCoins: rewardCoins } },
            { new: true }
        );

        if (user) {
            // 2. Create RewardHistory log
            const appDataDoc = await AppData.findOne({ key: 'appData' }).lean() || await AppData.findOne({}).lean();
            const superOfferConfig = appDataDoc?.config?.superOfferConfig || appDataDoc?.superOfferConfig || {};
            const configuredUsageSteps = Array.isArray(superOfferConfig.usageSteps) && superOfferConfig.usageSteps.length > 0
                ? superOfferConfig.usageSteps
                : [];
            const finalProvider = 'Super Offer Proof';

            await RewardHistory.create({
                appName: proof.appName || user.appName || 'Super Offer',
                userId: user.userId || proof.userId,
                provider: finalProvider,
                coins: rewardCoins,
                gems: 0,
                rewardType: 'coin',
                orderId: 'SOP_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6),
                createdAt: new Date(),
            });

            // 3. Send Notification to User
            try {
                const { sendNotificationViaApi } = require('../admin/middlewares/send-notification-api');
                if (typeof sendNotificationViaApi === 'function') {
                    await sendNotificationViaApi({
                        title: 'Super Offer Approved! 🎉',
                        body: `Your Super Offer for ${proof.appName || 'Super Offer'} was approved! +${rewardCoins} Coins added to your wallet.`,
                        userId: String(user.userId || proof.userId).trim(),
                        data: {
                            type: 'super_offer',
                            packageName: proof.offerId ? proof.offerId.replace('super_offer_', '') : '',
                            coins: String(rewardCoins),
                        }
                    });
                }
            } catch (notifErr) {
                console.error('⚠️ Notification error on proof approve:', notifErr.message);
            }
        }

        // 4. Update SuperOfferHistory
        try {
            const pkgName = proof.offerId ? proof.offerId.replace('super_offer_', '') : '';
            await SuperOfferHistory.updateMany(
                {
                    userId: proof.userId,
                    $or: [{ packageName: pkgName }, { appName: proof.appName }],
                    stepType: 'screenshot'
                },
                {
                    $set: {
                        status: 'approved',
                        coins: rewardCoins,
                        reviewedAt: new Date(),
                        reviewedBy: req.admin?.username || 'admin',
                        completedAt: new Date()
                    }
                }
            );
        } catch (hErr) {
            console.error('⚠️ SuperOfferHistory update error:', hErr.message);
        }

        return res.json({ success: true, message: `Proof approved! +${rewardCoins} coins credited to user.` });
    } catch (err) {
        console.error('🔥 Error approving super offer screenshot proof:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

// REJECT SUPER OFFER SCREENSHOT PROOF
router.post('/admin/super-offer/reject-proof/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const proofId = req.params.id;
        const reason = String(req.body.reason || 'Screenshot not valid or unreadable').trim();

        const proof = await ScreenshotProof.findById(proofId);
        if (!proof) return res.status(404).json({ success: false, message: 'Proof not found' });

        proof.status = 'rejected';
        proof.rejectionReason = reason;
        proof.reviewedAt = new Date();
        proof.reviewedBy = req.admin?.username || 'admin';
        await proof.save();

        // Update SuperOfferHistory
        try {
            const pkgName = proof.offerId ? proof.offerId.replace('super_offer_', '') : '';
            await SuperOfferHistory.updateMany(
                {
                    userId: proof.userId,
                    $or: [{ packageName: pkgName }, { appName: proof.appName }],
                    stepType: 'screenshot'
                },
                {
                    $set: {
                        status: 'rejected',
                        rejectionReason: reason,
                        reviewedAt: new Date(),
                        reviewedBy: req.admin?.username || 'admin'
                    }
                }
            );
        } catch (hErr) { }

        // Send Rejection Notification to User
        try {
            const { sendNotificationViaApi } = require('../admin/middlewares/send-notification-api');
            if (typeof sendNotificationViaApi === 'function') {
                await sendNotificationViaApi({
                    title: 'Proof Verification Rejected ❌',
                    body: `Your proof for ${proof.appName || 'Super Offer'} was rejected: ${reason}`,
                    userId: String(proof.userId).trim(),
                    data: {
                        type: 'super_offer_rejected',
                        rejectionReason: reason,
                    }
                });
            }
        } catch (notifErr) {
            console.error('⚠️ Notification error on proof reject:', notifErr.message);
        }

        return res.json({ success: true, message: 'Proof marked as rejected.' });
    } catch (err) {
        console.error('🔥 Error rejecting super offer screenshot proof:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

// GET USER SUPER OFFER HISTORY (For User Activity Screen)
router.get('/admin/user-super-offer-history/:userId', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const targetUserId = req.params.userId;
        const start = req.query.start;
        const end = req.query.end;
        const status = req.query.status;

        // Fetch superOfferConfig early so it is available for all computations
        let appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        if (!appDataDoc) {
            appDataDoc = await AppData.findOne({}).lean();
        }
        const superOfferConfig = (appDataDoc && appDataDoc.config && appDataDoc.config.superOfferConfig)
            ? appDataDoc.config.superOfferConfig
            : (appDataDoc && appDataDoc.superOfferConfig ? appDataDoc.superOfferConfig : {});

        // 1. Resolve all possible user identifiers (userId, email, gmail)
        const userDoc = await User.findOne({
            $or: [
                { userId: targetUserId },
                { userId: String(targetUserId).trim() },
                { email: targetUserId },
                { gmail: targetUserId }
            ]
        }).lean();

        const uidList = [targetUserId, String(targetUserId).trim()];
        if (userDoc) {
            if (userDoc.userId) {
                uidList.push(userDoc.userId);
                uidList.push(String(userDoc.userId).trim());
            }
            if (userDoc.email) uidList.push(userDoc.email);
            if (userDoc.gmail) uidList.push(userDoc.gmail);
        }

        const userQuery = {
            $or: [
                { userId: { $in: uidList } },
                { userEmail: { $in: uidList } }
            ]
        };

        if (start && end) {
            const startDate = new Date(`${String(start).trim()}T00:00:00.000+05:30`);
            const endDate = new Date(`${String(end).trim()}T23:59:59.999+05:30`);
            if (!Number.isNaN(startDate.getTime()) && !Number.isNaN(endDate.getTime())) {
                userQuery.createdAt = { $gte: startDate, $lte: endDate };
            }
        }

        // 2. Fetch SuperOfferHistory records
        let history = await SuperOfferHistory.find(userQuery).sort({ createdAt: -1 }).lean();

        // 3. Also fetch ScreenshotProof records for this user & merge pending/approved/rejected proofs
        const proofQuery = {
            $or: [
                { userId: { $in: uidList } },
                { userEmail: { $in: uidList } }
            ]
        };
        if (start && end) {
            const startDate = new Date(`${String(start).trim()}T00:00:00.000+05:30`);
            const endDate = new Date(`${String(end).trim()}T23:59:59.999+05:30`);
            if (!Number.isNaN(startDate.getTime()) && !Number.isNaN(endDate.getTime())) {
                proofQuery.createdAt = { $gte: startDate, $lte: endDate };
            }
        }
        const proofs = await ScreenshotProof.find(proofQuery).sort({ createdAt: -1 }).lean();

        for (const p of proofs) {
            const pkgName = p.offerId ? p.offerId.replace('super_offer_', '') : p.appName || '';
            const exists = history.some(h => (h.packageName === pkgName || h.offerId === p.offerId) && (h.status === p.status || h.status === 'pending_proof'));
            if (!exists) {
                history.push({
                    _id: p._id,
                    userId: p.userId,
                    packageName: pkgName,
                    appName: p.appName || 'Super Offer',
                    stepNumber: 2,
                    stepName: 'Screenshot Proof',
                    stepType: 'screenshot',
                    status: p.status === 'pending' ? 'pending_proof' : p.status,
                    coins: p.coins || 0,
                    proofImageUrl: p.imageUrl || '',
                    rejectionReason: p.rejectionReason || '',
                    createdAt: p.createdAt,
                });
            }
        }

        // 4. Fallback to RewardHistory if no history found
        if (history.length === 0 && (!status || status === 'all' || status === 'completed')) {
            const rewardQuery = {
                $or: [
                    { userId: { $in: uidList } }
                ],
                provider: 'Super Offer',
            };
            if (start && end) {
                const startDate = new Date(`${String(start).trim()}T00:00:00.000+05:30`);
                const endDate = new Date(`${String(end).trim()}T23:59:59.999+05:30`);
                if (!Number.isNaN(startDate.getTime()) && !Number.isNaN(endDate.getTime())) {
                    rewardQuery.createdAt = { $gte: startDate, $lte: endDate };
                }
            }
            const rewards = await RewardHistory.find(rewardQuery).sort({ createdAt: -1 }).lean();
            if (rewards.length > 0) {
                history = rewards.map((r) => ({
                    _id: r._id,
                    userId: r.userId,
                    packageName: r.appName || 'Super Offer App',
                    appName: r.appName || 'Super Offer',
                    stepNumber: 1,
                    stepName: 'Install App',
                    stepType: 'install',
                    status: 'completed',
                    coins: r.coins || 0,
                    usageMinutes: 2,
                    createdAt: r.createdAt,
                    completedAt: r.createdAt
                }));
            }
        }

        // 5. Build Completed Offers & Pending Offers
        const pendingApps = [];
        const completedApps = [];
        const appMap = new Map();

        history.forEach(h => {
            const pkg = h.packageName || h.appName || 'super_offer_app';
            if (!appMap.has(pkg)) {
                const isVerif = h.isVerificationEnabled === true;
                appMap.set(pkg, {
                    packageName: pkg,
                    appName: h.appName || pkg,
                    isVerificationEnabled: isVerif,
                    configSnapshot: h.configSnapshot || null,
                    status: h.status || 'in_progress',
                    totalCoinsEarned: 0,
                    totalOfferCoins: 0,
                    lastActivityAt: h.completedAt || h.createdAt,
                    steps: {
                        install: { stepName: 'Install App & Initial Launch', status: 'not_done', coins: 0, completedAt: null },
                        screenshot: { stepName: 'Screenshot Proof', status: 'not_submitted', coins: 0, imageUrl: '', rejectionReason: '', createdAt: null },
                        usageSteps: []
                    }
                });
            }

            const app = appMap.get(pkg);
            if (h.status === 'removed' || h.status === 'uninstalled') {
                app.status = h.status;
            }
            if (h.configSnapshot && !app.configSnapshot) {
                app.configSnapshot = h.configSnapshot;
            }
            if (h.isVerificationEnabled !== undefined) {
                app.isVerificationEnabled = h.isVerificationEnabled === true;
            }

            if (h.stepType === 'install') {
                if (h.status === 'completed' || h.status === 'approved') {
                    app.steps.install.status = 'completed';
                    app.steps.install.coins = Number(h.coins) || 0;
                    app.steps.install.completedAt = h.completedAt || h.createdAt;
                    app.totalCoinsEarned += (Number(h.coins) || 0);
                } else {
                    app.steps.install.status = h.status || 'in_progress';
                }
            } else if (h.stepType === 'screenshot') {
                app.steps.screenshot.status = h.status;
                app.steps.screenshot.imageUrl = h.proofImageUrl || '';
                app.steps.screenshot.rejectionReason = h.rejectionReason || '';
                if (h.status === 'approved' || h.status === 'completed') {
                    app.totalCoinsEarned += (Number(h.coins) || 0);
                }
            } else if (h.stepType === 'usage' || h.stepType === 'daily_usage') {
                if (h.status === 'completed' || h.status === 'approved') {
                    app.totalCoinsEarned += (Number(h.coins) || 0);
                }
            }
        });

        // Also merge pending/approved/rejected proofs from ScreenshotProof collection
        proofs.forEach(p => {
            const pkg = p.offerId ? p.offerId.replace('super_offer_', '') : p.appName || 'super_offer_app';
            if (!appMap.has(pkg)) {
                appMap.set(pkg, {
                    packageName: pkg,
                    appName: p.appName || pkg,
                    isVerificationEnabled: true,
                    configSnapshot: null,
                    status: 'in_progress',
                    totalCoinsEarned: 0,
                    totalOfferCoins: 0,
                    lastActivityAt: p.createdAt,
                    steps: {
                        install: { stepName: 'Install App & Initial Launch', status: 'completed', coins: 0, completedAt: p.createdAt },
                        screenshot: { stepName: 'Screenshot Proof', status: 'not_submitted', coins: 0, imageUrl: '', rejectionReason: '', createdAt: null },
                        usageSteps: []
                    }
                });
            }

            const app = appMap.get(pkg);
            let imgUrl = p.imageUrl || p.proofImageUrl || '';
            if (imgUrl && !imgUrl.startsWith('http') && !imgUrl.startsWith('/') && !imgUrl.startsWith('data:')) {
                imgUrl = '/' + imgUrl;
            }

            const scStatus = p.status === 'pending' ? 'pending_proof' : p.status;
            app.steps.screenshot.status = scStatus;
            app.steps.screenshot.imageUrl = imgUrl;
            app.steps.screenshot.rejectionReason = p.rejectionReason || '';
            app.steps.screenshot.coins = Number(p.coins) || 0;

            // Only add if not already added from SuperOfferHistory (prevent double counting)
            const alreadyAddedFromHistory = history.some(h =>
                (h.packageName === pkg || h.appName === app.appName) &&
                h.stepType === 'screenshot' &&
                (h.status === 'approved' || h.status === 'completed')
            );
            if (!alreadyAddedFromHistory && (p.status === 'approved' || p.status === 'completed')) {
                app.totalCoinsEarned += (Number(p.coins) || 0);
            }
        });

        // Determine Overall App Status & calculate total potential offer coins & distribute into completedApps vs pendingApps
        Array.from(appMap.values()).forEach(app => {
            const isInstallDone = app.steps.install && app.steps.install.status === 'completed';
            const scStatus = app.steps.screenshot ? app.steps.screenshot.status : 'not_submitted';

            const activeMethod = Number(app.configSnapshot?.activeMethod || superOfferConfig?.activeMethod || 4);
            const isScreenshotOn = app.isVerificationEnabled && (activeMethod === 4) &&
                (app.configSnapshot?.screenshotVerificationEnabled !== false && superOfferConfig?.screenshotVerificationEnabled !== false);

            const configuredUsageSteps = (app.configSnapshot && Array.isArray(app.configSnapshot.usageSteps) && app.configSnapshot.usageSteps.length > 0)
                ? app.configSnapshot.usageSteps
                : ((superOfferConfig && Array.isArray(superOfferConfig.usageSteps))
                    ? superOfferConfig.usageSteps
                    : []);
            const hasUsageSteps = configuredUsageSteps.length > 0;

            // Calculate Total Potential Offer Coins completely dynamically from config/snapshot
            const installCoins = (app.steps?.install?.coins > 0)
                ? Number(app.steps.install.coins)
                : (Number(app.configSnapshot?.reward) || Number(superOfferConfig?.reward) || 0);

            const screenshotCoins = isScreenshotOn
                ? (Number(app.steps?.screenshot?.coins) || Number(app.configSnapshot?.screenshotCoins) || Number(superOfferConfig?.screenshotCoins) || 0)
                : 0;

            let usageCoinsTotal = 0;
            if (app.isVerificationEnabled && hasUsageSteps) {
                configuredUsageSteps.forEach(st => {
                    usageCoinsTotal += (Number(st.coins) || 0);
                });
            }

            app.totalOfferCoins = app.isVerificationEnabled ? (installCoins + screenshotCoins + usageCoinsTotal) : installCoins;

            // CASE 0: Removed or Uninstalled offers
            if (app.status === 'removed' || app.status === 'uninstalled') {
                completedApps.push(app);
                return;
            }

            // CASE 1: Verification was OFF for this offer (Single Step)
            if (!app.isVerificationEnabled) {
                if (isInstallDone) {
                    app.status = 'completed';
                    completedApps.push(app);
                } else {
                    app.status = 'in_progress';
                    pendingApps.push(app);
                }
                return;
            }

            // CASE 2: Verification was ON for this offer (Multi-Step Pipeline)
            // Check if all configured usage steps are done
            let allUsageStepsDone = true;
            if (hasUsageSteps) {
                for (let i = 0; i < configuredUsageSteps.length; i++) {
                    const stepNum = isScreenshotOn ? (i + 3) : (i + 2);
                    const st = configuredUsageSteps[i];
                    const isDone = history.some(h => {
                        const isSame = (h.packageName === app.packageName || h.appName === app.appName);
                        if (!isSame) return false;
                        if (h.stepName && st.name) {
                            if (h.stepName.trim().toLowerCase() === st.name.trim().toLowerCase()) {
                                return (h.status === 'completed' || h.status === 'approved' || h.status === 'skipped');
                            }
                        }
                        return (h.stepNumber === stepNum) && (h.status === 'completed' || h.status === 'approved' || h.status === 'skipped');
                    });
                    if (!isDone) {
                        allUsageStepsDone = false;
                        break;
                    }
                }
            }

            const isScreenshotBypassed = !isScreenshotOn;

            if (isScreenshotBypassed || scStatus === 'approved' || scStatus === 'completed') {
                if (hasUsageSteps && !allUsageStepsDone) {
                    app.status = 'in_progress';
                    pendingApps.push(app);
                } else {
                    app.status = 'completed';
                    completedApps.push(app);
                }
            } else if (scStatus === 'rejected') {
                app.status = 'rejected';
                pendingApps.push(app);
            } else if (scStatus === 'pending_proof' || scStatus === 'pending') {
                app.status = 'pending_proof';
                pendingApps.push(app);
            } else {
                app.status = isInstallDone ? 'pending_upload' : 'in_progress';
                pendingApps.push(app);
            }
        });

        completedApps.sort((a, b) => new Date(b.lastActivityAt || 0) - new Date(a.lastActivityAt || 0));
        pendingApps.sort((a, b) => new Date(b.lastActivityAt || 0) - new Date(a.lastActivityAt || 0));

        // 6. Sort combined history chronologically descending
        history.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

        // 7. Apply status filtering
        if (status && status !== 'all') {
            history = history.filter(h => {
                if (status === 'pending_proof' || status === 'pending') {
                    return h.status === 'pending_proof' || h.status === 'pending' || h.status === 'started';
                }
                return h.status === status;
            });
        }

        // 8. Calculate KPI summary (totalCoins earned across all super offer activity)
        const totalCoins = Array.from(appMap.values()).reduce((sum, h) => sum + (Number(h.totalCoinsEarned) || 0), 0);
        const summary = {
            totalStarted: completedApps.length + pendingApps.length,
            totalCompleted: completedApps.length,
            totalPending: pendingApps.length,
            totalRemoved: history.filter(h => h.status === 'removed').length,
            totalCoinsEarned: totalCoins,
        };

        return res.json({
            success: true,
            superOfferConfig: superOfferConfig || {},
            apps: [...completedApps, ...pendingApps],
            pendingApps,
            completedApps,
            history,
            summary
        });
    } catch (err) {
        console.error('🔥 Error fetching user super offer history:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

// DELETE SINGLE SUPER OFFER HISTORY ITEM
router.post('/admin/user-super-offer-history/delete/:id', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const id = req.params.id;

        let hRes = null;
        let pRes = null;
        if (id && id.match(/^[0-9a-fA-F]{24}$/)) {
            hRes = await SuperOfferHistory.findByIdAndDelete(id);
            pRes = await ScreenshotProof.findByIdAndDelete(id);
        }

        if (hRes || pRes) {
            return res.json({ success: true, message: 'Super Offer history item deleted successfully' });
        }
        return res.status(404).json({ success: false, message: 'Record not found' });
    } catch (err) {
        console.error('🔥 Error deleting super offer history item:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

// DELETE ENTIRE APP SUPER OFFER RECORD FOR A USER
router.post('/admin/user-super-offer-history/delete-app', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const { userId, packageName } = req.body || {};
        if (!userId || !packageName) {
            return res.status(400).json({ success: false, message: 'Missing userId or packageName' });
        }

        const userDoc = await User.findOne({
            $or: [
                { userId: userId },
                { userId: String(userId).trim() },
                { email: userId },
                { gmail: userId }
            ]
        }).lean();

        const uidList = [userId, String(userId).trim()];
        if (userDoc) {
            if (userDoc.userId) {
                uidList.push(userDoc.userId);
                uidList.push(String(userDoc.userId).trim());
            }
            if (userDoc.email) uidList.push(userDoc.email);
            if (userDoc.gmail) uidList.push(userDoc.gmail);
        }

        const pkgRegex = new RegExp('^' + String(packageName).replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i');
        const offerIdRegex = new RegExp(String(packageName).replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&'), 'i');

        const userFilter = {
            $or: [
                { userId: { $in: uidList } },
                { userEmail: { $in: uidList } }
            ]
        };

        const superOfferFilter = {
            $and: [
                userFilter,
                {
                    $or: [
                        { packageName: pkgRegex },
                        { appName: pkgRegex },
                        { offerId: offerIdRegex }
                    ]
                }
            ]
        };

        const proofFilter = {
            $and: [
                userFilter,
                {
                    $or: [
                        { offerId: offerIdRegex },
                        { appName: pkgRegex }
                    ]
                }
            ]
        };

        // Mark as removed in SuperOfferHistory instead of hard deletion so record is preserved with 'REMOVED' status tag
        const hRes = await SuperOfferHistory.updateMany(
            superOfferFilter,
            { $set: { status: 'removed', removedAt: new Date() } }
        );
        const pRes = await ScreenshotProof.updateMany(
            proofFilter,
            { $set: { status: 'rejected', rejectionReason: 'Offer removed by admin' } }
        );

        // Invalidate Redis cache
        try {
            const cacheService = require('../../services/cacheService');
            if (cacheService && cacheService.del) {
                await cacheService.del('so_user_' + userId);
                await cacheService.del('user_data_' + userId);
            }
        } catch (_) { }

        return res.json({
            success: true,
            message: `Successfully marked offer as removed for ${packageName}`,
            modifiedCount: (hRes.modifiedCount || 0) + (pRes.modifiedCount || 0)
        });
    } catch (err) {
        console.error('🔥 Error deleting super offer app history:', err);
        return res.status(500).json({ success: false, message: 'Server error' });
    }
});

// DIAMOND CATCH PAGE
router.get('/diamond-catch', adminAuth, checkPermission('diamondCatch', 'dailyTasks', 'appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        const superOfferConfig = appDataDoc?.config?.superOfferConfig || {};

        res.render('diamond-catch/manage', {
            config: superOfferConfig,
            activePage: 'diamond-catch',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Error rendering Diamond Catch Page:', err);
        res.status(500).send('Internal Server Error');
    }
});

// MANAGE APP SETTINGS PAGE
router.get('/manage-app-settings', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        res.render('app-settings/manage', {
            firebaseServices,
            activeAppName: activeApp.appName,
            activePage: 'app-settings',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Error rendering Manage App Settings:', err);
        res.status(500).send('Internal Server Error');
    }
});

// MANAGE OFFERWALL PAGE
router.get('/manage-offerwall', adminAuth, checkPermission('offerwall', 'dailyTasks', 'appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        res.render('app-settings/offerwall', {
            firebaseServices,
            activeAppName: activeApp.appName,
            activePage: 'offerwall',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Error rendering Manage Offerwalls:', err);
        res.status(500).send('Internal Server Error');
    }
});

// MANAGE SURVEY PAGE
router.get('/manage-survey', adminAuth, checkPermission('survey', 'dailyTasks', 'appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        res.render('app-settings/survey', {
            firebaseServices,
            activeAppName: activeApp.appName,
            activePage: 'survey',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Error rendering Manage Surveys:', err);
        res.status(500).send('Internal Server Error');
    }
});

// MANAGE DAILY CHECK-IN & FOLLOW PAGE
router.get('/manage-daily-checkin-follow', adminAuth, checkPermission('dailyCheckinFollow', 'dailyTasks', 'appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        res.render('app-settings/daily-checkin-follow', {
            firebaseServices,
            activeAppName: activeApp.appName,
            activePage: 'daily-checkin-follow',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Error rendering Manage Daily Check-in & Follow:', err);
        res.status(500).send('Internal Server Error');
    }
});

// MORE APPS STANDALONE ADMIN PAGE
router.get('/more-apps-admin', adminAuth, checkPermission('moreApps', 'appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        const config = appDataDoc?.config || {};
        const moreApps = Array.isArray(config.moreApps) ? config.moreApps : (Array.isArray(config.ourApps) ? config.ourApps : []);

        res.render('app-settings/more-apps', {
            moreApps,
            activePage: 'more-apps',
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Error rendering More Apps Admin:', err);
        res.status(500).send('Internal Server Error');
    }
});

// SAVE MORE APPS STANDALONE ROUTE
router.post('/more-apps-admin/save', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const moreApps = Array.isArray(req.body?.moreApps) ? req.body.moreApps : [];

        let appDataDoc = await AppData.findOne({ key: 'appData' });
        const existingConfig = appDataDoc?.config || {};
        const updatedConfig = { ...existingConfig, moreApps: moreApps, ourApps: moreApps };

        await AppData.findOneAndUpdate(
            { key: 'appData' },
            { config: updatedConfig, updatedAt: new Date() },
            { upsert: true }
        );

        await cacheService.del('global:appData');

        return res.json({
            success: true,
            message: 'More Apps saved successfully!',
            moreApps: moreApps
        });
    } catch (err) {
        console.error('❌ Error saving More Apps:', err);
        return res.status(500).json({ success: false, message: 'Failed to save More Apps' });
    }
});

// APP DATA: GET CONFIGS
router.get('/app-data-config', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const [appDataDoc, offersDoc, referralDoc] = await Promise.all([
            AppData.findOne({ key: 'appData' }).lean(),
            OffersSettings.findOne({ key: 'offersSettings' }).lean(),
            ReferralSettings.findOne({ key: 'referralSettings' }).lean(),
        ]);

        let appData = {
            ...(appDataDoc?.config || {}),
            conversionRate: Number(appDataDoc?.config?.conversionRate || appDataDoc?.conversionRate || 150),
            showCoinConversionRate: Boolean(appDataDoc?.config?.showCoinConversionRate ?? appDataDoc?.showCoinConversionRate ?? false),
            oneSignalAppId: String(appDataDoc?.config?.oneSignalAppId !== undefined ? appDataDoc.config.oneSignalAppId : (appDataDoc?.oneSignalAppId || '')).trim(),
            oneSignalApiKey: String(appDataDoc?.config?.oneSignalApiKey !== undefined ? appDataDoc.config.oneSignalApiKey : (appDataDoc?.oneSignalApiKey || '')).trim(),
        };
        let offersSettings = resolveOfferwallEnvFallbacks(offersDoc?.config || {});
        let referralSettings = referralDoc?.config || {};

        return res.json({
            success: true,
            app: 'Crazyreward',
            appData: serializeFirestoreValue(appData),
            offersSettings: serializeFirestoreValue(offersSettings),
            referralSettings: serializeFirestoreValue(referralSettings),
        });
    } catch (err) {
        console.error('❌ App data fetch error:', err);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch app data',
        });
    }
});

// APP DATA: UPDATE APP DATA DOC
router.post('/app-data-config/app-data', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const normalized = normalizeAppDataPayload(req.body?.appData || {});
        if (!normalized.ok) {
            return res.status(400).json({ success: false, message: normalized.message });
        }

        let appDataDoc = await AppData.findOne({ key: 'appData' });
        const existingConfig = appDataDoc?.config || {};
        const updatedConfig = { ...existingConfig };
        for (const [key, val] of Object.entries(normalized.updates)) {
            if (key === 'screenBanners') {
                updatedConfig[key] = val;
            } else if (existingConfig[key] && typeof existingConfig[key] === 'object' && !Array.isArray(existingConfig[key]) &&
                val && typeof val === 'object' && !Array.isArray(val)) {
                updatedConfig[key] = { ...existingConfig[key], ...val };
            } else {
                updatedConfig[key] = val;
            }
        }

        const updateDoc = {
            config: updatedConfig,
            updatedAt: new Date()
        };
        if (updatedConfig.oneSignalAppId !== undefined) {
            updateDoc.oneSignalAppId = updatedConfig.oneSignalAppId;
        }
        if (updatedConfig.oneSignalApiKey !== undefined) {
            updateDoc.oneSignalApiKey = updatedConfig.oneSignalApiKey;
        }
        if (updatedConfig.conversionRate !== undefined) {
            updateDoc.conversionRate = updatedConfig.conversionRate;
        }
        if (updatedConfig.showCoinConversionRate !== undefined) {
            updateDoc.showCoinConversionRate = updatedConfig.showCoinConversionRate;
        }

        await AppData.findOneAndUpdate(
            { key: 'appData' },
            updateDoc,
            { upsert: true }
        );

        await cacheService.del('global:appData');
        await cacheService.del('diamondcatch:config');

        return res.json({
            success: true,
            message: 'appData updated successfully',
        });
    } catch (err) {
        console.error('❌ App data update error:', err);
        return res.status(500).json({ success: false, message: 'Failed to update appData' });
    }
});

// GET BANNER CLICK STATS
router.get('/admin/banner-stats', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const screenKey = String(req.query.screenKey || '').trim();
        if (!screenKey) {
            return res.status(400).json({ success: false, message: 'screenKey is required' });
        }

        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const istNow = new Date(now.getTime() + istOffset);
        const todayStr = istNow.toISOString().slice(0, 10); // 'YYYY-MM-DD'

        const yesterdayDate = new Date(now.getTime() + istOffset - (24 * 60 * 60 * 1000));
        const yesterdayStr = yesterdayDate.toISOString().slice(0, 10);

        const startDate = String(req.query.startDate || '').trim();
        const endDate = String(req.query.endDate || '').trim();

        const matchFilter = { screenKey };
        if (startDate && endDate) {
            matchFilter.date = { $gte: startDate, $lte: endDate };
        } else if (startDate) {
            matchFilter.date = { $gte: startDate };
        } else if (endDate) {
            matchFilter.date = { $lte: endDate };
        }

        const [totalClicks, todayClicks, yesterdayClicks, distinctUsers, filteredClicks, filteredDistinctUsers, dateLogs] = await Promise.all([
            BannerClickLogs.countDocuments({ screenKey }),
            BannerClickLogs.countDocuments({ screenKey, date: todayStr }),
            BannerClickLogs.countDocuments({ screenKey, date: yesterdayStr }),
            BannerClickLogs.distinct('userId', { screenKey, userId: { $ne: '' } }),
            (startDate || endDate) ? BannerClickLogs.countDocuments(matchFilter) : null,
            (startDate || endDate) ? BannerClickLogs.distinct('userId', { ...matchFilter, userId: { $ne: '' } }) : null,
            BannerClickLogs.aggregate([
                { $match: matchFilter },
                {
                    $group: {
                        _id: '$date',
                        clicks: { $sum: 1 },
                        uniqueUsers: { $addToSet: '$userId' },
                    }
                },
                { $sort: { _id: -1 } },
                { $limit: 100 }
            ])
        ]);

        const dateWise = dateLogs.map(d => ({
            date: d._id,
            clicks: d.clicks,
            uniqueUsers: (d.uniqueUsers || []).filter(Boolean).length
        }));

        return res.json({
            success: true,
            screenKey,
            todayDate: todayStr,
            yesterdayDate: yesterdayStr,
            startDate: startDate || null,
            endDate: endDate || null,
            stats: {
                totalClicks,
                uniqueUsers: distinctUsers.length,
                todayClicks,
                yesterdayClicks,
                filteredClicks: filteredClicks !== null ? filteredClicks : totalClicks,
                filteredUniqueUsers: filteredDistinctUsers !== null ? filteredDistinctUsers.length : distinctUsers.length,
                dateWise,
            }
        });
    } catch (err) {
        console.error('❌ Error fetching banner stats:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch banner stats' });
    }
});

// UPDATE DAILY TASK SECTION TITLE
router.post('/update-daily-task-title', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const rawTitle = (req.body?.title || '').trim();
        const title = rawTitle || 'Daily Task';

        let appDataDoc = await AppData.findOne({ key: 'appData' });
        const existingConfig = appDataDoc?.config || {};
        const updatedConfig = { ...existingConfig, dailyTaskTitle: title };

        await AppData.findOneAndUpdate(
            { key: 'appData' },
            { config: updatedConfig, updatedAt: new Date() },
            { upsert: true }
        );

        await cacheService.del('global:appData');

        return res.json({
            success: true,
            message: 'Daily Task title saved successfully!',
            title: title
        });
    } catch (err) {
        console.error('❌ Error updating Daily Task title:', err);
        return res.status(500).json({ success: false, message: 'Failed to update Daily Task title' });
    }
});

// APP DATA: UPDATE OFFERS SETTINGS
router.post('/app-data-config/offers-settings', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const normalized = normalizeOffersSettingsPayload(req.body?.offersSettings || {});
        if (!normalized.ok) {
            return res.status(400).json({ success: false, message: normalized.message });
        }

        let offersDoc = await OffersSettings.findOne({ key: 'offersSettings' });
        const existingConfig = offersDoc?.config || {};

        // Determine category of the incoming save request (from payload or explicit req.body.category)
        let targetCategory = req.body?.category || 'task';
        for (const val of Object.values(normalized.offersSettings || {})) {
            if (val.category) {
                targetCategory = val.category;
                break;
            }
        }

        // Build the new merged configuration
        const mergedOffers = {};

        // 1. Keep keys from existingConfig that do NOT belong to the targetCategory
        for (const [key, val] of Object.entries(existingConfig)) {
            const SURVEY_PROVIDERS = ['cpxresearch', 'bitlabs', 'pollfish', 'inbrain', 'tapresearch', 'theoremreach', 'yuno'];
            const cleanKey = key.toLowerCase().replace(/[\s\-_]/g, '');
            const itemCategory = val.category || (SURVEY_PROVIDERS.includes(cleanKey) ? 'survey' : 'task');

            if (itemCategory !== targetCategory) {
                mergedOffers[key] = val;
            }
        }

        // 2. Add all incoming settings (this replaces/adds targetCategory ones, and drops deleted ones)
        for (const [key, val] of Object.entries(normalized.offersSettings || {})) {
            mergedOffers[key] = val;
        }

        await OffersSettings.findOneAndUpdate(
            { key: 'offersSettings' },
            { config: mergedOffers, updatedAt: new Date() },
            { upsert: true }
        );

        await cacheService.del('global:appData');

        return res.json({
            success: true,
            message: 'offersSettings updated successfully',
        });
    } catch (err) {
        console.error('❌ Offers settings update error:', err);
        return res.status(500).json({ success: false, message: 'Failed to update offers settings' });
    }
});

// APP DATA: UPDATE REFERRAL SETTINGS
router.post('/app-data-config/referral-settings', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const normalized = normalizeReferralSettingsPayload(req.body?.referralSettings || {});
        if (!normalized.ok) {
            return res.status(400).json({ success: false, message: normalized.message });
        }

        const existingDoc = await ReferralSettings.findOne({ key: 'referralSettings' }).lean();
        const existingConfig = existingDoc?.config || {};

        const finalConfig = {
            ...existingConfig,
            ...normalized.referralSettings,
            referredRewardEnabled: ('referredRewardEnabled' in (req.body?.referralSettings || {}))
                ? normalized.referralSettings.referredRewardEnabled
                : (existingConfig.referredRewardEnabled === true),
            referredRewardCoins: ('referredRewardCoins' in (req.body?.referralSettings || {}))
                ? normalized.referralSettings.referredRewardCoins
                : (Number(existingConfig.referredRewardCoins) || 0),
            missionsEnabled: ('missionsEnabled' in (req.body?.referralSettings || {}))
                ? normalized.referralSettings.missionsEnabled
                : (existingConfig.missionsEnabled === true),
            missionsSubtitle: ('missionsSubtitle' in (req.body?.referralSettings || {}))
                ? normalized.referralSettings.missionsSubtitle
                : (existingConfig.missionsSubtitle || existingConfig.missionsDescription || ''),
            missions: (Array.isArray(req.body?.referralSettings?.missions))
                ? normalized.referralSettings.missions
                : (existingConfig.missions || []),
        };

        await ReferralSettings.findOneAndUpdate(
            { key: 'referralSettings' },
            { config: finalConfig, updatedAt: new Date() },
            { upsert: true }
        );

        await cacheService.del('global:appData');

        return res.json({
            success: true,
            message: 'referralSettings updated successfully',
        });
    } catch (err) {
        console.error('❌ Referral settings update error:', err);
        return res.status(500).json({ success: false, message: 'Failed to update referral settings' });
    }
});

// APP DATA: UPDATE REFERRAL MISSIONS
router.post('/app-data-config/referral-missions', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const missionsEnabled = req.body?.missionsEnabled === true;
        const missionsSubtitle = typeof req.body?.missionsSubtitle === 'string'
            ? req.body.missionsSubtitle.trim()
            : (typeof req.body?.missionsDescription === 'string' ? req.body.missionsDescription.trim() : '');
        const rawMissions = Array.isArray(req.body?.missions) ? req.body.missions : [];

        const missions = [];
        for (const m of rawMissions) {
            const target = Number(m.target);
            const reward = Number(m.reward);
            const enabled = m.enabled !== false;
            const title = String(m.title || `Invite ${target} Friends`).trim();
            const criteriaType = ['direct', 'withdrawal', 'offerwall', 'survey', 'super_offer'].includes(m.criteriaType)
                ? m.criteriaType
                : 'direct';
            const criteriaCount = Number(m.criteriaCount) > 0 ? Math.max(1, Math.round(Number(m.criteriaCount))) : 1;

            if (Number.isFinite(target) && target > 0 && Number.isFinite(reward) && reward >= 0) {
                missions.push({
                    id: String(m.id || `mission_${target}_${criteriaType}`),
                    target,
                    reward,
                    criteriaType,
                    criteriaCount: criteriaType === 'direct' ? 1 : criteriaCount,
                    enabled,
                    title,
                });
            }
        }
        missions.sort((a, b) => a.target - b.target);

        // Fetch existing referralSettings to preserve firstLevel, secondLevel, thirdLevel
        const existingDoc = await ReferralSettings.findOne({ key: 'referralSettings' }).lean();
        const existingConfig = existingDoc?.config || {};

        const updatedConfig = {
            ...existingConfig,
            missionsEnabled,
            missionsSubtitle,
            missions,
        };

        await ReferralSettings.findOneAndUpdate(
            { key: 'referralSettings' },
            { config: updatedConfig, updatedAt: new Date() },
            { upsert: true }
        );

        await cacheService.del('global:appData');

        return res.json({
            success: true,
            message: 'Referral missions updated successfully',
            missionsEnabled,
            missionsSubtitle,
            missions,
        });
    } catch (err) {
        console.error('❌ Referral missions update error:', err);
        return res.status(500).json({ success: false, message: 'Failed to update referral missions' });
    }
});

// APP DATA: UPDATE SCREEN SETTINGS
router.post('/app-data-config/screen-settings', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        await connectMongo();
        const screenSettings = req.body?.screenSettings || {};
        if (!screenSettings || typeof screenSettings !== 'object' || Array.isArray(screenSettings)) {
            return res.status(400).json({ success: false, message: 'screenSettings must be an object' });
        }

        let appDataDoc = await AppData.findOne({ key: 'appData' });
        const existingConfig = appDataDoc?.config || {};

        const updatedConfig = {
            ...existingConfig,
            screenSettings: {
                ...(existingConfig.screenSettings || {}),
                ...screenSettings
            }
        };

        await AppData.findOneAndUpdate(
            { key: 'appData' },
            { config: updatedConfig, updatedAt: new Date() },
            { upsert: true }
        );

        await cacheService.del('global:appData');

        return res.json({
            success: true,
            message: 'Screen settings updated successfully',
            screenSettings: updatedConfig.screenSettings
        });
    } catch (err) {
        console.error('❌ Screen settings update error:', err);
        return res.status(500).json({ success: false, message: 'Failed to update screen settings' });
    }
});

// SEND NOTIFICATION
router.post('/send-notification', async (req, res, next) => {
    // 1. Check if it's a valid API request with x-admin-key from Cloud Functions
    const adminKey = req.headers['x-admin-key'];
    const validKey = process.env.ADMIN_SECRET_KEY || 'admin_sk_830238348d0c92b0aa01b4a7c6d7729c';
    if (adminKey && adminKey === validKey) {
        return next(); // Bypasses adminAuth and checkPermission
    }

    // 2. Otherwise, run normal adminAuth and checkPermission for the Admin UI
    adminAuth(req, res, () => {
        checkPermission('notifications')(req, res, next);
    });
}, async (req, res) => {
    try {
        const {
            title,
            body,
            image,
            big_picture,
            large_icon,
            playerId,
            userId,
            token,
            provider,
            type,
            data,
        } = req.body || {};

        const response = await sendNotificationViaApi({
            title,
            body,
            image: image || big_picture || large_icon,
            big_picture,
            large_icon,
            playerId,
            userId,
            token,
            provider,
            type,
            data,
        });

        res.status(200).json({
            success: true,
            provider: response.provider,
            data: response.data || response,
            firebase: response.firebase,
            onesignal: response.onesignal,
        });

    } catch (err) {
        console.error('❌ Notification error:', err?.response?.data || err?.message || err);

        res.status(500).json({
            success: false,
            message: err?.response?.data?.message || err?.message || 'Failed to send notification',
        });
    }
});

// API: CLEAR / RESET USER COINS (ALL, INCLUDE, OR EXCLUDE USERS)
router.post('/api/admin/clear-user-coins', adminAuth, checkPermission('appConfig'), async (req, res) => {
    try {
        const { mode, identifiers } = req.body || {};

        if (mode === 'all') {
            const result = await User.updateMany({}, { $set: { coins: 0 } });
            console.log(`[ADMIN COIN RESET] Cleared coins for ALL users by ${req.session?.adminUsername || 'Admin'}. Modified: ${result.modifiedCount}`);
            return res.status(200).json({
                success: true,
                message: `Successfully cleared coins to 0 for all users (${result.modifiedCount} accounts updated).`,
                modifiedCount: result.modifiedCount
            });
        } else if (mode === 'specific' || mode === 'include') {
            let list = [];
            if (typeof identifiers === 'string') {
                list = identifiers.split(/[\n,;]+/).map(s => s.trim()).filter(Boolean);
            } else if (Array.isArray(identifiers)) {
                list = identifiers.map(s => String(s).trim()).filter(Boolean);
            }

            if (!list.length) {
                return res.status(400).json({
                    success: false,
                    message: 'Please provide at least one valid Email or User ID.'
                });
            }

            const emailListLower = list.map(e => e.toLowerCase());
            const query = {
                $or: [
                    { email: { $in: emailListLower } },
                    { userId: { $in: list } },
                    { firebaseUid: { $in: list } },
                    { referralCode: { $in: list } },
                    { referCode: { $in: list } }
                ]
            };

            const result = await User.updateMany(query, { $set: { coins: 0 } });
            console.log(`[ADMIN COIN RESET] (INCLUDE) Cleared coins for specific users by ${req.session?.adminUsername || 'Admin'}. Targeted: ${list.length}, Modified: ${result.modifiedCount}`);

            return res.status(200).json({
                success: true,
                message: `Successfully reset coins to 0 for ${result.modifiedCount} included user(s) (out of ${list.length} provided).`,
                modifiedCount: result.modifiedCount,
                targetedCount: list.length
            });
        } else if (mode === 'exclude') {
            let list = [];
            if (typeof identifiers === 'string') {
                list = identifiers.split(/[\n,;]+/).map(s => s.trim()).filter(Boolean);
            } else if (Array.isArray(identifiers)) {
                list = identifiers.map(s => String(s).trim()).filter(Boolean);
            }

            if (!list.length) {
                return res.status(400).json({
                    success: false,
                    message: 'Please provide at least one Email or User ID to exclude (protect).'
                });
            }

            const emailListLower = list.map(e => e.toLowerCase());
            const query = {
                $and: [
                    { email: { $nin: emailListLower } },
                    { userId: { $nin: list } },
                    { firebaseUid: { $nin: list } },
                    { referralCode: { $nin: list } },
                    { referCode: { $nin: list } }
                ]
            };

            const result = await User.updateMany(query, { $set: { coins: 0 } });
            console.log(`[ADMIN COIN RESET] (EXCLUDE) Cleared coins for all users EXCEPT ${list.length} accounts by ${req.session?.adminUsername || 'Admin'}. Modified: ${result.modifiedCount}`);

            return res.status(200).json({
                success: true,
                message: `Successfully cleared coins to 0 for ${result.modifiedCount} users (Excluded/Protected ${list.length} accounts).`,
                modifiedCount: result.modifiedCount,
                excludedCount: list.length
            });
        } else {
            return res.status(400).json({
                success: false,
                message: 'Invalid mode. Please select "include", "exclude", or "all".'
            });
        }
    } catch (err) {
        console.error('❌ Error clearing user coins:', err);
        return res.status(500).json({
            success: false,
            message: err?.message || 'Failed to clear user coins.'
        });
    }
});

// API: GET DATA OF USER FOR PAYOUT VALIDATION
router.get('/get-user-data', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { userId, email, referCode, startDate, endDate } = req.query;
        const app = String(req.query?.app || '').trim();

        if (!userId && !email && !referCode) {
            return res.status(400).json({
                success: false,
                message: 'Provide one of: userId, email, referCode'
            });
        }

        // ------------------ DATE FILTERING ------------------
        let dateRange = null;
        if (startDate || endDate) {
            const start = startDate ? new Date(startDate) : null;
            const end = endDate ? new Date(endDate + 'T23:59:59.999Z') : null;
            if (start || end) {
                dateRange = { start, end };
            }
        }

        // ------------------ RESOLVE USER FROM MONGODB ------------------
        let user = null;
        if (userId) {
            user = await User.findOne({
                $or: [{ userId: String(userId) }, { firebaseUid: String(userId) }]
            }).lean();
        } else if (email) {
            const cleanEmail = String(email).trim();
            user = await User.findOne({ email: cleanEmail.toLowerCase() }).lean();
            if (!user) {
                // Fallback: Check if input was actually userId or referralCode (e.g. for guest users without email)
                user = await User.findOne({
                    $or: [
                        { userId: cleanEmail },
                        { firebaseUid: cleanEmail },
                        { referralCode: cleanEmail.toUpperCase() },
                        { referCode: cleanEmail.toUpperCase() }
                    ]
                }).lean();
            }
        } else if (referCode) {
            const refCode = String(referCode).trim();
            user = await User.findOne({
                $or: [
                    { referralCode: refCode },
                    { referCode: refCode },
                    { referralCode: refCode.toUpperCase() },
                    { userId: refCode }
                ]
            }).lean();
        }

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        const resolvedUserId = user.userId;
        const userData = user;

        // ------------------ BASIC USER DATA ------------------
        const userName = userData.name || 'Unknown User';
        const photoUrl = userData.photoUrl || '';
        const coins = userData.coins || 0;
        const totalCoins = userData.totalCoins || 0;

        // ------------------ SUB COLLECTIONS ------------------
        const userRefCode = userData.referralCode || userData.referCode || '';
        const uidList = [resolvedUserId];
        if (userData.email) uidList.push(userData.email);
        if (userData.gmail) uidList.push(userData.gmail);
        if (userData.firebaseUid) uidList.push(userData.firebaseUid);

        const mongoUserQuery = {
            $or: [
                { userId: { $in: uidList } },
                { userId: resolvedUserId }
            ]
        };
        if (dateRange && (dateRange.start || dateRange.end)) {
            const dateC = {};
            if (dateRange.start) {
                dateC.$gte = dateRange.start instanceof Date ? dateRange.start : new Date(dateRange.start);
            }
            if (dateRange.end) {
                dateC.$lte = dateRange.end instanceof Date ? dateRange.end : new Date(dateRange.end);
            }
            mongoUserQuery.$and = [
                {
                    $or: [
                        { timestamp: dateC },
                        { createdAt: dateC }
                    ]
                }
            ];
        }

        const [payoutsMongo, rewardsMongo, totalReferredUsers, superOfferHistory] = await Promise.all([
            PayoutHistory.find(mongoUserQuery).sort({ timestamp: -1, createdAt: -1 }).lean(),
            RewardHistory.find(mongoUserQuery).sort({ timestamp: -1, createdAt: -1 }).lean(),
            userRefCode ? User.countDocuments({ referredBy: userRefCode }) : Promise.resolve(0),
            SuperOfferHistory.find({ $or: [{ userId: { $in: uidList } }, { userEmail: { $in: uidList } }] }).sort({ createdAt: -1 }).lean()
        ]);

        const referralStats = {
            referralCode: userRefCode,
            referred: userData.referredBy || userData.referred || '',
            totalReferredUsers: totalReferredUsers || 0,
        };

        const payoutHistory = payoutsMongo.map(data => {
            const coins = Number(data.coins) || 0;
            const amount = Number(data.amount) || 0;
            const status = data.status || 'unknown';
            const symbol = String(data.symbol || '₹');

            return {
                coins,
                amount,
                symbol,
                status,
                methodName: data.methodName || 'unknown',
                timestamp: toIsoDate(data.timestamp || data.createdAt),
            };
        });

        const dailyTaskHistory = [];
        const taskHistory = [];
        const gameHistory = [];
        const rewardHistoryList = [];

        // All-time earnings from MongoDB
        const allEarningsMap = {};

        // Today's earnings variables
        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const todayStart = new Date(now);
        todayStart.setHours(0, 0, 0, 0);

        const isToday = (ts) => {
            if (!ts) return false;
            const date = ts instanceof Date ? ts : new Date(ts);
            return new Date(date.getTime() + istOffset) >= todayStart;
        };

        let todayRewardCoins = 0;
        const todayEarnings = [];

        for (const data of rewardsMongo) {
            const timestamp = toIsoDate(data.timestamp || data.createdAt);
            const provider = String(data.provider || 'unknown').trim();
            const offerId = String(data.offerId || '').trim();
            const coins = Number(data.coins) || 0;
            const gems = Number(data.gems) || 0;
            const rewardType = String(data.rewardType || (gems !== 0 && coins === 0 ? 'gem' : 'coin')).trim();

            const isItemToday = isToday(data.timestamp || data.createdAt);

            if (provider === 'DailyTask') {
                dailyTaskHistory.push({
                    id: data._id.toString(),
                    taskId: offerId || 'Daily Task',
                    coins,
                    timestamp
                });
                const label = `Daily Task: ${offerId || 'Daily Task'}`;
                if (!allEarningsMap[label]) allEarningsMap[label] = { name: label, coins: 0, gems: 0, rewardType: 'coin' };
                allEarningsMap[label].coins += coins;

                if (isItemToday) {
                    todayRewardCoins += coins;
                    todayEarnings.push({
                        type: 'daily_task',
                        taskId: offerId || 'Daily Task',
                        coins,
                        gems: 0,
                        rewardType: 'coin',
                        timestamp: toIsoDate(data.timestamp || data.createdAt)
                    });
                }
            } else if (provider === 'PlayGames') {
                gameHistory.push({
                    id: data._id.toString(),
                    gameId: offerId || 'Game',
                    coins,
                    timestamp
                });
                const label = `Game: ${offerId || 'Game'}`;
                if (!allEarningsMap[label]) allEarningsMap[label] = { name: label, coins: 0, gems: 0, rewardType: 'coin' };
                allEarningsMap[label].coins += coins;

                if (isItemToday) {
                    todayRewardCoins += coins;
                    todayEarnings.push({
                        type: 'game',
                        gameId: offerId || 'Game',
                        coins,
                        gems: 0,
                        rewardType: 'coin',
                        timestamp: toIsoDate(data.timestamp || data.createdAt)
                    });
                }
            } else if (provider === 'Task' || provider === 'Offerwall' || provider === 'cpx' || provider === 'wannads' || provider === 'pubscale' || provider === 'timewall' || provider === 'bitlabs') {
                taskHistory.push({
                    id: data._id.toString(),
                    taskId: offerId || 'Task',
                    coins,
                    timestamp
                });
                const label = `Task: ${offerId || 'Task'}`;
                if (!allEarningsMap[label]) allEarningsMap[label] = { name: label, coins: 0, gems: 0, rewardType: 'coin' };
                allEarningsMap[label].coins += coins;

                if (isItemToday) {
                    todayRewardCoins += coins;
                    todayEarnings.push({
                        type: 'task',
                        taskId: offerId || 'Task',
                        coins,
                        gems: 0,
                        rewardType: 'coin',
                        timestamp: toIsoDate(data.timestamp || data.createdAt)
                    });
                }
            } else {
                rewardHistoryList.push({
                    coins,
                    gems,
                    rewardType,
                    provider,
                    offerId,
                    timestamp
                });
                if (!allEarningsMap[provider]) {
                    allEarningsMap[provider] = { name: provider, coins: 0, gems: 0, rewardType: rewardType || (gems > 0 && coins === 0 ? 'gem' : 'coin') };
                }
                allEarningsMap[provider].coins += coins;
                allEarningsMap[provider].gems += gems;
                if (rewardType === 'gem' || (gems > 0 && coins === 0) || provider.toLowerCase().includes('gem')) {
                    allEarningsMap[provider].rewardType = 'gem';
                }

                if (isItemToday) {
                    if (rewardType !== 'gem' && (gems === 0 || coins > 0)) {
                        todayRewardCoins += coins;
                    }
                    todayEarnings.push({
                        type: 'reward',
                        provider,
                        coins,
                        gems,
                        rewardType,
                        timestamp: toIsoDate(data.timestamp || data.createdAt)
                    });
                }
            }
        }

        const allEarnings = Object.values(allEarningsMap);

        const conversionRate = await getAppConversionRate();
        const istNow = new Date(now.getTime() + istOffset);

        // ------------------ DAILY CHALLENGE DATA ------------------
        let dailyChallenge = {
            config: null,
            today: null,
            history: []
        };
        try {
            const DailyChallengeConfig = require('../admin/models/dailyChallengeConfig');
            const UserDailyChallenge = require('../admin/models/userDailyChallenge');
            const todayDateStr = istNow.toISOString().split('T')[0];

            const [dcConfig, dcToday, dcHistory] = await Promise.all([
                DailyChallengeConfig.findOne({ key: 'dailyChallengeConfig' }).lean(),
                UserDailyChallenge.findOne({ userId: resolvedUserId, dateStr: todayDateStr }).lean(),
                UserDailyChallenge.find({ userId: resolvedUserId }).sort({ dateStr: -1 }).limit(7).lean()
            ]);

            dailyChallenge = {
                todayDateStr,
                config: dcConfig,
                today: dcToday,
                history: dcHistory
            };
        } catch (dcErr) {
            console.error('⚠️ Error fetching Daily Challenge for user-activity:', dcErr);
        }

        const todayIstDateStr = istNow.toISOString().split('T')[0];
        let effectiveSuperOfferClaimsToday = 0;
        if (userData.superOfferClaimsDateStr === todayIstDateStr) {
            effectiveSuperOfferClaimsToday = Number(userData.superOfferClaimsToday) || 0;
        } else if (userData.superOfferClaimsToday !== undefined && userData.superOfferClaimsToday !== null && !userData.superOfferClaimsDateStr) {
            effectiveSuperOfferClaimsToday = Number(userData.superOfferClaimsToday) || 0;
        }

        let globalGapMinutes = 60;
        try {
            const AppData = require('../admin/models/appData');
            const appDataDoc = (await AppData.findOne({ key: 'appData' }).lean()) || (await AppData.findOne({}).lean());
            const rawConfig = appDataDoc?.config || appDataDoc || {};
            const superOfferConfig = rawConfig.superOfferConfig || appDataDoc?.superOfferConfig || {};
            globalGapMinutes = Number(superOfferConfig.gapMinutes || superOfferConfig.hoursGap) || 60;
        } catch (_) { }

        // ------------------ RESPONSE ------------------
        return res.json({
            success: true,
            conversionRate,
            dailyChallenge,
            user: {
                // Basic info
                userId: resolvedUserId,
                name: userData.displayName || userData.name || userName,
                userName: userData.displayName || userName,
                photoUrl,
                email: userData.email || '',

                // Wallet & earnings
                coins,
                totalCoins,
                gems: userData.gems || 0,
                dailyGems: userData.dailyGems || 0,

                // Referral
                referralCode: userData.referralCode || userData.referCode || '',
                referred: userData.referred || '',

                // Status
                blocked: !!userData.isBlocked || !!userData.blocked,
                payoutBlocked: !!userData.payoutBlocked,
                payoutBlockReason: userData.payoutBlockReason || '',
                accountDeleted: !!userData.account_deleted || !!userData.accountDeleted,

                // Security & Device Info
                deviceId: userData.deviceId || '',
                deviceModel: userData.deviceModel || '',
                osVersion: userData.osVersion || '',
                appVersion: userData.appVersion || '',
                isRooted: !!userData.isRooted,
                isEmulator: !!userData.isEmulator,
                isVpnActive: !!userData.isVpnActive,
                isDeveloperOptions: !!userData.isDeveloperOptions || !!userData.isDevModeEnabled,
                isMockLocation: !!userData.isMockLocation,
                gaid: userData.gaid || userData.GAID || '',
                ipAddress: userData.ipAddress || '',
                isGuest: !!userData.isGuest,

                // User profile
                mobileNo: userData.mobileNo || '',
                country: userData.countryCode || userData.country || '',
                source: userData.source || '',

                // Gamification
                streak: userData.streak || 0,
                streakClaimed: !!userData.streakClaimed,
                socialFollowed: userData.socialFollowed || 0,

                // Super Offer & Game Assignment
                superOfferAssignType: userData.superOfferAssignType || 'hours',
                superOfferLimit: userData.superOfferLimit !== undefined && userData.superOfferLimit !== null ? userData.superOfferLimit : 10,
                superOfferGapMinutes: userData.superOfferGapMinutes !== undefined && userData.superOfferGapMinutes !== null ? Number(userData.superOfferGapMinutes) : globalGapMinutes,
                isSuperOfferUnlocked: !!userData.isSuperOfferUnlocked,
                superOfferUnlockedAt: toIsoDate(userData.superOfferUnlockedAt),
                gameDailyLimit: userData.gameDailyLimit !== undefined && userData.gameDailyLimit !== null ? userData.gameDailyLimit : 10,
                gameClaimsToday: userData.gameClaimsToday !== undefined && userData.gameClaimsToday !== null ? userData.gameClaimsToday : 0,
                superOfferGameInstallTriggerAt: userData.superOfferGameInstallTriggerAt || 2,
                superOfferClaimsToday: effectiveSuperOfferClaimsToday,
                superOfferAssignedAt: toIsoDate(userData.superOfferAssignedAt || userData.updatedAt || userData.lastActiveAt || userData.createdAt),
                gameAssignedAt: toIsoDate(userData.gameAssignedAt || userData.superOfferAssignedAt || userData.createdAt),
                battleInstallTaskNumber: userData.battleInstallTaskNumber !== undefined && userData.battleInstallTaskNumber !== null ? userData.battleInstallTaskNumber : 0,
                battleInstallTaskCompletedToday: !!userData.battleInstallTaskCompletedToday,
                battleInstallTaskAssignedDate: toIsoDate(userData.battleInstallTaskAssignedDate || userData.createdAt),
                freeBattlesJoinedToday: userData.freeBattlesJoinedToday !== undefined && userData.freeBattlesJoinedToday !== null ? userData.freeBattlesJoinedToday : 0,
                battleDailyLimit: userData.battleDailyLimit !== undefined && userData.battleDailyLimit !== null ? userData.battleDailyLimit : 0,
                updatedAt: toIsoDate(userData.updatedAt || userData.lastActiveAt || userData.createdAt),
                createdAt: toIsoDate(userData.createdAt),

                // Timestamps
                firstLogin: toIsoDate(userData.createdAt || userData.firstLogin),
                lastLogin: toIsoDate(userData.lastActiveAt || userData.lastLogin),
            },
            referralStats,
            payoutHistory,
            rewardHistory: rewardHistoryList,
            superOfferHistory: superOfferHistory || [],
            dailyTaskHistory,
            taskHistory,
            gameHistory,
            allEarnings,
            todayEarnings: {
                totalCoins: todayRewardCoins,
                items: todayEarnings,
            },
        });
    } catch (err) {
        console.error('🔥 Error fetching user data:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error'
        });
    }
});

// PROMOTERS PAGE RENDER
router.get('/promoters', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;

        res.render('promoters/manage', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            activePage: 'promoters',
        });
    } catch (err) {
        console.error('🔥 Error rendering promoters page:', err);
        res.status(500).send('Internal Server Error');
    }
});

// API: GET LIST OF ALL PROMOTERS (with optional date filtering)
router.get('/api/promoters/list', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { app, startDate, endDate, start, end } = req.query;
        if (!app) {
            return res.status(400).json({ success: false, message: 'App is required' });
        }

        const effectiveStart = startDate || start;
        const effectiveEnd = endDate || end;

        await connectMongo();
        const mongoQuery = { app };
        if (effectiveStart || effectiveEnd) {
            mongoQuery.promoDate = {};
            if (effectiveStart) mongoQuery.promoDate.$gte = new Date(effectiveStart);
            if (effectiveEnd) mongoQuery.promoDate.$lte = new Date(effectiveEnd + 'T23:59:59.999Z');
        }

        const mongoPromoters = await Promoter.find(mongoQuery).sort({ promoDate: -1 });

        // Resolve user info from MongoDB in batch
        const userIds = [...new Set(mongoPromoters.map(p => p.userId))];
        const usersMap = new Map();

        if (userIds.length > 0) {
            const users = await User.find({ userId: { $in: userIds } }).lean();
            users.forEach(u => {
                usersMap.set(u.userId, u);
            });
        }

        // Aggregate actual direct referral counts
        const allRefCodes = [];
        mongoPromoters.forEach(p => {
            const u = usersMap.get(p.userId) || {};
            if (u.referralCode) allRefCodes.push(u.referralCode);
            if (u.referCode) allRefCodes.push(u.referCode);
            if (p.userId) allRefCodes.push(p.userId);
        });

        const countMap = {};
        if (allRefCodes.length > 0) {
            const refCountsAgg = await User.aggregate([
                { $match: { referredBy: { $in: allRefCodes } } },
                { $group: { _id: '$referredBy', count: { $sum: 1 } } }
            ]);
            refCountsAgg.forEach(r => { countMap[r._id] = r.count; });
        }

        // For each MongoDB promotion, map user stats
        const results = mongoPromoters.map((p) => {
            const userData = usersMap.get(p.userId) || {};
            const directCount = (countMap[userData.referralCode] || 0) + (countMap[userData.referCode] || 0) + (countMap[p.userId] || 0) || Number(userData.referralCount) || 0;
            const totalReferralCount = directCount;
            const totalEarnings = Number(userData.totalCoins) || Number(userData.coins) || 0;

            return {
                id: p._id,
                userId: p.userId,
                name: userData.displayName || userData.name || 'Unknown',
                email: userData.email || '',
                referralCode: userData.referralCode || userData.referCode || '',
                directRefers: directCount,
                directReferralCount: directCount,
                totalRefers: totalReferralCount,
                totalReferralCount: totalReferralCount,
                totalEarnings,
                payoutBlocked: !!userData.payoutBlocked,
                channelName: p.channelName || '',
                priceInInr: Number(p.priceInInr) || 0,
                videoLink: p.videoLink || '',
                promoDate: p.promoDate ? (p.promoDate instanceof Date ? p.promoDate.toISOString().split('T')[0] : String(p.promoDate).split('T')[0]) : ''
            };
        });

        return res.json({
            success: true,
            promoters: results,
        });
    } catch (err) {
        console.error('🔥 Error listing promoters:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// API: SEARCH USERS TO ADD AS PROMOTER
router.get('/api/promoters/search-users', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { app, query } = req.query;
        if (!app || !query) {
            return res.status(400).json({ success: false, message: 'App and query are required' });
        }

        await connectMongo();
        const trimmedQuery = String(query).trim();
        const regex = new RegExp(trimmedQuery, 'i');

        const users = await User.find({
            $or: [
                { userId: trimmedQuery },
                { email: regex },
                { displayName: regex },
                { name: regex },
                { referralCode: trimmedQuery },
                { referCode: trimmedQuery }
            ]
        }).limit(10).lean();

        return res.json({
            success: true,
            users: users.map(user => ({
                userId: user.userId,
                name: user.displayName || user.name || 'Unknown',
                email: user.email || '',
                referralCode: user.referralCode || user.referCode || '',
                isPromoter: !!user.isPromoter,
                payoutBlocked: !!user.payoutBlocked,
            })),
        });
    } catch (err) {
        console.error('🔥 Error searching users for promoter:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// API: ADD PROMOTER FLAG (and create multi-promotion entry)
router.post('/api/promoters/add', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { app, userId, channelName, priceInInr, videoLink, promoDate } = req.body;
        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'App and userId are required' });
        }

        await connectMongo();
        const userDoc = await User.findOne({ userId: String(userId) });
        if (!userDoc) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        await User.updateOne({ userId: String(userId) }, { $set: { isPromoter: true } });

        // Save to MongoDB (allows multiple promotions per user)
        const promoDateObj = promoDate ? new Date(promoDate) : new Date();
        await Promoter.create({
            userId: String(userId),
            app,
            channelName: channelName || '',
            priceInInr: Number(priceInInr) || 0,
            videoLink: videoLink || '',
            promoDate: promoDateObj
        });

        return res.json({
            success: true,
            message: 'Promotion added successfully',
        });
    } catch (err) {
        console.error('🔥 Error adding promoter:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// API: REMOVE PROMOTER FLAG (remove specific promotion by ID)
router.post('/api/promoters/remove', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { app, userId, promoId } = req.body;
        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'App and userId are required' });
        }

        // Remove from MongoDB
        await connectMongo();
        if (promoId) {
            await Promoter.deleteOne({ _id: promoId });
        } else {
            await Promoter.deleteOne({ userId: String(userId), app });
        }

        // Check if any other promotions remain for this user + app
        const remaining = await Promoter.countDocuments({ userId: String(userId), app });
        if (remaining === 0) {
            await User.updateOne({ userId: String(userId) }, { $set: { isPromoter: false } });
        }

        return res.json({
            success: true,
            message: 'Promotion entry removed successfully',
        });
    } catch (err) {
        console.error('🔥 Error removing promoter:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// API: GET DETAIL STATS FOR PROMOTER (optionally by promoId)
router.get('/api/promoters/detail', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { app, userId, promoId, startDate, endDate, start, end } = req.query;
        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'App and userId are required' });
        }

        const effectiveStart = startDate || start;
        const effectiveEnd = endDate || end;

        await connectMongo();
        const userDoc = await User.findOne({ userId: String(userId) }).lean();
        if (!userDoc) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const userData = userDoc;

        // Date bounds parsing
        let startBound = null;
        let endBound = null;
        if (effectiveStart) {
            startBound = new Date(effectiveStart);
        }
        if (effectiveEnd) {
            endBound = new Date(effectiveEnd + 'T23:59:59.999Z');
        }

        const refCodes = [userData.referralCode, userData.referCode, userId].filter(Boolean);

        // Level 1 Users: users whose referredBy is in refCodes
        const lvl1Query = {
            referredBy: { $in: refCodes }
        };
        if (startBound || endBound) {
            lvl1Query.createdAt = {};
            if (startBound) lvl1Query.createdAt.$gte = startBound;
            if (endBound) lvl1Query.createdAt.$lte = endBound;
        }
        const lvl1Users = await User.find(lvl1Query).lean();

        // Collect Level 1 identifiers (their userIds and referralCodes)
        const lvl1Ids = lvl1Users.map(u => u.userId).filter(Boolean);
        const lvl1RefCodes = lvl1Users.map(u => u.referralCode || u.referCode).filter(Boolean);
        const lvl1Identifiers = [...new Set([...lvl1Ids, ...lvl1RefCodes])];

        let lvl2Users = [];
        if (lvl1Identifiers.length > 0) {
            const lvl2Query = {
                referredBy: { $in: lvl1Identifiers },
                userId: { $nin: [userId, ...lvl1Ids] }
            };
            if (startBound || endBound) {
                lvl2Query.createdAt = {};
                if (startBound) lvl2Query.createdAt.$gte = startBound;
                if (endBound) lvl2Query.createdAt.$lte = endBound;
            }
            lvl2Users = await User.find(lvl2Query).lean();
        }

        const lvl2Ids = lvl2Users.map(u => u.userId).filter(Boolean);
        const lvl2RefCodes = lvl2Users.map(u => u.referralCode || u.referCode).filter(Boolean);
        const lvl2Identifiers = [...new Set([...lvl2Ids, ...lvl2RefCodes])];

        let lvl3Users = [];
        if (lvl2Identifiers.length > 0) {
            const lvl3Query = {
                referredBy: { $in: lvl2Identifiers },
                userId: { $nin: [userId, ...lvl1Ids, ...lvl2Ids] }
            };
            if (startBound || endBound) {
                lvl3Query.createdAt = {};
                if (startBound) lvl3Query.createdAt.$gte = startBound;
                if (endBound) lvl3Query.createdAt.$lte = endBound;
            }
            lvl3Users = await User.find(lvl3Query).lean();
        }

        const mapUserItem = (u, level) => ({
            userId: u.userId,
            email: u.email || '',
            name: u.displayName || u.name || 'Unknown User',
            level,
            coins: Number(u.coins) || 0,
            coinsEarned: Number(u.totalCoins) || Number(u.coins) || 0,
            joinedAt: u.createdAt ? (u.createdAt instanceof Date ? u.createdAt.toISOString() : new Date(u.createdAt).toISOString()) : '',
            createdAt: u.createdAt
        });

        const lvl1List = lvl1Users.map(u => mapUserItem(u, 1));
        const lvl2List = lvl2Users.map(u => mapUserItem(u, 2));
        const lvl3List = lvl3Users.map(u => mapUserItem(u, 3));

        // Sort descending by date
        const sortByDate = (a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0);
        lvl1List.sort(sortByDate);
        lvl2List.sort(sortByDate);
        lvl3List.sort(sortByDate);

        const level1Count = lvl1List.length;
        const level2Count = lvl2List.length;
        const level3Count = lvl3List.length;

        const level1Earnings = lvl1List.reduce((sum, u) => sum + u.coinsEarned, 0);
        const level2Earnings = lvl2List.reduce((sum, u) => sum + u.coinsEarned, 0);
        const level3Earnings = lvl3List.reduce((sum, u) => sum + u.coinsEarned, 0);

        const totalReferrals = level1Count + level2Count + level3Count;
        const totalEarnings = level1Earnings + level2Earnings + level3Earnings;

        // Fetch MongoDB details (optionally by promoId)
        let dbProm = null;
        if (promoId) {
            dbProm = await Promoter.findById(promoId);
        } else {
            dbProm = await Promoter.findOne({ userId: String(userId), app }).sort({ promoDate: -1 });
        }

        return res.json({
            success: true,
            isBlocked: !!userData.payoutBlocked,
            blockReason: userData.payoutBlockReason || '',
            promoter: {
                userId: userData.userId,
                name: userData.displayName || userData.name || 'Unknown',
                email: userData.email || '',
                referralCode: userData.referralCode || userData.referCode || '',
                payoutBlocked: !!userData.payoutBlocked,
                payoutBlockReason: userData.payoutBlockReason || '',
                channelName: dbProm ? dbProm.channelName : '',
                priceInInr: dbProm ? Number(dbProm.priceInInr || 0) : 0,
                videoLink: dbProm ? dbProm.videoLink : '',
                promoDate: dbProm && dbProm.promoDate ? (dbProm.promoDate instanceof Date ? dbProm.promoDate.toISOString().split('T')[0] : String(dbProm.promoDate).split('T')[0]) : ''
            },
            totals: {
                refers: totalReferrals,
                coins: totalEarnings
            },
            stats: {
                totalReferrals,
                totalEarnings,
                level1Count,
                level1Earnings,
                level2Count,
                level2Earnings,
                level3Count,
                level3Earnings,
            },
            levels: {
                lvl1: { count: level1Count, coins: level1Earnings },
                lvl2: { count: level2Count, coins: level2Earnings },
                lvl3: { count: level3Count, coins: level3Earnings }
            },
            usersByLevel: {
                lvl1: lvl1List,
                lvl2: lvl2List,
                lvl3: lvl3List
            },
            referredUsers: lvl1List,
        });
    } catch (err) {
        console.error('🔥 Error fetching promoter detail:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// API: UPDATE DETAILS OF PROMOTER (MongoDB fields, supporting promoId)
router.post('/api/promoters/update-details', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { app, userId, promoId, channelName, priceInInr, videoLink, promoDate, isBlocked, blockReason } = req.body;
        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'App and userId are required' });
        }

        await connectMongo();

        // If blocking or unblocking payout
        if (isBlocked !== undefined) {
            await User.updateOne(
                { userId: String(userId) },
                {
                    $set: {
                        payoutBlocked: !!isBlocked,
                        payoutBlockReason: blockReason || '',
                        payoutBlockUpdatedAt: new Date()
                    }
                }
            );
        }

        if (channelName !== undefined || priceInInr !== undefined || videoLink !== undefined || promoDate !== undefined) {
            const promoDateObj = promoDate ? new Date(promoDate) : new Date();

            const updateData = {
                channelName: channelName || '',
                priceInInr: Number(priceInInr) || 0,
                videoLink: videoLink || '',
                promoDate: promoDateObj
            };

            if (promoId) {
                await Promoter.findByIdAndUpdate(promoId, updateData);
            } else {
                await Promoter.findOneAndUpdate(
                    { userId: String(userId), app },
                    updateData,
                    { upsert: true }
                );
            }
        }

        return res.json({
            success: true,
            message: 'Promoter details updated successfully',
        });
    } catch (err) {
        console.error('🔥 Error updating promoter details:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// API: GET PROMOTERS COST SUMMARY
router.get('/api/promoters/cost-summary', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const app = String(req.query.app || '').trim();
        const startDate = req.query.startDate || req.query.start;
        const endDate = req.query.endDate || req.query.end;

        if (!app) {
            return res.status(400).json({ success: false, message: 'App is required' });
        }

        await connectMongo();
        const tz = 'Asia/Kolkata';
        const nowIST = DateTime.now().setZone(tz);

        const todayStart = nowIST.startOf('day').toJSDate();
        const todayEnd = nowIST.endOf('day').toJSDate();

        const yesterdayStart = nowIST.minus({ days: 1 }).startOf('day').toJSDate();
        const yesterdayEnd = nowIST.minus({ days: 1 }).endOf('day').toJSDate();

        const thisMonthStart = nowIST.startOf('month').toJSDate();
        const thisMonthEnd = nowIST.endOf('month').toJSDate();

        const lastMonthStart = nowIST.minus({ months: 1 }).startOf('month').toJSDate();
        const lastMonthEnd = nowIST.minus({ months: 1 }).endOf('month').toJSDate();

        async function getSumForRange(start, end) {
            const match = { app };
            if (start && end) {
                match.promoDate = { $gte: start, $lte: end };
            }
            const result = await Promoter.aggregate([
                { $match: match },
                { $group: { _id: null, total: { $sum: '$priceInInr' } } }
            ]);
            return result.length > 0 ? result[0].total : 0;
        }

        const [todayCost, yesterdayCost, thisMonthCost, lastMonthCost] = await Promise.all([
            getSumForRange(todayStart, todayEnd),
            getSumForRange(yesterdayStart, yesterdayEnd),
            getSumForRange(thisMonthStart, thisMonthEnd),
            getSumForRange(lastMonthStart, lastMonthEnd)
        ]);

        let filteredCost = 0;
        if (startDate || endDate) {
            const start = startDate ? DateTime.fromISO(startDate, { zone: tz }).startOf('day').toJSDate() : null;
            const end = endDate ? DateTime.fromISO(endDate, { zone: tz }).endOf('day').toJSDate() : null;
            const match = { app };
            if (start || end) {
                match.promoDate = {};
                if (start) match.promoDate.$gte = start;
                if (end) match.promoDate.$lte = end;
            }
            const result = await Promoter.aggregate([
                { $match: match },
                { $group: { _id: null, total: { $sum: '$priceInInr' } } }
            ]);
            filteredCost = result.length > 0 ? result[0].total : 0;
        } else {
            filteredCost = await getSumForRange(null, null);
        }

        return res.json({
            success: true,
            todayCost,
            yesterdayCost,
            thisMonthCost,
            lastMonthCost,
            filteredCost,
            costs: {
                today: todayCost,
                yesterday: yesterdayCost,
                thisMonth: thisMonthCost,
                lastMonth: lastMonthCost,
                filtered: filteredCost
            }
        });
    } catch (err) {
        console.error('🔥 Error fetching cost summary:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// API: CALCULATE PROFIT & LOSS WITH 30% INVALID CUT AND 10% COMMISSION DEDUCTION
router.post('/api/promoters/profit-loss', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const app = String(req.body.app || '').trim();
        const startDate = req.body.startDate || req.body.start || '';
        const endDate = req.body.endDate || req.body.end || '';
        let usdToInrRate = Number(req.body.usdToInrRate || 95);
        if (usdToInrRate <= 0) usdToInrRate = 95;

        if (!app) {
            return res.status(400).json({ success: false, message: 'App parameter required' });
        }

        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const targetService = pickFirebaseService(firebaseServices, app) || firebaseServices[0];
        const db = targetService?.db;

        let earningConfig = { adEcpm: 0.5 };
        try {
            const appDataDoc = await AppData.findOne({ appName: app }).lean();
            if (appDataDoc?.earningConfig) earningConfig = appDataDoc.earningConfig;
        } catch (e) {}

        const tz = 'Asia/Kolkata';
        const nowIST = DateTime.now().setZone(tz);
        const todayStart = nowIST.startOf('day').toJSDate();
        const todayEnd = nowIST.endOf('day').toJSDate();

        let start = null, end = null;
        if (startDate && startDate !== 'lifetime') {
            start = DateTime.fromISO(startDate, { zone: tz }).startOf('day').toJSDate();
        }
        if (endDate && endDate !== 'lifetime') {
            end = DateTime.fromISO(endDate, { zone: tz }).endOf('day').toJSDate();
        }

        const boundsStart = start || nowIST.minus({ days: 365 }).startOf('day').toJSDate();
        const boundsEnd = end || todayEnd;

        // Fetch earnings across 3 modes
        const [adsSum, offerwallSum, readEarnSum] = await Promise.all([
            getSummaryEarningForRange(db, app, 'ads', boundsStart, boundsEnd, todayStart, todayEnd, null, earningConfig),
            getSummaryEarningForRange(db, app, 'offerwall', boundsStart, boundsEnd, todayStart, todayEnd, null, earningConfig),
            getSummaryEarningForRange(db, app, 'read_earn', boundsStart, boundsEnd, todayStart, todayEnd, null, earningConfig)
        ]);

        const grossEarningsUsd = adsSum.earnings + offerwallSum.earnings + readEarnSum.earnings;
        const grossEarningsInr = grossEarningsUsd * usdToInrRate;

        // 30% Invalid Traffic Cut
        const invalidCutInr = grossEarningsInr * 0.30;
        const postInvalidInr = grossEarningsInr - invalidCutInr;

        // 10% Commission on remaining amount
        const commissionCutInr = postInvalidInr * 0.10;
        const netAppRevenueInr = postInvalidInr - commissionCutInr;

        // Successful Payouts to Users
        const mongoPayoutQuery = {
            $or: [{ appName: app }, { appName: '' }, { appName: { $exists: false } }, { appName: null }],
            status: 'success'
        };
        if (start || end) {
            mongoPayoutQuery.processTimestamp = {};
            if (start) mongoPayoutQuery.processTimestamp.$gte = start;
            if (end) mongoPayoutQuery.processTimestamp.$lte = end;
        }
        const payoutsList = await PayoutRecord.find(mongoPayoutQuery).lean();
        let totalPayoutsInr = 0;
        payoutsList.forEach(d => {
            totalPayoutsInr += Number(d.amount || 0);
        });

        // Promoter Costs
        const promoMatch = { app };
        if (start || end) {
            promoMatch.promoDate = {};
            if (start) promoMatch.promoDate.$gte = start;
            if (end) promoMatch.promoDate.$lte = end;
        }
        const promotions = await Promoter.find(promoMatch).lean();
        let promoterCostInr = 0;
        promotions.forEach(p => {
            promoterCostInr += Number(p.priceInInr || 0);
        });

        // Net Profit / Loss
        const netProfitLossInr = netAppRevenueInr - promoterCostInr - totalPayoutsInr;
        const isProfitable = netProfitLossInr >= 0;

        return res.json({
            success: true,
            appName: app,
            startDate: startDate || 'Lifetime',
            endDate: endDate || 'Lifetime',
            dateRange: (!startDate || startDate === 'lifetime') ? 'Lifetime' : `${startDate} to ${endDate || startDate}`,
            usdToInrRate,
            earningsUsd: Number(grossEarningsUsd.toFixed(4)),
            grossUSD: Number(grossEarningsUsd.toFixed(4)),
            grossEarningsInr: Number(grossEarningsInr.toFixed(2)),
            grossINR: Number(grossEarningsInr.toFixed(2)),
            totalRevenue: Number(grossEarningsInr.toFixed(2)),
            invalidCutInr: Number(invalidCutInr.toFixed(2)),
            commissionCutInr: Number(commissionCutInr.toFixed(2)),
            netAppRevenueInr: Number(netAppRevenueInr.toFixed(2)),
            netRevenue: Number(netAppRevenueInr.toFixed(2)),
            promoterCostInr,
            totalCost: promoterCostInr,
            payoutsTotalInr: Number(totalPayoutsInr.toFixed(2)),
            netProfitLossInr: Number(netProfitLossInr.toFixed(2)),
            netProfit: Number(netProfitLossInr.toFixed(2)),
            isProfitable,
            breakdown: {
                adsUsd: Number(adsSum.earnings.toFixed(4)),
                offerwallUsd: Number(offerwallSum.earnings.toFixed(4)),
                readEarnUsd: Number(readEarnSum.earnings.toFixed(4))
            }
        });
    } catch (err) {
        console.error('🔥 Profit/Loss calculation error:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// UPDATE USER DATA
router.post('/api/update-user-data', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        console.log("📥 Incoming /api/update-user-data request body:", JSON.stringify(req.body, null, 2));
        const { app, userId, updates } = req.body;

        if (!app || !userId) {
            console.log("❌ Missing app or userId in request body");
            return res.status(400).json({ success: false, message: 'app and userId are required' });
        }

        if (!updates || typeof updates !== 'object') {
            console.log("❌ Missing updates or updates is not an object");
            return res.status(400).json({ success: false, message: 'updates must be an object' });
        }

        await connectMongo();
        const targetUserId = String(userId).trim();
        let userDoc = await User.findOne({
            $or: [
                { userId: targetUserId },
                { email: targetUserId.toLowerCase() },
                { gmail: targetUserId.toLowerCase() },
                { firebaseUid: targetUserId }
            ]
        });
        if (!userDoc) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const updateOps = {};

        for (const [key, value] of Object.entries(updates)) {
            let parsedValue = value;

            if (value === 'true' || value === true) {
                parsedValue = true;
            } else if (value === 'false' || value === false) {
                parsedValue = false;
            } else if (
                typeof value === 'string' &&
                !isNaN(Number(value)) &&
                value !== '' &&
                !['mobileNo', 'email', 'name', 'displayName', 'userName', 'photoUrl', 'country', 'source', 'referralCode', 'referCode', 'superOfferAssignType'].includes(key)
            ) {
                parsedValue = Number(value);
            }

            if (key === 'blocked' || key === 'isBlocked') {
                updateOps['blocked'] = parsedValue;
                updateOps['isBlocked'] = parsedValue;
            } else if (key === 'name' || key === 'displayName' || key === 'userName') {
                updateOps['name'] = parsedValue;
                updateOps['displayName'] = parsedValue;
                updateOps['userName'] = parsedValue;
            } else if (key === 'referralCode' || key === 'referCode') {
                updateOps['referralCode'] = parsedValue;
                updateOps['referCode'] = parsedValue;
            } else {
                updateOps[key] = parsedValue;
            }
        }

        const now = new Date();
        const istOffset = 5.5 * 60 * 60 * 1000;
        const istNow = new Date(now.getTime() + istOffset);
        const todayIstDateStr = istNow.toISOString().split('T')[0];

        if (updates.isSuperOfferAssignedToday !== undefined) {
            const isAssigned = (updates.isSuperOfferAssignedToday === 'true' || updates.isSuperOfferAssignedToday === true);
            if (isAssigned) {
                updateOps.superOfferAssignedDateStr = todayIstDateStr;
                if (!userDoc.superOfferAssignedAt) {
                    updateOps.superOfferAssignedAt = new Date();
                }
            } else {
                updateOps.superOfferAssignedDateStr = '';
                updateOps.superOfferAssignedAt = null;
            }
            delete updateOps.isSuperOfferAssignedToday;
        }

        if (updates.isGameAssignedToday !== undefined) {
            const isAssigned = (updates.isGameAssignedToday === 'true' || updates.isGameAssignedToday === true);
            if (isAssigned) {
                updateOps.gameAssignedDateStr = todayIstDateStr;
                if (!userDoc.gameAssignedAt) {
                    updateOps.gameAssignedAt = new Date();
                }
            } else {
                updateOps.gameAssignedDateStr = '';
                updateOps.gameAssignedAt = null;
            }
            delete updateOps.isGameAssignedToday;
        }

        if (updateOps.superOfferAssignedAt) {
            const dateObj = new Date(updateOps.superOfferAssignedAt);
            if (!isNaN(dateObj.getTime())) {
                const istDate = new Date(dateObj.getTime() + istOffset);
                updateOps.superOfferAssignedDateStr = istDate.toISOString().split('T')[0];
            }
        }

        if (updateOps.gameAssignedAt) {
            const dateObj = new Date(updateOps.gameAssignedAt);
            if (!isNaN(dateObj.getTime())) {
                const istDate = new Date(dateObj.getTime() + istOffset);
                updateOps.gameAssignedDateStr = istDate.toISOString().split('T')[0];
            }
        }

        if (updateOps.battleInstallTaskAssignedDate) {
            const dateObj = new Date(updateOps.battleInstallTaskAssignedDate);
            if (!isNaN(dateObj.getTime())) {
                const istDate = new Date(dateObj.getTime() + istOffset);
                updateOps.battleInstallTaskAssignedDateStr = istDate.toISOString().split('T')[0];
            }
        }

        if (updates.superOfferClaimsToday !== undefined) {
            updateOps.superOfferClaimsToday = Number(updates.superOfferClaimsToday) || 0;
            updateOps.superOfferClaimsDateStr = todayIstDateStr;
            if (updateOps.superOfferClaimsToday === 0 && updates.isSuperOfferUnlocked === undefined) {
                updateOps.lastSuperOfferClaim = null;
                updateOps.isSuperOfferUnlocked = false;
                updateOps.superOfferUnlockedAt = null;
            }
        }

        if (updates.isSuperOfferUnlocked !== undefined) {
            const isUnlockedBool = updates.isSuperOfferUnlocked === true || updates.isSuperOfferUnlocked === 'true';
            updateOps.isSuperOfferUnlocked = isUnlockedBool;
            if (isUnlockedBool) {
                updateOps.superOfferUnlockedAt = new Date();
            } else {
                updateOps.superOfferUnlockedAt = null;
            }
        }

        // If admin updated task settings, set today assigned date so verify handler respects admin values
        if (
            updateOps.gameDailyLimit !== undefined ||
            updateOps.superOfferLimit !== undefined ||
            updateOps.superOfferGapMinutes !== undefined ||
            updateOps.superOfferGameInstallTriggerAt !== undefined ||
            updateOps.superOfferAssignType !== undefined ||
            updateOps.superOfferClaimsToday !== undefined
        ) {
            if (updates.superOfferAssignedAt === undefined && updateOps.superOfferAssignedAt === undefined) {
                updateOps.superOfferAssignedDateStr = todayIstDateStr;
                updateOps.superOfferAssignedAt = new Date();
            }
            if (updates.gameAssignedAt === undefined && updateOps.gameAssignedAt === undefined) {
                updateOps.gameAssignedDateStr = todayIstDateStr;
                updateOps.gameAssignedAt = new Date();
            }
        }

        if (
            updateOps.battleInstallTaskNumber !== undefined ||
            updateOps.battleInstallTaskCompletedToday !== undefined ||
            updateOps.battleDailyLimit !== undefined ||
            updateOps.freeBattlesJoinedToday !== undefined
        ) {
            if (updates.battleInstallTaskAssignedDate === undefined && updateOps.battleInstallTaskAssignedDate === undefined) {
                updateOps.battleInstallTaskAssignedDateStr = todayIstDateStr;
                updateOps.battleInstallTaskAssignedDate = new Date();
            }
        }

        // Check if coins were updated by admin
        if (updateOps.coins !== undefined) {
            const oldCoins = Number(userDoc.coins) || 0;
            const newCoins = Number(updateOps.coins) || 0;
            const diff = newCoins - oldCoins;

            if (diff !== 0) {
                const isAdd = diff > 0;
                const providerLabel = isAdd ? 'Added By Admin' : 'Deducted By Admin';
                const orderId = `${isAdd ? 'BONUS' : 'DEDUCT'}_${Date.now()}_${Math.floor(1000 + Math.random() * 9000)}`;

                await RewardHistory.create({
                    appName: userDoc.appName || app || '',
                    orderId: orderId,
                    userId: userDoc.userId,
                    userName: userDoc.displayName || userDoc.name || 'User',
                    email: userDoc.email || '',
                    coins: diff,
                    provider: providerLabel,
                    offerName: isAdd ? 'Admin Coins Addition' : 'Admin Coins Deduction',
                    timestamp: new Date(),
                }).catch(err => console.error('⚠️ RewardHistory create warning:', err));

                // Send OneSignal push notification
                try {
                    const sendNotificationViaApi = require('../admin/middlewares/send-notification-api');
                    await sendNotificationViaApi({
                        userId: userDoc.userId,
                        title: isAdd ? '💰 Balance Added!' : '📉 Balance Deducted',
                        body: isAdd
                            ? `🎉 Added +${diff} coins to your account.`
                            : `⚠️ Deducted ${Math.abs(diff)} coins from your account.`,
                    });
                } catch (pushErr) {
                    console.error('⚠️ OneSignal push error:', pushErr?.message || pushErr);
                }
            }
        }

        await User.updateOne({ _id: userDoc._id }, { $set: updateOps });

        // Invalidate Redis user cache
        try {
            if (cacheService && cacheService.del) {
                await cacheService.del('so_user_' + userDoc.userId);
                await cacheService.del('user_data_' + userDoc.userId);
            }
        } catch (_) { }

        return res.json({ success: true, message: 'User data updated successfully' });
    } catch (err) {
        console.error('🔥 Error updating user data:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

async function getReferralStats(userId) {
    if (!userId) {
        return {
            totalCount: 0,
            totalCoins: 0,
            level1Count: 0,
            level2Count: 0,
            level3Count: 0,
            level1Coins: 0,
            level2Coins: 0,
            level3Coins: 0,
            inviteHistory: [],
        };
    }

    try {
        await connectMongo();
        const userDoc = await User.findOne({ userId: String(userId) }).lean();
        const refCode = userDoc?.referralCode || userDoc?.referCode || userId;

        const refUsers = await User.find({
            $or: [{ referredBy: refCode }, { referredBy: String(userId) }]
        }).sort({ createdAt: -1 }).lean();

        const inviteHistory = refUsers.map(u => ({
            email: u.email || '',
            referredEmail: u.email || '',
            userId: u.userId,
            level: 1,
            coins: u.coins || 0,
            firstLogin: toIsoDate(u.createdAt),
            timestamp: toIsoDate(u.createdAt),
        }));

        const totalCoins = refUsers.reduce((sum, u) => sum + (Number(u.coins) || 0), 0);

        return {
            totalCount: refUsers.length,
            totalCoins,
            level1Count: refUsers.length,
            level2Count: 0,
            level3Count: 0,
            level1Coins: totalCoins,
            level2Coins: 0,
            level3Coins: 0,
            inviteHistory,
        };
    } catch (err) {
        console.error('🔥 Error getting referral stats from Mongo:', err);
        return {
            totalCount: 0,
            totalCoins: 0,
            level1Count: 0,
            level2Count: 0,
            level3Count: 0,
            level1Coins: 0,
            level2Coins: 0,
            level3Coins: 0,
            inviteHistory: [],
        };
    }
}

function rangeToDates(range, startDateStr, endDateStr) {
    let start = null, end = null;
    const zone = 'Asia/Kolkata';
    const now = DateTime.now().setZone(zone);

    if (range === 'today') {
        start = now.startOf('day').toJSDate();
        end = now.endOf('day').toJSDate();
    } else if (range === 'yesterday') {
        start = now.minus({ days: 1 }).startOf('day').toJSDate();
        end = now.minus({ days: 1 }).endOf('day').toJSDate();
    } else if (range === 'last7') {
        start = now.minus({ days: 6 }).startOf('day').toJSDate();
        end = now.endOf('day').toJSDate();
    } else if (range === 'last30') {
        start = now.minus({ days: 29 }).startOf('day').toJSDate();
        end = now.endOf('day').toJSDate();
    } else if (range === 'this_month' || range === 'thismonth') {
        start = now.startOf('month').toJSDate();
        end = now.endOf('month').toJSDate();
    } else if (range === 'last_month' || range === 'lastmonth') {
        start = now.minus({ months: 1 }).startOf('month').toJSDate();
        end = now.minus({ months: 1 }).endOf('month').toJSDate();
    } else if (range === 'lifetime') {
        start = null;
        end = null;
    } else if (range === 'custom') {
        if (startDateStr) {
            const parsed = DateTime.fromISO(startDateStr, { zone });
            if (parsed.isValid) start = parsed.startOf('day').toJSDate();
        }
        if (endDateStr) {
            const parsed = DateTime.fromISO(endDateStr, { zone });
            if (parsed.isValid) end = parsed.endOf('day').toJSDate();
        }
    }
    return { start, end };
}

// DASHBOARD HOME STATS
router.post('/dashboard-home-stats', adminAuth, async (req, res) => {
    try {
        const app = String(req.body?.app || '').trim();
        const range = String(req.body?.range || 'today').trim();
        const startDate = String(req.body?.startDate || '').trim();
        const endDate = String(req.body?.endDate || '').trim();

        if (!app) {
            return res.status(400).json({
                success: false,
                message: 'app param required',
            });
        }

        const cacheKey = JSON.stringify({ app, range, startDate, endDate });
        const cached = getDashboardCache(cacheKey);
        if (cached) return res.json({ success: true, data: cached });

        await connectMongo();

        const { start, end } = rangeToDates(range, startDate, endDate);
        if (!start || !end) {
            return res.status(400).json({
                success: false,
                message: 'Invalid range filters',
            });
        }

        const buckets = buildDailyBuckets(start, end, 31);
        if (!buckets.length) {
            return res.status(400).json({
                success: false,
                message: 'Range too large. Max 31 days allowed.',
            });
        }

        const conversionRate = await getAppConversionRate();

        const [
            totalUsersCount,
            activeUsersCount,
            blockedUsersCount,
            registeredInPeriodCount,
            totalCoinsAgg,
            payoutsList
        ] = await Promise.all([
            User.countDocuments({}),
            User.countDocuments({ lastActiveAt: { $gte: start, $lte: end } }),
            User.countDocuments({ isBlocked: true }),
            User.countDocuments({ createdAt: { $gte: start, $lte: end } }),
            User.aggregate([{ $group: { _id: null, total: { $sum: '$coins' } } }]),
            PayoutRecord.find({
                status: 'success',
                $or: [
                    { processTimestamp: { $gte: start, $lte: end } },
                    { timestamp: { $gte: start, $lte: end } },
                    { updatedAt: { $gte: start, $lte: end } },
                    { createdAt: { $gte: start, $lte: end } }
                ]
            }).lean()
        ]);

        const totalCoinsUsers = totalCoinsAgg[0]?.total || 0;

        const todayPayout = payoutsList.reduce((sum, d) => {
            const byAmount = Number(d.amount);
            if (Number.isFinite(byAmount) && byAmount > 0) {
                return sum + byAmount;
            }
            return sum;
        }, 0);

        const graph = await Promise.all(buckets.map(async (bucket) => {
            const [regCount, activeCount] = await Promise.all([
                User.countDocuments({ createdAt: { $gte: bucket.start, $lte: bucket.end } }),
                User.countDocuments({ lastActiveAt: { $gte: bucket.start, $lte: bucket.end } })
            ]);

            return {
                label: bucket.label,
                registrations: regCount,
                active: activeCount,
            };
        }));

        const payload = {
            range,
            rangeStart: start.toISOString(),
            rangeEnd: end.toISOString(),
            conversionRate,
            totalUsers: totalUsersCount,
            activeUsers: activeUsersCount,
            todayRegisteredUsers: registeredInPeriodCount,
            blockedUsers: blockedUsersCount,
            todayPayout: Number(todayPayout.toFixed(2)),
            totalCoinsUsers: Math.max(0, Math.round(totalCoinsUsers)),
            coinsEstimated: false,
            graph,
            lastUpdatedAt: new Date().toISOString(),
        };

        setDashboardCache(cacheKey, payload);
        return res.json({ success: true, data: payload });
    } catch (err) {
        console.error('🔥 Dashboard stats error:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error',
        });
    }
});

router.get('/dashboard-user-directory', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        await connectMongo();
        const User = require('../admin/models/user');
        const search = String(req.query?.search || '').trim();
        const limitRaw = Number(req.query?.limit || 10);
        const limit = Math.min(100, Math.max(5, Number.isFinite(limitRaw) ? Math.trunc(limitRaw) : 10));

        let query = {};
        if (search) {
            query = {
                $or: [
                    { email: new RegExp(search, 'i') },
                    { displayName: new RegExp(search, 'i') },
                    { userId: new RegExp(search, 'i') },
                    { referralCode: new RegExp(search, 'i') }
                ]
            };
        }

        const cursorRaw = req.query?.cursor;
        let offset = 0;
        if (cursorRaw !== undefined && cursorRaw !== null && cursorRaw !== '') {
            const parsed = parseInt(cursorRaw, 10);
            if (!isNaN(parsed) && parsed >= 0) {
                offset = parsed;
            }
        }

        const sortBy = String(req.query?.sortBy || 'firstLogin').trim();
        const sortOrder = String(req.query?.sortOrder || 'desc').toLowerCase() === 'asc' ? 1 : -1;

        const sortFieldMap = {
            name: 'displayName',
            email: 'email',
            coins: 'coins',
            firstLogin: 'createdAt',
            createdAt: 'createdAt',
            blocked: 'isBlocked'
        };

        const sortField = sortFieldMap[sortBy] || 'createdAt';
        const sortObj = {};
        sortObj[sortField] = sortOrder;
        if (sortField !== '_id') {
            sortObj._id = sortOrder;
        }

        const [totalCount, users] = await Promise.all([
            User.countDocuments(query),
            User.find(query)
                .sort(sortObj)
                .skip(offset)
                .limit(limit)
                .lean()
        ]);

        const formattedUsers = users.map(u => ({
            id: u.userId,
            userId: u.userId,
            email: u.email || '',
            name: u.displayName || (u.isGuest ? 'Guest User' : (u.email || 'User')),
            displayName: u.displayName || (u.isGuest ? 'Guest User' : (u.email || 'User')),
            coins: u.coins || 0,
            totalCoins: u.totalCoins || 0,
            referralCode: u.referralCode || 'N/A',
            isGuest: !!u.isGuest,
            blocked: u.isBlocked || false,
            ipAddress: u.ipAddress || '',
            joinedAt: u.createdAt ? new Date(u.createdAt).toISOString() : (u.firstLogin ? new Date(u.firstLogin).toISOString() : new Date().toISOString())
        }));

        const hasMore = (offset + users.length) < totalCount;
        const nextCursor = hasMore ? String(offset + limit) : '';

        return res.json({
            success: true,
            rows: formattedUsers,
            users: formattedUsers,
            totalCount,
            hasMore,
            nextCursor
        });
    } catch (err) {
        console.error('Error fetching dashboard user directory from MongoDB:', err);
        return res.status(500).json({ success: false, message: 'Server error loading users' });
    }
});

//! ---------------------- CHECK APP STATS ---------------------
router.post('/check-app-stats', adminAuth, async (req, res) => {
    try {
        const {
            app,
            range = 'today',
            startDate,
            endDate
        } = req.body;

        await connectMongo();
        const conversionRate = await getAppConversionRate();
        const { start, end } = rangeToDates(range, startDate, endDate);

        // ===== USERS =====
        let userQuery = {};
        if (start || end) {
            userQuery.createdAt = {};
            if (start) userQuery.createdAt.$gte = start;
            if (end) userQuery.createdAt.$lte = end;
        }

        const usersTotal = await User.countDocuments(userQuery);
        const activeUsers = await User.countDocuments(userQuery);
        const usersResult = [
            { countryLabel: 'IN', count: usersTotal }
        ];

        // ===== REWARDS =====
        let rewardQuery = {};
        if (start || end) {
            rewardQuery.createdAt = {};
            if (start) rewardQuery.createdAt.$gte = start;
            if (end) rewardQuery.createdAt.$lte = end;
        }

        const rewardsList = await RewardRecord.find(rewardQuery).lean();
        const rewardsMap = {};
        let rewardsTotalCoins = 0;
        let referralTotalCoins = 0;

        rewardsList.forEach(d => {
            const provider = (d.provider || d.type || 'In-App Task').toString();
            const coins = (typeof d.coins === 'number') ? d.coins : 0;
            const referralCoins = (typeof d.referralCoins === 'number') ? d.referralCoins : 0;

            if (!rewardsMap[provider]) {
                rewardsMap[provider] = { coins: 0, referralCoins: 0, records: 0 };
            }

            rewardsMap[provider].coins += coins;
            rewardsMap[provider].referralCoins += referralCoins;
            rewardsMap[provider].records += 1;

            rewardsTotalCoins += coins;
            referralTotalCoins += referralCoins;
        });

        const rewardsResult = Object.entries(rewardsMap).map(([provider, val]) => ({
            provider,
            coins: val.coins || 0,
            referralCoins: val.referralCoins || 0,
            coinsInRs: Number(((val.coins || 0) / conversionRate).toFixed(2)),
            records: val.records || 0,
        })).sort((a, b) => b.coins - a.coins);

        // ===== PAYOUTS =====
        const payoutsMap = {};
        let payoutsTotal = 0;

        let mongoPayoutQuery = {};
        if (start || end) {
            mongoPayoutQuery.createdAt = {};
            if (start) mongoPayoutQuery.createdAt.$gte = start;
            if (end) mongoPayoutQuery.createdAt.$lte = end;
        }

        const payoutsList = await PayoutRecord.find(mongoPayoutQuery).lean();
        payoutsList.forEach(d => {
            const method = (d.methodName || 'UPI').toString();
            const coins = (typeof d.coins === 'number') ? d.coins : 0;
            const amountInRs = Number((coins / conversionRate).toFixed(2));

            if (!payoutsMap[method]) {
                payoutsMap[method] = { amount: 0, count: 0 };
            }

            payoutsMap[method].amount += amountInRs;
            payoutsMap[method].count += 1;
            payoutsTotal += amountInRs;
        });

        const payoutsResult = Object.entries(payoutsMap).map(([method, val]) => ({
            methodName: method,
            amount: Number((val.amount || 0).toFixed(2)),
            count: val.count
        }));

        // ==== RESPONSE ====
        return res.json({
            success: true,
            data: {
                users: usersResult,
                usersTotal,
                activeUsers,
                rewards: rewardsResult,
                referralTotalCoins,
                rewardsTotalCoins,
                rewardsTotalRevenue: Number((rewardsTotalCoins / conversionRate).toFixed(2)),
                rewardsTotalRecords: rewardsList.length,
                payouts: payoutsResult,
                payoutsTotal: Number(payoutsTotal.toFixed(2)),
                conversionRate
            }
        });
    } catch (err) {
        console.error('🔥 Error in stats api:', err);
        return res.status(500).json({
            success: false,
            message: 'Internal server error'
        });
    }
});

router.get('/postback-logs', adminAuth, async (req, res) => {
    try {
        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const activeApp = pickFirebaseService(firebaseServices, req.query.appName) || firebaseServices[0] || {};

        const logs = await PostbackLogs.find({ appName: activeApp.appName }).sort({ createdAt: -1 }).limit(300);
        res.render('postback-logs', {
            firebaseServices,
            activeAppName: activeApp.appName || '',
            activePage: 'postback-logs',
            logs,
            photo: req.admin && req.admin.username ? req.admin.username.charAt(0).toUpperCase() : 'A'
        });
    } catch (err) {
        console.error('🔥 Error loading postback logs:', err);
        res.status(500).send('Error loading logs');
    }
});

// ============================================
// PAYMENT HISTORY
// ============================================
router.get('/payment-history', adminAuth, async (req, res) => {
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;

        res.render('payment-history', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
        });
    } catch (err) {
        console.error('❌ Payment history page error:', err);
        res.status(500).send('Error loading payment history');
    }
});

router.post('/payment-history/stats', adminAuth, async (req, res) => {
    try {
        const selectedApp = String(req.body?.selectedApp || '').trim();
        const dbState = await getFirestoreForApp(req, selectedApp);

        if (!dbState.ok) {
            return res.status(dbState.status).json({ success: false, message: dbState.message });
        }

        const db = dbState.db;

        await connectMongo();
        const appRegex = selectedApp ? new RegExp(selectedApp.replace(/[^a-zA-Z0-9]/g, '.*'), 'i') : null;
        const mongoQuery = { status: 'success' };
        if (appRegex) {
            mongoQuery.$or = [
                { appName: appRegex },
                { appName: { $exists: false } },
                { appName: null },
                { appName: '' }
            ];
        }

        const records = await PayoutRecord.find(mongoQuery).lean();

        const zone = 'Asia/Kolkata';
        const nowIST = DateTime.now().setZone(zone);

        let todayTotal = 0;
        let yesterdayTotal = 0;
        let monthTotal = 0;

        // Date bounds (IST)
        const todayStartIST = nowIST.startOf('day').toJSDate();
        const monthStartIST = nowIST.startOf('month').toJSDate();

        const yesterdayStartIST = nowIST.minus({ days: 1 }).startOf('day').toJSDate();
        const yesterdayEndIST = nowIST.minus({ days: 1 }).endOf('day').toJSDate();

        for (const data of records) {
            const ts = data.timestamp;

            // Convert timestamp to Date
            let payoutDate;
            if (ts instanceof Date) {
                payoutDate = ts;
            } else if (ts) {
                payoutDate = new Date(ts);
            } else {
                continue;
            }

            const amount = Number(data.amount ?? 0) || 0;

            // Check if today (IST)
            if (payoutDate >= todayStartIST) {
                todayTotal += amount;
            }

            // Check if yesterday (IST)
            if (payoutDate >= yesterdayStartIST && payoutDate <= yesterdayEndIST) {
                yesterdayTotal += amount;
            }

            // Check if this month (IST)
            if (payoutDate >= monthStartIST) {
                monthTotal += amount;
            }
        }

        const distinctMethods = await PayoutRecord.distinct('methodName', appRegex ? {
            $or: [
                { appName: appRegex },
                { appName: { $exists: false } },
                { appName: null },
                { appName: '' }
            ]
        } : {});

        const availableMethods = Array.from(new Set(
            (distinctMethods || []).map(m => String(m || '').trim()).filter(Boolean)
        )).sort();

        return res.json({
            success: true,
            stats: {
                today: todayTotal,
                yesterday: yesterdayTotal,
                month: monthTotal,
            },
            methods: availableMethods,
        });
    } catch (err) {
        console.error('❌ Payment history stats error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch stats' });
    }
});

router.post('/payment-history/list', adminAuth, async (req, res) => {
    try {
        const selectedApp = String(req.body?.selectedApp || '').trim();
        const startDate = req.body?.startDate || '';
        const endDate = req.body?.endDate || '';
        const status = String(req.body?.status || 'all').trim().toLowerCase();
        const method = String(req.body?.method || 'all').trim().toLowerCase();
        const search = String(req.body?.search || '').trim();
        const page = Math.max(1, parseInt(req.body?.page || 1) || 1);
        const limit = Math.min(100, Math.max(10, parseInt(req.body?.limit || 20) || 20));

        const dbState = await getFirestoreForApp(req, selectedApp);
        if (!dbState.ok) {
            return res.status(dbState.status).json({ success: false, message: dbState.message });
        }

        const db = dbState.db;
        const zone = 'Asia/Kolkata';

        const query = {};

        const appRegex = selectedApp ? new RegExp(selectedApp.replace(/[^a-zA-Z0-9]/g, '.*'), 'i') : null;
        if (appRegex) {
            query.$or = [
                { appName: appRegex },
                { appName: { $exists: false } },
                { appName: null },
                { appName: '' }
            ];
        }

        if (status !== 'all') {
            query.status = new RegExp(`^${status.trim()}$`, 'i');
        }

        if (method && method !== 'all') {
            const cleanMethod = method.trim().replace(/[^a-zA-Z0-9]/g, '');
            if (cleanMethod) {
                const flexPattern = cleanMethod.split('').join('.*');
                query.methodName = new RegExp(flexPattern, 'i');
            }
        }

        // Date range
        if (startDate || endDate) {
            query.timestamp = {};
            if (startDate) {
                const parsed = DateTime.fromISO(startDate, { zone });
                if (parsed.isValid) {
                    query.timestamp.$gte = parsed.startOf('day').toJSDate();
                }
            }
            if (endDate) {
                const parsed = DateTime.fromISO(endDate, { zone });
                if (parsed.isValid) {
                    query.timestamp.$lte = parsed.endOf('day').toJSDate();
                }
            }
        }

        // Search
        if (search) {
            const rx = new RegExp(search, 'i');
            const searchOr = [
                { userId: rx },
                { email: rx },
                { orderId: rx },
                { redeemCode: rx },
                { giftCode: rx },
                { refId: rx },
                { referenceId: rx },
                { txnId: rx }
            ];

            if (query.$or) {
                query.$and = [{ $or: query.$or }, { $or: searchOr }];
                delete query.$or;
            } else {
                query.$or = searchOr;
            }
        }

        await connectMongo();
        const allRecords = await PayoutRecord.find(query).sort({ timestamp: -1 }).lean();

        const totalCount = allRecords.length;

        const filteredSuccessRecords = allRecords.filter(item => String(item.status).toLowerCase() === 'success');
        const filteredSuccessCount = filteredSuccessRecords.length;
        const filteredSuccessTotal = filteredSuccessRecords.reduce((sum, item) => sum + (item.amount || 0), 0);

        const filteredFailedTotal = allRecords
            .filter(item => String(item.status).toLowerCase() === 'failed')
            .reduce((sum, item) => sum + (item.amount || 0), 0);

        const filteredPendingTotal = allRecords
            .filter(item => ['pending', 'inprogress'].includes(String(item.status).toLowerCase()))
            .reduce((sum, item) => sum + (item.amount || 0), 0);

        // Paginate
        const offset = (page - 1) * limit;
        const records = allRecords.slice(offset, offset + limit).map(data => ({
            id: data.orderId,
            orderId: String(data.orderId || ''),
            userId: String(data.userId || ''),
            email: String(data.email || ''),
            methodName: String(data.methodName || '').trim(),
            amount: Number(data.amount ?? 0) || 0,
            coins: Number(data.coins ?? 0) || 0,
            status: String(data.status || ''),
            timestamp: data.timestamp instanceof Date ? data.timestamp.toISOString() : new Date(data.timestamp).toISOString(),
            txnId: String(data.txnId || ''),
            utr: String(data.utr || ''),
            redeemCode: String(data.redeemCode || data.giftCode || ''),
            giftPin: String(data.giftPin || data.pin || ''),
            refId: String(data.refId || data.referenceId || data.txnId || ''),
        }));

        return res.json({
            success: true,
            total: totalCount,
            filteredSuccessTotal,
            filteredSuccessCount,
            filteredFailedTotal,
            filteredPendingTotal,
            page,
            limit,
            totalPages: Math.ceil(totalCount / limit),
            records,
        });
    } catch (err) {
        console.error('❌ Payment history list error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch records' });
    }
});

// Delete Payment History Record by Order ID
router.post('/payment-history/delete', adminAuth, async (req, res) => {
    try {
        const orderId = String(req.body?.orderId || '').trim();
        if (!orderId) {
            return res.status(400).json({ success: false, message: 'Order ID is required' });
        }

        await connectMongo();
        await PayoutRecord.deleteMany({ orderId });
        await PayoutHistory.deleteMany({ orderId }).catch(() => {});

        return res.json({
            success: true,
            message: `Payment record ${orderId} deleted successfully.`
        });
    } catch (err) {
        console.error('❌ Payment history delete error:', err);
        return res.status(500).json({ success: false, message: 'Failed to delete payment record' });
    }
});

// Bulk Delete Payment History Records by Order IDs
router.post('/payment-history/delete-bulk', adminAuth, async (req, res) => {
    try {
        const orderIds = Array.isArray(req.body?.orderIds) ? req.body.orderIds.map(id => String(id).trim()).filter(Boolean) : [];
        if (!orderIds.length) {
            return res.status(400).json({ success: false, message: 'No Order IDs provided for deletion' });
        }

        await connectMongo();
        const deleteRes = await PayoutRecord.deleteMany({ orderId: { $in: orderIds } });
        await PayoutHistory.deleteMany({ orderId: { $in: orderIds } }).catch(() => {});

        return res.json({
            success: true,
            message: `Successfully deleted ${deleteRes.deletedCount || orderIds.length} payment records.`,
            deletedCount: deleteRes.deletedCount || orderIds.length,
        });
    } catch (err) {
        console.error('❌ Payment history bulk delete error:', err);
        return res.status(500).json({ success: false, message: 'Failed to delete payment records in bulk' });
    }
});

router.get('/payment-history/export', adminAuth, async (req, res) => {
    try {
        const selectedApp = String(req.query?.selectedApp || '').trim();
        const startDate = req.query?.startDate || '';
        const endDate = req.query?.endDate || '';
        const status = String(req.query?.status || 'all').trim().toLowerCase();
        const method = String(req.query?.method || 'all').trim().toLowerCase();
        const search = String(req.query?.search || '').trim();

        const dbState = await getFirestoreForApp(req, selectedApp);
        if (!dbState.ok) {
            return res.status(dbState.status).json({ success: false, message: dbState.message });
        }

        const db = dbState.db;
        const zone = 'Asia/Kolkata';

        const query = { appName: selectedApp };

        if (status !== 'all') {
            query.status = status;
        }

        if (method !== 'all') {
            query.methodName = method;
        }

        // Date range
        if (startDate || endDate) {
            query.timestamp = {};
            if (startDate) {
                const parsed = DateTime.fromISO(startDate, { zone });
                if (parsed.isValid) {
                    query.timestamp.$gte = parsed.startOf('day').toJSDate();
                }
            }
            if (endDate) {
                const parsed = DateTime.fromISO(endDate, { zone });
                if (parsed.isValid) {
                    query.timestamp.$lte = parsed.endOf('day').toJSDate();
                }
            }
        }

        // Search
        if (search) {
            const rx = new RegExp(search, 'i');
            query.$or = [
                { userId: rx },
                { email: rx },
                { orderId: rx }
            ];
        }

        await connectMongo();
        const allRecords = await PayoutRecord.find(query).sort({ timestamp: -1 }).lean();

        const records = allRecords.map(data => {
            let payoutDate = data.timestamp instanceof Date ? data.timestamp : new Date(data.timestamp);
            return {
                id: data.orderId,
                orderId: String(data.orderId || ''),
                userId: String(data.userId || ''),
                email: String(data.email || ''),
                methodName: String(data.methodName || '').trim(),
                amount: Number(data.amount ?? 0) || 0,
                coins: Number(data.coins ?? 0) || 0,
                status: String(data.status || ''),
                timestamp: payoutDate,
                txnId: String(data.txnId || ''),
                utr: String(data.utr || ''),
            };
        });

        // Sort by timestamp desc
        records.sort((a, b) => b.timestamp - a.timestamp);

        // CSV header
        const csvRows = ['Order ID,Date,User ID,Email,Method,Amount,Coins,Status,UTR/Transaction ID'];

        for (const item of records) {
            const timestampStr = item.timestamp ? item.timestamp.toLocaleString('en-IN', {
                day: '2-digit', month: 'short', year: 'numeric',
                hour: '2-digit', minute: '2-digit'
            }) : '';
            const row = [
                item.orderId.replace(/,/g, ';'),
                timestampStr.replace(/,/g, ';'),
                item.userId.replace(/,/g, ';'),
                item.email.replace(/,/g, ';'),
                item.methodName.replace(/,/g, ';'),
                item.amount,
                item.coins,
                item.status.replace(/,/g, ';'),
                (item.utr || item.txnId).replace(/,/g, ';'),
            ];
            csvRows.push(row.join(','));
        }

        const csv = csvRows.join('\n');
        const filename = `payment-history-${new Date().toISOString().split('T')[0]}.csv`;

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
        return res.send(csv);
    } catch (err) {
        console.error('❌ Payment history export error:', err);
        return res.status(500).json({ success: false, message: 'Failed to export' });
    }
});

// ============================================
// REWARD HISTORY
// ============================================
router.get('/manage-reward-history', adminAuth, checkPermission('userActivity'), async (req, res) => {
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;

        res.render('reward-history', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            activePage: 'reward-history'
        });
    } catch (err) {
        console.error('❌ Reward history page error:', err);
        res.status(500).send('Error loading reward history');
    }
});

router.post('/reward-history/stats', adminAuth, async (req, res) => {
    try {
        const selectedApp = String(req.body?.selectedApp || '').trim();
        await connectMongo();

        const zone = 'Asia/Kolkata';
        const nowIST = DateTime.now().setZone(zone);

        const todayStart = nowIST.startOf('day').toJSDate();
        const monthStart = nowIST.startOf('month').toJSDate();

        // Build base matches
        const todayMatch = {
            $or: [
                { timestamp: { $gte: todayStart } },
                { createdAt: { $gte: todayStart } }
            ]
        };
        const monthMatch = {
            $or: [
                { timestamp: { $gte: monthStart } },
                { createdAt: { $gte: monthStart } }
            ]
        };
        const totalMatch = {};

        const cleanApp = selectedApp.toLowerCase().replace(/[^a-z0-9]/g, '');
        const isCrazyreward = cleanApp === 'crazyreward' || cleanApp === 'diamondpanda' || cleanApp === 'countnreward' || !selectedApp;

        if (isCrazyreward) {
            const orQuery = [
                { appName: { $regex: /^(crazy\s*reward|crazyreward|count\s*n\s*reward|diamond\s*panda|diamondpanda)$/i } },
                { appName: '' },
                { appName: null },
                { appName: { $exists: false } }
            ];
            todayMatch.$and = [{ $or: orQuery }];
            monthMatch.$and = [{ $or: orQuery }];
            totalMatch.$or = orQuery;
        } else {
            const appOr = [
                { appName: selectedApp },
                { appName: new RegExp(`^${selectedApp.replace(/[^a-zA-Z0-9]/g, '.*')}$`, 'i') }
            ];
            todayMatch.$and = [{ $or: appOr }];
            monthMatch.$and = [{ $or: appOr }];
            totalMatch.$or = appOr;
        }

        // 1. Today's coins
        const todayRes = await RewardHistory.aggregate([
            { $match: todayMatch },
            {
                $group: {
                    _id: null,
                    total: { $sum: '$coins' }
                }
            }
        ]);
        const todayCoins = todayRes[0]?.total || 0;

        // 2. This Month's coins
        const monthRes = await RewardHistory.aggregate([
            { $match: monthMatch },
            {
                $group: {
                    _id: null,
                    total: { $sum: '$coins' }
                }
            }
        ]);
        const monthCoins = monthRes[0]?.total || 0;

        // 3. Total coins
        const totalRes = await RewardHistory.aggregate([
            { $match: totalMatch },
            {
                $group: {
                    _id: null,
                    total: { $sum: '$coins' }
                }
            }
        ]);
        const totalCoins = totalRes[0]?.total || 0;

        return res.json({
            success: true,
            stats: {
                today: todayCoins,
                month: monthCoins,
                total: totalCoins
            }
        });
    } catch (err) {
        console.error('❌ Reward history stats error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch stats' });
    }
});

router.post('/reward-history/list', adminAuth, async (req, res) => {
    try {
        const selectedApp = String(req.body?.selectedApp || '').trim();
        const startDate = req.body?.startDate || '';
        const endDate = req.body?.endDate || '';
        const search = String(req.body?.search || '').trim();
        const page = Math.max(1, parseInt(req.body?.page || 1) || 1);
        const limit = Math.min(100, Math.max(10, parseInt(req.body?.limit || 20) || 20));

        const zone = 'Asia/Kolkata';
        const conditions = [];

        // App selection filter
        const cleanApp = selectedApp.toLowerCase().replace(/[^a-z0-9]/g, '');
        const isCrazyreward = cleanApp === 'crazyreward' || cleanApp === 'diamondpanda' || cleanApp === 'countnreward' || !selectedApp;

        if (isCrazyreward) {
            conditions.push({
                $or: [
                    { appName: { $regex: /^(crazy\s*reward|crazyreward|count\s*n\s*reward|diamond\s*panda|diamondpanda)$/i } },
                    { appName: '' },
                    { appName: null },
                    { appName: { $exists: false } },
                    { provider: { $regex: /^(Super Offer|PubScale|BitLabs|TimeWall|CPX|Monlix|Wannads|Offerwall)/i } }
                ]
            });
        } else {
            conditions.push({
                $or: [
                    { appName: selectedApp },
                    { appName: new RegExp(`^${selectedApp.replace(/[^a-zA-Z0-9]/g, '.*')}$`, 'i') }
                ]
            });
        }

        // Date range
        const dateCond = {};
        if (startDate) {
            const parsed = DateTime.fromISO(startDate, { zone });
            if (parsed.isValid) {
                dateCond.$gte = parsed.startOf('day').toJSDate();
            }
        }
        if (endDate) {
            const parsed = DateTime.fromISO(endDate, { zone });
            if (parsed.isValid) {
                dateCond.$lte = parsed.endOf('day').toJSDate();
            }
        }
        if (Object.keys(dateCond).length > 0) {
            conditions.push({
                $or: [
                    { timestamp: dateCond },
                    { createdAt: dateCond }
                ]
            });
        }

        // Search by userId or provider or orderId
        if (search) {
            conditions.push({
                $or: [
                    { userId: new RegExp(search.replace(/[^a-zA-Z0-9_@.-]/g, ''), 'i') },
                    { provider: new RegExp(search, 'i') },
                    { orderId: new RegExp(search, 'i') }
                ]
            });
        }

        const query = conditions.length > 1 ? { $and: conditions } : (conditions[0] || {});

        await connectMongo();

        const total = await RewardHistory.countDocuments(query);
        const offset = (page - 1) * limit;
        const records = await RewardHistory.find(query)
            .sort({ timestamp: -1, createdAt: -1, _id: -1 })
            .skip(offset)
            .limit(limit)
            .lean();

        const totalPages = Math.ceil(total / limit) || 1;

        return res.json({
            success: true,
            records,
            total,
            page,
            totalPages
        });
    } catch (err) {
        console.error('❌ Reward history list error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch reward list' });
    }
});

router.post('/reward-history/delete', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { ids } = req.body || {};
        if (!Array.isArray(ids) || ids.length === 0) {
            return res.status(400).json({ success: false, message: 'IDs array is required' });
        }

        await connectMongo();
        const result = await RewardHistory.deleteMany({ _id: { $in: ids } });

        return res.json({
            success: true,
            message: `Successfully deleted ${result.deletedCount} reward history records`,
        });
    } catch (err) {
        console.error('❌ Reward history delete error:', err);
        return res.status(500).json({ success: false, message: 'Failed to delete records' });
    }
});

// ============================================
// SUPER OFFER HISTORY
// ============================================
router.get('/manage-super-offer-history', adminAuth, checkPermission('userActivity'), async (req, res) => {
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;

        res.render('super-offer-history', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            activePage: 'super-offer-history'
        });
    } catch (err) {
        console.error('❌ Super offer history page error:', err);
        res.status(500).send('Error loading super offer history');
    }
});

// ============================================
// SUPER OFFER VERIFICATION
// ============================================
router.get('/manage-super-offer-verification', adminAuth, checkPermission('userActivity'), async (req, res) => {
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;

        res.render('super-offer/verification', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            activePage: 'super-offer-verification'
        });
    } catch (err) {
        console.error('❌ Super offer verification page error:', err);
        res.status(500).send('Error loading super offer verification');
    }
});

router.post('/super-offer-history/stats', adminAuth, async (req, res) => {
    try {
        const selectedApp = String(req.body?.selectedApp || '').trim();
        await connectMongo();

        const zone = 'Asia/Kolkata';
        const nowIST = DateTime.now().setZone(zone);

        const todayStart = nowIST.startOf('day').toJSDate();
        const monthStart = nowIST.startOf('month').toJSDate();

        const todayMatch = {
            $or: [
                { completedAt: { $gte: todayStart } },
                { installedAt: { $gte: todayStart } },
                { createdAt: { $gte: todayStart } }
            ],
            status: { $in: ['completed', 'approved'] }
        };

        const monthMatch = {
            $or: [
                { completedAt: { $gte: monthStart } },
                { installedAt: { $gte: monthStart } },
                { createdAt: { $gte: monthStart } }
            ],
            status: { $in: ['completed', 'approved'] }
        };

        const [todayRes, monthRes, inProgressCount, completedCount] = await Promise.all([
            SuperOfferHistory.aggregate([
                { $match: todayMatch },
                { $group: { _id: null, total: { $sum: '$coins' } } }
            ]),
            SuperOfferHistory.aggregate([
                { $match: monthMatch },
                { $group: { _id: null, total: { $sum: '$coins' } } }
            ]),
            SuperOfferHistory.countDocuments({ status: { $in: ['in_progress', 'pending', 'pending_proof', 'pending_upload'] } }),
            SuperOfferHistory.countDocuments({ status: { $in: ['completed', 'approved'] } })
        ]);

        return res.json({
            success: true,
            stats: {
                todayCoins: todayRes[0]?.total || 0,
                monthCoins: monthRes[0]?.total || 0,
                inProgressCount: inProgressCount || 0,
                completedCount: completedCount || 0
            }
        });
    } catch (err) {
        console.error('❌ Super offer history stats error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch stats' });
    }
});

router.post('/super-offer-history/list', adminAuth, async (req, res) => {
    try {
        const body = req.body || {};
        const { search, status, stepType, startDate, endDate } = body;
        const page = Math.max(1, parseInt(body.page, 10) || 1);
        const limit = Math.max(1, Math.min(100, parseInt(body.limit, 10) || 20));
        const zone = 'Asia/Kolkata';

        const conditions = [];

        // Status Filter
        if (status) {
            if (status === 'completed') {
                conditions.push({ status: { $in: ['completed', 'approved'] } });
            } else if (status === 'in_progress') {
                conditions.push({ status: { $in: ['in_progress', 'pending', 'pending_proof', 'pending_upload'] } });
            } else {
                conditions.push({ status: status });
            }
        }

        // Step Type Filter
        if (stepType) {
            if (stepType === 'usage') {
                conditions.push({ stepType: { $in: ['usage', 'daily_usage'] } });
            } else {
                conditions.push({ stepType: stepType });
            }
        }

        // Date range filter
        const dateCond = {};
        if (startDate) {
            const parsed = DateTime.fromISO(startDate, { zone });
            if (parsed.isValid) {
                dateCond.$gte = parsed.startOf('day').toJSDate();
            }
        }
        if (endDate) {
            const parsed = DateTime.fromISO(endDate, { zone });
            if (parsed.isValid) {
                dateCond.$lte = parsed.endOf('day').toJSDate();
            }
        }
        if (Object.keys(dateCond).length > 0) {
            conditions.push({
                $or: [
                    { completedAt: dateCond },
                    { installedAt: dateCond },
                    { createdAt: dateCond }
                ]
            });
        }

        // Search query
        if (search) {
            const sRegex = new RegExp(search.replace(/[^a-zA-Z0-9_@.-]/g, ''), 'i');
            conditions.push({
                $or: [
                    { userId: sRegex },
                    { userEmail: sRegex },
                    { packageName: new RegExp(search, 'i') },
                    { appName: new RegExp(search, 'i') },
                    { stepName: new RegExp(search, 'i') }
                ]
            });
        }

        const query = conditions.length > 1 ? { $and: conditions } : (conditions[0] || {});

        await connectMongo();

        const total = await SuperOfferHistory.countDocuments(query);
        const offset = (page - 1) * limit;
        const records = await SuperOfferHistory.find(query)
            .sort({ createdAt: -1, _id: -1 })
            .skip(offset)
            .limit(limit)
            .lean();

        const totalPages = Math.ceil(total / limit) || 1;

        return res.json({
            success: true,
            records,
            total,
            page,
            totalPages
        });
    } catch (err) {
        console.error('❌ Super offer history list error:', err);
        return res.status(500).json({ success: false, message: 'Failed to fetch super offer list' });
    }
});

router.post('/super-offer-history/update', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { id, appName, packageName, stepNumber, stepName, coins, usageMinutes, status, rejectionReason } = req.body || {};

        if (!id) {
            return res.status(400).json({ success: false, message: 'Record ID is required' });
        }

        await connectMongo();
        const record = await SuperOfferHistory.findById(id);
        if (!record) {
            return res.status(404).json({ success: false, message: 'Super Offer record not found' });
        }

        if (appName !== undefined) record.appName = appName;
        if (packageName !== undefined) record.packageName = packageName;
        if (stepNumber !== undefined) record.stepNumber = Number(stepNumber) || record.stepNumber;
        if (stepName !== undefined) record.stepName = stepName;
        if (coins !== undefined) record.coins = Number(coins) || 0;
        if (usageMinutes !== undefined) record.usageMinutes = Number(usageMinutes) || 0;
        if (status !== undefined) {
            record.status = status;
            if (status === 'completed' || status === 'approved') {
                if (!record.completedAt) record.completedAt = new Date();
            }
        }
        if (rejectionReason !== undefined) record.rejectionReason = rejectionReason;
        record.updatedAt = new Date();

        await record.save();

        return res.json({
            success: true,
            message: 'Super Offer record updated successfully',
            record
        });
    } catch (err) {
        console.error('❌ Super offer history update error:', err);
        return res.status(500).json({ success: false, message: 'Failed to update record: ' + err.message });
    }
});

router.post('/super-offer-history/delete', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const { ids } = req.body || {};
        if (!Array.isArray(ids) || ids.length === 0) {
            return res.status(400).json({ success: false, message: 'IDs array is required' });
        }

        await connectMongo();
        const result = await SuperOfferHistory.deleteMany({ _id: { $in: ids } });

        return res.json({
            success: true,
            message: `Successfully deleted ${result.deletedCount} Super Offer records`,
        });
    } catch (err) {
        console.error('❌ Super offer history delete error:', err);
        return res.status(500).json({ success: false, message: 'Failed to delete records' });
    }
});

// ====================== UNUSUAL ACTIVITY API ROUTES ======================

// Helper functions for unusual activity
function getTodayStartIST() {
    const now = new Date();
    const istDateStr = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
    return new Date(`${istDateStr}T00:00:00+05:30`);
}

function getWeekStartIST() {
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istTime = new Date(now.getTime() + (now.getTimezoneOffset() * 60000) + istOffset);
    istTime.setDate(istTime.getDate() - 7);
    istTime.setHours(0, 0, 0, 0);
    return istTime;
}

// GET unusual activity users list
router.get('/api/unusual-activity-users', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const { app, page = 1, limit = 20, type, dateRange = 'all' } = req.query;
        const skip = (parseInt(page) - 1) * parseInt(limit);

        const query = { appName: app };
        const weekStart = getWeekStartIST();
        const todayStart = getTodayStartIST();

        if (dateRange === 'today') {
            query.lastUpdated = { $gte: todayStart };
        } else if (dateRange === 'week') {
            query.lastUpdated = { $gte: weekStart };
        } else if (dateRange === 'blocked') {
            query.isBlocked = true;
        }

        if (type) {
            query['activities.type'] = type;
        }

        const [users, total, blockedCount, activeCount] = await Promise.all([
            SuspiciousActivity.find(query)
                .sort({ lastUpdated: -1 })
                .skip(skip)
                .limit(parseInt(limit))
                .lean(),
            SuspiciousActivity.countDocuments(query),
            SuspiciousActivity.countDocuments({ ...query, isBlocked: true }),
            SuspiciousActivity.countDocuments({ ...query, isBlocked: false }),
        ]);

        return res.json({
            success: true,
            users,
            total,
            stats: { total, blocked: blockedCount, active: activeCount },
        });
    } catch (err) {
        console.error('Error fetching unusual activity users:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// GET unusual activity details
router.get('/api/unusual-activity-details', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const { app, userId } = req.query;

        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'app and userId required' });
        }

        const suspiciousData = await SuspiciousActivity.findOne({ appName: app, userId }).lean();
        const blockHistory = await BlockedHistory.find({ appName: app, userId })
            .sort({ blockedAt: -1 })
            .lean();

        let isBlocked = false;
        let payoutBlocked = false;
        let payoutBlockReason = '';
        let userEmail = '';

        try {
            const userDoc = await User.findOne({ userId });
            if (userDoc) {
                isBlocked = userDoc.isBlocked || false;
                payoutBlocked = userDoc.payoutBlocked || false;
                payoutBlockReason = userDoc.payoutBlockReason || '';
                userEmail = userDoc.email || '';
            }
        } catch (err) {
            console.warn('Error fetching user status:', err.message);
        }

        return res.json({
            success: true,
            suspiciousData: suspiciousData || { activities: [] },
            blockHistory,
            isBlocked,
            payoutBlocked,
            payoutBlockReason,
            email: userEmail,
        });
    } catch (err) {
        console.error('Error fetching unusual activity details:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// POST block user from unusual activity
router.post('/api/block-user', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const { app, userId, reason, activities } = req.body;
        const adminEmail = req.admin?.email || 'admin';

        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'app and userId required' });
        }

        await User.updateOne({ userId }, {
            $set: {
                isBlocked: true,
                blockReason: reason || 'Unusual activity detected',
                blockUpdatedAt: new Date(),
            }
        });

        await BlockedHistory.create({
            appName: app,
            userId,
            blockedBy: adminEmail,
            reason: reason || 'Unusual activity detected',
            type: 'unusual_activity',
            activities: activities || [],
        });

        await SuspiciousActivity.findOneAndUpdate(
            { appName: app, userId },
            { isBlocked: true }
        );

        return res.json({ success: true, message: 'User blocked successfully' });
    } catch (err) {
        console.error('Error blocking user:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// POST unblock user
router.post('/api/unblock-user', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const { app, userId } = req.body;

        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'app and userId required' });
        }

        await User.updateOne({ userId }, {
            $set: {
                isBlocked: false,
                blockReason: '',
                blockUpdatedAt: new Date(),
            }
        });

        await BlockedHistory.create({
            appName: app,
            userId,
            blockedBy: 'system',
            reason: 'User unblocked',
            type: 'manual',
            isActive: false,
        });

        await SuspiciousActivity.findOneAndUpdate(
            { appName: app, userId },
            { isBlocked: false }
        );

        return res.json({ success: true, message: 'User unblocked successfully' });
    } catch (err) {
        console.error('Error unblocking user:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// DELETE remove user from unusual activity list
router.post('/api/delete-unusual-activity', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const { app, userId } = req.body;

        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'app and userId required' });
        }

        const deleted = await SuspiciousActivity.findOneAndDelete({ appName: app, userId });

        if (!deleted) {
            return res.status(404).json({ success: false, message: 'User not found in unusual activity list' });
        }

        return res.json({ success: true, message: 'User removed from unusual activity list' });
    } catch (err) {
        console.error('Error deleting unusual activity:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// GET blocked history
router.get('/api/blocked-history', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const { app, userId } = req.query;

        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'app and userId required' });
        }

        const history = await BlockedHistory.find({ appName: app, userId })
            .sort({ blockedAt: -1 })
            .lean();

        return res.json({ success: true, history });
    } catch (err) {
        console.error('Error fetching blocked history:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// POST block user payout from unusual activity
router.post('/api/unusual-activity/block-payout', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const { app, userId, block, reason } = req.body;
        const adminEmail = req.admin?.email || 'admin';

        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'app and userId required' });
        }

        await User.findOneAndUpdate(
            { userId },
            {
                $set: {
                    payoutBlocked: !!block,
                    payoutBlockReason: block ? (reason || 'Payout blocked by admin from unusual activity') : '',
                    payoutBlockUpdatedAt: new Date(),
                }
            }
        );

        // Log to BlockedHistory
        await BlockedHistory.create({
            appName: app,
            userId,
            blockedBy: adminEmail,
            reason: block ? (reason || 'Payout blocked from unusual activity') : 'Payout unblocked',
            type: 'manual',
            isActive: !!block,
        });

        return res.json({ success: true, message: `Payout ${block ? 'blocked' : 'unblocked'} successfully` });
    } catch (err) {
        console.error('Error updating payout block status:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// GET raw logs for a specific activity type
router.get('/api/unusual-activity-logs', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const { app, userId, type } = req.query;
        if (!app || !userId || !type) {
            return res.status(400).json({ success: false, message: 'app, userId and type required' });
        }

        let logs = [];
        const todayStart = getTodayStartIST();
        const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

        if (type === 'read_earn') {
            const rawLogs = await ReadEarnLogs.find({
                appName: app,
                userId,
                createdAt: { $gte: twentyFourHoursAgo }
            }).sort({ createdAt: -1 }).lean();

            logs = rawLogs.map(l => ({
                title: l.url || 'Read & Earn Offer',
                payout: l.payout || 0,
                coins: Math.round((l.payout || 0) * 100),
                timestamp: l.createdAt,
            }));
        } else if (type === 'watch_earn') {
            const rawLogs = await PostbackLogs.find({
                appName: app,
                userId,
                offerType: 'WatchEarn',
                completedAt: { $gte: todayStart }
            }).sort({ completedAt: -1 }).lean();

            logs = rawLogs.map(l => ({
                title: l.payload?.offerName || l.offerId || 'Watch & Earn Video',
                payout: l.payout || 0,
                coins: Math.round((l.payout || 0) * 100),
                timestamp: l.completedAt,
            }));
        } else if (type === 'daily_task') {
            const rawLogs = await PostbackLogs.find({
                appName: app,
                userId,
                offerType: 'DailyTask',
                completedAt: { $gte: todayStart }
            }).sort({ completedAt: -1 }).lean();

            const DailyTask = require('../admin/models/dailyTask');
            const tasks = await DailyTask.find({ offerType: 'DailyTask' }).select('offerId offerName').lean();
            const taskMap = {};
            for (const t of tasks) {
                taskMap[t.offerId] = t;
            }

            logs = rawLogs.map(l => ({
                title: taskMap[l.offerId]?.offerName || l.payload?.offerName || l.offerId || 'Daily Task',
                payout: l.payout || 0,
                coins: Math.round((l.payout || 0) * 100),
                timestamp: l.completedAt,
            }));
        } else if (type === 'play_games') {
            const rawLogs = await GamePlayLogs.find({
                userId
            }).sort({ playedAt: -1 }).lean();

            const PlayGames = require('../admin/models/playGames');
            const games = await PlayGames.find({}).lean();
            const gameMap = {};
            for (const g of games) {
                gameMap[String(g._id)] = g;
            }

            logs = rawLogs.map(l => {
                const gameObj = gameMap[String(l.offerId)];
                const payout = gameObj ? (gameObj.payout || 0) : 0;
                return {
                    title: gameObj ? gameObj.offerName : 'Game Play',
                    payout: payout,
                    coins: Math.round(payout * 100),
                    timestamp: l.playedAt || l.createdAt,
                };
            });
        } else if (type === 'withdrawal') {
            await connectMongo();
            const records = await PayoutRecord.find({
                appName: app,
                userId,
                status: 'success',
                createdAt: { $gte: todayStart }
            }).lean();

            records.forEach(data => {
                logs.push({
                    title: `Withdrawal (${data.methodName || 'N/A'})`,
                    payout: data.amount || 0,
                    coins: data.coins || 0,
                    timestamp: data.createdAt || data.timestamp || new Date(),
                });
            });

            logs.sort((a, b) => b.timestamp - a.timestamp);
        }

        return res.json({
            success: true,
            logs
        });
    } catch (err) {
        console.error('Error fetching unusual activity logs:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.post('/api/trigger-scan', adminAuth, checkPermission('unusualActivity'), async (req, res) => {
    try {
        await connectMongo();

        const firebaseServices = await FirebaseService.find(
            {},
            { _id: 0, appName: 1, serviceAccount: 1 }
        );

        const todayStart = getTodayStartIST();
        const todayKey = DateTime.now().setZone('Asia/Kolkata').toFormat('yyyy-MM-dd');
        let totalScanned = 0;

        for (const service of firebaseServices) {
            const { appName, serviceAccount } = service;
            if (!appName || !serviceAccount) continue;

            try {
                await connectMongo();
                const appDataDoc = await AppData.findOne({ appName }).lean();
                const appData = appDataDoc || {};

                // a) Read & Earn logs (last 24h)
                const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
                const readEarnUsers = await ReadEarnLogs.distinct('userId', {
                    appName,
                    createdAt: { $gte: twentyFourHoursAgo }
                });
                readEarnUsers.forEach(id => activeUserIds.add(id));

                // b) Watch & Earn / Daily Task completions (today)
                const postbackUsers = await PostbackLogs.distinct('userId', {
                    appName,
                    completedAt: { $gte: todayStart }
                });
                postbackUsers.forEach(id => activeUserIds.add(id));

                // c) Game Play logs (today)
                let gamePlayUsers = [];
                try {
                    gamePlayUsers = await GamePlayLogs.distinct('userId', {
                        dayKey: todayKey
                    });
                } catch (e) { }
                gamePlayUsers.forEach(id => activeUserIds.add(id));



                // e) Users with withdrawals today
                try {
                    const withdrawalsMongo = await PayoutRecord.find({
                        appName,
                        status: 'success',
                        createdAt: { $gte: todayStart }
                    }).lean();
                    withdrawalsMongo.forEach(doc => {
                        if (doc.userId) activeUserIds.add(doc.userId);
                    });
                } catch (wErr) { }

                const candidateIds = Array.from(activeUserIds).filter(Boolean);
                console.log(`Scanning ${candidateIds.length} active/potential abusers for app: ${appName}`);
                totalScanned += candidateIds.length;

                // Load static configurations once outside the user loop
                const games = await PlayGames.find({ enabled: true }).lean();
                const tasks = await DailyTask.find({ offerType: 'DailyTask' }).select('offerId offerName dailyReset').lean();
                const taskMap = {};
                for (const task of tasks) {
                    taskMap[task.offerId] = task;
                }
                const readEarnConfig = await ReadEarn.findOne({}).sort({ updatedAt: -1 }).lean();
                const readEarnLimit = readEarnConfig ? (readEarnConfig.limits || 5) : 5;

                // Get currently flagged suspicious userIds to avoid redundant findOneAndDelete operations
                const existingSuspicious = await SuspiciousActivity.distinct('userId', { appName });
                const existingSuspiciousSet = new Set(existingSuspicious);

                let userDocsMap = {};
                if (candidateIds.length > 0) {
                    try {
                        const usersList = await User.find({ userId: { $in: candidateIds } }).lean();
                        usersList.forEach(u => {
                            userDocsMap[u.userId] = u;
                        });
                    } catch (fsErr) {
                        console.error("Error fetching user documents in bulk:", fsErr);
                    }
                }

                // Bulk query and count successful payouts for today in MongoDB
                const payoutCounts = {};
                if (candidateIds.length > 0) {
                    try {
                        const agg = await PayoutRecord.aggregate([
                            {
                                $match: {
                                    appName,
                                    userId: { $in: candidateIds },
                                    status: 'success',
                                    createdAt: { $gte: todayStart }
                                }
                            },
                            {
                                $group: {
                                    _id: '$userId',
                                    count: { $sum: 1 }
                                }
                            }
                        ]);
                        for (const item of agg) {
                            payoutCounts[item._id] = item.count;
                        }
                    } catch (mErr) {
                        console.error('🔥 Failed to aggregate PayoutRecord counts in MongoDB:', mErr);
                    }
                }

                // Cache game play logs, read logs and postback logs for candidates in bulk to reduce DB queries!
                const bulkWatchEarnLogs = await PostbackLogs.find({
                    appName,
                    userId: { $in: candidateIds },
                    offerType: 'WatchEarn',
                    completedAt: { $gte: todayStart }
                }).lean();

                const bulkDailyTaskLogs = await PostbackLogs.find({
                    appName,
                    userId: { $in: candidateIds },
                    offerType: 'DailyTask'
                }).sort({ completedAt: -1 }).lean();

                const bulkReadEarnLogs = await ReadEarnLogs.find({
                    appName,
                    userId: { $in: candidateIds },
                    createdAt: { $gte: twentyFourHoursAgo }
                }).lean();

                let bulkGamePlayLogs = [];
                try {
                    bulkGamePlayLogs = await GamePlayLogs.find({
                        userId: { $in: candidateIds }
                    }).lean();
                } catch (err) { }

                for (const userId of candidateIds) {
                    const userData = userDocsMap[userId];
                    if (!userData) continue;

                    const email = userData.email || '';
                    const allActivities = [];



                    // 3. Watch & Earn - Same offer multiple times today
                    const watchEarnLogs = bulkWatchEarnLogs.filter(log => log.userId === userId);
                    const watchEarnCounts = {};
                    for (const log of watchEarnLogs) {
                        if (!watchEarnCounts[log.offerId]) {
                            watchEarnCounts[log.offerId] = {
                                count: 0,
                                offerName: log.payload?.offerName || log.offerId,
                                payoutSum: 0
                            };
                        }
                        watchEarnCounts[log.offerId].count++;
                        watchEarnCounts[log.offerId].payoutSum += (Number(log.payout) || 1);
                    }
                    for (const [offerId, data] of Object.entries(watchEarnCounts)) {
                        if (data.count > 1) {
                            allActivities.push({
                                type: 'watch_earn',
                                details: `Watch & Earn offer '${data.offerName}' completed ${data.count} times today`,
                                coinValue: Math.round(data.payoutSum * 100),
                                detectedAt: new Date(),
                            });
                        }
                    }

                    // 4. Daily Task Exploit
                    const dailyTaskLogs = bulkDailyTaskLogs.filter(log => log.userId === userId);
                    const completionMap = {};
                    for (const log of dailyTaskLogs) {
                        const key = log.eventId ? `${log.offerId}:${log.eventId}` : log.offerId;
                        if (!completionMap[key]) {
                            completionMap[key] = {
                                offerId: log.offerId,
                                offerName: taskMap[log.offerId]?.offerName || log.offerId,
                                dailyReset: taskMap[log.offerId]?.dailyReset || false,
                                count: 0,
                                lastCompletedAt: null,
                                payoutSum: 0
                            };
                        }
                        completionMap[key].count++;
                        completionMap[key].payoutSum += (Number(log.payout) || 1);
                        if (!completionMap[key].lastCompletedAt || log.completedAt > completionMap[key].lastCompletedAt) {
                            completionMap[key].lastCompletedAt = log.completedAt;
                        }
                    }
                    for (const [key, data] of Object.entries(completionMap)) {
                        const isOneTimeTask = data.dailyReset === false;
                        const completedMultipleTimes = data.count > 1;
                        const completedToday = data.lastCompletedAt && data.lastCompletedAt >= todayStart;

                        if (isOneTimeTask && completedMultipleTimes) {
                            allActivities.push({
                                type: 'daily_task',
                                details: `One-time task '${data.offerName}' completed ${data.count} times`,
                                coinValue: Math.round(data.payoutSum * 100),
                                detectedAt: new Date(),
                            });
                        } else if (completedToday && completedMultipleTimes) {
                            allActivities.push({
                                type: 'daily_task',
                                details: `Task '${data.offerName}' completed ${data.count} times today`,
                                coinValue: Math.round(data.payoutSum * 100),
                                detectedAt: new Date(),
                            });
                        }
                    }

                    // 5. Play Games Exploit
                    for (const game of games) {
                        const gameId = String(game._id);
                        const userPlayLogs = bulkGamePlayLogs.filter(log => log.userId === userId && log.offerId === gameId);

                        if (game.maxPlaysPerUser > 0 && userPlayLogs.length > game.maxPlaysPerUser) {
                            allActivities.push({
                                type: 'play_games',
                                details: `Game '${game.offerName}': ${userPlayLogs.length} plays (lifetime limit: ${game.maxPlaysPerUser})`,
                                coinValue: userPlayLogs.length * (game.payout || 0) * 100,
                                detectedAt: new Date(),
                            });
                        }

                        if (game.dailyEnabled && game.maxPlaysPerDay > 0) {
                            const todayLogs = userPlayLogs.filter(log => log.dayKey === todayKey);
                            if (todayLogs.length > game.maxPlaysPerDay) {
                                allActivities.push({
                                    type: 'play_games',
                                    details: `Game '${game.offerName}': ${todayLogs.length} plays today (daily limit: ${game.maxPlaysPerDay})`,
                                    coinValue: todayLogs.length * (game.payout || 0) * 100,
                                    detectedAt: new Date(),
                                });
                            }
                        }
                    }

                    // 6. Read & Earn Exploit
                    const userReadLogs = bulkReadEarnLogs.filter(log => log.userId === userId);
                    const readLogs = userReadLogs.length;
                    if (readLogs > readEarnLimit) {
                        const totalCoins = userReadLogs.reduce((sum, log) => sum + Math.round((Number(log.payout) || 1) * 100), 0);
                        allActivities.push({
                            type: 'read_earn',
                            details: `Completed ${readLogs} Read & Earn offers in 24h (limit: ${readEarnLimit})`,
                            coinValue: totalCoins,
                            detectedAt: new Date(),
                        });
                    }

                    // 7. Withdrawal Exploit
                    const dailyMaxPayout = appData.dailyMaxPayout !== undefined ? appData.dailyMaxPayout : 1;
                    const count = payoutCounts[userId] || 0;
                    if (count > dailyMaxPayout) {
                        allActivities.push({
                            type: 'withdrawal',
                            details: `${count} successful withdrawals today (limit: ${dailyMaxPayout})`,
                            coinValue: 0,
                            detectedAt: new Date(),
                        });
                    }

                    if (allActivities.length > 0) {
                        await SuspiciousActivity.findOneAndUpdate(
                            { appName, userId },
                            {
                                appName,
                                userId,
                                email,
                                activities: allActivities,
                                lastUpdated: new Date(),
                                isBlocked: userData.blocked || false,
                            },
                            { upsert: true, returnDocument: 'after' }
                        );
                    } else if (existingSuspiciousSet.has(userId)) {
                        // If they were previously suspicious and are no longer suspicious (e.g. limit reset), clean them from list
                        await SuspiciousActivity.findOneAndDelete({ appName, userId });
                    }
                }

                console.log(`Scan completed for app: ${appName}`);
            } catch (err) {
                console.error(`Error scanning app ${appName}:`, err);
            }
        }

        console.log(`All scans completed. Total active users scanned: ${totalScanned}`);
        return res.json({ success: true, message: `Scan completed! ${totalScanned} active users scanned.` });
    } catch (err) {
        console.error('Error triggering scan:', err);
        return res.status(500).json({ success: false, message: 'Internal server error: ' + err.message });
    }
});

// ==========================================
// TASK PERFORMANCE DASHBOARD ROUTES
// ==========================================

// 1. RENDER TASK PERFORMANCE SCREEN
router.get('/task-performance', adminAuth, checkPermission('dashboard'), async (req, res) => {
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;

        res.render('task-performance', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            activePage: 'task-performance'
        });
    } catch (err) {
        console.error('🔥 Error rendering task performance view:', err);
        res.status(500).send('Internal Server Error');
    }
});

// In-memory cache for task performance stats (TTL: 30s)
const taskPerfCache = new Map();

// 2. FETCH AGGREGATED TASK PERFORMANCE STATS & GRAPH
router.post('/api/task-performance/stats', adminAuth, checkPermission('dashboard'), async (req, res) => {
    try {
        const app = String(req.body?.app || '').trim();
        const range = String(req.body?.range || 'today').trim();
        const startDate = String(req.body?.startDate || '').trim();
        const endDate = String(req.body?.endDate || '').trim();

        if (!app) {
            return res.status(400).json({ success: false, message: 'app param required' });
        }

        const cacheKey = `${app}_${range}_${startDate}_${endDate}`;
        const cached = taskPerfCache.get(cacheKey);
        if (cached && (Date.now() - cached.timestamp < 30000)) {
            return res.json(cached.data);
        }

        let start = null, end = null;
        if (range !== 'lifetime') {
            const bounds = rangeToDates(range, startDate, endDate);
            start = bounds.start;
            end = bounds.end;
        }

        await connectMongo();

        const mongoQuery = {
            $or: [
                { appName: app },
                { appName: '' },
                { appName: { $exists: false } },
                { appName: null }
            ]
        };
        if (start || end) {
            mongoQuery.timestamp = {};
            if (start) mongoQuery.timestamp.$gte = start;
            if (end) mongoQuery.timestamp.$lte = end;
        }

        const rewardsMongo = await RewardHistory.find(mongoQuery).lean();

        const tasksMap = {};
        let totalCoins = 0;
        let totalCompletions = 0;
        const activeEarners = new Set();

        rewardsMongo.forEach(data => {
            const rawProvider = String(data.provider || data.type || 'Activity').trim();
            const provider = rawProvider || 'Activity';
            const coins = Number(data.coins) || 0;
            const userId = data.userId ? String(data.userId) : null;

            if (!tasksMap[provider]) {
                tasksMap[provider] = {
                    provider,
                    coins: 0,
                    count: 0
                };
            }

            tasksMap[provider].coins += coins;
            tasksMap[provider].count += 1;

            totalCoins += coins;
            totalCompletions += 1;
            if (userId) {
                activeEarners.add(userId);
            }
        });

        const conversionRate = await getAppConversionRate();
        const tasksResult = Object.values(tasksMap).map(task => ({
            provider: task.provider,
            coins: task.coins,
            count: task.count,
            coinsInRs: Number((task.coins / conversionRate).toFixed(2))
        })).sort((a, b) => b.coins - a.coins);

        // Fetch daily buckets for graph data
        let buckets = [];
        if (range === 'lifetime') {
            const graphBucketsStart = new Date();
            graphBucketsStart.setDate(graphBucketsStart.getDate() - 30);
            buckets = buildDailyBuckets(graphBucketsStart, new Date(), 31);
        } else {
            buckets = buildDailyBuckets(start, end, 31);
        }
        const graphData = buckets.map(bucket => ({
            label: bucket.label,
            coins: 0
        }));

        rewardsMongo.forEach(data => {
            const coins = Number(data.coins) || 0;
            const ts = data.timestamp ? new Date(data.timestamp) : null;

            if (ts) {
                const tsTime = ts.getTime();
                for (let i = 0; i < buckets.length; i++) {
                    const bucket = buckets[i];
                    if (tsTime >= bucket.start.getTime() && tsTime <= bucket.end.getTime()) {
                        graphData[i].coins += coins;
                        break;
                    }
                }
            }
        });

        const responsePayload = {
            success: true,
            totalCoins,
            totalCompletions,
            activeEarners: activeEarners.size,
            revenueInRs: Number((totalCoins / conversionRate).toFixed(2)),
            tasks: tasksResult,
            graphData
        };

        taskPerfCache.set(cacheKey, { timestamp: Date.now(), data: responsePayload });
        return res.json(responsePayload);
    } catch (err) {
        console.error('🔥 Error fetching task stats:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 3. FETCH LIVE APP LEADERBOARD
router.get('/api/task-performance/leaderboard', adminAuth, checkPermission('dashboard'), async (req, res) => {
    try {
        const app = String(req.query?.app || '').trim();
        const range = String(req.query?.range || 'today').trim();
        const startDate = String(req.query?.startDate || '').trim();
        const endDate = String(req.query?.endDate || '').trim();

        if (!app) {
            return res.status(400).json({ success: false, message: 'app param required' });
        }

        let coinsToppers = [];
        let referralToppers = [];

        // Parse date filters
        let start = null, end = null;
        if (range !== 'lifetime') {
            const bounds = rangeToDates(range, startDate, endDate);
            start = bounds.start;
            end = bounds.end;
        }

        await connectMongo();

        // 1. DYNAMIC COINS LEADERBOARD
        if (range === 'lifetime') {
            const topUsers = await User.find({
                account_deleted: { $ne: true },
                isBlocked: { $ne: true }
            })
            .sort({ totalCoins: -1, coins: -1 })
            .limit(20)
            .lean();

            coinsToppers = topUsers.map(u => ({
                userId: u.userId,
                name: u.displayName || u.name || 'Unknown User',
                photoUrl: u.photoUrl || '',
                totalCoins: Number(u.totalCoins) || Number(u.coins) || 0
            }));
        } else {
            const mongoQuery = {
                $or: [
                    { appName: app },
                    { appName: '' },
                    { appName: { $exists: false } },
                    { appName: null }
                ]
            };
            if (start || end) {
                mongoQuery.timestamp = {};
                if (start) mongoQuery.timestamp.$gte = start;
                if (end) mongoQuery.timestamp.$lte = end;
            }

            const rewardsMongo = await RewardHistory.find(mongoQuery).select('userId coins').lean();
            const userCoinsMap = {};

            rewardsMongo.forEach(d => {
                const userId = d.userId;
                if (!userId) return;
                const coins = Number(d.coins) || 0;

                if (!userCoinsMap[userId]) {
                    userCoinsMap[userId] = 0;
                }
                userCoinsMap[userId] += coins;
            });

            const sortedCoinUsers = Object.entries(userCoinsMap)
                .sort((a, b) => b[1] - a[1])
                .slice(0, 20);

            if (sortedCoinUsers.length > 0) {
                const userIds = sortedCoinUsers.map(t => t[0]);
                const dbUsers = await User.find({ userId: { $in: userIds } }).lean();
                const usersDataMap = {};
                dbUsers.forEach(uDoc => {
                    usersDataMap[uDoc.userId] = uDoc;
                });

                coinsToppers = sortedCoinUsers.map(([uId, totalCoins]) => {
                    const uData = usersDataMap[uId] || {};
                    return {
                        userId: uId,
                        name: uData.displayName || uData.name || 'Unknown User',
                        photoUrl: uData.photoUrl || '',
                        totalCoins
                    };
                });
            }
        }

        // 2. DYNAMIC REFERRALS LEADERBOARD (Date filtered if range != lifetime)
        if (range === 'lifetime') {
            // Check users with referralCount or group by referredBy
            const topRefUsers = await User.find({
                account_deleted: { $ne: true },
                isBlocked: { $ne: true }
            })
            .sort({ referralCount: -1 })
            .limit(20)
            .lean();

            if (topRefUsers.length > 0 && topRefUsers[0].referralCount > 0) {
                referralToppers = topRefUsers.map(u => ({
                    userId: u.userId,
                    name: u.displayName || u.name || 'Unknown User',
                    photoUrl: u.photoUrl || '',
                    totalReferrals: u.referralCount || 0
                }));
            } else {
                // Aggregate from all referred users
                const refAgg = await User.aggregate([
                    { $match: { referredBy: { $exists: true, $ne: '' } } },
                    { $group: { _id: '$referredBy', count: { $sum: 1 } } },
                    { $sort: { count: -1 } },
                    { $limit: 20 }
                ]);

                if (refAgg.length > 0) {
                    const refCodes = refAgg.map(r => r._id);
                    const dbUsers = await User.find({
                        $or: [{ userId: { $in: refCodes } }, { referralCode: { $in: refCodes } }]
                    }).lean();
                    const uMap = {};
                    dbUsers.forEach(u => {
                        uMap[u.userId] = u;
                        if (u.referralCode) uMap[u.referralCode] = u;
                    });

                    referralToppers = refAgg.map(r => {
                        const u = uMap[r._id] || {};
                        return {
                            userId: u.userId || r._id,
                            name: u.displayName || u.name || 'Unknown User',
                            photoUrl: u.photoUrl || '',
                            totalReferrals: r.count
                        };
                    });
                }
            }
        } else {
            // Aggregate referred users created in the selected date range
            const refDateQuery = {
                referredBy: { $exists: true, $ne: '' }
            };
            if (start || end) {
                refDateQuery.createdAt = {};
                if (start) refDateQuery.createdAt.$gte = start;
                if (end) refDateQuery.createdAt.$lte = end;
            }

            const refAgg = await User.aggregate([
                { $match: refDateQuery },
                { $group: { _id: '$referredBy', count: { $sum: 1 } } },
                { $sort: { count: -1 } },
                { $limit: 20 }
            ]);

            if (refAgg.length > 0) {
                const refCodes = refAgg.map(r => r._id);
                const dbUsers = await User.find({
                    $or: [{ userId: { $in: refCodes } }, { referralCode: { $in: refCodes } }]
                }).lean();
                const uMap = {};
                dbUsers.forEach(u => {
                    uMap[u.userId] = u;
                    if (u.referralCode) uMap[u.referralCode] = u;
                });

                referralToppers = refAgg.map(r => {
                    const u = uMap[r._id] || {};
                    return {
                        userId: u.userId || r._id,
                        name: u.displayName || u.name || 'Unknown User',
                        photoUrl: u.photoUrl || '',
                        totalReferrals: r.count
                    };
                });
            }
        }

        return res.json({
            success: true,
            coinsToppers,
            referralToppers
        });
    } catch (err) {
        console.error('🔥 Leaderboard fetch error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 4. FETCH USER TASK-WISE EARNINGS BREAKDOWN
router.get('/api/task-performance/user-breakdown', adminAuth, checkPermission('dashboard'), async (req, res) => {
    try {
        const app = String(req.query?.app || '').trim();
        const userId = String(req.query?.userId || '').trim();
        const range = String(req.query?.range || 'lifetime').trim();
        const startDate = String(req.query?.startDate || '').trim();
        const endDate = String(req.query?.endDate || '').trim();

        if (!app || !userId) {
            return res.status(400).json({ success: false, message: 'app and userId are required' });
        }

        await connectMongo();
        const userSnap = await User.findOne({ userId }).lean();
        if (!userSnap) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const userData = userSnap || {};

        // Parse date filters based on the selected range
        let start = null, end = null;
        if (range !== 'lifetime') {
            const bounds = rangeToDates(range, startDate, endDate);
            start = bounds.start;
            end = bounds.end;
        }

        const mongoQuery = {
            $or: [
                { appName: app },
                { appName: '' },
                { appName: { $exists: false } },
                { appName: null }
            ],
            userId: String(userId)
        };
        if (start || end) {
            mongoQuery.timestamp = {};
            if (start) mongoQuery.timestamp.$gte = start;
            if (end) mongoQuery.timestamp.$lte = end;
        }

        const rewardsMongo = await RewardHistory.find(mongoQuery).lean();

        const breakdownMap = {};

        rewardsMongo.forEach(data => {
            const coins = Number(data.coins) || 0;
            const provider = String(data.provider || data.type || 'Task Activity').trim();
            const offerId = String(data.offerId || '').trim();

            let label = provider;
            if (provider.toLowerCase() === 'dailytask' || provider.toLowerCase() === 'daily task') {
                label = `Daily Task: ${offerId || 'Daily Task'}`;
            } else if (provider.toLowerCase() === 'playgames' || provider.toLowerCase() === 'game') {
                label = `Game: ${offerId || 'Game'}`;
            } else if (provider.toLowerCase() === 'super offer' || provider.toLowerCase() === 'superoffer') {
                label = `Super Offer: ${offerId || 'Super Offer'}`;
            } else if (offerId) {
                label = `${provider}: ${offerId}`;
            }
            breakdownMap[label] = (breakdownMap[label] || 0) + coins;
        });

        const breakdown = Object.entries(breakdownMap).map(([name, coins]) => ({
            name,
            coins
        })).sort((a, b) => b.coins - a.coins);

        return res.json({
            success: true,
            user: {
                userId,
                name: userData.displayName || userData.name || 'Unknown User',
                email: userData.email || '',
                photoUrl: userData.photoUrl || ''
            },
            breakdown
        });
    } catch (err) {
        console.error('🔥 User breakdown fetch error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// 5. MY EARNING ROUTES
router.get('/my-earning', adminAuth, checkPermission('dashboard'), async (req, res) => {
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;

        res.render('my-earning', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            activePage: 'my-earning'
        });
    } catch (err) {
        console.error('🔥 Error rendering My Earning view:', err);
        return res.status(500).send('Internal server error');
    }
});

// Earnings Caching and Calculation Helpers
const earningSummaryCache = {};

function getEarningMetrics(coins, modeVal, earningConfig = {}) {
    const adEcpm = Number(earningConfig.adEcpm !== undefined ? earningConfig.adEcpm : 1.00);
    const offerwallRate = Number(earningConfig.offerwallRate !== undefined ? earningConfig.offerwallRate : 5100);
    const readEarnRate = Number(earningConfig.readEarnRate !== undefined ? earningConfig.readEarnRate : 1.00);

    if (modeVal === 'ads') {
        return {
            earnings: adEcpm / 1000,
            impressions: 1
        };
    } else if (modeVal === 'offerwall') {
        return {
            earnings: offerwallRate > 0 ? (coins / offerwallRate) : 0,
            impressions: 1
        };
    } else if (modeVal === 'read_earn') {
        return {
            earnings: readEarnRate / 1000,
            impressions: 2
        };
    }
    return { earnings: 0, impressions: 0 };
}

async function getEarningRecords(db, mode, startBound, endBound) {
    await connectMongo();
    const query = {};
    if (startBound || endBound) {
        query.timestamp = {};
        if (startBound) query.timestamp.$gte = startBound;
        if (endBound) query.timestamp.$lte = endBound;
    }

    const records = await RewardHistory.find(query).select('coins timestamp provider type').lean();
    return records.filter(data => {
        const provider = (data.provider || '').toLowerCase().trim();
        const type = (data.type || '').toLowerCase().trim();

        // Exclude Signup bonus, Admin bonus, and Referral bonus/commissions completely
        const excluded = [
            'signup bonus', 'signup', 'sign up', 'admin bonus', 'admin adjustment', 
            'admin added', 'referral bonus', 'referral commission', 'referral', 'referral mission'
        ];
        if (excluded.some(ex => provider.includes(ex) || type.includes(ex))) {
            return false;
        }

        if (mode === 'ads') {
            const adsKeywords = [
                'streak', 'daily check-in', 'check-in', 'super offer', 'game gems', 'app install gems',
                'battle free', 'battle arena', 'watch & earn', 'watch video', 'diamond catch', 'daily challenge', 'daily task'
            ];
            return adsKeywords.some(ak => provider.includes(ak) || type.includes(ak));
        } else if (mode === 'offerwall') {
            if (provider.includes('read & earn') || type.includes('read & earn')) return false;
            if (type === 'offerwall' || type === 'survey') return true;
            const offerwallKeywords = [
                'offerwall', 'survey', 'cpx', 'wannads', 'pubscale', 'timewall', 'bitlabs', 
                'adgate', 'pollfish', 'monlix', 'inbrain', 'tapjoy', 'adjoe', 'torox', 'aye-t', 'revlum', 'offertoro', 'task'
            ];
            return offerwallKeywords.some(ok => provider.includes(ok) || type.includes(ok));
        } else if (mode === 'read_earn') {
            return provider.includes('read & earn') || type.includes('read & earn');
        }
        return false;
    });
}

async function getSummaryEarningForRange(db, app, mode, startBound, endBound, todayStart, todayEnd, todayData = null, earningConfig = {}) {
    const tz = 'Asia/Kolkata';
    const nowIST = DateTime.now().setZone(tz);
    const startDT = DateTime.fromJSDate(startBound).setZone(tz);
    const endDT = DateTime.fromJSDate(endBound).setZone(tz);
    const todayStr = nowIST.toFormat('yyyy-MM-dd');

    let totalEarnings = 0;
    let totalImpressions = 0;

    let current = startDT;
    const dateRequests = [];
    let todayIncluded = false;

    while (current <= endDT) {
        if (current.startOf('day') > nowIST.startOf('day')) {
            current = current.plus({ days: 1 });
            continue;
        }
        const dateStr = current.toFormat('yyyy-MM-dd');

        if (dateStr === todayStr) {
            todayIncluded = true;
        } else {
            dateRequests.push({
                dateStr,
                startBound: current.startOf('day').toJSDate(),
                endBound: current.endOf('day').toJSDate()
            });
        }
        current = current.plus({ days: 1 });
    }

    if (todayIncluded) {
        if (todayData) {
            totalEarnings += todayData.earnings;
            totalImpressions += todayData.impressions;
        } else {
            const records = await getEarningRecords(db, mode, todayStart, todayEnd);
            records.forEach(rec => {
                const { earnings, impressions } = getEarningMetrics(Number(rec.coins) || 0, mode, earningConfig);
                totalEarnings += earnings;
                totalImpressions += impressions;
            });
        }
    }

    if (dateRequests.length > 0) {
        const dateStrings = dateRequests.map(r => r.dateStr);
        // Find existing in MongoDB
        const existing = await DailyEarningSummary.find({
            appName: app,
            mode,
            dateStr: { $in: dateStrings }
        });

        const existingMap = {};
        existing.forEach(e => {
            if (!existingMap[e.dateStr]) {
                existingMap[e.dateStr] = [];
            }
            existingMap[e.dateStr].push(e);
        });

        // Query missing days in parallel to save time
        const missingRequests = dateRequests.filter(req => !existingMap[req.dateStr]);

        if (missingRequests.length > 0) {
            const missingPromises = missingRequests.map(async (req) => {
                const records = await getEarningRecords(db, mode, req.startBound, req.endBound);
                const providerMap = {};

                if (records.length === 0) {
                    const saved = await DailyEarningSummary.findOneAndUpdate(
                        { appName: app, mode, provider: 'None', dateStr: req.dateStr },
                        { earnings: 0, impressions: 0 },
                        { upsert: true, new: true }
                    );
                    return { dateStr: req.dateStr, summaries: [saved] };
                }

                records.forEach(rec => {
                    const provider = String(rec.provider || 'Unknown').trim();
                    const metrics = getEarningMetrics(Number(rec.coins) || 0, mode, earningConfig);
                    if (!providerMap[provider]) {
                        providerMap[provider] = { earnings: 0, impressions: 0 };
                    }
                    providerMap[provider].earnings += metrics.earnings;
                    providerMap[provider].impressions += metrics.impressions;
                });

                const savePromises = Object.entries(providerMap).map(async ([provider, data]) => {
                    return await DailyEarningSummary.findOneAndUpdate(
                        { appName: app, mode, provider, dateStr: req.dateStr },
                        { earnings: data.earnings, impressions: data.impressions },
                        { upsert: true, new: true }
                    );
                });

                const savedSummaries = await Promise.all(savePromises);
                return { dateStr: req.dateStr, summaries: savedSummaries };
            });

            const results = await Promise.all(missingPromises);
            results.forEach(res => {
                existingMap[res.dateStr] = res.summaries;
            });
        }

        // Aggregate all values from existingMap
        dateRequests.forEach(req => {
            const daySummaries = existingMap[req.dateStr] || [];
            daySummaries.forEach(daySummary => {
                totalEarnings += daySummary.earnings;
                totalImpressions += daySummary.impressions;
            });
        });
    }

    return { earnings: totalEarnings, impressions: totalImpressions };
}

router.get('/api/my-earning/stats', adminAuth, checkPermission('dashboard'), async (req, res) => {
    try {
        const app = String(req.query?.app || '').trim();
        const mode = String(req.query?.mode || 'ads').trim();
        const range = String(req.query?.range || 'today').trim();
        const startDate = String(req.query?.startDate || '').trim();
        const endDate = String(req.query?.endDate || '').trim();

        if (!app) {
            return res.status(400).json({ success: false, message: 'app param required' });
        }
        if (!['ads', 'offerwall', 'read_earn'].includes(mode)) {
            return res.status(400).json({ success: false, message: 'invalid mode parameter' });
        }

        await connectMongo();
        const firebaseServices = req.firebaseServices || [];
        const targetService = pickFirebaseService(firebaseServices, app) || firebaseServices[0];
        const db = targetService?.db;
        if (!db) {
            return res.status(400).json({ success: false, message: `Firebase database not initialized for app: ${app}` });
        }

        let earningConfig = { adEcpm: 0.5 };
        try {
            const appDataDoc = await AppData.findOne({ appName: app }).lean();
            if (appDataDoc) {
                earningConfig = appDataDoc.earningConfig || earningConfig;
            }
        } catch (e) {
            // Ignore error
        }

        const tz = 'Asia/Kolkata';
        const nowIST = DateTime.now().setZone(tz);

        // Summary Date Bounds (Today, Yesterday, This Month, Last Month)
        const todayStart = nowIST.startOf('day').toJSDate();
        const todayEnd = nowIST.endOf('day').toJSDate();

        const yesterdayStart = nowIST.minus({ days: 1 }).startOf('day').toJSDate();
        const yesterdayEnd = nowIST.minus({ days: 1 }).endOf('day').toJSDate();

        const thisMonthStart = nowIST.startOf('month').toJSDate();
        const thisMonthEnd = nowIST.endOf('month').toJSDate();

        const lastMonthStart = nowIST.minus({ months: 1 }).startOf('month').toJSDate();
        const lastMonthEnd = nowIST.minus({ months: 1 }).endOf('month').toJSDate();

        // Selected Range Bounds
        let start = null, end = null;
        if (range === 'today') {
            start = todayStart;
            end = todayEnd;
        } else if (range === 'yesterday') {
            start = yesterdayStart;
            end = yesterdayEnd;
        } else if (range === 'last7') {
            start = nowIST.minus({ days: 6 }).startOf('day').toJSDate();
            end = todayEnd;
        } else if (range === 'last30') {
            start = nowIST.minus({ days: 29 }).startOf('day').toJSDate();
            end = todayEnd;
        } else if (range === 'this_month') {
            start = thisMonthStart;
            end = thisMonthEnd;
        } else if (range === 'last_month') {
            start = lastMonthStart;
            end = lastMonthEnd;
        } else if (range === 'custom') {
            if (startDate) {
                start = DateTime.fromISO(startDate, { zone: tz }).startOf('day').toJSDate();
            }
            if (endDate) {
                end = DateTime.fromISO(endDate, { zone: tz }).endOf('day').toJSDate();
            }
        }

        // 1. Fetch Today's Firestore records once to avoid multiple parallel scans
        const todayRecords = await getEarningRecords(db, mode, todayStart, todayEnd);
        let todayValEarnings = 0;
        let todayValImpressions = 0;
        todayRecords.forEach(rec => {
            const { earnings, impressions } = getEarningMetrics(Number(rec.coins) || 0, mode, earningConfig);
            todayValEarnings += earnings;
            todayValImpressions += impressions;
        });

        const todayData = { earnings: todayValEarnings, impressions: todayValImpressions };

        // Calculate Summary Cards concurrently (uses Mongo hybrid aggregation)
        const [
            todaySummary,
            yesterdaySummary,
            thisMonthSummary,
            lastMonthSummary
        ] = await Promise.all([
            getSummaryEarningForRange(db, app, mode, todayStart, todayEnd, todayStart, todayEnd, todayData, earningConfig),
            getSummaryEarningForRange(db, app, mode, yesterdayStart, yesterdayEnd, todayStart, todayEnd, todayData, earningConfig),
            getSummaryEarningForRange(db, app, mode, thisMonthStart, thisMonthEnd, todayStart, todayEnd, todayData, earningConfig),
            getSummaryEarningForRange(db, app, mode, lastMonthStart, lastMonthEnd, todayStart, todayEnd, todayData, earningConfig)
        ]);

        const todayEarnings = todaySummary.earnings;
        const yesterdayEarnings = yesterdaySummary.earnings;
        const thisMonthEarnings = thisMonthSummary.earnings;
        const lastMonthEarnings = lastMonthSummary.earnings;

        // Calculate Selected Range Metrics, breakdown, and graph data dynamically using Mongo daily summaries
        let totalEarnings = 0;
        let totalImpressions = 0;
        const providerMap = {};
        const summaryByDate = {}; // dateStr -> earnings

        // Helper: dynamic graph buckets
        function getGraphBuckets(startBound, endBound) {
            if (!startBound || !endBound) return [];
            const dayMs = 24 * 60 * 60 * 1000;
            const totalDays = Math.floor((endBound.getTime() - startBound.getTime()) / dayMs) + 1;

            if (totalDays > 90) {
                const list = [];
                const startDT = DateTime.fromJSDate(startBound).setZone(tz);
                const endDT = DateTime.fromJSDate(endBound).setZone(tz);
                let current = startDT.startOf('month');
                while (current <= endDT) {
                    list.push({
                        start: current.toJSDate(),
                        end: current.endOf('month').toJSDate(),
                        label: current.toFormat('MMM yyyy'),
                        dateStrings: []
                    });
                    current = current.plus({ months: 1 });
                }
                return list;
            } else {
                const list = [];
                for (let i = 0; i < totalDays; i++) {
                    const dayStart = new Date(startBound.getTime() + (i * dayMs));
                    dayStart.setHours(0, 0, 0, 0);
                    const dayEnd = new Date(dayStart);
                    dayEnd.setHours(23, 59, 59, 999);
                    list.push({
                        start: dayStart,
                        end: dayEnd,
                        label: dayStart.toLocaleDateString('en-IN', { day: '2-digit', month: 'short' }),
                        dateStrings: [DateTime.fromJSDate(dayStart).setZone(tz).toFormat('yyyy-MM-dd')]
                    });
                }
                return list;
            }
        }

        // Build Graph buckets
        let graphBuckets = [];
        if (range === 'lifetime') {
            const graphStart = nowIST.minus({ days: 29 }).startOf('day').toJSDate();
            graphBuckets = getGraphBuckets(graphStart, todayEnd);
        } else if (start && end) {
            graphBuckets = getGraphBuckets(start, end);
        }

        // Gather dates belonging to past range and check if Today is in the selected range
        const pastDateStrings = [];
        const todayStr = nowIST.toFormat('yyyy-MM-dd');
        let todayIncluded = false;

        graphBuckets.forEach(b => {
            if (b.dateStrings.length === 0) {
                let curr = DateTime.fromJSDate(b.start).setZone(tz);
                const endCurr = DateTime.fromJSDate(b.end).setZone(tz);
                while (curr <= endCurr) {
                    b.dateStrings.push(curr.toFormat('yyyy-MM-dd'));
                    curr = curr.plus({ days: 1 });
                }
            }

            b.dateStrings.forEach(dStr => {
                if (dStr === todayStr) {
                    todayIncluded = true;
                } else {
                    pastDateStrings.push(dStr);
                }
            });
        });

        // Ensure any missing days in the selected range are aggregated and saved to MongoDB
        const ensureStart = range === 'lifetime' ? nowIST.minus({ days: 29 }).startOf('day').toJSDate() : start;
        const ensureEnd = range === 'lifetime' ? todayEnd : end;
        if (ensureStart && ensureEnd) {
            await getSummaryEarningForRange(db, app, mode, ensureStart, ensureEnd, todayStart, todayEnd, todayData, earningConfig);
        }

        // 1. Fetch pre-aggregated summaries from MongoDB for past days
        const summaries = pastDateStrings.length > 0 ? await DailyEarningSummary.find({
            appName: app,
            mode,
            dateStr: { $in: pastDateStrings }
        }) : [];

        summaries.forEach(s => {
            if (!summaryByDate[s.dateStr]) {
                summaryByDate[s.dateStr] = 0;
            }
            summaryByDate[s.dateStr] += s.earnings;

            const provider = s.provider;
            if (!providerMap[provider]) {
                providerMap[provider] = { earnings: 0, count: 0 };
            }
            providerMap[provider].earnings += s.earnings;
            providerMap[provider].count += s.impressions;
            totalEarnings += s.earnings;
            totalImpressions += s.impressions;
        });

        // 2. Reuse Today's data from Firestore if included in selected range
        if (todayIncluded) {
            let todaySumEarnings = 0;
            todayRecords.forEach(rec => {
                const { earnings, impressions } = getEarningMetrics(Number(rec.coins) || 0, mode, earningConfig);
                const provider = String(rec.provider || 'Unknown').trim();

                if (!providerMap[provider]) {
                    providerMap[provider] = { earnings: 0, count: 0 };
                }
                providerMap[provider].earnings += earnings;
                providerMap[provider].count += impressions;

                todaySumEarnings += earnings;
                totalEarnings += earnings;
                totalImpressions += impressions;
            });
            summaryByDate[todayStr] = todaySumEarnings;
        }

        // Build Graph Data
        const graphData = graphBuckets.map(b => {
            let bucketEarnings = 0;
            b.dateStrings.forEach(dStr => {
                bucketEarnings += (summaryByDate[dStr] || 0);
            });
            return {
                label: b.label,
                earnings: Number(bucketEarnings.toFixed(4))
            };
        });

        const breakdown = Object.entries(providerMap).map(([name, data]) => ({
            name,
            earnings: Number(data.earnings.toFixed(4)),
            count: data.count
        })).sort((a, b) => b.earnings - a.earnings);

        return res.json({
            success: true,
            summary: {
                today: Number(todayEarnings.toFixed(4)),
                yesterday: Number(yesterdayEarnings.toFixed(4)),
                thisMonth: Number(thisMonthEarnings.toFixed(4)),
                lastMonth: Number(lastMonthEarnings.toFixed(4))
            },
            selected: {
                totalEarnings: Number(totalEarnings.toFixed(4)),
                totalImpressions
            },
            breakdown,
            graphData
        });

    } catch (err) {
        console.error('🔥 My Earning Stats error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.get('/api/my-earning/provider-users', adminAuth, checkPermission('dashboard'), async (req, res) => {
    try {
        const app = String(req.query?.app || '').trim();
        const mode = String(req.query?.mode || 'ads').trim();
        const range = String(req.query?.range || 'today').trim();
        const startDate = String(req.query?.startDate || '').trim();
        const endDate = String(req.query?.endDate || '').trim();
        const providerName = String(req.query?.provider || '').trim();

        if (!app) {
            return res.status(400).json({ success: false, message: 'app param required' });
        }
        if (!providerName) {
            return res.status(400).json({ success: false, message: 'provider param required' });
        }
        if (!['ads', 'offerwall', 'read_earn'].includes(mode)) {
            return res.status(400).json({ success: false, message: 'invalid mode parameter' });
        }

        await connectMongo();
        const appDataDoc = await AppData.findOne({ appName: app }).lean();
        const earningConfig = appDataDoc?.earningConfig || {};

        const tz = 'Asia/Kolkata';
        const nowIST = DateTime.now().setZone(tz);

        // Selected Range Bounds
        let start = null, end = null;
        if (range === 'today') {
            start = nowIST.startOf('day').toJSDate();
            end = nowIST.endOf('day').toJSDate();
        } else if (range === 'yesterday') {
            start = nowIST.minus({ days: 1 }).startOf('day').toJSDate();
            end = nowIST.minus({ days: 1 }).endOf('day').toJSDate();
        } else if (range === 'last7') {
            start = nowIST.minus({ days: 6 }).startOf('day').toJSDate();
            end = nowIST.endOf('day').toJSDate();
        } else if (range === 'last30') {
            start = nowIST.minus({ days: 29 }).startOf('day').toJSDate();
            end = nowIST.endOf('day').toJSDate();
        } else if (range === 'this_month') {
            start = nowIST.startOf('month').toJSDate();
            end = nowIST.endOf('month').toJSDate();
        } else if (range === 'last_month') {
            start = nowIST.minus({ months: 1 }).startOf('month').toJSDate();
            end = nowIST.minus({ months: 1 }).endOf('month').toJSDate();
        } else if (range === 'custom') {
            if (startDate) {
                start = DateTime.fromISO(startDate, { zone: tz }).startOf('day').toJSDate();
            }
            if (endDate) {
                end = DateTime.fromISO(endDate, { zone: tz }).endOf('day').toJSDate();
            }
        }

        // Query MongoDB RewardHistory with appName fallback
        const mongoQuery = {
            $or: [
                { appName: app },
                { appName: '' },
                { appName: { $exists: false } },
                { appName: null }
            ]
        };
        if (start || end) {
            mongoQuery.timestamp = {};
            if (start) mongoQuery.timestamp.$gte = start;
            if (end) mongoQuery.timestamp.$lte = end;
        }

        const rewardsList = await RewardHistory.find(mongoQuery).lean();

        const pClean = providerName.toLowerCase().trim();

        const records = rewardsList.filter(rec => {
            const provider = (rec.provider || '').toLowerCase().trim();
            const type = (rec.type || '').toLowerCase().trim();

            // Exclude bonus coins
            const excluded = [
                'signup bonus', 'signup', 'sign up', 'admin bonus', 'admin adjustment', 
                'admin added', 'referral bonus', 'referral commission', 'referral', 'referral mission'
            ];
            if (excluded.some(ex => provider.includes(ex) || type.includes(ex))) {
                return false;
            }

            if (pClean && provider !== pClean && !provider.includes(pClean) && !pClean.includes(provider)) {
                return false;
            }

            return true;
        });

        // Aggregate by userId
        const userMap = {};
        records.forEach(rec => {
            const userId = rec.userId;
            if (!userId) return;

            const { earnings, impressions } = getEarningMetrics(Number(rec.coins) || 0, mode, earningConfig);
            if (!userMap[userId]) {
                userMap[userId] = {
                    userId,
                    earnings: 0,
                    count: 0,
                    coins: 0
                };
            }
            userMap[userId].earnings += earnings;
            userMap[userId].count += impressions;
            userMap[userId].coins += Number(rec.coins) || 0;
        });

        // Sort and limit
        const sortedUsers = Object.values(userMap)
            .sort((a, b) => b.earnings - a.earnings)
            .slice(0, 150);

        // Fetch User profile details (email, name) from MongoDB
        const userIds = sortedUsers.map(u => u.userId);
        const dbUsers = await User.find({ userId: { $in: userIds } }).lean();

        const userDetailsMap = {};
        dbUsers.forEach(uDoc => {
            userDetailsMap[uDoc.userId] = {
                name: uDoc.displayName || uDoc.name || 'Unknown User',
                email: uDoc.email || 'N/A'
            };
        });

        const result = sortedUsers.map(u => ({
            ...u,
            earnings: Number(u.earnings.toFixed(4)),
            name: userDetailsMap[u.userId]?.name || 'Unknown User',
            email: userDetailsMap[u.userId]?.email || 'N/A'
        }));

        return res.json({
            success: true,
            provider: providerName,
            users: result
        });

    } catch (err) {
        console.error('🔥 Fetch provider users error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// ============================================
// PROMOTION MANAGER
// ============================================
router.get('/manage-promotions', adminAuth, checkPermission('promotions'), async (req, res) => {
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;
        const promotions = await PromotionRequest.find({}).sort({ createdAt: -1 });

        res.render('promotions/manage', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            promotions,
            activePage: 'promotions',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Manage promotions page error:', err);
        res.status(500).send('Error loading promotions');
    }
});

router.post('/update-promotion-status', adminAuth, checkPermission('promotions'), async (req, res) => {
    try {
        const { id, status, adminReply } = req.body;
        if (!id || !status) {
            return res.status(400).json({ success: false, message: 'ID and Status are required' });
        }

        const promo = await PromotionRequest.findById(id);
        if (!promo) {
            return res.status(404).json({ success: false, message: 'Promotion request not found' });
        }

        promo.status = status;
        if (adminReply !== undefined) {
            promo.adminReply = adminReply;
        }

        await promo.save();

        // Send push notification to the user
        try {
            await sendNotificationViaApi({
                title: 'Promotion Request Update',
                body: `Your promotion request status has been updated to "${status.toUpperCase()}".${adminReply ? '\nReply: ' + adminReply : ''}`,
                userId: promo.userId,
                type: 'service',
            });
        } catch (notifErr) {
            console.error('🔥 Failed to send promotion request status update notification:', notifErr.message);
        }

        return res.json({ success: true, message: 'Promotion status updated successfully', data: promo });
    } catch (err) {
        console.error('🔥 Update promotion status error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// ============================================
// SUPPORT MANAGER
// ============================================
router.get('/manage-support', adminAuth, checkPermission('support'), async (req, res) => {
    try {
        await connectMongo();
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;
        const tickets = await SupportRequest.find({}).sort({ createdAt: -1 });

        res.render('support/manage', {
            name,
            email,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            tickets,
            activePage: 'support',
            admin: req.admin
        });
    } catch (err) {
        console.error('❌ Manage support page error:', err);
        res.status(500).send('Error loading support tickets');
    }
});

router.post('/reply-support-ticket', adminAuth, checkPermission('support'), async (req, res) => {
    try {
        await connectMongo();
        const { id, status, adminReply } = req.body;
        if (!id || !status) {
            return res.status(400).json({ success: false, message: 'ID and Status are required' });
        }

        const ticket = await SupportRequest.findById(id);
        if (!ticket) {
            return res.status(404).json({ success: false, message: 'Support ticket not found' });
        }

        ticket.status = status;
        if (adminReply !== undefined) {
            ticket.adminReply = adminReply;
        }

        await ticket.save();

        // Send push notification to the user
        try {
            await sendNotificationViaApi({
                title: 'Support Ticket Update',
                body: `Your support ticket status has been updated to "${status.replace('_', ' ').toUpperCase()}".${adminReply ? '\nReply: ' + adminReply : ''}`,
                userId: ticket.userId,
                type: 'support',
            });
        } catch (notifErr) {
            console.error('🔥 Failed to send support ticket update notification:', notifErr.message);
        }

        return res.json({ success: true, message: 'Support ticket updated successfully', data: ticket });
    } catch (err) {
        console.error('🔥 Reply support ticket error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.post('/delete-support-ticket', adminAuth, checkPermission('support'), async (req, res) => {
    try {
        await connectMongo();
        const { id } = req.body;
        if (!id) {
            return res.status(400).json({ success: false, message: 'ID is required' });
        }

        const ticket = await SupportRequest.findByIdAndDelete(id);
        if (!ticket) {
            return res.status(404).json({ success: false, message: 'Support ticket not found' });
        }

        return res.json({ success: true, message: 'Support ticket deleted successfully' });
    } catch (err) {
        console.error('🔥 Delete support ticket error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

router.post('/delete-promotion-request', adminAuth, checkPermission('promotions'), async (req, res) => {
    try {
        const { id } = req.body;
        if (!id) {
            return res.status(400).json({ success: false, message: 'ID is required' });
        }

        const promo = await PromotionRequest.findByIdAndDelete(id);
        if (!promo) {
            return res.status(404).json({ success: false, message: 'Promotion request not found' });
        }

        return res.json({ success: true, message: 'Promotion request deleted successfully' });
    } catch (err) {
        console.error('🔥 Delete promotion request error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// ==================== ACCOUNT DELETION REQUEST ROUTES ====================

// Page: Manage Account Deletion Requests
router.get('/manage-deletions', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        await connectMongo();

        const firebaseServices = req.firebaseServices || [];
        const admin = req.admin || { role: 'admin', permissions: {} };
        const name = admin.name || 'Admin';
        const photo = name.split(' ').map(part => part[0]).join('').toUpperCase() || 'A';

        res.render('deletions/manage', {
            admin,
            activePage: 'deletions',
            title: 'Account Deletions',
            photo,
            firebaseServices,
        });
    } catch (err) {
        console.error('❌ Manage deletions page error:', err);
        res.status(500).send('Error loading account deletions page');
    }
});

// API: Get List of Deletion Requests
router.get('/api/admin/delete-requests', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        await connectMongo();
        const requests = await User.find({ delete_requested: true })
            .select('userId email displayName photoUrl delete_requested_at coins gems deviceId')
            .sort({ delete_requested_at: -1 })
            .lean();

        return res.json({ success: true, requests });
    } catch (err) {
        console.error('🔥 Fetch delete requests error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// API: Approve Deletion Request
router.post('/api/admin/delete-request/approve', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        await connectMongo();
        const { userId } = req.body;
        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        const user = await User.findOneAndUpdate(
            { userId },
            {
                $set: {
                    account_deleted: true,
                    account_deleted_at: new Date(),
                    isBlocked: false,
                    blocked: false,
                    delete_requested: false,
                    delete_requested_at: null
                }
            },
            { new: true }
        );

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        // Invalidate cache immediately so new state is reflected
        try {
            if (cacheService && cacheService.del) {
                await cacheService.del('user_data_' + userId);
                await cacheService.del('so_user_' + userId);
                if (user.email) {
                    await cacheService.del('user_data_' + user.email);
                    await cacheService.del('so_user_' + user.email);
                }
            }
        } catch (_) {}

        return res.json({ success: true, message: 'Account deletion approved. User marked as deleted (not blocked).' });
    } catch (err) {
        console.error('🔥 Approve delete request error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// API: Reject Deletion Request
router.post('/api/admin/delete-request/reject', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        await connectMongo();
        const { userId } = req.body;
        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        const user = await User.findOneAndUpdate(
            { userId },
            {
                $set: {
                    delete_requested: false,
                    delete_requested_at: null
                }
            },
            { new: true }
        );

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        return res.json({ success: true, message: 'Account deletion request rejected/cancelled successfully' });
    } catch (err) {
        console.error('🔥 Reject delete request error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// API: Full Wipe Deletion Request (A-to-Z Wipe from Database & Firebase)
router.post('/api/admin/delete-request/wipe', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        const body = req.body || {};
        const userId = String(body.userId || '').trim();
        const email = String(body.email || '').trim();
        const selectedApp = String(body.selectedApp || body.appName || '').trim();

        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required for wiping data' });
        }

        const wipeRes = await executeUserFullWipe({ userId, email, selectedApp });

        return res.json({
            success: true,
            message: `User (${userId}) and ALL associated data (A to Z) permanently wiped successfully!${wipeRes.firebaseDeleted ? ' Firebase Auth deleted.' : ''}`
        });
    } catch (err) {
        console.error('🔥 Full wipe delete request error:', err);
        return res.status(500).json({
            success: false,
            message: `Error wiping user data: ${err.message || 'Server error'}`
        });
    }
});

// API: Get List of Deleted Accounts History (account_deleted: true)
router.get('/api/admin/deleted-history', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        await connectMongo();
        const limit = Math.min(parseInt(req.query.limit) || 200, 1000);
        const history = await User.find({ account_deleted: true })
            .select('userId email displayName photoUrl account_deleted_at updatedAt createdAt coins gems deviceId isBlocked')
            .sort({ account_deleted_at: -1, updatedAt: -1 })
            .limit(limit)
            .lean();

        return res.json({ success: true, history });
    } catch (err) {
        console.error('🔥 Fetch deleted history error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// API: Restore Deleted User Account (sets account_deleted: false)
router.post('/api/admin/delete-request/restore', adminAuth, checkPermission('users'), async (req, res) => {
    try {
        await connectMongo();
        const { userId } = req.body;
        if (!userId) {
            return res.status(400).json({ success: false, message: 'userId is required' });
        }

        const user = await User.findOneAndUpdate(
            { userId },
            {
                $set: {
                    account_deleted: false,
                    account_deleted_at: null,
                    delete_requested: false,
                    delete_requested_at: null,
                    isBlocked: false,
                    blocked: false
                }
            },
            { new: true }
        );

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        // Invalidate cache immediately so user can login normally
        try {
            if (cacheService && cacheService.del) {
                await cacheService.del('user_data_' + userId);
                await cacheService.del('so_user_' + userId);
                if (user.email) {
                    await cacheService.del('user_data_' + user.email);
                    await cacheService.del('so_user_' + user.email);
                }
            }
        } catch (_) {}

        return res.json({ success: true, message: 'User account restored successfully! User can now sign in normally.' });
    } catch (err) {
        console.error('🔥 Restore user error:', err);
        return res.status(500).json({ success: false, message: 'Internal server error' });
    }
});

// ==================== BATTLE ARENA SUB-SIDEBAR ADMIN ROUTES ====================
const battleAdminRoutes = require('../battle-arena/routes/battleAdminRoutes');
router.use('/admin/battle-arena', adminAuth, checkPermission('battleArena'), battleAdminRoutes);

// ==================== DAILY CHALLENGE ADMIN ROUTES ====================
const dailyChallengeAdminRoutes = require('./modules/dailyChallengeAdminRoutes');
router.use(dailyChallengeAdminRoutes);

// ==================== APP TRACKING & GA4 ANALYTICS ADMIN ROUTES ====================
const appTrackingRoutes = require('./modules/appTrackingRoutes');
router.use(appTrackingRoutes);

module.exports = router;
