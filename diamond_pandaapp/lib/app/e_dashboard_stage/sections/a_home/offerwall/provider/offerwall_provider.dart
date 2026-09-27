import 'package:bitlabs/bitlabs.dart';
import 'package:cpx_research_sdk_flutter/cpx.dart';
import 'package:flutter/material.dart';
import 'package:growdeck_playtime_plugin/growdeck_playtime_plugin_method_channel.dart';
import 'package:playtime_ads/playtime_ads.dart';
import 'package:pubscale_plugin/pubscale_plugin.dart';
import '../../../../../b_splash_stage/splash_service.dart';

import '../../../../../../../services/launch_url.dart';
import '../../../../../../../widgets/common/custom_toast.dart';
import '../../../../../../utils/helper/helper.dart';
import '../model/offerwall_data_model.dart';

abstract class OfferwallProvider {
  final String name;
  final List<Color> gradient;
  bool enabled = false;

  OffersDataModel? config;
  bool hasValidConfig() => true;

  OfferwallProvider({required this.name, required this.gradient});

  String get logoImage => 'assets/icons/${name.img()}-logo.png';
  String get textImage => 'assets/icons/${name.img()}-text.png';

  void attachConfig(OffersDataModel data) {
    config = data;
    enabled = data.enabled;
  }

  Future<void> init({required String userId}) async {}

  Future<void> show({
    required BuildContext context,
    required String userId,
    required String email,
  }) async {}
}

class WebViewTaskProvider extends OfferwallProvider {
  WebViewTaskProvider({required super.name, required super.gradient});

  @override
  Future<void> show({
    required BuildContext context,
    required String userId,
    required String email,
  }) async {
    final String urlBase = config?.url ?? '';
    if (urlBase.isNotEmpty) {
      CustomToast.showToast(context, msg: 'loading');
      final String url = urlBase
          .replaceAll('{USER_ID}', userId)
          .replaceAll('{USER_EMAIL}', email)
          .replaceAll('{DEVICE_ID}', SplashService.deviceId)
          .replaceAll('{USER_GAID}', SplashService.gaid);
      await LaunchUrl.inApp(url: url, context: context);
    } else {
      CustomToast.showToast(context, msg: 'offerwall-locked');
    }
  }

  @override
  bool hasValidConfig() => config?.url.isNotEmpty == true;
}

// TASK PROVIDER - SDK BASED
class PubscaleTaskProvider extends OfferwallProvider {
  PubscaleTaskProvider()
    : super(
        name: 'Pubscale',
        gradient: [
          Color.fromRGBO(37, 197, 185, 1),
          Color.fromRGBO(0, 72, 67, 1),
        ],
      );

  final PubscalePlugin _pubscale = PubscalePlugin.instance;

  @override
  Future<void> init({required String userId}) async {
    final String appId = config?.appId ?? '';
    if (appId.isNotEmpty) {
      try {
        await _pubscale.initSDK(appId: appId, userId: userId);
      } catch (e, s) {
         // debugPrint('❌ Error initializing $name: $e\n$s');
      }
    } else {
       // debugPrint('⚠️ Pubscale appId is missing in config');
    }
  }

  @override
  Future<void> show({
    required BuildContext context,
    required String userId,
    required String email,
  }) async {
    final String appId = config?.appId ?? '';
    if (appId.isNotEmpty) {
      try {
        CustomToast.showToast(context, msg: 'loading');
        await _pubscale.showOfferwall();
      } catch (e, s) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
         // debugPrint('❌ Error showing $name: $e\n$s');
      }
    } else {
      CustomToast.showToast(context, msg: 'offerwall-locked');
    }
  }

  @override
  bool hasValidConfig() => config?.appId.isNotEmpty == true;
}

// SURVEY PROVIDER - SDK BASED
class CpxResearchSurveyProvider extends OfferwallProvider {
  CpxResearchSurveyProvider()
    : super(
        name: 'CPX Research',
        gradient: [
          Color.fromRGBO(232, 245, 254, 1),
          Color.fromRGBO(189, 227, 253, 1),
          Color.fromRGBO(149, 209, 252, 1),
        ],
      );

  @override
  Future<void> init({required String userId}) async {}

  @override
  Future<void> show({
    required BuildContext context,
    required String userId,
    required String email,
  }) async {
    final String appId = config?.appId ?? '';

    if (appId.isNotEmpty) {
      try {
        CustomToast.showToast(context, msg: 'loading');
        showCPXBrowserDialog(
          context: context,
          config: CPXConfig(appID: appId, userID: userId),
        );
      } catch (e, s) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
         // debugPrint('❌ Error showing $name: $e\n$s');
      }
    } else {
      CustomToast.showToast(context, msg: 'offerwall-locked');
    }
  }

  @override
  bool hasValidConfig() => config?.appId.isNotEmpty == true;
}

class BitlabsSurveyProvider extends OfferwallProvider {
  BitlabsSurveyProvider()
    : super(
        name: 'Bitlabs',
        gradient: [
          Color.fromRGBO(0, 123, 255, 1),
          Color.fromRGBO(1, 85, 175, 1),
        ],
      );

  static final BitLabs _bitLabs = BitLabs.instance;

  @override
  Future<void> init({required String userId}) async {
    final String token = config?.token ?? '';

    if (token.isNotEmpty) {
      try {
        _bitLabs.init(token, userId);
      } catch (e, s) {
         // debugPrint('❌ Error initializing $name: $e\n$s');
      }
    } else {
       // debugPrint('⚠️ Bitlabs token is missing in config');
    }
  }

  @override
  Future<void> show({
    required BuildContext context,
    required String userId,
    required String email,
  }) async {
    final String token = config?.token ?? '';

    if (token.isNotEmpty) {
      try {
        CustomToast.showToast(context, msg: 'loading');
        _bitLabs.launchOfferWall(context);
      } catch (e, s) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
         // debugPrint('❌ Error showing $name: $e\n$s');
      }
    } else {
      CustomToast.showToast(context, msg: 'offerwall-locked');
    }
  }

  @override
  bool hasValidConfig() => config?.token.isNotEmpty == true;
}

class GrowDeckTaskProvider extends OfferwallProvider {
  GrowDeckTaskProvider()
    : super(
        name: 'GrowDeck',
        gradient: [
          Color.fromRGBO(78, 78, 78, 1),
          Color.fromRGBO(12, 12, 12, 1),
        ],
      );

  @override
  Future<void> init({required String userId}) async {
    final String appId = config?.appId ?? '';
    final String secretKey = config?.secretKey ?? '';

    if (appId.isNotEmpty && secretKey.isNotEmpty) {
      try {
        await MethodChannelGrowdeckPlaytimePlugin.initialize(
          appId: appId,
          userId: userId,
          secretKey: secretKey,
        );
      } catch (e, s) {
         // debugPrint('❌ Error initializing $name: $e\n$s');
      }
    } else {
       // debugPrint('⚠️ GrowDeck appId or secretKey is missing in config');
    }
  }

  @override
  Future<void> show({
    required BuildContext context,
    required String userId,
    required String email,
  }) async {
    final String appId = config?.appId ?? '';
    final String secretKey = config?.secretKey ?? '';

    if (appId.isNotEmpty && secretKey.isNotEmpty) {
      try {
        CustomToast.showToast(context, msg: 'loading');
        await MethodChannelGrowdeckPlaytimePlugin.show();
      } catch (e, s) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
         // debugPrint('❌ Error showing $name: $e\n$s');
      }
    } else {
      CustomToast.showToast(context, msg: 'offerwall-locked');
    }
  }

  @override
  bool hasValidConfig() =>
      config?.appId.isNotEmpty == true && config?.secretKey.isNotEmpty == true;
}

class PlaytimeAdsTaskProvider extends OfferwallProvider {
  PlaytimeAdsTaskProvider()
    : super(
        name: 'Playtime Ads',
        gradient: [Colors.white, Color.fromRGBO(136, 59, 236, 1)],
      );

  @override
  Future<void> init({required String userId}) async {
    final String appKey = config?.appKey ?? '';
    if (appKey.isNotEmpty) {
      try {
        await PlaytimeAds.initSdk(appKey: appKey, userId: userId);
      } catch (e, s) {
         // debugPrint('❌ Error initializing $name: $e\n$s');
      }
    } else {
       // debugPrint('⚠️ Playtime Ads appKey is missing in config');
    }
  }

  @override
  Future<void> show({
    required BuildContext context,
    required String userId,
    required String email,
  }) async {
    final String appKey = config?.appKey ?? '';
    if (appKey.isNotEmpty) {
      try {
        CustomToast.showToast(context, msg: 'loading');
        await PlaytimeAds.launchOfferwall();
      } catch (e, s) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
         // debugPrint('❌ Error showing $name: $e\n$s');
      }
    } else {
      CustomToast.showToast(context, msg: 'offerwall-locked');
    }
  }

  @override
  bool hasValidConfig() => config?.appKey.isNotEmpty == true;
}
