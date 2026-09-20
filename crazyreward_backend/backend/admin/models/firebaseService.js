const mongoose = require('mongoose');

const firebaseServiceSchema = new mongoose.Schema({
    serviceAccount: { type: Object, required: true },
    appName: { type: String, required: true, unique: true },
    displayName: { type: String, required: true, },
}, { timestamps: true });

module.exports = mongoose.model('FirebaseService', firebaseServiceSchema);