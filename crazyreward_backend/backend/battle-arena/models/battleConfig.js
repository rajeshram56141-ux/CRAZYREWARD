const mongoose = require('mongoose');

const rewardTierSchema = new mongoose.Schema({
    rankStart: { type: Number, required: true },
    rankEnd: { type: Number, required: true },
    coins: { type: Number, default: 0, required: false },
    iconUrl: { type: String, default: '' },
    customText: { type: String, default: '' }
}, { _id: false });

const battleTermSchema = new mongoose.Schema({
    title: { type: String, required: true },
    description: { type: String, required: true }
}, { _id: false });

const battleConfigSchema = new mongoose.Schema({
    key: { type: String, default: 'battleConfig', unique: true },
    leaderboardId: { type: String, default: '' },
    title: { type: String, default: 'Leaderboard' },
    cycleType: { type: String, default: 'Weekly' }, // 'Daily', 'Weekly', 'Monthly', 'Custom'
    rankingBasis: { type: String, enum: ['wins', 'points'], default: 'wins' }, // 'wins' (Wins Based), 'points' (Points Based)
    terms: {
        type: [battleTermSchema],
        default: [
            { title: "Acceptance of Terms", description: "By accessing or using this Quiz Application (\"App\"), you agree to be bound by these Terms and Conditions." },
            { title: "Fair Play & Anti-Cheat", description: "Minimizing the app or switching to Google during a battle will forfeit the current question." },
            { title: "Winner Coin Distribution", description: "Platform fee cut % is deducted automatically, and net coins are credited to the winner." }
        ]
    },
    isActive: { type: Boolean, default: true },
    cycleDays: { type: Number, default: 7 },
    platformCommissionFee: { type: Number, default: 10 }, // Platform Cut %
    freeRoomAdMandate: { type: Boolean, default: true }, // Require Rewarded Video Ad for Free rooms
    battleInstallTaskCount: { type: String, default: '0' },
    battleDailyLimit: { type: String, default: '0' },
    antiCheatStrictMode: { type: Boolean, default: true }, // Anti-cheat strict mode
    autoRewardProcess: { type: Boolean, default: true },
    autoReschedule: { type: Boolean, default: true }, // Auto-reschedule next round when payout time arrives
    startTime: { type: Date, default: () => new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
    nextPayoutTime: { type: Date, default: () => new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) },
    showWinnersOnly: { type: Boolean, default: false },
    initialSeeded: { type: Boolean, default: false }, // Prevent re-seeding deleted rooms
    installTaskMb: { type: Number, default: 15 },
    installTaskUsageSeconds: { type: Number, default: 30 },
    correctPoints: { type: Number, default: 100 },
    wrongPoints: { type: Number, default: -100 },
    maxBonusPoints: { type: Number, default: 100 },
    allowBonusCoins: { type: Boolean, default: false },
    bonusUsagePercent: { type: Number, default: 0 },
    freeTerms: { type: [battleTermSchema], default: [] },
    paidTerms: { type: [battleTermSchema], default: [] },
    rewardTiers: {
        type: [rewardTierSchema],
        default: []
    }
}, { timestamps: true });

module.exports = mongoose.models.BattleConfig || mongoose.model('BattleConfig', battleConfigSchema);
