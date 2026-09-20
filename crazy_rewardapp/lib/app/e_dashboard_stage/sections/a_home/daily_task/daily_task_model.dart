import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DailyTaskType {
  dailyTask,
  watchEarn;

  static String getName(DailyTaskType type) {
    switch (type) {
      case DailyTaskType.dailyTask:
        return 'DailyTask';
      case DailyTaskType.watchEarn:
        return 'WatchEarn';
    }
  }
}

class DailyTaskEvent {
  final String eventId;
  final String name;
  final int coins;
  final double payout;
  final bool completed;
  final DateTime? completedAt;
  final String status; // 'completed', 'active', 'locked'
  final int timerDuration;
  final String label;
  final String redirectionUrl;

  DailyTaskEvent({
    required this.eventId,
    required this.name,
    required this.coins,
    required this.payout,
    required this.completed,
    required this.status,
    this.completedAt,
    this.timerDuration = 0,
    this.label = '',
    this.redirectionUrl = '',
  });

  factory DailyTaskEvent.fromJson(Map<String, dynamic> json) {
    return DailyTaskEvent(
      eventId: json['eventId'] as String? ?? '',
      name: json['name'] as String? ?? 'Task',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      payout: (json['payout'] as num?)?.toDouble() ?? 0.0,
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      status: json['status'] as String? ?? 'active',
      timerDuration: (json['timerDuration'] as num?)?.toInt() ?? 0,
      label: json['label'] as String? ??
          json['levelText'] as String? ??
          json['eventLabel'] as String? ??
          '',
      redirectionUrl: json['redirectionUrl'] as String? ?? '',
    );
  }
}

class DailyTaskModel {
  final String offerId;
  final String offerName;
  final List<String> offerDescription;
  final List<String> offerDisclaimer;
  final String imagePath;
  final String bannerPath;
  final String offerType;
  final String offerCategory;
  final int coins;
  final String redirectionUrl;
  final int trackingTime;
  final bool reelFormat;
  final DateTime timestamp;
  final Color color;
  // Multi-event support
  final bool hasEvents;
  final List<DailyTaskEvent> events;
  final bool dailyReset;
  // Package & Timer fields
  final bool packageEnabled;
  final String packageName;
  final bool timerEnabled;
  final int timerDuration;
  final bool dailyRewardEnabled;
  final String watchTutorial;
  final String subDescription;
  final bool videoVerificationEnabled;
  final String videoVerificationId;
  final int? perUserDailyCap;
  final String rating;
  final String downloads;
  final bool screenshotVerificationEnabled;

  DailyTaskModel({
    required this.offerId,
    required this.offerName,
    required this.offerDescription,
    required this.imagePath,
    required this.bannerPath,
    required this.offerType,
    required this.offerCategory,
    required this.coins,
    required this.redirectionUrl,
    required this.trackingTime,
    required this.reelFormat,
    required this.timestamp,
    required this.color,
    required this.offerDisclaimer,
    this.hasEvents = false,
    this.events = const [],
    this.dailyReset = false,
    this.packageEnabled = false,
    this.packageName = '',
    this.timerEnabled = false,
    this.timerDuration = 0,
    this.dailyRewardEnabled = false,
    this.watchTutorial = '',
    this.subDescription = '',
    this.videoVerificationEnabled = false,
    this.videoVerificationId = '',
    this.perUserDailyCap,
    this.rating = '',
    this.downloads = '',
    this.screenshotVerificationEnabled = false,
  });

  factory DailyTaskModel.fromJson(Map<String, dynamic> json) {
    final eventsJson = json['events'] as List?;
    final events = eventsJson != null
        ? eventsJson.map((e) => DailyTaskEvent.fromJson(e)).toList()
        : <DailyTaskEvent>[];

    return DailyTaskModel(
      offerId: json['offerId'] as String? ?? '',
      offerName: json['offerName'] as String? ?? '',
      offerDescription: json['offerDescription'] != null
          ? List<String>.from(json['offerDescription'] as List)
          : (json['description'] != null
              ? (json['description'] is List
                  ? List<String>.from(json['description'] as List)
                  : [json['description'].toString()])
              : const <String>[]),
      offerDisclaimer: json['offerDisclaimer'] != null
          ? List<String>.from(json['offerDisclaimer'] as List)
          : (json['disclaimer'] != null
              ? (json['disclaimer'] is List
                  ? List<String>.from(json['disclaimer'] as List)
                  : [json['disclaimer'].toString()])
              : (json['offer_disclaimer'] != null
                  ? List<String>.from(json['offer_disclaimer'] as List)
                  : const <String>[])),
      imagePath: json['imagePath'] as String? ??
          json['image'] as String? ??
          json['icon'] as String? ??
          json['iconUrl'] as String? ??
          json['image_path'] as String? ??
          '',
      bannerPath: json['bannerPath'] as String? ??
          json['banner'] as String? ??
          json['bannerUrl'] as String? ??
          json['banner_path'] as String? ??
          '',
      offerType: json['offerType'] as String? ?? '',
      offerCategory: json['offerCategory'] as String? ?? '',
      coins: () {
        final parsedCoins = (json['coins'] as num?)?.toInt() ?? 0;
        if (parsedCoins > 0) return parsedCoins;
        if (events.isNotEmpty) {
          final eventSum = events.fold<int>(0, (sum, e) => sum + e.coins);
          if (eventSum > 0) return eventSum;
        }
        return 0;
      }(),
      redirectionUrl: json['redirectionUrl'] as String? ?? '',
      trackingTime: (json['trackingTime'] as num?)?.toInt() ?? 0,
      reelFormat: json['reelFormat'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      color: _parseColor(json['color']),
      hasEvents: json['hasEvents'] as bool? ?? false,
      events: events,
      dailyReset: json['dailyReset'] as bool? ?? false,
      packageEnabled: json['packageEnabled'] as bool? ?? false,
      packageName: json['packageName'] as String? ?? '',
      timerEnabled: json['timerEnabled'] as bool? ?? false,
      timerDuration: (json['timerDuration'] as num?)?.toInt() ?? 0,
      dailyRewardEnabled: json['dailyRewardEnabled'] as bool? ?? false,
      watchTutorial: json['watchTutorial'] as String? ?? '',
      subDescription: json['subDescription'] as String? ?? '',
      videoVerificationEnabled: json['videoVerificationEnabled'] as bool? ?? false,
      videoVerificationId: json['videoVerificationId'] as String? ?? '',
      perUserDailyCap: (json['perUserDailyCap'] as num?)?.toInt(),
      rating: json['rating'] as String? ?? '',
      downloads: json['downloads'] as String? ?? '',
      screenshotVerificationEnabled: json['screenshotVerificationEnabled'] as bool? ?? false,
    );
  }

  String getRedirectionUrlForEvent(String eventId) {
    if (events.isNotEmpty) {
      for (final e in events) {
        if (e.eventId == eventId && e.redirectionUrl.isNotEmpty) {
          return e.redirectionUrl;
        }
      }
    }
    return redirectionUrl.replaceAll('{eventId}', eventId);
  }

  bool get isTaskCompleted {
    if (events.isNotEmpty) {
      if (dailyRewardEnabled) {
        return events.every((e) => e.status == 'completed' || e.completed);
      }
      return events.every((e) => e.completed);
    }
    return false;
  }

  bool get isTaskActive {
    if (isTaskCompleted) return false;
    if (events.isNotEmpty) {
      return events.any((e) => e.completed || e.status == 'completed');
    }
    return false;
  }

  bool get isTaskNew => !isTaskCompleted && !isTaskActive;

  String get cleanSubtitle {
    final raw = subDescription.trim().isNotEmpty
        ? subDescription.trim()
        : (offerDescription.isNotEmpty
            ? offerDescription[0].trim()
            : 'Play & earn rewards');

    if (raw.contains(':::')) {
      final parts = raw.split(':::');
      final p0 = parts[0].trim();
      final p1 = parts.length > 1 ? parts[1].trim() : '';
      if (p1.isNotEmpty && p1.toLowerCase() != p0.toLowerCase()) {
        return p1;
      }
      if (p0.isNotEmpty) {
        return p0;
      }
    }
    return raw;
  }

  static Color _parseColor(String color) {
    if (color.startsWith('#')) {
      return Color(int.parse(color.replaceFirst('#', '0xff')));
    }

    if (color.startsWith('rgb')) {
      final values = color
          .replaceAll(RegExp(r'[^0-9,]'), '')
          .split(',')
          .map(int.parse)
          .toList();

      return Color.fromRGBO(values[0], values[1], values[2], 1);
    }

    return Colors.grey;
  }
}

class AppManager {
  static const _channel = MethodChannel('com.crazyreward.games/app_manager');

  static Future<bool> isAppInstalled(String packageName) async {
    if (packageName.isEmpty) return false;
    try {
      final bool result = await _channel.invokeMethod<bool>('isAppInstalled', {'packageName': packageName}) ?? false;
      return result;
    } catch (e) {
       // debugPrint('Error checking app install: $e');
      return false;
    }
  }

  static Future<bool> launchApp(String packageName) async {
    if (packageName.isEmpty) return false;
    try {
      final bool result = await _channel.invokeMethod<bool>('launchApp', {'packageName': packageName}) ?? false;
      return result;
    } catch (e) {
       // debugPrint('Error launching app: $e');
      return false;
    }
  }

  static Future<int> getInstallTime(String packageName) async {
    if (packageName.isEmpty) return 0;
    try {
      final int result = await _channel.invokeMethod<int>('getInstallTime', {'packageName': packageName}) ?? 0;
      return result;
    } catch (e) {
       // debugPrint('Error getting app install time: $e');
      return 0;
    }
  }

  static Future<bool> checkUsagePermission() async {
    try {
      final bool result = await _channel.invokeMethod<bool>('checkUsagePermission') ?? false;
      return result;
    } catch (e) {
       // debugPrint('Error checking usage permission: $e');
      return false;
    }
  }

  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (e) {
       // debugPrint('Error opening usage settings: $e');
    }
  }

  static Future<int> getAppUsageDuration(String packageName, int startTimeMs) async {
    if (packageName.isEmpty) return 0;
    try {
      final int result = await _channel.invokeMethod<int>('getAppUsageDuration', {
        'packageName': packageName,
        'startTimeMs': startTimeMs,
      }) ?? 0;
      return result;
    } catch (e) {
       // debugPrint('Error getting app usage duration: $e');
      return 0;
    }
  }
}
