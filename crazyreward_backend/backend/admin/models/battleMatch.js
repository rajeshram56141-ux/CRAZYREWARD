const mongoose = require('mongoose');

const playerResultSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    userName: { type: String, default: 'Player' },
    avatar: { type: String, default: '' },
    ipAddress: { type: String, default: '' },
    deviceId: { type: String, default: '' },
    adVerified: { type: Boolean, default: false },
    speedScore: { type: Number, default: 0 },
    correctCount: { type: Number, default: 0 },
    wrongCount: { type: Number, default: 0 },
    skippedCount: { type: Number, default: 0 },
    totalTimeTakenSec: { type: Number, default: 0 },
    forfeited: { type: Boolean, default: false },
    finished: { type: Boolean, default: false }
}, { _id: false });

const answerLogSchema = new mongoose.Schema({
    questionId: { type: String, required: true },
    userId: { type: String, required: true },
    selectedOptionIndex: { type: Number, required: true },
    isCorrect: { type: Boolean, required: true },
    timeTakenMs: { type: Number, required: true },
    speedPointsEarned: { type: Number, required: true },
    submittedAt: { type: Date, default: Date.now }
}, { _id: false });

const battleMatchSchema = new mongoose.Schema({
    matchId: { type: String, required: true, unique: true },
    roomId: { type: String, required: true },
    title: { type: String, default: '1v1 Quiz Battle' },
    
    // Configurations Snapshots (To prevent admin edits/deletions from affecting live matches)
    entryType: { type: String, default: 'Paid' },
    adType: { type: String, default: 'None' },
    skipAdMatches: { type: Number, default: 0 },
    entryFeeCoins: { type: Number, default: 0 },
    platformCutPercent: { type: Number, default: 0 },
    timePerQuestionSec: { type: Number, default: 20 },
    matchingTimeoutSec: { type: Number, default: 35 },
    enableAiBot: { type: Boolean, default: false },
    capacity: { type: Number, default: 2 },
    rankRewards: { type: mongoose.Schema.Types.Mixed, default: [] },

    player1: { type: playerResultSchema, required: true },
    player2: { type: playerResultSchema, default: null }, // Null until paired
    players: { type: [playerResultSchema], default: [] }, // Multi-player support array
    questions: [{ type: String }], // Question IDs array
    answerLogs: [answerLogSchema],
    status: { type: String, enum: ['MATCHING', 'WAITING', 'IN_PROGRESS', 'COMPLETED', 'FORFEITED', 'CANCELLED'], default: 'WAITING' },
    winnerUserId: { type: String, default: '' },
    platformFeeEarned: { type: Number, default: 0 },
    netPrizeAwarded: { type: Number, default: 0 },
    gameStartedAt: { type: Date, default: null },
    suspiciousFlag: { type: Boolean, default: false },
    cheatReason: { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('BattleMatch', battleMatchSchema);
