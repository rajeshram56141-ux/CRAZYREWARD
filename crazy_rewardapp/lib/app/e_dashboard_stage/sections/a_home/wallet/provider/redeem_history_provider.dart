import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../services/security_service.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../b_splash_stage/splash_service.dart';
import '../model/redeem_history_model.dart';

final payoutHistoryProvider = FutureProvider.family
    .autoDispose<List<PayoutHistoryModel>, String>((ref, String uid) async {
      final dio = Dio();

      // Fetch dynamic method titles from MongoDB wallet methods API
      final catalogTitles = <String, String>{};
      try {
        final rawInput = {
          'appName': SplashService.appName.toLowerCase(),
          'countryResident': 'GLOBAL',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        final encryptedPayload = SecurityService.encryptPayload(rawInput);

        final response = await dio.post(
          AppConst.getWalletMethods,
          data: {'payload': encryptedPayload},
          options: Options(
            headers: AppConst.apiHeader,
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
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

        if (response.statusCode == 200 && resData['success'] == true) {
          final List methods = resData['methods'] ?? [];
          for (final m in methods) {
            final methodKey = (m['methodId'] ?? m['id'])?.toString();
            if (methodKey != null && methodKey.isNotEmpty) {
              catalogTitles[methodKey] = (m['title'] ?? methodKey).toString();
            }
          }
        }
      } catch (e) {
         // debugPrint('🔥 Error fetching wallet methods for redeem history titles: $e');
      }

      // Fetch user payout history from MongoDB server API
      try {
        final user = FirebaseAuth.instance.currentUser;
        final token = await user?.getIdToken() ?? '';

        final rawInput = {
          'appName': SplashService.appName.toLowerCase(),
          'userId': uid,
          'limit': 150,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: uid);

        final response = await dio.post(
          AppConst.getPayoutHistory,
          data: {'payload': encryptedPayload},
          options: Options(
            headers: {
              ...AppConst.apiHeader,
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
              if (uid.isNotEmpty) 'x-user-id': uid,
            },
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        Map<String, dynamic> resData = response.data is Map<String, dynamic>
            ? response.data
            : jsonDecode(response.data.toString());

        if (resData['responsePayload'] != null) {
          final decryptedStr = SecurityService.decryptPayload(resData['responsePayload'].toString(), userId: uid);
          if (decryptedStr.isNotEmpty) {
            try {
              resData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
            } catch (_) {}
          }
        }

        if (response.statusCode == 200 && resData['success'] == true) {
          final List dataList = resData['history'] ?? resData['data'] ?? [];
          final seen = <String>{};
          final result = <PayoutHistoryModel>[];
          for (final item in dataList) {
            final model = PayoutHistoryModel.fromJson(Map<String, dynamic>.from(item), catalogTitles);
            final key = model.orderId.isNotEmpty
                ? model.orderId
                : '${model.timestamp.millisecondsSinceEpoch}_${model.amount}_${model.methodName}';
            if (seen.add(key)) {
              result.add(model);
            }
          }
          return result;
        }
      } catch (e) {
         // debugPrint('🔥 Error fetching payout history for redeem history screen: $e');
      }

      return const [];
    });

// Semantic & backward-compatible aliases
final redeemHistoryProvider = payoutHistoryProvider;
final withdrawalHistoryProvider = payoutHistoryProvider;
