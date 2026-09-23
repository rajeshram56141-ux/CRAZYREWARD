import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../services/cloud_functions.dart';
import '../../../services/security_service.dart';
import '../../../services/notification_service.dart';
import '../../../utils/constant/constant.dart';
import '../../b_splash_stage/splash_service.dart';
import '../../d_authentication_stage/users_data_model.dart';
import '../sections/a_home/offerwall/provider/offerwall_manager.dart';
import '../sections/a_home/super_offer/super_offer_model.dart';
import '../sections/a_home/super_offer/super_offer_provider.dart';

class DashboardService {
  //! Init Dashboard
  static Future<void> initDashboard({
    required String userId,
    required bool isGuest,
  }) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait(([
        if (!isGuest) _updateUserStats(userId),
        OfferwallManager.initAll(userId: userId),
        CloudFunctions.trackUser(),
      ]));
    });
    NotificationService.setUserId(userId);
  }

  static Future<void> _updateUserStats(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';

      final syncInput = {
        'deviceId': SplashService.deviceId,
        'gaid': SplashService.gaid,
      };

      await SecurityService.post(
        '${AppConst.serverBaseUrl}/api/user/sync',
        userId: userId,
        deviceId: SplashService.deviceId,
        token: token,
        body: syncInput,
      );
    } catch (e) {
       // debugPrint('Error updating user stats: $e');
    }
  }

  static UserDataModel? _cachedUser;

  static void setCachedUser(UserDataModel user) {
    _cachedUser = user;
    try {
      final storage = GetStorage();
      storage.write('cached_user_${user.userId}', user.toSnapshot());
    } catch (_) {}
  }

  static UserDataModel? getCachedUser(String userId) {
    if (_cachedUser != null && _cachedUser!.userId == userId) {
      return _cachedUser;
    }
    try {
      final storage = GetStorage();
      final data = storage.read('cached_user_$userId');
      if (data != null && data is Map) {
        _cachedUser = UserDataModel.fromJson(Map<String, dynamic>.from(data));
        return _cachedUser;
      }
    } catch (_) {}
    return null;
  }

  //! Helper to fetch user profile from MongoDB
  static Future<UserDataModel?> fetchUserProfile(String userId) async {
    try {
      var firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        firebaseUser = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
      }

      if (firebaseUser != null) {
        final token = await firebaseUser.getIdToken() ?? '';

        final res = await http.get(
          Uri.parse('${AppConst.serverBaseUrl}/api/user/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'user-id': userId,
          },
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          Map<String, dynamic> data = jsonDecode(res.body);
          if (data['responsePayload'] != null) {
            final decryptedStr = SecurityService.decryptPayload(
              data['responsePayload'].toString(),
              userId: userId,
            );
            if (decryptedStr.isNotEmpty) {
              try {
                data = Map<String, dynamic>.from(jsonDecode(decryptedStr));
              } catch (_) {}
            }
          }

          if (data['success'] == true && data['user'] != null) {
            final userModel = UserDataModel.fromJson(data['user']);
            setCachedUser(userModel);
            return userModel;
          }
        } else {
           // debugPrint('userProfile HTTP error: ${res.statusCode} ${res.body}');
        }
      }
    } catch (e) {
       // debugPrint('Error fetching user profile: $e');
    }
    return null;
  }

  //! User Data Provider (Instant Cache + Background Refresh)
  static final userDataProvider = FutureProvider.family<UserDataModel, String>(
    (ref, String userId) async {
      // 1. Instant Cache Hit
      final cached = getCachedUser(userId);
      if (cached != null) {
        // Refresh asynchronously in background without blocking UI
        unawaited(fetchUserProfile(userId));
        return cached;
      }

      // 2. Fallback to immediate fetch or Firebase user data
      final user = await fetchUserProfile(userId);
      if (user != null) {
        return user;
      }

      final curUser = FirebaseAuth.instance.currentUser;
      final fallbackUser = UserDataModel.fromJson({
        'userId': userId.isNotEmpty ? userId : (curUser?.uid ?? ''),
        'email': curUser?.email ?? '',
        'displayName': curUser?.displayName ?? (curUser?.isAnonymous == true ? 'Guest User' : 'User'),
        'photoUrl': curUser?.photoURL ?? '',
        'mobileNo': curUser?.phoneNumber ?? '',
        'coins': 0.0,
        'bonusCoins': 0.0,
        'gems': 0,
        'referralCode': '',
        'streak': 1,
        'streakClaimed': false,
        'isBlocked': false,
        'account_deleted': false,
        'isGuest': curUser?.isAnonymous ?? false,
      });
      setCachedUser(fallbackUser);
      return fallbackUser;
    },
  );

  //! Super Offer Data Provider
  static final superOfferDataProvider = FutureProvider.family<SuperOfferModel, String>((ref, String userId) async {
    final user = await ref.watch(userDataProvider(userId).future);
    final soVerify = await ref.watch(superOfferVerifierProvider(userId).future);
    return SuperOfferModel(
      streak: user.streak,
      gems: user.gems,
      dailyGems: 0,
      completedSuperOffers: soVerify.completedSuperOffers,
    );
  });

  //! User Coins Provider
  static final userCoinsProvider = FutureProvider.family.autoDispose<double, String>((ref, String userId) async {
    final user = await ref.watch(userDataProvider(userId).future);
    return user.coins;
  });

  //! User Gems Provider
  static final userGemsProvider = FutureProvider.family.autoDispose<int, String>((ref, String userId) async {
    final user = await ref.watch(userDataProvider(userId).future);
    return user.gems;
  });

  //! Spin Count Provider
  static final spinCountProvider = FutureProvider.family.autoDispose<int, String>((ref, String userId) async {
    return 0;
  });
}
