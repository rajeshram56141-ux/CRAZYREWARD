import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../../../../services/security_service.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../b_splash_stage/splash_service.dart';

class BattleArenaService {
  static final BattleArenaService instance = BattleArenaService._();
  BattleArenaService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => status != null && status < 500,
  ));

  Map<String, dynamic>? configData;
  List<dynamic> activeRooms = [];
  bool isLeaderboardActive = false;
  String leaderboardTitle = 'Leaderboard';
  String rankingBasis = 'points';
  List<dynamic> leaderboardStandings = [];
  String? nextPayoutTime;
  int cycleDays = 7;
  List<dynamic> rewardTiers = [];
  bool showWinnersOnly = false;

  dynamic _decryptResponse(dynamic respData, String userId) {
    String decryptedStr = '';
    if (respData is String) {
      decryptedStr = SecurityService.decryptPayload(respData, userId: userId, deviceId: SplashService.deviceId);
    } else if (respData is Map && respData['responsePayload'] != null) {
      decryptedStr = SecurityService.decryptPayload(respData['responsePayload'].toString(), userId: userId, deviceId: SplashService.deviceId);
    }
    return decryptedStr.isNotEmpty ? jsonDecode(decryptedStr) : respData;
  }

  /// 1. Fetch Active Battle Rooms & Configuration
  Future<Map<String, dynamic>> fetchActiveRooms(String userId) async {
    try {
      final rawPayload = {
        'userId': userId,
        'deviceId': SplashService.deviceId,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/active-rooms',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final data = _decryptResponse(response.data, userId);

      if (response.statusCode == 200) {
        if (data is Map<String, dynamic> && data['success'] == true) {
          configData = data['config'];
          activeRooms = data['rooms'] ?? [];
          return data;
        }
      }
    } catch (e) {
       // debugPrint('🔥 Error fetching active battle rooms: $e');
    }
    return {'success': false};
  }

  /// 1b. Fetch Fresh Room Details
  Future<Map<String, dynamic>?> fetchRoomDetails({
    required String userId,
    required String roomId,
  }) async {
    try {
      final rawPayload = {
        'userId': userId,
        'roomId': roomId,
        'deviceId': SplashService.deviceId,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/room-details',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final data = _decryptResponse(response.data, userId);

      if (response.statusCode == 200) {
        if (data is Map<String, dynamic> && data['success'] == true) {
          if (data['config'] != null) {
            configData = data['config'];
          }
          return data;
        }
      }
    } catch (e) {
      // debugPrint('🔥 Error fetching room details: $e');
    }
    return null;
  }

  /// 2. Join Battle Room (Deducts entry fee / Verifies Ad Watch / IP Self-Match Check)
  Future<Map<String, dynamic>> joinRoom({
    required String userId,
    required String roomId,
    String adVerifiedToken = '',
  }) async {
    try {
      final rawPayload = {
        'userId': userId,
        'roomId': roomId,
        'deviceId': SplashService.deviceId,
        'adVerifiedToken': adVerifiedToken,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/join-room',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final data = _decryptResponse(response.data, userId);

      return data is Map<String, dynamic> ? data : {};
    } catch (e) {
       // debugPrint('🔥 Error joining battle room: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 3. Check Match Status (Delivers Questions WITHOUT Answer Keys)
  Future<Map<String, dynamic>> checkMatchStatus({
    required String userId,
    required String matchId,
    bool timeout = false,
  }) async {
    try {
      final rawPayload = {
        'userId': userId,
        'matchId': matchId,
        'deviceId': SplashService.deviceId,
        if (timeout) 'timeout': true,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/match-status',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final respData = response.data;
      String decryptedStr = '';
      if (respData is String) {
        decryptedStr = SecurityService.decryptPayload(respData, userId: userId, deviceId: SplashService.deviceId);
      } else if (respData is Map && respData['responsePayload'] != null) {
        decryptedStr = SecurityService.decryptPayload(respData['responsePayload'], userId: userId, deviceId: SplashService.deviceId);
      }
      final data = decryptedStr.isNotEmpty ? jsonDecode(decryptedStr) : respData;

      return data is Map<String, dynamic> ? data : {};
    } catch (e) {
       // debugPrint('🔥 Error checking match status: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 4. Submit Answer (Speed & Accuracy Calculation: Base 100 Pts + Time Ratio Bonus)
  Future<Map<String, dynamic>> submitAnswer({
    required String userId,
    required String matchId,
    required String questionId,
    required int selectedOptionIndex,
    required int timeTakenMs,
  }) async {
    try {
      final rawPayload = {
        'userId': userId,
        'matchId': matchId,
        'questionId': questionId,
        'selectedOptionIndex': selectedOptionIndex,
        'timeTakenMs': timeTakenMs,
        'deviceId': SplashService.deviceId,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/submit-answer',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final data = _decryptResponse(response.data, userId);

      return data is Map<String, dynamic> ? data : {};
    } catch (e) {
       // debugPrint('🔥 Error submitting answer: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 5. Finish Match (Calculates final speed points & updates weekly leaderboard)
  Future<Map<String, dynamic>> finishMatch({
    required String userId,
    required String matchId,
  }) async {
    try {
      final rawPayload = {
        'userId': userId,
        'matchId': matchId,
        'deviceId': SplashService.deviceId,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/finish-match',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final data = _decryptResponse(response.data, userId);

      return data is Map<String, dynamic> ? data : {};
    } catch (e) {
       // debugPrint('🔥 Error finishing battle match: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 6. Fetch Weekly Cycle Leaderboard
  Future<List<dynamic>> fetchWeeklyLeaderboard(String userId) async {
    try {
      final rawPayload = {
        'userId': userId,
        'deviceId': SplashService.deviceId,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/leaderboard',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final data = _decryptResponse(response.data, userId);

      if (data is Map<String, dynamic> && data['success'] == true) {
        isLeaderboardActive = data['isActive'] == true;
        leaderboardTitle = data['title']?.toString() ?? 'Leaderboard';
        rankingBasis = data['rankingBasis']?.toString() ?? 'points';
        leaderboardStandings = data['standings'] ?? [];
        nextPayoutTime = data['nextPayoutTime']?.toString();
        cycleDays = (data['cycleDays'] is num) ? (data['cycleDays'] as num).toInt() : 7;
        rewardTiers = data['rewardTiers'] ?? [];
        showWinnersOnly = data['showWinnersOnly'] == true;
        return leaderboardStandings;
      } else {
        isLeaderboardActive = false;
        leaderboardTitle = 'Leaderboard';
        rankingBasis = 'points';
        leaderboardStandings = [];
        rewardTiers = [];
      }
    } catch (e) {
       // debugPrint('🔥 Error fetching weekly leaderboard: $e');
       isLeaderboardActive = false;
       leaderboardTitle = 'Leaderboard';
       rankingBasis = 'points';
       leaderboardStandings = [];
       rewardTiers = [];
    }
    return [];
  }

  /// 7. Fetch User's My Matches
  Future<Map<String, dynamic>> fetchMyMatches(String userId) async {
    try {
      final rawPayload = {
        'userId': userId,
        'deviceId': SplashService.deviceId,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/my-matches',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final data = _decryptResponse(response.data, userId);
      return data is Map<String, dynamic> ? data : {};
    } catch (e) {
       // debugPrint('🔥 Error fetching my matches: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// 8. Fetch Leaderboard History per Filter ('all', 'today', 'yesterday')
  Future<List<dynamic>> fetchLeaderboardHistory({
    required String userId,
    String filter = 'all',
    int cycleDays = 7,
  }) async {
    try {
      final rawPayload = {
        'userId': userId,
        'filter': filter,
        'cycleDays': cycleDays,
        'deviceId': SplashService.deviceId,
      };

      final encryptedPayload = SecurityService.encryptPayload(rawPayload, userId: userId, deviceId: SplashService.deviceId);
      final headers = SecurityService.getSecurityHeaders(rawPayload);
      headers['Content-Type'] = 'application/json';
      headers['x-user-id'] = userId;
      headers['x-device-id'] = SplashService.deviceId;

      final response = await _dio.post(
        '${AppConst.serverBaseUrl}/api/battle/leaderboard/history',
        options: Options(headers: headers),
        data: {'payload': encryptedPayload},
      );

      final data = _decryptResponse(response.data, userId);

      if (data is Map<String, dynamic> && data['success'] == true) {
        return data['records'] ?? [];
      }
    } catch (e) {
       // debugPrint('🔥 Error fetching leaderboard history: $e');
    }
    return [];
  }
}
