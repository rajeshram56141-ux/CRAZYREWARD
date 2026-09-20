const mongoose = require('mongoose');

const rewardHistorySchema = new mongoose.Schema({
    appName: { type: String, default: '' },
    userId: { type: String, required: true },
    provider: { type: String, required: true },
    coins: { type: Number, default: 0 },
    gems: { type: Number, default: 0 },
    rewardType: { type: String, enum: ['coin', 'gem'], default: 'coin' },
    orderId: { type: String, default: null },
    offerId: { type: String, default: null },
    transId: { type: String, default: null },
    eventId: { type: String, default: null },
    timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

// 🚀 Index for ultra-fast history lookups per user (sorted by most recent first)
rewardHistorySchema.index({ appName: 1, userId: 1, timestamp: -1 });
rewardHistorySchema.index({ userId: 1, timestamp: -1 });

module.exports = mongoose.model('rewardHistory', rewardHistorySchema);
