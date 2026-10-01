 import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../provider/dashboard_provider.dart';
import '../../../../b_splash_stage/splash_service.dart';
import 'super_offer_model.dart';
import '../Crazy_racing/crazy_racing_model.dart';
import 'super_offer_provider.dart';
import '../Crazy_racing/crazy_racing_provider.dart';
import 'super_offer_widget.dart';
import 'super_offer_step2_list_screen.dart';
import 'super_offer_leaderboard_screen.dart';
import 'super_offer_leaderboard_provider.dart';
import '../../../../../widgets/common/shimmer_tag.dart';
import '../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../../widgets/ads/topon_native_ad_card.dart';
import '../../../../../utils/constant/constant.dart';
import '../widgets/daily_checkin_sheet.dart';

@RoutePage()
class SuperOfferScreen extends HookConsumerWidget {
  const SuperOfferScreen({super.key, required this.userId});

  final String userId;

  String _translate(String key, String fallback) {
    final val = key.tr();
    return val == key ? fallback : val;
  }

  void _showOffersCompletedInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
          side: BorderSide(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
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
                  Icon(
                    Icons.task_alt_rounded,
                    color: const Color(0xFFAB31DE),
                    size: 24.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Offers Completed',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E1B2E),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'This shows the total number of Super Offers and Daily Tasks you have successfully completed.',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20.h),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 44.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE39FFF),
                        Color(0xFFAB31DE),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Text(
                    'GOT IT',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
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



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPadding = MediaQuery.of(context).padding.top;

    final animController = useAnimationController(
      duration: const Duration(milliseconds: 550),
    );

    final effectiveUid = userId.isNotEmpty ? userId : (FirebaseAuth.instance.currentUser?.uid ?? '');
    final pendingOffersAsync = ref.watch(pendingOffersProvider(effectiveUid));
    final pendingList = pendingOffersAsync.maybeWhen(
      data: (list) => list,
      orElse: () => SuperOfferStep2ListScreen.getSavedOffers(effectiveUid),
    );

    useEffect(() {
      animController.forward();
      Future.microtask(() {
        ref.invalidate(DashboardService.userDataProvider(effectiveUid));
        ref.invalidate(superOfferVerifierProvider(effectiveUid));
        ref.invalidate(diamondCatchVerifierProvider(effectiveUid));
        ref.invalidate(pendingOffersProvider(effectiveUid));
      });
      return null;
    }, [effectiveUid]);

    final contentSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animController,
      curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
    ));

    final contentFadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animController,
      curve: const Interval(0.1, 0.85, curve: Curves.easeOut),
    ));

    final userAsync = ref.watch(DashboardService.userDataProvider(userId));
    final liveGems = userAsync.maybeWhen(
      data: (user) => user.gems,
      orElse: () => 0,
    );

    final superOfferVerifierAsync = ref.watch(superOfferVerifierProvider(effectiveUid));
    final completedSuperOffersCount = superOfferVerifierAsync.maybeWhen(
      data: (so) => so.completedSuperOffers,
      orElse: () => 0,
    );

    final leaderboardAsync = ref.watch(superOfferLeaderboardProvider(''));
    final isContestActive = leaderboardAsync.maybeWhen(
      data: (res) => res.contest.isActive,
      orElse: () => true,
    );

     return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Stack(
          children: [
            // 1. Soft Slate Gray Background matching Home Screen
            Positioned.fill(
              child: Container(
                color: const Color(0xFFF1F5F9),
              ),
            ),

            // 2. Main Content
            Positioned.fill(
              child: FadeTransition(
                opacity: contentFadeAnim,
                child: SlideTransition(
                  position: contentSlideAnim,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(DashboardService.userDataProvider(effectiveUid));
                          ref.invalidate(superOfferVerifierProvider(effectiveUid));
                          ref.invalidate(diamondCatchVerifierProvider(effectiveUid));
                          ref.invalidate(pendingOffersProvider(effectiveUid));
                          ref.invalidate(superOfferLeaderboardProvider(''));
                          await SuperOfferStep2ListScreen.syncSavedOffers(effectiveUid);
                        },
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                          child: Container(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                // 1. Top Section Header
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    16.w,
                                    topPadding + 8.h,
                                    16.w,
                                    16.h,
                                  ),
                                  child: Column(
                                    children: [
                                      // Top Header Bar (Back button + Center Title + Gems counter)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Left Back Button
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
                                                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.arrow_back_rounded,
                                                color: const Color(0xFF1E1B2E),
                                                size: 22.sp,
                                              ),
                                            ),
                                          ),

                                          // Center Title
                                          Text(
                                            'Super Offer',
                                            style: GoogleFonts.kaushanScript(
                                              color: const Color(0xFF26262B),
                                              fontSize: 24.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),

                                          // Right Gems Pill
                                          _AvailableGemsBadge(gems: liveGems),
                                        ],
                                      ),

                                      SizedBox(height: 14.h),

                                      // Screen Banner (Admin Configurable 700x200 with AD badge) placed at the TOP!
                                      const ScreenBannerWidget(
                                        screenKey: 'superOfferScreen',
                                        margin: EdgeInsets.only(bottom: 12),
                                      ),

                                      if (isContestActive) ...[
                                        // 🏆 Contest Active (App Status ON): Show Mega Bumper Prize Card
                                        _buildLeaderboardBannerCard(context),
                                      ] else ...[
                                        // 🔒 Contest Paused/Off (App Status OFF): Show Super Mission Header
                                        _buildSuperMissionHeader(),
                                      ],
                                      SizedBox(height: 14.h),
                                      _buildStatsCard(
                                        context,
                                        SuperOfferModel(
                                          gems: liveGems,
                                          completedSuperOffers: completedSuperOffersCount,
                                          streak: userAsync.maybeWhen(
                                            data: (u) => u.streak,
                                            orElse: () => 0,
                                          ),
                                          dailyGems: 0,
                                        ),
                                        ref,
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 6.h),

                                // 3. Offers Content Section
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                                  child: Column(
                                    children: [
                                      ref.watch(superOfferVerifierProvider(effectiveUid)).when(
                                            skipLoadingOnRefresh: true,
                                            data: (SuperOfferSet superOffer) {
                                              if (superOffer.coins == 0 ||
                                                  superOffer.gemsRequired == 0) {
                                                return _buildNoTasksWidget();
                                              }

                                              final config = SplashService.superOfferConfig;
                                              final gameGemsVal =
                                                  (config['gameGems'] as num?)?.toInt() ?? 1;
                                              final installGemsVal =
                                                  (config['installGems'] as num?)?.toInt() ?? 5;
                                              final dailyGemsForInstallVal =
                                                  (config['dailyGemsForInstall'] as num?)
                                                          ?.toInt() ??
                                                      2;

                                              return SuperOfferWidget(
                                                coins: superOffer.coins,
                                                gems: liveGems,
                                                gemsRequired: superOffer.gemsRequired,
                                                adsRequired: superOffer.adsRequired,
                                                installTask: superOffer.installTask,
                                                superOfferVerificationEnabled: superOffer.superOfferVerificationEnabled,
                                                userId: effectiveUid,
                                                dailyGemsForInstall: dailyGemsForInstallVal,
                                                gameGems: gameGemsVal,
                                                installGems: installGemsVal,
                                                eligible: superOffer.eligible,
                                                lastClaimedAt: superOffer.lastClaimedAt,
                                                hoursGap: superOffer.hoursGap,
                                                gapMinutes: superOffer.gapMinutes,
                                                isUnlocked: superOffer.isUnlocked,
                                                limitType: superOffer.limitType,
                                              );
                                            },
                                            error: (_, __) => _buildNoTasksWidget(),
                                            loading: () => const SuperOfferShimmer(),
                                          ),

                                       if (pendingList.isNotEmpty) ...[
                                         SizedBox(height: 14.h),
                                         _buildPendingTasksCard(context, ref, pendingList),
                                       ],

                                      SizedBox(height: 24.h),

                                      // Play Games Section Header
                                      _buildPlayGamesHeader(),

                                      SizedBox(height: 10.h),

                                      // Play Games Card
                                      ref.watch(diamondCatchVerifierProvider(effectiveUid)).when(
                                            skipLoadingOnRefresh: true,
                                            data: (DiamondCatchSet diamondCatch) {
                                              return _buildTaskCard(
                                                context: context,
                                                iconPath: 'assets/Icons1/Crazy Racing.png',
                                                title: 'Crazy Racing',
                                                subtitle: '+${diamondCatch.gameGems} Gems',
                                                buttonText: _translate('play-now', 'Play Now'),
                                                onTap: () => AutoRouter.of(context).push(
                                                  DiamondCatchScreenRoute(
                                                    userId: effectiveUid,
                                                    gameGems: diamondCatch.gameGems,
                                                    installGems: diamondCatch.installGems,
                                                    dailyGemsForInstall:
                                                        diamondCatch.dailyGemsForInstall,
                                                    gemsRequired: 25,
                                                  ),
                                                ),
                                              );
                                            },
                                            error: (_, __) => _buildTaskCard(
                                              context: context,
                                              iconPath: 'assets/Icons1/Crazy Racing.png',
                                              title: 'Crazy Racing',
                                              subtitle: '+1 Gems',
                                              buttonText: _translate('play-now', 'Play Now'),
                                              onTap: () => AutoRouter.of(context).push(
                                                DiamondCatchScreenRoute(
                                                  userId: userId,
                                                  gameGems: 1,
                                                  installGems: 5,
                                                  dailyGemsForInstall: 2,
                                                  gemsRequired: 25,
                                                ),
                                              ),
                                            ),
                                            loading: () {
                                              final config = SplashService.superOfferConfig;
                                              final gameGems =
                                                  (config['gameGems'] as num?)?.toInt() ?? 1;
                                              return _buildTaskCard(
                                                context: context,
                                                iconPath: 'assets/Icons1/Crazy Racing.png',
                                                title: 'Crazy Racing',
                                                subtitle: '+$gameGems Gems',
                                                buttonText: _translate('play-now', 'Play Now'),
                                                onTap: () {},
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Native Ad at the bottom of Super Offer Screen
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                                    child: ToponNativeAdCard(
                                      isEnabled: AdKeys.isSuperOfferNativeEnabled,
                                      margin: EdgeInsets.only(top: 16.h),
                                    ),
                                  ),

                                  SizedBox(height: 60.h),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pure Dark Obsidian Floating Stats Cards
  Widget _buildStatsCard(BuildContext context, SuperOfferModel offerData, WidgetRef ref) {
    final userAsync = ref.watch(DashboardService.userDataProvider(userId));
    final liveStreak = userAsync.maybeWhen(
      data: (user) => user.streak,
      orElse: () => offerData.streak,
    );
    final liveStreakClaimed = userAsync.maybeWhen(
      data: (user) => user.streakClaimed,
      orElse: () => false,
    );

    return Row(
      children: [
        // 1. OFFERS COMPLETED CARD (Obsidian Black Gloss Card)
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showOffersCompletedInfo(context);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/Icons1/Rectangle 13.png'),
                  fit: BoxFit.fill,
                ),
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
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
                      color: const Color(0xFF202028),
                      borderRadius: BorderRadius.circular(11.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.all(7.r),
                    child: Image.asset(
                      'assets/icons/donee.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.task_alt_rounded,
                        color: Color(0xFFC084FC),
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
                          offerData.completedSuperOffers.toString(),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
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
                                _translate('completed', 'Completed'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF9E9EA7),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Icon(
                              Icons.info_outline_rounded,
                              color: const Color(0xFFC084FC).withValues(alpha: 0.8),
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

        SizedBox(width: 10.w),

        // 2. CURRENT STREAK CARD (Obsidian Black Gloss Card)
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              DailyCheckInPopup.show(
                context: context,
                streak: liveStreak,
                streakClaimed: liveStreakClaimed,
                userId: userId,
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 13.h),
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage('assets/Icons1/Rectangle 13.png'),
                  fit: BoxFit.fill,
                ),
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
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
                      color: const Color(0xFF202028),
                      borderRadius: BorderRadius.circular(11.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.all(6.r),
                    child: Image.asset(
                      'assets/icons/fire (2).png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/icons/ninja streak.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$liveStreak ${liveStreak == 1 ? "Day" : "Days"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16.5.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _translate('streak', 'Streak'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF9E9EA7),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 22.h,
                    height: 22.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Color(0xFFE5E7EB),
                          Color(0xFFB0B5C2),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: const Color(0xFF16161A),
                        size: 12.sp,
                      ),
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

  Widget _buildPendingTasksCard(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> pendingList,
  ) {
    final count = pendingList.length;
    if (count == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final first = pendingList.first;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuperOfferStep2ListScreen(
              userId: userId,
              coins: (first['coins'] as num?)?.toInt() ?? 0,
              packageName: first['packageName']?.toString(),
              appName: first['appName']?.toString() ?? 'Pending Offer App',
              installTimeText: first['installTimeText']?.toString() ?? 'Pending Proof',
            ),
          ),
        );
        ref.invalidate(pendingOffersProvider(userId));
        ref.invalidate(DashboardService.userDataProvider(userId));
        ref.invalidate(superOfferVerifierProvider(userId));
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/Icons1/Rectangle 13.png'),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: const Color(0xFF202028),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.pending_actions_rounded,
                color: const Color(0xFFF59E0B),
                size: 19.sp,
              ),
            ),
            SizedBox(width: 9.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Pending Offers',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF26262E),
                          borderRadius: BorderRadius.circular(7.r),
                          border: Border.all(
                            color: const Color(0xFF383842),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          count > 0 ? '$count' : '0',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF38BDF8),
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    count > 0
                        ? 'Tap to continue your offer'
                        : 'No pending offers',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9E9EA7),
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Colors.white,
                    Color(0xFFE5E7EB),
                    Color(0xFFB0B5C2),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(9.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Resume',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF16161A),
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: const Color(0xFF16161A),
                    size: 9.sp,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperMissionHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/Icons1/Rectangle 13.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left 3D Super Offer Icon (assets/Icons1/Super Offer .png)
          SizedBox(
            width: 85.w,
            height: 75.h,
            child: Image.asset(
              'assets/Icons1/bonus.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/Icons1/super_offer_3d.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // Right Title & Subtitle Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Super Missions!',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Complete verified offers to earn massive rewards!',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9E9EA7),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTasksWidget() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/Icons1/Rectangle 13.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_late_outlined,
            size: 40.sp,
            color: const Color(0xFF9E9EA7),
          ),
          SizedBox(height: 10.h),
          Text(
            _translate('no-tasks-available', 'No Task Available'),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _translate('check-back-later', 'Please check back later for new offers.'),
            style: GoogleFonts.poppins(
              color: const Color(0xFF9E9EA7),
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayGamesHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'Play Games',
            style: GoogleFonts.kaushanScript(
              color: const Color(0xFF26262B),
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required String iconPath,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        image: const DecorationImage(
          image: AssetImage('assets/Icons1/Rectangle 13.png'),
          fit: BoxFit.fill,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Row(
          children: [
            // Left 3D Game Icon Container (Home Screen Dark Container)
            SizedBox(
              width: 56.w,
              height: 56.w,
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFF38BDF8),
                  size: 28,
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Middle: Title + Reward Pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26262E),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: const Color(0xFF383842),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/gems.png',
                          width: 13.w,
                          height: 13.w,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF38BDF8),
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),

            // Right Silver Metallic Button
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFE5E7EB),
                      Color(0xFFB0B5C2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  buttonText,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF16161A),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardBannerCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SuperOfferLeaderboardScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(left: 2.w, right: 10.w, top: 4.h, bottom: 4.h),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/Icons1/Rectangle 13.png'),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 105.w,
              height: 100.h,
              child: Transform.scale(
                scale: 1.15,
                child: const FloatingPulseIcon(
                  child: Image(
                    image: AssetImage('assets/Icons1/output-onlinegiftools.gif'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: Offset(12.w, -6.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mega Prize!',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 13.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Unlock offers & win iPhone 16 Pro, Smart Watch & Gifts!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9E9EA7),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pure White Shimmer for Super Offer
class SuperOfferShimmer extends StatelessWidget {
  const SuperOfferShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86.h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                ShimmerTag(
                  type: ShimmerType.pulse,
                  baseColor: const Color(0xFFF1F5F9),
                  highlightColor: const Color(0xFFE2E8F0),
                  child: Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerTag(
                        type: ShimmerType.pulse,
                        baseColor: const Color(0xFFF1F5F9),
                        highlightColor: const Color(0xFFE2E8F0),
                        child: Container(
                          width: 75.w,
                          height: 11.h,
                          decoration: BorderRadius.circular(4.r).toBoxDecoration(),
                        ),
                      ),
                      SizedBox(height: 5.h),
                      ShimmerTag(
                        type: ShimmerType.pulse,
                        baseColor: const Color(0xFFF1F5F9),
                        highlightColor: const Color(0xFFE2E8F0),
                        child: Container(
                          width: 55.w,
                          height: 18.h,
                          decoration: BorderRadius.circular(6.r).toBoxDecoration(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
         ],
      ),
    );
  }
}

extension BoxDecoExt on BorderRadius {
  BoxDecoration toBoxDecoration() => BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: this);
}

// AVAILABLE GEMS BADGE (MATCHING HOME SCREEN OBSIDIAN & CYAN CAPSULE)
class _AvailableGemsBadge extends StatelessWidget {
  final int gems;

  const _AvailableGemsBadge({required this.gems});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36.h,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
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
          SizedBox(width: 5.w),
          Text(
            gems.toString(),
            style: GoogleFonts.poppins(
              color: const Color(0xFF38BDF8),
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingPulseIcon extends StatefulWidget {
  final Widget child;
  const FloatingPulseIcon({Key? key, required this.child}) : super(key: key);

  @override
  State<FloatingPulseIcon> createState() => _FloatingPulseIconState();
}

class _FloatingPulseIconState extends State<FloatingPulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translation;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _translation = Tween<double>(begin: 0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translation.value),
          child: Transform.scale(
            scale: _scale.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}

