import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../app/e_dashboard_stage/sections/a_home/notifications/notification_model.dart';
import '../utils/constant/constant.dart';
import 'local_storage.dart';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'crazyreward',
  'Crazyreward',
  description: 'Crazyreward Notifications',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

Future<String?> _downloadAndSaveImage(String? url, String filename) async {
  if (url == null || url.trim().isEmpty) return null;
  try {
    final cleanUrl = url.trim();
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null || !uri.hasScheme) return null;
    final response = await http.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
      'Accept': 'image/*,*/*',
    }).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    }
  } catch (_) {}
  return null;
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await LocalStorage.init();
    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    final type = (message.data['type'] ?? '').toString();
    if (NotificationModel.isAllowedType(type, title: title, body: body)) {
      final notif = NotificationModel(
        title: title ?? 'Notification',
        body: body ?? '',
        type: NotificationModel.resolveType(type: type, title: title, body: body),
        data: message.data,
        time: DateTime.now(),
      );
      LocalStorage.saveNotification(notif);
    }
  } catch (_) {}
}

class NotificationService {
  static String playerId = '';
  static String? _initializedAppId;
  static bool _fcmInitialized = false;

  //! ================= INIT =================
  static Future<void> init({String? userId}) async {
    try {
      await LocalStorage.init();

      // 1. Initialize Firebase Messaging (FCM)
      await _initFirebaseMessaging(userId: userId);

      // 2. Initialize OneSignal
      final cachedAppId = LocalStorage.getOneSignalAppId();
      if (cachedAppId != null && cachedAppId.trim().isNotEmpty) {
        AppConst.oneSignalAppId = cachedAppId.trim();
      } else if (AppConst.oneSignalAppId.trim().isEmpty && AppConst.defaultOneSignalAppId.trim().isNotEmpty) {
        AppConst.oneSignalAppId = AppConst.defaultOneSignalAppId.trim();
      }

      // If no App ID available yet, do not call OneSignal with empty string!
      // It will be initialized as soon as SplashService receives it from Admin.
      if (AppConst.oneSignalAppId.trim().isEmpty) {
        return;
      }

      await _initOneSignal(userId: userId);
    } catch (e) {
      // debugPrint('❌ Init Error: $e');
    }
  }

  //! ================= FIREBASE CLOUD MESSAGING =================
  static Future<void> _initFirebaseMessaging({String? userId}) async {
    try {
      if (_fcmInitialized) return;
      _fcmInitialized = true;

      // 1. Setup local notifications for foreground popups
      try {
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@drawable/logo');
        const InitializationSettings initSettings =
            InitializationSettings(android: androidSettings);
        await _localNotifications.initialize(settings: initSettings);

        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_defaultChannel);
      } catch (_) {}

      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request notification permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Subscribe to general topic 'all'
      await messaging.subscribeToTopic('all');

      // If userId provided, subscribe to personal user topic
      if (userId != null && userId.trim().isNotEmpty) {
        final safeTopic = userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
        await messaging.subscribeToTopic('user_$safeTopic');
      }

      //! Foreground FCM listener (handles both OneSignal and Firebase pushes in foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final title = message.notification?.title ??
            message.data['title']?.toString() ??
            message.data['heading']?.toString() ??
            'Crazyreward';

        final body = message.notification?.body ??
            message.data['body']?.toString() ??
            message.data['alert']?.toString() ??
            message.data['message']?.toString() ??
            message.data['msg']?.toString() ??
            '';

        final imageUrl = message.notification?.android?.imageUrl ??
            message.data['image'] ??
            message.data['imageUrl'] ??
            message.data['big_picture'];

        final largeIconUrl = message.data['large_icon'] ??
            message.data['largeIcon'] ??
            message.data['icon'];

        await _displayForegroundNotification(
          id: message.hashCode,
          title: title,
          body: body,
          imageUrl: imageUrl?.toString(),
          largeIconUrl: largeIconUrl?.toString(),
          data: message.data,
        );
      });

      //! Clicked notification listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // App opened from background/killed state by tapping notification
      });
    } catch (e) {
      // debugPrint('❌ Firebase Messaging Init Error: $e');
    }
  }

  //! ================= UPDATE APP ID DYNAMICALLY FROM ADMIN =================
  static Future<void> updateAppId(String newAppId, {String? userId}) async {
    final cleanId = newAppId.trim();
    if (cleanId.isEmpty) return;

    // Save to local storage so next cold start has it immediately
    LocalStorage.saveOneSignalAppId(cleanId);
    AppConst.oneSignalAppId = cleanId;

    if (cleanId == _initializedAppId) {
      // Already initialized with this ID, just ensure user is bound
      if (userId != null && userId.isNotEmpty) {
        await setUserId(userId);
      }
      return;
    }

    await _initOneSignal(userId: userId);
  }

  //! ================= ONESIGNAL =================
  static Future<void> _initOneSignal({String? userId}) async {
    try {
      final appId = AppConst.oneSignalAppId.trim();
      if (appId.isEmpty) return;

      OneSignal.Debug.setLogLevel(OSLogLevel.none);

      //! Initialize
      OneSignal.initialize(appId);
      _initializedAppId = appId;

      //! Permission & Opt-in
      await OneSignal.Notifications.requestPermission(true);
      await OneSignal.User.pushSubscription.optIn();

      //! Subscription Observer
      OneSignal.User.pushSubscription.addObserver((state) async {
        final subId = state.current.id;
        if (subId != null && subId.isNotEmpty) {
          playerId = subId;
        }

        //! Login & tag after subscription is ready
        if (userId != null && userId.isNotEmpty) {
          await setUserId(userId);
        }
      });

      // Also check if subscription already active
      final currentSubId = OneSignal.User.pushSubscription.id;
      if (currentSubId != null && currentSubId.isNotEmpty) {
        playerId = currentSubId;
        if (userId != null && userId.isNotEmpty) {
          await setUserId(userId);
        }
      }

      //! ================= FOREGROUND =================
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        event.preventDefault();

        final notification = event.notification;
        final rawData = notification.additionalData;
        final rawPayload = notification.rawPayload;

        final imageUrl = rawData?['image']?.toString() ??
            rawData?['imageUrl']?.toString() ??
            rawData?['big_picture']?.toString() ??
            notification.bigPicture ??
            rawPayload?['b_pic']?.toString() ??
            rawPayload?['big_picture']?.toString() ??
            rawPayload?['image']?.toString();

        final largeIconUrl = rawData?['large_icon']?.toString() ??
            rawData?['icon']?.toString() ??
            notification.largeIcon ??
            rawPayload?['licon']?.toString();

        _displayForegroundNotification(
          id: notification.notificationId.hashCode,
          title: notification.title,
          body: notification.body,
          imageUrl: imageUrl,
          largeIconUrl: largeIconUrl,
          data: rawData,
        );
      });

      //! ================= CLICK =================
      OneSignal.Notifications.addClickListener((event) {
      });
    } catch (e) {
      // debugPrint('❌ OneSignal Error: $e');
    }
  }

  static final Set<String> _recentNotificationKeys = <String>{};

  //! ================= UNIFIED FOREGROUND DISPLAY =================
  static Future<void> _displayForegroundNotification({
    required int id,
    String? title,
    String? body,
    String? imageUrl,
    String? largeIconUrl,
    Map<String, dynamic>? data,
  }) async {
    final cleanTitle = (title ?? '').trim();
    final cleanBody = (body ?? '').trim();

    if (cleanTitle.isEmpty && cleanBody.isEmpty) return;

    // Deduplicate notifications arriving within 4 seconds (e.g. from both FCM and OneSignal)
    final dedupeKey = '${cleanTitle}_$cleanBody';
    if (_recentNotificationKeys.contains(dedupeKey)) return;
    _recentNotificationKeys.add(dedupeKey);
    Future.delayed(const Duration(seconds: 4), () {
      _recentNotificationKeys.remove(dedupeKey);
    });

    _saveNotification(
      title: cleanTitle.isNotEmpty ? cleanTitle : 'Crazyreward',
      body: cleanBody,
      data: data,
    );

    String? bigPicturePath;
    String? largeIconPath;

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      bigPicturePath = await _downloadAndSaveImage(
        imageUrl.trim(),
        'big_${id.abs()}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    }
    if (largeIconUrl != null && largeIconUrl.trim().isNotEmpty) {
      largeIconPath = await _downloadAndSaveImage(
        largeIconUrl.trim(),
        'icon_${id.abs()}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    }

    final StyleInformation styleInformation = bigPicturePath != null
        ? BigPictureStyleInformation(
            FilePathAndroidBitmap(bigPicturePath),
            largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
            hideExpandedLargeIcon: true,
            contentTitle: cleanTitle.isNotEmpty ? cleanTitle : null,
            summaryText: cleanBody.isNotEmpty ? cleanBody : null,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          )
        : BigTextStyleInformation(
            cleanBody,
            contentTitle: cleanTitle.isNotEmpty ? cleanTitle : null,
            htmlFormatContentTitle: true,
            htmlFormatBigText: true,
          );

    try {
      await _localNotifications.show(
        id: id,
        title: cleanTitle.isNotEmpty ? cleanTitle : null,
        body: cleanBody.isNotEmpty ? cleanBody : null,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _defaultChannel.id,
            _defaultChannel.name,
            channelDescription: _defaultChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@drawable/logo',
            largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
            styleInformation: styleInformation,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    } catch (_) {}
  }

  //! ================= SAVE =================
  static void _saveNotification({
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) {
    final type = (data?['type'] ?? '').toString();
    if (!NotificationModel.isAllowedType(type, title: title, body: body)) {
      return;
    }

    final notif = NotificationModel(
      title: title ?? 'Notification',
      body: body ?? '',
      type: NotificationModel.resolveType(type: type, title: title, body: body),
      data: data ?? {},
      time: DateTime.now(),
    );

    LocalStorage.saveNotification(notif);
  }

  // attach userId to both OneSignal and Firebase FCM
  static Future<void> setUserId(String userId) async {
    try {
      final cleanUid = userId.trim();
      if (cleanUid.isEmpty) return;

      // 1. OneSignal login & tags
      await OneSignal.login(cleanUid);
      await OneSignal.User.addTags({'userId': cleanUid});

      final subId = OneSignal.User.pushSubscription.id;
      if (subId != null && subId.isNotEmpty) {
        playerId = subId;
      }

      // 2. Firebase FCM user topic subscription
      try {
        final safeTopic = cleanUid.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
        await FirebaseMessaging.instance.subscribeToTopic('user_$safeTopic');
      } catch (_) {}
    } catch (e) {
      // debugPrint('❌ Set User ID Error: $e');
    }
  }
}
