const mongoose = require('mongoose');

const gamePlayLogsSchema = new mongoose.Schema({
    offerId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'PlayGames',
        required: true,
    },
    userId: {
        type: String,
        required: true,
    },
    playedAt: {
        type: Date,
        default: Date.now,
    },
    dayKey: {
        type: String, // Format: "2026-05-20" (IST timezone)
    },
}, { timestamps: true });

// Indexes for fast lookups
gamePlayLogsSchema.index({ offerId: 1, userId: 1 });
gamePlayLogsSchema.index({ offerId: 1, userId: 1, dayKey: 1 });

module.exports = mongoose.model('GamePlayLogs', gamePlayLogsSchema);