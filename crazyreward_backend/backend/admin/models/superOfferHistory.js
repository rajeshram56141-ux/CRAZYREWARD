const mongoose = require('mongoose');

const superOfferHistorySchema = new mongoose.Schema({
    userId: {
        type: String,
        required: true,
        index: true,
    },
    userEmail: {
        type: String,
        default: '',
    },
    packageName: {
        type: String,
        required: true,
        index: true,
    },
    appName: {
        type: String,
        required: true,
    },
    stepNumber: {
        type: Number,
        default: 1,
    },
    stepName: {
        type: String,
        default: 'Install App',
    },
    stepType: {
        type: String,
        enum: ['install', 'screenshot', 'usage', 'removed', 'skipped', 'uninstalled'],
        default: 'install',
    },
    status: {
        type: String,
        enum: ['started', 'in_progress', 'pending', 'pending_proof', 'approved', 'rejected', 'completed', 'skipped', 'removed', 'uninstalled'],
        default: 'completed',
        index: true,
    },
    coins: {
        type: Number,
        default: 0,
    },
    usageMinutes: {
        type: Number,
        default: 0,
    },
    proofImageUrl: {
        type: String,
        default: '',
    },
    rejectionReason: {
        type: String,
        default: '',
    },
    installedAt: {
        type: Date,
        default: null,
    },
    completedAt: {
        type: Date,
        default: null,
    },
    removedAt: {
        type: Date,
        default: null,
    },
    reviewedAt: {
        type: Date,
        default: null,
    },
    reviewedBy: {
        type: String,
        default: null,
    },
    isVerificationEnabled: {
        type: Boolean,
        default: false,
    },
    configSnapshot: {
        type: mongoose.Schema.Types.Mixed,
        default: null,
    },
    stepsStatus: {
        type: mongoose.Schema.Types.Mixed,
        default: null,
    },
    createdAt: {
        type: Date,
        default: Date.now,
        index: true,
    },
    updatedAt: {
        type: Date,
        default: Date.now,
    },
});

superOfferHistorySchema.pre('save', function () {
    this.updatedAt = new Date();
});

module.exports =
    mongoose.models.SuperOfferHistory ||
    mongoose.model('SuperOfferHistory', superOfferHistorySchema);
