const express = require('express');
const router = express.Router();

const adminRoutes = require('./adminRoutes');
const appRoutes = require('./appRoutes');

router.use((req, res, next) => {
    const host = req.headers['x-forwarded-host'] || req.headers.host || '';
    const reqPath = req.path || '';

    const isAdminPath = reqPath.startsWith('/manage-') ||
        reqPath.startsWith('/add-') ||
        reqPath.startsWith('/giveaway') ||
        reqPath.startsWith('/dashboard') ||
        reqPath.startsWith('/login') ||
        reqPath.startsWith('/logout') ||
        reqPath.startsWith('/app-data') ||
        reqPath.startsWith('/payment') ||
        reqPath.startsWith('/user-') ||
        reqPath.startsWith('/redis-') ||
        reqPath.startsWith('/cpa-') ||
        reqPath.startsWith('/s2s-') ||
        reqPath.startsWith('/api/admin') ||
        reqPath.startsWith('/api/app-tracking') ||
        reqPath.startsWith('/app-tracking') ||
        reqPath.startsWith('/admin') ||
        reqPath.startsWith('/send-notification') ||
        reqPath.startsWith('/wallet-catalog') ||
        reqPath.startsWith('/toggle-account-deleted') ||
        reqPath.startsWith('/wipe-user-data') ||
        reqPath.startsWith('/delete-user-account') ||
        reqPath.startsWith('/update-user-data') ||
        reqPath.startsWith('/bulk-delete-users') ||
        reqPath.startsWith('/update-daily-task-title') ||
        Boolean(req.cookies && (req.cookies.adminToken || req.cookies.admin_token || req.cookies.token || req.cookies.admin)) ||
        Boolean(req.headers['x-admin-key']);

    if (host.startsWith('admin') || isAdminPath) {
        return adminRoutes.handle(req, res, next);
    }

    if (host.startsWith('app') || host.includes('crazyreward')) {
        return appRoutes.handle(req, res, next);
    }

    return appRoutes.handle(req, res, next);
});

// MAIN WEBSITE
router.get('/', (_, res) => {
    res.send('🌍 Main Website Working');
});

module.exports = router;