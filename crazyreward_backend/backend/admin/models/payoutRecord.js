const mongoose = require('mongoose');

const payoutRecordSchema = new mongoose.Schema({
    appName: { type: String, default: '' },
    userId: { type: String, required: true },
    orderId: { type: String, required: true, unique: true },
    coins: { type: Number, required: true },
    amount: { type: Number, required: true },
    symbol: { type: String, default: '' },
    image: { type: String, default: '' },
    status: { type: String, required: true, default: 'pending' },
    txnId: { type: String, default: '' },
    methodName: { type: String, required: true },
    methodDetails: { type: mongoose.Schema.Types.Mixed, default: {} },
    redeemUrl: { type: String, default: '' },
    redeemCode: { type: String, default: '' },
    giftPin: { type: String, default: '' },
    email: { type: String, default: '' },
    autoPayment: { type: Boolean, default: false },
    provider: { type: String, default: '' },
    message: { type: String, default: '' },
    rejectReason: { type: String, default: '' },
    failureReason: { type: String, default: '' },
    apiOrderId: { type: String, default: '' },
    postbackStatus: { type: String, default: '' },
    transferMode: { type: String, default: '' },
    utr: { type: String, default: '' },
    referenceId: { type: String, default: '' },
    apiPostbackRaw: { type: mongoose.Schema.Types.Mixed, default: null },
    timestamp: { type: Date, default: Date.now },
    processTimestamp: { type: Date, default: null }
}, { timestamps: true });

// 🚀 Indexes for fast query of app-specific order listings, filtering, and searches
payoutRecordSchema.index({ appName: 1, status: 1, timestamp: -1 });
payoutRecordSchema.index({ appName: 1, userId: 1, timestamp: -1 });
payoutRecordSchema.index({ apiOrderId: 1 });

module.exports = mongoose.model('payoutRecord', payoutRecordSchema);
