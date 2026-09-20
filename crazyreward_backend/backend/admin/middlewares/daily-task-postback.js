const connectMongo = require('./connectMongo');
const DailyTask = require('../models/dailyTask');
const FirebaseService = require('../models/firebaseService');
const PostbackLog = require('../models/postbackLogs');
const axios = require('axios');

// Helper to get start of today in IST (Timezone-safe for UTC servers)
function getTodayStartIST() {
    const now = new Date();
    const istDateStr = now.toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' });
    return new Date(`${istDateStr}T00:00:00+05:30`);
}

// Helper to calculate multi-event task completion state and cycles
function getMultiEventStatus(logs, events, todayStart) {
    const eventIds = events.map(e => e.eventId);
    const eventSet = new Set(eventIds);

    // Sort logs ascending by completedAt (first to last)
    const sortedLogs = [...logs]
        .filter(log => eventSet.has(log.eventId))
        .sort((a, b) => new Date(a.completedAt) - new Date(b.completedAt));

    let currentSet = new Set();
    let cycleCompletedAt = null;

    for (const log of sortedLogs) {
        currentSet.add(log.eventId);
        if (currentSet.size === eventIds.length) {
            cycleCompletedAt = log.completedAt;
            currentSet.clear();
        }
    }

    const activeCompletions = cycleCompletedAt 
        ? sortedLogs.filter(log => new Date(log.completedAt) > new Date(cycleCompletedAt))
        : sortedLogs;

    const completedInActiveCycle = new Set(activeCompletions.map(log => log.eventId));
    
    let isFullyCompletedToday = false;
    if (cycleCompletedAt) {
        const cycleDate = new Date(cycleCompletedAt);
        if (cycleDate >= todayStart) {
            isFullyCompletedToday = true;
        }
    }

    return {
        completedInActiveCycle,
        isFullyCompletedToday,
    };
}

const activeRequests = new Set();

async function handleDailyTaskPostback({
    appName,
    userId,
    offerId,
    query,
    res,
    userEmail,
    userGaid,
    eventId = '',
}) {
    const lockKey = `${userId}:${offerId}:${eventId || '__single__'}`;
    if (activeRequests.has(lockKey)) {
        return res.status(429).json({
            success: false,
            message: 'Request already in progress',
        });
    }
    activeRequests.add(lockKey);

    try {
        await connectMongo();

        const offerDoc = await DailyTask.findOne({ offerId });
        if (!offerDoc) {
            return res.status(404).json({
                success: false,
                message: 'Offer not found',
            });
        }

        if (offerDoc.enabled === false) {
            return res.status(400).json({
                success: false,
                message: 'Offer not active',
            });
        }

        // 🎬 If this is a Watch & Earn offer, route completely to dedicated Watch & Earn engine!
        if (offerDoc.offerType === 'WatchEarn') {
            const { handleWatchEarnPostback } = require('./watch-earn-postback');
            return handleWatchEarnPostback({
                appName,
                userId,
                offerId,
                userEmail,
                userGaid,
                query,
                res
            });
        }

        const todayStart = getTodayStartIST();
        const dailyReset = offerDoc.enabled ? (offerDoc.dailyReset || false) : false;

        // 🛡️ GAID Multi-Accounting check (same device, different user ID)
        if (userGaid && userGaid.trim() !== '') {
            const gaidQuery = {
                appName,
                offerId,
                userGaid: userGaid.trim(),
                userId: { $ne: userId }
            };
            if (eventId) {
                gaidQuery.eventId = eventId;
            }
            const existingGaidLog = await PostbackLog.findOne(gaidQuery).sort({ completedAt: -1 });
            if (existingGaidLog) {
                if (dailyReset) {
                    const completedAt = new Date(existingGaidLog.completedAt);
                    if (completedAt >= todayStart) {
                        return res.status(400).json({
                            success: false,
                            message: 'Device already completed this offer today',
                        });
                    }
                } else {
                    return res.status(400).json({
                        success: false,
                        message: 'Device already completed this offer',
                    });
                }
            }
        }

        const firebaseService = await FirebaseService.findOne({ appName });
        if (!firebaseService?.serviceAccount?.project_id) {
            return res.status(404).json({
                success: false,
                message: 'Invalid App',
            });
        }

        // Get event-specific coins directly (no conversion)
        let coins = Number(offerDoc.coins || offerDoc.payout || 0);
        let payout = offerDoc.payout || coins;

        let isDailyRewardEvent = eventId && eventId.startsWith('day_') && offerDoc.dailyRewardEnabled;
        let dailyStep = null;

        if (isDailyRewardEvent) {
            const dayNum = parseInt(eventId.split('_')[1]);
            dailyStep = (offerDoc.dailyRewards || []).find(r => r.day === dayNum);
            if (!dailyStep) {
                return res.status(404).json({
                    success: false,
                    message: 'Daily step event not found',
                });
            }
            payout = dailyStep.payout || dailyStep.coins;
            coins = Number(dailyStep.coins || dailyStep.payout || coins);
        } else if (eventId && offerDoc.events && offerDoc.events.length > 0) {
            // Multi-event task - find specific event
            const event = offerDoc.events.find(e => e.eventId === eventId);
            if (!event) {
                return res.status(404).json({
                    success: false,
                    message: 'Event not found',
                });
            }
            payout = event.payout || event.coins;
            coins = Number(event.coins || event.payout || coins);
        }

        // 🛡️ Daily Reward same-day lock check
        if (isDailyRewardEvent) {
            const lastDailyLog = await PostbackLog.findOne({
                appName,
                userId,
                offerId,
                eventId: { $regex: /^day_/ }
            }).sort({ completedAt: -1 });

            if (lastDailyLog) {
                const lastCompletedAt = new Date(lastDailyLog.completedAt);
                const offset = 5.5 * 60 * 60 * 1000;
                const lastCompletedIST = new Date(lastCompletedAt.getTime() + (lastCompletedAt.getTimezoneOffset() * 60000) + offset);
                lastCompletedIST.setHours(0, 0, 0, 0);
                
                if (lastCompletedIST.getTime() === todayStart.getTime()) {
                    return res.status(200).json({
                        success: false,
                        message: 'Only one daily task completion allowed per day. Come back tomorrow!',
                    });
                }
            }
        }

        // 🛡️ Check if already claimed (considering daily reset)
        if (offerDoc.events && offerDoc.events.length > 0) {
            // Multi-event task logic
            const allLogs = await PostbackLog.find({
                appName,
                userId,
                offerId,
            }).lean();

            const { completedInActiveCycle, isFullyCompletedToday } = getMultiEventStatus(allLogs, offerDoc.events, todayStart);

            if (eventId) {
                const canonicalEvent = offerDoc.events.find(e => e.eventId.toLowerCase() === eventId.toLowerCase());
                const checkEventId = canonicalEvent ? canonicalEvent.eventId : eventId;

                if (dailyReset) {
                    if (isFullyCompletedToday) {
                        return res.status(200).json({
                            success: false,
                            message: 'Event already completed today',
                        });
                    }
                    if (completedInActiveCycle.has(checkEventId)) {
                        return res.status(200).json({
                            success: false,
                            message: 'All Events not completed',
                        });
                    }
                } else {
                    // Daily reset OFF
                    const hasEverCompleted = allLogs.some(log => log.eventId === checkEventId);
                    if (hasEverCompleted) {
                        return res.status(200).json({
                            success: true,
                            message: 'Offer Already completed',
                        });
                    }
                }
            }
        } else {
            // Single-event daily task
            const existingQuery = {
                appName,
                userId,
                offerId,
            };

            if (eventId) {
                existingQuery.eventId = eventId;
            }

            const existingCompletion = await PostbackLog.findOne(existingQuery).sort({ completedAt: -1 });

            if (existingCompletion) {
                if (dailyReset) {
                    // Daily reset ON: check if completed today
                    const completedAt = new Date(existingCompletion.completedAt);
                    if (completedAt >= todayStart) {
                        return res.status(200).json({
                            success: false,
                            message: 'Event already completed today',
                        });
                    }
                    // Completed before today - allow again
                } else {
                    // Daily reset OFF: permanently blocked
                    return res.status(200).json({
                        success: false,
                        message: 'Offer Already completed',
                    });
                }
            }
        }

        // 🛡️ Package Verification Check (Only for Daily Reward events)
        if (isDailyRewardEvent && offerDoc.packageEnabled && offerDoc.packageName) {
            const packageNameFromQuery = query.packageName || '';
            if (packageNameFromQuery !== offerDoc.packageName) {
                return res.status(400).json({
                    success: false,
                    message: 'Package verification failed',
                });
            }
        }

        // 🛡️ Timer Verification Check (Only for Daily Reward events)
        if (isDailyRewardEvent && offerDoc.timerEnabled) {
            const requiredDuration = dailyStep ? dailyStep.timerDuration : 0;
            if (requiredDuration > 0) {
                const elapsedSeconds = Number(query.elapsedSeconds) || 0;
                if (elapsedSeconds < requiredDuration) {
                    return res.status(400).json({
                        success: false,
                        message: `Timer not complete. Required: ${requiredDuration}s, Elapsed: ${elapsedSeconds}s`,
                    });
                }
            }
        }

        // 🔥 Process postback & write completion logs before sending success response
        await processPostback({
            firebaseService,
            offerDoc,
            appName,
            userId,
            offerId,
            query,
            userEmail,
            userGaid,
            eventId,
            payout,
            coins,
        }).catch(err =>
            console.error('Postback processing error:', err)
        );

        // Clear tasks cache so updated caps and completions are immediately reflected
        try {
            const cacheService = require('../../services/cacheService');
            await cacheService.delPattern('tasks:watchearn:*');
            await cacheService.delPattern('tasks:daily:*');
        } catch (_) {}

        // ⚡ SUCCESS AFTER PROCESSING & LOGGING
        return res.status(200).json({
            success: true,
            message: 'Postback accepted',
            coins: coins,
        });

    } catch (err) {
        console.error(`🔥 Error in postback: ${err.message}`);
        return res.status(500).json({
            success: false,
            message: 'Internal Server Error',
        });
    } finally {
        activeRequests.delete(lockKey);
    }
}

async function processPostback({
    firebaseService,
    offerDoc,
    appName,
    userId,
    offerId,
    query,
    userEmail,
    userGaid,
    eventId,
    payout,
    coins,
}) {
    const startTime = process.hrtime.bigint();
    const transactionId = Date.now() + '-' + Math.floor(Math.random() * 1000);

    const User = require('../models/user');
    const RewardHistory = require('../models/rewardHistory');

    // 1. Credit User Wallet in MongoDB
    let statusCode = 200;
    try {
        const user = await User.findOneAndUpdate(
            {
                userId,
                account_deleted: { $ne: true },
                blocked: { $ne: true },
                isBlocked: { $ne: true },
                isGuest: { $ne: true },
                isAnonymous: { $ne: true }
            },
            {
                $inc: { coins: coins, totalCoins: coins },
                $set: { lastActiveAt: new Date() }
            },
            { new: true }
        );
        if (user) {

            await RewardHistory.create({
                appName: user.appName || appName,
                userId: userId,
                provider: offerDoc?.provider || 'Daily Task',
                coins: coins,
                rewardType: 'coin',
                orderId: `daily_task_${transactionId}`,
                transId: transactionId,
                timestamp: new Date()
            }).catch(err => console.error("⚠️ RewardHistory create warning:", err.message));

            // 🔔 Send OneSignal push notification to user
            try {
                const sendNotificationViaApi = require('./send-notification-api');
                sendNotificationViaApi({
                    title: 'Task Completed! 🎉',
                    body: `You received +${coins} coins for completing ${offerDoc?.offerName || 'Daily Task'}!`,
                    userId: userId,
                }).catch(e => console.warn('⚠️ OneSignal daily task push error:', e?.message || e));
            } catch (pushErr) {
                console.warn('⚠️ OneSignal import warning:', pushErr?.message || pushErr);
            }

            // Track Daily Challenge progress for daily_task / offerwall
            try {
                const { trackDailyChallengeProgress } = require('../../routes/modules/dailyChallengeApiRoutes');
                trackDailyChallengeProgress(userId, 'daily_task', 1);
                trackDailyChallengeProgress(userId, 'offerwall', 1);
            } catch (_) {}

            // 🤝 Referral Commission & Joinee Bonus Trigger
            try {
                const { distributeTaskReferralCommission, checkAndUnlockTaskReferrerBonus } = require('../../services/referralCommissionService');
                checkAndUnlockTaskReferrerBonus(userId, 'daily_task').catch(e => console.error("⚠️ [DailyTask] Ref bonus error:", e.message));
                distributeTaskReferralCommission(userId, coins, offerDoc?.provider || 'Daily Tasks').catch(e => console.error("⚠️ [DailyTask] Ref comm error:", e.message));
            } catch (refErr) {
                console.error("⚠️ [DailyTask] Referral processing error:", refErr.message);
            }

            // 🌐 S2S Outgoing Postback Trigger (Case 2)
            if (user.publisherRef && user.publisherUid) {
                try {
                    const triggerOutgoingPostback = require('../../services/publisherPostbackService');
                    triggerOutgoingPostback({
                        user,
                        offerId,
                        coins,
                        eventId
                    }).catch(err => console.error("⚠️ S2S Outgoing Postback runner error:", err.message));

                    // Trigger the generic 'daily_task_complete' postback
                    triggerOutgoingPostback({
                        user,
                        offerId: 'daily_task_complete',
                        coins,
                        eventId
                    }).catch(() => {});
                } catch (loadErr) {
                    console.error("⚠️ Failed to load publisherPostbackService:", loadErr.message);
                }
            }
        }

        // 2. Increment Task postback counter
        await DailyTask.updateOne(
            { offerId },
            {
                $inc: {
                    postbackCount: 1,
                    dailyCapCount: 1,
                },
            }
        ).catch(err => console.error("⚠️ DailyTask update warning:", err.message));

    } catch (err) {
        statusCode = 500;
        console.error(`❌ Postback processing error: ${err.message}`);
    }

    const endTime = process.hrtime.bigint();
    const durationMs = Number(endTime - startTime) / 1e6;

    // 3. Log to PostbackLog
    try {
        await PostbackLog.create({
            appName,
            userId,
            txnId: transactionId,
            offerId,
            eventId: eventId || '',
            payout: coins,
            responseStatus: statusCode,
            userEmail: userEmail || '',
            userGaid: userGaid || '',
            payload: query,
            processingTime: durationMs,
            completedAt: new Date(),
        });
    } catch (logErr) {
        console.error('❌ Log Error:', logErr.message);
    }
}

module.exports = { handleDailyTaskPostback };