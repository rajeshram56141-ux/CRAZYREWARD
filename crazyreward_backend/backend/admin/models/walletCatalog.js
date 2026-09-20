const mongoose = require('mongoose');

const walletCatalogSchema = new mongoose.Schema({
    appName: { type: String, required: true },
    methodId: { type: String, required: true },
    title: { type: String, required: true },
    enabled: { type: Boolean, default: true },
    autoPayment: { type: Boolean, default: false },
    image: { type: String, default: '' },
    rank: { type: Number, default: 0 },
    symbol: { type: String, default: '₹' },
    country: [{ type: String }],
    ex_country: [{ type: String }],
    validators: [{ type: String }],
    hints: { type: mongoose.Schema.Types.Mixed, default: {} },
    denominations: [{
        denomId: { type: String, required: true },
        amount: { type: Number, required: true },
        coins: { type: Number, required: true },
        enabled: { type: Boolean, default: true },
        subtitle: { type: String, default: '' }
    }]
}, { timestamps: true });

// Compound index for unique app-specific methods
walletCatalogSchema.index({ appName: 1, methodId: 1 }, { unique: true });
walletCatalogSchema.index({ appName: 1, enabled: 1, rank: 1 });

module.exports = mongoose.model('walletCatalog', walletCatalogSchema);
