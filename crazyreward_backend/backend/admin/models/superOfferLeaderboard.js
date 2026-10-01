const mongoose = require('mongoose');

const superOfferLeaderboardSchema = new mongoose.Schema({
    monthKey: { type: String, required: true, index: true }, // e.g. "2026-10"
    userId: { type: String, required: true, index: true },
    userName: { type: String, default: 'User' },
    avatar: { type: String, default: '' },
    profileImage: { type: String, default: '' },
    unlockCount: { type: Number, default: 0 },
    lastUnlockedAt: { type: Date, default: Date.now },
    isDisqualified: { type: Boolean, default: false }
}, { timestamps: true });

superOfferLeaderboardSchema.index({ monthKey: 1, userId: 1 }, { unique: true });
superOfferLeaderboardSchema.index({ monthKey: 1, isDisqualified: 1, unlockCount: -1, lastUnlockedAt: 1 });

module.exports = mongoose.models.SuperOfferLeaderboard || mongoose.model('SuperOfferLeaderboard', superOfferLeaderboardSchema);
