import 'package:flutter/services.dart';

class PlaytimeAds {
  static const MethodChannel _channel = MethodChannel('playtime_ads');

  static Future<bool> initSdk({
    required String appKey,
    required String userId,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('initSdk', {
        'appKey': appKey,
        'userId': userId,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> destroySdk() async {
    try {
      final result = await _channel.invokeMethod<bool>('destroySdk');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> launchOfferwall() async {
    try {
      final result = await _channel.invokeMethod<bool>('launchOfferwall');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
