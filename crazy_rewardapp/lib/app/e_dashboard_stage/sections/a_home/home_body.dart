import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../../utils/helper/helper.dart';
import '../../../../utils/routes/routes_import.gr.dart';
import '../../../../widgets/common/custom_status_popup.dart';
import '../../../../widgets/common/custom_loading.dart';
import '../../../../widgets/common/internet_image.dart';
import '../../provider/dashboard_provider.dart';
import 'daily_task/daily_task_model.dart';
import 'daily_task/daily_task_provider.dart';
import 'widgets/balance_card.dart';
import 'widgets/daily_task_card.dart';
import 'widgets/daily_checkin_sheet.dart';

import '../../../b_splash_stage/splash_service.dart';
import '../../../../services/cloud_functions.dart';
import '../../../../services/launch_url.dart';
import '../../../../services/local_storage.dart';
import 'widgets/top_recommended_task_widget.dart';
import 'widgets/offer_partners_section.dart';
import 'widgets/more_ways.dart';
import 'widgets/more_apps_section.dart';
import 'widgets/home_screen_shimmer.dart';
import '../../../../widgets/ads/topon_native_ad_card.dart';

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
    final effectiveLoading = isLoading || (!taskAsync.hasValue && taskAsync.isLoading);

    if (effectiveLoading) {
      return const HomeScreenShimmer();
    }

    final scrollController = useScrollController();

    return Stack(
      children: [
        // 1. Solid White Background
        Positioned.fill(
          child: Container(
            color: Colors.white,
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
                  top: 64.h + MediaQuery.of(context).padding.top,
                  child: ClipRect(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: 10.h),

                          // Main Balance Card (Coins & Gems) - Scrolls UP and DISAPPEARS cleanly under header!
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            child: BalanceCard(
                              coins: coins,
                              gems: gems,
                              userId: userId,
                              country: country,
                              isGuest: isGuest,
                            ),
                          ),

                          SizedBox(height: 14.h),

                          // Home Banner Slider
                          const _HomeBannerSlider(),

                          SizedBox(height: 14.h),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            child: Column(
                              children: [
                                if (!SplashService.isScreenHidden('dailyTasks'))
                                  taskAsync.when(
                                    data: (offers) {
                                      if (offers.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 16.h),
                                        child: HomeDailyTaskSection(
                                          offers: offers,
                                          userId: userId,
                                          email: email,
                                          country: country,
                                        ),
                                      );
                                    },
                                    error: (_, __) => const SizedBox.shrink(),
                                    loading: () => const SizedBox.shrink(),
                                  ),
                                TopRecommendedTaskWidget(
                                  userId: userId,
                                  email: email,
                                  country: country,
                                  dailyChallengeWidget: !SplashService.isScreenHidden('dailyChallenge')
                                      ? _PlayGamesHeroBanner(
                                          userId: userId,
                                          email: email,
                                          country: country,
                                          currentIndex: currentIndex,
                                        )
                                      : null,
                                  quickShortcutGridWidget: _HomeQuickShortcutGrid(
                                    userId: userId,
                                    email: email,
                                    country: country,
                                    currentIndex: currentIndex,
                                    streak: streak,
                                    streakClaimed: streakClaimed,
                                    coins: coins,
                                  ),
                                ),
                                ToponNativeAdCard(
                                  margin: EdgeInsets.only(top: 20.h, bottom: 20.h),
                                ),
                                OfferPartnersSection(userId: userId, email: email, country: country),
                                SizedBox(height: 14.h),
                                MoreWaysSection(
                                  userId: userId,
                                  email: email,
                                  country: country,
                                  currentIndex: currentIndex,
                                ),
                                SizedBox(height: 24.h),
                                MoreAppsSection(userId: userId),
                                SizedBox(height: 24.h),
                                _buildFollowUsCard(
                                  context: context,
                                  socialFollowed: socialFollowed,
                                ),
                                SizedBox(height: 100.h),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. PINNED FIXED USER PROFILE HEADER (Exact original colors & styling)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _HomeTopHeaderCard(
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUsCard({
    required BuildContext context,
    required List<String> socialFollowed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Card Container
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: _PopScaleButton(
            onTap: () {
              HapticFeedback.lightImpact();
              AutoRouter.of(context).push(
                FollowScreenRoute(userId: userId),
              );
            },
            child: Container(
              width: double.infinity,
              height: 124.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22.r),
                child: Stack(
                  children: [
                    // 1. Right Side Soft Purple Dome Backdrop
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 140.w,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFAB31DE).withValues(alpha: 0.12),
                              const Color(0xFFAB31DE).withValues(alpha: 0.03),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(55.r),
                            bottomLeft: Radius.circular(55.r),
                            topRight: Radius.circular(22.r),
                            bottomRight: Radius.circular(22.r),
                          ),
                        ),
                      ),
                    ),

                    // 2. Foreground Row Content
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      child: Row(
                        children: [
                          // Left Section: VIP Badge + Title + Subtitle + Action Button
                          Expanded(
                            flex: 13,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 16.h),
                                    Text(
                                      'Join Our Social Media',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF1E1B4B),
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      'Unlock exclusive daily giveaway codes & extra coins!',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF64748B),
                                        fontSize: 8.5.sp,
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),

                                 Container(
                                   padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.5.h),
                                   decoration: BoxDecoration(
                                     gradient: const LinearGradient(
                                       begin: Alignment.topCenter,
                                       end: Alignment.bottomCenter,
                                       colors: [
                                         Color(0xFFE39FFF),
                                         Color(0xFFAB31DE),
                                       ],
                                     ),
                                     borderRadius: BorderRadius.circular(10.r),
                                     boxShadow: [
                                       BoxShadow(
                                         color: const Color(0xFFAB31DE).withValues(alpha: 0.30),
                                         blurRadius: 8,
                                         offset: const Offset(0, 2),
                                       ),
                                     ],
                                   ),
                                   child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                       Text(
                                         'Join Now',
                                         style: GoogleFonts.poppins(
                                           color: Colors.white,
                                           fontSize: 11.5.sp,
                                           fontWeight: FontWeight.w700,
                                           letterSpacing: 0.2,
                                         ),
                                       ),
                                       SizedBox(width: 4.w),
                                       Icon(
                                         Icons.arrow_forward_ios_rounded,
                                         color: Colors.white,
                                         size: 10.5.sp,
                                       ),
                                     ],
                                   ),
                                 ),
                              ],
                            ),
                          ),

                          // Right Section: Glassmorphic Container with 4 Social Icons
                          Expanded(
                            flex: 8,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.all(7.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                                    width: 1.0,
                                  ),
                                ),
                                child: Wrap(
                                  spacing: 6.w,
                                  runSpacing: 6.h,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _buildSocialBadge('assets/icons/telegram.png'),
                                    _buildSocialBadge('assets/icons/instagram.png'),
                                    _buildSocialBadge('assets/icons/youtube.png'),
                                    _buildSocialBadge('assets/icons/whatsapp.png'),
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialBadge(String imageAsset) {
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11.r),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(6.5.w),
      child: Image.asset(
        imageAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.share_rounded,
          color: const Color(0xFFAB31DE),
          size: 18.sp,
        ),
      ),
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


// Fading gradient border painter
class _FadingCardBorderPainter extends CustomPainter {
  final double borderRadius;
  final Color borderColor;

  const _FadingCardBorderPainter({
    required this.borderRadius,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius.r));

    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        borderColor,
        borderColor.withValues(alpha: 0.1),
        Colors.transparent,
      ],
      stops: const [0.0, 0.75, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _FadingCardBorderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor || oldDelegate.borderRadius != borderRadius;
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
    return SizedBox(
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ---------------- LEFT: USER PROFILE PICTURE + GREETING & NAME ----------------
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => currentIndex.value = 3, // Open Profile / Menu
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User Profile Picture Avatar with Profile.json Lottie Frame
                    SizedBox(
                      width: 72.w,
                      height: 72.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Profile Avatar
                          Container(
                            width: 38.w,
                            height: 38.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: photoUrl.isNotEmpty
                                  ? AvatarInternetImage(
                                      url: photoUrl,
                                      size: 36.w,
                                      borderWidth: 0,
                                      borderColor: Colors.transparent,
                                    )
                                  : Image.asset(
                                      'assets/icons/DIAMONDPANDA_LOGO.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.person_rounded,
                                        color: const Color(0xFFAB31DE),
                                        size: 24.sp,
                                      ),
                                    ),
                            ),
                          ),

                          // 2. Profile.json Lottie Animation Overlay Frame (Precisely offset to center over avatar)
                          IgnorePointer(
                            child: Transform.translate(
                              offset: Offset(0, -4.h),
                              child: SizedBox(
                                width: 72.w,
                                height: 72.w,
                                child: Lottie.asset(
                                  'assets/icons/Profile.json',
                                  fit: BoxFit.contain,
                                  repeat: true,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
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
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 130.w),
                          child: Text(
                            name.isNotEmpty ? name : 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 15.sp,
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

              // ---------------- RIGHT: NOTIFICATION BELL ICON BUTTON (Daily Task Style) ----------------
              _PopScaleButton(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await AutoRouter.of(context).push(const NotificationScreenRoute());
                  LocalStorage.hasUnreadNotificationNotifier.value = LocalStorage.hasUnreadNotifications();
                },
                child: Container(
                  width: 40.w,
                  height: 40.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.r),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Inner 3D Gradient Bubble (Signature Daily Task Gradient: #E39FFF -> #AB31DE)
                      Container(
                        width: 28.w,
                        height: 28.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.40),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.notifications_rounded,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                        ),
                      ),
                      // Notification Indicator Dot (Only shown when unread notifications exist)
                      ValueListenableBuilder<bool>(
                        valueListenable: LocalStorage.hasUnreadNotificationNotifier,
                        builder: (context, hasUnread, _) {
                          if (!hasUnread) return const SizedBox.shrink();
                          return Positioned(
                            top: -2.h,
                            right: -2.w,
                            child: Container(
                              width: 9.w,
                              height: 9.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
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
        ),
      ),
    );
  }
}

class _CoinPillShapePainter extends CustomPainter {
  const _CoinPillShapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shapePaint = Paint()
      ..color = const Color(0xFF4C1D95)
      ..style = PaintingStyle.fill;

    final path = Path();

    final humpX = w * 0.28;
    final r = h * 0.38;

    // 1. Top-left hump beside coin
    path.moveTo(humpX, 0);

    // 2. Top horizontal edge to right rounded corner
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);

    // 3. Right vertical edge
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);

    // 4. Bottom horizontal edge under coin
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);

    // 5. Left edge behind coin
    path.lineTo(0, h * 0.48);

    // 6. Concave neck notch curving into top hump
    path.quadraticBezierTo(w * 0.05, h * 0.40, w * 0.12, h * 0.40);
    path.quadraticBezierTo(w * 0.22, h * 0.40, w * 0.25, h * 0.18);
    path.quadraticBezierTo(w * 0.26, 0, humpX, 0);

    path.close();

    canvas.drawPath(path, shapePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ===========================================================================
// PLAY GAMES HERO BANNER (Treasure Chest Featured Card)
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
      padding: EdgeInsets.symmetric(horizontal: 10.w),
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
          height: 126.h,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              bottomLeft: Radius.circular(20.r),
              topRight: Radius.circular(16.r),
              bottomRight: Radius.circular(16.r),
            ),
            border: Border.all(
              color: Colors.white,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 1. Glassmorphic Heavy Blurred Daily Challenge Asset Backdrop (Directly behind foreground artwork)
              Positioned(
                right: -24.w,
                top: -20.h,
                bottom: -10.h,
                width: 190.w,
                child: Opacity(
                  opacity: 0.60,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Image.asset(
                      'assets/icons/dailychallange.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.topRight,
                    ),
                  ),
                ),
              ),

              // 2. Left Text Area
              Positioned(
                left: 22.w,
                top: 14.h,
                bottom: 14.h,
                right: 138.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Heading: Daily Challenge
                    Text(
                      'Daily Challenge',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 21.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 5.h),

                    // Description
                    Text(
                      'Complete simple tasks, play games and unlock exciting rewards every day',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF475569),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 7.h),

                    // Interactive Action Button
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFAB31DE).withValues(alpha: 0.30),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Play & Earn',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 10.5.sp,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Foreground Crisp 3D Daily Challenge Icon on top
              Positioned(
                right: -2.w,
                bottom: 0.h,
                top: 4.h,
                width: 140.w,
                child: Image.asset(
                  'assets/icons/dailychallange.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
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





// ---------------------------------------------------------------------------
// GAMING BALANCE PILL CARD WITH SLANTED 3D BUTTON & FADING OUTLINE
// ---------------------------------------------------------------------------
class _GamingBalancePillCard extends StatelessWidget {
  const _GamingBalancePillCard({
    required this.iconWidget,
    required this.child,
    required this.onTap,
  });

  final Widget iconWidget;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 38.h,
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // 1. Center Slot Bar with Right-to-Left Fading Neon Top/Bottom Outlines
            Positioned(
              left: 18.w,
              right: 14.w,
              top: 4.h,
              bottom: 4.h,
              child: CustomPaint(
                painter: const _FadingBorderSlotPainter(),
                child: Padding(
                  padding: EdgeInsets.only(left: 16.w, right: 16.w),
                  child: Center(
                    child: child,
                  ),
                ),
              ),
            ),

            // 2. Right Slanted 3D Glossy Button (Aligned flush with bar height)
            Positioned(
              right: 0,
              top: 4.h,
              bottom: 4.h,
              child: Transform(
                transform: Matrix4.skewX(-0.12),
                alignment: Alignment.center,
                child: Container(
                  width: 34.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _GlossyButtonPainter(borderRadius: 7.r),
                    child: Center(
                      child: Transform(
                        transform: Matrix4.skewX(0.12), // Un-skew icon
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Left 3D Icon (Overlapping on the Left Edge)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 38.w,
                child: Center(
                  child: iconWidget,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FadingBorderSlotPainter extends CustomPainter {
  const _FadingBorderSlotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 1. Dark Slot Background
    final bgPaint = Paint()
      ..color = const Color(0xFF141235)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(6.r)),
      bgPaint,
    );

    // 2. Right-to-Left Fading Neon Border Shader
    final borderShader = const LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        Color(0xFFC084FC),
        Color(0xFF9333EA),
        Color(0x009333EA),
      ],
      stops: [0.0, 0.65, 1.0],
    ).createShader(rect);

    final borderPaint = Paint()
      ..shader = borderShader
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Top Neon Line (Fading from right to left)
    canvas.drawLine(
      Offset(0, 0.75),
      Offset(size.width, 0.75),
      borderPaint,
    );

    // Bottom Neon Line (Fading from right to left)
    canvas.drawLine(
      Offset(0, size.height - 0.75),
      Offset(size.width, size.height - 0.75),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlossyButtonPainter extends CustomPainter {
  const _GlossyButtonPainter({required this.borderRadius});
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Fill Gradient (Brand purple/lavender look)
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE39FFF), // Light lavender
          Color(0xFFAB31DE), // Rich brand purple
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    // 2. Shiny Highlight Borders (Top & side shine, fading out to bottom)
    final borderPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white, // Pure white shiny top bevel
          Color(0xFFF3E8FF), // Glossy light purple sides
          Color(0x108B1BF4), // Clean fading bottom edge
        ],
        stops: [0.0, 0.45, 1.0],
      ).createShader(rect)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget _buildColoredName(String name, double fontSize) {
  if (name.isEmpty) name = 'User';
  final words = name.split(' ');
  final spans = <TextSpan>[];

  for (int i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) continue;
    
    // Divide word: first half is white, second half is yellow
    final halfLen = word.length ~/ 2;
    final firstHalf = word.substring(0, halfLen == 0 ? 1 : halfLen);
    final secondHalf = word.substring(halfLen == 0 ? 1 : halfLen);

    spans.add(
      TextSpan(
        text: firstHalf,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    spans.add(
      TextSpan(
        text: secondHalf,
        style: GoogleFonts.outfit(
          color: const Color(0xFFFACC15), // WinSphere Yellow
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (i < words.length - 1) {
      spans.add(
        TextSpan(
          text: ' ',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
  }

  return RichText(
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    text: TextSpan(children: spans),
  );
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
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 68.w,
            height: 74.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: Colors.white,
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                      height: 40.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(14.r),
                        ),
                        color: lightColor.withValues(alpha: 0.14),
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
                            color: const Color(0xFF1E1B4B),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
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
