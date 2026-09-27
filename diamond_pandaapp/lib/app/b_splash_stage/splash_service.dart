import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:advertising_id/advertising_id.dart';
import 'package:android_id/android_id.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../services/notification_service.dart';
import '../../services/security_service.dart';
import '../../utils/constant/constant.dart';
import '../e_dashboard_stage/sections/a_home/offerwall/model/offerwall_data_model.dart';
import '../e_dashboard_stage/sections/a_home/offerwall/provider/offerwall_manager.dart';
import '../e_dashboard_stage/sections/b_invite/model/referral_level_model.dart';
import '../e_dashboard_stage/sections/a_home/more_apps/more_apps_model.dart';
import '../e_dashboard_stage/sections/a_home/wallet/model/wallet_catalog_model.dart';
import 'model.dart';

class SplashService {
  static final Dio _dio = Dio();
  static final FirebaseAuth _fireAuth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final CollectionReference<Map<String, dynamic>> _adminColl = _firestore
      .collection('admin');

  static String deviceId = '';
  static String gaid = '';
  static String appName = '';
  static String dailyTaskTitle = 'Daily Task';
  static String packageName = '';
  static String appVersion = '';
  static String buildNumber = '';

  static UpdateConfig updateConfig = const UpdateConfig();
  static MaintenanceConfig maintenanceConfig = MaintenanceConfig();
  static SpinConfig spinConfig = SpinConfig();
  static StreakConfig streakConfig = StreakConfig();
  static UrlConfig urlConfig = UrlConfig();
  static WelcomePopupConfig welcomePopupConfig = WelcomePopupConfig();
  static Map<String, dynamic> superOfferConfig = {};
  static Map<String, dynamic> howToUseConfig = {};
  static Map<String, dynamic> playtimeConfig = {};
  static List<HomeBanner> homeBanners = [];
  static Map<String, ScreenBanner> screenBanners = {};
  static List<MoreAppsModel> moreApps = [];
  static AdsConfig adsConfig = const AdsConfig();
  static HideDenominationConfig hideDenominationConfig = const HideDenominationConfig();

  static ScreenBanner? getScreenBanner(String screenKey) {
    // 1. Screen-specific banner
    final banner = screenBanners[screenKey];
    if (banner != null && banner.enabled && banner.imageUrl.isNotEmpty) {
      return banner;
    }
    // 2. Global fallback: All Screens banner
    final globalBanner = screenBanners['allScreens'];
    if (globalBanner != null && globalBanner.enabled && globalBanner.imageUrl.isNotEmpty) {
      return globalBanner;
    }
    return null;
  }

  static String getTutorialUrl(String key, String fallbackUrl) {
    if (howToUseConfig.containsKey(key)) {
      final item = howToUseConfig[key];
      if (item is Map && item['tutorialUrl'] != null) {
        final url = item['tutorialUrl'].toString().trim();
        if (url.isNotEmpty) {
          return url;
        }
      }
    }
    return fallbackUrl;
  }

  static Map<String, dynamic> screenSettings = {};
  static List<String> defaultDisclaimer = [];

  static String getScreenStatus(String key) {
    if (screenSettings.containsKey(key)) {
      final v = screenSettings[key];
      if (v == 'hidden' || v == 'hide') return 'hidden';
      if (v == false || v == 'disabled' || v == 'false') return 'disabled';
      return 'enabled';
    }
    if (key == 'readTask' && screenSettings.containsKey('readAndEarn')) {
      return getScreenStatus('readAndEarn');
    }
    if (key == 'readAndEarn' && screenSettings.containsKey('readTask')) {
      return getScreenStatus('readTask');
    }
    return 'enabled';
  }

  static bool isScreenHidden(String key) {
    return getScreenStatus(key) == 'hidden';
  }

  static bool isScreenEnabled(String key, {bool defaultValue = true}) {
    final status = getScreenStatus(key);
    if (status == 'hidden' || status == 'disabled') {
      return false;
    }
    return true;
  }

  static int followCoins = 0;
  static bool gameRewardedAds = false;
  static String shareText = '';
  static int coinConversionRate = 150;
  static bool showCoinConversionRate = false;

  // Offers (filled from offersSettings each time)
  static final List<OffersDataModel> _surveyList = [];
  static final List<OffersDataModel> _taskList = [];
  static ReferralSettings referralSettings = ReferralSettings.empty();
  static ServerTime serverTime = ServerTime(
    leaderboardTimeLeft: 0,
    serverTime: 0,
  );
  static DateTime? serverTimeFetchedAt;

  // ------------------ Providers ------------------
  static final authProvider = FutureProvider<UserCheckResult>((ref) async {
    try {
      final User? user = _fireAuth.currentUser;

      if (user == null) {
        return UserCheckResult(user: null, userNotFound: false);
      }



      try {
        final token = await user.getIdToken() ?? '';
        final rawInput = {
          'userId': user.uid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        final encryptedPayload = SecurityService.encryptPayload(
          rawInput,
          userId: user.uid,
          deviceId: SplashService.deviceId,
        );

        final res = await http.post(
          Uri.parse('${AppConst.serverBaseUrl}/api/user/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'user-id': user.uid,
            'device-id': SplashService.deviceId,
          },
          body: jsonEncode({'payload': encryptedPayload}),
        ).timeout(const Duration(seconds: 5));



        Map<String, dynamic> resData = {};
        try {
          resData = Map<String, dynamic>.from(jsonDecode(res.body));
        } catch (_) {}

        // Check deleted FIRST - before any decryption
        if (resData['isDeleted'] == true) {
          return UserCheckResult(user: user, userNotFound: false, isBlocked: false, isDeleted: true);
        }

        // Check blocked FIRST - before any decryption
        if (res.statusCode == 403 || resData['isBlocked'] == true || resData['blocked'] == true) {
          return UserCheckResult(user: user, userNotFound: false, isBlocked: true);
        }

        // Decrypt if needed
        if (resData['responsePayload'] != null) {
          final decryptedStr = SecurityService.decryptPayload(
            resData['responsePayload'].toString(),
            userId: user.uid,
            deviceId: SplashService.deviceId,
          );
          if (decryptedStr.isNotEmpty) {
            try {
              resData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
            } catch (_) {}
          }
        }

        final Map<String, dynamic>? userData = resData['user'] is Map<String, dynamic>
            ? resData['user']
            : (resData['data'] is Map<String, dynamic> ? resData['data'] : null);

        // Check deleted again after decryption
        if (resData['isDeleted'] == true ||
            (userData != null && (userData['account_deleted'] == true || userData['accountDeleted'] == true))) {
          return UserCheckResult(user: user, userNotFound: false, isBlocked: false, isDeleted: true);
        }

        // Check blocked again after decryption
        if (resData['isBlocked'] == true || resData['blocked'] == true ||
            (userData != null && (userData['isBlocked'] == true || userData['blocked'] == true))) {
          return UserCheckResult(user: user, userNotFound: false, isBlocked: true);
        }

        if (res.statusCode == 200 && userData != null) {
          if (userData['account_deleted'] == true || userData['accountDeleted'] == true) {
            return UserCheckResult(user: user, userNotFound: false, isBlocked: false, isDeleted: true);
          }

          // Validate profile exists and has user identity
          final bool isGuest = userData['isGuest'] == true;
          final String email = (userData['email'] ?? '').toString().trim();
          final String uId = (userData['userId'] ?? '').toString().trim();
          final bool hasValidProfile = isGuest || (email.isNotEmpty && email != 'null') || uId.isNotEmpty;

          if (!hasValidProfile) {
            await _fireAuth.signOut();
            await SecurityService.clearSecureKeys();
            return UserCheckResult(user: null, userNotFound: true, isBlocked: false);
          }

          return UserCheckResult(
            user: user,
            userNotFound: false,
            isBlocked: false,
            userData: userData,
          );
        }

        // User not found on server (404, 200 with no data, or any other status)
        await _fireAuth.signOut();
        await SecurityService.clearSecureKeys();
        return UserCheckResult(user: null, userNotFound: true, isBlocked: false);
      } catch (e) {

        return UserCheckResult(
          user: user,
          userNotFound: false,
          isBlocked: false,
        );
      }
    } catch (e) {
      dev.log('Error fetching current user: $e');
      return UserCheckResult(user: null, userNotFound: false, isBlocked: false);
    }
  });

  static final homeBannersProvider = Provider<AsyncValue<List<HomeBanner>>>((ref) {
    final appDataAsync = ref.watch(appDataProvider);
    return appDataAsync.when(
      data: (_) => AsyncValue.data(homeBanners),
      loading: () => homeBanners.isNotEmpty
          ? AsyncValue.data(homeBanners)
          : const AsyncValue.loading(),
      error: (_, __) => AsyncValue.data(homeBanners),
    );
  });

  static final appDataProvider = FutureProvider((ref) async {
    try {
      //! Fetching Leaderboard Time
      serverTime = await _getServerTime();
      serverTimeFetchedAt = DateTime.now();

      // ---- Basic info
      try {
        deviceId = await const AndroidId().getId() ?? '';
      } catch (_) {
        deviceId = '';
      }

      try {
        gaid = await AdvertisingId.id(true) ?? '';
      } catch (_) {
        gaid = '';
      }

      try {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        appName = packageInfo.appName;
        packageName = packageInfo.packageName;
        appVersion = packageInfo.version;
        buildNumber = packageInfo.buildNumber;
      } catch (_) {}

      // ---- Fetch App Configuration from MongoDB Backend
      try {
        final rawInput = {
          'deviceId': deviceId,
          'gaid': gaid,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        final encryptedPayload = SecurityService.encryptPayload(rawInput);

        final res = await _dio.post(
          AppConst.getAppData,
          data: {'payload': encryptedPayload},
          options: Options(
            headers: AppConst.apiHeader,
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        Map<String, dynamic> mongoData = res.data is Map<String, dynamic>
            ? Map<String, dynamic>.from(res.data)
            : Map<String, dynamic>.from(jsonDecode(res.data.toString()));

        if (mongoData['responsePayload'] != null) {
          final decryptedStr = SecurityService.decryptPayload(mongoData['responsePayload'].toString());
          if (decryptedStr.isNotEmpty) {
            try {
              mongoData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
            } catch (_) {}
          }
        }

        if (res.statusCode == 200 && mongoData['success'] == true) {
          final Map<String, dynamic> appDataMap = Map<String, dynamic>.from(mongoData['appData'] ?? {});
          final Map<String, dynamic> offersSettingsData = Map<String, dynamic>.from(mongoData['offersSettings'] ?? {});
          final Map<String, dynamic> referralSettingsData = Map<String, dynamic>.from(mongoData['referralSettings'] ?? {});

          if (appDataMap.isNotEmpty) {
            await _setAppData(appDataMap, buildNumber);
          }
          if (offersSettingsData.isNotEmpty) {
            _fillOffersListsFromMap(offersSettingsData);
          }
          if (referralSettingsData.isNotEmpty) {
            referralSettings = ReferralSettings.fromFirestore(referralSettingsData);
          }
        } else {
          dev.log('MongoDB app-data returned non-200, falling back to Firestore');
        }
      } catch (e) {
        dev.log('MongoDB app-data fetch error, falling back to Firestore: $e');
        // Fallback to Firestore if backend is offline
        try {
          final appDataSnap = await _adminColl
              .doc('appData')
              .get()
              .timeout(const Duration(seconds: 5));
          if (appDataSnap.exists && appDataSnap.data() != null) {
            await _setAppData(appDataSnap.data()!, buildNumber);
          }
        } catch (ex) {
          dev.log('appData Firestore fallback error: $ex');
        }

        try {
          final offersSnap = await _adminColl
              .doc('offersSettings')
              .get()
              .timeout(const Duration(seconds: 5));
          if (offersSnap.exists && offersSnap.data() != null) {
            _fillOffersListsFromMap(offersSnap.data()!);
          } else {
            _clearOffersLists();
          }
        } catch (ex) {
          dev.log('offersSettings Firestore fallback error: $ex');
          _clearOffersLists();
        }

        try {
          final referralSnap = await _adminColl
              .doc('referralSettings')
              .get()
              .timeout(const Duration(seconds: 5));

          if (referralSnap.exists && referralSnap.data() != null) {
            referralSettings = ReferralSettings.fromFirestore(referralSnap.data()!);
          } else {
            referralSettings = ReferralSettings.empty();
          }
        } catch (ex) {
          dev.log('referralSettings Firestore fallback error: $ex');
          referralSettings = ReferralSettings.empty();
        }

        try {
          final moreAppsSnap = await _adminColl
              .doc('moreApps')
              .get()
              .timeout(const Duration(seconds: 5));

          if (moreAppsSnap.exists && moreAppsSnap.data() != null) {
            final data = moreAppsSnap.data()!;
            final List<dynamic>? rawApps = data['apps'] ?? data['moreApps'] ?? data['list'];
            if (rawApps != null) {
              moreApps = rawApps
                  .whereType<Map>()
                  .map((b) => MoreAppsModel.fromMap(Map<String, dynamic>.from(b)))
                  .where((b) => b.enabled)
                  .toList();
            }
          }
        } catch (ex) {
          dev.log('moreApps Firestore doc fallback error: $ex');
        }
      }

      // ---- Arrange (enabled-first, rank sort, same-rank shuffle, disabled-last)
      OfferwallManager.arrangeOffers(
        surveyList: _surveyList,
        taskList: _taskList,
      );
    } catch (e, s) {
      dev.log('Error in appDataProvider: $e\n$s');
      rethrow;
    }
  });

  // ------------------ Private Helpers ------------------
  static Future<void> _setAppData(
    Map<String, dynamic> appData,
    String buildNumber,
  ) async {
    try {
      updateConfig = UpdateConfig.fromMap(appData['updateConfig'], buildNumber);

      maintenanceConfig = MaintenanceConfig.fromMap(
        appData['maintenanceConfig'],
      );

      spinConfig = SpinConfig.fromMap(appData['spinConfig']);
      streakConfig = StreakConfig.fromMap(appData['streakConfig']);
      urlConfig = UrlConfig.fromMap(appData['urlConfig']);
      welcomePopupConfig = WelcomePopupConfig.fromMap(appData['welcomePopup']);
      if (appData['adsConfig'] != null) {
        adsConfig = AdsConfig.fromMap(
          Map<String, dynamic>.from(appData['adsConfig'] as Map),
        );
        AdKeys.updateFromConfig(
          interstitial: adsConfig.interstitialKey,
          rewarded: adsConfig.rewardedKey,
          native: adsConfig.nativeKey,
          banner: adsConfig.bannerKey,
          enabled: adsConfig.enabled,
          homeNative: adsConfig.homeNativeEnabled,
          superOfferNative: adsConfig.superOfferNativeEnabled,
          dailyChallengeNative: adsConfig.dailyChallengeNativeEnabled,
          playGamesNative: adsConfig.playGamesNativeEnabled,
          watchVideoNative: adsConfig.watchVideoNativeEnabled,
        );
      }

      // Sync social links used by SocialMedia.link getter.
      AppConst.whatsappLink = urlConfig.whatsappLink;
      AppConst.youtubeLink = urlConfig.youtubeLink;
      AppConst.telegramLink = urlConfig.telegramLink;
      AppConst.instagramLink = urlConfig.instagramLink;

      // Set API key from server config (security: don't store in APK)
      _setApiKeyFromAppData(appData);

      // Sync dynamic OneSignal App ID from server
      final dynamicOneSignalId = appData['oneSignalAppId'] ?? (appData['config'] is Map ? appData['config']['oneSignalAppId'] : null);
      if (dynamicOneSignalId != null && dynamicOneSignalId.toString().trim().isNotEmpty) {
        final cleanId = dynamicOneSignalId.toString().trim();
        NotificationService.updateAppId(cleanId);
      }

      gameRewardedAds = appData['gameRewardedAds'] ?? false;
      final rawFollowCoins = appData['followCoins'] ?? (appData['config'] is Map ? appData['config']['followCoins'] : null);
      if (rawFollowCoins is num) {
        followCoins = rawFollowCoins.toInt();
      } else if (rawFollowCoins != null) {
        followCoins = int.tryParse(rawFollowCoins.toString()) ?? 0;
      } else {
        followCoins = 0;
      }
      shareText = appData['shareText']?.toString() ?? '';

      final rawTitle = appData['dailyTaskTitle'] ?? (appData['config'] is Map ? appData['config']['dailyTaskTitle'] : null);
      if (rawTitle != null && rawTitle.toString().trim().isNotEmpty) {
        dailyTaskTitle = rawTitle.toString().trim();
      } else {
        dailyTaskTitle = 'Daily Task';
      }

      final rawDisclaimer = appData['disclaimer'] ?? appData['defaultDisclaimer'] ?? appData['taskDisclaimer'];
      if (rawDisclaimer != null) {
        if (rawDisclaimer is List) {
          defaultDisclaimer = List<String>.from(rawDisclaimer);
        } else {
          defaultDisclaimer = [rawDisclaimer.toString()];
        }
      } else {
        defaultDisclaimer = [];
      }
      final rawConversionRate = appData['conversionRate'] ?? (appData['config'] is Map ? appData['config']['conversionRate'] : null);
      if (rawConversionRate is num && rawConversionRate > 0) {
        coinConversionRate = rawConversionRate.toInt();
      } else if (rawConversionRate != null) {
        coinConversionRate = int.tryParse(rawConversionRate.toString()) ?? 150;
      } else {
        coinConversionRate = 150;
      }

      final rawShowConversionRate = appData['showCoinConversionRate'] ?? (appData['config'] is Map ? appData['config']['showCoinConversionRate'] : null);
      if (rawShowConversionRate != null) {
        showCoinConversionRate = rawShowConversionRate == true || rawShowConversionRate.toString() == 'true';
      } else {
        showCoinConversionRate = false;
      }

      if (appData['screenSettings'] is Map) {
        screenSettings = Map<String, dynamic>.from(appData['screenSettings'] as Map);
      }
      if (appData['config'] is Map && appData['config']['hideDenomination'] is Map) {
        hideDenominationConfig = HideDenominationConfig.fromJson(
          Map<String, dynamic>.from(appData['config']['hideDenomination']),
        );
      } else if (appData['hideDenomination'] is Map) {
        hideDenominationConfig = HideDenominationConfig.fromJson(
          Map<String, dynamic>.from(appData['hideDenomination']),
        );
      }
      superOfferConfig = appData['superOfferConfig'] is Map
          ? Map<String, dynamic>.from(appData['superOfferConfig'] as Map)
          : {};
      howToUseConfig = appData['howToUseConfig'] is Map
          ? Map<String, dynamic>.from(appData['howToUseConfig'] as Map)
          : {};
      playtimeConfig = appData['playtimeConfig'] is Map
          ? Map<String, dynamic>.from(appData['playtimeConfig'] as Map)
          : (appData['playtimeOfferwall'] is Map
              ? Map<String, dynamic>.from(appData['playtimeOfferwall'] as Map)
              : (appData['playtimeBanner'] is Map
                  ? Map<String, dynamic>.from(appData['playtimeBanner'] as Map)
                  : {}));

      try {
        final List<dynamic>? rawBanners = appData['homeBanners'];
        if (rawBanners != null) {
          homeBanners = rawBanners
              .whereType<Map>()
              .map((b) => HomeBanner.fromMap(Map<String, dynamic>.from(b)))
              .where((b) => b.imageUrl.isNotEmpty && b.enabled)
              .toList();
        } else {
          homeBanners = [];
        }
      } catch (ex, st) {
        dev.log('Error parsing home banners: $ex\n$st');
        homeBanners = [];
      }

      try {
        if (appData['screenBanners'] is Map) {
          final Map<String, dynamic> rawMap = Map<String, dynamic>.from(appData['screenBanners'] as Map);
          screenBanners = rawMap.map((key, val) => MapEntry(
            key,
            val is Map ? ScreenBanner.fromMap(Map<String, dynamic>.from(val)) : const ScreenBanner(imageUrl: '', clickUrl: '', enabled: false),
          ));
        } else {
          screenBanners = {};
        }
      } catch (ex, st) {
        dev.log('Error parsing screen banners: $ex\n$st');
        screenBanners = {};
      }

      try {
        final List<dynamic>? rawMoreApps = appData['moreApps'] ?? appData['ourApps'] ?? appData['moreAppsList'];
        if (rawMoreApps != null) {
          moreApps = rawMoreApps
              .whereType<Map>()
              .map((b) => MoreAppsModel.fromMap(Map<String, dynamic>.from(b)))
              .where((b) => b.enabled)
              .toList();
        } else {
          moreApps = [];
        }
      } catch (ex, st) {
        dev.log('Error parsing moreApps: $ex\n$st');
        moreApps = [];
      }
    } catch (e, s) {
      dev.log('Error setting app data: $e\n$s');
    }
  }

  static void _fillOffersListsFromMap(Map<String, dynamic> data) {
    _surveyList.clear();
    _taskList.clear();

    // 1. Load all configured ones from the database map
    for (final entry in data.entries) {
      if (entry.value is! Map) continue;
      final configMap = Map<String, dynamic>.from(entry.value as Map);
      
      final String providerName = entry.key;
      final String category = configMap['category'] ?? 'task';

      final OffersDataModel model = OffersDataModel.fromMap({
        ...configMap,
        'providerName': providerName,
        'category': category,
      });

      if (category == 'survey') {
        _surveyList.add(model);
      } else {
        _taskList.add(model);
      }
    }

    // 2. For any standard enums not in the database, add a disabled placeholder
    // This ensures standard providers still show as locked/disabled in the UI rather than disappearing completely
    
    // Check Surveys
    for (final e in SurveyName.values) {
      final String name = _enumKey(e);
      final cleanEnumName = name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
      final hasConfig = _surveyList.any((m) => m.providerName.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '') == cleanEnumName);
      if (!hasConfig) {
        _surveyList.add(OffersDataModel(
          enabled: false,
          rank: 999,
          providerName: name,
          category: 'survey',
        ));
      }
    }

    // Check Tasks
    for (final e in TaskName.values) {
      final String name = _enumKey(e);
      final cleanEnumName = name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
      final hasConfig = _taskList.any((m) => m.providerName.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '') == cleanEnumName);
      if (!hasConfig) {
        _taskList.add(OffersDataModel(
          enabled: false,
          rank: 999,
          providerName: name,
          category: 'task',
        ));
      }
    }
  }

  static void _setApiKeyFromAppData(Map<String, dynamic> data) {
    try {
      final apiKey = data['apiKey'];
      if (apiKey != null && apiKey is String && apiKey.isNotEmpty) {
        AppConst.apiKey = apiKey;
      }
    } catch (e) {
      dev.log('Error setting API key: $e');
    }
  }

  static void _clearOffersLists() {
    _surveyList.clear();
    _taskList.clear();
  }

  // Safe enum name (works on older Dart too – avoids .name crashes)
  static String _enumKey(Object e) {
    final s = e.toString();
    final i = s.indexOf('.');
    return i == -1 ? s : s.substring(i + 1);
  }

  static Future<ServerTime> _getServerTime() async {
    try {
      final rawInput = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final encryptedPayload = SecurityService.encryptPayload(rawInput);

      final Response response = await _dio.post(
        AppConst.getServerTime,
        data: {'payload': encryptedPayload},
        options: Options(
          headers: AppConst.apiHeader,
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      Map<String, dynamic> resData = response.data is Map<String, dynamic>
          ? response.data
          : jsonDecode(response.data.toString());

      if (resData['responsePayload'] != null) {
        final decryptedStr = SecurityService.decryptPayload(resData['responsePayload'].toString());
        if (decryptedStr.isNotEmpty) {
          try {
            resData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
          } catch (_) {}
        }
      }

      if (response.statusCode == 200 && resData['status'] == 'success') {
        final data = resData;

        final int durationLeft = data['leaderboardTimeLeft'] ?? 0;
        final int currentServerTime =
            data['serverTime'] ?? DateTime.now().millisecondsSinceEpoch;

        final int targetTimestamp = currentServerTime + durationLeft;

        return ServerTime(
          leaderboardTimeLeft: targetTimestamp,
          serverTime: currentServerTime,
        );
      } else {
        return ServerTime(leaderboardTimeLeft: 0, serverTime: 0);
      }
    } catch (e) {
      dev.log('Error fetching server time: $e');
      return ServerTime(leaderboardTimeLeft: 0, serverTime: 0);
    }
  }

  static String getFormattedShareText({
    required String referralCode,
    required String referralLink,
  }) {
    if (shareText.trim().isEmpty) {
      return 'referral-invite-message'.tr(args: [referralCode, referralLink]);
    }
    String text = shareText;
    if (text.contains('{ReferCode}') || text.contains('{referCode}') || text.contains('{0}')) {
      text = text.replaceAll('{ReferCode}', referralCode)
                 .replaceAll('{referCode}', referralCode)
                 .replaceAll('{0}', referralCode);
    }
    if (text.contains('{ReferLink}') || text.contains('{referLink}') || text.contains('{1}')) {
      text = text.replaceAll('{ReferLink}', referralLink)
                 .replaceAll('{referLink}', referralLink)
                 .replaceAll('{1}', referralLink);
    }
    if (!text.contains(referralLink) && !shareText.contains('{ReferLink}') && !shareText.contains('{referLink}') && !shareText.contains('{1}')) {
      text = "$text\n\nDownload: $referralLink";
    }
    return text;
  }
}

class UserCheckResult {
  final User? user;
  final bool userNotFound;
  final bool isBlocked;
  final bool isDeleted;
  final bool isAccountDetailsCompleted;
  final Map<String, dynamic>? userData;

  UserCheckResult({
    required this.user,
    required this.userNotFound,
    this.isBlocked = false,
    this.isDeleted = false,
    this.isAccountDetailsCompleted = true,
    this.userData,
  });
}
