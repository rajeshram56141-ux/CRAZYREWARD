import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'storage_service.dart';

/// ============================================================================
/// CRAZY RACING CENTRALIZED HAPTIC FEEDBACK MANAGER
/// ============================================================================
/// Features:
/// - Subtle, tactile haptic vibrations for:
///   * Coin Pickup (Ultra-light micro-tick)
///   * Power-up (Crisp uplifting pulse)
///   * Near Miss (Speed overtaker pulse)
///   * Nitro Activation (Tactical boost surge)
///   * Crash (Impact shudder - restrained & non-excessive)
///   * Button Press (Subtle UI click)
/// - Safe Device Detection: Gracefully falls back on emulators or devices without hardware vibration.
/// - Rapid-fire throttle / rate limiter to prevent excessive battery drain or motor wear.
/// - Vibration ON/OFF toggle with local persistence.
/// ============================================================================
class CrazyHapticManager {
  static final CrazyHapticManager _instance = CrazyHapticManager._internal();
  factory CrazyHapticManager() => _instance;
  CrazyHapticManager._internal();

  // State
  bool _enabled = true;
  bool? _hasVibratorHardware;
  bool? _hasCustomVibrations;

  // Rate Limiting (Prevent excessive buzzing on clustered items)
  int _lastCoinHapticTimestamp = 0;
  int _lastNearMissHapticTimestamp = 0;
  int _lastButtonHapticTimestamp = 0;

  bool get isEnabled => _enabled;

  /// Initialize hardware capabilities & load user preference
  Future<void> init({bool? enabled}) async {
    _enabled = enabled ?? RunnerStorageService.isVibrationEnabled();
    _checkHardwareCapabilities();
  }

  void _checkHardwareCapabilities() {
    try {
      Vibration.hasVibrator().then((hasVib) {
        _hasVibratorHardware = hasVib;
      }).catchError((_) {
        _hasVibratorHardware = false;
      });

      Vibration.hasCustomVibrationsSupport().then((hasCustom) {
        _hasCustomVibrations = hasCustom;
      }).catchError((_) {
        _hasCustomVibrations = false;
      });
    } catch (_) {
      _hasVibratorHardware = false;
      _hasCustomVibrations = false;
    }
  }

  // ----------------------------------------------------
  // Settings & Toggles
  // ----------------------------------------------------
  void setEnabled(bool value) {
    _enabled = value;
    RunnerStorageService.setVibrationEnabled(value);
    if (value) {
      buttonPress();
    }
  }

  void toggle() => setEnabled(!_enabled);

  // ----------------------------------------------------
  // 6 SPECIFIC SUBTLE HAPTIC PROFILES
  // ----------------------------------------------------

  /// 1. Button Press (Subtle UI tick)
  void buttonPress() {
    if (!_enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastButtonHapticTimestamp < 40) return;
    _lastButtonHapticTimestamp = now;

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
  void click() => buttonPress();

  /// 2. Coin Pickup (Ultra-light, throttled micro-tick for dense coin lines)
  void coinPickup() {
    if (!_enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    // 35ms cooldown prevents motor buzz overload on rapid coin magnets
    if (now - _lastCoinHapticTimestamp < 35) return;
    _lastCoinHapticTimestamp = now;

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// 3. Power-Up Collection (Crisp, rewarding medium pulse)
  void powerUp() {
    if (!_enabled) return;
    try {
      HapticFeedback.mediumImpact();
      _customVibrate(durationMs: 25, amplitude: 90);
    } catch (_) {}
  }

  /// 4. Near Miss Overtake (Exciting speed pulse)
  void nearMiss({int comboLevel = 1}) {
    if (!_enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNearMissHapticTimestamp < 80) return;
    _lastNearMissHapticTimestamp = now;

    try {
      if (comboLevel >= 3) {
        HapticFeedback.mediumImpact();
        _customVibrate(durationMs: 30, amplitude: 120);
      } else {
        HapticFeedback.lightImpact();
        _customVibrate(durationMs: 18, amplitude: 80);
      }
    } catch (_) {}
  }

  /// 5. Nitro Activation (Tactical boost surge)
  void nitroActivation() {
    if (!_enabled) return;
    try {
      HapticFeedback.mediumImpact();
      _customVibrate(durationMs: 32, amplitude: 130);
    } catch (_) {}
  }

  /// 6. Crash Impact (Impact shudder - restrained to 40ms to avoid excessive vibration)
  void crash() {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
      _customVibrate(durationMs: 40, amplitude: 160);
    } catch (_) {}
  }

  // ----------------------------------------------------
  // Additional Game Events (Subtle)
  // ----------------------------------------------------
  void laneShift() {
    if (!_enabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  void jump() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void slide() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void countdownBeep() {
    if (!_enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void countdownGo() {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
      _customVibrate(durationMs: 35, amplitude: 140);
    } catch (_) {}
  }

  void gameOver() {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
      _customVibrate(durationMs: 40, amplitude: 120);
    } catch (_) {}
  }

  void victory() {
    if (!_enabled) return;
    try {
      HapticFeedback.heavyImpact();
      _customVibrate(durationMs: 35, amplitude: 130);
    } catch (_) {}
  }

  // ----------------------------------------------------
  // Low-level Safe Hardware Trigger
  // ----------------------------------------------------
  void _customVibrate({required int durationMs, required int amplitude}) {
    if (_hasVibratorHardware == false) return;

    try {
      if (_hasCustomVibrations == true) {
        Vibration.vibrate(
          duration: durationMs.clamp(5, 50),
          amplitude: amplitude.clamp(1, 255),
        ).catchError((_) {});
      } else {
        Vibration.vibrate(
          duration: durationMs.clamp(5, 50),
        ).catchError((_) {});
      }
    } catch (_) {
      // Graceful silence on unsupported devices
    }
  }
}

/// ============================================================================
/// BACKWARD COMPATIBILITY ALIAS
/// ============================================================================
typedef RunnerHapticService = CrazyHapticManager;
