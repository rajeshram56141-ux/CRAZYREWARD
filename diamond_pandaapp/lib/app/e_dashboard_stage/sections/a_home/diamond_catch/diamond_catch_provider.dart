import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/security_service.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../../utils/helper/helper.dart';
import '../../../../b_splash_stage/splash_service.dart';
import 'diamond_catch_model.dart';

final diamondCatchVerifierProvider = FutureProvider.autoDispose.family<DiamondCatchSet, String>((ref, String userId) async {
  final Dio dio = Dio();

  final appName = SplashService.appName;

  try {
    final rawInput = {'appName': appName.lows(), 'userId': userId};
    final encryptedPayload = SecurityService.encryptPayload(rawInput, userId: userId);

    final response = await dio.post(
      AppConst.diamondCatchVerify,
      options: Options(
        headers: {
          ...AppConst.apiHeader,
          if (userId.isNotEmpty) 'x-user-id': userId,
        },
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
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

      final config = SplashService.superOfferConfig;

      final gameDailyLimit = (data['gameDailyLimit'] as num?)?.toInt() ?? (config['gameDailyLimit'] as num?)?.toInt() ?? 10;
      final gameClaimsToday = (data['gameClaimsToday'] as num?)?.toInt() ?? 0;
      final gameEligible = data['gameEligible'] ?? true;
      final gameInstallTask = data['gameInstallTask'] ?? false;
      final gameGems = (config['gameGems'] as num?)?.toInt() ?? 1;
      final installGems = (config['installGems'] as num?)?.toInt() ?? 5;
      final dailyGemsForInstall = (config['dailyGemsForInstall'] as num?)?.toInt() ?? 2;

      return DiamondCatchSet(
        gameInstallTask: gameInstallTask,
        dailyGemsForInstall: dailyGemsForInstall,
        gameGems: gameGems,
        installGems: installGems,
        gameEligible: gameEligible,
        gameDailyLimit: gameDailyLimit,
        gameClaimsToday: gameClaimsToday,
      );
    }

    final config = SplashService.superOfferConfig;
    return DiamondCatchSet(
      gameInstallTask: false,
      dailyGemsForInstall: (config['dailyGemsForInstall'] as num?)?.toInt() ?? 2,
      gameGems: (config['gameGems'] as num?)?.toInt() ?? 1,
      installGems: (config['installGems'] as num?)?.toInt() ?? 5,
      gameEligible: true,
      gameDailyLimit: 10,
      gameClaimsToday: 0,
    );
  } catch (e) {
    final config = SplashService.superOfferConfig;
    return DiamondCatchSet(
      gameInstallTask: false,
      dailyGemsForInstall: (config['dailyGemsForInstall'] as num?)?.toInt() ?? 2,
      gameGems: (config['gameGems'] as num?)?.toInt() ?? 1,
      installGems: (config['installGems'] as num?)?.toInt() ?? 5,
      gameEligible: true,
      gameDailyLimit: 10,
      gameClaimsToday: 0,
    );
  }
});
