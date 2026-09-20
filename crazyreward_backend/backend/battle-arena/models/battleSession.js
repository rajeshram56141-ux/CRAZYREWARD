const mongoose = require('mongoose');

const waitingPlayerSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    userName: { type: String, default: 'Player' },
    avatar: { type: String, default: '' },
    deviceId: { type: String, default: '' },
    ipAddress: { type: String, default: '' },
    adVerified: { type: Boolean, default: false },
    joinedAt: { type: Date, default: Date.now }
}, { _id: false });

const battleSessionSchema = new mongoose.Schema({
    sessionId: { type: String, required: true, unique: true }, // match_xxx
    roomId: { type: String, required: true },
    roomTitle: { type: String, required: true },
    startTime: { type: Date, required: true },
    endTime: { type: Date, required: true }, // When countdown ends
    waitingPlayers: [waitingPlayerSchema],
    matchesCreated: [{ type: String }], // Array of standard BattleMatch matchIds (sub-matches)
    status: { type: String, enum: ['WAITING', 'ACTIVE', 'COMPLETED', 'CANCELLED'], default: 'WAITING' }
}, { timestamps: true });

module.exports = mongoose.model('BattleSession', battleSessionSchema);
