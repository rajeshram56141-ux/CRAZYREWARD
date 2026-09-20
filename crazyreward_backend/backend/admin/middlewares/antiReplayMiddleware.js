const crypto = require('crypto');
const cacheService = require('../../services/cacheService');

// In-memory sliding window signature cache fallback
const signatureCache = new Map();

// Periodic cleanup of expired signatures every 3 minutes for in-memory fallback
setInterval(() => {
    const now = Date.now();
    const ttlMs = (cacheService.getTtl('antiReplay') || 300) * 1000;
    for (const [signature, timestamp] of signatureCache.entries()) {
        if (now - timestamp > ttlMs) {
            signatureCache.delete(signature);
        }
    }
}, 3 * 60 * 1000);

/**
 * Anti-Replay Guard Middleware
 * Verifies timestamp freshness and checks HMAC-SHA256 signature to block duplicate HTTP requests.
 * Uses Redis RAM Cache (0.1ms) when available with automatic In-Memory sliding window fallback.
 */
const antiReplayMiddleware = async (req, res, next) => {
    // Only enforce anti-replay on POST, PUT, DELETE state-changing requests
    if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
        return next();
    }

    const timestampHeader = req.headers['x-request-timestamp'] || req.headers['time'] || req.body?.clientMillis;
    const signatureHeader = req.headers['x-signature'];

    // If no timestamp or signature header provided, proceed (backward compatibility)
    if (!timestampHeader || !signatureHeader) {
        return next();
    }

    const clientMillis = Number(timestampHeader);
    if (isNaN(clientMillis) || clientMillis <= 0) {
        return res.status(400).json({
            success: false,
            message: 'Invalid request timestamp header'
        });
    }

    const now = Date.now();
    const ttlSeconds = cacheService.getTtl('antiReplay') || 300;
    const maxDrift = ttlSeconds * 1000; // Synchronized drift window

    // 1. Time sync & drift check
    if (Math.abs(now - clientMillis) > maxDrift) {
        return res.status(400).json({
            success: false,
            message: 'Request timestamp expired or out of sync'
        });
    }

    const redisKey = `replay:${signatureHeader}`;
    const redisClient = cacheService.getClient();

    // 2. Anti-Replay check using Redis or In-Memory fallback
    if (redisClient) {
        try {
            const exists = await redisClient.get(redisKey);
            if (exists) {
                console.warn(`⚠️ Replay attack blocked via Redis RAM: ${signatureHeader.substring(0, 10)}...`);
                return res.status(400).json({
                    success: false,
                    message: 'Replay request blocked: Signature already processed'
                });
            }
        } catch (e) {
            // Fall back to memory below
        }
    }

    if (!redisClient) {
        if (signatureCache.has(signatureHeader)) {
            console.warn(`⚠️ Replay attack blocked via In-Memory Cache: ${signatureHeader.substring(0, 10)}...`);
            return res.status(400).json({
                success: false,
                message: 'Replay request blocked: Signature already processed'
            });
        }
    }

    // 3. Verify HMAC-SHA256 signature
    const secretKey = process.env.MASTER_API_KEY || '';
    const payloadStr = typeof req.body === 'string' ? req.body : JSON.stringify(req.body || {});
    const expectedSignature = crypto
        .createHmac('sha256', secretKey)
        .update(`${clientMillis}.${payloadStr}`)
        .digest('hex');

    if (signatureHeader !== expectedSignature) {
        return res.status(400).json({
            success: false,
            message: 'Invalid request signature'
        });
    }

    // Save signature with configured TTL (default 300 seconds)
    if (redisClient) {
        try {
            await redisClient.set(redisKey, String(now), 'EX', ttlSeconds);
        } catch (_) {
            signatureCache.set(signatureHeader, now);
        }
    } else {
        signatureCache.set(signatureHeader, now);
    }

    next();
};

module.exports = antiReplayMiddleware;

module.exports.getRedisStatus = async () => {
    let keyDetails = [];
    let totalKeysCount = 0;
    const redisClient = cacheService.getClient();

    if (redisClient) {
        try {
            const patterns = ['battle:*', 'global:*', 'daily_*', 'replay:*', 'rl:*', 'dp:*', 'leaderboard:*', 'wallet:*', 'games:*', 'tasks:*', 'giveaways:*', 'readearn:*', 'quiz:*', 'diamondcatch:*'];
            let allKeys = [];
            for (const p of patterns) {
                const found = await redisClient.keys(p);
                if (found && found.length > 0) {
                    allKeys.push(...found);
                }
            }

            allKeys = Array.from(new Set(allKeys));
            totalKeysCount = allKeys.length;

            const sliceKeys = allKeys.slice(0, 100);
            for (const k of sliceKeys) {
                try {
                    const [type, ttl] = await Promise.all([
                        redisClient.type(k).catch(() => 'string'),
                        redisClient.ttl(k).catch(() => -1)
                    ]);

                    let preview = '';
                    let val = '';
                    if (type === 'string') {
                        val = await redisClient.get(k).catch(() => '');
                        preview = val ? (val.length > 90 ? val.substring(0, 90) + '...' : val) : '';
                    } else if (type === 'zset') {
                        const card = await redisClient.zcard(k).catch(() => 0);
                        preview = `ZSet (${card} entries)`;
                    } else if (type === 'hash') {
                        const len = await redisClient.hlen(k).catch(() => 0);
                        preview = `Hash (${len} fields)`;
                    } else if (type === 'set') {
                        const card = await redisClient.scard(k).catch(() => 0);
                        preview = `Set (${card} items)`;
                    } else if (type === 'list') {
                        const len = await redisClient.llen(k).catch(() => 0);
                        preview = `List (${len} items)`;
                    } else {
                        preview = type;
                    }

                    keyDetails.push({
                        name: k,
                        type: (type || 'string').toUpperCase(),
                        ttl: (ttl !== undefined && ttl !== null) ? Number(ttl) : -1,
                        preview: preview || '-',
                        value: (type === 'string') ? (val || '') : null
                    });
                } catch (_) {
                    keyDetails.push({
                        name: k,
                        type: 'STRING',
                        ttl: -1,
                        preview: '-',
                        value: ''
                    });
                }
            }
        } catch (_) {}
    } else {
        const now = Date.now();
        const ttlMs = (cacheService.getTtl('antiReplay') || 300) * 1000;
        totalKeysCount = signatureCache.size;
        for (const [k, timestamp] of signatureCache.entries()) {
            const remSec = Math.max(0, Math.round((ttlMs - (now - timestamp)) / 1000));
            keyDetails.push({
                name: k,
                type: 'MEMORY',
                ttl: remSec,
                preview: String(timestamp),
                value: String(timestamp)
            });
            if (keyDetails.length >= 100) break;
        }
    }

    return {
        isRedisActive: cacheService.isRedisActive(),
        config: cacheService.getConfig(),
        keysCount: totalKeysCount,
        keys: keyDetails
    };
};

module.exports.flushRedisCache = async () => {
    await cacheService.flushCrazyrewardCache();
    signatureCache.clear();
    return true;
};

module.exports.deleteRedisKey = async (key) => {
    await cacheService.del(key);
    signatureCache.delete(key);
    return true;
};
