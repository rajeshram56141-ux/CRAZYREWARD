const mongoose = require('mongoose');

const battleRoomSchema = new mongoose.Schema({
    roomId: { type: String, required: true, unique: true },
    title: { type: String, required: true },
    subtitle: { type: String, default: '1v1 Quiz Battle Clash' },
    capacity: { type: Number, default: 2 }, // 2 for 1v1
    entryType: { type: String, enum: ['Free', 'Paid'], default: 'Paid' },
    entryFeeCoins: { type: Number, default: 100 },
    platformCutPercent: { type: Number, default: 10 },
    netPrizePoolCoins: { type: Number, default: 180 }, // Prize for winner after cut
    rankRewards: {
        type: [{
            rank: { type: Number, required: true },
            coins: { type: Number, required: true }
        }],
        default: []
    },
    questionCount: { type: Number, default: 7 },
    timePerQuestionSec: { type: Number, default: 20 },
    category: { type: String, default: 'General Knowledge' },
    assignedGameTitle: { type: String, default: 'General Quiz Clash' }, // Assigned Quiz Game Set
    badge: { type: String, default: 'HOT' },
    autoRepeatIntervalMinutes: { type: Number, default: 2 }, // Auto recurring timer in minutes
    nextStartTime: { type: Date, default: () => new Date(Date.now() + 2 * 60 * 1000) },
    totalMatchesPlayed: { type: Number, default: 0 },
    matchingTimeoutSec: { type: Number, default: 35 },
    enableAiBot: { type: Boolean, default: false },
    adType: { type: String, enum: ['None', 'Rewarded', 'Interstitial'], default: 'None' },
    skipAdMatches: { type: Number, default: 0 },
    status: { type: String, enum: ['Active', 'Draft', 'Closed'], default: 'Active' }
}, { timestamps: true });

module.exports = mongoose.model('BattleRoom', battleRoomSchema);
