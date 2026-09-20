const mongoose = require('mongoose');

const readEarnUrlSchema = new mongoose.Schema({
    url: {
        type: String,
        required: true,
        trim: true,
    },
    payout: {
        type: Number,
        required: true,
        min: 0,
    },
    enabled: {
        type: Boolean,
        default: true,
    },
    trackingTime: {
        type: Number,
        default: 0,
        min: 0,
    },
    verificationEnabled: {
        type: Boolean,
        default: false,
    },
    verificationTitle: {
        type: String,
        default: '',
        trim: true,
    },
    verificationDomain: {
        type: String,
        default: '',
        trim: true,
    }
}, { _id: true });

const readEarnSchema = new mongoose.Schema({
    limits: {
        type: Number,
        required: true,
        min: 1,
    },
    urlsList: {
        type: [readEarnUrlSchema],
        default: [],
    },
    enabled: {
        type: Boolean,
        default: true,
    },
    pendingLimits: {
        type: Number,
        default: null,
        min: 1,
    },
    pendingLimitsApplyAt: {
        type: Date,
        default: null,
    }
}, { timestamps: true });

module.exports = mongoose.model('ReadEarn', readEarnSchema);
