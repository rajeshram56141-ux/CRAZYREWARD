import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:get_storage/get_storage.dart';
import '../../../../../../services/security_service.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../../utils/helper/helper.dart';
import '../../../../b_splash_stage/splash_service.dart';
import 'daily_task_model.dart';

final dailyTaskProvider = FutureProvider.family
    .autoDispose<
      List<DailyTaskModel>,
      ({
        String userId,
        String email,
        String countryCode,
        DailyTaskType offerType,
      })
    >((ref, params) async {
      final offers = await DailyTaskService.fetchDailyTask(
        appName: SplashService.appName.lows(),
        userId: params.userId,
        email: params.email,
        countryCode: params.countryCode,
        offerType: params.offerType,
      );

      if (offers.isEmpty) {
        return const [];
      }

      // Query reward history from MongoDB using Dio
      final List<Map<String, dynamic>> rewardHistoryList = [];
      try {
        final response = await Dio().get(
          AppConst.getRewardHistory,
          queryParameters: {
            'appName': SplashService.appName.lows(),
            'userId': params.userId,
            'limit': 200,
          },
          options: Options(
            headers: AppConst.apiHeader,
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );

        if (response.statusCode == 200 && response.data['success'] == true) {
          final List rawList = response.data['data'] ?? [];
          for (final item in rawList) {
            if (item is Map) {
              rewardHistoryList.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (e) {
         // debugPrint('🔥 Error fetching reward history for daily task: $e');
      }

      final Map<String, DateTime> lastCompletionMap = {};
      final Map<String, DateTime> completedEventsMap = {};
      final Map<String, int> completionsTodayMap = {};

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      for (final data in rewardHistoryList) {
        final dynamic rawId = data['offerId'] ?? data['offerID'] ?? data['offer_id'];

        if (rawId == null) continue;

        final normalized = rawId.toString().trim().toLowerCase();
        if (normalized.isEmpty) continue;

        DateTime ts;
        final tsString = data['timestamp'];
        if (tsString != null) {
          ts = DateTime.parse(tsString).toLocal();
        } else {
          ts = DateTime.now();
        }

        if (!lastCompletionMap.containsKey(normalized) ||
            ts.isAfter(lastCompletionMap[normalized]!)) {
          lastCompletionMap[normalized] = ts;
        }

        if (ts.isAfter(todayStart)) {
          completionsTodayMap[normalized] = (completionsTodayMap[normalized] ?? 0) + 1;
        }

        final dynamic rawEventId = data['eventId'] ?? data['eventID'] ?? data['event_id'] ?? data['eventid'];
        if (rawEventId != null) {
          final normalizedEventId = rawEventId.toString().trim().toLowerCase();
          if (normalizedEventId.isNotEmpty) {
            final key = '${normalized}_$normalizedEventId';
            if (!completedEventsMap.containsKey(key) || ts.isAfter(completedEventsMap[key]!)) {
              completedEventsMap[key] = ts;
            }
          }
        }
      }

      final updatedOffers = await Future.wait(offers.map((offer) async {
        final normalizedId = offer.offerId.trim().toLowerCase();

        // ========== MULTI-EVENT TASKS ==========
        if (offer.hasEvents && offer.events.isNotEmpty) {
          final updatedEvents = offer.events.map((e) {
            final key = '${normalizedId}_${e.eventId.trim().toLowerCase()}';
            final completedAt = completedEventsMap[key];

            bool isEventCompleted = e.completed;
            if (completedAt != null) {
              if (offer.dailyReset) {
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                isEventCompleted = completedAt.isAfter(todayStart);
              } else {
                isEventCompleted = true;
              }
            }

            if (isEventCompleted) {
              return DailyTaskEvent(
                eventId: e.eventId,
                name: e.name,
                coins: e.coins,
                payout: e.payout,
                completed: true,
                completedAt: completedAt ?? e.completedAt ?? DateTime.now(),
                status: 'completed',
                timerDuration: e.timerDuration,
              );
            }
            return e;
          }).toList();

          return DailyTaskModel(
            offerId: offer.offerId,
            offerName: offer.offerName,
            offerDescription: offer.offerDescription,
            offerDisclaimer: offer.offerDisclaimer,
            imagePath: offer.imagePath,
            bannerPath: offer.bannerPath,
            offerType: offer.offerType,
            offerCategory: offer.offerCategory,
            coins: offer.coins,
            redirectionUrl: offer.redirectionUrl,
            trackingTime: offer.trackingTime,
            reelFormat: offer.reelFormat,
            timestamp: offer.timestamp,
            color: offer.color,
            hasEvents: offer.hasEvents,
            events: updatedEvents,
            dailyReset: offer.dailyReset,
            packageEnabled: offer.packageEnabled,
            packageName: offer.packageName,
            timerEnabled: offer.timerEnabled,
            timerDuration: offer.timerDuration,
            dailyRewardEnabled: offer.dailyRewardEnabled,
            watchTutorial: offer.watchTutorial,
            videoVerificationEnabled: offer.videoVerificationEnabled,
            videoVerificationId: offer.videoVerificationId,
            perUserDailyCap: offer.perUserDailyCap,
          );
        }

        // ========== SINGLE-EVENT TASKS ==========
        final lastCompleted = lastCompletionMap[normalizedId];
        if (lastCompleted != null) {
          bool isTaskCompleted = false;
          if (offer.offerType == 'WatchEarn' && offer.perUserDailyCap != null && offer.perUserDailyCap! > 0) {
            final completionsToday = completionsTodayMap[normalizedId] ?? 0;
            isTaskCompleted = completionsToday >= offer.perUserDailyCap!;
          } else if (offer.dailyReset) {
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            isTaskCompleted = lastCompleted.isAfter(todayStart);
          } else {
            isTaskCompleted = true;
          }

          if (isTaskCompleted) {
            final updatedEvents = offer.events.isNotEmpty
                ? offer.events.map((e) {
                    return DailyTaskEvent(
                      eventId: e.eventId,
                      name: e.name,
                      coins: e.coins,
                      payout: e.payout,
                      completed: true,
                      completedAt: lastCompleted,
                      status: 'completed',
                      timerDuration: e.timerDuration,
                    );
                  }).toList()
                : [
                    DailyTaskEvent(
                      eventId: '__single__',
                      name: 'Complete Task',
                      coins: offer.coins,
                      payout: offer.coins / 100.0,
                      completed: true,
                      completedAt: lastCompleted,
                      status: 'completed',
                      timerDuration: offer.timerDuration,
                    )
                  ];

            return DailyTaskModel(
              offerId: offer.offerId,
              offerName: offer.offerName,
              offerDescription: offer.offerDescription,
              offerDisclaimer: offer.offerDisclaimer,
              imagePath: offer.imagePath,
              bannerPath: offer.bannerPath,
              offerType: offer.offerType,
              offerCategory: offer.offerCategory,
              coins: offer.coins,
              redirectionUrl: offer.redirectionUrl,
              trackingTime: offer.trackingTime,
              reelFormat: offer.reelFormat,
              timestamp: offer.timestamp,
              color: offer.color,
              hasEvents: offer.hasEvents,
              events: updatedEvents,
              dailyReset: offer.dailyReset,
              packageEnabled: offer.packageEnabled,
              packageName: offer.packageName,
              timerEnabled: offer.timerEnabled,
              timerDuration: offer.timerDuration,
              dailyRewardEnabled: offer.dailyRewardEnabled,
              watchTutorial: offer.watchTutorial,
              videoVerificationEnabled: offer.videoVerificationEnabled,
              videoVerificationId: offer.videoVerificationId,
              perUserDailyCap: offer.perUserDailyCap,
            );
          }
        }

        return offer;
      }));

      final filteredOffers = <DailyTaskModel>[];
      final storage = GetStorage();
      for (final offer in updatedOffers) {
        if (offer.packageEnabled && offer.packageName.trim().isNotEmpty) {
          final pkg = offer.packageName.trim();
          final started = storage.read<bool>('started_${offer.offerId}') ?? false;
          final redirected = storage.read<bool>('redirected_${offer.offerId}') ?? false;
          final hasProgress = started ||
              redirected ||
              (offer.hasEvents &&
                  offer.events.any((e) => e.completed || e.status == 'completed'));
          if (!hasProgress) {
            final wasPreInstalled =
                (storage.read<bool>('pre_installed_${offer.offerId}') ?? false) ||
                (storage.read<bool>('pre_installed_pkg_$pkg') ?? false);
            if (wasPreInstalled) {
              continue;
            }
            final installed = await AppManager.isAppInstalled(pkg);
            if (installed) {
              await storage.write('pre_installed_${offer.offerId}', true);
              await storage.write('pre_installed_pkg_$pkg', true);
              continue;
            }
          }
        }
        filteredOffers.add(offer);
      }

      return filteredOffers.where((offer) {
        if (offer.hasEvents && offer.events.isNotEmpty) {
          if (offer.dailyReset) return true;
          if (offer.dailyRewardEnabled) {
            return !offer.events.every((e) => e.completed || e.status == 'completed');
          }
          return !offer.events.every((e) => e.completed);
        }
        if (offer.dailyReset) return true;
        return !(offer.events.isNotEmpty && offer.events.first.completed);
      }).toList();
    });

/// History provider for completed tasks
final dailyTaskHistoryProvider = FutureProvider.family<
  List<DailyTaskModel>,
  ({
    String userId,
    String email,
    String countryCode,
    DailyTaskType offerType,
  })
>((ref, params) async {
      final offers = await DailyTaskService.fetchDailyTask(
        appName: SplashService.appName.lows(),
        userId: params.userId,
        email: params.email,
        countryCode: params.countryCode,
        offerType: params.offerType,
        includeCompleted: true,
      );

      if (offers.isEmpty) {
        return const [];
      }

      return offers.where((offer) {
        final storage = GetStorage();
        final redirected = storage.read<bool>('redirected_${offer.offerId}') ?? false;
        final started = storage.read<bool>('started_${offer.offerId}') ?? false;
        if (redirected || started) return true;

        if (offer.hasEvents && offer.events.isNotEmpty) {
          return offer.events.any((e) => e.completed || e.status == 'completed');
        }
        return offer.events.isNotEmpty &&
            (offer.events.first.completed || offer.events.first.status == 'completed');
      }).toList();
    });

class DailyTaskService {
  static final Dio _dio = Dio();

  static Future<List<DailyTaskModel>> fetchDailyTask({
    required String appName,
    required String email,
    required String userId,
    required String countryCode,
    required DailyTaskType offerType,
    bool includeCompleted = false,
  }) async {
    try {
      final cleanAppName = appName.trim().isEmpty ? SplashService.appName : appName.trim();
      final cleanCountryCode = countryCode.trim();
      final cleanUserId = userId.trim();
      final cleanEmail = email.trim();

      final rawInput = {
        'appName': cleanAppName,
        'userId': cleanUserId,
        'email': cleanEmail,
        'countryCode': cleanCountryCode,
        'offerType': DailyTaskType.getName(offerType),
        if (includeCompleted) 'includeCompleted': true,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: cleanUserId);

      final Response response = await _dio.request(
        AppConst.fetchDailyTask,
        data: {'payload': encryptedPayload},
        options: Options(
          headers: {
            ...AppConst.apiHeader,
            if (cleanUserId.isNotEmpty) 'x-user-id': cleanUserId,
          },
          method: 'POST',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      Map<String, dynamic> resData = response.data is Map<String, dynamic>
          ? response.data
          : jsonDecode(response.data.toString());

      if (resData['responsePayload'] != null) {
        final decryptedStr = SecurityService.decryptPayload(resData['responsePayload'].toString(), userId: cleanUserId);
        if (decryptedStr.isNotEmpty) {
          try {
            resData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
          } catch (_) {}
        }
      }

      if (response.statusCode == 200 && resData['success'] == true) {
        final rawOffers = resData['offers'] as List;
        final parsedOffers = List<DailyTaskModel>.from(
          rawOffers.map((x) => DailyTaskModel.fromJson(x)),
        );
        return parsedOffers;
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<String?> dailyTaskPostback({
    required String userId,
    required String email,
    required String offerId,
    required String appName,
    String? packageName,
    int? elapsedSeconds,
    String? eventId,
  }) async {
    try {
      final rawInput = {
        'appName': appName,
        'userId': userId,
        'email': email,
        'offerId': offerId,
        if (packageName != null && packageName.isNotEmpty) 'packageName': packageName,
        if (elapsedSeconds != null) 'elapsedSeconds': elapsedSeconds,
        if (eventId != null && eventId.isNotEmpty) 'eventId': eventId,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: userId);

      final response = await _dio.post(
        AppConst.dailyTaskPostback,
        data: {'payload': encryptedPayload},
        options: Options(
          headers: {
            ...AppConst.apiHeader,
            if (userId.isNotEmpty) 'x-user-id': userId,
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> resData = response.data is Map<String, dynamic>
            ? response.data
            : jsonDecode(response.data.toString());

        if (resData['responsePayload'] != null) {
          final decryptedStr = SecurityService.decryptPayload(resData['responsePayload'].toString(), userId: userId);
          if (decryptedStr.isNotEmpty) {
            try {
              resData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
            } catch (_) {}
          }
        }

        if (resData['success'] == true) {
          return null; // Success
        } else {
          return resData['message'] as String? ?? 'Failed to complete task.';
        }
      }
      return 'Server error: ${response.statusCode}';
    } catch (e) {
      return 'Network error: $e';
    }
  }

  static Future<DailyTaskModel?> fetchSingleTask({
    required String appName,
    required String email,
    required String userId,
    required String countryCode,
    required DailyTaskType offerType,
    required String offerId,
  }) async {
    try {
      final cleanAppName = appName.trim().isEmpty ? AppConst.defaultAppName : appName.trim();
      final cleanCountryCode = countryCode.trim().isEmpty ? 'IN' : countryCode.trim();

      final rawInput = {
        'appName': cleanAppName,
        'userId': userId,
        'email': email,
        'countryCode': cleanCountryCode,
        'offerType': DailyTaskType.getName(offerType),
      };

      final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: userId);

      final Response response = await _dio.request(
        AppConst.fetchDailyTask,
        data: {'payload': encryptedPayload},
        options: Options(
          headers: {
            ...AppConst.apiHeader,
            if (userId.isNotEmpty) 'x-user-id': userId,
          },
          method: 'POST',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> resData = response.data is Map<String, dynamic>
            ? response.data
            : jsonDecode(response.data.toString());

        if (resData['responsePayload'] != null) {
          final decryptedStr = SecurityService.decryptPayload(resData['responsePayload'].toString(), userId: userId);
          if (decryptedStr.isNotEmpty) {
            try {
              resData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
            } catch (_) {}
          }
        }

        if (resData['success'] == true) {
          final List<dynamic> offers = resData['offers'] ?? [];
          // Find the specific offer by offerId
          final match = offers.firstWhere(
            (o) => o['offerId'] == offerId,
            orElse: () => null,
          );
          if (match != null) {
            return DailyTaskModel.fromJson(match);
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
