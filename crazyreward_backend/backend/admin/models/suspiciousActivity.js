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
    detectedAt: {
        type: Date,
        default: Date.now,
    },
}, { _id: false });

const suspiciousActivitySchema = new mongoose.Schema({
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
    activities: {
        type: [activitySchema],
        default: [],
    },
    lastUpdated: {
        type: Date,
        default: Date.now,
    },
    isBlocked: {
        type: Boolean,
        default: false,
    },
}, { timestamps: true });

suspiciousActivitySchema.index({ appName: 1, userId: 1 }, { unique: true });
suspiciousActivitySchema.index({ appName: 1, lastUpdated: -1 });
suspiciousActivitySchema.index({ appName: 1, isBlocked: 1 });

module.exports = mongoose.model('SuspiciousActivity', suspiciousActivitySchema);