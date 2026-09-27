import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'haptic_service.dart';
import 'storage_service.dart';

enum HapticType {
  selection,
  light,
  medium,
  heavy,
}

/// ============================================================================
/// CRAZY RACING CENTRALIZED AUDIO MANAGER
/// ============================================================================
/// Features:
/// - 10 Dedicated Sound Effects: Button Click, Car Engine, Coin Pickup, Nitro,
///   Crash, Near Miss, Power-up, Countdown, Game Over, High Score.
/// - 3 Music Channels: Menu Music, Looping Gameplay Music, Game Over Music.
/// - Independent Volume Controls for Sound (SFX) & Music (BGM).
/// - Enable/Disable toggles with local storage synchronization.
/// - Bulletproof Missing Asset Guard: Never crashes if any audio file is missing.
/// - Intelligent System Sound & Haptic Fallbacks.
/// - Complete Resource Disposal.
/// ============================================================================
class CrazyAudioManager {
  static final CrazyAudioManager _instance = CrazyAudioManager._internal();
  factory CrazyAudioManager() => _instance;
  CrazyAudioManager._internal();

  // ----------------------------------------------------
  // Audio Player Instances (Centralized Channels)
  // ----------------------------------------------------
  AudioPlayer? _sfxPlayer;
  AudioPlayer? _bgmPlayer;
  AudioPlayer? _enginePlayer;
  AudioPlayer? _nitroPlayer;

  // Track known missing assets to prevent log spam
  final Set<String> _missingAssets = {};

  // ----------------------------------------------------
  // Settings & Volume States
  // ----------------------------------------------------
  bool soundEnabled = true;
  bool musicEnabled = true;
  bool vibrationEnabled = true;

  double soundVolume = 1.0; // 0.0 to 1.0
  double musicVolume = 0.8; // 0.0 to 1.0

  bool _isEngineRunning = false;
  bool _isNitroPlaying = false;
  String? _currentBgmTrack;

  // ----------------------------------------------------
  // Initialization & Setup
  // ----------------------------------------------------
  Future<void> init({
    bool? sound,
    bool? music,
    bool? vibration,
    double? sfxVolume,
    double? bgmVolume,
  }) async {
    soundEnabled = sound ?? RunnerStorageService.isSoundEnabled();
    musicEnabled = music ?? RunnerStorageService.isMusicEnabled();
    vibrationEnabled = vibration ?? RunnerStorageService.isVibrationEnabled();
    soundVolume = (sfxVolume ?? 1.0).clamp(0.0, 1.0);
    musicVolume = (bgmVolume ?? 0.8).clamp(0.0, 1.0);

    _initPlayers();
  }

  void _initPlayers() {
    try {
      _sfxPlayer ??= AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
      _sfxPlayer?.setVolume(soundVolume).catchError((_) {});

      _bgmPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      _bgmPlayer?.setVolume(musicVolume).catchError((_) {});

      _enginePlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      _enginePlayer?.setVolume((soundVolume * 0.35).clamp(0.0, 1.0)).catchError((_) {});

      _nitroPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      _nitroPlayer?.setVolume((soundVolume * 0.65).clamp(0.0, 1.0)).catchError((_) {});
    } catch (_) {
      // Graceful fallback if platform audio engine is busy or unavailable
    }
  }

  // ----------------------------------------------------
  // Volume Controls
  // ----------------------------------------------------
  void setSoundVolume(double volume) {
    soundVolume = volume.clamp(0.0, 1.0);
    try {
      _sfxPlayer?.setVolume(soundVolume).catchError((_) {});
      _enginePlayer?.setVolume((soundVolume * 0.35).clamp(0.0, 1.0)).catchError((_) {});
      _nitroPlayer?.setVolume((soundVolume * 0.65).clamp(0.0, 1.0)).catchError((_) {});
    } catch (_) {}
  }

  void setMusicVolume(double volume) {
    musicVolume = volume.clamp(0.0, 1.0);
    try {
      _bgmPlayer?.setVolume(musicVolume).catchError((_) {});
    } catch (_) {}
  }

  // ----------------------------------------------------
  // Enable / Disable Settings
  // ----------------------------------------------------
  void setSoundEnabled(bool value) {
    soundEnabled = value;
    if (!soundEnabled) {
      stopCarEngine();
      stopNitroSound();
    }
  }

  void setMusicEnabled(bool value) {
    musicEnabled = value;
    if (!musicEnabled) {
      stopBgm();
    }
  }

  void setVibrationEnabled(bool value) {
    vibrationEnabled = value;
  }

  void toggleSound() => setSoundEnabled(!soundEnabled);
  void toggleMusic() => setMusicEnabled(!musicEnabled);
  void toggleVibration() => setVibrationEnabled(!vibrationEnabled);

  // ----------------------------------------------------
  // Generic Safe Audio File Player
  // ----------------------------------------------------
  Future<void> _playSound(
    String filename, {
    double volumeScale = 1.0,
    HapticType? fallbackHaptic,
  }) async {
    // 1. Trigger haptics if requested
    if (fallbackHaptic != null) {
      triggerHaptic(fallbackHaptic);
    }

    // 2. Check if sound is enabled
    if (!soundEnabled || soundVolume <= 0.0) return;

    // 3. Skip attempting if we already know this asset is missing
    final assetPath = 'audio/$filename';
    if (_missingAssets.contains(assetPath)) {
      // Use subtle native platform click sound if primary asset is missing
      _fallbackNativeSound(filename);
      return;
    }

    try {
      _initPlayers();
      final effectiveVolume = (soundVolume * volumeScale).clamp(0.0, 1.0);
      await _sfxPlayer?.setVolume(effectiveVolume);
      await _sfxPlayer?.stop();
      await _sfxPlayer?.play(AssetSource(assetPath));
    } catch (_) {
      // Gracefully record missing asset and trigger fallback without throwing
      _missingAssets.add(assetPath);
      _fallbackNativeSound(filename);
    }
  }

  void _fallbackNativeSound(String filename) {
    try {
      if (filename.contains('click') || filename.contains('button') || filename.contains('swipe')) {
        SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {}
  }

  // ----------------------------------------------------
  // 10 SOUND EFFECTS (SFX)
  // ----------------------------------------------------

  /// 1. Button Click SFX
  void playButtonClick() {
    triggerHaptic(HapticType.selection);
    if (!soundEnabled) return;
    _playSound('click.mp3');
  }
  void playClick() => playButtonClick();
  void playSwipe() => playButtonClick();

  /// 2. Car Engine Sound (Continuous Loop & Pitch Scaler)
  void startCarEngine({double initialSpeedRatio = 0.3}) {
    if (!soundEnabled || _isEngineRunning) return;
    _isEngineRunning = true;
    try {
      _initPlayers();
      final effectiveVol = (soundVolume * 0.35).clamp(0.0, 1.0);
      _enginePlayer?.setVolume(effectiveVol);
      _enginePlayer?.setPlaybackRate((0.8 + initialSpeedRatio * 0.6).clamp(0.5, 2.0));
      _enginePlayer?.play(AssetSource('audio/engine_loop.mp3')).catchError((_) {
        _missingAssets.add('audio/engine_loop.mp3');
      });
    } catch (_) {}
  }

  void updateEnginePitch(double speedRatio) {
    if (!_isEngineRunning || !soundEnabled) return;
    try {
      final rate = (0.75 + speedRatio * 0.75).clamp(0.6, 2.0);
      _enginePlayer?.setPlaybackRate(rate).catchError((_) {});
    } catch (_) {}
  }

  void stopCarEngine() {
    _isEngineRunning = false;
    try {
      _enginePlayer?.stop().catchError((_) {});
    } catch (_) {}
  }

  /// 3. Coin Pickup SFX
  void playCoinPickup() {
    triggerHaptic(HapticType.selection);
    if (!soundEnabled) return;
    _playSound('coin.mp3', volumeScale: 0.9);
  }
  void playCoin() => playCoinPickup();

  /// 4. Nitro Boost Sound
  void playNitro() {
    triggerHaptic(HapticType.medium);
    if (!soundEnabled) return;
    _playSound('nitro_boost.mp3', volumeScale: 1.0);
  }

  void startNitroSound() {
    if (!soundEnabled || _isNitroPlaying) return;
    _isNitroPlaying = true;
    triggerHaptic(HapticType.heavy);
    try {
      _initPlayers();
      final effectiveVol = (soundVolume * 0.7).clamp(0.0, 1.0);
      _nitroPlayer?.setVolume(effectiveVol);
      _nitroPlayer?.play(AssetSource('audio/nitro_loop.mp3')).catchError((_) {
        _missingAssets.add('audio/nitro_loop.mp3');
      });
    } catch (_) {}
  }

  void stopNitroSound() {
    _isNitroPlaying = false;
    try {
      _nitroPlayer?.stop().catchError((_) {});
    } catch (_) {}
  }

  /// 5. Crash Impact SFX
  void playCrash() {
    triggerHaptic(HapticType.heavy);
    if (!soundEnabled) return;
    _playSound('crash.mp3', volumeScale: 1.0);
  }
  void playHit() => playCrash();

  /// 6. Near Miss Overtake SFX
  void playNearMiss() {
    triggerHaptic(HapticType.light);
    if (!soundEnabled) return;
    _playSound('near_miss.mp3', volumeScale: 0.85);
  }

  void playCombo(int comboLevel) {
    if (comboLevel >= 4) {
      triggerHaptic(HapticType.heavy);
    } else if (comboLevel >= 2) {
      triggerHaptic(HapticType.medium);
    } else {
      triggerHaptic(HapticType.light);
    }
    if (!soundEnabled) return;
    if (comboLevel >= 3) {
      _playSound('powerup.mp3', volumeScale: 0.95);
    } else {
      _playSound('gem.mp3', volumeScale: 0.85);
    }
  }

  void playComboLost() {
    if (!soundEnabled) return;
    _playSound('slide.mp3', volumeScale: 0.6);
  }

  /// 7. Power-up Collection SFX
  void playPowerUp() {
    triggerHaptic(HapticType.medium);
    if (!soundEnabled) return;
    _playSound('powerup.mp3', volumeScale: 1.0);
  }
  void playShieldBreak() {
    triggerHaptic(HapticType.medium);
    if (!soundEnabled) return;
    _playSound('hit.mp3', volumeScale: 0.8);
  }
  void playGem() {
    triggerHaptic(HapticType.medium);
    if (!soundEnabled) return;
    _playSound('gem.mp3', volumeScale: 0.9);
  }

  /// 8. Countdown SFX (3-2-1 Beep & GO!)
  void playCountdownBeep() {
    triggerHaptic(HapticType.light);
    if (!soundEnabled) return;
    _playSound('countdown_beep.mp3', volumeScale: 0.85);
  }

  void playCountdownGo() {
    triggerHaptic(HapticType.heavy);
    if (!soundEnabled) return;
    _playSound('countdown_go.mp3', volumeScale: 1.0);
  }

  void playCountdown(int count) {
    if (count > 0) {
      playCountdownBeep();
    } else {
      playCountdownGo();
    }
  }

  /// 9. Game Over Defeat SFX
  void playGameOverSound() {
    triggerHaptic(HapticType.heavy);
    stopCarEngine();
    stopNitroSound();
    if (!soundEnabled) return;
    _playSound('gameover.mp3', volumeScale: 1.0);
  }
  void playGameOver() => playGameOverSound();

  /// 10. High Score / Victory Celebration SFX
  void playHighScore() {
    triggerHaptic(HapticType.heavy);
    if (!soundEnabled) return;
    _playSound('high_score.mp3', volumeScale: 1.0);
  }
  void playVictory() => playHighScore();

  // Jump & Slide helpers
  void playJump() {
    triggerHaptic(HapticType.light);
    if (!soundEnabled) return;
    _playSound('jump.mp3', volumeScale: 0.8);
  }

  void playSlide() {
    triggerHaptic(HapticType.light);
    if (!soundEnabled) return;
    _playSound('slide.mp3', volumeScale: 0.8);
  }

  // ----------------------------------------------------
  // MUSIC TRACKS (BGM)
  // ----------------------------------------------------

  /// 1. Menu Music
  void playMenuMusic() {
    if (!musicEnabled || musicVolume <= 0.0) return;
    _playBgmTrack('menu_bgm.mp3', loop: true);
  }

  /// 2. Gameplay Music (Always Looped)
  void playGameplayMusic() {
    if (!musicEnabled || musicVolume <= 0.0) return;
    _playBgmTrack('runner_bgm.mp3', loop: true);
  }
  void startBgm() => playGameplayMusic();

  /// 3. Game Over Music
  void playGameOverMusic() {
    if (!musicEnabled || musicVolume <= 0.0) return;
    _playBgmTrack('game_over_music.mp3', loop: false);
  }

  Future<void> _playBgmTrack(String filename, {bool loop = true}) async {
    final assetPath = 'audio/$filename';
    if (_currentBgmTrack == assetPath) return;

    if (_missingAssets.contains(assetPath)) return;

    try {
      _initPlayers();
      _currentBgmTrack = assetPath;
      await _bgmPlayer?.setVolume(musicVolume);
      await _bgmPlayer?.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
      await _bgmPlayer?.stop();
      await _bgmPlayer?.play(AssetSource(assetPath));
    } catch (_) {
      _missingAssets.add(assetPath);
    }
  }

  void pauseBgm() {
    try {
      _bgmPlayer?.pause().catchError((_) {});
      _enginePlayer?.pause().catchError((_) {});
      _nitroPlayer?.pause().catchError((_) {});
    } catch (_) {}
  }

  void resumeBgm() {
    if (!musicEnabled) return;
    try {
      _bgmPlayer?.resume().catchError((_) {});
      if (_isEngineRunning) {
        _enginePlayer?.resume().catchError((_) {});
      }
      if (_isNitroPlaying) {
        _nitroPlayer?.resume().catchError((_) {});
      }
    } catch (_) {}
  }

  void stopBgm() {
    _currentBgmTrack = null;
    try {
      _bgmPlayer?.stop().catchError((_) {});
    } catch (_) {}
  }

  // ----------------------------------------------------
  // Haptic Feedback Engine
  // ----------------------------------------------------
  void triggerHaptic(HapticType type) {
    if (!vibrationEnabled) return;
    try {
      switch (type) {
        case HapticType.selection:
          CrazyHapticManager().buttonPress();
          break;
        case HapticType.light:
          CrazyHapticManager().coinPickup();
          break;
        case HapticType.medium:
          CrazyHapticManager().powerUp();
          break;
        case HapticType.heavy:
          CrazyHapticManager().crash();
          break;
      }
    } catch (_) {}
  }

  // ----------------------------------------------------
  // Resource Disposal
  // ----------------------------------------------------
  void dispose() {
    stopCarEngine();
    stopNitroSound();
    stopBgm();

    try {
      _sfxPlayer?.dispose();
      _bgmPlayer?.dispose();
      _enginePlayer?.dispose();
      _nitroPlayer?.dispose();
    } catch (_) {}

    _sfxPlayer = null;
    _bgmPlayer = null;
    _enginePlayer = null;
    _nitroPlayer = null;
    _missingAssets.clear();
  }
}

/// ============================================================================
/// BACKWARD COMPATIBILITY ALIAS
/// ============================================================================
typedef RunnerAudioService = CrazyAudioManager;
