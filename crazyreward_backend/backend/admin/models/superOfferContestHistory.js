const mongoose = require('mongoose');

const superOfferContestHistorySchema = new mongoose.Schema({
    monthKey: { type: String, required: true },
    title: { type: String, required: true },
    subtitle: { type: String, default: "" },
    bannerUrl: { type: String, default: "" },
    startTime: { type: Date },
    endTime: { type: Date },
    declaredAt: { type: Date, default: Date.now },
    declaredBy: { type: String, default: "Admin" },
    totalWinnersCount: { type: Number, default: 0 },
    totalCoinsAwarded: { type: Number, default: 0 },
    prizes: [
        {
            minRank: { type: Number },
            maxRank: { type: Number },
            rankRange: { type: String },
            title: { type: String },
            subtitle: { type: String },
            imageUrl: { type: String },
            coinBonus: { type: Number }
        }
    ],
    winners: [
        {
            userId: { type: String },
            userName: { type: String },
            avatar: { type: String },
            rank: { type: Number },
            unlockCount: { type: Number },
            prizeTitle: { type: String },
            prizeImageUrl: { type: String },
            coinBonusAwarded: { type: Number, default: 0 }
        }
    ]
}, { timestamps: true });

module.exports = mongoose.models.SuperOfferContestHistory || mongoose.model('SuperOfferContestHistory', superOfferContestHistorySchema);
