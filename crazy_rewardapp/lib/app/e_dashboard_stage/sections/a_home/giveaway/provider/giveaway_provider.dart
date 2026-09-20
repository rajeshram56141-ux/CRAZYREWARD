import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../../b_splash_stage/splash_service.dart';
import '../../../../../../utils/constant/constant.dart';
import '../model/giveaway_model.dart';

class GiveawayProviders {
  /// 🔹 Server Time (Single Fetch)
  static final serverTimeProvider = Provider<DateTime>((ref) {
    final millis = SplashService.serverTime.serverTime;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  });

  /// 🔹 Ticking Server Time (Auto Refresh)
  static final tickingServerTimeProvider = StreamProvider<DateTime>((ref) async* {
    while (true) {
      final baseMillis = SplashService.serverTime.serverTime;
      final fetchedAt = SplashService.serverTimeFetchedAt;
      final int currentMillis;
      if (fetchedAt == null) {
        currentMillis = baseMillis;
      } else {
        final elapsed = DateTime.now().difference(fetchedAt).inMilliseconds;
        currentMillis = baseMillis + elapsed;
      }
      yield DateTime.fromMillisecondsSinceEpoch(currentMillis);
      await Future.delayed(const Duration(seconds: 1));
    }
  });

  /// 🔹 All Giveaways Future (Fetched ONCE on screen load or refresh)
  static final giveawaysProvider = FutureProvider.autoDispose<List<GiveawayModel>>((ref) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      final res = await http.get(
        Uri.parse('${AppConst.serverBaseUrl}/api/giveaway/list?userId=$uid'),
        headers: {
          'Content-Type': 'application/json',
          ...AppConst.apiHeader.map((k, v) => MapEntry(k, v.toString())),
          if (uid.isNotEmpty) 'user-id': uid,
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['giveaways'] != null) {
          final List<dynamic> list = data['giveaways'];
          return list.map((g) => GiveawayModel.fromJson(g as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
       // debugPrint('Error fetching giveaways from MongoDB: $e');
    }
    return [];
  });

  /// 🔹 Check If Current User Joined Specific Giveaway
  static final joinedProvider = Provider.family.autoDispose<bool, (String userId, String giveawayId)>((ref, params) {
    final giveawayId = params.$2;
    final giveawaysAsync = ref.watch(giveawaysProvider);

    if (giveawaysAsync is AsyncData) {
      final list = giveawaysAsync.value ?? [];
      final matches = list.where((g) => g.id == giveawayId);
      if (matches.isNotEmpty) {
        return matches.first.joined;
      }
    }
    return false;
  });

  /// 🔹 Filter Giveaways By Status
  static final filteredGiveawaysProvider = Provider.family<List<GiveawayModel>, GiveawayStatus>((ref, status) {
    final giveawaysAsync = ref.watch(giveawaysProvider);
    final serverTime = ref.watch(tickingServerTimeProvider).value;

    if (giveawaysAsync is AsyncData && serverTime != null) {
      return giveawaysAsync.value!
          .where((g) => g.getStatus(serverTime) == status)
          .toList();
    }

    return [];
  });

  static final winnersProvider = FutureProvider.family.autoDispose<List<GiveawayWinnerModel>, String>((ref, giveawayId) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConst.serverBaseUrl}/api/giveaway/winners?giveawayId=$giveawayId'),
        headers: {
          'Content-Type': 'application/json',
          ...AppConst.apiHeader.map((k, v) => MapEntry(k, v.toString())),
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['winners'] != null) {
          final List<dynamic> list = data['winners'];
          return list.map((w) => GiveawayWinnerModel.fromMap(w as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
       // debugPrint('Error fetching winners from server: $e');
    }
    return [];
  });
}
