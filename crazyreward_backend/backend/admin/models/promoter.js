const mongoose = require('mongoose');

const promoterSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    app: { type: String, required: true },
    channelName: { type: String, default: '' },
    priceInInr: { type: Number, default: 0 },
    videoLink: { type: String, default: '' },
    promoDate: { type: Date, required: true, default: Date.now }
}, { timestamps: true });

module.exports = mongoose.model('Promoter', promoterSchema);
