const mongoose = require('mongoose');

const promotionRequestSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    email: { type: String, required: true },
    promotionType: { type: String, enum: ['app_promotion', 'video_promotion', 'app_development'], required: true },
    title: { type: String, required: true },
    description: { type: String, required: true },
    link: { type: String, default: '' },
    phoneNumber: { type: String, default: '' },
    budget: { type: String, default: '' },
    campaignType: { type: String, default: '' },
    status: { type: String, enum: ['pending', 'active', 'completed', 'rejected'], default: 'pending' },
    adminReply: { type: String, default: '' }
}, { timestamps: true });

module.exports = mongoose.model('PromotionRequest', promotionRequestSchema);
