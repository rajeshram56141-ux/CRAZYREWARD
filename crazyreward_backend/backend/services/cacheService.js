let Redis;
try {
    Redis = require('ioredis');
} catch (_) { }

let redisClient = null;
let isRedisAvailable = false;

// 2 Clean TTL Configurations: Global (300s) & Leaderboard (60s)
let currentConfig = {
    isEnabled: process.env.REDIS_ENABLED === 'true',
    globalTtlSeconds: 300,        // 5 minutes (Rooms, App Config, Wallet, Games, Daily Tasks)
    leaderboardTtlSeconds: 60     // 1 minute (Battle & Coins Leaderboards)
};

function connectRedis() {
    if (!Redis) return null;
    try {
        const redisUrl = process.env.REDIS_URL || 'redis://127.0.0.1:6379';
        const client = new Redis(redisUrl, {
            connectTimeout: 2000,
            maxRetriesPerRequest: 1,
            retryStrategy: () => false
        });

        client.on('connect', () => {
            isRedisAvailable = true;
            console.log('🔴 Redis Cache Service connected successfully');
        });

        client.on('error', () => {
            isRedisAvailable = false;
        });

        return client;
    } catch (_) {
        isRedisAvailable = false;
        return null;
    }
}

if (Redis && process.env.REDIS_ENABLED === 'true') {
    redisClient = connectRedis();
}

// In-Memory fallback cache
const memoryCache = new Map();

// Periodic cleanup of expired entries in memory cache every 5 minutes
setInterval(() => {
    const now = Date.now();
    for (const [key, record] of memoryCache.entries()) {
        if (record && now > record.expiry) {
            memoryCache.delete(key);
        }
    }
}, 5 * 60 * 1000);

const cacheService = {
    /**
     * Get a cached value
     * @param {string} key Cache key
     * @returns {Promise<any>} Parsed JSON value or null
     */
    async get(key) {
        if (isRedisAvailable && redisClient) {
            try {
                const data = await redisClient.get(key);
                return data ? JSON.parse(data) : null;
            } catch (_) {
                // Fallback to memory
            }
        }

        const record = memoryCache.get(key);
        if (record) {
            if (Date.now() > record.expiry) {
                memoryCache.delete(key);
                return null;
            }
            return record.value;
        }
        return null;
    },

    /**
     * Set a cached value
     * @param {string} key Cache key
     * @param {any} value Value to store (will be JSON stringified)
     * @param {number} ttlSeconds Expiry time in seconds
     */
    async set(key, value, ttlSeconds) {
        const ttl = Number(ttlSeconds) > 0 ? Number(ttlSeconds) : this.getTtl('global');

        if (isRedisAvailable && redisClient) {
            try {
                const dataStr = JSON.stringify(value);
                await redisClient.set(key, dataStr, 'EX', ttl);
                return true;
            } catch (_) {
                // Fallback to memory
            }
        }

        memoryCache.set(key, {
            value,
            expiry: Date.now() + (ttl * 1000)
        });
        return true;
    },

    /**
     * Delete a cached value
     * @param {string} key Cache key
     */
    async del(key) {
        if (isRedisAvailable && redisClient) {
            try {
                await redisClient.del(key);
                return true;
            } catch (_) {
                // Fallback to memory
            }
        }

        memoryCache.delete(key);
        return true;
    },

    /**
     * Delete multiple keys matching a pattern
     */
    async delPattern(pattern) {
        if (isRedisAvailable && redisClient) {
            try {
                const keys = await redisClient.keys(pattern);
                if (keys && keys.length > 0) {
                    await redisClient.del(...keys);
                }
            } catch (_) { }
        }

        if (pattern.endsWith('*')) {
            const prefix = pattern.slice(0, -1);
            for (const key of memoryCache.keys()) {
                if (key.startsWith(prefix)) {
                    memoryCache.delete(key);
                }
            }
        } else {
            memoryCache.delete(pattern);
        }
        return true;
    },

    /**
     * Safely flush only Crazyreward cache keys without touching other server databases (e.g. knifeslice_meapp)
     */
    async flushCrazyrewardCache() {
        if (isRedisAvailable && redisClient) {
            try {
                const patterns = ['battle:*', 'global:*', 'daily_*', 'replay:*', 'rl:*', 'dp:*', 'leaderboard:*', 'wallet:*', 'games:*', 'tasks:*', 'giveaways:*', 'readearn:*', 'quiz:*', 'diamondcatch:*'];
                for (const pattern of patterns) {
                    const keys = await redisClient.keys(pattern);
                    if (keys && keys.length > 0) {
                        await redisClient.del(...keys);
                    }
                }
            } catch (err) {
                console.error('⚠️ Error purging Crazyreward Redis keys:', err.message);
            }
        }

        memoryCache.clear();
        console.log('🧹 Crazyreward cache flushed successfully (Redis & In-Memory).');
        return true;
    },

    async flush() {
        return this.flushCrazyrewardCache();
    },

    isRedisActive() {
        return isRedisAvailable && redisClient !== null;
    },

    getClient() {
        return isRedisAvailable ? redisClient : null;
    },

    /**
     * Get TTL by category: only 2 TTLs - 'leaderboard' or 'global'
     * @param {'global'|'leaderboard'|string} category
     */
    getTtl(category) {
        if (category === 'leaderboard') {
            return currentConfig.leaderboardTtlSeconds || 60;
        }
        return currentConfig.globalTtlSeconds || 300;
    },

    getConfig() {
        return {
            ...currentConfig,
            isRedisActive: this.isRedisActive()
        };
    },

    updateConfig(newConfig = {}) {
        if (typeof newConfig.isEnabled === 'boolean') {
            currentConfig.isEnabled = newConfig.isEnabled;
            this.toggleRedis(newConfig.isEnabled);
        }
        if (Number(newConfig.globalTtlSeconds) > 0) {
            currentConfig.globalTtlSeconds = Number(newConfig.globalTtlSeconds);
        }
        if (Number(newConfig.leaderboardTtlSeconds) > 0) {
            currentConfig.leaderboardTtlSeconds = Number(newConfig.leaderboardTtlSeconds);
        }
        return this.getConfig();
    },

    toggleRedis(enabled) {
        if (enabled) {
            if (!redisClient || !isRedisAvailable) {
                try {
                    if (redisClient) {
                        try { redisClient.disconnect(); } catch (_) { }
                    }
                    redisClient = connectRedis();
                    process.env.REDIS_ENABLED = 'true';
                    currentConfig.isEnabled = true;
                } catch (e) {
                    console.error('Error toggling Redis ON:', e);
                }
            }
        } else {
            if (redisClient) {
                try {
                    redisClient.disconnect();
                } catch (_) { }
                redisClient = null;
            }
            isRedisAvailable = false;
            process.env.REDIS_ENABLED = 'false';
            currentConfig.isEnabled = false;
            console.log('⚪ Redis disconnected. Fallback to In-Memory RAM active.');
        }
        return this.isRedisActive();
    },

    async loadConfigFromDb() {
        try {
            const RedisConfig = require('../admin/models/redisConfig');
            let configDoc = await RedisConfig.findOne({ key: 'redisConfig' }).lean();
            if (!configDoc) {
                configDoc = await RedisConfig.create({
                    key: 'redisConfig',
                    isEnabled: process.env.REDIS_ENABLED === 'true',
                    globalTtlSeconds: 300,
                    leaderboardTtlSeconds: 60
                });
            }
            if (configDoc) {
                this.updateConfig({
                    isEnabled: configDoc.isEnabled,
                    globalTtlSeconds: configDoc.globalTtlSeconds || configDoc.roomsTtlSeconds || configDoc.appDataTtlSeconds || 300,
                    leaderboardTtlSeconds: configDoc.leaderboardTtlSeconds || 60
                });
            }
        } catch (_) { }
    }
};

module.exports = cacheService;
