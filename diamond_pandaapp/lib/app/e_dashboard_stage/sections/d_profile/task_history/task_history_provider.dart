import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/constant/constant.dart';
import '../../../../b_splash_stage/splash_service.dart';
import 'task_history_model.dart';

final rewardHistoryProvider = FutureProvider.autoDispose
    .family<List<CoinHistoryModel>, String>((ref, String userId) async {
      // 1. Fetch completed tasks from server backend API (MongoDB)
      final Dio dio = Dio();
      final List<CoinHistoryModel> list = [];
      final appName = SplashService.appName.toLowerCase();

      try {
        final Response response = await dio.get(
          AppConst.getRewardHistory,
          queryParameters: {
            'appName': appName,
            'userId': userId,
            'limit': 150,
          },
          options: Options(
            headers: {
              ...AppConst.apiHeader,
              'x-user-id': userId,
            },
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        if (response.statusCode == 200 && response.data['success'] == true) {
          final List dataList = response.data['data'] ?? [];
          for (final item in dataList) {
            final coins = (item['coins'] ?? 0.0).toDouble();
            final rewardType = item['rewardType']?.toString().toLowerCase();
            String title = (item['provider'] ?? 'Task Reward').toString();

            // Filter out 0 coin items or gem unlock records from Coin History
            if (coins == 0.0 || rewardType == 'gem' || title.toLowerCase().contains('unlock')) {
              continue;
            }

            final tsString = item['timestamp'];
            Timestamp ts;
            if (tsString != null) {
              ts = Timestamp.fromDate(DateTime.parse(tsString));
            } else {
              ts = Timestamp.now();
            }

            if (title.toLowerCase() == 'referral_mission') {
              title = 'Referral Mission';
            }

            list.add(CoinHistoryModel(
              title: title,
              coins: coins,
              timestamp: ts,
              type: CoinHistoryType.task,
            ));
          }
        }
      } catch (_) {}

      // 2. Fetch withdrawal requests from server backend API (MongoDB)
      final catalogTitles = <String, String>{};
      try {
        final response = await dio.get(
          AppConst.getWalletMethods,
          queryParameters: {
            'appName': appName,
            'countryResident': 'GLOBAL',
          },
          options: Options(
            headers: AppConst.apiHeader,
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
        if (response.statusCode == 200 && response.data['success'] == true) {
          final List methods = response.data['methods'] ?? [];
          for (final m in methods) {
            catalogTitles[m['id']] = m['title'] ?? m['id'];
          }
        }
      } catch (_) {}

      try {
        final Response response = await dio.get(
          AppConst.getPayoutHistory,
          queryParameters: {
            'appName': appName,
            'userId': userId,
            'limit': 150,
            'excludeFailed': 'true',
          },
          options: Options(
            headers: {
              ...AppConst.apiHeader,
              'x-user-id': userId,
            },
            sendTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

        if (response.statusCode == 200 && response.data['success'] == true) {
          final List dataList = response.data['data'] ?? [];
          for (final item in dataList) {
            final cleanStatus = (item['status'] ?? '').toString().trim().toLowerCase();
            // Exclude failed / rejected / refunded withdrawals from coin history
            if (cleanStatus == 'failed' ||
                cleanStatus == 'rejected' ||
                cleanStatus == 'refund' ||
                cleanStatus == 'refunded') {
              continue;
            }

            final tsString = item['timestamp'];
            Timestamp ts;
            if (tsString != null) {
              ts = Timestamp.fromDate(DateTime.parse(tsString));
            } else {
              ts = Timestamp.now();
            }

            final method = item['methodName'] ?? 'Redeem';
            
            String resolvedTitle = '';
            if (catalogTitles.containsKey(method)) {
              resolvedTitle = catalogTitles[method]!;
            } else if (item.containsKey('title') && item['title'] != null) {
              resolvedTitle = item['title'];
            } else {
              resolvedTitle = method.toString().replaceAll('_', ' ').toUpperCase();
            }

            list.add(CoinHistoryModel(
              title: resolvedTitle,
              coins: (item['coins'] ?? 0.0).toDouble(),
              timestamp: ts,
              type: CoinHistoryType.withdrawal,
              status: item['status'],
            ));
          }
        }
      } catch (_) {}

      // 3. Sort by timestamp descending (newest first)
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return list;
    });
