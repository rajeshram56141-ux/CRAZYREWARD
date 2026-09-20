const mongoose = require('mongoose');

const screenshotProofSchema = new mongoose.Schema({
    userId: {
        type: String,
        required: true,
        index: true,
    },
    userEmail: {
        type: String,
        default: '',
    },
    appName: {
        type: String,
        required: true,
        index: true,
    },
    offerId: {
        type: String,
        required: true,
        index: true,
    },
    offerName: {
        type: String,
        default: '',
    },
    eventId: {
        type: String,
        default: '',
    },
    eventName: {
        type: String,
        default: '',
    },
    coins: {
        type: Number,
        default: 0,
    },
    imageUrl: {
        type: String,
        required: true,
    },
    status: {
        type: String,
        enum: ['pending', 'approved', 'rejected', 'rejected_final', 'uninstalled', 'removed'],
        default: 'pending',
        index: true,
    },
    rejectionReason: {
        type: String,
        default: '',
    },
    reviewedAt: {
        type: Date,
        default: null,
    },
    reviewedBy: {
        type: String,
        default: null,
    },
}, { timestamps: true });

module.exports = mongoose.model('ScreenshotProof', screenshotProofSchema);
