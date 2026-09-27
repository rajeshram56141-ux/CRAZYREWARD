import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateConfig {
  final bool updateAvailable;
  final String latestVersion;
  final String message;

  const UpdateConfig({
    this.updateAvailable = false,
    this.latestVersion = '',
    this.message = '',
  });

  factory UpdateConfig.fromMap(Map<String, dynamic>? map, String buildNumber) {
    final data = map ?? {};

    final int currentBuild =
        int.tryParse(data['currentBuildNumber']?.toString() ?? '1') ?? 1;

    final bool updateAvailable = int.parse(buildNumber) < currentBuild;

    return UpdateConfig(
      updateAvailable: updateAvailable,
      latestVersion: data['currentVersion'] ?? '',
      message: data['message'] ?? '',
    );
  }
}

class MaintenanceConfig {
  final bool enabled;
  final Timestamp completedAt;
  final List<String> excludedUserIds;

  MaintenanceConfig({
    this.enabled = false,
    Timestamp? completedAt,
    this.excludedUserIds = const [],
  }) : completedAt = completedAt ?? Timestamp.fromDate(DateTime.now());

  bool isExcluded(String? userId) {
    if (userId == null || userId.trim().isEmpty || excludedUserIds.isEmpty) return false;
    final normalized = userId.trim().toLowerCase();
    return excludedUserIds.any((id) => id.trim().toLowerCase() == normalized);
  }

  factory MaintenanceConfig.fromMap(Map<String, dynamic>? map) {
    final data = map ?? {};
    Timestamp? parsedTimestamp;
    
    final rawVal = data['completedAt'];
    if (rawVal != null) {
      if (rawVal is Timestamp) {
        parsedTimestamp = rawVal;
      } else if (rawVal is String) {
        final parsedDt = DateTime.tryParse(rawVal);
        if (parsedDt != null) {
          parsedTimestamp = Timestamp.fromDate(parsedDt);
        }
      } else if (rawVal is int) {
        parsedTimestamp = Timestamp.fromMillisecondsSinceEpoch(rawVal);
      }
    }

    List<String> parsedExcluded = [];
    final rawExcluded = data['excludedUserIds'];
    if (rawExcluded is List) {
      parsedExcluded = rawExcluded
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawExcluded is String && rawExcluded.trim().isNotEmpty) {
      parsedExcluded = rawExcluded
          .split(RegExp(r'[\n,]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return MaintenanceConfig(
      enabled: data['enabled'] ?? false,
      completedAt: parsedTimestamp,
      excludedUserIds: parsedExcluded,
    );
  }
}


class SpinConfig {
  final int dailyMax;
  final List<int> items;
  final bool rewardedAds;

  SpinConfig({
    this.dailyMax = 0,
    this.items = const [],
    this.rewardedAds = false,
  });

  factory SpinConfig.fromMap(Map<String, dynamic>? map) {
    final data = map ?? {};

    return SpinConfig(
      dailyMax: data['dailyMax'] ?? 0,
      items: List<int>.from(data['items'] ?? []),
      rewardedAds: data['rewardedAds'] ?? false,
    );
  }
}

// streak config - coins,
class StreakConfig {
  final int coins;
  final bool rewardedAds;

  StreakConfig({this.coins = 0, this.rewardedAds = false});

  factory StreakConfig.fromMap(Map<String, dynamic>? map) {
    final data = map ?? {};

    return StreakConfig(
      coins: data['coins'] ?? 0,
      rewardedAds: data['rewardedAds'] ?? false,
    );
  }
}

class ServerTime {
  final int leaderboardTimeLeft;
  final int serverTime;

  ServerTime({required this.leaderboardTimeLeft, required this.serverTime});

  factory ServerTime.fromMap(Map<String, dynamic>? map) {
    final data = map ?? {};

    return ServerTime(
      leaderboardTimeLeft: data['leaderboardTimeLeft'] ?? 0,
      serverTime: data['serverTime'] ?? 0,
    );
  }
}

class UrlConfig {
  final String privacyPolicy;
  final String termsOfService;
  final String supportMail;
  final String whatsappLink;
  final String youtubeLink;
  final String telegramLink;
  final String instagramLink;
  final String dailyTaskTutorial;
  final String playGamesTutorial;
  final String giveawayTutorial;
  final String taskTutorial;
  final String surveyTutorial;
  final String readEarnTutorial;
  final String watchEarnTutorial;

  UrlConfig({
    this.privacyPolicy = '',
    this.termsOfService = '',
    this.supportMail = '',
    this.whatsappLink = '',
    this.youtubeLink = '',
    this.telegramLink = '',
    this.instagramLink = '',
    this.dailyTaskTutorial = '',
    this.giveawayTutorial = '',
    this.playGamesTutorial = '',
    this.readEarnTutorial = '',
    this.surveyTutorial = '',
    this.taskTutorial = '',
    this.watchEarnTutorial = '',
  });

  factory UrlConfig.fromMap(Map<String, dynamic>? map) {
    final data = map ?? {};

    return UrlConfig(
      privacyPolicy: data['privacyPolicy'] ?? '',
      termsOfService: data['termsOfService'] ?? '',
      supportMail: (data['supportMail'] ?? '').toString().trim(),
      whatsappLink: data['whatsappLink'] ?? '',
      youtubeLink: data['youtubeLink'] ?? '',
      telegramLink: data['telegramLink'] ?? '',
      instagramLink: data['instagramLink'] ?? '',
      dailyTaskTutorial: data['dailyTaskTutorial'] ?? '',
      playGamesTutorial: data['playGamesTutorial'] ?? '',
      giveawayTutorial: data['giveawayTutorial'] ?? '',
      readEarnTutorial: data['readEarnTutorial'] ?? '',
      surveyTutorial: data['surveyTutorial'] ?? '',
      taskTutorial: data['taskTutorial'] ?? '',
      watchEarnTutorial: data['watchEarnTutorial'] ?? '',
    );
  }
}

class WelcomePopupConfig {
  final bool enabled;
  final String imageUrl;
  final String title;
  final String message;
  final String buttonName;
  final String buttonClickUrl;
  final int cap;

  WelcomePopupConfig({
    this.enabled = false,
    this.imageUrl = '',
    this.title = '',
    this.message = '',
    this.buttonName = '',
    this.buttonClickUrl = '',
    this.cap = 0,
  });

  factory WelcomePopupConfig.fromMap(Map<String, dynamic>? map) {
    final data = map ?? {};
    return WelcomePopupConfig(
      enabled: data['enabled'] ?? false,
      imageUrl: data['imageUrl'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      buttonName: data['buttonName'] ?? '',
      buttonClickUrl: data['buttonClickUrl'] ?? '',
      cap: data['cap'] ?? 0,
    );
  }
}

class HomeBanner {
  final String imageUrl;
  final String clickUrl;
  final bool enabled;

  const HomeBanner({required this.imageUrl, required this.clickUrl, this.enabled = true});

  factory HomeBanner.fromMap(Map<String, dynamic> map) {
    final img = (map['imageUrl'] ?? map['image'] ?? map['bannerUrl'] ?? map['banner'])?.toString() ?? '';
    final link = (map['clickUrl'] ?? map['url'] ?? map['linkUrl'] ?? map['link'])?.toString() ?? '';
    return HomeBanner(
      imageUrl: img,
      clickUrl: link,
      enabled: map['enabled'] != false,
    );
  }
}

class ScreenBanner {
  final String imageUrl;
  final String clickUrl;
  final bool enabled;

  const ScreenBanner({
    required this.imageUrl,
    required this.clickUrl,
    this.enabled = true,
  });

  factory ScreenBanner.fromMap(Map<String, dynamic> map) {
    final img = (map['imageUrl'] ?? map['image'] ?? map['bannerUrl'] ?? map['banner'])?.toString().trim() ?? '';
    final link = (map['clickUrl'] ?? map['url'] ?? map['linkUrl'] ?? map['link'])?.toString().trim() ?? '';
    return ScreenBanner(
      imageUrl: img,
      clickUrl: link,
      enabled: map['enabled'] != false,
    );
  }
}

class AdsConfig {
  final String interstitialKey;
  final String rewardedKey;
  final String nativeKey;
  final String bannerKey;
  final bool enabled;
  final bool homeNativeEnabled;
  final bool superOfferNativeEnabled;
  final bool dailyChallengeNativeEnabled;
  final bool playGamesNativeEnabled;
  final bool watchVideoNativeEnabled;

  const AdsConfig({
    this.interstitialKey = '',
    this.rewardedKey = '',
    this.nativeKey = '',
    this.bannerKey = '',
    this.enabled = true,
    this.homeNativeEnabled = true,
    this.superOfferNativeEnabled = true,
    this.dailyChallengeNativeEnabled = true,
    this.playGamesNativeEnabled = true,
    this.watchVideoNativeEnabled = true,
  });

  factory AdsConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const AdsConfig();
    return AdsConfig(
      interstitialKey: (map['interstitialKey'] ?? '').toString().trim(),
      rewardedKey: (map['rewardedKey'] ?? '').toString().trim(),
      nativeKey: (map['nativeKey'] ?? '').toString().trim(),
      bannerKey: (map['bannerKey'] ?? '').toString().trim(),
      enabled: map['enabled'] != false,
      homeNativeEnabled: map['homeNativeEnabled'] != false,
      superOfferNativeEnabled: map['superOfferNativeEnabled'] != false,
      dailyChallengeNativeEnabled: map['dailyChallengeNativeEnabled'] != false,
      playGamesNativeEnabled: map['playGamesNativeEnabled'] != false,
      watchVideoNativeEnabled: map['watchVideoNativeEnabled'] != false,
    );
  }
}
