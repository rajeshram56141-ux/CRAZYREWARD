const mongoose = require('mongoose');

const referralSettingsSchema = new mongoose.Schema({
    key: { type: String, default: 'referralSettings', unique: true },
    config: { type: mongoose.Schema.Types.Mixed, default: {} },
}, { timestamps: true, strict: false });

module.exports = mongoose.model('ReferralSettings', referralSettingsSchema);
