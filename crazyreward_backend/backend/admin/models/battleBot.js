const mongoose = require('mongoose');

const battleBotSchema = new mongoose.Schema({
    name: { type: String, required: true },
    avatar: { type: String, default: '' },
    isActive: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.model('BattleBot', battleBotSchema);
