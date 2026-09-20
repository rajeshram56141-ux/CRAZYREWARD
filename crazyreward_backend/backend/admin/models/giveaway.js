const mongoose = require('mongoose');

const rewardSubSchema = new mongoose.Schema({
    productName: { type: String, default: '' },
    productImage: { type: String, default: '' },
    productRank: { type: Number, default: 1 },
    coins: { type: Number, default: 0 },
    autoDistribute: { type: Boolean, default: false }
}, { _id: false });

const giveawaySchema = new mongoose.Schema({
    giveawayId: { type: String, required: true, unique: true },
    appName: { type: String, default: '' },
    title: { type: String, required: true },
    description: { type: String, default: '' },
    image: { type: String, default: '' },
    bannerUrl: { type: String, default: '' },
    prizeCoins: { type: Number, default: 100 },
    totalSlots: { type: Number, default: 100 },
    joinedUsers: [{ type: String }],
    participants: [{ type: String }],
    joinedHistory: [{ userId: String, joinedAt: { type: Date, default: Date.now } }],
    priorityUsers: [{ type: String }],
    assignedRanks: [{ userId: String, rank: Number }],
    winners: [{ type: String }],
    winnerRanks: [{ userId: String, rank: Number }],
    winnerStatuses: { type: Map, of: String, default: {} },
    status: { type: String, default: 'active' }, // active, completed, cancelled
    startsAt: { type: Date, default: Date.now },
    declaresAt: { type: Date },
    declaredAt: { type: Date },
    endDate: { type: Date, required: true },
    rewards: [rewardSubSchema],
    createdAt: { type: Date, default: Date.now }
}, { timestamps: true });

giveawaySchema.index({ status: 1, endDate: -1 });

module.exports = mongoose.model('Giveaway', giveawaySchema);
