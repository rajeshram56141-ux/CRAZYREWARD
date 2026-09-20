const mongoose = require('mongoose');

const pendingReadEarnTokenSchema = new mongoose.Schema({
    userId: {
        type: String,
        required: true,
        index: true,
    },
    offerId: {
        type: String,
        required: true,
        index: true,
    },
    token: {
        type: String,
        required: true,
        unique: true,
    },
    createdAt: {
        type: Date,
        default: Date.now,
        expires: 600, // Expires after 10 minutes (600 seconds)
    }
});

module.exports = mongoose.model('PendingReadEarnToken', pendingReadEarnTokenSchema);
