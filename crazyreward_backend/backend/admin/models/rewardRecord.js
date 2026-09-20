const mongoose = require('mongoose');

const rewardRecordSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    coins: { type: Number, required: true },
    type: { type: String, required: true }, // streak, promoCode, offerwall, dailyTask, giveaway, battle, follow
    description: { type: String, default: '' },
    referralCoins: { type: Number, default: 0 },
    referralProcessedAt: { type: Date, default: null },
    metadata: { type: mongoose.Schema.Types.Mixed, default: {} },
    timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

rewardRecordSchema.index({ userId: 1, timestamp: -1 });
rewardRecordSchema.index({ type: 1, timestamp: -1 });

module.exports = mongoose.model('RewardRecord', rewardRecordSchema);
