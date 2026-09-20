const mongoose = require('mongoose');

const dailyEarningSummarySchema = new mongoose.Schema({
    appName: { type: String, required: true },
    mode: { type: String, required: true },
    provider: { type: String, required: true }, // e.g. "Battle Arena", "Daily Task", etc.
    dateStr: { type: String, required: true }, // "YYYY-MM-DD"
    earnings: { type: Number, required: true },
    impressions: { type: Number, required: true }
}, { timestamps: true });

dailyEarningSummarySchema.index({ appName: 1, mode: 1, provider: 1, dateStr: 1 }, { unique: true });

module.exports = mongoose.model('DailyEarningSummary', dailyEarningSummarySchema);
