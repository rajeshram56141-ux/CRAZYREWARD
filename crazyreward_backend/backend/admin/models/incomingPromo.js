const mongoose = require('mongoose');

const eventRewardSchema = new mongoose.Schema({
    eventId: { type: String, required: true },
    coins: { type: Number, required: true }
});

const incomingPromoSchema = new mongoose.Schema({
    trackerCode: { type: String, required: true, unique: true },
    secretKey: { type: String, required: true },
    offerId: { type: String, required: true },
    packageId: { type: String, default: '' },
    events: [eventRewardSchema],
    isActive: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.models.IncomingPromo || mongoose.model('IncomingPromo', incomingPromoSchema);
