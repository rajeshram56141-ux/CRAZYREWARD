const mongoose = require('mongoose');

const payoutHistorySchema = new mongoose.Schema({
    appName: { type: String, required: true },
    userId: { type: String, required: true },
    orderId: { type: String, required: true, unique: true },
    coins: { type: Number, required: true },
    amount: { type: Number, required: true },
    symbol: { type: String, required: true },
    image: { type: String, default: '' },
    status: { type: String, required: true, default: 'pending' },
    txnId: { type: String, default: '' },
    methodName: { type: String, required: true },
    methodDetails: { type: mongoose.Schema.Types.Mixed, default: {} },
    redeemUrl: { type: String, default: '' },
    redeemCode: { type: String, default: '' },
    giftPin: { type: String, default: '' },
    message: { type: String, default: '' },
    rejectReason: { type: String, default: '' },
    failureReason: { type: String, default: '' },
    timestamp: { type: Date, default: Date.now },
    processTimestamp: { type: Date, default: null }
}, { timestamps: true });

// 🚀 Index for fast query of individual user withdrawal lists
payoutHistorySchema.index({ appName: 1, userId: 1, timestamp: -1 });

module.exports = mongoose.model('payoutHistory', payoutHistorySchema);
