import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_browser/flutter_web_browser.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/b_splash_stage/splash_service.dart';
import '../app/e_dashboard_stage/sections/a_home/offerwall/model/offerwall_data_model.dart';
import '../app/e_dashboard_stage/sections/a_home/offerwall/provider/offerwall_manager.dart';
import '../utils/routes/routes_import.gr.dart';
import '../widgets/common/custom_toast.dart';
import '../widgets/common/custom_status_popup.dart';
import '../widgets/screens/account_blocked_screen.dart';
import '../widgets/screens/account_deleted_screen.dart';
import '../widgets/screens/error_screen.dart';
import '../widgets/screens/no_internet_screen.dart';
import '../widgets/screens/under_maintenance_screen.dart';
import '../widgets/screens/unsecure_device_screen.dart';
import '../widgets/screens/update_available_screen.dart';
import '../widgets/screens/vpn_active_screen.dart';
import '../app/e_dashboard_stage/sections/a_home/battle_arena/battle_leaderboard_screen.dart';
import '../app/e_dashboard_stage/sections/a_home/battle_arena/battle_leaderboard_history_screen.dart';
import '../app/e_dashboard_stage/sections/a_home/battle_arena/my_matches_screen.dart';
import '../app/e_dashboard_stage/sections/c_leaderboard/_leaderboard_body.dart';

class LaunchUrl {
  static Future<void> inWeb({
    required String url,
    required BuildContext context,
    String? userId,
    String? email,
    String? country,
  }) async {
    final cleanUrl = url.trim();

    // Check if this is the support config or an email address / mailto URL
    if ((SplashService.urlConfig.supportMail.isNotEmpty &&
            cleanUrl == SplashService.urlConfig.supportMail.trim()) ||
        cleanUrl.startsWith('mailto:') ||
        (cleanUrl.contains('@') &&
            !cleanUrl.startsWith('http://') &&
            !cleanUrl.startsWith('https://') &&
            !cleanUrl.startsWith('app://'))) {
      await openSupportContact(context: context);
      return;
    }

    if (cleanUrl.isEmpty) {
      CustomToast.showToast(context, msg: 'link-error');
      return;
    }

    if (url.startsWith('app://')) {
      final routeName = url.replaceFirst('app://', '').trim();
      final router = AutoRouter.of(context);

      String userUid = userId ?? '';
      String userEmail = email ?? '';
      String userCountry = country ?? '';

      if (userUid.isEmpty || userEmail.isEmpty || userCountry.isEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          if (userUid.isEmpty) userUid = currentUser.uid;
          if (userEmail.isEmpty) userEmail = currentUser.email ?? '';
          
          try {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userUid).get().timeout(const Duration(seconds: 4));
            if (userDoc.exists) {
              final data = userDoc.data();
              if (data != null) {
                if (userEmail.isEmpty) userEmail = data['email'] ?? '';
                if (userCountry.isEmpty) userCountry = data['country'] ?? '';
              }
            }
          } catch (_) {}
        }
      }

      if (!context.mounted) return;

      final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;

      switch (routeName) {
        case 'splash':
          router.push(const SplashScreenRoute());
          break;
        case 'onboarding':
          router.push(const OnboardingScreenRoute());
          break;
        case 'authentication':
          router.push(const AuthenticationScreenRoute());
          break;
        case 'account_details':
          router.push(AccountDetailsScreenRoute(
            userId: userUid,
            userEmail: userEmail,
            userName: '',
            userPhotoUrl: '',
            fetchedReferralCode: '',
          ));
          break;
        case 'dashboard':
          router.push(DashboardScreenRoute(userId: userUid));
          break;
        case 'notifications':
          router.push(const NotificationScreenRoute());
          break;
        case 'wallet':
        case 'redeem':
          router.push(RedeemScreenRoute(
            userId: userUid,
            country: userCountry,
            isGuest: isGuest,
          ));
          break;
        case 'withdrawal_history':
        case 'redeem_history':
          router.push(RedeemHistoryScreenRoute(userId: userUid));
          break;
        case 'change_language':
          router.push(const ChangeLanguageScreenRoute());
          break;
        case 'edit_account_details':
          router.push(EditAccountDetailsScreenRoute(userId: userUid));
          break;
        case 'task_history':
          router.push(TaskHistoryScreenRoute(userId: userUid));
          break;
        case 'promo_code':
          if (!SplashService.isScreenEnabled('promoCode')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Promo Code Coming Soon!',
              message: 'Promo Code feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(const PromoCodeScreenRoute());
          break;
        case 'offerwall':
          if (!SplashService.isScreenEnabled('offerwall')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Offerwall Coming Soon!',
              message: 'Offerwall feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(OfferwallScreenRoute(
            userId: userUid,
            offerwallList: OfferwallManager.getOffersByCategory(
              category: OfferwallCategory.task,
            ).toList(),
            title: 'task-partner',
            email: userEmail,
          ));
          break;
        case 'watch_earn':
          if (!SplashService.isScreenEnabled('watchAndEarn')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Watch & Earn Coming Soon!',
              message: 'Watch & Earn feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(WatchVideoScreenRoute(
            userId: userUid,
            email: userEmail,
            country: userCountry,
          ));
          break;
        case 'read_earn':
        case 'read_tsk':
          if (!SplashService.isScreenEnabled('readAndEarn') && !SplashService.isScreenEnabled('readTask')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Read & Earn Coming Soon!',
              message: 'Read & Earn feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(ReadTskScreenRoute(userId: userUid));
          break;
        case 'play_games':
          if (!SplashService.isScreenEnabled('playGames')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Play Games Coming Soon!',
              message: 'Play Games feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(PlayGamesScreenRoute(userId: userUid));
          break;
        case 'giveaway':
          if (!SplashService.isScreenEnabled('giveaway')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Giveaway Coming Soon!',
              message: 'Giveaway feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(GiveawayScreenRoute(userId: userUid));
          break;
        case 'super_offer':
          if (!SplashService.isScreenEnabled('superOffer')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Super Offer Coming Soon!',
              message: 'Super Offer feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(SuperOfferScreenRoute(userId: userUid));
          break;
        case 'level_program':
          router.push(LevelProgramScreenRoute(
            title: 'Level Program',
            level: 1,
          ));
          break;
        case 'daily_tasks':
          if (!SplashService.isScreenEnabled('dailyTasks') && !SplashService.isScreenEnabled('dailyTask')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Daily Tasks Coming Soon!',
              message: 'Daily Tasks feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(DailyTaskScreenRoute(
            userId: userUid,
            email: userEmail,
            country: userCountry,
          ));
          break;
        case 'daily_challenge':
        case 'dailyChallenge':
        case 'challenge':
          if (!SplashService.isScreenEnabled('dailyChallenge')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Daily Challenge Coming Soon!',
              message: 'Daily Challenge feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(const DailyChallengeScreenRoute());
          break;
        case 'battle_arena':
        case 'battle_arena_splash':
        case 'battle':
          if (!SplashService.isScreenEnabled('battleArena')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Battle Arena Coming Soon!',
              message: 'Battle Arena feature is currently under active development and will be available very soon.',
            );
            return;
          }
          router.push(BattleArenaSplashScreenRoute(
            userId: userUid,
            email: userEmail,
          ));
          break;
        case 'battle_leaderboard':
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BattleLeaderboardScreen(userId: userUid),
          ));
          break;
        case 'battle_leaderboard_history':
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BattleLeaderboardHistoryScreen(userId: userUid),
          ));
          break;
        case 'my_matches':
        case 'battle_my_matches':
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MyMatchesScreen(userId: userUid),
          ));
          break;
        case 'leaderboard':
        case 'rank':
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const Scaffold(
              backgroundColor: Color(0xFF0C0F1D),
              body: LeaderboardBody(),
            ),
          ));
          break;
        case 'diamond_catch':
        case 'diamondcatch':
          router.push(DiamondCatchScreenRoute(
            userId: userUid,
            gameGems: 0,
            installGems: 0,
            dailyGemsForInstall: 0,
            gemsRequired: 0,
          ));
          break;
        case 'services':
          router.push(ServicesScreenRoute(
            userId: userUid,
            email: userEmail,
          ));
          break;
        case 'contact_support':
          router.push(ContactSupportScreenRoute(
            userId: userUid,
            email: userEmail,
          ));
          break;
        case 'how_to_use':
          router.push(const HowToUseScreenRoute());
          break;
        case 'follow':
        case 'follow_screen':
          router.push(FollowScreenRoute(userId: userUid));
          break;
        case 'more_apps':
        case 'more-apps':
          router.push(MoreAppsScreenRoute(userId: userUid));
          break;
        case 'daily_task_history':
          router.push(DailyTaskHistoryScreenRoute(
            userId: userUid,
            email: userEmail,
            country: userCountry,
          ));
          break;
        case 'daily_task_details':
          router.push(DailyTaskScreenRoute(
            userId: userUid,
            email: userEmail,
            country: userCountry,
          ));
          break;
        case 'giveaway_details':
          router.push(GiveawayScreenRoute(userId: userUid));
          break;
        case 'withdrawal_history_details':
          router.push(RedeemHistoryScreenRoute(userId: userUid));
          break;
        case 'watch_earn_category':
        case 'watch_earn_details':
          router.push(WatchVideoScreenRoute(
            userId: userUid,
            email: userEmail,
            country: userCountry,
          ));
          break;
        case 'read_earn_verification':
          router.push(ReadTskScreenRoute(userId: userUid));
          break;
        case 'battle_arena_game':
        case 'battle_arena_main':
          router.push(BattleArenaScreenRoute(
            userId: userUid,
            email: userEmail,
          ));
          break;
        // Status & System Screens
        case 'something_went_wrong':
        case 'something-went-wrong':
        case 'error':
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ErrorScreen()));
          break;
        case 'vpn':
        case 'vpn_active':
        case 'vpn-active':
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VpnActiveScreen()));
          break;
        case 'update':
        case 'update_available':
        case 'update-available':
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UpdateAvailableScreen()));
          break;
        case 'maintenance':
        case 'under_maintenance':
        case 'under-maintenance':
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnderMaintenanceScreen()));
          break;
        case 'unsecure_device':
        case 'unsecure-device':
        case 'unsequre_device':
        case 'unsequre-device':
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnsecureDeviceScreen()));
          break;
        case 'account_blocked':
        case 'account-blocked':
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountBlockedScreen()));
          break;
        case 'no_internet':
        case 'no-internet':
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoInternetScreen(onRetry: () {
            Navigator.of(context).maybePop();
          })));
          break;
        case 'account_deleted':
        case 'account-deleted':
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountDeletedScreen()));
          break;
        default:
           // debugPrint('Unknown route name: $routeName');
      }
      return;
    }

    try {
      final uri = Uri.parse(url);
      final canLaunchExternally = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!canLaunchExternally && context.mounted) {
        CustomToast.showToast(context, msg: 'link-error');
      }
    } catch (e) {
      if (context.mounted) {
        CustomToast.showToast(context);
      }
    }
  }

  static Future<void> inApp({
    required String url,
    required BuildContext context,
  }) async {
    if (url.isEmpty) {
      CustomToast.showToast(context, msg: 'link-error');
      return;
    }

    try {
      await FlutterWebBrowser.openWebPage(
        url: Uri.parse(url).toString(),
        customTabsOptions: CustomTabsOptions(
          colorScheme: CustomTabsColorScheme.dark,
          shareState: CustomTabsShareState.on,
          instantAppsEnabled: true,
          showTitle: true,
          urlBarHidingEnabled: true,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        CustomToast.showToast(context);
      }
    }
  }

  static Future<void> openSupportMail({
    required BuildContext context,
    String? subject,
    String? body,
  }) async {
    await openSupportContact(context: context, subject: subject);
  }

  static Future<void> openSupportContact({
    required BuildContext context,
    String? subject,
  }) async {
    final rawSupport = SplashService.urlConfig.supportMail.trim();
    if (rawSupport.isEmpty) {
      CustomToast.showToast(context, msg: 'link-error');
      return;
    }

    // 1. If it's a web URL (http:// or https://)
    if (rawSupport.startsWith('http://') || rawSupport.startsWith('https://')) {
      try {
        final uri = Uri.parse(rawSupport);
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          await FlutterWebBrowser.openWebPage(
            url: rawSupport,
            customTabsOptions: const CustomTabsOptions(
              colorScheme: CustomTabsColorScheme.dark,
              shareState: CustomTabsShareState.on,
              instantAppsEnabled: true,
              showTitle: true,
              urlBarHidingEnabled: true,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          CustomToast.showToast(context, msg: 'link-error');
        }
      }
      return;
    }

    // 2. If it's an email address or mailto
    String email = rawSupport;
    if (email.toLowerCase().startsWith('mailto:')) {
      email = email.substring(7).trim();
    }
    final qIdx = email.indexOf('?');
    if (qIdx != -1) {
      email = email.substring(0, qIdx).trim();
    }

    if (email.contains('@')) {
      final Map<String, String> queryParams = {};
      if (subject != null && subject.isNotEmpty) {
        queryParams['subject'] = subject;
      }

      final Uri mailUri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      try {
        final launched = await launchUrl(
          mailUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          final simpleUri = Uri(scheme: 'mailto', path: email);
          final simpleLaunched = await launchUrl(
            simpleUri,
            mode: LaunchMode.externalApplication,
          );
          if (!simpleLaunched && context.mounted) {
            await Clipboard.setData(ClipboardData(text: email));
            if (context.mounted) {
              CustomToast.showToast(
                context,
                msg: 'Support email: $email (Copied)',
              );
            }
          }
        }
      } catch (_) {
        if (context.mounted) {
          await Clipboard.setData(ClipboardData(text: email));
          if (context.mounted) {
            CustomToast.showToast(
              context,
              msg: 'Support email: $email (Copied)',
            );
          }
        }
      }
      return;
    }

    // 3. Any other scheme (tg://, whatsapp://, etc.)
    try {
      final uri = Uri.parse(rawSupport);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        CustomToast.showToast(context, msg: 'link-error');
      }
    } catch (_) {
      if (context.mounted) {
        CustomToast.showToast(context, msg: 'link-error');
      }
    }
  }
}
