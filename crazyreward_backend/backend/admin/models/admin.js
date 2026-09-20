const mongoose = require('mongoose');

const adminSchema = new mongoose.Schema({
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    name: { type: String, required: true },
    role: { type: String, enum: ['superadmin', 'admin'], default: 'admin' },
    permissions: {
        type: mongoose.Schema.Types.Mixed,
        default: {}
    },
    lastLogin: { type: Date, default: Date.now },
    createdAt: { type: Date, default: Date.now },
}, { strict: false });

module.exports = mongoose.model('Admin', adminSchema);

