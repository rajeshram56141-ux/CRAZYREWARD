import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';

import 'security_service.dart';
import '../app/e_dashboard_stage/sections/a_home/notifications/notification_model.dart';

class LocalStorage {
  static final GetStorage _storage = GetStorage();

  static const String _notifKey = 'notifications';

  //! SDK Init
  static Future<void> init() async {
    try {
      await GetStorage.init();
    } catch (e) {
       // debugPrint('Failed to init local storage: $e');
    }
  }

  //! Onboarding
  static bool isOnboardingCompleted() =>
      _storage.read('onboardingCompleted') ?? false;

  static void setOnboardingCompleted() =>
      _storage.write('onboardingCompleted', true);

  //! Rating Dialog Tracking
  static int getRatingDialogShowCount() =>
      _storage.read('ratingDialogShowCount') ?? 0;

  static void incrementRatingDialogShowCount() =>
      _storage.write('ratingDialogShowCount', getRatingDialogShowCount() + 1);

  static bool hasUserRated() =>
      _storage.read('hasUserRated') ?? false;

  static void setUserRated() =>
      _storage.write('hasUserRated', true);

  //! Unread Notification Tracking Notifier
  static final ValueNotifier<bool> hasUnreadNotificationNotifier =
      ValueNotifier<bool>(hasUnreadNotifications());

  static bool hasUnreadNotifications() {
    try {
      final list = getNotifications();
      return list.any((n) => !n.isRead);
    } catch (_) {
      return false;
    }
  }

  static void markAllNotificationsAsRead() {
    try {
      final list = getNotifications();
      if (list.isEmpty) return;
      bool hasUnread = false;
      final updated = list.map((n) {
        if (!n.isRead) hasUnread = true;
        return n.copyWith(isRead: true);
      }).toList();
      if (hasUnread) {
        setNotifications(updated);
      }
      hasUnreadNotificationNotifier.value = false;
    } catch (_) {}
  }

  //! Notification Management
  static List<NotificationModel> getNotifications() {
    try {
      final raw = _storage.read(_notifKey);
      if (raw == null) return [];

      List list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is String && raw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            list = decoded;
          }
        } catch (_) {}
      }

      final List<NotificationModel> result = [];
      for (final item in list) {
        try {
          if (item is Map) {
            final notif = NotificationModel.fromJson(item);
            if (NotificationModel.isAllowedType(notif.type, title: notif.title, body: notif.body)) {
              result.add(notif);
            }
          }
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  static void saveNotification(NotificationModel notif) {
    try {
      if (!NotificationModel.isAllowedType(notif.type, title: notif.title, body: notif.body)) {
        return; // Do not store broad broadcast promotional notifications
      }
      final list = getNotifications();
      list.insert(0, notif);
      _storage.write(_notifKey, list.map((e) => e.toJson()).toList());
      hasUnreadNotificationNotifier.value = true;
    } catch (_) {}
  }

  static void setNotifications(List<NotificationModel> list) {
    try {
      final filtered = list
          .where((n) => NotificationModel.isAllowedType(n.type, title: n.title, body: n.body))
          .toList();
      _storage.write(_notifKey, filtered.map((e) => e.toJson()).toList());
    } catch (_) {}
  }

  static void deleteNotification(NotificationModel notif) {
    try {
      final list = getNotifications();
      list.removeWhere((item) {
        if (notif.id != null && notif.id!.isNotEmpty && item.id != null && item.id!.isNotEmpty) {
          return item.id == notif.id;
        }
        return item.title == notif.title &&
            item.body == notif.body &&
            item.time.millisecondsSinceEpoch == notif.time.millisecondsSinceEpoch;
      });
      setNotifications(list);
      hasUnreadNotificationNotifier.value = hasUnreadNotifications();
    } catch (_) {}
  }

  static void clearNotifications() {
    try {
      _storage.remove(_notifKey);
      hasUnreadNotificationNotifier.value = false;
    } catch (_) {}
  }

  //! OneSignal App ID Cache
  static String? getOneSignalAppId() => _storage.read('oneSignalAppId');
  static void saveOneSignalAppId(String id) => _storage.write('oneSignalAppId', id);

  //! Encrypted Local Storage Helpers (Phase 4 AES-256)
  static void writeEncrypted(String key, String value) {
    try {
      final encrypted = SecurityService.encryptPayload(value);
      _storage.write('enc_$key', encrypted);
    } catch (e) {
       // debugPrint('🔥 Error writing encrypted storage: $e');
    }
  }

  static String readEncrypted(String key) {
    try {
      final encryptedStr = _storage.read('enc_$key');
      if (encryptedStr != null && encryptedStr is String && encryptedStr.isNotEmpty) {
        return SecurityService.decryptPayload(encryptedStr);
      }
    } catch (e) {
       // debugPrint('🔥 Error reading encrypted storage: $e');
    }
    return '';
  }

  //! Free Battle Ad Pass Tracking
  static bool hasFreeBattleAdPass() =>
      _storage.read('hasFreeBattleAdPass') ?? false;

  static void setFreeBattleAdPass(bool value) =>
      _storage.write('hasFreeBattleAdPass', value);

  //! Room Ad Skip Passes Tracking
  static int getRoomAdSkipMatches(String userId, String roomId) =>
      _storage.read('ad_skip_${userId}_$roomId') ?? 0;

  static void setRoomAdSkipMatches(String userId, String roomId, int count) =>
      _storage.write('ad_skip_${userId}_$roomId', count);

  static void consumeRoomAdSkipMatch(String userId, String roomId) {
    final current = getRoomAdSkipMatches(userId, roomId);
    if (current > 0) {
      _storage.write('ad_skip_${userId}_$roomId', current - 1);
    }
  }
}
