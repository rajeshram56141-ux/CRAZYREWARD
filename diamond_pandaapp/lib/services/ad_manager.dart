import 'dart:async';

import 'package:flutter/material.dart';
import 'package:topon_ad_plugin/topon_ad_plugin.dart';

import '../utils/constant/constant.dart';
import 'analytics_service.dart';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;
  AdManager._internal();

  bool _isSdkInitialized = false;

  bool _isRewardedLoaded = false;
  bool _isInterstitialLoaded = false;
  ToponNativeAdInfo? _cachedNativeAd;
  final ValueNotifier<ToponNativeAdInfo?> nativeAdNotifier = ValueNotifier<ToponNativeAdInfo?>(null);

  Future<bool>? _rewardedLoadFuture;
  Future<bool>? _interstitialLoadFuture;

  VoidCallback? _onRewardEarned;
  VoidCallback? _onRewardedAdClosed;
  VoidCallback? _onInterstitialClosed;
  Future<void> Function()? _onRewardAdClicked;

  bool get isRewardedLoaded => _isRewardedLoaded;
  bool get isInterstitialLoaded => _isInterstitialLoaded;
  ToponNativeAdInfo? get cachedNativeAd => _cachedNativeAd;

  /* ---------------- INIT ---------------- */

  Future<bool> initSdk() async {
    if (_isSdkInitialized) return true;

    final result = await ToponAdPlugin.initializeSdk(
      appId: AdKeys.appId,
      appKey: AdKeys.appKey,
    );

    if (result) {
      _isSdkInitialized = true;
      ToponAdPlugin.setUpListeners();
      ToponAdPlugin.onEvent = _handleAdEvents;
    }

    return result;
  }

  /* ---------------- SMART PRELOAD ---------------- */

  /// Preload rewarded video ad safely in background.
  Future<bool> preloadRewarded() async {
    if (!AdKeys.isAdsEnabled || AdKeys.rewardedKey.trim().isEmpty) {
      _isRewardedLoaded = false;
      return false;
    }
    if (_isRewardedLoaded) return true;
    if (_rewardedLoadFuture != null) return _rewardedLoadFuture!;

    _rewardedLoadFuture = _loadRewarded();
    try {
      final res = await _rewardedLoadFuture!;
      return res;
    } catch (_) {
      return false;
    } finally {
      _rewardedLoadFuture = null;
    }
  }

  /// Preload interstitial ad safely in background.
  Future<bool> preloadInterstitial() async {
    if (!AdKeys.isAdsEnabled || AdKeys.interstitialKey.trim().isEmpty) {
      _isInterstitialLoaded = false;
      return false;
    }
    if (_isInterstitialLoaded) return true;
    if (_interstitialLoadFuture != null) return _interstitialLoadFuture!;

    _interstitialLoadFuture = _loadInterstitial();
    try {
      final res = await _interstitialLoadFuture!;
      return res;
    } catch (_) {
      return false;
    } finally {
      _interstitialLoadFuture = null;
    }
  }

  Future<bool> _loadRewarded() async {
    if (AdKeys.rewardedKey.trim().isEmpty) {
      _isRewardedLoaded = false;
      return false;
    }
    try {
      _isRewardedLoaded = await ToponAdPlugin.loadRewardedAd(
        placementId: AdKeys.rewardedKey,
      );
    } catch (e) {
      _isRewardedLoaded = false;
    }
    return _isRewardedLoaded;
  }

  Future<bool> _loadInterstitial() async {
    if (AdKeys.interstitialKey.trim().isEmpty) {
      _isInterstitialLoaded = false;
      return false;
    }
    try {
      _isInterstitialLoaded = await ToponAdPlugin.loadInterstitialAd(
        placementId: AdKeys.interstitialKey,
      );
    } catch (e) {
      _isInterstitialLoaded = false;
    }
    return _isInterstitialLoaded;
  }

  /* ---------------- NATIVE AD ---------------- */

  Future<ToponNativeAdInfo?>? _nativeLoadFuture;

  /// Loads native ad from TopOn SDK
  Future<ToponNativeAdInfo?> loadNativeAd() async {
    if (!AdKeys.isAdsEnabled || !AdKeys.isHomeNativeEnabled || AdKeys.nativeKey.trim().isEmpty) {
      return null;
    }
    if (_cachedNativeAd != null) {
      return _cachedNativeAd;
    }
    if (_nativeLoadFuture != null) {
      return await _nativeLoadFuture;
    }
    _nativeLoadFuture = _performLoadNativeAd();
    try {
      final res = await _nativeLoadFuture;
      return res;
    } finally {
      _nativeLoadFuture = null;
    }
  }

  Future<ToponNativeAdInfo?> _performLoadNativeAd() async {
    try {
      final bool loaded = await ToponAdPlugin.loadNativeAd(
        placementId: AdKeys.nativeKey,
      );
      if (loaded) {
        final info = await ToponAdPlugin.getNativeAdInfo();
        if (info != null) {
          _cachedNativeAd = info;
          nativeAdNotifier.value = info;
          return info;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Triggers click on TopOn native ad
  Future<bool> clickNativeAd() async {
    try {
      return await ToponAdPlugin.clickNativeAd();
    } catch (_) {
      return false;
    }
  }

  /* ---------------- SHOW REWARDED ---------------- */

  Future<void> showRewardedAd({
    required BuildContext context,
    required Future<void> Function() onReward,
    required Future<void> Function() onAdClicked,
    Function(bool)? onAdClosed,
    VoidCallback? onAdShown,
    VoidCallback? onAdFailed,
  }) async {
    if (!AdKeys.isAdsEnabled || AdKeys.rewardedKey.trim().isEmpty) {
      if (onAdFailed != null) {
        onAdFailed();
      }
      return;
    }

    // If an existing preload is running in background, await it
    if (_rewardedLoadFuture != null) {
      try {
        await _rewardedLoadFuture;
      } catch (_) {}
    }

    // If not loaded yet, initiate preload
    if (!_isRewardedLoaded) {
      await preloadRewarded();
    }

    // Wait briefly for TopOn callback if ad is still buffering (up to 3 seconds)
    if (!_isRewardedLoaded) {
      int retries = 0;
      while (!_isRewardedLoaded && retries < 12) {
        await Future.delayed(const Duration(milliseconds: 250));
        retries++;
      }
    }

    if (!_isRewardedLoaded) {
      if (!context.mounted) return;
      if (onAdFailed != null) {
        onAdFailed();
      }
      return;
    }

    final completer = Completer<void>();
    bool hasEarnedReward = false;

    /// Reward callback
    _onRewardEarned = () async {
      hasEarnedReward = true;
      AnalyticsService.logAdRewardEarned(
        adFormat: 'rewarded_video',
        provider: 'topon',
      );
      await onReward();
    };

    /// Close callback
    _onRewardedAdClosed = () async {
      _isRewardedLoaded = false;
      if (onAdClosed != null) {
        onAdClosed(hasEarnedReward);
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    };

    /// Click callback
    _onRewardAdClicked = onAdClicked;

    final result = await ToponAdPlugin.showRewardedAd();

    if (result) {
      if (onAdShown != null) {
        onAdShown();
      }
    } else {
      _isRewardedLoaded = false;
      if (onAdFailed != null) {
        onAdFailed();
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    return completer.future;
  }

  /* ---------------- SHOW INTERSTITIAL ---------------- */

  Future<void> showInterstitialAd({
    required VoidCallback onClosed,
    VoidCallback? onAdShown,
    VoidCallback? onAdFailed,
  }) async {
    if (!AdKeys.isAdsEnabled || AdKeys.interstitialKey.trim().isEmpty) {
      onClosed.call();
      return;
    }

    if (!_isInterstitialLoaded) {
      await _loadInterstitial();
    }

    if (!_isInterstitialLoaded) {
      if (onAdFailed != null) {
        onAdFailed();
      }
      // Fallback: call completion directly when ad is unavailable
      onClosed.call();
      return;
    }

    final completer = Completer<void>();

    _onInterstitialClosed = () async {
      _isInterstitialLoaded = false;
      onClosed.call();

      if (!completer.isCompleted) {
        completer.complete();
      }
    };

    final result = await ToponAdPlugin.showInterstitialAd();

    if (result) {
      if (onAdShown != null) {
        onAdShown();
      }
    } else {
      _isInterstitialLoaded = false;
      if (onAdFailed != null) {
        onAdFailed();
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    return completer.future;
  }

  /* ---------------- EVENT HANDLER ---------------- */

  void _handleAdEvents(String method, dynamic arguments) {
    switch (method) {
      //! ===== REWARDED =====

      case 'onRewardedVideoAdLoaded':
        _isRewardedLoaded = true;
        break;

      case 'onRewardedVideoAdFailed':
        _isRewardedLoaded = false;
        break;

      case 'onReward':
        _onRewardEarned?.call();
        _onRewardEarned = null;
        break;

      case 'onRewardedVideoAdClosed':
        _onRewardedAdClosed?.call();
        _onRewardedAdClosed = null;
        break;

      /// User clicked ad
      case 'onRewardedVideoAdPlayClicked':
        _onRewardAdClicked?.call().catchError((_) {});
        break;

      //! ===== INTERSTITIAL =====

      case 'onInterstitialAdLoaded':
        _isInterstitialLoaded = true;
        break;

      case 'onInterstitialAdLoadFail':
        _isInterstitialLoaded = false;
        break;

      case 'onInterstitialAdClose':
        _onInterstitialClosed?.call();
        _onInterstitialClosed = null;
        break;

      //! ===== NATIVE AD =====
      case 'onNativeAdLoaded':
        ToponAdPlugin.getNativeAdInfo().then((info) {
          if (info != null) {
            _cachedNativeAd = info;
            nativeAdNotifier.value = info;
          }
        }).catchError((_) {});
        break;

      case 'onNativeAdLoadFail':
        break;
    }
  }
}
