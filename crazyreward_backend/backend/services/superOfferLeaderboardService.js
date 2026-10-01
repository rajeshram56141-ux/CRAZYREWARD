const SuperOfferLeaderboard = require('../admin/models/superOfferLeaderboard');
const SuperOfferContest = require('../admin/models/superOfferContest');
const User = require('../admin/models/user');

function getMonthKey(date = new Date()) {
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    return `${year}-${month}`;
}

function getDefaultPrizes() {
    return [
        {
            minRank: 1,
            maxRank: 1,
            rankRange: "1",
            title: "iPhone 16 Pro",
            subtitle: "128GB Storage - Brand New",
            imageUrl: "https://zodplay.in/image-tool/uploads/2026/10/Screenshot-2026-10-01-114548-20261001-062010-b67c1809.png",
            coinBonus: 0
        },
        {
            minRank: 2,
            maxRank: 2,
            rankRange: "2",
            title: "Smart Watch",
            subtitle: "Bluetooth Calling & AMOLED Display",
            imageUrl: "https://zodplay.in/image-tool/uploads/2026/10/Screenshot-2026-10-01-114254-20261001-061902-bb9d841e.png",
            coinBonus: 0
        },
        {
            minRank: 3,
            maxRank: 3,
            rankRange: "3",
            title: "Wireless Earbuds",
            subtitle: "Active Noise Cancellation",
            imageUrl: "https://zodplay.in/image-tool/uploads/2026/10/Screenshot-2026-10-01-123959-20261001-075856-c7406f57.png",
            coinBonus: 0
        },
        {
            minRank: 4,
            maxRank: 12,
            rankRange: "4-12",
            title: "5,000 Wallet Coins",
            subtitle: "Instant Wallet Credit",
            imageUrl: "https://zodplay.in/image-tool/uploads/2026/10/super-offer-coin-20261001-080429-6da1485c.png",
            coinBonus: 5000
        }
    ];
}

async function getOrCreateActiveContest(requestedKey) {
    let contest = null;
    if (requestedKey) {
        contest = await SuperOfferContest.findOne({
            $or: [{ contestId: requestedKey }, { _id: requestedKey.match(/^[0-9a-fA-F]{24}$/) ? requestedKey : null }, { monthKey: requestedKey }]
        }).sort({ createdAt: -1 });
    }
    
    if (!contest) {
        contest = await SuperOfferContest.findOne({ status: 'active' }).sort({ createdAt: -1 });
    }

    if (!contest) {
        const now = new Date();
        const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
        const contestId = 'SO_' + Date.now();
        const monthKey = getMonthKey();
        contest = await SuperOfferContest.create({
            contestId,
            monthKey,
            title: "Super Offer Bumper League",
            subtitle: "Unlock maximum super offers & win iPhone 16 Pro and more!",
            bannerUrl: "",
            startTime: now,
            endTime: endOfMonth,
            status: "active",
            isActive: true,
            prizes: getDefaultPrizes()
        });
    }

    if (!contest.contestId) {
        contest.contestId = 'SO_' + (contest._id ? contest._id.toString() : Date.now());
        await contest.save().catch(() => {});
    }

    return contest;
}

async function recordSuperOfferUnlock(userId) {
    if (!userId) return null;
    const cleanUserId = String(userId).trim();
    const contest = await getOrCreateActiveContest();
    const targetKey = contest.contestId || contest.monthKey;

    // Fetch user details for caching in leaderboard
    let userDoc = await User.findOne({
        $or: [
            { userId: cleanUserId },
            { email: cleanUserId },
            { gmail: cleanUserId },
            { firebaseUid: cleanUserId }
        ]
    }).lean();

    const userName = userDoc?.name || userDoc?.userName || 'User';
    const avatar = userDoc?.avatar || userDoc?.profileImage || '';

    const updatedDoc = await SuperOfferLeaderboard.findOneAndUpdate(
        { monthKey: targetKey, userId: cleanUserId },
        {
            $inc: { unlockCount: 1 },
            $set: {
                userName,
                avatar,
                lastUnlockedAt: new Date()
            }
        },
        { upsert: true, new: true }
    );

    return updatedDoc;
}

async function getLeaderboardData(requestedKey, currentUserId) {
    const contest = await getOrCreateActiveContest(requestedKey);
    const targetKey = contest.contestId || contest.monthKey;

    // Fetch top 100 non-disqualified users
    const topUsers = await SuperOfferLeaderboard.find({
        monthKey: targetKey,
        isDisqualified: false
    })
    .sort({ unlockCount: -1, lastUnlockedAt: 1 })
    .limit(100)
    .lean();

    // Map ranks
    let leaderboard = topUsers.map((item, index) => ({
        rank: index + 1,
        userId: item.userId,
        userName: item.userName || 'User',
        avatar: item.avatar || '',
        unlockCount: item.unlockCount,
        lastUnlockedAt: item.lastUnlockedAt
    }));

    // Current User Stats
    let userStats = {
        rank: 0,
        unlockCount: 0,
        isInTop3: false,
        isInTop10: false
    };

    if (currentUserId) {
        const cleanUserId = String(currentUserId).trim();
        const userRecord = await SuperOfferLeaderboard.findOne({
            monthKey: targetKey,
            userId: cleanUserId
        }).lean();

        if (userRecord && !userRecord.isDisqualified) {
            // Find rank among all users
            const higherCount = await SuperOfferLeaderboard.countDocuments({
                monthKey: targetKey,
                isDisqualified: false,
                $or: [
                    { unlockCount: { $gt: userRecord.unlockCount } },
                    { unlockCount: userRecord.unlockCount, lastUnlockedAt: { $lt: userRecord.lastUnlockedAt } }
                ]
            });
            userStats.rank = higherCount + 1;
            userStats.unlockCount = userRecord.unlockCount;
            userStats.isInTop3 = userStats.rank <= 3;
            userStats.isInTop10 = userStats.rank <= 10;
        }
    }

    // Compute time remaining based on custom endTime or end of month
    const now = new Date();
    const endTimeTarget = contest.endTime ? new Date(contest.endTime) : new Date(now.getFullYear(), now.getMonth() + 1, 1, 0, 0, 0, 0);
    const timeRemainingSeconds = Math.max(0, Math.floor((endTimeTarget.getTime() - now.getTime()) / 1000));

    return {
        success: true,
        monthKey: targetKey,
        contestId: contest.contestId,
        contest: {
            contestId: contest.contestId,
            title: contest.title,
            subtitle: contest.subtitle,
            bannerUrl: contest.bannerUrl,
            status: contest.status,
            isActive: contest.isActive !== false,
            startTime: contest.startTime,
            endTime: contest.endTime,
            isWinnerDeclared: contest.isWinnerDeclared || false,
            declaredAt: contest.declaredAt || null,
            prizes: contest.prizes,
            winners: contest.winners || []
        },
        timeRemainingSeconds,
        userStats,
        leaderboard
    };
}

const SuperOfferContestHistory = require('../admin/models/superOfferContestHistory');

async function getPastWinnersData() {
    let pastHistories = await SuperOfferContestHistory.find()
        .sort({ declaredAt: -1 })
        .limit(20)
        .lean();

    if (!pastHistories || pastHistories.length === 0) {
        pastHistories = await SuperOfferContest.find({
            isWinnerDeclared: true,
            'winners.0': { $exists: true }
        })
        .sort({ declaredAt: -1 })
        .limit(20)
        .lean();
    }

    return {
        success: true,
        pastContests: pastHistories
    };
}

module.exports = {
    getMonthKey,
    getOrCreateActiveContest,
    recordSuperOfferUnlock,
    getLeaderboardData,
    getPastWinnersData
};
