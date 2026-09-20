import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'device_integrity_service.dart';
import 'security_service.dart';
import '../utils/constant/constant.dart';
import '../app/b_splash_stage/splash_service.dart';

class CloudFunctions {
  static final ValueNotifier<int> balanceRefreshNotifier = ValueNotifier<int>(0);

  static void triggerBalanceRefresh() {
    balanceRefreshNotifier.value++;
  }

  //! Handle Signup Bonus
  static Future<void> handleSignupBonus(String referralCode) async =>
      await _makeCloudCall('handleSignupBonus', {'referralCode': referralCode});

  //! Claim Gems
  static Future<Map<String, dynamic>> claimGems(
    int gems,
    bool isInstall,
  ) async =>
      await _makeCloudCall('claimGems', {'gems': gems, 'isInstall': isInstall});

  //! Track User Activity
  static Future<bool> trackUser() async {
    final Map<String, dynamic> res = await _makeCloudCall('trackUser', {});
    if (res['response'] == 'success') {
      return true;
    }
    return false;
  }

  //! Claim Super Offers
  static Future<bool> claimSuperOffer(
    int coins,
    int gemsRequired, {
    String? userId,
    String? packageName,
    String? appName,
  }) async {
    final Map<String, dynamic> res = await _makeCloudCall('claimSuperOffer', {
      'coins': coins,
      'gemsRequired': gemsRequired,
      if (userId != null && userId.isNotEmpty) 'userId': userId,
      if (packageName != null && packageName.isNotEmpty) 'packageName': packageName,
      if (appName != null && appName.isNotEmpty) 'appName': appName,
    });
    if (res['response'] == 'success' || res['success'] == true) {
      triggerBalanceRefresh();
      return true;
    }
    throw Exception(res['message'] ?? 'Failed to claim Super Offer');
  }

  //! Log Super Offer Activity
  static Future<void> logSuperOfferActivity({
    required String packageName,
    required String appName,
    int stepNumber = 1,
    String stepName = 'Install App',
    String stepType = 'install',
    String status = 'completed',
    int coins = 0,
    int usageMinutes = 0,
    String proofImageUrl = '',
    String rejectionReason = '',
  }) async {
    try {
      await _makeCloudCall('logSuperOfferActivity', {
        'packageName': packageName,
        'appName': appName,
        'stepNumber': stepNumber,
        'stepName': stepName,
        'stepType': stepType,
        'status': status,
        'coins': coins,
        'usageMinutes': usageMinutes,
        'proofImageUrl': proofImageUrl,
        'rejectionReason': rejectionReason,
      });
    } catch (_) {}
  }

  //! Submit Super Offer Screenshot Proof
  static Future<bool> submitSuperOfferScreenshot({
    required String packageName,
    required String appName,
    required String imageUrl,
    String userId = '',
    int coins = 0,
  }) async {
    try {
      final res = await _makeCloudCall('submitSuperOfferScreenshot', {
        if (userId.isNotEmpty) 'userId': userId,
        'packageName': packageName,
        'appName': appName,
        'imageUrl': imageUrl,
        'coins': coins,
      });
      return res['success'] == true || res['response'] == 'success';
    } catch (_) {
      return false;
    }
  }

  //! Claim or Skip Super Offer Usage Step
  static Future<bool> claimSuperOfferUsageStep({
    required String packageName,
    required String appName,
    required int stepNumber,
    required String stepName,
    required int coins,
    required int usageMinutes,
    String userId = '',
    String status = 'completed',
  }) async {
    try {
      final res = await _makeCloudCall('claimSuperOfferUsageStep', {
        if (userId.isNotEmpty) 'userId': userId,
        'packageName': packageName,
        'appName': appName,
        'stepNumber': stepNumber,
        'stepName': stepName,
        'coins': coins,
        'usageMinutes': usageMinutes,
        'status': status,
      });
      if (res['success'] == true || res['response'] == 'success') {
        triggerBalanceRefresh();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  //! Get Super Offer Screenshot Proof Status
  static Future<Map<String, dynamic>> getSuperOfferProofStatus({
    required String packageName,
  }) async {
    try {
      final res = await _makeCloudCall('getSuperOfferProofStatus', {
        'packageName': packageName,
      });
      return res;
    } catch (_) {
      return {'success': false, 'status': 'none'};
    }
  }

  //! Get Active User Super Offers (Backend Sync)
  static Future<List<String>> getUserPendingOffers({required String userId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final uid = user?.uid ?? userId;
      final deviceBundle = await DeviceIntegrityService.getSecurityBundle();
      final deviceId = deviceBundle['physicalDeviceId']?.toString() ?? deviceBundle['deviceId']?.toString() ?? '';

      final response = await SecurityService.post(
        AppConst.getUserPendingOffersApi,
        userId: uid,
        deviceId: deviceId,
        token: token,
        headers: AppConst.apiHeader.map((key, val) => MapEntry(key, val.toString())),
        body: {
          'userId': uid,
          'deviceInfo': deviceBundle,
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = {};
        try {
          data = Map<String, dynamic>.from(jsonDecode(response.body));
        } catch (_) {}

        if (data['responsePayload'] != null) {
          final decryptedStr = SecurityService.decryptPayload(data['responsePayload'].toString(), userId: uid, deviceId: deviceId);
          if (decryptedStr.isNotEmpty) {
            try {
              data = Map<String, dynamic>.from(jsonDecode(decryptedStr));
            } catch (_) {}
          }
        }

        if (data['success'] == true && data['packages'] is List) {
          return List<String>.from((data['packages'] as List).map((e) => e.toString()));
        }
      }
    } catch (_) {}
    return [];
  }

  //! Get Full Active User Super Offers with DB Snapshots (Backend Sync)
  static Future<List<Map<String, dynamic>>> getUserPendingOffersDetails({required String userId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final uid = user?.uid ?? userId;
      final deviceBundle = await DeviceIntegrityService.getSecurityBundle();
      final deviceId = deviceBundle['physicalDeviceId']?.toString() ?? deviceBundle['deviceId']?.toString() ?? '';

      final response = await SecurityService.post(
        AppConst.getUserPendingOffersApi,
        userId: uid,
        deviceId: deviceId,
        token: token,
        headers: AppConst.apiHeader.map((key, val) => MapEntry(key, val.toString())),
        body: {
          'userId': uid,
          'deviceInfo': deviceBundle,
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = {};
        try {
          data = Map<String, dynamic>.from(jsonDecode(response.body));
        } catch (_) {}

        if (data['responsePayload'] != null) {
          final decryptedStr = SecurityService.decryptPayload(data['responsePayload'].toString(), userId: uid, deviceId: deviceId);
          if (decryptedStr.isNotEmpty) {
            try {
              data = Map<String, dynamic>.from(jsonDecode(decryptedStr));
            } catch (_) {}
          }
        }

        if (data['success'] == true && data['offers'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['offers'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
          );
        }
      }
    } catch (_) {}
    return [];
  }

  //! Deduct Gems for Super Offer Unlock
  static Future<bool> deductSuperOfferGems(int gemsRequired) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final uid = user?.uid ?? '';
      final deviceBundle = await DeviceIntegrityService.getSecurityBundle();
      final deviceId = deviceBundle['physicalDeviceId']?.toString() ?? deviceBundle['deviceId']?.toString() ?? '';

      final response = await SecurityService.post(
        AppConst.deductSuperOfferGemsApi,
        userId: uid,
        deviceId: deviceId,
        token: token,
        headers: AppConst.apiHeader.map((key, val) => MapEntry(key, val.toString())),
        body: {
          'userId': uid,
          'gemsRequired': gemsRequired,
          'deviceInfo': deviceBundle,
          'appName': SplashService.appName.toLowerCase(),
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true || data['response'] == 'success') {
          triggerBalanceRefresh();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  //! Complete Battle Install Task
  static Future<Map<String, dynamic>> completeBattleInstallTask() async =>
      await _makeCloudCall('completeBattleInstallTask', {});

  //! Get Daily Challenge Status
  static Future<Map<String, dynamic>> getDailyChallengeStatus() async =>
      await _makeCloudCall('getDailyChallengeStatus', {});

  //! Claim Daily Challenge Reward
  static Future<Map<String, dynamic>> claimDailyChallengeReward() async =>
      await _makeCloudCall('claimDailyChallengeReward', {});

  //! Request Payout
  static Future<Map<String, dynamic>> requestPayout({
    required String id,
    int? coinsRequired,
    int? amount,
    String? paymentMethod,
    Map<String, dynamic>? paymentDetail,
  }) async =>
      await _makeCloudCall('requestPayout', {
        'id': id,
        if (coinsRequired != null) 'coinsRequired': coinsRequired,
        if (amount != null) 'amount': amount,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (paymentDetail != null) 'paymentDetail': paymentDetail,
      });

  //! Promo Code Reward
  static Future<String> promoCodeReward(String code) async {
    final Map<String, dynamic> res = await _makeCloudCall('promoCodeReward', {
      'code': code,
    });
    if (res['response'] != 'success') {
      throw Exception(res['message'] ?? 'The promo code you entered is invalid or incorrect.');
    }
    triggerBalanceRefresh();
    return res['message'] ?? 'Promo code processed';
  }


  //! Streak Reward
  static Future<void> streakReward() async =>
      await _makeCloudCall('streakReward', {});

  //! Follow Reward
  static Future<void> followReward(String tag) async =>
      await _makeCloudCall('followReward', {'tag': tag});

  //! Giveaway Join
  static Future<String> joinGiveaway(String giveawayId) async {
    final Map<String, dynamic> res = await _makeCloudCall('joinGiveaway', {
      'giveawayId': giveawayId,
    });
    return res['message'];
  }

  //! Request Claim Giveaway Reward
  static Future<String> requestClaimGiveawayReward(String giveawayId) async {
    final Map<String, dynamic> res = await _makeCloudCall(
      'requestClaimGiveawayReward',
      {'giveawayId': giveawayId},
    );
    return res['message'];
  }

  //! Play Games Postback
  static Future<String> playGamesPostback({
    required String offerId,
    required int coins,
  }) async {
    final Map<String, dynamic> res = await _makeCloudCall('playGamesPostback', {
      'offerId': offerId,
      'coins': coins,
    });
    return res['message'];
  }

  static Future<Map<String, dynamic>> _makeCloudCall(
    String callName,
    Map<String, dynamic> input,
  ) async {
    try {
      if (await SecurityService.isVpnOrProxyActive()) {
        return {
          'response': 'error-title'.tr(),
          'message': 'vpn-required-subtitle'.tr(),
        };
      }

      // Map Cloud Function names to VPS Node.js API routes derived from AppConst
      String endpoint = AppConst.userSyncApi;

      if (callName == 'streakReward') endpoint = AppConst.streakRewardApi;
      if (callName == 'promoCodeReward') endpoint = AppConst.promoCodeRewardApi;
      if (callName == 'requestPayout') endpoint = AppConst.requestPayoutApi;
      if (callName == 'joinGiveaway') endpoint = AppConst.joinGiveawayApi;
      if (callName == 'requestClaimGiveawayReward') endpoint = AppConst.claimGiveawayRewardApi;
      if (callName == 'claimGems') endpoint = AppConst.claimGemsApi;
      if (callName == 'claimSuperOffer') endpoint = AppConst.claimSuperOfferApi;
      if (callName == 'followReward') endpoint = AppConst.followRewardApi;
      if (callName == 'handleSignupBonus') endpoint = AppConst.userSyncApi;
      if (callName == 'completeBattleInstallTask') endpoint = AppConst.completeBattleInstallTaskApi;
      if (callName == 'getDailyChallengeStatus') endpoint = AppConst.dailyChallengeStatusApi;
      if (callName == 'claimDailyChallengeReward') endpoint = AppConst.claimDailyChallengeRewardApi;
      if (callName == 'logSuperOfferActivity') endpoint = AppConst.logSuperOfferActivityApi;
      if (callName == 'submitSuperOfferScreenshot') endpoint = AppConst.submitSuperOfferScreenshotApi;
      if (callName == 'getSuperOfferProofStatus') endpoint = AppConst.getSuperOfferProofStatusApi;
      if (callName == 'getUserPendingOffers') endpoint = AppConst.getUserPendingOffersApi;
      if (callName == 'claimSuperOfferUsageStep') endpoint = AppConst.claimSuperOfferUsageStepApi;

      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final uid = user?.uid ?? input['userId']?.toString() ?? '';

      final deviceBundle = await DeviceIntegrityService.getSecurityBundle();
      final mergedInput = {
        ...input,
        'deviceInfo': deviceBundle,
      };

      final deviceId = deviceBundle['physicalDeviceId']?.toString() ?? deviceBundle['deviceId']?.toString() ?? '';
      final response = await SecurityService.post(
        endpoint,
        userId: uid,
        deviceId: deviceId,
        token: token,
        headers: AppConst.apiHeader.map((key, val) => MapEntry(key, val.toString())),
        body: mergedInput,
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true || data['response'] == 'success') {
          triggerBalanceRefresh();
          return {
            ...data,
            'response': 'success',
            'message': data['message'] ?? 'Success',
            'coins': data['coins'],
            'user': data['user'],
            'status': data['status'] ?? data['payout']?['status'],
            'payout': data['payout'],
            'redeemCode': data['redeemCode'] ?? data['payout']?['redeemCode'] ?? data['giftCode'] ?? data['payout']?['giftCode'] ?? data['code'] ?? data['payout']?['code'],
          };
        } else {
          return {
            'response': 'error',
            'message': data['message'] ?? 'Failed to process request',
          };
        }
      }

      String errorMsg = 'Server returned ${response.statusCode}';
      Map<String, dynamic> errBody = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          errBody = decoded;
          if (errBody['message'] != null) {
            errorMsg = errBody['message'].toString();
          }
        }
      } catch (_) {}

      return {
        ...errBody,
        'response': 'error-title'.tr(),
        'message': errorMsg,
      };
    } catch (e) {
       // debugPrint('Node API call error: $e');
      return {'response': 'error-title'.tr(), 'message': 'unknown-error'.tr()};
    }
  }
}
