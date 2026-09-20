const mongoose = require('mongoose');

const offersSettingsSchema = new mongoose.Schema({
    key: { type: String, default: 'offersSettings', unique: true },
    config: { type: mongoose.Schema.Types.Mixed, default: {} },
}, { timestamps: true, strict: false });

module.exports = mongoose.model('OffersSettings', offersSettingsSchema);
