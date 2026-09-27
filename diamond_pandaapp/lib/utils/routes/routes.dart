part of 'routes_import.dart';

Widget _appScreenTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.2, 0.85, 0.25, 1.0),
      reverseCurve: Curves.easeInCubic,
    ),
  );
  final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ),
  );
  final slideAnimation = Tween<Offset>(
    begin: const Offset(0.05, 0.02),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.2, 0.85, 0.25, 1.0),
      reverseCurve: Curves.easeInCubic,
    ),
  );

  return FadeTransition(
    opacity: fadeAnimation,
    child: ScaleTransition(
      scale: scaleAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    ),
  );
}

Widget _appBottomSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final slideAnimation = Tween<Offset>(
    begin: const Offset(0.0, 1.0),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.2, 0.85, 0.25, 1.0),
      reverseCurve: Curves.easeInCubic,
    ),
  );
  final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ),
  );
  final scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.2, 0.85, 0.25, 1.0),
      reverseCurve: Curves.easeInCubic,
    ),
  );

  return FadeTransition(
    opacity: fadeAnimation,
    child: ScaleTransition(
      scale: scaleAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: child,
      ),
    ),
  );
}

@AutoRouterConfig(replaceInRouteName: 'Screen')
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => RouteType.custom(
        duration: const Duration(milliseconds: 380),
        reverseDuration: const Duration(milliseconds: 280),
        transitionsBuilder: _appScreenTransition,
      );

  @override
  List<AutoRoute> get routes => [
        CustomRoute(
          page: SplashScreenRoute.page,
          path: '/',
          initial: true,
          transitionsBuilder: TransitionsBuilders.slideBottom,
        ),
        CustomRoute(
          page: OnboardingScreenRoute.page,
          path: '/onboarding',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: AuthenticationScreenRoute.page,
          path: '/authentication',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: AccountDetailsScreenRoute.page,
          path: '/account-details',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: DashboardScreenRoute.page,
          path: '/dashboard',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: NotificationScreenRoute.page,
          path: '/notifications',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: RedeemScreenRoute.page,
          path: '/redeem',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: RedeemHistoryScreenRoute.page,
          path: '/redeem-history',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: RedeemHistoryDetailsScreenRoute.page,
          path: '/redeem-history-details',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: ChangeLanguageScreenRoute.page,
          path: '/change-language',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: EditAccountDetailsScreenRoute.page,
          path: '/edit-account-details',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: TaskHistoryScreenRoute.page,
          path: '/task-history',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: PromoCodeScreenRoute.page,
          path: '/promo-code',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: OfferwallScreenRoute.page,
          path: '/offerwall',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: WatchVideoScreenRoute.page,
          path: '/watch-video',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: ReadTskScreenRoute.page,
          path: '/read-tsk',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: ReadTskVerificationScreenRoute.page,
          path: '/read-tsk-verification',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: PlayGamesScreenRoute.page,
          path: '/play-games',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: FollowScreenRoute.page,
          path: '/follow',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: MoreAppsScreenRoute.page,
          path: '/more-apps',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: GiveawayScreenRoute.page,
          path: '/giveaway',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: GiveawayDetailScreenRoute.page,
          path: '/giveaway-details',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: SuperOfferScreenRoute.page,
          path: '/super-offer',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: LevelProgramScreenRoute.page,
          path: '/level-program',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: WatchVideoCategoryScreenRoute.page,
          path: '/watch-video-category',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: WatchVideoDetailsScreenRoute.page,
          path: '/watch-video-details',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: DailyTaskScreenRoute.page,
          path: '/daily-tasks',
          duration: const Duration(milliseconds: 400),
          reverseDuration: const Duration(milliseconds: 300),
          transitionsBuilder: _appBottomSlideTransition,
        ),
        CustomRoute(
          page: DailyTaskDetailsScreenRoute.page,
          path: '/daily-task-details',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: DailyTaskHistoryScreenRoute.page,
          path: '/daily-task-history',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: DiamondCatchScreenRoute.page,
          path: '/diamond-catch',
          duration: const Duration(milliseconds: 400),
          reverseDuration: const Duration(milliseconds: 300),
          transitionsBuilder: _appBottomSlideTransition,
        ),
        CustomRoute(
          page: ServicesScreenRoute.page,
          path: '/services',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: ContactSupportScreenRoute.page,
          path: '/contact-support',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: HowToUseScreenRoute.page,
          path: '/how-to-use',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: BattleArenaSplashScreenRoute.page,
          path: '/battle-arena-splash',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: BattleArenaScreenRoute.page,
          path: '/battle-arena',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
        CustomRoute(
          page: DailyChallengeScreenRoute.page,
          path: '/daily-challenge',
          duration: const Duration(milliseconds: 380),
          reverseDuration: const Duration(milliseconds: 280),
          transitionsBuilder: _appScreenTransition,
        ),
      ];
}
