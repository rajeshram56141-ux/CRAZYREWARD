const mongoose = require('mongoose');

const userDailyChallengeSchema = new mongoose.Schema({
    userId: {
        type: String,
        required: true,
        index: true
    },
    dateStr: {
        type: String,
        required: true,
        index: true // Format: YYYY-MM-DD in IST
    },
    taskProgress: {
        type: Map,
        of: Number,
        default: () => ({})
    },
    completedTasks: {
        type: [String],
        default: []
    },
    claimedReward: {
        type: Boolean,
        default: false
    },
    claimedAt: {
        type: Date,
        default: null
    },
    rewardCoinsEarned: {
        type: Number,
        default: 0
    }
}, { timestamps: true });

// Compound index for fast queries per user per day
userDailyChallengeSchema.index({ userId: 1, dateStr: 1 }, { unique: true });

module.exports = mongoose.models.UserDailyChallenge || mongoose.model('UserDailyChallenge', userDailyChallengeSchema);
