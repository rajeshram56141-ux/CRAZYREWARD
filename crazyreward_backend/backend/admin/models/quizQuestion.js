const mongoose = require('mongoose');

const quizQuestionSchema = new mongoose.Schema({
    questionId: { type: String, required: true, unique: true },
    gameTitle: { type: String, default: 'General Quiz Clash' },
    category: { type: String, default: 'General Knowledge' },
    question: { type: String, required: true },
    options: { type: [String], required: true }, // Array of 4 option strings
    correctIndex: { type: Number, required: true }, // 0 to 3 index (SECRET ON SERVER ONLY)
    timeLimitSec: { type: Number, default: 20 },
    active: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.models.QuizQuestion || mongoose.model('QuizQuestion', quizQuestionSchema);
