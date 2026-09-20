const mongoose = require('mongoose');

async function connectMongo() {
    if (mongoose.connection.readyState === 1 || mongoose.connection.readyState === 2) {
        return;
    }
    await mongoose.connect(process.env.MONGO_URI);
    try {
        const cacheService = require('../../services/cacheService');
        cacheService.loadConfigFromDb();
    } catch (_) {}
}

module.exports = connectMongo;
