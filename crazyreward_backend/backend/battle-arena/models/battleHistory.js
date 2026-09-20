const mongoose = require('mongoose');

const battleHistoryWinnerSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    userName: { type: String, default: 'Player' },
    avatar: { type: String, default: '' },
    rank: { type: Number, required: true },
    winsCount: { type: Number, default: 0 },
    totalSpeedPoints: { type: Number, default: 0 },
    coinsAwarded: { type: Number, default: 0 }
});

const battleHistorySchema = new mongoose.Schema({
    cycleId: { type: String, required: true },
    title: { type: String, default: 'Leaderboard' },
    cycleType: { type: String, default: 'Weekly' },
    rankingBasis: { type: String, enum: ['wins', 'points'], default: 'wins' }, // 'wins' (Wins Based), 'points' (Points Based)
    cycleDays: { type: Number, default: 7 },
    showWinnersOnly: { type: Boolean, default: false },
    status: { type: String, enum: ['PENDING', 'APPROVED', 'REJECTED'], default: 'PENDING' },
    resultDeclaredAt: { type: Date, default: null },
    startTime: { type: Date },
    nextPayoutTime: { type: Date },
    winners: [battleHistoryWinnerSchema],
    autoRewarded: { type: Boolean, default: false }
}, { timestamps: true });

module.exports = mongoose.models.BattleHistory || mongoose.model('BattleHistory', battleHistorySchema);
