const DailyTask = require('../models/dailyTask');

/** ✅ 1. Refresh Daily Task */
const refreshDailyTask = async () => {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const offers = await DailyTask.find({});

    for (const offer of offers) {
        let updated = false;

        // Reset daily cap count
        if (offer.dailyCapCount !== 0) {
            offer.dailyCapCount = 0;
            updated = true;
        }

        // Lifetime cap limit check
        if (
            offer.lifetimeCapLimit !== null &&
            offer.postbackCount >= offer.lifetimeCapLimit
        ) {
            offer.enabled = false;
            updated = true;
        }

        if (updated) {
            await offer.save();
        }
    }

    console.log(`🔥 Daily Task refreshed: ${offers.length} checked`);
};

module.exports = { refreshDailyTask };