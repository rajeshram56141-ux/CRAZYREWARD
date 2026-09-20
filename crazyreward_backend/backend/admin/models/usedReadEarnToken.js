const mongoose = require('mongoose');

const usedReadEarnTokenSchema = new mongoose.Schema({
    token: {
        type: String,
        required: true,
        unique: true,
        index: true,
    },
    createdAt: {
        type: Date,
        default: Date.now,
        expires: 600, // Expires after 10 minutes (600 seconds)
    }
});

module.exports = mongoose.model('UsedReadEarnToken', usedReadEarnTokenSchema);
