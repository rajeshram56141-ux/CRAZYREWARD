import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A Flutter plugin for displaying TopOn Ads using platform channels.
///
/// This plugin supports various ad formats such as interstitial,
/// rewarded video, splash, banner, and native ads. It also allows listening
/// to ad lifecycle events from the native side.
class ToponAdPlugin {
  static const MethodChannel _channel = MethodChannel('topon_ad_plugin');

  /// Callback to listen to native ad events.
  ///
  /// Example:
  /// ```dart
  /// ToponAdPlugin.onEvent = (method, arguments) {
  ///   if (method == 'onRewardedAdCompleted') {
  ///     // Reward the user
  ///   }
  /// };
  /// ```
  static void Function(String method, dynamic arguments)? onEvent;

  /// Initializes the TopOn SDK with the given [appId] and [appKey].
  ///
  /// Returns `true` if initialization is successful, otherwise `false`.
  static Future<bool> initializeSdk({
    required String appId,
    required String appKey,
  }) async {
    try {
      return await _channel.invokeMethod('initSdk', {
        'appId': appId,
        'appKey': appKey,
      });
    } catch (e) {
      return false;
    }
  }

  /// Sets up a listener to receive ad events from the native side.
  ///
  /// Call this once during app startup before loading or showing any ads.
  static void setUpListeners() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (onEvent != null) {
        onEvent!(call.method, call.arguments);
      }
    });
  }

  /// Loads an interstitial ad for the provided [placementId].
  static Future<bool> loadInterstitialAd({required String placementId}) async {
    try {
      return await _channel.invokeMethod('loadInterstitialAd', {
        'placementId': placementId,
      });
    } catch (e) {
      return false;
    }
  }

  /// Shows a previously loaded interstitial ad.
  static Future<bool> showInterstitialAd() async {
    try {
      return await _channel.invokeMethod('showInterstitial');
    } catch (e) {
      return false;
    }
  }

  /// Loads a splash ad for the provided [placementId].
  static Future<bool> loadSplashAd({required String placementId}) async {
    try {
      return await _channel.invokeMethod('loadSplashAd', {
        'placementId': placementId,
      });
    } catch (e) {
      return false;
    }
  }

  /// Loads a banner ad for the provided [placementId] at the given [position].
  static Future<bool> loadBannerAd({
    required String placementId,
    required BannerPosition position,
  }) async {
    try {
      return await _channel.invokeMethod('loadBannerAd', {
        'placementId': placementId,
        'position': position.name,
      });
    } catch (e) {
      return false;
    }
  }

  /// Removes any currently displayed banner ad.
  static Future<bool> removeBannerAd() async {
    try {
      return await _channel.invokeMethod('removeBannerAd');
    } catch (e) {
      return false;
    }
  }

  /// Loads a native ad for the provided [placementId].
  static Future<bool> loadNativeAd({required String placementId}) async {
    try {
      return await _channel.invokeMethod('loadNativeAd', {
        'placementId': placementId,
      });
    } catch (e) {
      return false;
    }
  }

  /// Retrieves information about the loaded native ad.
  ///
  /// Returns a [ToponNativeAdInfo] object if successful, otherwise `null`.
  static Future<ToponNativeAdInfo?> getNativeAdInfo() async {
    try {
      final Map<dynamic, dynamic>? adInfoMap = await _channel.invokeMethod(
        'getNativeAdInfo',
      );
      if (adInfoMap != null) {
        return ToponNativeAdInfo.fromMap(adInfoMap.cast<String, dynamic>());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Triggers click on the currently active TopOn native ad to open advertiser URL/market
  static Future<bool> clickNativeAd() async {
    try {
      final res = await _channel.invokeMethod('clickNativeAd');
      return res == true;
    } catch (e) {
      return false;
    }
  }

  /// Loads a rewarded video ad for the provided [placementId].
  static Future<bool> loadRewardedAd({required String placementId}) async {
    try {
      return await _channel.invokeMethod('loadRewardedAd', {
        'placementId': placementId,
      });
    } catch (e) {
      return false;
    }
  }

  /// Shows a previously loaded rewarded video ad.
  static Future<bool> showRewardedAd() async {
    try {
      return await _channel.invokeMethod('showRewardedAd');
    } catch (e) {
      return false;
    }
  }
}

/// Banner ad position.
enum BannerPosition { top, bottom }

/// A class representing the information of a loaded native ad from TopOn.
class ToponNativeAdInfo {
  final String title;
  final String description;
  final String iconUrl;
  final String mainImageUrl;
  final String callToAction;
  final double? starRating;
  final String adFrom;
  final String adChoiceIconUrl;
  final String videoUrl;
  final double? appPrice;
  final int? appCommentNum;
  final String advertiserName;
  final String adType;
  final String domain;
  final String warning;
  final int? downloadStatus;
  final int? downloadProgress;

  ToponNativeAdInfo({
    required this.title,
    required this.description,
    required this.iconUrl,
    required this.mainImageUrl,
    required this.callToAction,
    this.starRating,
    required this.adFrom,
    required this.adChoiceIconUrl,
    required this.videoUrl,
    this.appPrice,
    this.appCommentNum,
    required this.advertiserName,
    required this.adType,
    required this.domain,
    required this.warning,
    this.downloadStatus,
    this.downloadProgress,
  });

  /// Creates a [ToponNativeAdInfo] object from a map.
  factory ToponNativeAdInfo.fromMap(Map<String, dynamic> map) {
    return ToponNativeAdInfo(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      iconUrl: map['iconUrl'] ?? '',
      mainImageUrl: map['mainImageUrl'] ?? '',
      callToAction: map['callToAction'] ?? '',
      starRating:
          map['starRating'] != null
              ? (map['starRating'] as num).toDouble()
              : null,
      adFrom: map['adFrom'] ?? '',
      adChoiceIconUrl: map['adChoiceIconUrl'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      appPrice:
          map['appPrice'] != null ? (map['appPrice'] as num).toDouble() : null,
      appCommentNum: map['appCommentNum'],
      advertiserName: map['advertiserName'] ?? '',
      adType: map['adType'] ?? '',
      domain: map['domain'] ?? '',
      warning: map['warning'] ?? '',
      downloadStatus: map['downloadStatus'],
      downloadProgress: map['downloadProgress'],
    );
  }
}

/// A Flutter widget that renders a real Android Native Ad from TopOn.
///
/// Supports both Self-Rendering and Template (Express) Native Ads with
/// full AdMob / Google Ad Manager AdChoices (exclamation mark '!') icon support,
/// Meta MediaView/IconView requirements, real touch dispatching, and zero policy issues.
class ToponNativeAdWidget extends StatefulWidget {
  final String placementId;
  final double? height;
  final VoidCallback? onAdLoaded;
  final void Function(String error)? onAdFailed;
  final VoidCallback? onAdClicked;

  const ToponNativeAdWidget({
    super.key,
    required this.placementId,
    this.height,
    this.onAdLoaded,
    this.onAdFailed,
    this.onAdClicked,
  });

  @override
  State<ToponNativeAdWidget> createState() => _ToponNativeAdWidgetState();
}

class _ToponNativeAdWidgetState extends State<ToponNativeAdWidget> {
  MethodChannel? _channel;
  double? _measuredHeight;

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('topon_native_ad_view_$id');
    _channel?.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAdRenderSuccess':
          widget.onAdLoaded?.call();
          break;
        case 'onAdHeightMeasured':
          if (call.arguments is num) {
            final double h = (call.arguments as num).toDouble();
            if (h > 50 && mounted && widget.height == null) {
              setState(() {
                _measuredHeight = h;
              });
            }
          }
          break;
        case 'onAdLoadFailed':
        case 'onAdRenderError':
          widget.onAdFailed?.call(call.arguments?.toString() ?? 'Error');
          break;
        case 'onAdClicked':
          widget.onAdClicked?.call();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }

    final double effectiveHeight = widget.height ?? _measuredHeight ?? 245.0;

    return SizedBox(
      width: double.infinity,
      height: effectiveHeight,
      child: AndroidView(
        viewType: 'topon_native_ad_view',
        creationParams: <String, dynamic>{
          'placementId': widget.placementId,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );
  }
}
