const mongoose = require('mongoose');

const developerApiKeySchema = new mongoose.Schema({
    name: { type: String, required: true },
    apiKey: { type: String, required: true, unique: true },
    scopes: [{ 
        type: String 
    }],
    isActive: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.models.DeveloperApiKey || mongoose.model('DeveloperApiKey', developerApiKeySchema);
