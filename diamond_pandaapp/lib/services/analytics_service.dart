import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Route observer to automatically track screen transitions and last screen for uninstall attribution
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: _analytics,
    nameExtractor: (RouteSettings settings) {
      final name = settings.name;
      if (name != null && name.trim().isNotEmpty) {
        final cleanName = name.replaceAll('/', '').trim();
        final finalName = cleanName.isEmpty ? 'root' : cleanName;
        // Set user property so GA4 can attribute app_remove / drop-offs to the last visited screen
        _analytics.setUserProperty(name: 'last_screen', value: finalName);
        return finalName;
      }
      return 'unknown_screen';
    },
  );

  /// Track app open
  static Future<void> trackAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (_) {}
  }

  /// Explicitly log a screen view and update last_screen user property
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      await _analytics.setUserProperty(name: 'last_screen', value: screenName);
    } catch (_) {}
  }

  /// Call this once when user logs in
  static Future<void> logSignup(String userId) async {
    try {
      await _analytics.setUserId(id: userId);

      await _analytics.logSignUp(
        signUpMethod: 'Google',
        parameters: {'userId': userId},
      );
    } catch (_) {}
  }

  /// Track when a user successfully requests a payout/redemption
  static Future<void> logPayoutRequested({
    required num amount,
    required int coins,
    required String paymentMethod,
    String? status,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'payout_requested',
        parameters: {
          'amount': amount.toDouble(),
          'coins': coins,
          'payment_method': paymentMethod,
          if (status != null) 'status': status,
        },
      );
    } catch (_) {}
  }

  /// Track rewarded ad completion (matches GA4 standard ad_reward event)
  static Future<void> logAdRewardEarned({
    String adFormat = 'rewarded_video',
    String provider = 'topon',
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ad_reward',
        parameters: {
          'ad_format': adFormat,
          'provider': provider,
        },
      );
    } catch (_) {}
  }

  /// Track user sharing referral link/code via WhatsApp, Telegram, Instagram, or System Sheet
  static Future<void> logShareReferral({required String method}) async {
    try {
      await _analytics.logShare(
        contentType: 'referral_link',
        itemId: 'invite_screen',
        method: method,
      );
    } catch (_) {}
  }

  /// Track when daily challenge milestone reward is claimed
  static Future<void> logDailyChallengeClaimed({required int rewardCoins}) async {
    try {
      await _analytics.logEvent(
        name: 'daily_challenge_claimed',
        parameters: {
          'reward_coins': rewardCoins,
        },
      );
    } catch (_) {}
  }

  /// Track promo code redemption success
  static Future<void> logPromoCodeRedeemed({required String code}) async {
    try {
      await _analytics.logEvent(
        name: 'promo_code_redeemed',
        parameters: {
          'code': code,
        },
      );
    } catch (_) {}
  }

  /// Log custom event
  static Future<void> logCustomEvent(String eventName, {Map<String, Object>? parameters}) async {
    try {
      await _analytics.logEvent(name: eventName, parameters: parameters);
    } catch (_) {}
  }
}

