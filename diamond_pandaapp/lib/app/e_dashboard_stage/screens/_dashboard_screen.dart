import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../sections/a_home/widgets/home_screen_shimmer.dart';

import '../../../../../services/cloud_functions.dart';
import '../../../../../services/restart_app.dart';
import '../../../../widgets/screens/error_screen.dart';
import '../../../widgets/screens/account_blocked_screen.dart';
import '../../../widgets/screens/account_deleted_screen.dart';
import '../../../widgets/screens/under_maintenance_screen.dart';
import '../../../widgets/screens/update_available_screen.dart';
import '../../b_splash_stage/splash_service.dart';
import '../../d_authentication_stage/authentication_service.dart';
import '../../d_authentication_stage/users_data_model.dart';
import '../provider/dashboard_provider.dart';
import 'dashboard_scaffold.dart';

@RoutePage()
class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useListenable(CloudFunctions.balanceRefreshNotifier);

    useEffect(() {
      void refreshListener() {
        if (userId.trim().isNotEmpty) {
          ref.invalidate(DashboardService.userDataProvider(userId.trim()));
        }
      }

      CloudFunctions.balanceRefreshNotifier.addListener(refreshListener);
      return () {
        CloudFunctions.balanceRefreshNotifier.removeListener(refreshListener);
      };
    }, [userId]);
    // Global app states first
    if (SplashService.updateConfig.updateAvailable) {
      return const UpdateAvailableScreen();
    }

    if (SplashService.maintenanceConfig.enabled &&
        !SplashService.maintenanceConfig.isExcluded(userId)) {
      return const UnderMaintenanceScreen();
    }

    final dummyUserData = UserDataModel(
      name: '',
      email: '',
      photoUrl: '',
      userId: userId,
      coins: 0.0,
      referralCode: '',
      firstLogin: Timestamp.now(),
      lastLogin: Timestamp.now(),
      socialFollowed: [],
      country: '',
      deviceId: '',
      streak: 0,
      streakClaimed: false,
      source: '',
      isGuest: false,
      mobileNo: '',
      blocked: false,
      referred: false,
      gems: 0,
      account_deleted: false,
      battleInstallTaskNumber: 0,
      battleInstallTaskCompletedToday: false,
      freeBattlesJoinedToday: 0,
      battleDailyLimit: 0,
    );

    final userAsync = ref.watch(DashboardService.userDataProvider(userId));

    return userAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.white,
        body: HomeScreenShimmer(),
      ),
      error: (err, stack) => const ErrorScreen(),
      data: (UserDataModel userData) {
        if (_shouldForceLogout(userData)) {
          _handleForceLogout(context);
          return DashboardScaffold(
            userData: dummyUserData,
            userId: userId,
            isLoadingOverride: true,
          );
        }

        if (userData.account_deleted == true) {
          return const AccountDeletedScreen();
        }

        if (userData.blocked) {
          return const AccountBlockedScreen();
        }

        return DashboardScaffold(userData: userData, userId: userId);
      },
    );
  }

  bool _shouldForceLogout(UserDataModel userData) {
    if (kDebugMode) return false;

    return ((SplashService.deviceId.isNotEmpty &&
            SplashService.deviceId != userData.deviceId) &&
        !userData.isGuest);
  }

  void _handleForceLogout(BuildContext context) {
    Future.microtask(() async {
      if (!context.mounted) return;
      await AuthenticationService.signOut(context);
      if (context.mounted) {
        RestartApp.rebirth(context);
      }
    });
  }
}
