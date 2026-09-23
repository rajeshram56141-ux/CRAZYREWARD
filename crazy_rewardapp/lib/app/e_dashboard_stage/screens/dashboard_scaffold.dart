import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../widgets/common/custom_status_popup.dart';
import '../../b_splash_stage/splash_service.dart';
import '../../d_authentication_stage/users_data_model.dart';
import '../provider/dashboard_provider.dart';
import '../sections/a_home/home_body.dart';
import '../sections/a_home/daily_task/daily_task_screen.dart';
import '../sections/c_leaderboard/_leaderboard_body.dart';
import '../sections/b_invite/_invite_body.dart';
import '../sections/d_profile/_profile_body.dart';
import '../widgets/dashboard_navbar.dart';

const List<String> _dashboardSection = [
  'home',
  'invite',
  'daily-task',
  'profile',
  'rank',
];

class DashboardScaffold extends HookConsumerWidget {
  const DashboardScaffold({
    super.key,
    required this.userData,
    required this.userId,
    this.isLoadingOverride = false,
  });

  final UserDataModel userData;
  final String userId;
  final bool isLoadingOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = useState<int>(0);
    final referralNavIndex = useState<int>(0);
    final isLoading = useState<bool>(false);
    final isNavbarVisible = useMemoized(() => ValueNotifier<bool>(true));

    final effectiveLoading = isLoadingOverride || isLoading.value;

    useEffect(() {
      isNavbarVisible.value = true;
      return null;
    }, [currentIndex.value]);

    useEffect(() {
      if (isLoadingOverride) return null;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        DashboardService.initDashboard(
          userId: userId,
          isGuest: userData.isGuest,
        );

        // Show Welcome Popup if configured
        final welcomePopup = SplashService.welcomePopupConfig;
        if (welcomePopup.enabled) {
          final storage = GetStorage();
          final popupKey = 'welcome_popup_shown_${welcomePopup.title.hashCode}_${welcomePopup.imageUrl.hashCode}';
          final shownCount = storage.read<int>(popupKey) ?? 0;

          if (welcomePopup.cap == 0 || shownCount < welcomePopup.cap) {
            CustomStatusPopup.showWelcomePopup(
              context: context,
              welcomePopup: welcomePopup,
              userId: userId,
            );
            if (welcomePopup.cap > 0) {
              storage.write(popupKey, shownCount + 1);
            } else if (shownCount != 0) {
              storage.write(popupKey, 0);
            }
          }
        }
      });
      return null;
    }, [isLoadingOverride]);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, __) => currentIndex.value != 0
            ? currentIndex.value = 0
            : CustomStatusPopup.showAppExit(context: context),
        child: Container(
          width: double.infinity,
          color: Colors.white,
          child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.white,
            appBar: null,
          body: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction == ScrollDirection.reverse) {
                // Scrolling down into page -> hide navbar
                if (isNavbarVisible.value) {
                  isNavbarVisible.value = false;
                }
              } else if (notification.direction == ScrollDirection.forward) {
                // Scrolling up towards top -> show navbar
                if (!isNavbarVisible.value) {
                  isNavbarVisible.value = true;
                }
              }
              return false;
            },
            child: IndexedStack(
              index: currentIndex.value,
              children: [
                HomeBody(
                  userId: userId,
                  coins: userData.coins,
                  gems: userData.gems,
                  country: userData.country,
                  email: userData.email,
                  name: userData.name,
                  photoUrl: userData.photoUrl,
                  socialFollowed: userData.socialFollowed,
                  streak: userData.streak,
                  streakClaimed: userData.streakClaimed,
                  isGuest: userData.isGuest,
                  currentIndex: currentIndex,
                  isLoading: effectiveLoading,
                ),
                InviteBody(
                  referralNavIndex: referralNavIndex,
                  referred: userData.referred,
                  referralCode: userData.referralCode,
                  userId: userId,
                ),
                DailyTaskScreen(
                  userId: userId,
                  email: userData.email,
                  country: userData.country,
                ),
                ProfileBody(
                  email: userData.email,
                  coins: userData.coins,
                  gems: userData.gems,
                  name: userData.name,
                  photoUrl: userData.photoUrl,
                  userId: userId,
                  referralCode: userData.referralCode,
                  currentIndex: currentIndex,
                ),
                const LeaderboardBody(),
              ],
            ),
          ),
          bottomNavigationBar: ValueListenableBuilder<bool>(
            valueListenable: isNavbarVisible,
            builder: (context, isVisible, child) {
              return IgnorePointer(
                ignoring: !isVisible,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  offset: isVisible ? Offset.zero : const Offset(0, 1.6),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    opacity: isVisible ? 1.0 : 0.0,
                    child: child,
                  ),
                ),
              );
            },
            child: DashboardNavbar(
              currentIndex: currentIndex,
              items: _dashboardSection,
              isLoading: effectiveLoading,
            ),
          ),
        ),
      ),
    ),
  );
}
}
