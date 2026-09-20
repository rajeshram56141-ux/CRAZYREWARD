import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/cloud_functions.dart';
import '../../../../../services/security_service.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../model/refer_history_model.dart';
import '../model/referral_level_model.dart';

class ReferralStatsData {
  final int totalReferred;
  final bool missionsEnabled;
  final String missionsSubtitle;
  final List<ReferralMissionModel> missions;
  final List<String> claimedMissions;
  final List<ReferHistoryModel> referredUsers;
  final String rewardMode;
  final int allCommissionPercent;

  const ReferralStatsData({
    this.totalReferred = 0,
    this.missionsEnabled = false,
    this.missionsSubtitle = '',
    this.missions = const [],
    this.claimedMissions = const [],
    this.referredUsers = const [],
    this.rewardMode = 'all',
    this.allCommissionPercent = 10,
  });
}

class ReferralService {
  ReferralService._();

  static Future<Map<String, dynamic>> _fetchReferralData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final userId = user?.uid ?? '';

      final rawInput = {
        'userId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final res = await SecurityService.post(
        '${AppConst.serverBaseUrl}/api/referral/stats',
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
        return resData;
      }
    } catch (_) {}
    return {'success': false, 'referredUsers': [], 'claimedMissions': []};
  }

  static Future<ReferralStatsData> getReferralStats() async {
    final data = await _fetchReferralData();

    final totalCount = (data['totalReferred'] as num?)?.toInt() ?? 0;
    final bool missionsEnabled = data.containsKey('missionsEnabled')
        ? (data['missionsEnabled'] == true)
        : (data.containsKey('missions_enabled')
            ? (data['missions_enabled'] == true)
            : SplashService.referralSettings.missionsEnabled);

    List<ReferralMissionModel> missions = [];
    final rawMissions = data['missions'];
    if (rawMissions is List && rawMissions.isNotEmpty) {
      missions = rawMissions
          .where((m) => m is Map<String, dynamic> || m is Map)
          .map((m) => ReferralMissionModel.fromMap(
              Map<String, dynamic>.from(m as Map)))
          .where((m) => m.enabled && m.target > 0)
          .toList()
        ..sort((a, b) => a.target.compareTo(b.target));
    } else {
      missions = SplashService.referralSettings.missions;
    }

    final rawClaimed = data['claimedMissions'];
    List<String> claimed = [];
    if (rawClaimed is List) {
      claimed = rawClaimed.map((e) => e.toString()).toList();
    }

    final String missionsSubtitle = (data['missionsSubtitle'] ??
            data['missionsDescription'] ??
            SplashService.referralSettings.missionsSubtitle)
        .toString();

    final List<dynamic> list = data['referredUsers'] ?? [];
    final users = list.map<ReferHistoryModel>((item) {
      final map = item as Map<String, dynamic>;
      return ReferHistoryModel(
        name: map['displayName'] ?? map['name'] ?? '',
        photoUrl: map['photoUrl'] ?? '',
        coins: (map['coins'] as num?)?.toDouble() ?? 0.0,
        level: 1,
        inviterName: '',
        userId: map['userId'] ?? '',
      );
    }).toList();

    final String rewardMode = (data['rewardMode'] ?? SplashService.referralSettings.rewardMode).toString();
    final int allCommissionPercent = (data['allCommissionPercent'] as num?)?.toInt() ?? SplashService.referralSettings.allCommissionPercent;

    if (data.containsKey('rewardMode') || data.containsKey('allCommissionPercent')) {
      SplashService.referralSettings = SplashService.referralSettings.copyWith(
        rewardMode: rewardMode,
        allCommissionPercent: allCommissionPercent,
      );
    }

    return ReferralStatsData(
      totalReferred: totalCount,
      missionsEnabled: missionsEnabled,
      missionsSubtitle: missionsSubtitle,
      missions: missions,
      claimedMissions: claimed,
      referredUsers: users,
      rewardMode: rewardMode,
      allCommissionPercent: allCommissionPercent,
    );
  }

  static Future<int> getTotalCount() async {
    final stats = await getReferralStats();
    return stats.totalReferred;
  }

  static Future<double> getTotalEarning() async {
    return 0.0;
  }

  static Future<List<String>> getClaimedMissions() async {
    final stats = await getReferralStats();
    return stats.claimedMissions;
  }

  static Future<List<ReferralMissionModel>> getActiveMissions() async {
    final stats = await getReferralStats();
    return stats.missions;
  }

  static Future<Map<String, dynamic>> claimMission(int target) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final userId = user?.uid ?? '';

      final rawInput = {
        'userId': userId,
        'target': target,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final res = await SecurityService.post(
        '${AppConst.serverBaseUrl}/api/referral/claim-mission',
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
              if (dec is Map) resData = Map<String, dynamic>.from(dec);
            } catch (_) {}
          }
        }

        if (resData['success'] == true) {
          CloudFunctions.balanceRefreshNotifier.value++;
        }
        return resData;
      } else {
        try {
          final errJson = jsonDecode(res.body);
          return {
            'success': false,
            'message': errJson['message'] ?? 'Failed to claim mission'
          };
        } catch (_) {}
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
    return {'success': false, 'message': 'Failed to claim mission'};
  }

  static Future<Map<String, dynamic>> applyReferralCode(String code) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final userId = user?.uid ?? '';

      final rawInput = {
        'userId': userId,
        'referralCode': code.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final res = await SecurityService.post(
        '${AppConst.serverBaseUrl}/api/referral/apply-code',
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
              if (dec is Map) resData = Map<String, dynamic>.from(dec);
            } catch (_) {}
          }
        }
        if (resData['success'] == true) {
          CloudFunctions.balanceRefreshNotifier.value++;
        }
        return resData;
      } else {
        try {
          final errJson = jsonDecode(res.body);
          return {
            'success': false,
            'message': errJson['message'] ?? 'Failed to apply referral code'
          };
        } catch (_) {}
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
    return {'success': false, 'message': 'Failed to apply referral code'};
  }

  static Future<int> getLevelCount(int level) async {
    final data = await _fetchReferralData();
    if (level == 1) return (data['totalReferred'] as num?)?.toInt() ?? 0;
    return 0;
  }

  static Future<double> getLevelEarning(int level) async {
    return 0.0;
  }

  static Future<List<ReferHistoryModel>> getLevelUsers(int level) async {
    return getAllUsers();
  }

  static Future<List<ReferHistoryModel>> getAllUsers() async {
    final stats = await getReferralStats();
    return stats.referredUsers;
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    final count = await getTotalCount();
    return {
      'totalCount': count,
      'totalCoins': 0.0,
      'level1Count': count,
      'level2Count': 0,
      'level3Count': 0,
      'level1Coins': 0.0,
      'level2Coins': 0.0,
      'level3Coins': 0.0,
    };
  }

  static final referralStatsProvider =
      FutureProvider.autoDispose<ReferralStatsData>(
          (ref) => getReferralStats());
  static final totalCountProvider =
      FutureProvider.autoDispose<int>((ref) => getTotalCount());
  static final totalEarningProvider =
      FutureProvider.autoDispose<double>((ref) => getTotalEarning());
  static final claimedMissionsProvider =
      FutureProvider.autoDispose<List<String>>((ref) => getClaimedMissions());
  static final activeMissionsProvider =
      FutureProvider.autoDispose<List<ReferralMissionModel>>(
          (ref) => getActiveMissions());
  static final levelCountProvider =
      FutureProvider.autoDispose.family<int, int>((ref, level) => getLevelCount(level));
  static final levelEarningProvider =
      FutureProvider.autoDispose.family<double, int>((ref, level) => getLevelEarning(level));
  static final levelUsersProvider =
      FutureProvider.autoDispose.family<List<ReferHistoryModel>, int>((ref, level) => getLevelUsers(level));
  static final allUsersProvider =
      FutureProvider.autoDispose<List<ReferHistoryModel>>((ref) => getAllUsers());
  static final dashboardProvider =
      FutureProvider.autoDispose<Map<String, dynamic>>((ref) => getDashboard());
}
