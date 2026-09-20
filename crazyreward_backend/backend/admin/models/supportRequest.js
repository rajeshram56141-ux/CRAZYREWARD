const mongoose = require('mongoose');

const supportRequestSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    email: { type: String, required: true },
    subject: { type: String, required: true },
    message: { type: String, required: true },
    screenshot: { type: String, default: '' },
    status: { type: String, enum: ['pending', 'in_progress', 'resolved', 'closed'], default: 'pending' },
    adminReply: { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('SupportRequest', supportRequestSchema);
