const mongoose = require('mongoose');

const battleLeaderboardSchema = new mongoose.Schema({
    cycleId: { type: String, required: true }, // e.g. "cycle_2026_w32"
    userId: { type: String, required: true },
    userName: { type: String, default: 'Player' },
    avatar: { type: String, default: '' },
    winsCount: { type: Number, default: 0 },
    totalSpeedPoints: { type: Number, default: 0 },
    totalMatchesPlayed: { type: Number, default: 0 },
    rank: { type: Number, default: 0 },
    projectedPrizeCoins: { type: Number, default: 0 },
    isTied: { type: Boolean, default: false },
    tiedPlayerCount: { type: Number, default: 1 },
    payoutProcessed: { type: Boolean, default: false },
    lastMatchAt: { type: Date, default: Date.now }
}, { timestamps: true });

battleLeaderboardSchema.index({ cycleId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.models.BattleLeaderboard || mongoose.model('BattleLeaderboard', battleLeaderboardSchema);
