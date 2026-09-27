import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../services/security_service.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../../../../utils/constant/constant.dart';
import 'read_tsk_model.dart';

typedef ReadTskParams = ({String userId, String appName});

final readTskProvider = FutureProvider.autoDispose.family<ReadTskModel?, ReadTskParams>((
  ref,
  params,
) async {
  return ReadTskService.fetchReadTskOffer(
    appName: params.appName,
    userId: params.userId,
  );
});

final readTskHistoryProvider =
    FutureProvider.autoDispose.family<List<ReadTskHistoryModel>, String>((ref, uid) async {
      final Dio dio = Dio();
      final List<ReadTskHistoryModel> list = [];
      final appName = SplashService.appName.toLowerCase();

      try {
        final rawInput = {
          'appName': appName,
          'userId': uid,
          'limit': 100,
        };
        final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: uid);

        final Response response = await dio.post(
          AppConst.getRewardHistory,
          data: {'payload': encryptedPayload},
          options: Options(
            headers: {
              ...AppConst.apiHeader,
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
          final List dataList = resData['data'] ?? [];
          final validProviders = {
            'read & earn', 'read&earn', 'read and earn', 'readandearn',
            'read earn', 'readearn', 'read & reward', 'read&reward',
            'read and reward', 'readandreward', 'read reward', 'readreward',
            'read task', 'readtask', 'read tsk', 'readtsk'
          };

          for (final item in dataList) {
            final providerName = (item['provider'] ?? '').toString().toLowerCase().trim();
            if (validProviders.contains(providerName)) {
              final tsString = item['timestamp'];
              DateTime tsDate;
              if (tsString != null) {
                final parsed = DateTime.tryParse(tsString.toString());
                tsDate = parsed != null ? parsed.toLocal() : DateTime.now();
              } else {
                tsDate = DateTime.now();
              }

              list.add(ReadTskHistoryModel(
                offerId: (item['offerId'] ?? item['provider'] ?? 'Read & Earn').toString(),
                coins: (item['coins'] as num?)?.toInt() ?? 0,
                timestamp: tsDate,
              ));
            }
          }
        }
      } catch (_) {}

      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });

class ReadTskService {
  static final Dio _dio = Dio();

  static Future<ReadTskModel?> fetchReadTskOffer({
    required String appName,
    required String userId,
  }) async {
    final cleanUserId = userId.trim();
    final cleanAppName = appName.trim();

    if (cleanUserId.isEmpty) {
      return null;
    }

    try {
      final rawInput = {
        'appName': cleanAppName,
        'userId': cleanUserId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: cleanUserId);

      final response = await _dio.post(
        AppConst.fetchReadTskUrl,
        data: {'payload': encryptedPayload},
        options: Options(
          headers: {
            ...AppConst.apiHeader,
            if (cleanUserId.isNotEmpty) 'x-user-id': cleanUserId,
          },
          validateStatus: (status) => status != null && status < 500,
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
        final model = ReadTskModel.fromJson(resData);
        return model;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> readTskPostback({
    required String appName,
    required String userId,
    required String offerId,
    String? token,
  }) async {
    try {
      final rawInput = {
        'appName': appName,
        'userId': userId,
        'offerId': offerId,
        if (token != null) 'token': token,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: userId);

      final response = await _dio.post(
        AppConst.readTskPostback,
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

      return response.statusCode == 200 && resData['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
