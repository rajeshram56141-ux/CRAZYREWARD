const axios = require('axios');
const crypto = require('crypto');
const PublisherPostback = require('../admin/models/publisherPostback');

async function triggerOutgoingPostback({ user, offerId, coins, eventId }) {
    try {
        if (!user.publisherRef || !user.publisherUid) {
            return;
        }

        const publisher = await PublisherPostback.findOne({ referCode: user.publisherRef, isActive: true });
        if (!publisher) {
            console.log(`ℹ️ Outgoing Postback: No active publisher found for referCode ${user.publisherRef}`);
            return;
        }

        // Check if this offerId is assigned to the publisher
        const isAssigned = publisher.assignedTasks.includes(offerId);
        if (!isAssigned) {
            console.log(`ℹ️ Outgoing Postback: Offer ${offerId} is not assigned to publisher ${user.publisherRef}`);
            return;
        }

        const subEventId = eventId || '';

        // Generate SHA256 signature: sha256(secretKey:user_id:offer_id:coins:eventId)
        const rawString = `${publisher.secretKey}:${user.publisherUid}:${offerId}:${coins}:${subEventId}`;
        const signature = crypto.createHash('sha256').update(rawString).digest('hex');

        // Build callback URL
        const connector = publisher.postbackUrl.includes('?') ? '&' : '?';
        const finalUrl = `${publisher.postbackUrl}${connector}user_id=${user.publisherUid}&offer_id=${offerId}&coins=${coins}&eventId=${subEventId}&sig=${signature}&refer_code=${user.publisherRef}`;

        console.log(`📡 Triggering publisher postback request: ${finalUrl}`);
        const res = await axios.get(finalUrl, { timeout: 8000 });
        console.log(`✅ Publisher postback response received:`, res.data);
    } catch (err) {
        console.error(`❌ Outgoing publisher postback failed:`, err.message);
    }
}

module.exports = triggerOutgoingPostback;
