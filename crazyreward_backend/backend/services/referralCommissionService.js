const User = require('../admin/models/user');
const ReferralSettings = require('../admin/models/referralSettings');
const RewardHistory = require('../admin/models/rewardHistory');

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
 * Distribute referral commission when a user earns coins from an ACTUAL coin task
 * Excludes: user bonus, signup coins, admin bonus/adjustment, referral income, and streaks.
 *
 * @param {string} userId - User who earned task coins
 * @param {number} earnedCoins - Actual coins awarded for task
 * @param {string} taskCategory - 'Daily Task' | 'Watch & Earn' | 'Read & Earn' | 'Play Games' | 'Super Offer' | 'Offerwall'
 */
async function distributeTaskReferralCommission(userId, earnedCoins, taskCategory = 'Task') {
    if (!userId || !earnedCoins || earnedCoins <= 0) return 0;

    try {
        const user = await User.findOne({ userId })
            .select('userId referredBy upline isGuest isAnonymous isBlocked account_deleted')
            .lean();

        // 🛡️ Anti-Fraud: Guest / Anonymous users cannot generate referral commission
        if (!user || !user.referredBy || user.isGuest || user.isAnonymous || user.isBlocked || user.account_deleted) {
            return 0;
        }

        const referralSettingsDoc = await ReferralSettings.findOne({ key: 'referralSettings' }).lean();
        const config = referralSettingsDoc?.config || {};
        const rewardMode = config.rewardMode || 'all';

        if (rewardMode === 'all') {
            // 🎯 "ALL" Mode: Direct 1st Level Referrer ONLY
            const directReferrerId = user.referredBy;
            const referrer = await User.findOne({
                $or: [{ userId: directReferrerId }, { referralCode: directReferrerId }],
                isBlocked: { $ne: true },
                account_deleted: { $ne: true },
                isGuest: { $ne: true },
                isAnonymous: { $ne: true }
            }).select('userId isGuest isAnonymous isBlocked account_deleted appName').lean();

            if (!referrer) return 0;

            const percent = Number(config.allCommissionPercent) || 10;
            if (percent <= 0) return 0;

            const commissionCoins = Math.floor((earnedCoins * percent) / 100);
            if (commissionCoins <= 0) return 0;

            await User.updateOne(
                { userId: referrer.userId },
                { $inc: { coins: commissionCoins, totalCoins: commissionCoins } }
            );

            await RewardHistory.create({
                appName: referrer.appName || 'Crazyreward',
                userId: referrer.userId,
                provider: 'Referral Commission',
                coins: commissionCoins,
                rewardType: 'coin',
                orderId: `ref_comm_${Date.now()}_${referrer.userId}`,
                eventId: `${percent}% from ${taskCategory}`,
                timestamp: new Date()
            }).catch(e => console.error('⚠️ RewardHistory commission error:', e.message));

            console.log(`✅ [RefCommission-ALL] Credited ${commissionCoins} coins (${percent}%) to 1st level referrer ${referrer.userId} from ${userId}'s ${taskCategory}`);
            return commissionCoins;
        } else {
            // 🎯 "TASK WISE" Mode: Multi-Level based on category config
            const upline = Array.isArray(user.upline) && user.upline.length > 0
                ? user.upline
                : await getUplineChain(userId, 3);

            if (!upline || !upline.length) return 0;

            const firstLevel = config.firstLevel || {};
            const secondLevel = config.secondLevel || {};
            const thirdLevel = config.thirdLevel || {};

            // Find matching category (case-insensitive)
            const findVal = (obj, cat) => {
                if (!obj || typeof obj !== 'object') return 0;
                if (obj[cat] !== undefined) return Number(obj[cat]) || 0;
                const matchKey = Object.keys(obj).find(k => k.toLowerCase() === cat.toLowerCase());
                return matchKey ? (Number(obj[matchKey]) || 0) : 0;
            };

            const l1Val = findVal(firstLevel, taskCategory);
            const l2Val = findVal(secondLevel, taskCategory);
            const l3Val = findVal(thirdLevel, taskCategory);
            const levelValues = [l1Val, l2Val, l3Val];

            let totalCommission = 0;

            for (let i = 0; i < upline.length && i < 3; i++) {
                const parentId = upline[i];
                const configuredPercent = levelValues[i] || 0;
                if (configuredPercent <= 0) continue;

                const parent = await User.findOne({
                    $or: [{ userId: parentId }, { referralCode: parentId }],
                    isBlocked: { $ne: true },
                    account_deleted: { $ne: true },
                    isGuest: { $ne: true },
                    isAnonymous: { $ne: true }
                }).select('userId isGuest isAnonymous isBlocked account_deleted appName').lean();

                if (!parent) continue;

                const commissionCoins = Math.floor((earnedCoins * configuredPercent) / 100);
                if (commissionCoins <= 0) continue;

                totalCommission += commissionCoins;

                await User.updateOne(
                    { userId: parent.userId },
                    { $inc: { coins: commissionCoins, totalCoins: commissionCoins } }
                );

                await RewardHistory.create({
                    appName: parent.appName || 'Crazyreward',
                    userId: parent.userId,
                    provider: 'Referral Commission',
                    coins: commissionCoins,
                    rewardType: 'coin',
                    orderId: `ref_l${i + 1}_${Date.now()}_${parent.userId}`,
                    eventId: `Level ${i + 1} commission from ${taskCategory}`,
                    timestamp: new Date()
                }).catch(e => console.error('⚠️ RewardHistory commission error:', e.message));
            }

            console.log(`✅ [RefCommission-TaskWise] Credited total ${totalCommission} coins across upline from ${userId}'s ${taskCategory}`);
            return totalCommission;
        }
    } catch (err) {
        console.error('❌ Error distributing task referral commission:', err.message);
        return 0;
    }
}

/**
 * Check and unlock conditional Referrer Bonus when referred user completes a task
 *
 * @param {string} userId - User who just completed task
 * @param {string} taskType - 'super_offer' | 'daily_task' | 'watch_earn' | 'read_earn' | 'play_games' | 'offerwall'
 */
async function checkAndUnlockTaskReferrerBonus(userId, taskType) {
    if (!userId || !taskType) return false;

    try {
        const user = await User.findOne({ userId })
            .select('userId referredBy isGuest isAnonymous referrerBonusClaimed')
            .lean();

        // 🛡️ If user has no referrer, is a guest, or already unlocked bonus, exit
        if (!user || !user.referredBy || user.isGuest || user.isAnonymous || user.referrerBonusClaimed) {
            return false;
        }

        const referralSettingsDoc = await ReferralSettings.findOne({ key: 'referralSettings' }).lean();
        const config = referralSettingsDoc?.config || {};
        const bonusCoins = Number(config.referrerBonusCoins) || 0;
        const condition = config.referrerBonusCondition || 'none';

        if (bonusCoins <= 0 || condition === 'none') {
            return false;
        }

        // Check if condition matches
        const isMatch = (condition === 'any_task') || (condition === taskType);
        if (!isMatch) return false;

        // Verify direct referrer is valid & non-guest
        const directReferrerId = user.referredBy;
        const referrer = await User.findOne({
            $or: [{ userId: directReferrerId }, { referralCode: directReferrerId }],
            isBlocked: { $ne: true },
            account_deleted: { $ne: true },
            isGuest: { $ne: true },
            isAnonymous: { $ne: true }
        }).select('userId isGuest isAnonymous isBlocked account_deleted appName').lean();

        if (!referrer) return false;

        // Atomically award bonus to referrer
        await User.updateOne(
            { userId: referrer.userId },
            { $inc: { coins: bonusCoins, totalCoins: bonusCoins } }
        );

        // Mark user's bonus claimed so it cannot be triggered again
        await User.updateOne(
            { userId: user.userId },
            { $set: { referrerBonusClaimed: true } }
        );

        // Record in RewardHistory for referrer
        await RewardHistory.create({
            appName: referrer.appName || 'Crazyreward',
            userId: referrer.userId,
            provider: 'Referral Bonus',
            coins: bonusCoins,
            rewardType: 'coin',
            orderId: `ref_joinee_${Date.now()}_${referrer.userId}`,
            eventId: `Referred user completed ${taskType}`,
            timestamp: new Date()
        }).catch(e => console.error('⚠️ RewardHistory joinee bonus error:', e.message));

        console.log(`🎉 [ReferrerBonus-Unlocked] Credited ${bonusCoins} bonus coins to referrer ${referrer.userId} because ${user.userId} completed ${taskType}`);
        return true;
    } catch (err) {
        console.error('❌ Error in checkAndUnlockTaskReferrerBonus:', err.message);
        return false;
    }
}

module.exports = {
    getUplineChain,
    distributeTaskReferralCommission,
    checkAndUnlockTaskReferrerBonus
};
