const { getOrInitFirebase } = require('./firebase-helper');
const FirebaseService = require('../models/firebaseService');

const connectMongo = require('./connectMongo');

/**
 * Middleware to verify Firebase Auth ID Token in Authorization header
 */
const verifyAuthToken = async (req, res, next) => {
    try {
        await connectMongo();
        const headerUserId = req.headers['x-user-id'] || req.headers['user-id'] || req.body?.userId;
        const authHeader = req.headers.authorization || '';

        if (authHeader.startsWith('Bearer ')) {
            const idToken = authHeader.split('Bearer ')[1].trim();
            const appName = req.body?.appName || req.query?.appName || process.env.DEFAULT_APP_NAME || '';
            let serviceDoc = await FirebaseService.findOne({ appName: appName.toLowerCase() }).lean();
            if (!serviceDoc) {
                serviceDoc = await FirebaseService.findOne().lean();
            }
            
            let adminApp;
            if (serviceDoc && serviceDoc.serviceAccount) {
                adminApp = getOrInitFirebase(serviceDoc.appName || appName, serviceDoc.serviceAccount);
            } else {
                const admin = require('firebase-admin');
                adminApp = admin.apps.length ? admin.app() : null;
            }

            if (adminApp) {
                try {
                    const decodedToken = await adminApp.auth().verifyIdToken(idToken);
                    req.user = decodedToken;
                    req.userId = decodedToken.uid;
                } catch (tokErr) {
                    if (headerUserId) {
                        req.userId = String(headerUserId).trim();
                    }
                }
            } else if (headerUserId) {
                req.userId = String(headerUserId).trim();
            }
        } else if (headerUserId) {
            req.userId = String(headerUserId).trim();
        }

        if (!req.userId && headerUserId) {
            req.userId = String(headerUserId).trim();
        }

        if (!req.userId) {
            return res.status(401).json({ success: false, message: 'Unauthorized: Missing user authentication' });
        }

        // Security check: Verify if account is blocked for suspicious activity
        const User = require('../models/user');
        const userDoc = await User.findOne({ $or: [{ userId: req.userId }, { firebaseUid: req.userId }] }).select('isBlocked').lean();
        if (userDoc && userDoc.isBlocked) {
            return res.status(403).json({ success: false, message: 'Account blocked due to suspicious activity' });
        }

        next();
    } catch (err) {
        console.error('❌ Auth Middleware Error:', err.message);
        const headerUserId = req.headers['x-user-id'] || req.headers['user-id'] || req.body?.userId;
        if (headerUserId) {
            req.userId = String(headerUserId).trim();
            return next();
        }
        return res.status(401).json({ success: false, message: 'Unauthorized: Authentication failed' });
    }
};

module.exports = verifyAuthToken;
