import 'package:flutter/services.dart';

class SuperOfferNativeManager {
  static const _channel = MethodChannel('com.crazyreward.games/app_manager');

  static Future<bool> isAppInstalled(String packageName) async {
    if (packageName.isEmpty) return false;
    try {
      final bool result = await _channel.invokeMethod<bool>('isAppInstalled', {'packageName': packageName}) ?? false;
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> launchApp(String packageName) async {
    if (packageName.isEmpty) return false;
    try {
      final bool result = await _channel.invokeMethod<bool>('launchApp', {'packageName': packageName}) ?? false;
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getRecentlyInstalledPackage(int startTimeMs) async {
    try {
      final String? result = await _channel.invokeMethod<String?>('getRecentlyInstalledPackage', {'startTimeMs': startTimeMs});
      return result;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkUsagePermission() async {
    try {
      final bool result = await _channel.invokeMethod<bool>('checkUsagePermission') ?? false;
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (e) {
      // ignore error
    }
  }

  static Future<int> getAppUsageDuration(String packageName, int startTimeMs) async {
    if (packageName.isEmpty) return 0;
    try {
      final int result = await _channel.invokeMethod<int>('getAppUsageDuration', {
        'packageName': packageName,
        'startTimeMs': startTimeMs,
      }) ?? 0;
      return result;
    } catch (e) {
      return 0;
    }
  }

  static Future<String?> getAppName(String packageName) async {
    if (packageName.isEmpty) return null;
    try {
      final String? result = await _channel.invokeMethod<String?>('getAppName', {'packageName': packageName});
      return result;
    } catch (e) {
      return null;
    }
  }

  static Future<int> getInstallTime(String packageName) async {
    if (packageName.isEmpty) return 0;
    try {
      final int result = await _channel.invokeMethod<int>('getInstallTime', {'packageName': packageName}) ?? 0;
      return result;
    } catch (e) {
      return 0;
    }
  }
}
