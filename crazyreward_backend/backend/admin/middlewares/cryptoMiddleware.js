const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

// Load Server Private Key once at startup
const serverPrivateKeyPath = path.join(__dirname, '../../keys/server_private.pem');
let serverPrivateKey = null;
if (fs.existsSync(serverPrivateKeyPath)) {
    try {
        serverPrivateKey = fs.readFileSync(serverPrivateKeyPath, 'utf8');
    } catch (e) { }
}

/**
 * ChCrypto — AES-256-CBC Cipher Utility
 * Key: 32-byte key derived from secret
 * IV: First 16 bytes of Key
 */
class ChCrypto {
    static _buildKeyIv(secretKey) {
        const keyBuf = Buffer.alloc(32, 0);
        Buffer.from(secretKey || '', 'utf8').copy(keyBuf, 0, 0, 32);
        const ivBuf = keyBuf.slice(0, 16);
        return { key: keyBuf, iv: ivBuf };
    }

    static encrypt(value, secretKey) {
        if (!value) return '';
        try {
            const { key, iv } = this._buildKeyIv(secretKey);
            const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
            let encrypted = cipher.update(typeof value === 'string' ? value : JSON.stringify(value), 'utf8', 'base64');
            encrypted += cipher.final('base64');
            return encrypted;
        } catch (error) {
            console.error('🔥 AES Encryption Error:', error);
            return null;
        }
    }

    static encryptWithKey(value, keyBuf) {
        if (!value) return '';
        try {
            const ivBuf = keyBuf.slice(0, 16);
            const cipher = crypto.createCipheriv('aes-256-cbc', keyBuf, ivBuf);
            let encrypted = cipher.update(typeof value === 'string' ? value : JSON.stringify(value), 'utf8', 'base64');
            encrypted += cipher.final('base64');
            return encrypted;
        } catch (error) {
            console.error('🔥 AES Encryption with Raw Key Error:', error);
            return null;
        }
    }

    static decrypt(encryptedValue, secretKey) {
        if (!encryptedValue) return '';
        try {
            const { key, iv } = this._buildKeyIv(secretKey);
            const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
            let decrypted = decipher.update(encryptedValue, 'base64', 'utf8');
            decrypted += decipher.final('utf8');
            return decrypted;
        } catch (error) {
            console.error('🔥 AES Decryption Error:', error);
            return null;
        }
    }

    static decryptWithKey(encryptedValue, keyBuf) {
        if (!encryptedValue) return '';
        try {
            const ivBuf = keyBuf.slice(0, 16);
            const decipher = crypto.createDecipheriv('aes-256-cbc', keyBuf, ivBuf);
            let decrypted = decipher.update(encryptedValue, 'base64', 'utf8');
            decrypted += decipher.final('utf8');
            return decrypted;
        } catch (error) {
            console.error('🔥 AES Decryption with Raw Key Error:', error);
            return null;
        }
    }
}

/**
 * Derives dynamic per-user/per-device session AES key
 */
function deriveSessionKey(userId = '', deviceId = '') {
    const masterSecret = process.env.MASTER_API_KEY || '';
    if (!userId && !deviceId) {
        return masterSecret;
    }
    // Blend masterSecret with userId & deviceId for dynamic per-user encryption
    const seed = `${masterSecret}:${userId}:${deviceId}`;
    return crypto.createHash('sha256').update(seed).digest('hex').substring(0, 32);
}

/**
 * Payload Decryption Middleware
 * Automatically intercepts encrypted `req.body.payload` and decrypts it before route handlers execute.
 * Supports both traditional symmetric AES and new asymmetric RSA Envelope hybrid cryptography.
 */
const cryptoMiddleware = async (req, res, next) => {
    // If already processed/decrypted by global middleware, pass through
    if (req.isDecrypted) {
        return next();
    }

    // Only process POST, PUT, PATCH requests with encrypted payload
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
        return next();
    }

    const urlLower = (req.originalUrl || req.url || '').toLowerCase();
    const reqPath = (req.path || '').toLowerCase();

    // Bypass encryption ONLY for explicit Admin panel routes, webhooks, login/logout, postbacks & user balance updates
    const isBypassPath =
        ['admin', 'login', 'logout', 'postback', 'webhook', 'verify', 'support', 'promotion', 'update-user-data', 'add-app-bonus', 'deduct-user-coins', 'block-user', 'unblock-user', 'block-payout', 'handle-payout', 'send-notification', 'wallet-catalog', 'app-data-config', 'promoter', 'giveaway', 'task', 'promo', 'delete-user-account', 'toggle-account-deleted', 'bulk-delete-users', 'wipe-user-data', 'reward-history', 'banner'].some(path => urlLower.includes(path)) ||
        ['/manage-', '/add-', '/giveaway', '/dashboard', '/app-data', '/payment', '/user-', '/redis-'].some(prefix => reqPath.startsWith(prefix)) ||
        Boolean(req.cookies && (req.cookies.adminToken || req.cookies.admin_token || req.cookies.token || req.cookies.admin)) ||
        Boolean(req.session && (req.session.admin || req.session.adminId));

    const encryptedPayload = req.body?.payload;
    const envelopeKeyHeader = req.headers['x-envelope-key'];

    if (!encryptedPayload || typeof encryptedPayload !== 'string') {
        if (isBypassPath) {
            req.isDecrypted = true;
            return next();
        }
        return res.status(400).json({
            success: false,
            message: 'Encryption required'
        });
    }

    const userId = req.headers['x-user-id'] || req.headers['user-id'] || req.userId || req.body?.userId || '';
    const deviceId = req.headers['x-device-id'] || req.headers['device-id'] || req.body?.deviceId || '';
    const masterSecret = process.env.MASTER_API_KEY || '';

    // Fetch user public key from DB asynchronously for response encryption
    let clientPublicKey = '';
    if (userId) {
        try {
            const User = require('../models/user');
            const user = await User.findOne({ userId }).select('clientPublicKey').lean();
            if (user && user.clientPublicKey) {
                clientPublicKey = user.clientPublicKey;
            }
        } catch (dbError) {
            console.error('Error fetching user clientPublicKey:', dbError);
        }
    }

    // CASE 1: RSA Envelope (Hybrid Asymmetric Decryption)
    if (envelopeKeyHeader && serverPrivateKey) {
        let aesKeyBuf = null;
        let paddingHash = 'sha256';

        try {
            // Attempt 1: SHA-256 OAEP padding
            aesKeyBuf = crypto.privateDecrypt(
                {
                    key: serverPrivateKey,
                    padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
                    oaepHash: 'sha256'
                },
                Buffer.from(envelopeKeyHeader, 'base64')
            );
        } catch (err256) {
            try {
                // Attempt 2: Fallback to SHA-1 OAEP padding (compatible with standard Dart RSA OAEP)
                aesKeyBuf = crypto.privateDecrypt(
                    {
                        key: serverPrivateKey,
                        padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
                        oaepHash: 'sha1'
                    },
                    Buffer.from(envelopeKeyHeader, 'base64')
                );
                paddingHash = 'sha1';
            } catch (err1) {
                console.error('🔥 RSA Decryption Failed for both SHA-256 and SHA-1 OAEP');
            }
        }

        if (aesKeyBuf) {
            try {
                // Decrypt payload using decrypted ephemeral AES Key
                const decryptedStr = ChCrypto.decryptWithKey(encryptedPayload, aesKeyBuf);
                if (decryptedStr) {
                    const parsedBody = JSON.parse(decryptedStr);
                    req.rawPayload = encryptedPayload;
                    req.body = parsedBody;
                    req.isDecrypted = true;

                    // Hook response interceptor to encrypt using Client's RSA Public Key (matching negotiated hash)
                    const currentPaddingHash = paddingHash;
                    const originalJson = res.json.bind(res);
                    res.json = function (data) {
                        try {
                            if (clientPublicKey) {
                                // Generate random 32-byte ephemeral AES Key for response
                                const responseAesKey = crypto.randomBytes(32);
                                const encResponse = ChCrypto.encryptWithKey(data, responseAesKey);

                                // Encrypt response AES key using Client's RSA Public Key
                                const encryptedResponseKey = crypto.publicEncrypt(
                                    {
                                        key: clientPublicKey,
                                        padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
                                        oaepHash: currentPaddingHash
                                    },
                                    responseAesKey
                                );

                                // Set envelope key header and return payload
                                res.setHeader('x-envelope-key', encryptedResponseKey.toString('base64'));
                                return originalJson({ success: true, responsePayload: encResponse });
                            }
                        } catch (err) {
                            console.error('🔥 Asymmetric Response Encryption Error:', err);
                        }
                        return originalJson(data);
                    };

                    return next();
                }
            } catch (err) {
                console.error('🔥 RSA Envelope Decryption Fail:', err);
            }
        }
    }

    // CASE 2: Fallback to Traditional Symmetric AES Decryption (Backward Compatibility)
    let sessionKey = deriveSessionKey(userId, deviceId);
    let decryptedStr = ChCrypto.decrypt(encryptedPayload, sessionKey);
    let activeKey = sessionKey;

    if (!decryptedStr && userId && deviceId) {
        const userOnlyKey = deriveSessionKey(userId, '');
        decryptedStr = ChCrypto.decrypt(encryptedPayload, userOnlyKey);
        if (decryptedStr) activeKey = userOnlyKey;
    }

    if (!decryptedStr) {
        const defaultKey = deriveSessionKey('', '');
        decryptedStr = ChCrypto.decrypt(encryptedPayload, defaultKey);
        if (decryptedStr) activeKey = defaultKey;
    }

    if (!decryptedStr) {
        decryptedStr = ChCrypto.decrypt(encryptedPayload, masterSecret);
        if (decryptedStr) activeKey = masterSecret;
    }

    if (!decryptedStr) {
        if (isBypassPath) {
            req.isDecrypted = true;
            return next();
        }
        return res.status(400).json({
            success: false,
            message: 'Failed to decrypt request payload'
        });
    }

    try {
        const parsedBody = JSON.parse(decryptedStr);
        req.rawPayload = encryptedPayload;
        req.body = parsedBody;
        req.isDecrypted = true;

        // Auto-encrypt outgoing response if incoming request was encrypted
        const originalJson = res.json.bind(res);
        res.json = function (data) {
            try {
                const encResponse = ChCrypto.encrypt(data, activeKey);
                if (encResponse) {
                    return originalJson({ success: true, responsePayload: encResponse });
                }
            } catch (err) {
                console.error('🔥 Symmetric Response Encryption Error:', err);
            }
            return originalJson(data);
        };

        next();
    } catch (parseError) {
        return res.status(400).json({
            success: false,
            message: 'Invalid decrypted payload format'
        });
    }
};

cryptoMiddleware.ChCrypto = ChCrypto;
cryptoMiddleware.deriveSessionKey = deriveSessionKey;
cryptoMiddleware.cryptoMiddleware = cryptoMiddleware;

module.exports = cryptoMiddleware;
