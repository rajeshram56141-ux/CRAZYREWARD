const User = require('../models/user');
const ReferralSettings = require('../models/referralSettings');

/**
 * Fetch Upline chain up to 3 levels for a given user
 */
async function getUplineChain(userId, maxLevels = 3) {
    const upline = [];
    let currentUid = userId;

    for (let i = 0; i < maxLevels; i++) {
        const user = await User.findOne({ userId: currentUid }).select('referredBy').lean();
        if (!user || !user.referredBy) break;
        
        upline.push(user.referredBy);
        currentUid = user.referredBy;
    }

    return upline;
}

/**
 * Process multi-level referral commission distribution in MongoDB
 */
async function processReferralCommission(userId, coins, type) {
    if (!userId || !coins || coins <= 0) return 0;

    try {
        const user = await User.findOne({ userId }).lean();
        if (!user || !user.referredBy || user.isAnonymous || user.isGuest) return 0;

        // Fetch settings or use defaults
        let settings = await ReferralSettings.findOne().lean();
        if (!settings) {
            settings = { level1Percent: 10, level2Percent: 5, level3Percent: 2 };
        }

        const upline = await getUplineChain(userId, 3);
        if (!upline.length) return 0;

        let totalReferralCoins = 0;
        const levelPercents = [settings.level1Percent, settings.level2Percent, settings.level3Percent];

        for (let i = 0; i < upline.length; i++) {
            const parentUid = upline[i];
            const percent = levelPercents[i] || 0;
            if (percent <= 0) continue;

            const parentUser = await User.findOne({ userId: parentUid }).select('isGuest isBlocked account_deleted').lean();
            if (!parentUser || parentUser.isGuest || parentUser.isBlocked || parentUser.account_deleted) continue;

            const commission = Math.floor((coins * percent) / 100);
            if (commission <= 0) continue;

            totalReferralCoins += commission;

            // Credit referrer wallet atomically in MongoDB
            await User.updateOne(
                { userId: parentUid },
                { 
                    $inc: { coins: commission, totalCoins: commission } 
                }
            );
        }

        return totalReferralCoins;
    } catch (err) {
        console.error('❌ Error processing referral commission in MongoDB:', err);
        return 0;
    }
}

module.exports = {
    getUplineChain,
    processReferralCommission
};
