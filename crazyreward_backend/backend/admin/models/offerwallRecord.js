const mongoose = require('mongoose');

const offerwallRecordSchema = new mongoose.Schema({
    provider: { type: String, required: true },
    transactionId: { type: String, required: true, unique: true },
    userId: { type: String, required: true },
    payout: { type: Number, required: true },
    coins: { type: Number, required: true },
    status: { type: String, default: 'credited' },
    ipAddress: { type: String, default: '' },
    rawData: { type: mongoose.Schema.Types.Mixed, default: {} },
    timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

offerwallRecordSchema.index({ provider: 1, transactionId: 1 });
offerwallRecordSchema.index({ userId: 1, timestamp: -1 });

module.exports = mongoose.model('OfferwallRecord', offerwallRecordSchema);
