const mongoose = require('mongoose');

const appDataSchema = new mongoose.Schema({
    key: { type: String, default: 'appData', unique: true },
    config: { type: mongoose.Schema.Types.Mixed, default: {} },
}, { timestamps: true, strict: false });

module.exports = mongoose.model('AppData', appDataSchema);
