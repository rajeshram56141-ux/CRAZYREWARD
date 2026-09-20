import 'package:flutter/material.dart';

import 'pubscale_plugin_platform_interface.dart';

class PubscalePlugin {
  static PubscalePlugin? _instance;

  static PubscalePlugin get instance => _instance ??= PubscalePlugin();

  final PubscalePluginPlatform _platform = PubscalePluginPlatform.instance;

  Future<bool> initSDK({
    required String appId,
    required String userId,
  }) async {
    try {
      await _platform.initSDK(appId, userId);
      return true; // Initialization succeeded
    } catch (e) {
      debugPrint('Failed to initialize SDK: $e');
      return false; // Initialization failed
    }
  }

  Future<bool> showOfferwall() async {
    try {
      await _platform.showOfferWall();
      return true; // Offerwall shown successfully
    } catch (e) {
      debugPrint('Failed to show offerwall: $e');
      return false; // Failed to show offerwall
    }
  }
}
