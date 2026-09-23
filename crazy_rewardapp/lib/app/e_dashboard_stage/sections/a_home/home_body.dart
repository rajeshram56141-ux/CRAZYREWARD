import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../utils/helper/helper.dart';
import '../../../../utils/routes/routes_import.gr.dart';
import '../../../../widgets/common/custom_status_popup.dart';
import '../../../../widgets/common/custom_loading.dart';
import '../../../../widgets/common/internet_image.dart';
import '../../provider/dashboard_provider.dart';
import 'daily_task/daily_task_model.dart';
import 'daily_task/daily_task_provider.dart';
import 'widgets/daily_task_card.dart';
import 'widgets/daily_checkin_sheet.dart';

import '../../../b_splash_stage/splash_service.dart';
import '../../../../services/cloud_functions.dart';
import '../../../../services/launch_url.dart';
import '../../../../services/local_storage.dart';
import 'widgets/top_recommended_task_widget.dart';
import 'widgets/more_ways.dart';
import 'widgets/more_apps_section.dart';
import 'widgets/home_screen_shimmer.dart';
import 'widgets/bonus_offers_section.dart';
import '../../../../widgets/ads/topon_native_ad_card.dart';

import 'more_apps/more_apps_provider.dart';
import 'read_tsk/read_tsk_provider.dart';
import 'play_games/play_games_provider.dart';
import 'offerwall/model/offerwall_data_model.dart';
import 'offerwall/provider/offerwall_manager.dart';

class HomeBody extends HookConsumerWidget {
  const HomeBody({
    super.key,
    required this.coins,
    required this.gems,
    required this.userId,
    required this.country,
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.socialFollowed,
    required this.currentIndex,
    required this.streak,
    required this.streakClaimed,
    required this.isGuest,
    required this.isLoading,
  });

  final double coins;
  final int gems;
  final String userId;
  final String country;
  final String email;
  final String name;
  final String photoUrl;
  final List<String> socialFollowed;
  final ValueNotifier<int> currentIndex;
  final int streak;
  final bool streakClaimed;
  final bool isGuest;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useListenable(CloudFunctions.balanceRefreshNotifier);
    ref.watch(SplashService.appDataProvider);
    useEffect(() {
      return null;
    }, [userId]);

    final taskProvider = dailyTaskProvider((
      userId: userId,
      email: email,
      countryCode: country,
      offerType: DailyTaskType.dailyTask,
    ));

    final taskAsync = ref.watch(taskProvider);
    final effectiveLoading = isLoading;

    if (effectiveLoading) {
      return const HomeScreenShimmer();
    }

    final scrollController = useScrollController();

    return Stack(
      children: [
        // 1. Soft Premium Neutral Background
        Positioned.fill(
          child: Container(
            color: const Color(0xFFF8FAFC),
          ),
        ),

        // 3. Foreground Content List
        Positioned.fill(
          child: RefreshIndicator(
            edgeOffset: 100.h,
            displacement: 35.h,
            color: const Color(0xFFC084FC),
            backgroundColor: const Color(0xFF1E1B4B),
            onRefresh: () async {
              ref.invalidate(DashboardService.userDataProvider(userId));
              ref.invalidate(taskProvider);
              ref.invalidate(SplashService.appDataProvider);
              ref.invalidate(moreAppsStreamProvider);
              ref.invalidate(playGamesProvider(userId));
              ref.invalidate(readTskProvider((userId: userId, appName: SplashService.appName.lows())));
              ref.invalidate(dailyTaskProvider((
                userId: userId,
                email: email,
                countryCode: country,
                offerType: DailyTaskType.watchEarn,
              )));
              try {
                await ref.read(DashboardService.userDataProvider(userId).future);
              } catch (_) {}
              try {
                await ref.read(taskProvider.future);
              } catch (_) {}
              try {
                await ref.read(SplashService.appDataProvider.future);
              } catch (_) {}
            },
            child: Stack(
              children: [
                // 1. SCROLLABLE FEED (BalanceCard & all task cards scroll up and DISAPPEAR under fixed User Profile Header)
                Positioned.fill(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    child: Column(
                      children: [
                        // 1. Unified Silver Curved Header & Balance Card (Rectangle 285.png)
                        _HomeTopHeaderCard(
                          userId: userId,
                          name: name,
                          photoUrl: photoUrl,
                          coins: coins,
                          gems: gems,
                          country: country,
                          isGuest: isGuest,
                          streak: streak,
                          streakClaimed: streakClaimed,
                          currentIndex: currentIndex,
                        ),

                        // Daily Task Section (Above Banner Slider)
                        if (!SplashService.isScreenHidden('dailyTasks'))
                          taskAsync.when(
                            data: (offers) {
                              if (offers.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Transform.translate(
                                offset: Offset(0, -10.h),
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 2.h),
                                  child: HomeDailyTaskSection(
                                    offers: offers,
                                    userId: userId,
                                    email: email,
                                    country: country,
                                  ),
                                ),
                              );
                            },
                            error: (_, __) => const SizedBox.shrink(),
                            loading: () => const SizedBox.shrink(),
                          ),

                        // Home Banner Slider
                        const _HomeBannerSlider(),

                        SizedBox(height: 14.h),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          child: Column(
                            children: [
                              TopRecommendedTaskWidget(
                                userId: userId,
                                email: email,
                                country: country,
                                streak: streak,
                                streakClaimed: streakClaimed,
                                coins: coins,
                                dailyChallengeWidget: !SplashService.isScreenHidden('dailyChallenge')
                                    ? _PlayGamesHeroBanner(
                                        userId: userId,
                                        email: email,
                                        country: country,
                                        currentIndex: currentIndex,
                                      )
                                    : null,
                              ),
                              ToponNativeAdCard(
                                margin: EdgeInsets.only(top: 10.h, bottom: 20.h),
                              ),
                              SizedBox(height: 10.h),
                              MoreWaysSection(
                                userId: userId,
                                email: email,
                                country: country,
                                currentIndex: currentIndex,
                              ),
                              SizedBox(height: 24.h),
                              BonusOffersSection(
                                userId: userId,
                              ),
                              SizedBox(height: 24.h),
                              MoreAppsSection(userId: userId),
                              SizedBox(height: 100.h),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}


class _PopScaleButton extends StatefulWidget {
  const _PopScaleButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}






class _HomeTopHeaderCard extends HookConsumerWidget {
  const _HomeTopHeaderCard({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.coins,
    required this.gems,
    required this.country,
    required this.isGuest,
    required this.streak,
    required this.streakClaimed,
    required this.currentIndex,
  });

  final String userId;
  final String name;
  final String photoUrl;
  final double coins;
  final int gems;
  final String country;
  final bool isGuest;
  final int streak;
  final bool streakClaimed;
  final ValueNotifier<int> currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(SplashService.appDataProvider);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/icons/rectangle_285.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 26.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---------------- 1. TOP ROW: PROFILE & NAME (LEFT) + NOTIFICATION (RIGHT) ----------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Pill & Greeting
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => currentIndex.value = 3, // Open Profile / Menu
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Dynamic User Profile Capsule Pill (Real User Avatar + Hamburger Menu)
                        Container(
                          height: 38.h,
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B2E),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.20),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28.w,
                                height: 28.w,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: ClipOval(
                                  child: (photoUrl.isNotEmpty && photoUrl != 'null')
                                      ? AvatarInternetImage(
                                          url: photoUrl,
                                          size: 28.w,
                                          borderWidth: 0,
                                          borderColor: Colors.transparent,
                                        )
                                      : Icon(
                                          Icons.person_rounded,
                                          color: const Color(0xFF1E1B2E),
                                          size: 19.sp,
                                        ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Padding(
                                padding: EdgeInsets.only(right: 6.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 14.w,
                                      height: 2.2.h,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2.r),
                                      ),
                                    ),
                                    SizedBox(height: 3.h),
                                    Container(
                                      width: 14.w,
                                      height: 2.2.h,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2.r),
                                      ),
                                    ),
                                    SizedBox(height: 3.h),
                                    Container(
                                      width: 14.w,
                                      height: 2.2.h,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2.r),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 10.w),

                        // Greeting & Name
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Hi,',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1E1B2E),
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 140.w),
                              child: Text(
                                name.isNotEmpty ? name : 'User',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF1E1B2E),
                                  fontSize: 15.5.sp,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right Actions: Gems & Bell Notification
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (gems > 0) ...[
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => AutoRouter.of(context).push(
                            SuperOfferScreenRoute(userId: userId),
                          ),
                          child: Container(
                            height: 36.h,
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            margin: EdgeInsets.only(right: 8.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B2E),
                              borderRadius: BorderRadius.circular(18.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons/gems.png',
                                  width: 18.w,
                                  height: 18.w,
                                  fit: BoxFit.contain,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '$gems',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF38BDF8),
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Right Polygon Button with Bell Icon
                      _PopScaleButton(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await AutoRouter.of(context).push(const NotificationScreenRoute());
                      LocalStorage.hasUnreadNotificationNotifier.value = LocalStorage.hasUnreadNotifications();
                    },
                    child: SizedBox(
                      width: 44.w,
                      height: 44.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/icons/polygon_2.png',
                            width: 44.w,
                            height: 44.w,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/Icons1/Polygon 2.png',
                              width: 44.w,
                              height: 44.w,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          Image.asset(
                            'assets/icons/iconoir_bell_notification_solid.png',
                            width: 22.w,
                            height: 22.w,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/Icons1/iconoir_bell-notification-solid.png',
                              width: 22.w,
                              height: 22.w,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.notifications_rounded,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                            ),
                          ),
                          ValueListenableBuilder<bool>(
                            valueListenable: LocalStorage.hasUnreadNotificationNotifier,
                            builder: (context, hasUnread, _) {
                              if (!hasUnread) return const SizedBox.shrink();
                              return Positioned(
                                top: 6.h,
                                right: 8.w,
                                child: Container(
                                  width: 8.w,
                                  height: 8.w,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

              SizedBox(height: 18.h),

              // ---------------- 2. MIDDLE: AVAILABLE BALANCE WITH DIAMOND DIVIDERS ----------------
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => AutoRouter.of(context).push(
                  RedeemScreenRoute(userId: userId, country: country, isGuest: isGuest),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      child: Row(
                        children: [
                          // Left Divider Line with Diamond
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1.2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.0),
                                          Colors.white.withValues(alpha: 0.85),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Transform.rotate(
                                  angle: 0.785398, // 45 deg
                                  child: Container(
                                    width: 5.5.w,
                                    height: 5.5.w,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            child: Text(
                              'Available Balance',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),

                          // Right Divider Line with Diamond
                          Expanded(
                            child: Row(
                              children: [
                                Transform.rotate(
                                  angle: 0.785398, // 45 deg
                                  child: Container(
                                    width: 5.5.w,
                                    height: 5.5.w,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Container(
                                    height: 1.2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.85),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // ---------------- 3. BOTTOM: 3D COIN + LARGE BOLD COIN BALANCE ----------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 3D Dollar Coin matching screenshot
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFDF00),
                                Color(0xFFFFA500),
                                Color(0xFFFF8C00),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFF7C2),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9800).withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '\$',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFFFF9E6),
                                fontSize: 25.sp,
                                fontWeight: FontWeight.w900,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xFFB45309),
                                    offset: Offset(1, 1.5),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 10.w),

                        // Large 3D White/Chrome Balance Text
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Color(0xFFFFFFFF),
                              Color(0xFFB8C2CC),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ).createShader(bounds),
                          child: Text(
                            coins.toInt().addComma(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  offset: const Offset(0, 4),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Admin Coin Conversion Rate
                    if (SplashService.showCoinConversionRate && SplashService.coinConversionRate > 0) ...[
                      SizedBox(height: 5.h),
                      Text(
                        '≈ ₹${(coins / SplashService.coinConversionRate).toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF10B981),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              offset: const Offset(0, 1.5),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 18.h),
            ],
          ),
        ),
      ),
    );
  }
}



// ===========================================================================
// DAILY CHALLENGE HERO BANNER (Golden Yellow Pastel Card)
// ===========================================================================
class _PlayGamesHeroBanner extends HookConsumerWidget {
  const _PlayGamesHeroBanner({
    required this.userId,
    required this.email,
    required this.country,
    required this.currentIndex,
  });

  final String userId;
  final String email;
  final String country;
  final ValueNotifier<int> currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          HapticFeedback.lightImpact();
          if (!SplashService.isScreenEnabled('dailyChallenge')) {
            CustomStatusPopup.showComingSoon(
              context: context,
              title: 'Daily Challenge Coming Soon!',
              message: 'Daily Challenge feature is currently under active development and will be available very soon.',
            );
            return;
          }
          await AutoRouter.of(context).push(const DailyChallengeScreenRoute());
          ref.invalidate(DashboardService.userDataProvider(userId));
        },
        child: Container(
          width: double.infinity,
          height: 96.h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7CC),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: const Color(0xFFFEF08A).withValues(alpha: 0.80),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEAB308).withValues(alpha: 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 1. Soft white circular backdrop on left
              Positioned(
                left: -15.w,
                top: -12.h,
                bottom: -12.h,
                width: 120.w,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),

              // 2. Foreground Content: Left Icon + Right Text
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                child: Row(
                  children: [
                    // 3D Challenge Trophy Podium Icon
                    SizedBox(
                      width: 90.w,
                      height: 80.h,
                      child: Center(
                        child: Image.asset(
                          'assets/Icons1/challenge-3d-icon-png-download-10612205 1.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/icons/dailychallange.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Title & Subtitle Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Daily Challenge',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.black,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            "Complete today's set of tasks to earn bonus coins",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF1F2937),
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBannerSlider extends HookConsumerWidget {
  const _HomeBannerSlider();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(SplashService.homeBannersProvider);

    return bannersAsync.when(
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        final pageController = usePageController(
          initialPage: (5000 ~/ banners.length) * banners.length,
          viewportFraction: 0.92,
        );
        final currentPage = useState<int>(0);

        useEffect(() {
          final timer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
            if (pageController.hasClients && pageController.page != null) {
              final nextPage = pageController.page!.round() + 1;
              pageController.animateToPage(
                nextPage,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
              );
            }
          });
          return timer.cancel;
        }, [banners.length]);

        return Column(
          children: [
            SizedBox(height: 16.h),
            SizedBox(
              height: 140.h,
              child: PageView.builder(
                controller: pageController,
                onPageChanged: (index) {
                  currentPage.value = index % banners.length;
                },
                itemCount: 10000,
                itemBuilder: (context, index) {
                  final banner = banners[index % banners.length];
                  return GestureDetector(
                    onTap: () {
                      LaunchUrl.inWeb(url: banner.clickUrl, context: context);
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.circular(26.r),
                        border: Border.all(
                          color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26.r),
                        child: Image.network(
                          banner.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFF1E1B4B),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.grey,
                                size: 40,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFF1E1B4B),
                              alignment: Alignment.center,
                              child: const Center(
                                child: GlowLightingSpinner(size: 22),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (banners.length > 1) ...[
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  banners.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6.h,
                    width: index == currentPage.value ? 20.w : 6.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: index == currentPage.value
                          ? const Color(0xFFC084FC)
                          : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 16.h),
          ],
        );
      },
      error: (error, stack) {
         // debugPrint('Error loading home banners stream: $error');
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
    );
  }
}







class _GlossyActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final IconData icon;

  const _GlossyActionButton({
    required this.label,
    required this.onTap,
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
    required this.icon,
  });

  @override
  State<_GlossyActionButton> createState() => _GlossyActionButtonState();
}

class _GlossyActionButtonState extends State<_GlossyActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: SizedBox(
          width: double.infinity,
          height: 36.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Skewed Glossy Glowing Button Base
              Positioned.fill(
                child: Transform(
                  transform: Matrix4.skewX(-0.16),
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: widget.borderColor,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.shadowColor.withValues(
                            alpha: _isPressed ? 0.25 : 0.55,
                          ),
                          blurRadius: _isPressed ? 6 : 12,
                          spreadRadius: _isPressed ? 0 : 1,
                          offset: Offset(0, _isPressed ? 2 : 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const CustomPaint(
                      painter: _GlossyButtonOverlayPainter(),
                    ),
                  ),
                ),
              ),

              // 2. Center Content (Icon + Text)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 13.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    widget.label,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlossyButtonOverlayPainter extends CustomPainter {
  const _GlossyButtonOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Top sweeping curved glass reflection
    final wavePath = Path();
    wavePath.moveTo(0, 0);
    wavePath.lineTo(w, 0);
    wavePath.lineTo(w, h * 0.36);
    wavePath.cubicTo(
      w * 0.70, h * 0.46,
      w * 0.35, h * 0.68,
      0, h * 0.42,
    );
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.68));

    canvas.drawPath(wavePath, wavePaint);

    // 2. Top-left oval bright specular reflection dot / pill
    final dotRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(20.w, 4.5.h, 18.w, 5.h),
      Radius.circular(3.r),
    );
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90);
    canvas.drawRRect(dotRect, dotPaint);

    // 3. Bottom-right subtle reflection crescent
    final bottomPath = Path();
    bottomPath.moveTo(w * 0.65, h);
    bottomPath.cubicTo(
      w * 0.80, h * 0.85,
      w * 0.92, h * 0.80,
      w, h * 0.68,
    );
    bottomPath.lineTo(w, h);
    bottomPath.close();

    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(w * 0.65, h * 0.68, w * 0.35, h * 0.32));

    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _GlossyButtonOverlayPainter oldDelegate) => false;
}

class _HomeQuickShortcutGrid extends StatefulWidget {
  final String userId;
  final String email;
  final String country;
  final ValueNotifier<int> currentIndex;
  final int streak;
  final bool streakClaimed;
  final double coins;

  const _HomeQuickShortcutGrid({
    required this.userId,
    required this.email,
    required this.country,
    required this.currentIndex,
    required this.streak,
    required this.streakClaimed,
    required this.coins,
  });

  @override
  State<_HomeQuickShortcutGrid> createState() => _HomeQuickShortcutGridState();
}

class _HomeQuickShortcutGridState extends State<_HomeQuickShortcutGrid> {
  int _activeTagIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _activeTagIndex = (_activeTagIndex + 1) % 6;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hideOfferwall = SplashService.isScreenHidden('offerwall') ||
        !OfferwallManager.getOffersByCategory(category: OfferwallCategory.task).any((e) => e.enabled);
    final bool hideDailyTask = SplashService.isScreenHidden('dailyTask');
    final bool hideStreak = SplashService.isScreenHidden('dailyStreak') || SplashService.isScreenHidden('streak');
    final bool hideSurvey = SplashService.isScreenHidden('survey') ||
        !OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey).any((e) => e.enabled);
    final bool hidePromo = SplashService.isScreenHidden('promoCode');
    final bool hideGiveaway = SplashService.isScreenHidden('giveaway');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Row(
        children: [
          // 1. Offerwall (Index 0)
          if (!hideOfferwall) ...[
            _buildItem(
              context: context,
              itemIndex: 0,
              label: 'Offerwall',
              iconData: Icons.local_offer_rounded,
              badgeText: '2X',
              iconColors: const [Color(0xFF38BDF8), Color(0xFF0284C7)],
              onTap: () {
                HapticFeedback.lightImpact();
                if (!SplashService.isScreenEnabled('offerwall')) {
                  CustomStatusPopup.showComingSoon(
                    context: context,
                    title: 'Offerwall Coming Soon!',
                    message: 'Offerwall feature is currently under active development and will be available very soon.',
                  );
                  return;
                }
                final taskOffers = OfferwallManager.getOffersByCategory(category: OfferwallCategory.task);
                AutoRouter.of(context).push(
                  OfferwallScreenRoute(
                    userId: widget.userId,
                    offerwallList: taskOffers,
                    title: 'task-partner',
                    email: widget.email,
                  ),
                );
              },
            ),
            SizedBox(width: 10.w),
          ],

          // 2. Daily Task (Index 1)
          if (!hideDailyTask) ...[
            _buildItem(
              context: context,
              itemIndex: 1,
              label: 'Daily Task',
              iconData: Icons.task_alt_rounded,
              badgeText: 'HOT',
              iconColors: const [Color(0xFFE39FFF), Color(0xFFAB31DE)],
              onTap: () {
                HapticFeedback.lightImpact();
                if (!SplashService.isScreenEnabled('dailyTask') && !SplashService.isScreenEnabled('dailyTasks')) {
                  CustomStatusPopup.showComingSoon(
                    context: context,
                    title: 'Daily Task Coming Soon!',
                    message: 'Daily Task feature is currently under active development and will be available very soon.',
                  );
                  return;
                }
                AutoRouter.of(context).push(
                  DailyTaskScreenRoute(
                    userId: widget.userId,
                    email: widget.email,
                    country: widget.country,
                  ),
                );
              },
            ),
            SizedBox(width: 10.w),
          ],

          // 3. Daily Streak (Index 2)
          if (!hideStreak) ...[
            _buildItem(
              context: context,
              itemIndex: 2,
              label: 'Daily Streak',
              iconData: Icons.local_fire_department_rounded,
              badgeText: widget.streakClaimed ? 'STREAK' : 'CLAIM',
              iconColors: const [Color(0xFFFF9800), Color(0xFFF57C00)],
              onTap: () {
                HapticFeedback.lightImpact();
                if (!SplashService.isScreenEnabled('dailyStreak') && !SplashService.isScreenEnabled('streak')) {
                  CustomStatusPopup.showComingSoon(
                    context: context,
                    title: 'Daily Streak Coming Soon!',
                    message: 'Daily Streak feature is currently under active development and will be available very soon.',
                  );
                  return;
                }
                DailyCheckInPopup.show(
                  context: context,
                  streak: widget.streak,
                  streakClaimed: widget.streakClaimed,
                  userId: widget.userId,
                  coins: widget.coins.toInt(),
                );
              },
            ),
            SizedBox(width: 10.w),
          ],

          // 4. Survey (Index 3)
          if (!hideSurvey) ...[
            _buildItem(
              context: context,
              itemIndex: 3,
              label: 'Survey',
              iconData: Icons.poll_rounded,
              badgeText: 'TOP',
              iconColors: const [Color(0xFFFACC15), Color(0xFFCA8A04)],
              onTap: () {
                HapticFeedback.lightImpact();
                if (!SplashService.isScreenEnabled('survey')) {
                  CustomStatusPopup.showComingSoon(
                    context: context,
                    title: 'Survey Coming Soon!',
                    message: 'Survey feature is currently under active development and will be available very soon.',
                  );
                  return;
                }
                final surveyOffers = OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey);
                AutoRouter.of(context).push(
                  OfferwallScreenRoute(
                    userId: widget.userId,
                    offerwallList: surveyOffers,
                    title: 'survey-partner',
                    email: widget.email,
                  ),
                );
              },
            ),
            SizedBox(width: 10.w),
          ],

          // 5. Promocode (Index 4)
          if (!hidePromo) ...[
            _buildItem(
              context: context,
              itemIndex: 4,
              label: 'Promocode',
              iconData: Icons.confirmation_number_rounded,
              badgeText: 'CODE',
              iconColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              onTap: () {
                HapticFeedback.lightImpact();
                if (!SplashService.isScreenEnabled('promoCode')) {
                  CustomStatusPopup.showComingSoon(
                    context: context,
                    title: 'Promo Code Coming Soon!',
                    message: 'Promo Code feature is currently under active development and will be available very soon.',
                  );
                  return;
                }
                AutoRouter.of(context).push(const PromoCodeScreenRoute());
              },
            ),
            SizedBox(width: 10.w),
          ],

          // 6. Giveaway (Index 5 - LAST)
          if (!hideGiveaway) ...[
            _buildItem(
              context: context,
              itemIndex: 5,
              label: 'Giveaway',
              iconData: Icons.card_giftcard_rounded,
              badgeText: 'GIFT',
              iconColors: const [Color(0xFF10B981), Color(0xFF059669)],
              onTap: () {
                HapticFeedback.lightImpact();
                if (!SplashService.isScreenEnabled('giveaway')) {
                  CustomStatusPopup.showComingSoon(
                    context: context,
                    title: 'Giveaway Coming Soon!',
                    message: 'Giveaway feature is currently under active development and will be available very soon.',
                  );
                  return;
                }
                AutoRouter.of(context).push(
                  GiveawayScreenRoute(
                    userId: widget.userId,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required int itemIndex,
    required String label,
    required IconData iconData,
    String? badgeText,
    required List<Color> iconColors,
    required VoidCallback onTap,
  }) {
    final primaryColor = iconColors.last;
    final lightColor = iconColors.first;
    final bool isTagActive = _activeTagIndex == itemIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 68.w,
            height: 74.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: const Color(0xFF2C2C36),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18.r),
              child: Stack(
                children: [
                  // Top Center Light Pastel Tint Pillar
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 44.w,
                      height: 38.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(14.r),
                        ),
                        color: lightColor.withValues(alpha: 0.12),
                      ),
                    ),
                  ),

                  // 3D Material Icon in the Center of Pillar
                  Positioned(
                    top: 7.h,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 32.w,
                        height: 32.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [lightColor, primaryColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.40),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            iconData,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Label
                  Positioned(
                    bottom: 6.h,
                    left: 4.w,
                    right: 4.w,
                    child: SizedBox(
                      height: 22.h,
                      child: Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top-Right Micro Tag (Animated sequentially across cards)
          if (badgeText != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              top: isTagActive ? -5.h : 2.h,
              right: isTagActive ? -3.w : 4.w,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isTagActive ? 1.0 : 0.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 350),
                  scale: isTagActive ? 1.0 : 0.3,
                  curve: Curves.elasticOut,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(6.r),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.35),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
