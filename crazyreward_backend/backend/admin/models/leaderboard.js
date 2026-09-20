const mongoose = require('mongoose');

const leaderboardSchema = new mongoose.Schema({
    type: { type: String, required: true, unique: true }, // 'coins' or 'referral'
    toppers: [{
        userId: { type: String, default: '' },
        name: { type: String, default: '' },
        photoUrl: { type: String, default: '' },
        totalCoins: { type: Number, default: 0 },
        totalReferrals: { type: Number, default: 0 }
    }],
    updatedAt: { type: Date, default: Date.now }
}, { timestamps: true });

module.exports = mongoose.models.Leaderboard || mongoose.model('Leaderboard', leaderboardSchema);
