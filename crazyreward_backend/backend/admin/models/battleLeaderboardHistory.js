const mongoose = require('mongoose');

const battleLeaderboardHistorySchema = new mongoose.Schema({
    cycleId: { type: String, required: true, unique: true },
    periodEnd: { type: Date, required: true },
    totalPlayers: { type: Number, default: 0 },
    topWinnerName: { type: String, default: 'No Participants' },
    topWinnerAvatar: { type: String, default: '' },
    payoutStatus: { type: String, enum: ['PENDING', 'PROCESSED'], default: 'PENDING' },
    payoutProcessedAt: { type: Date, default: null },
    title: { type: String, default: 'Leaderboard' },
    cycleType: { type: String, default: 'Weekly' },
    showWinnersOnly: { type: Boolean, default: false },
    standingsSnapshot: { type: Array, default: [] }
}, { timestamps: true });

module.exports = mongoose.models.BattleLeaderboardHistory || mongoose.model('BattleLeaderboardHistory', battleLeaderboardHistorySchema);

