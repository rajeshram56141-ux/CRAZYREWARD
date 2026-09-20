import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/security_service.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../../utils/helper/helper.dart';
import '../../../../b_splash_stage/splash_service.dart';
import 'super_offer_model.dart';
import 'super_offer_step2_list_screen.dart';

final superOfferVerifierProvider = FutureProvider.autoDispose.family<SuperOfferSet, String>((ref, String userId) async {
      final Dio dio = Dio();

      final appName = SplashService.appName;

      try {
        final rawInput = {'appName': appName.lows(), 'userId': userId};
        final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: userId);

        final response = await dio.post(
          AppConst.superOfferVerify,
          options: Options(
            headers: {
              ...AppConst.apiHeader,
              if (userId.isNotEmpty) 'x-user-id': userId,
            },
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
          data: {'payload': encryptedPayload},
        );

        if (response.statusCode == 200) {
          Map<String, dynamic> data = response.data is Map<String, dynamic>
              ? response.data
              : jsonDecode(response.data.toString());

          if (data['responsePayload'] != null) {
            final decryptedStr = SecurityService.decryptPayload(data['responsePayload'].toString(), userId: userId);
            if (decryptedStr.isNotEmpty) {
              try {
                data = Map<String, dynamic>.from(jsonDecode(decryptedStr));
              } catch (_) {}
            }
          }
          if (data['superOfferConfig'] is Map) {
            SplashService.superOfferConfig = Map<String, dynamic>.from(data['superOfferConfig'] as Map);
          }
          if (data['dailyLimit'] != null) {
            SplashService.superOfferConfig['dailyLimit'] = data['dailyLimit'];
          }
          if (data['claimsToday'] != null || data['superOfferClaimsToday'] != null) {
            SplashService.superOfferConfig['claimsToday'] = data['claimsToday'] ?? data['superOfferClaimsToday'];
          }

          final config = SplashService.superOfferConfig;

          DateTime? lastClaimedAt;
          if (data['lastClaimedAt'] != null) {
            lastClaimedAt = DateTime.fromMillisecondsSinceEpoch((data['lastClaimedAt'] as num).toInt());
          }
          final rawGap = data['gapMinutes'] ?? config['gapMinutes'] ?? data['hoursGap'] ?? config['hoursGap'] ?? 60;
          final int gapMinutes = (rawGap is num) ? rawGap.toInt() : (int.tryParse(rawGap.toString()) ?? 60);
          final int hoursGap = (gapMinutes / 60).round();

          final rewardVal = (data['reward'] as num?)?.toInt() ?? (config['reward'] as num?)?.toInt() ?? 0;
          final gemsReqVal = (data['gemsRequired'] as num?)?.toInt() ?? (config['gemsRequired'] as num?)?.toInt() ?? 0;
          final limitType = (data['limitType'] ?? config['limitType'] ?? 'hours').toString();

          final int activeMethod = (data['activeMethod'] as num?)?.toInt() ??
              (config['activeMethod'] as num?)?.toInt() ??
              ((data['installTask'] == false) ? 1 : 2);
          final bool effectiveInstallTask = (activeMethod == 1)
              ? false
              : (data['installTask'] ?? config['installTask'] ?? true);
          final bool effectiveVerification = (activeMethod == 3 || activeMethod == 4);

          final result = SuperOfferSet(
            coins: rewardVal,
            gemsRequired: gemsReqVal,
            adsRequired: data['adsRequired'] ?? config['adsRequired'] ?? true,
            installTask: effectiveInstallTask,
            superOfferVerificationEnabled: effectiveVerification,
            dailyGemsForInstall: (data['dailyGemsForInstall'] as num?)?.toInt() ??
                (config['dailyGemsForInstall'] as num?)?.toInt() ??
                0,
            installGems: (data['installGems'] as num?)?.toInt() ??
                (config['installGems'] as num?)?.toInt() ??
                0,
            eligible: data['eligible'] ?? false,
            lastClaimedAt: lastClaimedAt,
            hoursGap: hoursGap,
            gapMinutes: gapMinutes,
            isUnlocked: data['isUnlocked'] == true,
            completedSuperOffers: (data['completedSuperOffers'] as num?)?.toInt() ?? 0,
            limitType: limitType,
          );
          return result;
        }

        final config = SplashService.superOfferConfig;
        return SuperOfferSet(
          coins: (config['reward'] as num?)?.toInt() ?? 100,
          gemsRequired: (config['gemsRequired'] as num?)?.toInt() ?? 10,
          adsRequired: config['adsRequired'] ?? true,
          installTask: config['installTask'] ?? true,
          superOfferVerificationEnabled: config['superOfferVerificationEnabled'] ?? true,
          dailyGemsForInstall: (config['dailyGemsForInstall'] as num?)?.toInt() ?? 2,
          installGems: (config['installGems'] as num?)?.toInt() ?? 5,
          eligible: false,
          limitType: (config['limitType'] ?? 'hours').toString(),
        );
      } catch (_) {
        final config = SplashService.superOfferConfig;
        return SuperOfferSet(
          coins: (config['reward'] as num?)?.toInt() ?? 100,
          gemsRequired: (config['gemsRequired'] as num?)?.toInt() ?? 10,
          adsRequired: config['adsRequired'] ?? true,
          installTask: config['installTask'] ?? true,
          superOfferVerificationEnabled: config['superOfferVerificationEnabled'] ?? true,
          dailyGemsForInstall: (config['dailyGemsForInstall'] as num?)?.toInt() ?? 2,
          installGems: (config['installGems'] as num?)?.toInt() ?? 5,
          eligible: false,
          limitType: (config['limitType'] ?? 'hours').toString(),
        );
      }
    });

final pendingOffersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, String userId) async {
  final uid = userId.isNotEmpty ? userId : (FirebaseAuth.instance.currentUser?.uid ?? '');
  return await SuperOfferStep2ListScreen.syncSavedOffers(uid);
});

