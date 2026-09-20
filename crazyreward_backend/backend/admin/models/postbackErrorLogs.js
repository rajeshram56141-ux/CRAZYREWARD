const mongoose = require('mongoose');

const postbackErrorLogSchema = new mongoose.Schema({
    provider: { type: String, required: true },
    errorType: { type: String, required: true },
    incomingIP: { type: String, default: '' },
    details: { type: mongoose.Schema.Types.Mixed, default: {} },
    timestamp: { type: Date, default: Date.now }
}, { timestamps: true });

module.exports = mongoose.model('postbackErrorLogs', postbackErrorLogSchema);
