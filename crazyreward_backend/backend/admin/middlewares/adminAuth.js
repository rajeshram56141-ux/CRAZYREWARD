const jwt = require('jsonwebtoken');
const connectMongo = require('./connectMongo');
const Admin = require('../models/admin');
const FirebaseService = require('../models/firebaseService');
const { DateTime } = require('luxon');

module.exports = async function (req, res, next) {
    try {
        await connectMongo();

        const token = req.cookies?.adminToken || req.cookies?.admin_token || req.cookies?.token || req.cookies?.adminSession || req.headers['x-admin-token'] || (req.headers.authorization && req.headers.authorization.startsWith('Bearer ') ? req.headers.authorization.slice(7) : null);
        const isJson = req.xhr || req.headers['content-type'] === 'application/json' || (req.headers.accept && req.headers.accept.includes('application/json')) || req.originalUrl?.includes('/api/');

        if (!token) {
            if (isJson) return res.status(401).json({ success: false, message: 'Admin session expired. Please log in again.' });
            return res.redirect('/login');
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const admin = await Admin.findById(decoded.id);
        if (!admin) {
            if (isJson) return res.status(401).json({ success: false, message: 'Admin not found. Please log in again.' });
            return res.redirect('/login');
        }

        admin.lastLogin = DateTime.now();
        await admin.save();

        const firebaseServices = await FirebaseService.find({}, { _id: 0 });

        req.admin = admin;
        req.firebaseServices = firebaseServices;
        res.locals.admin = admin;

        next();
    } catch (err) {
        const isJson = req.xhr || req.headers['content-type'] === 'application/json' || (req.headers.accept && req.headers.accept.includes('application/json'));
        if (isJson) return res.status(401).json({ success: false, message: 'Session error: ' + (err.message || err) });
        return res.redirect('/login');
    }
};
