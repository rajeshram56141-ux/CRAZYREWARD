import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
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

  //! Helper to fetch user profile from MongoDB
  static Future<UserDataModel?> fetchUserProfile(String userId) async {
    try {
      var firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        firebaseUser = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
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
        );

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
            return UserDataModel.fromJson(data['user']);
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

  //! User Data Provider (MongoDB On-Demand FutureProvider)
  static final userDataProvider = FutureProvider.autoDispose.family<UserDataModel, String>(
    (ref, String userId) async {
      final user = await fetchUserProfile(userId);
      if (user == null) {
        throw Exception('Failed to load user profile');
      }
      return user;
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
