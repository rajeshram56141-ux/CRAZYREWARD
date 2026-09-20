const mongoose = require('mongoose');

const eventSchema = new mongoose.Schema({
    eventId: {
        type: String,
        required: true,
    },
    name: {
        type: String,
        required: true,
    },
    label: {
        type: String,
        default: '',
    },
    coins: {
        type: Number,
        required: true,
        min: 1,
    },
    payout: {
        type: Number,
        default: 0,
    },
});

const dailyRewardStepSchema = new mongoose.Schema({
    day: {
        type: Number,
        required: true,
    },
    timerDuration: {
        type: Number,
        required: true,
        min: 1,
    },
    coins: {
        type: Number,
        required: true,
        min: 1,
    },
    payout: {
        type: Number,
        default: 0,
    },
});

const dailyTaskSchema = new mongoose.Schema({
    offerId: {
        type: String,
        required: true,
        unique: true,
    },
    imagePath: {
        type: String,
        required: true,
    },
    bannerPath: {
        type: String,
        default: '',
    },
    provider: {
        type: String,
        required: true,
    },
    offerName: {
        type: String,
        required: true,
    },
    offerDescription: {
        type: [String],
        required: true,
        validate: {
            validator: function (val) {
                return Array.isArray(val) && val.length > 0;
            },
            message: 'Offer description must contain at least one item'
        }
    },
    offerDisclaimer: {
        type: [String],
        default: [],
    },
    subDescription: {
        type: String,
        default: '',
    },
    offerType: {
        type: String,
        required: true,
    },
    offerCategory: {
        type: String,
        required: true,
    },
    trackingTime: {
        type: Number,
        default: 0,
    },
    payout: {
        type: Number,
        required: true,
        min: 0,
    },
    redirectionUrl: {
        type: String,
        default: '',
    },
    packageEnabled: {
        type: Boolean,
        default: false,
    },
    packageName: {
        type: String,
        default: '',
    },
    timerEnabled: {
        type: Boolean,
        default: false,
    },
    timerDuration: {
        type: Number,
        default: 0,
    },
    enabled: {
        type: Boolean,
        default: true,
    },
    color: {
        type: String,
        default: '#3F97FF'
    },
    countries: {
        type: [String],
        required: true,
        validate: {
            validator: function (val) {
                return (val.length === 1 && val[0] === 'GLOBAL') || (val.length > 0 && !val.includes('GLOBAL'));
            },
            message: 'Countries must be either ["GLOBAL"] or a list of country codes without GLOBAL',
        }
    },
    dailyCapLimit: {
        type: Number,
        default: null,
        min: 0,
    },
    dailyCapCount: {
        type: Number,
        default: 0,
    },
    lifetimeCapLimit: {
        type: Number,
        default: null,
        min: 0,
    },
    postbackCount: {
        type: Number,
        default: 0,
    },
    // Multi-event support
    events: {
        type: [eventSchema],
        default: [],
    },
    // Daily timer reward progression
    dailyRewardEnabled: {
        type: Boolean,
        default: false,
    },
    dailyRewards: {
        type: [dailyRewardStepSchema],
        default: [],
    },
    // Daily reset toggle - if true, events reset every day
    dailyReset: {
        type: Boolean,
        default: false,
    },
    watchTutorial: {
        type: String,
        default: '',
    },
    videoVerificationEnabled: {
        type: Boolean,
        default: false,
    },
    videoVerificationId: {
        type: String,
        default: '',
    },
    perUserDailyCap: {
        type: Number,
        default: null,
    },
    // Per-task secret key for postback authentication
    secretKey: {
        type: String,
        default: null,
    },
    rating: {
        type: String,
        default: '',
    },
    downloads: {
        type: String,
        default: '',
    },
    screenshotVerificationEnabled: {
        type: Boolean,
        default: false,
    },
}, { timestamps: true });

module.exports = mongoose.model('DailyTask', dailyTaskSchema);
