const mongoose = require('mongoose');

const redisConfigSchema = new mongoose.Schema({
    key: {
        type: String,
        default: 'redisConfig',
        unique: true
    },
    isEnabled: {
        type: Boolean,
        default: true
    },
    globalTtlSeconds: {
        type: Number,
        default: 300 // 5 minutes default (App Config, Battle Rooms, Wallet Methods, Games, Daily Tasks)
    },
    leaderboardTtlSeconds: {
        type: Number,
        default: 60 // 1 minute default (Battle & Coins Leaderboards)
    },
    updatedAt: {
        type: Date,
        default: Date.now
    }
}, { timestamps: true });

module.exports = mongoose.model('RedisConfig', redisConfigSchema);
