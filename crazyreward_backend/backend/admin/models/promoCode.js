const mongoose = require('mongoose');

const promoCodeSchema = new mongoose.Schema({
    appName: { type: String, required: true, default: '' },
    code: { type: String, required: true, index: true },
    reward: { type: Number, required: true, default: 0 },
    maxRedemptions: { type: Number, required: true, default: 0 },
    redeemedCount: { type: Number, default: 0 },
    active: { type: Boolean, default: true },
    createdAt: { type: Date, default: Date.now }
}, { timestamps: true });

promoCodeSchema.index({ appName: 1, code: 1 }, { unique: true });

module.exports = mongoose.models.PromoCode || mongoose.model('PromoCode', promoCodeSchema);
