const express = require('express');
const router = express.Router();

const userRoutes = require('./modules/userRoutes');
const configRoutes = require('./modules/configRoutes');
const leaderboardRoutes = require('./modules/leaderboardRoutes');
const giveawayRoutes = require('./modules/giveawayRoutes');
const referralRoutes = require('./modules/referralRoutes');
const payoutRoutes = require('./modules/payoutRoutes');
const superOfferRoutes = require('./modules/superOfferRoutes');
const rewardRoutes = require('./modules/rewardRoutes');
const offerwallRoutes = require('./modules/offerwallRoutes');
const readEarnRoutes = require('./modules/readEarnRoutes');
const diamondCatchRoutes = require('./modules/diamondCatchRoutes');
const watchEarnRoutes = require('./modules/watchEarnRoutes');
const battleApiRoutes = require('../battle-arena/routes/battleApiRoutes');
const postbackRoutes = require('./modules/postbackRoutes');
const integrationRoutes = require('./integrationRoutes');
const { router: dailyChallengeApiRoutes } = require('./modules/dailyChallengeApiRoutes');

// Mount Sub-Routers
router.use('/user', userRoutes);
router.use('/config', configRoutes);
router.use('/leaderboard', leaderboardRoutes);
router.use('/giveaway', giveawayRoutes);
router.use('/referral', referralRoutes);
router.use('/payout', payoutRoutes);
router.use('/super-offer', superOfferRoutes);
router.use('/reward', rewardRoutes);
router.use('/postback', offerwallRoutes);
router.use('/offerwall', offerwallRoutes);
router.use('/read-earn', readEarnRoutes);
router.use('/diamond-catch', diamondCatchRoutes);
router.use('/watch-earn', watchEarnRoutes);
router.use('/battle', battleApiRoutes);
router.use('/daily-challenge', dailyChallengeApiRoutes);
router.use('/integrations', integrationRoutes);

// Top-Level Router Exports
router.use('/', userRoutes);
router.use('/', configRoutes);
router.use('/', leaderboardRoutes);
router.use('/', giveawayRoutes);
router.use('/', referralRoutes);
router.use('/', payoutRoutes);
router.use('/', superOfferRoutes);
router.use('/', rewardRoutes);
router.use('/', readEarnRoutes);
router.use('/', offerwallRoutes);
router.use('/', diamondCatchRoutes);
router.use('/', watchEarnRoutes);
router.use('/', battleApiRoutes);
router.use('/', dailyChallengeApiRoutes);
router.use('/', postbackRoutes);
router.use('/', integrationRoutes);

module.exports = router;
