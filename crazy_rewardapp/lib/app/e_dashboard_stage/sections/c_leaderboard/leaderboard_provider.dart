// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../services/security_service.dart';
import '../../../../utils/constant/constant.dart';
import 'leaderboard_model.dart';

final leaderboardDataProvider =
    FutureProvider.autoDispose.family<List<LeaderboardModel>, String>((
  ref,
  String docId,
) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';
    final token = await user?.getIdToken();

    final rawInput = {
      'docId': docId,
      'type': docId,
      'userId': userId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final res = await SecurityService.post(
      '${AppConst.serverBaseUrl}/api/leaderboard/top',
      body: rawInput,
      userId: userId,
      token: token,
    );

    if (res.statusCode == 200) {
      dynamic parsed = jsonDecode(res.body);
      Map<String, dynamic> resData = {};
      if (parsed is Map) {
        resData = Map<String, dynamic>.from(parsed);
      }

      if (resData['responsePayload'] != null) {
        final decryptedStr = SecurityService.decryptPayload(
          resData['responsePayload'].toString(),
          userId: userId,
        );
        if (decryptedStr.isNotEmpty) {
          try {
            final dec = jsonDecode(decryptedStr);
            if (dec is Map) {
              resData = Map<String, dynamic>.from(dec);
            }
          } catch (_) {}
        }
      }

      if (resData['success'] == true && resData['leaderboard'] != null) {
        final List<dynamic> list = resData['leaderboard'];
        final List<LeaderboardModel> models = list
            .where((item) => item is Map<String, dynamic> || item is Map)
            .map((item) => LeaderboardModel.fromMap(
                Map<String, dynamic>.from(item as Map)))
            .toList();

        if (docId == 'referralBased') {
          final filtered = models.where((m) => m.totalReferrals > 0).toList();
          filtered.sort((a, b) => b.totalReferrals.compareTo(a.totalReferrals));
          return filtered;
        } else {
          final filtered = models.where((m) => m.totalCoins > 0).toList();
          filtered.sort((a, b) => b.totalCoins.compareTo(a.totalCoins));
          return filtered;
        }
      }
    }
    return [];
  } catch (_) {
    return [];
  }
});
