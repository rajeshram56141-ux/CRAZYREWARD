const mongoose = require('mongoose');

const bannerClickLogSchema = new mongoose.Schema({
    screenKey: { type: String, required: true, index: true },
    userId: { type: String, default: '', index: true },
    clickUrl: { type: String, default: '' },
    date: { type: String, required: true, index: true }, // 'YYYY-MM-DD' in IST
    ipAddress: { type: String, default: '' },
}, { timestamps: true });

bannerClickLogSchema.index({ screenKey: 1, date: 1 });

module.exports = mongoose.model('BannerClickLogs', bannerClickLogSchema);
