const cron = require('node-cron');
const axios = require('axios');
const connectMongo = require('../middlewares/connectMongo');
const CronState = require('../models/cronState');

// Curated unique notifications based on actual app tasks (Diamond Catch, Play Games, Super Offer, Daily Target, Invite, etc.)
const notifications = [
    // === MORNING SLOTS ===
    {
        "category": "morning",
        "title": "Morning check-in time! 🌅",
        "body": "Utho aur aaj ka first login reward claim karo. Free coins are waiting!",
        "buttons": [
            { "id": "check_in", "text": "Claim Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Daily Check-in Active! 🎁",
        "body": "Tap to collect your daily check-in coins and start your earning streak.",
        "buttons": [
            { "id": "check_in", "text": "Check-in" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Morning Diamond Catch! 🎮",
        "body": "Play Diamond Catch game and earn gems!",
        "buttons": [
            { "id": "play_game", "text": "Catch Gems" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Morning Fruit Catch is Live! 🍎",
        "body": "Play Fruit Catch now to score high and earn quick coins.",
        "buttons": [
            { "id": "play_game", "text": "Play Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Watch & Earn Morning! 📺",
        "body": "Watch a quick video tutorial and claim 50+ coins instantly.",
        "buttons": [
            { "id": "watch_video", "text": "Watch Video" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Start your Daily Target! 🎯",
        "body": "Check today's milestone tasks. Complete them to get extra bonus coins!",
        "buttons": [
            { "id": "do_task", "text": "Check Target" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Morning Super Offer active! ⚡",
        "body": "Download recommended apps from Super Offer and earn high rewards.",
        "buttons": [
            { "id": "super_offer", "text": "Get Coins" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Quiz Battle Arena Active! ⚔️",
        "body": "Play 1v1 Quiz Battles this morning and claim bonus coin rewards!",
        "buttons": [
            { "id": "battle_arena", "text": "Battle Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Play Games & Earn! 🎮",
        "body": "Start your day with fun games. Earn coins for every minute you play.",
        "buttons": [
            { "id": "play_game", "text": "Play Games" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "morning",
        "title": "Morning Energy Booster! 🔋",
        "body": "Utho mamu! Quick tasks complete karo aur wallet balance badhao.",
        "buttons": [
            { "id": "do_task", "text": "Loot Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },

    // === AFTERNOON SLOTS ===
    {
        "category": "afternoon",
        "title": "Bored this afternoon? 🎮",
        "body": "Play bubble shooter and arcade games inside Play Games to earn coins per minute.",
        "buttons": [
            { "id": "play_game", "text": "Play Games" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Afternoon Diamond Catch! 🎮",
        "body": "Play Diamond Catch and win gems!",
        "buttons": [
            { "id": "play_game", "text": "Play Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Quick Break, Easy Coins! ☕",
        "body": "Complete 1 simple task during your break and get instant coins.",
        "buttons": [
            { "id": "do_task", "text": "Complete Task" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Watch Video Afternoon! 📺",
        "body": "Short video rewards are refreshed. Watch now to claim your share.",
        "buttons": [
            { "id": "watch_video", "text": "Watch Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Fruit Catch Challenge! 🍓",
        "body": "Fruit Catch game limit is open. Play now and beat your high score!",
        "buttons": [
            { "id": "play_game", "text": "Play Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Super Offer Loot! 🚀",
        "body": "Try high-paying app install tasks. Double points active this afternoon.",
        "buttons": [
            { "id": "super_offer", "text": "Loot Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Daily Target check! 🎯",
        "body": "Aapne kitne tasks complete kiye? Complete them to unlock target bonus.",
        "buttons": [
            { "id": "do_task", "text": "Check Status" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Game Arena is Open! 👾",
        "body": "Play games and claim daily game gems in your wallet.",
        "buttons": [
            { "id": "play_game", "text": "Enter Arena" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Invite Friends & Earn! 👥",
        "body": "Share your refer link with friends during lunch break and get level rewards.",
        "buttons": [
            { "id": "invite", "text": "Invite Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "afternoon",
        "title": "Quick task approval! ⚡",
        "body": "Instantly approved tasks are active. Get 200+ coins in 1 minute.",
        "buttons": [
            { "id": "do_task", "text": "Do Task" },
            { "id": "open_app", "text": "Open App" }
        ]
    },

    // === EVENING SLOTS ===
    {
        "category": "evening",
        "title": "Shaam ki special loot! 💥",
        "body": "Diamond Catch limit is refreshed. Play now and catch gems to win rewards.",
        "buttons": [
            { "id": "play_game", "text": "Catch Gems" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Evening Fruit Catch! 🍇",
        "body": "Fruits are falling fast! Catch them now and turn scores into coins.",
        "buttons": [
            { "id": "play_game", "text": "Play Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Relax with Games! 🎮",
        "body": "Play your favorite games and earn coins per minute. No installs needed!",
        "buttons": [
            { "id": "play_game", "text": "Play Games" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Watch daily video task! 📺",
        "body": "Watch short videos and claim video bonus coins directly in your wallet.",
        "buttons": [
            { "id": "watch_video", "text": "Watch Video" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Super Offer Evening! 🔥",
        "body": "Exclusive high payout offers are active. Install now to claim massive coins.",
        "buttons": [
            { "id": "super_offer", "text": "Get Rewards" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Milestone status check! 🎯",
        "body": "Aap daily target ke bahut kareeb hain. 1-2 tasks aur karke bonus claim karein.",
        "buttons": [
            { "id": "do_task", "text": "Claim Bonus" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Earn points while chilling! 🛋️",
        "body": "Chill and play simple games in Play Games section to keep earning.",
        "buttons": [
            { "id": "play_game", "text": "Play Games" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Invite & Level Up! 🚀",
        "body": "Tell your friends about Crazyreward. Earn level commissions together!",
        "buttons": [
            { "id": "invite", "text": "Invite" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Quiz Battle Arena Active! ⚔️",
        "body": "Compete in live Quiz Battles and climb the Leaderboard for big rewards.",
        "buttons": [
            { "id": "battle_arena", "text": "Play Battle" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "evening",
        "title": "Quick Evening Reward! ⚡",
        "body": "Do a quick 30-second task and keep your streak burning.",
        "buttons": [
            { "id": "do_task", "text": "Do Task" },
            { "id": "open_app", "text": "Open App" }
        ]
    },

    // === NIGHT SLOTS ===
    {
        "category": "night",
        "title": "Sone se pehle check-in! 🌙",
        "body": "Streak break hone se bachayein. Aaj ka daily target check-in claim karein.",
        "buttons": [
            { "id": "check_in", "text": "Claim Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Bedtime Diamond Catch! 🎮",
        "body": "Play a quick session of Diamond Catch and add extra gems to your wallet.",
        "buttons": [
            { "id": "play_game", "text": "Catch Gems" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Night Loot active! 🪙",
        "body": "Sone se pehle high paying Super Offers complete karein and wake up with huge coins.",
        "buttons": [
            { "id": "super_offer", "text": "Loot Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Watch videos before sleep! 📺",
        "body": "Watch the final videos of the day and maximize your wallet balance.",
        "buttons": [
            { "id": "watch_video", "text": "Watch Video" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Is your daily target done? 🎯",
        "body": "Don't miss the milestone bonus! Check your daily task status before midnight.",
        "buttons": [
            { "id": "do_task", "text": "Check Status" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Play a night game! 🎮",
        "body": "Enjoy a relaxed game session. Earn coins per minute as you play.",
        "buttons": [
            { "id": "play_game", "text": "Play Games" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Night Fruit Catch! 🍉",
        "body": "Quickly play Fruit Catch and collect final daily game rewards.",
        "buttons": [
            { "id": "play_game", "text": "Play Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Referral link share! 👥",
        "body": "Invite friends before sleep. When they join, you both get bonus coins!",
        "buttons": [
            { "id": "invite", "text": "Refer Friends" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Bedtime coin booster! ⚡",
        "body": "Claim 150 bedtime bonus coins in 1 click. Open app now!",
        "buttons": [
            { "id": "do_task", "text": "Claim 150" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "night",
        "title": "Good night with extra coins! 💤",
        "body": "Sleep well! Your earned coins are safe in your wallet. See you tomorrow!",
        "buttons": [
            { "id": "open_app", "text": "Open App" }
        ]
    },

    // === GENERAL SLOTS ===
    {
        "category": "general",
        "title": "Diamond Catch is active! 🎮",
        "body": "Tap to play Diamond Catch and claim your free daily gems.",
        "buttons": [
            { "id": "play_game", "text": "Play Match" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Earn coins by playing games! 🎮",
        "body": "Play unlimited games without any download. Get coins per minute.",
        "buttons": [
            { "id": "play_game", "text": "Play Games" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Super Offer of the Day! 🚀",
        "body": "Huge reward tasks are active. Complete them to get direct coins.",
        "buttons": [
            { "id": "super_offer", "text": "Open Offers" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Daily Check-in Reminder! 🎁",
        "body": "Don't miss today's check-in coins. Tap to claim instantly.",
        "buttons": [
            { "id": "check_in", "text": "Claim" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Watch Videos & Earn! 📺",
        "body": "Easiest way to earn! Watch short video ads and collect your rewards.",
        "buttons": [
            { "id": "watch_video", "text": "Watch & Earn" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Complete Daily Target! 🎯",
        "body": "Achieve today's goal and unlock the special milestone bonus chest.",
        "buttons": [
            { "id": "do_task", "text": "Check Status" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Invite Friends, Earn Level Bonus! 👥",
        "body": "Refer your friends and earn bonus coins on their every task completion.",
        "buttons": [
            { "id": "invite", "text": "Invite" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Fruit Catch Game is live! 🍎",
        "body": "Collect falling fruits and score high to claim extra app coins.",
        "buttons": [
            { "id": "play_game", "text": "Play Now" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Instant Task Approval! ⚡",
        "body": "Simple and fast tasks are online. Get rewards in your wallet instantly.",
        "buttons": [
            { "id": "do_task", "text": "Open Tasks" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Check your Wallet Balance! 💼",
        "body": "Your coins are ready to be claimed or transferred. Open app to check.",
        "buttons": [
            { "id": "do_task", "text": "Check Balance" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Play Games, Collect Gems! 🎮",
        "body": "Join the gaming zone. Earning coins has never been this fun!",
        "buttons": [
            { "id": "play_game", "text": "Play Games" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "High Payout Apps are here! 📥",
        "body": "Super Offer section has new apps. Install them now for massive points.",
        "buttons": [
            { "id": "super_offer", "text": "View Apps" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Quiz Battle Leaderboard! 🏆",
        "body": "Compete in Quiz Battles today and win coin prizes on the Leaderboard.",
        "buttons": [
            { "id": "battle_arena", "text": "Battle Arena" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Watch and Earn tutorial! 📺",
        "body": "Learn how to use Crazyreward and earn free learning bonus coins.",
        "buttons": [
            { "id": "watch_video", "text": "Watch Tutorial" },
            { "id": "open_app", "text": "Open App" }
        ]
    },
    {
        "category": "general",
        "title": "Game Arena updates! 👾",
        "body": "Bubble Shooter, Knife Hit, and Racing Arena are now offering extra points.",
        "buttons": [
            { "id": "play_game", "text": "Play Arena" },
            { "id": "open_app", "text": "Open App" }
        ]
    }
];

// Function to trigger sending the notification via OneSignal API
async function triggerOneSignalNotification(notification) {
    let oneSignalAppId = String(process.env.ONESIGNAL_APP_ID || '').trim();
    let oneSignalApiKey = String(process.env.ONESIGNAL_API_KEY || '').trim();

    try {
        const AppData = require('../models/appData');
        const appDoc = await AppData.findOne({ key: 'appData' }).lean();
        if (appDoc?.oneSignalAppId || appDoc?.config?.oneSignalAppId) {
            oneSignalAppId = String(appDoc.oneSignalAppId || appDoc.config.oneSignalAppId).trim();
        }
        if (appDoc?.oneSignalApiKey || appDoc?.config?.oneSignalApiKey) {
            oneSignalApiKey = String(appDoc.oneSignalApiKey || appDoc.config.oneSignalApiKey).trim();
        }
    } catch (_) {}

    if (!oneSignalAppId || !oneSignalApiKey) {
        console.error('❌ OneSignal keys are missing in appData/env');
        return false;
    }

    const payload = {
        app_id: oneSignalAppId,
        headings: { en: notification.title },
        contents: { en: notification.body },
        // Target only users in India (IN)
        filters: [
            { field: "country", relation: "=", value: "IN" }
        ]
    };

    if (notification.buttons && notification.buttons.length > 0) {
        payload.buttons = notification.buttons;
    }

    try {
        console.log(`📡 Sending push to OneSignal: "${notification.title}"`);
        const response = await axios.post(
            'https://api.onesignal.com/notifications',
            payload,
            {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Key ${oneSignalApiKey}`,
                },
                timeout: 20000,
            }
        );
        console.log(`✅ Push sent successfully! Response:`, response.data);
        return true;
    } catch (err) {
        console.error('❌ Error calling OneSignal API:', err?.response?.data || err?.message || err);
        return false;
    }
}

// Main job runner
async function sendHourlyNotification() {
    console.log('⏰ Starting push notification rotation job...');
    try {
        await connectMongo();

        // 1. Calculate current India Standard Time (IST, UTC+5:30)
        const date = new Date();
        const utcTime = date.getTime() + (date.getTimezoneOffset() * 60000);
        const istDate = new Date(utcTime + (3600000 * 5.5));
        const hour = istDate.getHours();
        
        console.log(`📍 Current India Standard Time (IST): ${istDate.toISOString()} (Hour: ${hour})`);

        // 2. Map current hour to permitted categories
        // Morning: 5 AM - 12 PM (5 to 11)
        // Afternoon: 12 PM - 4 PM (12 to 15)
        // Evening: 4 PM - 8 PM (16 to 19)
        // Night: 8 PM - 5 AM (20 to 4)
        let permittedCategories = ['general']; // General/Games/Tasks can always be mixed in
        
        if (hour >= 5 && hour < 12) {
            permittedCategories.push('morning');
            console.log('🌅 Morning Slot Active. Selecting from Morning & General categories.');
        } else if (hour >= 12 && hour < 16) {
            permittedCategories.push('afternoon');
            console.log('☀️ Afternoon Slot Active. Selecting from Afternoon & General categories.');
        } else if (hour >= 16 && hour < 20) {
            permittedCategories.push('evening');
            console.log('🌇 Evening Slot Active. Selecting from Evening & General categories.');
        } else {
            permittedCategories.push('night');
            console.log('🌙 Night Slot Active. Selecting from Night & General categories.');
        }

        // 3. Filter notifications matching the active categories
        const filteredNotifications = notifications.filter(n => permittedCategories.includes(n.category));
        console.log(`📋 Permitted notifications count: ${filteredNotifications.length} / ${notifications.length}`);

        // 4. Find or create rotation state in DB to avoid repeating recently sent notifications
        const stateKey = 'hourly_push_notification_rotation';
        let stateDoc = await CronState.findOne({ key: stateKey });
        
        if (!stateDoc) {
            stateDoc = new CronState({
                key: stateKey,
                value: { recentTitles: [] }
            });
        }

        let recentTitles = stateDoc.value.recentTitles || [];
        
        // Remove from available list if it was sent recently (last 100 runs history)
        let available = filteredNotifications.filter(n => !recentTitles.includes(n.title));
        
        if (available.length === 0) {
            console.log('⚠️ All permitted notifications were recently sent. Resetting recent history filter.');
            available = filteredNotifications;
            recentTitles = [];
        }

        // 5. Select a random notification from the available list
        const selectedIndex = Math.floor(Math.random() * available.length);
        const selectedNotification = available[selectedIndex];
        
        console.log(`📌 Selected notification category: "${selectedNotification.category}", title: "${selectedNotification.title}"`);

        // 6. Trigger OneSignal push
        const success = await triggerOneSignalNotification(selectedNotification);

        if (success) {
            recentTitles.push(selectedNotification.title);
            // Keep recent history length within 100 to allow rotation eventually
            if (recentTitles.length > 100) {
                recentTitles.shift();
            }
            stateDoc.value = { recentTitles, lastSentAt: new Date() };
            stateDoc.markModified('value');
            await stateDoc.save();
            console.log('💾 Saved updated rotation state history to DB.');
        } else {
            console.warn('⚠️ Push notification trigger failed. Index state not advanced.');
        }

    } catch (err) {
        console.error('🔥 Error in notification job:', err);
    }
    console.log('🏁 Notification job completed.');
}

// Schedule cron job to run every 3 hours
cron.schedule('0 */3 * * *', async () => {
    await sendHourlyNotification();
});

console.log('⏰ Push Notification Cron initialized. Pattern: 0 */3 * * *');

// Export helper and lists for tests
module.exports = {
    notifications,
    sendHourlyNotification,
    triggerOneSignalNotification
};
