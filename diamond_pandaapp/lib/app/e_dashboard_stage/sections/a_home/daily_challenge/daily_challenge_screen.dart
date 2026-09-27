import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../services/analytics_service.dart';
import '../../../../../../services/cloud_functions.dart';
import '../../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../../widgets/common/custom_loading.dart';
import '../../../../../../widgets/common/custom_toast.dart';
import '../../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../../../widgets/ads/topon_native_ad_card.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../provider/dashboard_provider.dart';
import 'daily_challenge_model.dart';
import 'daily_challenge_provider.dart';
import '../offerwall/model/offerwall_data_model.dart';
import '../offerwall/provider/offerwall_manager.dart';
import '../widgets/daily_checkin_sheet.dart';

// ---------------------------------------------------------------------------
// Interactive Pop-Scale Button (Matching Home & Redeem Screen)
// ---------------------------------------------------------------------------
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
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 130),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
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
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
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



// ---------------------------------------------------------------------------
// Main Daily Challenge Screen (Clean Executive White UI System)
// ---------------------------------------------------------------------------
@RoutePage()
class DailyChallengeScreen extends ConsumerStatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  ConsumerState<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends ConsumerState<DailyChallengeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isClaiming = false;
  Timer? _timer;
  int _secondsRemaining = 0;

  late final AnimationController _animController;
  late final Animation<Offset> _contentSlideAnim;
  late final Animation<double> _contentFadeAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _contentSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _contentFadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        ref.invalidate(dailyChallengeProvider(user.uid));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        ref.invalidate(dailyChallengeProvider(user.uid));
        ref.invalidate(DashboardService.userDataProvider(user.uid));
      }
    }
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _secondsRemaining = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00:00';
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showTasksCompletedInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: const BorderSide(
            color: Color(0xFFF1F5F9),
            width: 1.2,
          ),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.task_alt_rounded,
                      color: const Color(0xFFAB31DE),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Tasks Completed Today',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'This displays the total number of sub-tasks you have completed for today\'s Daily Challenge.',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20.h),
              _PopScaleButton(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 42.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE39FFF),
                        Color(0xFFAB31DE),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'GOT IT',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: const BorderSide(
            color: Color(0xFFF1F5F9),
            width: 1.2,
          ),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.timer_outlined,
                      color: const Color(0xFFF97316),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Daily Challenge Reset',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'The Daily Challenge resets every night at 12:00 AM Midnight (IST). Complete 100% of tasks before time expires to claim your reward!',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20.h),
              _PopScaleButton(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 42.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFB923C),
                        Color(0xFFEA580C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'GOT IT',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToTask(String taskType, String userId, String email) async {
    HapticFeedback.lightImpact();
    switch (taskType.toLowerCase()) {
      case 'play_games':
        await context.router.push(PlayGamesScreenRoute(userId: userId));
        break;
      case 'read_and_earn':
        await context.router.push(ReadTskScreenRoute(userId: userId));
        break;
      case 'super_offer':
        await context.router.push(SuperOfferScreenRoute(userId: userId));
        break;
      case 'battle_arena':
        await context.router.push(BattleArenaScreenRoute(userId: userId, email: email));
        break;
      case 'watch_earn':
      case 'watch_video':
        await context.router.push(WatchVideoScreenRoute(userId: userId, email: email, country: 'IN'));
        break;
      case 'offerwall':
      case 'offerwalls': {
        final taskOffers = OfferwallManager.getOffersByCategory(category: OfferwallCategory.task);
        final surveyOffers = OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey);
        final allOffers = [...taskOffers, ...surveyOffers];
        await context.router.push(
          OfferwallScreenRoute(
            userId: userId,
            email: email,
            title: 'Offerwall Partners',
            offerwallList: allOffers.isNotEmpty ? allOffers : taskOffers,
          ),
        );
        break;
      }
      case 'survey':
      case 'surveys': {
        final surveyOffers = OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey);
        await context.router.push(
          OfferwallScreenRoute(
            userId: userId,
            email: email,
            title: 'Surveys & Research',
            offerwallList: surveyOffers,
          ),
        );
        break;
      }
      case 'daily_task':
      case 'daily_tasks': {
        final taskOffers = OfferwallManager.getOffersByCategory(category: OfferwallCategory.task);
        await context.router.push(
          OfferwallScreenRoute(
            userId: userId,
            email: email,
            title: 'Daily Tasks & Offers',
            offerwallList: taskOffers,
          ),
        );
        break;
      }
      case 'daily_checkin':
      case 'checkin':
      case 'daily_streak':
      case 'streak': {
        final userData = ref.read(DashboardService.userDataProvider(userId)).value;
        final streak = userData?.streak ?? 0;
        final streakClaimed = userData?.streakClaimed ?? false;
        await DailyCheckInPopup.show(
          context: context,
          userId: userId,
          streak: streak,
          streakClaimed: streakClaimed,
        );
        break;
      }
      case 'giveaway':
        await context.router.push(GiveawayScreenRoute(userId: userId));
        break;
      default:
        await context.router.push(PlayGamesScreenRoute(userId: userId));
        break;
    }
    if (mounted) {
      ref.invalidate(dailyChallengeProvider(userId));
      ref.invalidate(DashboardService.userDataProvider(userId));
    }
  }

  Future<void> _handleClaim(String userId, int rewardCoins) async {
    setState(() => _isClaiming = true);
    try {
      final res = await CloudFunctions.claimDailyChallengeReward();
      if (!mounted) return;
      setState(() => _isClaiming = false);

      if (res['success'] == true || res['response'] == 'success') {
        AnalyticsService.logDailyChallengeClaimed(rewardCoins: rewardCoins);
        ref.invalidate(dailyChallengeProvider(userId));
        ref.invalidate(DashboardService.userDataProvider(userId));

        CustomStatusPopup.show(
          context: context,
          type: StatusPopupType.success,
          tag: 'CHALLENGE COMPLETE',
          title: 'Reward Claimed!',
          message: 'You received +$rewardCoins Coins for completing all daily challenge tasks!',
          primaryButtonText: 'Awesome!',
          onPrimaryTap: () => Navigator.of(context).pop(),
        );
      } else {
        CustomToast.showToast(context, msg: res['message'] ?? 'Failed to claim challenge reward');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isClaiming = false);
        CustomToast.showToast(context, msg: 'Error claiming reward. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';
    final email = user?.email ?? '';
    final challengeAsync = ref.watch(dailyChallengeProvider(userId));

    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Solid White Clean Background (Matching Home & Redeem Screen)
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Foreground Scrollable Content
            Positioned.fill(
              child: FadeTransition(
                opacity: _contentFadeAnim,
                child: SlideTransition(
                  position: _contentSlideAnim,
                  child: Column(
                    children: [
                      // Header Navigation Bar (Back Arrow + Clean Title)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16.w,
                          topPadding + 8.h,
                          16.w,
                          14.h,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                AutoRouter.of(context).maybePop();
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
                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: const Color(0xFFAB31DE),
                                  size: 22.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              'Daily Challenge',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Main Async Challenge Feed
                      Expanded(
                        child: challengeAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: GlowLightingSpinner(size: 36),
                            ),
                          ),
                          error: (err, _) => Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32.w),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_off_rounded, color: const Color(0xFFAB31DE), size: 48.sp),
                                  SizedBox(height: 14.h),
                                  Text(
                                    'Connection Error',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF1E1B4B),
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Unable to load today\'s challenge. Please check your internet connection.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF64748B),
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                  SizedBox(height: 18.h),
                                  _PopScaleButton(
                                    onTap: () => ref.invalidate(dailyChallengeProvider(userId)),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFE39FFF),
                                            Color(0xFFAB31DE),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Text(
                                        'Retry',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          data: (challengeData) {
                            if (challengeData == null || !challengeData.isActive) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.event_busy_rounded, color: const Color(0xFFAB31DE), size: 48.sp),
                                      SizedBox(height: 14.h),
                                      Text(
                                        'Daily Challenge Inactive',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF1E1B4B),
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        'Daily Challenge is currently resting. Check back tomorrow for exciting new rewards!',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF64748B),
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (_timer == null && challengeData.secondsRemaining > 0) {
                              _startTimer(challengeData.secondsRemaining);
                            }

                            final isDone = challengeData.isAllCompleted;
                            final isClaimed = challengeData.claimedReward;
                            final progressPercent = challengeData.overallProgressPercent.clamp(0.0, 1.0);

                            return RefreshIndicator(
                              color: const Color(0xFFAB31DE),
                              backgroundColor: Colors.white,
                              onRefresh: () async {
                                ref.invalidate(dailyChallengeProvider(userId));
                                ref.invalidate(DashboardService.userDataProvider(userId));
                              },
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(height: 4.h),

                                    // Native Ad at the top of Daily Challenge Screen
                                    ToponNativeAdCard(
                                      isEnabled: AdKeys.isDailyChallengeNativeEnabled,
                                      margin: EdgeInsets.only(bottom: 12.h),
                                    ),

                                    // -------------------------------------------------------------
                                    // 1. Hero Executive Balance Card System (Matching Redeem Screen)
                                    // -------------------------------------------------------------
                                    _buildHeroExecutiveCard(
                                      context: context,
                                      data: challengeData,
                                      isDone: isDone,
                                      isClaimed: isClaimed,
                                      progress: progressPercent,
                                      userId: userId,
                                    ),

                                    SizedBox(height: 16.h),

                                    // Screen Banner Widget (Daily Challenge Screen)
                                    const ScreenBannerWidget(
                                      screenKey: 'dailyChallengeScreen',
                                      margin: EdgeInsets.only(bottom: 12.0),
                                    ),

                                    // -------------------------------------------------------------
                                    // 2. Dual Floating Executive Stats Cards (Matching Redeem Screen)
                                    // -------------------------------------------------------------
                                    _buildDualStatsCards(
                                      context: context,
                                      data: challengeData,
                                    ),

                                    SizedBox(height: 24.h),

                                    // -------------------------------------------------------------
                                    // 3. Section Header: Today's Tasks (Matching Redeem Method Header)
                                    // -------------------------------------------------------------
                                    _buildTodayTasksSectionHeader(challengeData),

                                    SizedBox(height: 14.h),

                                    // -------------------------------------------------------------
                                    // 4. Sub-Tasks List Cards (Executive White Clean Style)
                                    // -------------------------------------------------------------
                                    if (challengeData.tasks.isEmpty)
                                      _buildEmptyTasksCard()
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: challengeData.tasks.length,
                                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                                        itemBuilder: (context, index) {
                                          final task = challengeData.tasks[index];
                                          return _buildExecutiveTaskCard(
                                            context: context,
                                            task: task,
                                            userId: userId,
                                            email: email,
                                          );
                                        },
                                      ),

                                    SizedBox(height: 24.h),

                                    // -------------------------------------------------------------
                                    // 5. How It Works Rules Card (Clean White Executive Style)
                                    // -------------------------------------------------------------
                                    _buildRulesInfoCard(),

                                    SizedBox(height: 50.h),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Executive Hero Card (Matching Home & Redeem Screen Balance Card 1-to-1)
  // ---------------------------------------------------------------------------
  Widget _buildHeroExecutiveCard({
    required BuildContext context,
    required DailyChallengeData data,
    required bool isDone,
    required bool isClaimed,
    required double progress,
    required String userId,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            // Right Soft Purple Dome Backdrop Patti (Matching Redeem Balance Card)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 125.w,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFAF5FF).withValues(alpha: 0.0),
                      const Color(0xFFFAF5FF).withValues(alpha: 0.6),
                      const Color(0xFFF3E8FF),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(60.r),
                    bottomLeft: Radius.circular(60.r),
                    topRight: Radius.circular(24.r),
                    bottomRight: Radius.circular(24.r),
                  ),
                ),
              ),
            ),

            // Right Artwork Graphic (Coin asset)
            Positioned(
              right: 12.w,
              top: 12.h,
              bottom: 12.h,
              width: 90.w,
              child: Center(
                child: Image.asset(
                  'assets/icons/coin.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Main Content Area
            Padding(
              padding: EdgeInsets.all(18.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Action Badge / Claim Button Position
                  Row(
                    children: [
                      if (!isDone)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.5.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                color: const Color(0xFF64748B),
                                size: 13.sp,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                'LOCKED',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!isClaimed)
                        _PopScaleButton(
                          onTap: () {
                            if (!_isClaiming) {
                              _handleClaim(userId, data.rewardCoins);
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF59E0B),
                                  Color(0xFFD97706),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(20.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: _isClaiming
                                ? const GlowLightingSpinner(size: 16)
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/icons/coin.png',
                                        width: 16.sp,
                                        height: 16.sp,
                                        fit: BoxFit.contain,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        'CLAIM +${data.rewardCoins}',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.5.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color(0xFF86EFAC),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: const Color(0xFF15803D),
                                size: 13.sp,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                'CLAIMED',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF15803D),
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 10.h),

                  // Headline: Bonus Reward
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Challenge: ',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        TextSpan(
                          text: '+${data.rewardCoins} Coins',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFAB31DE),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // Subtitle
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.55,
                    child: Text(
                      isDone
                          ? (isClaimed
                              ? 'You claimed today\'s reward. Check back tomorrow!'
                              : 'Awesome! All tasks complete. Claim your bonus coins now.')
                          : 'Complete all ${data.totalTasksCount} tasks today & claim your bonus coins before midnight.',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        height: 1.35,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  SizedBox(height: 14.h),

                  // Progress Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Progress',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}% Complete',
                        style: GoogleFonts.outfit(
                          color: isDone ? const Color(0xFF16A34A) : const Color(0xFFAB31DE),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 6.h),

                  // Clean Progress Track
                  Stack(
                    children: [
                      Container(
                        height: 8.h,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: 8.h,
                        width: (MediaQuery.of(context).size.width - 68.w) * progress,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.r),
                          gradient: LinearGradient(
                            colors: isDone
                                ? [const Color(0xFF34D399), const Color(0xFF059669)]
                                : [const Color(0xFFE39FFF), const Color(0xFFAB31DE)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dual Stats Cards (Matching Executive Light Style)
  // ---------------------------------------------------------------------------
  Widget _buildDualStatsCards({
    required BuildContext context,
    required DailyChallengeData data,
  }) {
    return Row(
      children: [
        // 1. Tasks Completed Card
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              _showTasksCompletedInfo(context);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: const Color(0xFFF3E8FF),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.all(8.r),
                    child: Image.asset(
                      'assets/icons/donee.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.task_alt_rounded,
                        color: Color(0xFFAB31DE),
                        size: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${data.completedTasksCount}/${data.totalTasksCount}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Completed',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Icon(
                              Icons.info_outline_rounded,
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.6),
                              size: 11.sp,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(width: 12.w),

        // 2. Countdown Timer Card
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              _showResetsInfo(context);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: const Color(0xFFF1F5F9),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: const Color(0xFFFFEDD5),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.all(7.r),
                    child: Image.asset(
                      'assets/icons/fire (2).png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFFF97316),
                        size: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimer(_secondsRemaining),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Resets In',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Icon(
                              Icons.info_outline_rounded,
                              color: const Color(0xFFF97316).withValues(alpha: 0.6),
                              size: 11.sp,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Today's Tasks Section Header (Matching Redeem Screen Method Header)
  // ---------------------------------------------------------------------------
  Widget _buildTodayTasksSectionHeader(DailyChallengeData challengeData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFE39FFF),
                      Color(0xFFAB31DE),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Icon(
                    Icons.stars_rounded,
                    color: Colors.white,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                RichText(
                  text: TextSpan(
                    text: 'Today\'s ',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 16.5.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    children: [
                      TextSpan(
                        text: 'Tasks',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 16.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFFE39FFF).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                '${challengeData.completedTasksCount}/${challengeData.totalTasksCount} Complete',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFAB31DE),
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 3.h),
        Text(
          'Finish sub-tasks to achieve 100% completion',
          style: GoogleFonts.outfit(
            color: const Color(0xFF64748B),
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          width: 36.w,
          height: 2.h,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFAB31DE),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(1.r),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Fallback Empty Tasks Card
  // ---------------------------------------------------------------------------
  Widget _buildEmptyTasksCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_late_outlined,
            size: 40.sp,
            color: const Color(0xFFAB31DE),
          ),
          SizedBox(height: 10.h),
          Text(
            'No Tasks Available',
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Please check back later for new daily challenges.',
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Executive Task Item Card (Matching Clean Home Card System 1-to-1)
  // ---------------------------------------------------------------------------
  Widget _buildExecutiveTaskCard({
    required BuildContext context,
    required DailyChallengeTaskItem task,
    required String userId,
    required String email,
  }) {
    final isComplete = task.isCompleted;
    final current = task.currentCount.clamp(0, task.targetCount);
    final target = task.targetCount;
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isComplete ? const Color(0xFF86EFAC) : const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isComplete
                ? const Color(0xFF16A34A).withValues(alpha: 0.06)
                : const Color(0xFFAB31DE).withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Task Icon Avatar Container
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isComplete ? const Color(0xFFDCFCE7) : const Color(0xFFFAF5FF),
                border: Border.all(
                  color: isComplete ? const Color(0xFF86EFAC) : const Color(0xFFF3E8FF),
                  width: 1.2,
                ),
              ),
              padding: EdgeInsets.all(8.w),
              child: Image.asset(
                task.icon.isNotEmpty ? task.icon : 'assets/icons/playtimegame.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.emoji_events_rounded,
                  color: isComplete ? const Color(0xFF15803D) : const Color(0xFFAB31DE),
                  size: 22.sp,
                ),
              ),
            ),

            SizedBox(width: 12.w),

            // Middle: Title, Description & Progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    task.description.isNotEmpty ? task.description : 'Complete $target times today',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // Mini Progress Track
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 6.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(3.r),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: 6.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3.r),
                                  gradient: LinearGradient(
                                    colors: isComplete
                                        ? [const Color(0xFF34D399), const Color(0xFF059669)]
                                        : [const Color(0xFFE39FFF), const Color(0xFFAB31DE)],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '$current/$target',
                        style: GoogleFonts.outfit(
                          color: isComplete ? const Color(0xFF16A34A) : const Color(0xFFAB31DE),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: 12.w),

            // Right CTA: "Done" Badge or Gradient "GO" Button
            if (isComplete)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFF86EFAC),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, color: const Color(0xFF15803D), size: 14.sp),
                    SizedBox(width: 4.w),
                    Text(
                      'Done',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF15803D),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else
              _PopScaleButton(
                onTap: () => _navigateToTask(task.taskType, userId, email),
                child: Container(
                  width: 62.w,
                  height: 34.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE39FFF),
                        Color(0xFFAB31DE),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'GO',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // How It Works Rules Card (Executive Light Style)
  // ---------------------------------------------------------------------------
  Widget _buildRulesInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: const Color(0xFFAB31DE), size: 18.sp),
              SizedBox(width: 6.w),
              Text(
                'How Daily Challenge Works',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _buildBulletPoint('Daily Challenge resets every night at 12:00 AM (Midnight IST).'),
          _buildBulletPoint('Complete 100% of all listed tasks within 24 hours to unlock the bonus reward.'),
          _buildBulletPoint('Tap "CLAIM" once all tasks show "Done" to instantly add coins to your balance.'),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: const Color(0xFFAB31DE), fontSize: 14.sp, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 11.5.sp,
                height: 1.35,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
