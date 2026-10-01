const mongoose = require('mongoose');

const superOfferContestSchema = new mongoose.Schema({
    contestId: { type: String, required: true, default: () => 'SO_' + Date.now() },
    monthKey: { type: String, required: true }, // e.g. "2026-10"
    title: { type: String, default: "Super Offer Bumper League" },
    subtitle: { type: String, default: "Unlock maximum super offers this month & win iPhone 16 Pro and more!" },
    bannerUrl: { type: String, default: "" },
    startTime: { type: Date, default: Date.now },
    endTime: { type: Date },
    status: { type: String, enum: ['draft', 'active', 'ended', 'completed'], default: 'active' },
    isActive: { type: Boolean, default: true },
    isWinnerDeclared: { type: Boolean, default: false },
    declaredAt: { type: Date },
    prizes: [
        {
            minRank: { type: Number, default: 1 },
            maxRank: { type: Number, default: 1 },
            rankRange: { type: String, required: true }, // "1", "2", "3", "4-10", "11-50"
            title: { type: String, required: true },     // "iPhone 16 Pro"
            subtitle: { type: String, default: "" },
            imageUrl: { type: String, default: "" },
            coinBonus: { type: Number, default: 0 }
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

module.exports = mongoose.models.SuperOfferContest || mongoose.model('SuperOfferContest', superOfferContestSchema);
