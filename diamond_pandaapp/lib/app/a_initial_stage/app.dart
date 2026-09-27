import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../services/analytics_service.dart';
import '../../utils/routes/routes_import.dart';
import '../../utils/theme/theme.dart';
import '../../widgets/screens/error_screen.dart';
import '../../widgets/screens/no_internet_screen.dart';
import '../../widgets/screens/vpn_active_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppRouter _appRouter = AppRouter();

  bool isVpnActive = false;
  bool isNoInternet = false;

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => checkConnectivity());

    _subscription = Connectivity().onConnectivityChanged.listen(
      (results) => updateStatus(results),
    );
  }

  Future<void> checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    updateStatus(results);
  }

  void updateStatus(List<ConnectivityResult> results) {
    if (!mounted) return;

    setState(() {
      isNoInternet = results.contains(ConnectivityResult.none);
      isVpnActive = results.contains(ConnectivityResult.vpn);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) =>
        getErrorScreen(errorDetails);

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: false,
      enableScaleText: () => false,
      builder: (context, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.appTheme,
          themeMode: ThemeMode.dark,
          routerConfig: _appRouter.config(
            navigatorObservers: () => [AnalyticsService.observer],
          ),
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(),
          ),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.0)),
            child: Stack(
              children: [
                child!,
                if (isNoInternet)
                  const Positioned.fill(
                    child: NoInternetScreen(),
                  ),
                if (isVpnActive)
                  const Positioned.fill(
                    child: VpnActiveScreen(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
