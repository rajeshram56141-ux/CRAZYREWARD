import 'dart:convert';

mixin AppConst {
  static String get serverBaseUrl =>
      utf8.decode(base64.decode('aHR0cHM6Ly9kaWFtb25kcGFuZGEuem9kcGxheWdhbWVzLmNvbQ=='));

  static const String appBaseUrl =
      'https://play.google.com/store/apps/details?id=';

  static const String defaultAppName = 'diamondpanda';

  static const int maxAccountPerDevice = 1;
  static const int maxStreak = 7;

  // Filled from SplashService.urlConfig at runtime.
  static String whatsappLink = '';
  static String youtubeLink = '';
  static String telegramLink = '';
  static String instagramLink = '';

  // API Key - Set via Firebase Remote Config for security
  // Removed hardcoded key to prevent exposure via APK decompilation
  static String apiKey = '';

  static Map<String, dynamic> get apiHeader => {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'x-api-key': apiKey,
      };

  static const String defaultOneSignalAppId = '';
  static String oneSignalAppId = defaultOneSignalAppId;

  static String get fetchDailyTask => '$serverBaseUrl/get-daily-task';
  static String get fetchGames => '$serverBaseUrl/get-games';
  static String get fetchReadTskUrl => '$serverBaseUrl/get-read-earn-url';
  static String get dailyTaskPostback => '$serverBaseUrl/daily-task-postback';
  static String get dailyTaskVerifyOcr => '$serverBaseUrl/daily-task-verify-ocr';
  static String get readTskPostback => '$serverBaseUrl/read-earn-postback';
  static String get superOfferVerify => '$serverBaseUrl/super-offer-verify';
  static String get diamondCatchVerify => '$serverBaseUrl/diamond-catch-verify';
  static String get fetchWatchEarnTasks => '$serverBaseUrl/get-watch-earn-tasks';
  static String get watchEarnPostback => '$serverBaseUrl/watch-earn-postback';
  static String get watchVideoVerifyOcr => '$serverBaseUrl/watch-video-verify-ocr';
  static String get getServerTime => '$serverBaseUrl/getServerTime';
  static String get getAppData => '$serverBaseUrl/get-app-data';
  static String get trackBannerClickApi => '$serverBaseUrl/api/banner/click';

  static String get submitPromotionRequest =>
      '$serverBaseUrl/submit-promotion-request';
  static String get getPromotionRequests =>
      '$serverBaseUrl/get-promotion-requests';
  static String get submitSupportRequest =>
      '$serverBaseUrl/submit-support-request';
  static String get getSupportRequests =>
      '$serverBaseUrl/get-support-requests';
  static String get getRewardHistory =>
      '$serverBaseUrl/api/get-reward-history';
  static String get getDailyTaskHistory =>
      '$serverBaseUrl/api/get-daily-task-history';
  static String get getPayoutHistory =>
      '$serverBaseUrl/api/get-payout-history';
  static String get getWalletMethods =>
      '$serverBaseUrl/api/get-wallet-methods';
  static String get streakRewardApi => '$serverBaseUrl/api/reward/streak';
  static String get promoCodeRewardApi => '$serverBaseUrl/api/reward/promo-code';
  static String get requestPayoutApi => '$serverBaseUrl/api/payout/request';
  static String get userSyncApi => '$serverBaseUrl/api/user-sync';
  static String get saveUserDetailsApi => '$serverBaseUrl/api/save-user-details';
  static String get joinGiveawayApi => '$serverBaseUrl/api/giveaways/join';
  static String get claimGiveawayRewardApi => '$serverBaseUrl/api/giveaway/claim-reward';
  static String get claimGemsApi => '$serverBaseUrl/api/reward/gems';
  static String get claimSuperOfferApi => '$serverBaseUrl/api/reward/super-offer';
  static String get followRewardApi => '$serverBaseUrl/api/reward/follow';
  static String get completeBattleInstallTaskApi => '$serverBaseUrl/api/complete-battle-install-task';
  static String get applyReferralApi => '$serverBaseUrl/api/referral/apply';
  static String get dailyChallengeStatusApi => '$serverBaseUrl/api/daily-challenge/status';
  static String get claimDailyChallengeRewardApi => '$serverBaseUrl/api/daily-challenge/claim';
  static String get logSuperOfferActivityApi => '$serverBaseUrl/api/super-offer/log-activity';
  static String get submitSuperOfferScreenshotApi => '$serverBaseUrl/api/super-offer/submit-screenshot';
  static String get getSuperOfferProofStatusApi => '$serverBaseUrl/api/super-offer/proof-status';
  static String get getUserPendingOffersApi => '$serverBaseUrl/api/super-offer/user-pending-offers';
  static String get deductSuperOfferGemsApi => '$serverBaseUrl/api/super-offer/deduct-gems';
  static String get claimSuperOfferUsageStepApi => '$serverBaseUrl/api/super-offer/claim-usage-step';
}

mixin AdKeys {
  static const String appId = 'h6a8a7aa8b5f30';
  static const String appKey = 'a196d32c78bfaa8b67e43b9732d4e3f26';

  // Configured purely from Admin Panel > Manage App Settings > Ads Config
  static String interstitialKey = '';
  static String rewardedKey = '';
  static String nativeKey = '';
  static String bannerKey = '';
  static bool isAdsEnabled = true;
  static bool isHomeNativeEnabled = true;
  static bool isSuperOfferNativeEnabled = true;
  static bool isDailyChallengeNativeEnabled = true;
  static bool isPlayGamesNativeEnabled = true;
  static bool isWatchVideoNativeEnabled = true;

  static void updateFromConfig({
    String? interstitial,
    String? rewarded,
    String? native,
    String? banner,
    bool? enabled,
    bool? homeNative,
    bool? superOfferNative,
    bool? dailyChallengeNative,
    bool? playGamesNative,
    bool? watchVideoNative,
  }) {
    interstitialKey = (interstitial ?? '').trim();
    rewardedKey = (rewarded ?? '').trim();
    nativeKey = (native ?? '').trim();
    bannerKey = (banner ?? '').trim();
    if (enabled != null) {
      isAdsEnabled = enabled;
    }
    if (homeNative != null) {
      isHomeNativeEnabled = homeNative;
    }
    if (superOfferNative != null) {
      isSuperOfferNativeEnabled = superOfferNative;
    }
    if (dailyChallengeNative != null) {
      isDailyChallengeNativeEnabled = dailyChallengeNative;
    }
    if (playGamesNative != null) {
      isPlayGamesNativeEnabled = playGamesNative;
    }
    if (watchVideoNative != null) {
      isWatchVideoNativeEnabled = watchVideoNative;
    }
  }
}

enum SocialMedia { whatsapp, youtube, telegram, instagram }

extension SocialMediaLink on SocialMedia {
  String get link {
    switch (this) {
      case SocialMedia.whatsapp:
        return AppConst.whatsappLink;
      case SocialMedia.youtube:
        return AppConst.youtubeLink;
      case SocialMedia.telegram:
        return AppConst.telegramLink;
      case SocialMedia.instagram:
        return AppConst.instagramLink;
    }
  }

  String get title {
    switch (this) {
      case SocialMedia.whatsapp:
        return 'join-whatsapp';
      case SocialMedia.youtube:
        return 'subscribe-youtube';
      case SocialMedia.telegram:
        return 'join-telegram-group';
      case SocialMedia.instagram:
        return 'follow-instagram';
    }
  }
}
