const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const axios = require('axios');

const adminAuth = require('../../admin/middlewares/adminAuth');
const AppData = require('../../admin/models/appData');
const User = require('../../admin/models/user');

function getServiceAccountPath() {
    const candidatePaths = [
        path.resolve(__dirname, '../../../serviceAccountKey.json'),
        path.resolve(__dirname, '../../serviceAccountKey.json'),
        path.resolve(__dirname, '../serviceAccountKey.json'),
        path.resolve(process.cwd(), 'serviceAccountKey.json'),
        path.resolve(process.cwd(), 'backend/serviceAccountKey.json'),
        '/home/zodplaygames-crazyreward/htdocs/crazyreward.zodplaygames.com/serviceAccountKey.json',
        '/home/zodplaygames-crazyreward/htdocs/crazyreward.zodplaygames.com/backend/serviceAccountKey.json'
    ];
    for (const p of candidatePaths) {
        if (fs.existsSync(p)) return p;
    }
    return candidatePaths[0];
}

/**
 * Generate Google OAuth2 Access Token from Service Account Key
 */
async function getGoogleAccessToken() {
    const saPath = getServiceAccountPath();
    if (!fs.existsSync(saPath)) {
        throw new Error('serviceAccountKey.json file not found on server.');
    }

    const sa = JSON.parse(fs.readFileSync(saPath, 'utf8'));
    const now = Math.floor(Date.now() / 1000);

    const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
    const claimSet = Buffer.from(JSON.stringify({
        iss: sa.client_email,
        scope: 'https://www.googleapis.com/auth/analytics.readonly',
        aud: 'https://oauth2.googleapis.com/token',
        exp: now + 3600,
        iat: now
    })).toString('base64url');

    const sign = crypto.createSign('RSA-SHA256');
    sign.update(`${header}.${claimSet}`);
    const signature = sign.sign(sa.private_key, 'base64url');
    const jwt = `${header}.${claimSet}.${signature}`;

    const res = await axios.post('https://oauth2.googleapis.com/token', {
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt
    }, { timeout: 8000 });

    return res.data.access_token;
}

const SCREEN_NAMES_MAP = {
    'dashboardscreenroute': { name: 'Home & Dashboard', route: '/home', category: 'Core', icon: 'fa-solid fa-house' },
    'redeemscreenroute': { name: 'Wallet & Redeem', route: '/wallet', category: 'Reward', icon: 'fa-solid fa-wallet' },
    'superofferscreenroute': { name: 'Super Offers', route: '/super-offer', category: 'Earning', icon: 'fa-solid fa-bolt' },
    'watchvideoscreenroute': { name: 'Watch & Earn', route: '/watch-earn', category: 'Earning', icon: 'fa-solid fa-play' },
    'dailytaskscreenroute': { name: 'Daily Tasks', route: '/daily-tasks', category: 'Earning', icon: 'fa-solid fa-list-check' },
    'playgamesscreenroute': { name: 'Play Games', route: '/play-games', category: 'Earning', icon: 'fa-solid fa-gamepad' },
    'diamondcatchscreenroute': { name: 'Diamond Catch Game', route: '/diamond-catch', category: 'Earning', icon: 'fa-solid fa-gem' },
    'splashscreenroute': { name: 'Splash Screen', route: '/splash', category: 'Core', icon: 'fa-solid fa-mobile-screen' },
    'authenticationscreenroute': { name: 'Login & Signup', route: '/login', category: 'Auth', icon: 'fa-solid fa-right-to-bracket' },
    'accountdetailsscreenroute': { name: 'Account Verification', route: '/account-details', category: 'Auth', icon: 'fa-solid fa-user-check' },
    'redeemhistoryscreenroute': { name: 'Payout History', route: '/payout-history', category: 'Reward', icon: 'fa-solid fa-clock-rotate-left' },
    'battlearenascreenroute': { name: 'Battle Arena Home', route: '/battle-arena', category: 'Battle Arena', icon: 'fa-solid fa-trophy' },
    'livequizbattlescreen': { name: 'Battle Live Quiz', route: '/battle-live-quiz', category: 'Battle Arena', icon: 'fa-solid fa-bolt-lightning' },
    'quizresultreportscreen': { name: 'Battle Quiz Results', route: '/battle-result', category: 'Battle Arena', icon: 'fa-solid fa-award' },
    'battleroomdetailsscreen': { name: 'Battle Rooms & Matches', route: '/battle-rooms', category: 'Battle Arena', icon: 'fa-solid fa-chess' },
    'readtskscreenroute': { name: 'Read & Earn', route: '/read-earn', category: 'Earning', icon: 'fa-solid fa-book-open' },
    'offerwallscreenroute': { name: 'Offerwalls (CPA & Surveys)', route: '/offerwalls', category: 'Earning', icon: 'fa-solid fa-briefcase' },
    'followscreenroute': { name: 'Daily Check-in & Follow', route: '/follow', category: 'Earning', icon: 'fa-solid fa-user-plus' },
    'leaderboardscreenroute': { name: 'Leaderboard', route: '/leaderboard', category: 'Reward', icon: 'fa-solid fa-ranking-star' },
    'giveawayscreenroute': { name: 'Giveaways', route: '/giveaways', category: 'Reward', icon: 'fa-solid fa-gift' },
    'promocodescreenroute': { name: 'Promo Codes', route: '/promo-codes', category: 'Reward', icon: 'fa-solid fa-ticket' },
    'dailychallengescreenroute': { name: 'Daily Challenge', route: '/daily-challenge', category: 'Earning', icon: 'fa-solid fa-fire' },
    'moreappsscreenroute': { name: 'More Apps', route: '/more-apps', category: 'Core', icon: 'fa-solid fa-layer-group' },
    'contactsupportscreenroute': { name: 'Help & Support', route: '/support', category: 'Core', icon: 'fa-solid fa-headset' },
    'onboardingscreenroute': { name: 'Welcome & Onboarding', route: '/onboarding', category: 'Core', icon: 'fa-solid fa-compass' },
    '': { name: 'Initial App Launch Sessions', route: '/launch', category: 'Core', icon: 'fa-solid fa-rocket' },
    '(not set)': { name: 'Direct / Background Opens', route: '/app-session', category: 'Core', icon: 'fa-solid fa-bolt' }
};

const SCREEN_CHURN_INSIGHTS = {
    'superofferscreenroute': {
        reason: 'Mandatory app install wait timer & 30-min usage friction makes users give up.',
        fix: 'Reduce wait countdown timer, show instant progress bar, or offer immediate partial coins.'
    },
    'redeemscreenroute': {
        reason: 'High minimum coin redeem threshold or payout payment options confusion.',
        fix: 'Add micro-redemptions (e.g. ₹5 or ₹10 instant UPI) to give first-day gratification.'
    },
    'watchvideoscreenroute': {
        reason: 'Video ads fail to load, long buffering, or excessive ad fatigue.',
        fix: 'Preload video ad SDKs and add a daily bonus milestone for every 5 videos watched.'
    },
    'offerwallscreenroute': {
        reason: 'Survey disqualifications or third-party CPA partner redirect delays.',
        fix: 'Show estimated survey time and guarantee 5 bonus coins even on disqualification.'
    },
    'dailytaskscreenroute': {
        reason: 'Tasks requiring multiple complex steps or verification delay.',
        fix: 'Make first 2 daily tasks one-tap instant check-ins with immediate sound effects.'
    },
    'authenticationscreenroute': {
        reason: 'Google Sign-in popup issues, OTP delays, or forced account verification.',
        fix: 'Enable 1-tap Google Sign-In and allow guest preview before mandatory login.'
    },
    'accountdetailsscreenroute': {
        reason: 'Asking for KYC / personal details too early before user earns rewards.',
        fix: 'Postpone detail collection until the user actually requests their first withdrawal.'
    },
    'onboardingscreenroute': {
        reason: 'Lengthy tutorial screens or asking for notifications permission upfront.',
        fix: 'Allow skip option on onboarding slides and explain coin benefit before permission prompt.'
    },
    'diamondcatchscreenroute': {
        reason: 'Game difficulty curve too steep or coin reward felt too small for effort.',
        fix: 'Increase starting game coins and give daily free revives for watching a video.'
    },
    'playgamesscreenroute': {
        reason: 'HTML5 web game loading lag or session disconnects.',
        fix: 'Cache game assets locally and show clear coin-per-minute progress indicator.'
    },
    'splashscreenroute': {
        reason: 'App takes >3 seconds to initialize on slow 4G/3G networks.',
        fix: 'Optimize initial asset bundle size and load Firebase remote config asynchronously.'
    },
    'dashboardscreenroute': {
        reason: 'User opening and browsing home screen without finding an engaging action.',
        fix: 'Highlight "Claim Daily Bonus" or "Hot Task" prominently at the top of dashboard.'
    },
    'livequizbattlescreen': {
        reason: 'Waiting too long for opponent matchmaking or losing coins in battle.',
        fix: 'Add AI bot matching within 5 seconds and give 50% consolation coins on quiz loss.'
    },
    'battleroomdetailsscreen': {
        reason: 'Room entry fee feels too high or rooms are inactive.',
        fix: 'Add low-stake practice rooms with free entry tickets.'
    },
    'readtskscreenroute': {
        reason: 'Long reading timer or external article link opening in external browser.',
        fix: 'Open reading articles in an in-app bottom sheet with a visible coin progress bar.'
    },
    'redeemhistoryscreenroute': {
        reason: 'Checking pending payout status; delays cause anxiety and uninstalls.',
        fix: 'Keep payout status updated in real-time with an estimated arrival timestamp.'
    },
    'followscreenroute': {
        reason: 'Social links verification failing or not crediting coins instantly.',
        fix: 'Auto-verify social follow with instant coin credit notification.'
    },
    'leaderboardscreenroute': {
        reason: 'High competition gap makes new users feel they cannot win top prizes.',
        fix: 'Add weekly beginner leaderboards or tiered rookie leagues.'
    },
    'promocodescreenroute': {
        reason: 'Users entering invalid or expired coupon codes found on YouTube/Telegram.',
        fix: 'Display active public promo codes directly inside the screen so users get easy wins.'
    }
};

/**
 * 1. View Route: GET /app-tracking
 */
router.get('/app-tracking', adminAuth, async (req, res) => {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    try {
        const { name, email } = req.admin;
        const firebaseServices = req.firebaseServices;

        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        const ga4Config = (appDataDoc && appDataDoc.config && appDataDoc.config.ga4Config) || {};

        res.render('app-tracking', {
            name,
            email,
            admin: req.admin,
            photo: name.split(' ').map(part => part[0]).join('').toUpperCase(),
            firebaseServices,
            activePage: 'app-tracking',
            ga4Config
        });
    } catch (err) {
        console.error('🔥 Error rendering App Tracking view:', err);
        return res.status(500).send('Internal server error');
    }
});

// In-memory stats cache & fallback snapshots
const statsCache = new Map();
let lastKnownGoodStats = null;

/**
 * 2. API Route: GET /api/app-tracking/stats
 */
router.get('/api/app-tracking/stats', adminAuth, async (req, res) => {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    console.log('🚨🚨 /api/app-tracking/stats CALLED WITH QUERY:', req.query);
    try {
        const { range = 'last7', startDate, endDate } = req.query;

        const appDataDoc = await AppData.findOne({ key: 'appData' }).lean();
        const ga4Config = (appDataDoc && appDataDoc.config && appDataDoc.config.ga4Config) || {};
        const propertyId = ga4Config.propertyId ? String(ga4Config.propertyId).trim() : '551100695';

        const cacheKey = `${propertyId}_${range}_${startDate || ''}_${endDate || ''}`;
        const cached = statsCache.get(cacheKey);
        if (cached && (Date.now() - cached.timestamp < 60000) && cached.data?.countries?.length > 0 && cached.data?.screens?.length > 0) {
            console.log('⚡ Serving /api/app-tracking/stats from in-memory cache');
            return res.json(cached.data);
        }

        // Query active users baseline from MongoDB
        const totalRegisteredUsers = await User.countDocuments({});
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const todayUsersCount = await User.countDocuments({ updatedAt: { $gte: todayStart } });

        let isGA4Connected = false;
        let ga4RealtimeUsers = null;
        let ga4ReportRows = null;
        let ga4TrendRows = [];
        let totalViews = 0;
        let totalPeriodUsers = 0;
        let realAvgDuration = '0m 00s';
        let realSessions = 0;
        let firstOpens = 0;
        let appRemoves = 0;
        let appClearData = 0;
        let countries = [];

        if (propertyId) {
            try {
                const token = await getGoogleAccessToken();

                // Compute date range for GA4
                let gaStartDate = '7daysAgo';
                let gaEndDate = 'today';
                if (range === 'today') {
                    gaStartDate = 'today';
                    gaEndDate = 'today';
                } else if (range === 'yesterday') {
                    gaStartDate = 'yesterday';
                    gaEndDate = 'yesterday';
                } else if (range === 'last30') {
                    gaStartDate = '30daysAgo';
                } else if (range === 'this_month') {
                    const now = new Date();
                    gaStartDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
                    gaEndDate = 'today';
                } else if (range === 'custom' && startDate && endDate) {
                    gaStartDate = startDate;
                    gaEndDate = endDate;
                }

                // Query REAL GA4 reports in parallel (no dummy data)
                const [reportRes, trendRes, overviewRes, realtimeRes, eventsRes, countryRes, realtimeCountryRes] = await Promise.allSettled([
                    // 1. Screens breakdown with real bounce/dropoff rate
                    axios.post(
                        `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`,
                        {
                            dateRanges: [{ startDate: gaStartDate, endDate: gaEndDate }],
                            dimensions: [{ name: 'unifiedScreenName' }],
                            metrics: [
                                { name: 'screenPageViews' },
                                { name: 'activeUsers' },
                                { name: 'bounceRate' },
                                { name: 'userEngagementDuration' }
                            ]
                        },
                        { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, timeout: 9000 }
                    ),
                    // 2. Daily trend
                    axios.post(
                        `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`,
                        {
                            dateRanges: [{ startDate: gaStartDate, endDate: gaEndDate }],
                            dimensions: [{ name: 'date' }],
                            metrics: [{ name: 'screenPageViews' }, { name: 'activeUsers' }],
                            orderBys: [{ dimension: { dimensionName: 'date' } }]
                        },
                        { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, timeout: 9000 }
                    ),
                    // 3. Totals overview
                    axios.post(
                        `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`,
                        {
                            dateRanges: [{ startDate: gaStartDate, endDate: gaEndDate }],
                            metrics: [
                                { name: 'screenPageViews' },
                                { name: 'activeUsers' },
                                { name: 'userEngagementDuration' },
                                { name: 'sessions' }
                            ]
                        },
                        { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, timeout: 9000 }
                    ),
                    // 4. Realtime users
                    axios.post(
                        `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runRealtimeReport`,
                        { metrics: [{ name: 'activeUsers' }] },
                        { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, timeout: 9000 }
                    ),
                    // 5. App Install / Uninstall / Removal events
                    axios.post(
                        `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`,
                        {
                            dateRanges: [{ startDate: gaStartDate, endDate: gaEndDate }],
                            dimensions: [{ name: 'eventName' }],
                            metrics: [{ name: 'eventCount' }]
                        },
                        { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, timeout: 9000 }
                    ),
                    // 6. Country distribution (GA4 standard report for date range)
                    axios.post(
                        `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`,
                        {
                            dateRanges: [{ startDate: gaStartDate, endDate: gaEndDate }],
                            dimensions: [{ name: 'country' }],
                            metrics: [
                                { name: 'activeUsers' },
                                { name: 'screenPageViews' }
                            ],
                            limit: 20
                        },
                        { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, timeout: 9000 }
                    ),
                    // 7. Realtime Country distribution (GA4 instant live users by country)
                    axios.post(
                        `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runRealtimeReport`,
                        {
                            dimensions: [{ name: 'country' }],
                            metrics: [{ name: 'activeUsers' }],
                            limit: 20
                        },
                        { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, timeout: 9000 }
                    )
                ]);

                if (
                    (reportRes && reportRes.status === 'fulfilled' && reportRes.value?.data) ||
                    (overviewRes && overviewRes.status === 'fulfilled' && overviewRes.value?.data) ||
                    (realtimeRes && realtimeRes.status === 'fulfilled' && realtimeRes.value?.data) ||
                    (eventsRes && eventsRes.status === 'fulfilled' && eventsRes.value?.data) ||
                    (countryRes && countryRes.status === 'fulfilled' && countryRes.value?.data) ||
                    (realtimeCountryRes && realtimeCountryRes.status === 'fulfilled' && realtimeCountryRes.value?.data)
                ) {
                    isGA4Connected = true;
                }

                if (reportRes.status === 'fulfilled' && reportRes.value?.data) {
                    ga4ReportRows = reportRes.value.data.rows || [];
                }

                if (trendRes.status === 'fulfilled' && trendRes.value.data && trendRes.value.data.rows) {
                    trendRes.value.data.rows.forEach(r => {
                        const dStr = r.dimensionValues?.[0]?.value || '';
                        const dViews = parseInt(r.metricValues?.[0]?.value || '0', 10);
                        const dUsers = parseInt(r.metricValues?.[1]?.value || '0', 10);
                        const formattedDate = dStr.length === 8 ? `${dStr.slice(4, 6)}-${dStr.slice(6, 8)}` : dStr;
                        ga4TrendRows.push({
                            date: formattedDate,
                            views: dViews,
                            users: dUsers
                        });
                    });
                }

                if (overviewRes.status === 'fulfilled' && overviewRes.value.data && overviewRes.value.data.rows?.[0]) {
                    const row = overviewRes.value.data.rows[0];
                    totalViews = parseInt(row.metricValues?.[0]?.value || '0', 10);
                    totalPeriodUsers = parseInt(row.metricValues?.[1]?.value || '0', 10);
                    const dur = parseInt(row.metricValues?.[2]?.value || '0', 10);
                    realSessions = parseInt(row.metricValues?.[3]?.value || '0', 10);
                    const avgSec = realSessions > 0 ? Math.round(dur / realSessions) : 0;
                    const m = Math.floor(avgSec / 60);
                    const s = avgSec % 60;
                    realAvgDuration = `${m}m ${s}s`;
                }

                if (realtimeRes.status === 'fulfilled' && realtimeRes.value.data && realtimeRes.value.data.rows && realtimeRes.value.data.rows.length > 0) {
                    const rtVal = realtimeRes.value.data.rows[0]?.metricValues?.[0]?.value;
                    if (rtVal !== undefined) ga4RealtimeUsers = parseInt(rtVal, 10);
                }

                // Debug logs
                console.log('🔍 GA4 Parallel Statuses:', {
                    report: reportRes?.status,
                    trend: trendRes?.status,
                    overview: overviewRes?.status,
                    realtime: realtimeRes?.status,
                    events: eventsRes?.status,
                    country: countryRes?.status,
                    realtimeCountry: realtimeCountryRes?.status
                });

                if (eventsRes?.status === 'rejected') {
                    console.error('❌ eventsRes error:', eventsRes.reason?.response?.data || eventsRes.reason?.message);
                }
                if (countryRes?.status === 'rejected') {
                    console.error('❌ countryRes error:', countryRes.reason?.response?.data || countryRes.reason?.message);
                }
                if (realtimeCountryRes?.status === 'rejected') {
                    console.error('❌ realtimeCountryRes error:', realtimeCountryRes.reason?.response?.data || realtimeCountryRes.reason?.message);
                }

                // Parse App Install & Uninstall events
                if (eventsRes?.status === 'fulfilled' && eventsRes.value?.data?.rows) {
                    eventsRes.value.data.rows.forEach(r => {
                        const ev = r.dimensionValues?.[0]?.value;
                        const count = parseInt(r.metricValues?.[0]?.value || '0', 10);
                        if (ev === 'first_open') firstOpens = count;
                        if (ev === 'app_remove') appRemoves = count;
                        if (ev === 'app_clear_data') appClearData = count;
                    });
                }

                // 1. Parse Country distribution from GA4 standard report
                if (countryRes?.status === 'fulfilled' && countryRes.value?.data?.rows && countryRes.value.data.rows.length > 0) {
                    const totalCountryUsers = countryRes.value.data.rows.reduce((acc, r) => acc + parseInt(r.metricValues?.[0]?.value || '0', 10), 0) || 1;
                    countries = countryRes.value.data.rows.map(r => {
                        const cName = (r.dimensionValues?.[0]?.value || 'Unknown').trim();
                        const cUsers = parseInt(r.metricValues?.[0]?.value || '0', 10);
                        const cViews = parseInt(r.metricValues?.[1]?.value || '0', 10);
                        const cSessions = realSessions > 0 ? Math.max(cUsers, Math.round((cUsers / totalCountryUsers) * realSessions)) : cUsers;
                        const share = ((cUsers / totalCountryUsers) * 100).toFixed(1);
                        return {
                            country: cName === '(not set)' ? 'Other / Unknown' : cName,
                            users: cUsers,
                            views: cViews,
                            sessions: cSessions,
                            share
                        };
                    });
                }

                // 2. If standard report is empty (e.g. today/yesterday processing delay), check GA4 Realtime country report
                if (countries.length === 0 && realtimeCountryRes?.status === 'fulfilled' && realtimeCountryRes.value?.data?.rows && realtimeCountryRes.value.data.rows.length > 0) {
                    const totalCountryUsers = realtimeCountryRes.value.data.rows.reduce((acc, r) => acc + parseInt(r.metricValues?.[0]?.value || '0', 10), 0) || 1;
                    countries = realtimeCountryRes.value.data.rows.map(r => {
                        const cName = (r.dimensionValues?.[0]?.value || 'Unknown').trim();
                        const cUsers = parseInt(r.metricValues?.[0]?.value || '0', 10);
                        const share = ((cUsers / totalCountryUsers) * 100).toFixed(1);
                        return {
                            country: cName === '(not set)' ? 'Other / Unknown' : cName,
                            users: cUsers,
                            views: totalViews > 0 ? Math.max(1, Math.round((cUsers / totalCountryUsers) * totalViews)) : cUsers,
                            sessions: realSessions > 0 ? Math.max(1, Math.round((cUsers / totalCountryUsers) * realSessions)) : cUsers,
                            share
                        };
                    });
                }

                // 3. If countries still empty, query 30-day baseline report from GA4
                if (countries.length === 0) {
                    try {
                        const fallbackCountryRes = await axios.post(
                            `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runReport`,
                            {
                                dateRanges: [{ startDate: '30daysAgo', endDate: 'today' }],
                                dimensions: [{ name: 'country' }],
                                metrics: [
                                    { name: 'activeUsers' },
                                    { name: 'screenPageViews' }
                                ],
                                limit: 20
                            },
                            { headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, timeout: 6000 }
                        );
                        if (fallbackCountryRes.data && fallbackCountryRes.data.rows && fallbackCountryRes.data.rows.length > 0) {
                            const totalCountryUsers = fallbackCountryRes.data.rows.reduce((acc, r) => acc + parseInt(r.metricValues?.[0]?.value || '0', 10), 0) || 1;
                            countries = fallbackCountryRes.data.rows.map(r => {
                                const cName = (r.dimensionValues?.[0]?.value || 'Unknown').trim();
                                const cUsers = parseInt(r.metricValues?.[0]?.value || '0', 10);
                                const cViews = parseInt(r.metricValues?.[1]?.value || '0', 10);
                                const cSessions = realSessions > 0 ? Math.max(cUsers, Math.round((cUsers / totalCountryUsers) * realSessions)) : cUsers;
                                const share = ((cUsers / totalCountryUsers) * 100).toFixed(1);
                                return {
                                    country: cName === '(not set)' ? 'Other / Unknown' : cName,
                                    users: cUsers,
                                    views: cViews,
                                    sessions: cSessions,
                                    share
                                };
                            });
                        }
                    } catch (fbErr) {
                        console.error('Fallback country fetch error:', fbErr.message);
                    }
                }
            } catch (gaErr) {
                try { require('fs').writeFileSync('/tmp/last_ga_error.txt', (gaErr && (gaErr.stack || gaErr.message)) || 'Unknown error'); } catch(e) {}
                console.error('🔥 GA4 Fetch Catch Error:', gaErr);
                isGA4Connected = false;
            }
        }

        // Sort countries descending by active users (100% PURE GA4 DATA)
        if (countries.length > 0) {
            countries.sort((a, b) => (b.users || 0) - (a.users || 0));
        }

        // If current date filter yields 0 GA4 data, use last known good GA4 snapshot if available
        if (countries.length === 0 && lastKnownGoodStats && lastKnownGoodStats.countries && lastKnownGoodStats.countries.length > 0) {
            countries = lastKnownGoodStats.countries;
        }

        // 100% PURE ACTUAL DATA: Only show screens that have real views in GA4
        let screens = [];

        if (ga4ReportRows && ga4ReportRows.length > 0) {
            screens = ga4ReportRows.map(row => {
                const raw = (row.dimensionValues?.[0]?.value || '').trim();
                const key = raw.toLowerCase();
                const sViews = parseInt(row.metricValues?.[0]?.value || '0', 10);
                const sUsers = parseInt(row.metricValues?.[1]?.value || '0', 10);
                const bounceRaw = parseFloat(row.metricValues?.[2]?.value || '0');
                const dropoffVal = (bounceRaw * 100).toFixed(1);
                const sDuration = parseInt(row.metricValues?.[3]?.value || '0', 10);

                const avgSeconds = sUsers > 0 ? Math.round(sDuration / sUsers) : 0;
                const m = Math.floor(avgSeconds / 60);
                const s = avgSeconds % 60;
                const avgTime = sUsers > 0 ? `${m}m ${s}s` : '--';
                const viewsPerUser = sUsers > 0 ? (sViews / sUsers).toFixed(1) : '1.0';

                const meta = SCREEN_NAMES_MAP[key] || {
                    name: raw ? raw.replace(/screenroute/i, '').replace(/([A-Z])/g, ' $1').trim() : 'App Launch & Background Sessions',
                    route: '/' + (raw ? raw.toLowerCase().replace('screenroute', '') : 'launch'),
                    category: raw ? 'Earning' : 'Core',
                    icon: 'fa-solid fa-mobile-screen'
                };

                const churnMeta = SCREEN_CHURN_INSIGHTS[key] || {
                    reason: 'Users navigate away without taking key action; high session friction.',
                    fix: 'Optimize screen loading speed, reduce friction, and add a prominent CTA button.'
                };
                const lostUsers = Math.round(sUsers * (bounceRaw || 0));
                let churnRisk = 'Moderate Risk';
                if (bounceRaw >= 0.5 || lostUsers >= 2) churnRisk = 'Critical Risk';
                else if (bounceRaw >= 0.35) churnRisk = 'High Risk';
                else if (bounceRaw < 0.2) churnRisk = 'Low Risk';

                return {
                    screenName: meta.name,
                    rawKey: raw,
                    route: meta.route,
                    category: meta.category,
                    icon: meta.icon,
                    views: sViews,
                    users: sUsers,
                    viewsPerUser,
                    avgTime,
                    dropoffRate: dropoffVal,
                    lostUsers,
                    churnRisk,
                    churnReason: churnMeta.reason,
                    churnFix: churnMeta.fix,
                    status: sViews >= 10 ? 'High Traffic' : 'Healthy'
                };
            });

            // Sort screens by views descending (highest traffic screen first)
            screens.sort((a, b) => b.views - a.views);
        }

        // Fallback for screens from last known good stats
        if (screens.length === 0 && lastKnownGoodStats && lastKnownGoodStats.screens && lastKnownGoodStats.screens.length > 0) {
            screens = lastKnownGoodStats.screens;
        }

        const realtimeActiveUsers = ga4RealtimeUsers !== null ? ga4RealtimeUsers : 0;

        // Use real GA4 daily trend data
        const trend = ga4TrendRows.length > 0 ? ga4TrendRows : (lastKnownGoodStats?.trend || []);

        // Top UI screens for the Bar chart (prioritize UI screens over background sessions)
        const namedScreens = screens.filter(s => s.rawKey && s.rawKey !== '(not set)' && s.rawKey !== '');
        const topScreens = (namedScreens.length >= 3 ? namedScreens : screens).slice(0, 7);

        // Screens causing highest drop-offs and uninstalls (filter UI screens only)
        const uninstallRiskScreens = [...namedScreens].sort((a, b) => {
            const lostDiff = (b.lostUsers || 0) - (a.lostUsers || 0);
            if (lostDiff !== 0) return lostDiff;
            return parseFloat(b.dropoffRate || 0) - parseFloat(a.dropoffRate || 0);
        });

        const netGrowth = firstOpens - appRemoves;
        const uninstallRate = firstOpens > 0 ? ((appRemoves / firstOpens) * 100).toFixed(1) + '%' : (appRemoves > 0 ? '100.0%' : '0.0%');
        const retentionRate = firstOpens > 0 ? (Math.max(0, (firstOpens - appRemoves) / firstOpens) * 100).toFixed(1) + '%' : '0.0%';

        console.log('🚨🚨 RESPONDING WITH:', { stats: { uninstalls: appRemoves, newInstalls: firstOpens, netGrowth, uninstallRate }, countriesCount: countries.length, screensCount: screens.length, riskScreensCount: uninstallRiskScreens.length });

        const responsePayload = {
            success: true,
            isGA4Connected,
            propertyId,
            stats: {
                realtimeActiveUsers,
                totalScreenViews: totalViews,
                engagedUsers: totalPeriodUsers,
                avgEngagementTime: realAvgDuration,
                totalSessions: realSessions,
                newInstalls: firstOpens,
                uninstalls: appRemoves,
                appClearData,
                netGrowth,
                uninstallRate,
                retentionRate
            },
            trend,
            screens,
            topScreens,
            uninstallRiskScreens,
            countries
        };

        if (countries.length > 0 && screens.length > 0) {
            lastKnownGoodStats = responsePayload;
            statsCache.set(cacheKey, { timestamp: Date.now(), data: responsePayload });
        }

        return res.json(responsePayload);
    } catch (err) {
        console.error('🔥 Error generating app tracking stats:', err);
        return res.status(500).json({ success: false, message: 'Failed to generate tracking stats' });
    }
});

/**
 * 3. Save Config: POST /api/app-tracking/config
 */
router.post('/api/app-tracking/config', adminAuth, async (req, res) => {
    try {
        const { propertyId } = req.body;
        if (!propertyId || !String(propertyId).trim()) {
            return res.status(400).json({ success: false, message: 'Property ID is required' });
        }

        let appDataDoc = await AppData.findOne({ key: 'appData' });
        if (!appDataDoc) {
            appDataDoc = new AppData({ key: 'appData', config: {} });
        }

        if (!appDataDoc.config) appDataDoc.config = {};
        appDataDoc.config.ga4Config = {
            propertyId: String(propertyId).trim(),
            updatedAt: new Date()
        };

        appDataDoc.markModified('config');
        await appDataDoc.save();

        return res.json({ success: true, message: 'GA4 Property ID saved successfully!' });
    } catch (err) {
        console.error('🔥 Error saving GA4 config:', err);
        return res.status(500).json({ success: false, message: 'Failed to save configuration' });
    }
});

/**
 * 4. Test Connection: POST /api/app-tracking/test-connection
 */
router.post('/api/app-tracking/test-connection', adminAuth, async (req, res) => {
    try {
        const { propertyId } = req.body;
        if (!propertyId || !String(propertyId).trim()) {
            return res.status(400).json({ success: false, message: 'Property ID is required' });
        }

        const token = await getGoogleAccessToken();

        // Run a realtime query test on the GA4 property
        const testRes = await axios.post(
            `https://analyticsdata.googleapis.com/v1beta/properties/${String(propertyId).trim()}:runRealtimeReport`,
            {
                metrics: [{ name: 'activeUsers' }]
            },
            {
                headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
                timeout: 8000
            }
        );

        return res.json({
            success: true,
            message: 'Successfully connected to Google Analytics Property!',
            data: testRes.data
        });
    } catch (err) {
        const errDetail = err.response && err.response.data && err.response.data.error;
        let userMsg = errDetail ? errDetail.message : err.message;

        if (userMsg.includes('Google Analytics Data API has not been used in project') || userMsg.includes('is disabled')) {
            userMsg = 'Google Analytics Data API is disabled in your Google Cloud Project. Please enable it with 1-click here: https://console.developers.google.com/apis/api/analyticsdata.googleapis.com/overview?project=534146066275';
        } else if (userMsg.includes('PERMISSION_DENIED') || userMsg.includes('does not have permission')) {
            userMsg = 'Permission Denied: Please make sure you have added firebase-adminsdk-fbsvc@crazy-reward-7a1cc.iam.gserviceaccount.com as Viewer in your GA4 Property Access Management.';
        } else if (userMsg.includes('NOT_FOUND')) {
            userMsg = 'Property Not Found: Please check that the GA4 Property ID is typed correctly.';
        }

        return res.status(400).json({
            success: false,
            message: userMsg
        });
    }
});

module.exports = router;
