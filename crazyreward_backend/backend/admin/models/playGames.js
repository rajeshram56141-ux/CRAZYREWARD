const mongoose = require('mongoose');

const playGamesSchema = new mongoose.Schema({
    imagePath: {
        type: String,
        required: true,
    },
    offerName: {
        type: String,
        required: true,
    },
    category: {
        type: String,
        required: true,
        trim: true,
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
        required: true,
        unique: true,
    },
    enabled: {
        type: Boolean,
        default: true,
    },
    maxPlaysPerUser: {
        type: Number,
        default: -1, // -1 = unlimited
    },
    dailyEnabled: {
        type: Boolean,
        default: false, // OFF by default
    },
    maxPlaysPerDay: {
        type: Number,
        default: 1,
    },
}, { timestamps: true });

module.exports = mongoose.model('PlayGames', playGamesSchema);
