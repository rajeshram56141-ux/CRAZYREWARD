const mongoose = require('mongoose');

const postbackLogSchema = new mongoose.Schema({
    appName: { type: String, required: true },
    userId: { type: String, required: true },
    txnId: { type: String, required: true },
    offerId: { type: String, required: true },
    eventId: { type: String, default: '' },  // For multi-event tasks
    payout: { type: Number, required: true },
    responseStatus: { type: Number, required: true },
    payload: { type: mongoose.Schema.Types.Mixed, required: true },
    userEmail: { type: String, default: '' },
    userGaid: { type: String, default: '' },
    processingTime: { type: Number, default: 0 },
    completedAt: { type: Date, default: Date.now },  // For daily reset tracking
}, { timestamps: true });

// 🚀 Index for ultra-fast task completion checks
postbackLogSchema.index({ appName: 1, userId: 1, offerId: 1 });
postbackLogSchema.index({ appName: 1, userId: 1, offerId: 1, eventId: 1 });  // For event-level tracking
postbackLogSchema.index({ userId: 1, completedAt: 1 });  // For daily reset queries


module.exports = mongoose.model('postbackLogs', postbackLogSchema);
