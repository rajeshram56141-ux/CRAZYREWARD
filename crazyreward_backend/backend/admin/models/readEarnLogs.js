const mongoose = require('mongoose');

const readEarnLogSchema = new mongoose.Schema({
    appName: { type: String, required: true },
    userId: { type: String, required: true },
    offerId: { type: String, required: true },
    url: { type: String, required: true },
    payout: { type: Number, required: true },
    responseStatus: { type: Number, required: true },
    payload: { type: mongoose.Schema.Types.Mixed, required: true },
    processingTime: { type: Number, default: 0 }, 
}, { timestamps: true });

module.exports = mongoose.model('ReadEarnLogs', readEarnLogSchema);
