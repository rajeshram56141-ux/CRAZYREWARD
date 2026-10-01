import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/constant/constant.dart';
import 'super_offer_leaderboard_model.dart';

final superOfferLeaderboardProvider = FutureProvider.autoDispose.family<SuperOfferLeaderboardResponse, String>((ref, String month) async {
  final Dio dio = Dio();
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  try {
    final response = await dio.get(
      AppConst.superOfferLeaderboard,
      queryParameters: {
        if (userId.isNotEmpty) 'userId': userId,
        if (month.isNotEmpty) 'month': month,
      },
      options: Options(
        headers: {
          ...AppConst.apiHeader,
          if (userId.isNotEmpty) 'x-user-id': userId,
        },
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> data = response.data is Map<String, dynamic>
          ? response.data
          : jsonDecode(response.data.toString());
      return SuperOfferLeaderboardResponse.fromJson(data);
    }
  } catch (e) {
    print('🔥 Error fetching super offer leaderboard: $e');
  }

  return SuperOfferLeaderboardResponse(
    success: false,
    monthKey: '',
    contest: SuperOfferContest(
      title: 'Super Offer Bumper League',
      subtitle: 'Unlock maximum super offers to win Bumper Prizes!',
      bannerUrl: '',
      status: 'active',
      isActive: true,
      startTime: '',
      endTime: '',
      isWinnerDeclared: false,
      declaredAt: '',
      prizes: [],
    ),
    timeRemainingSeconds: 0,
    userStats: SuperOfferUserRankStats(rank: 0, unlockCount: 0, isInTop3: false, isInTop10: false),
    leaderboard: [],
  );
});

final superOfferWinnerHistoryProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final Dio dio = Dio();
  try {
    final response = await dio.get(
      '${AppConst.serverBaseUrl}/admin/super-offer/public-winner-history',
      options: Options(
        headers: AppConst.apiHeader,
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    if (response.statusCode == 200) {
      Map<String, dynamic> data = response.data is Map<String, dynamic>
          ? response.data
          : jsonDecode(response.data.toString());
      if (data['success'] == true && data['history'] is List) {
        return data['history'] as List<dynamic>;
      }
    }
  } catch (e) {
    print('🔥 Error fetching super offer winner history: $e');
  }
  return [];
});

