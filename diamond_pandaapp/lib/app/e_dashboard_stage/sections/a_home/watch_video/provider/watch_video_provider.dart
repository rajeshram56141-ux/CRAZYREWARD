import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../services/security_service.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../../utils/helper/helper.dart';
import '../../../../../b_splash_stage/splash_service.dart';
import '../../daily_task/daily_task_model.dart';

final watchVideoProvider = FutureProvider.family
    .autoDispose<
      List<DailyTaskModel>,
      ({
        String userId,
        String email,
        String countryCode,
      })
    >((ref, params) async {
      final offers = await WatchVideoService.fetchWatchVideoTasks(
        appName: SplashService.appName.lows(),
        userId: params.userId,
        email: params.email,
        countryCode: params.countryCode,
      );
      return offers;
    });

class WatchVideoService {
  static final Dio _dio = Dio();

  static Future<List<DailyTaskModel>> fetchWatchVideoTasks({
    required String appName,
    required String email,
    required String userId,
    required String countryCode,
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
      };

      final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: cleanUserId);



      final Response response = await _dio.request(
        AppConst.fetchWatchEarnTasks,
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
    } catch (e) {
      return [];
    }
  }

  static Future<String?> watchVideoPostback({
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
        AppConst.watchEarnPostback,
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
}
