import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

import '../../../../../../services/security_service.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../../utils/helper/helper.dart';
import '../../../../../b_splash_stage/splash_service.dart';
import '../model/wallet_catalog_model.dart';

final hideDenominationConfigProvider = StateProvider<HideDenominationConfig>((ref) {
  return SplashService.hideDenominationConfig;
});

final walletCatalogProvider = FutureProvider.autoDispose.family<List<WalletMethod>, String>(
  (ref, countryResident) async {
    try {
      final rawInput = {
        'appName': SplashService.appName.lows(),
        'countryResident': countryResident,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final encryptedPayload = SecurityService.encryptPayload(rawInput);

      final response = await Dio().post(
        AppConst.getWalletMethods,
        data: {'payload': encryptedPayload},
        options: Options(
          headers: AppConst.apiHeader,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      Map<String, dynamic> resData = response.data is Map<String, dynamic>
          ? response.data
          : jsonDecode(response.data.toString());

      if (resData['responsePayload'] != null) {
        final decryptedStr = SecurityService.decryptPayload(resData['responsePayload'].toString());
        if (decryptedStr.isNotEmpty) {
          try {
            resData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
          } catch (_) {}
        }
      }

      if (response.statusCode == 200 && resData['success'] == true) {
        if (resData['hideDenomination'] is Map) {
          final config = HideDenominationConfig.fromJson(
            Map<String, dynamic>.from(resData['hideDenomination']),
          );
          SplashService.hideDenominationConfig = config;
          Future.microtask(() {
            try {
              ref.read(hideDenominationConfigProvider.notifier).state = config;
            } catch (_) {}
          });
        }
        final List rawMethods = resData['methods'] ?? [];
        return rawMethods
            .map((json) => WalletMethod.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
      return const [];
    } catch (e) {
       // debugPrint('🔥 Error fetching wallet catalog methods: $e');
      return const [];
    }
  },
);

final methodDenominationsProvider = FutureProvider.autoDispose.family<WalletMethod?, ({String country, String methodId})>(
  (ref, params) async {
    try {
      final rawInput = {
        'appName': SplashService.appName.lows(),
        'countryResident': params.country,
        'methodId': params.methodId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final encryptedPayload = SecurityService.encryptPayload(rawInput);

      final response = await Dio().post(
        AppConst.getWalletMethods,
        data: {'payload': encryptedPayload},
        options: Options(
          headers: AppConst.apiHeader,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      Map<String, dynamic> resData = response.data is Map<String, dynamic>
          ? response.data
          : jsonDecode(response.data.toString());

      if (resData['responsePayload'] != null) {
        final decryptedStr = SecurityService.decryptPayload(resData['responsePayload'].toString());
        if (decryptedStr.isNotEmpty) {
          try {
            resData = Map<String, dynamic>.from(jsonDecode(decryptedStr));
          } catch (_) {}
        }
      }

      if (response.statusCode == 200 && resData['success'] == true) {
        if (resData['hideDenomination'] is Map) {
          final config = HideDenominationConfig.fromJson(
            Map<String, dynamic>.from(resData['hideDenomination']),
          );
          SplashService.hideDenominationConfig = config;
          Future.microtask(() {
            try {
              ref.read(hideDenominationConfigProvider.notifier).state = config;
            } catch (_) {}
          });
        }
        final List rawMethods = resData['methods'] ?? [];
        for (final json in rawMethods) {
          final method = WalletMethod.fromJson(Map<String, dynamic>.from(json));
          if (method.id == params.methodId) {
            return method;
          }
        }
        if (rawMethods.isNotEmpty) {
          return WalletMethod.fromJson(Map<String, dynamic>.from(rawMethods.first));
        }
      }
      return null;
    } catch (e) {
       // debugPrint('🔥 Error fetching method denominations: $e');
      return null;
    }
  },
);
