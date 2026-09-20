const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const connectMongo = require('../../admin/middlewares/connectMongo');
const IncomingPromo = require('../../admin/models/incomingPromo');
const PublisherPostback = require('../../admin/models/publisherPostback');
const User = require('../../admin/models/user');
const RewardHistory = require('../../admin/models/rewardHistory');
const PostbackLog = require('../../admin/models/postbackLogs');

// helper to verify sha256 hash signature
function verifySignature(raw, secret, sig) {
    const computed = crypto.createHash('sha256').update(raw).digest('hex');
    return computed.toLowerCase() === String(sig).toLowerCase();
}

// 💎 Case 1: Incoming Promo from another clone app to reward our user
router.get('/postback/incoming-promo', async (req, res) => {
    try {
        await connectMongo();
        const { tracker_code, user_id, event, sig } = req.query;

        if (!tracker_code || !user_id || !event || !sig) {
            return res.status(400).json({ success: false, message: 'Missing required parameters' });
        }

        const promo = await IncomingPromo.findOne({ trackerCode: tracker_code, isActive: true });
        if (!promo) {
            return res.status(404).json({ success: false, message: 'Active promo configuration not found' });
        }

        // Verify signature: sha256(secretKey:user_id:event)
        const rawString = `${promo.secretKey}:${user_id}:${event}`;
        if (!verifySignature(rawString, promo.secretKey, sig)) {
            return res.status(403).json({ success: false, message: 'Invalid signature' });
        }

        // Find user
        const user = await User.findOne({ userId: user_id });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        // Find mapped event reward
        const eventReward = promo.events.find(e => e.eventId === event);
        if (!eventReward) {
            return res.status(400).json({ success: false, message: 'Mapped event reward not found' });
        }

        const coins = Number(eventReward.coins);

        // Credit coins
        user.coins = (Number(user.coins) || 0) + coins;
        user.totalCoins = (Number(user.totalCoins) || 0) + coins;
        await user.save();

        // Send push notification to the user
        try {
            const { sendNotificationViaApi } = require('../../admin/middlewares/send-notification-api');
            sendNotificationViaApi({
                title: 'Coins Credited!',
                body: `You received ${coins} coins for completing ${event || 'promo task'}.`,
                userId: user_id
            }).catch(e => console.error('⚠️ OneSignal promo push error:', e.message));
        } catch (pushErr) {
            console.error('⚠️ OneSignal import error in promo route:', pushErr.message);
        }

        // Create reward history
        const transactionId = Date.now() + '-' + Math.floor(Math.random() * 1000);
        await RewardHistory.create({
            appName: user.appName || '',
            userId: user_id,
            provider: 'S2S Promo',
            coins: coins,
            rewardType: 'coin',
            orderId: `promo_${transactionId}`,
            transId: transactionId,
            timestamp: new Date()
        }).catch(err => console.error("⚠️ RewardHistory create warning:", err.message));

        // Log to PostbackLog
        await PostbackLog.create({
            appName: user.appName || '',
            userId: user_id,
            txnId: transactionId,
            offerId: promo.offerId,
            eventId: event,
            payout: coins,
            responseStatus: 200,
            payload: req.query,
            completedAt: new Date()
        }).catch(logErr => console.error('❌ Log Error:', logErr.message));

        return res.json({ success: true, message: 'Coins credited successfully via promo postback', coins });
    } catch (err) {
        console.error('🔥 Error in incoming-promo postback:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

// 💎 Case 2: Incoming Task completed on our app, credited on the clone app (Receiver endpoint)
router.get('/postback/incoming-task', async (req, res) => {
    try {
        await connectMongo();
        const { user_id, offer_id, coins, eventId = '', sig, refer_code } = req.query;

        if (!user_id || !offer_id || !coins || !sig || !refer_code) {
            return res.status(400).json({ success: false, message: 'Missing required parameters' });
        }

        const publisher = await PublisherPostback.findOne({ referCode: refer_code, isActive: true });
        if (!publisher) {
            return res.status(404).json({ success: false, message: 'Active publisher configuration not found' });
        }

        // Verify signature: sha256(secretKey:user_id:offer_id:coins:eventId)
        const rawString = `${publisher.secretKey}:${user_id}:${offer_id}:${coins}:${eventId}`;
        if (!verifySignature(rawString, publisher.secretKey, sig)) {
            return res.status(403).json({ success: false, message: 'Invalid signature' });
        }

        // Find user
        const user = await User.findOne({ userId: user_id });
        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const creditCoins = Number(coins);

        // Credit coins
        user.coins = (Number(user.coins) || 0) + creditCoins;
        user.totalCoins = (Number(user.totalCoins) || 0) + creditCoins;
        await user.save();

        // Send push notification to the user
        try {
            const { sendNotificationViaApi } = require('../../admin/middlewares/send-notification-api');
            sendNotificationViaApi({
                title: 'Coins Credited!',
                body: `You received ${creditCoins} coins for completing ${offer_id || 'task'}.`,
                userId: user_id
            }).catch(e => console.error('⚠️ OneSignal task push error:', e.message));
        } catch (pushErr) {
            console.error('⚠️ OneSignal import error in task route:', pushErr.message);
        }

        // Create reward history
        const transactionId = Date.now() + '-' + Math.floor(Math.random() * 1000);
        await RewardHistory.create({
            appName: user.appName || '',
            userId: user_id,
            provider: 'Publisher Promo',
            coins: creditCoins,
            rewardType: 'coin',
            orderId: `publisher_${transactionId}`,
            transId: transactionId,
            timestamp: new Date()
        }).catch(err => console.error("⚠️ RewardHistory create warning:", err.message));

        return res.json({ success: true, message: 'Coins credited successfully via publisher task postback', coins: creditCoins });
    } catch (err) {
        console.error('🔥 Error in incoming-task postback:', err);
        return res.status(500).json({ success: false, message: 'Internal Server Error' });
    }
});

module.exports = router;
