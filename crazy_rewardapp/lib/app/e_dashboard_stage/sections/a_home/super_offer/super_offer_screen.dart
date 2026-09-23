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
import '../diamond_catch/diamond_catch_model.dart';
import 'super_offer_provider.dart';
import '../diamond_catch/diamond_catch_provider.dart';
import 'super_offer_widget.dart';
import 'super_offer_step2_list_screen.dart';
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
          borderRadius: BorderRadius.circular(20.r),
          side: const BorderSide(
            color: Color(0xFFE2E8F0),
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
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF26262B),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.task_alt_rounded,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Offers Completed',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 17.sp,
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
                  fontSize: 12.5.sp,
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
                    color: const Color(0xFF26262B),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'GOT IT',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13.5.sp,
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
            // 1. Solid White Background
            Positioned.fill(
              child: Container(
                color: Colors.white,
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
                        color: const Color(0xFF26262B),
                        backgroundColor: Colors.white,
                        onRefresh: () async {
                          ref.invalidate(DashboardService.userDataProvider(effectiveUid));
                          ref.invalidate(superOfferVerifierProvider(effectiveUid));
                          ref.invalidate(diamondCatchVerifierProvider(effectiveUid));
                          ref.invalidate(pendingOffersProvider(effectiveUid));
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
                                      // Top Header Bar (Back button, "Super Offer" Kaushan Header, Gems counter)
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
                                                borderRadius: BorderRadius.circular(14.r),
                                                border: Border.all(
                                                  color: const Color(0xFFE2E8F0),
                                                  width: 1.2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.04),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.arrow_back_rounded,
                                                color: const Color(0xFF26262B),
                                                size: 20.sp,
                                              ),
                                            ),
                                          ),

                                          // Center Title: "Super Offer" (Exact Home Screen Style)
                                          Text(
                                            'Super Offer',
                                            style: GoogleFonts.kaushanScript(
                                              color: const Color(0xFF26262B),
                                              fontSize: 28.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),

                                          // Right Gems Pill
                                          _AvailableGemsBadge(gems: liveGems),
                                        ],
                                      ),

                                      SizedBox(height: 12.h),

                                      // Screen Banner (Admin Configurable 700x200 with AD badge) placed at the TOP!
                                      const ScreenBannerWidget(
                                        screenKey: 'superOfferScreen',
                                        margin: EdgeInsets.only(bottom: 12),
                                      ),

                                      // Super Mission Hero Card
                                      _buildSuperMissionHeader(),

                                      SizedBox(height: 14.h),

                                      // Stats Card (Offers Completed | Current Streak)
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
                                                iconPath: 'assets/icons/playtimegame.png',
                                                title: 'Diamond Catch',
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
                                              iconPath: 'assets/icons/playtimegame.png',
                                              title: 'Diamond Catch',
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
                                                iconPath: 'assets/icons/playtimegame.png',
                                                title: 'Diamond Catch',
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

  // Home Style Luxury Floating Stats Cards
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
        // 1. OFFERS COMPLETED CARD
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showOffersCompletedInfo(context);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF26262B),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.all(8.r),
                    child: Image.asset(
                      'assets/icons/donee.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.task_alt_rounded,
                        color: Colors.white,
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
                            color: const Color(0xFF1E1B4B),
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
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
                                  color: const Color(0xFF64748B),
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Icon(
                              Icons.info_outline_rounded,
                              color: const Color(0xFF64748B),
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

        // 2. CURRENT STREAK CARD
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
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFFFFEDD5),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.all(6.5.r),
                    child: Image.asset(
                      'assets/icons/fire (2).png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFF5722),
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
                          '$liveStreak ${liveStreak == 1 ? "Day" : "Days"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _translate('streak', 'Streak'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 22.w,
                    height: 22.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: const Color(0xFF26262B),
                        size: 9.sp,
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: count > 0 ? const Color(0xFF26262B) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: const Color(0xFF26262B),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.pending_actions_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Pending Offers',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 14.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: count > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          count > 0 ? '$count Pending' : '0 Offers',
                          style: GoogleFonts.poppins(
                            color: count > 0 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    count > 0
                        ? 'Tap to continue your offer steps and earn rewards'
                        : 'No pending offers. Complete offers to see them here',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF64748B),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFF94A3B8),
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperMissionHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 14.w, 14.h),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/Icons1/Rectangle 13.png'),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      Icon(
                        Icons.bolt_rounded,
                        color: const Color(0xFFFBBF24),
                        size: 12.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'SUPER MISSION',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Unlock High Rewards',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Complete offers to earn big coins instantly',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF9E9EA7),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Image.asset(
            'assets/Icons1/super_offer_3d.png',
            width: 72.w,
            height: 72.w,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/icons/suprerofferdhn.png',
              width: 68.w,
              height: 68.w,
              fit: BoxFit.contain,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_late_outlined,
              size: 26.sp,
              color: const Color(0xFF26262B),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            _translate('no-tasks-available', 'No Task Available'),
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E1B4B),
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _translate('check-back-later', 'Please check back later for new offers.'),
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 11.5.sp,
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
              color: const Color(0xFF26262B),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'Play Games',
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E1B4B),
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        child: Row(
          children: [
            // Left Game Icon Container
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.all(7.w),
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFF26262B),
                  size: 26,
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
                      color: const Color(0xFF1E1B4B),
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
                          width: 12.w,
                          height: 12.w,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 8.w),

            // Right Silver Metallic Play Button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
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
                  border: Border.all(
                    color: const Color(0xFF9CA3AF),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: const Color(0xFF16161A),
                      size: 16.sp,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      buttonText,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF16161A),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
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

// Clean Shimmer for Super Offer
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
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
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

// AVAILABLE GEMS BADGE (HOME STYLE COIN BADGE DESIGN)
class _AvailableGemsBadge extends StatelessWidget {
  final int gems;

  const _AvailableGemsBadge({required this.gems});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFF26262E),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFF383842),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
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
            width: 16.w,
            height: 16.w,
            fit: BoxFit.contain,
          ),
          SizedBox(width: 5.w),
          Text(
            gems.toString(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

