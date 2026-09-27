import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pubscale_plugin_platform_interface.dart';

/// An implementation of [PubscalePluginPlatform] that uses method channels.
class MethodChannelPubscalePlugin extends PubscalePluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pubscale_plugin');

  @override
  Future<bool> initSDK(String appId, String userId) async {
    try {
      await methodChannel.invokeMethod<bool>('initSDK', {
        'appId': appId,
        'userId': userId,
      });
      log('Pubscale initialization succeeded');
      return true;
    } catch (e) {
      log('Failed to initialize SDK: $e');
      return false;
    }
  }

  @override
  Future<bool> showOfferWall() async {
    try {
      await methodChannel.invokeMethod<bool>('showOfferwall');
      log('Pubscale offerwall shown successfully');
      return true;
    } catch (e) {
      log('Failed to show offerwall: $e');
      return false;
    }
  }
}
