let Redis;
try {
    Redis = require('ioredis');
} catch (_) {}

// Redis Connection detection (graceful in-memory fallback)
let redisClient = null;
let isRedisAvailable = false;

if (Redis && process.env.REDIS_ENABLED === 'true') {
    try {
        const redisUrl = process.env.REDIS_URL || 'redis://127.0.0.1:6379';
        redisClient = new Redis(redisUrl, {
            connectTimeout: 2000,
            maxRetriesPerRequest: 1,
            retryStrategy: () => false
        });

        redisClient.on('connect', () => {
            isRedisAvailable = true;
        });

        redisClient.on('error', () => {
            isRedisAvailable = false;
        });
    } catch (_) {
        isRedisAvailable = false;
    }
}

// In-Memory fallback cache
const memoryCache = new Map();

// Periodic cleanup of memory cache every 5 minutes
setInterval(() => {
    const now = Date.now();
    for (const [key, data] of memoryCache.entries()) {
        if (now > data.expiry) {
            memoryCache.delete(key);
        }
    }
}, 5 * 60 * 1000);

/**
 * Dynamic Rate Limiter Factory
 * @param {Object} options Configuration options
 * @param {number} options.windowMs Time window in milliseconds (default: 60000ms / 1 min)
 * @param {number} options.max Maximum requests in the window
 * @param {string} options.keyPrefix Prefix for cache keys
 * @param {function} options.keyGenerator Custom function to generate rate-limit identifier key
 */
const rateLimiter = (options = {}) => {
    const windowMs = options.windowMs || 60 * 1000;
    const max = options.max || 10;
    const prefix = options.keyPrefix || 'rl';
    const keyGenerator = options.keyGenerator || ((req) => req.ip || req.headers['x-forwarded-for'] || 'global');

    return async (req, res, next) => {
        const identifier = keyGenerator(req);
        const cacheKey = `${prefix}:${identifier}`;
        const now = Date.now();

        if (isRedisAvailable && redisClient) {
            try {
                // Multi/Pipeline atomic command
                const current = await redisClient.get(cacheKey);
                if (current && Number(current) >= max) {
                    return res.status(429).json({
                        success: false,
                        message: 'Too many requests. Please try again later.'
                    });
                }

                if (!current) {
                    await redisClient.set(cacheKey, '1', 'PX', windowMs);
                } else {
                    await redisClient.incr(cacheKey);
                }
                return next();
            } catch (_) {
                // Fail-over to memory cache below
            }
        }

        // Memory Cache Fallback
        const record = memoryCache.get(cacheKey);
        if (record) {
            if (now > record.expiry) {
                memoryCache.set(cacheKey, {
                    count: 1,
                    expiry: now + windowMs
                });
                return next();
            }

            if (record.count >= max) {
                return res.status(429).json({
                    success: false,
                    message: 'Too many requests. Please try again later.'
                });
            }

            record.count += 1;
            memoryCache.set(cacheKey, record);
        } else {
            memoryCache.set(cacheKey, {
                count: 1,
                expiry: now + windowMs
            });
        }

        next();
    };
};

module.exports = rateLimiter;
