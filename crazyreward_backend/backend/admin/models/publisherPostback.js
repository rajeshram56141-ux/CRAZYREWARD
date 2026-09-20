const mongoose = require('mongoose');

const publisherPostbackSchema = new mongoose.Schema({
    referCode: { type: String, required: true, unique: true },
    postbackUrl: { type: String, required: true },
    secretKey: { type: String, required: true },
    packageId: { type: String, default: '' },
    assignedTasks: [{ type: String }], // Array of DailyTask offerId
    isActive: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.models.PublisherPostback || mongoose.model('PublisherPostback', publisherPostbackSchema);
