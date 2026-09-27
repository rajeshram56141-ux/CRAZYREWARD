import 'dart:io';
import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';

class DeviceIntegrityService {
  /// Fetches complete environment & device security bundle
  static Future<Map<String, dynamic>> getSecurityBundle() async {
    bool isRooted = false;
    bool isRealDevice = true;
    bool isDevOptions = false;
    bool isMockLocation = false;
    String androidIdStr = '';

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        isRooted = await SafeDevice.isJailBroken;
        isRealDevice = await SafeDevice.isRealDevice;
        isDevOptions = await SafeDevice.isDevelopmentModeEnable;
        isMockLocation = await SafeDevice.isMockLocation;
      }
    } catch (e) {
       // debugPrint('🔥 Error fetching safe_device checks: $e');
    }

    try {
      if (Platform.isAndroid) {
        androidIdStr = await const AndroidId().getId() ?? '';
      }
    } catch (e) {
       // debugPrint('🔥 Error fetching android_id: $e');
    }

    return {
      'isRooted': isRooted,
      'isEmulator': !isRealDevice,
      'isDeveloperOptions': isDevOptions,
      'isMockLocation': isMockLocation,
      'physicalDeviceId': androidIdStr,
      'os_platform': Platform.operatingSystem,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Checks if device is suspicious (Rooted, Emulator, or Developer Options)
  static Future<bool> isSuspiciousEnvironment() async {
    try {
      final isRooted = await SafeDevice.isJailBroken;
      final isRealDevice = await SafeDevice.isRealDevice;
      final isDevOptions = await SafeDevice.isDevelopmentModeEnable;
      return isRooted || !isRealDevice || isDevOptions;
    } catch (e) {
      return false;
    }
  }
}
