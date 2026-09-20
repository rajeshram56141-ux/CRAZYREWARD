const mongoose = require('mongoose');

const activitySchema = new mongoose.Schema({
    type: {
        type: String,
        required: true,
    },
    details: {
        type: String,
        required: true,
    },
    coinValue: {
        type: Number,
        default: 0,
    },
    date: {
        type: Date,
        default: Date.now,
    },
}, { _id: false });

const blockedHistorySchema = new mongoose.Schema({
    appName: {
        type: String,
        required: true,
        index: true,
    },
    userId: {
        type: String,
        required: true,
        index: true,
    },
    email: {
        type: String,
        default: '',
    },
    blockedAt: {
        type: Date,
        default: Date.now,
    },
    blockedBy: {
        type: String,
        default: '',
    },
    reason: {
        type: String,
        default: '',
    },
    type: {
        type: String,
        enum: ['manual', 'unusual_activity'],
        default: 'manual',
    },
    activities: {
        type: [activitySchema],
        default: [],
    },
    isActive: {
        type: Boolean,
        default: true,
    },
}, { timestamps: true });

blockedHistorySchema.index({ appName: 1, userId: 1 });
blockedHistorySchema.index({ appName: 1, userId: 1, isActive: 1 });

module.exports = mongoose.model('BlockedHistory', blockedHistorySchema);