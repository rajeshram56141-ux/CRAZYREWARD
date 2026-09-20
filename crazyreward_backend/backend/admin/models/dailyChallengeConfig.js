const mongoose = require('mongoose');

const challengeTaskSchema = new mongoose.Schema({
    taskId: {
        type: String,
        default: () => new mongoose.Types.ObjectId().toString()
    },
    title: {
        type: String,
        required: true,
        trim: true
    },
    description: {
        type: String,
        default: '',
        trim: true
    },
    taskType: {
        type: String,
        required: true,
        enum: [
            'super_offer',
            'offerwall',
            'play_games',
            'read_and_earn',
            'battle_arena',
            'daily_task',
            'watch_earn',
            'watch_video',
            'daily_checkin',
            'diamond_catch',
            'giveaway'
        ],
        trim: true
    },
    targetCount: {
        type: Number,
        default: 1,
        min: 1
    },
    icon: {
        type: String,
        default: 'assets/icons/task.png'
    },
    displayOrder: {
        type: Number,
        default: 0
    },
    isActive: {
        type: Boolean,
        default: true
    }
}, { _id: false });

const dailyChallengeConfigSchema = new mongoose.Schema({
    key: {
        type: String,
        default: 'dailyChallengeConfig',
        unique: true
    },
    isActive: {
        type: Boolean,
        default: true
    },
    rewardCoins: {
        type: Number,
        default: 500,
        min: 1
    },
    tasks: {
        type: [challengeTaskSchema],
        default: [
            {
                taskId: 'task_super_offer',
                title: 'Complete Super Offer',
                description: 'Claim 1 Super Offer today',
                taskType: 'super_offer',
                targetCount: 1,
                icon: 'assets/icons/fire (2).png',
                displayOrder: 1,
                isActive: true
            },
            {
                taskId: 'task_play_games',
                title: 'Play 5 Games',
                description: 'Play 5 HTML5 games today',
                taskType: 'play_games',
                targetCount: 5,
                icon: 'assets/icons/game.png',
                displayOrder: 2,
                isActive: true
            },
            {
                taskId: 'task_read_earn',
                title: 'Read 5 Articles',
                description: 'Read 5 articles in Read & Earn',
                taskType: 'read_and_earn',
                targetCount: 5,
                icon: 'assets/icons/news.png',
                displayOrder: 3,
                isActive: true
            },
            {
                taskId: 'task_battle_arena',
                title: 'Join 1 Battle',
                description: 'Play 1 Battle Arena match',
                taskType: 'battle_arena',
                targetCount: 1,
                icon: 'assets/icons/battle.png',
                displayOrder: 4,
                isActive: true
            },
            {
                taskId: 'task_offerwall',
                title: 'Complete 1 Offerwall',
                description: 'Complete any offerwall task',
                taskType: 'offerwall',
                targetCount: 1,
                icon: 'assets/icons/offerwall.png',
                displayOrder: 5,
                isActive: true
            }
        ]
    }
}, { timestamps: true });

module.exports = mongoose.models.DailyChallengeConfig || mongoose.model('DailyChallengeConfig', dailyChallengeConfigSchema);
