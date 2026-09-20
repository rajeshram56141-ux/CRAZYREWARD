import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app/a_initial_stage/app.dart';
import 'services/ad_manager.dart';
import 'services/analytics_service.dart';
import 'services/firebase_options.dart';
import 'services/local_storage.dart';
import 'services/notification_service.dart';
import 'services/restart_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
  }
  AdManager().initSdk();
  NotificationService.init();
  AnalyticsService.trackAppOpen();
  try {
    FirebaseAppCheck.instance.activate(
      providerAndroid: AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
     // debugPrint('AppCheck init error: $e');
  }
  await Future.wait([
    EasyLocalization.ensureInitialized(),
    LocalStorage.init(),
  ]);
  runApp(
    RestartApp(
      child: ProviderScope(
        child: EasyLocalization(
          supportedLocales: const [
            Locale('en'), // English
            Locale('de'), // German
            Locale('es'), // Spanish
            Locale('fr'), // French
            Locale('hi'), // Hindi
            Locale('id'), // Indonesian
            Locale('ja'), // Japanese
            Locale('ko'), // Korean
            Locale('pl'), // Polish
            Locale('pt'), // Portguesech
            Locale('tl'), // Filipino
          ],
          path: 'assets/locale',
          fallbackLocale: const Locale('en'),
          useOnlyLangCode: true,
          child: App(),
        ),
      ),
    ),
  );
}
