import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../widgets/common/internet_image.dart';
import '../../../../widgets/common/screen_banner_widget.dart';
import '../../../../widgets/common/shimmer_tag.dart';
import '../../../b_splash_stage/splash_service.dart';
import '../../provider/dashboard_provider.dart';
import 'leaderboard_model.dart';
import 'leaderboard_provider.dart';

class LeaderboardBody extends HookConsumerWidget {
  const LeaderboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 0: Top Earners (coinsBased), 1: Top Referrals (referralBased)
    final selectedTab = useState<int>(0);
    final coinsBased = ref.watch(leaderboardDataProvider('coinsBased'));
    final referralBased = ref.watch(leaderboardDataProvider('referralBased'));
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final isCoinsTab = selectedTab.value == 0;
    final activeDataAsync = isCoinsTab ? coinsBased : referralBased;

    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserName = currentUser?.displayName?.isNotEmpty == true
        ? currentUser!.displayName!
        : (currentUser?.email?.isNotEmpty == true
            ? currentUser!.email!.split('@')[0]
            : 'You');
    final currentUserPhoto = currentUser?.photoURL ?? '';

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
            // 1. Solid Clean White Base Background
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: RefreshIndicator(
                color: const Color(0xFFAB31DE),
                backgroundColor: Colors.white,
                edgeOffset: topPadding + 60.h,
                onRefresh: () async {
                  ref.invalidate(leaderboardDataProvider('referralBased'));
                  ref.invalidate(leaderboardDataProvider('coinsBased'));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    topPadding + 14.h,
                    16.w,
                    bottomPadding + 110.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Navigation Header: Back Button + Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        ],
                      ),

                      SizedBox(height: 12.h),

                      // Top Graphic Hero Banner (3D Trophy + Title)
                      _buildTopHeroBanner(),

                      const ScreenBannerWidget(
                        screenKey: 'leaderboardScreen',
                        margin: EdgeInsets.only(top: 14.0, bottom: 2.0),
                      ),

                      SizedBox(height: 14.h),

                      // Segmented Tab Switcher (Top Referrals vs Top Earners)
                      _buildSegmentedTabBar(
                        selectedTab: selectedTab.value,
                        onTabChanged: (val) {
                          selectedTab.value = val;
                        },
                      ),

                      SizedBox(height: 20.h),

                      // Active Leaderboard Data
                      activeDataAsync.when(
                        loading: () => const _LeaderboardShimmer(),
                        error: (_, __) => _buildErrorState(ref),
                        data: (data) {
                          final topThree = data.take(3).toList();
                          final remaining = data.length > 3 ? data.sublist(3) : <LeaderboardModel>[];

                          return Column(
                            children: [
                              // Top 3 Winners Podium
                              _buildTopThreePodium(topThree, !isCoinsTab),

                              SizedBox(height: 14.h),

                              // Countdown Timer Pill ("11:59:59")
                              _buildTimerRow(),

                              SizedBox(height: 20.h),

                              // Leaderboard Table Header
                              _buildTableHeader(),

                              SizedBox(height: 8.h),

                              // Ranks 4 to 100 List
                              if (remaining.isNotEmpty)
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: remaining.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    color: Color(0xFFF1F5F9),
                                    height: 1,
                                    thickness: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final rank = index + 4;
                                    final item = remaining[index];
                                    return _buildRankListItem(rank, item, !isCoinsTab);
                                  },
                                )
                              else
                                _buildEmptyState(!isCoinsTab),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Fixed Bottom "You" Rank Sticky Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: activeDataAsync.maybeWhen(
                data: (data) {
                  int userRank = 0;
                  int userScore = 0;
                  final currentUid = currentUser?.uid ?? '';
                  if (data.isNotEmpty) {
                    final idx = data.indexWhere((m) =>
                        (currentUid.isNotEmpty && m.userId == currentUid) ||
                        (currentUserName.isNotEmpty &&
                            m.name.toLowerCase() == currentUserName.toLowerCase()));
                    if (idx != -1) {
                      userRank = idx + 1;
                      userScore = isCoinsTab
                          ? data[idx].totalCoins.toInt()
                          : data[idx].totalReferrals;
                    }
                  }

                  if (userRank == 0 && currentUid.isNotEmpty) {
                    final userModel = ref.watch(DashboardService.userDataProvider(currentUid)).value;
                    if (userModel != null) {
                      userScore = isCoinsTab ? userModel.coins.toInt() : 0;
                    }
                  }

                  return _buildUserStickyRankBar(
                    context: context,
                    userRank: userRank,
                    userName: currentUserName,
                    photoUrl: currentUserPhoto,
                    score: userScore,
                    isReferralTab: !isCoinsTab,
                    bottomPadding: bottomPadding,
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TOP GRAPHIC HERO BANNER (3D TROPHY + TITLE)
  // -------------------------------------------------------------
  Widget _buildTopHeroBanner() {
    return Column(
      children: [
        // Trophy Illustration Box
        SizedBox(
          height: 90.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Purple Wreath & Laurel Background Glow
              Container(
                width: 140.w,
                height: 70.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE39FFF).withValues(alpha: 0.20),
                ),
              ),
              // Golden 3D Trophy Image / Icon
              Image.asset(
                'assets/icons/leader.png',
                height: 100.h,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.emoji_events_rounded,
                  color: const Color(0xFFFFB800),
                  size: 70.sp,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 6.h),

        // Big Leaderboard Title
        Text(
          'Leaderboard',
          style: GoogleFonts.outfit(
            color: const Color(0xFF1E1B4B),
            fontSize: 26.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),

        SizedBox(height: 2.h),

        // Tagline Subtitle
        Text(
          'Compete. Earn. Win Big!',
          style: GoogleFonts.outfit(
            color: const Color(0xFF64748B),
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SEGMENTED TAB SWITCHER
  // -------------------------------------------------------------
  Widget _buildSegmentedTabBar({
    required int selectedTab,
    required ValueChanged<int> onTabChanged,
  }) {
    return Container(
      height: 48.h,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(
            label: 'Top Earners',
            iconWidget: Image.asset(
              'assets/icons/coin.png',
              width: 17.w,
              height: 17.w,
              fit: BoxFit.contain,
            ),
            tabIndex: 0,
            selectedTab: selectedTab,
            onTap: () => onTabChanged(0),
          ),
          _buildTabItem(
            label: 'Top Referrals',
            iconWidget: (isSelected) => Icon(
              Icons.people_alt_rounded,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              size: 17.sp,
            ),
            tabIndex: 1,
            selectedTab: selectedTab,
            onTap: () => onTabChanged(1),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required dynamic iconWidget,
    required int tabIndex,
    required int selectedTab,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedTab == tabIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFFE39FFF),
                      Color(0xFFAB31DE),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconWidget is Function)
                iconWidget(isSelected)
              else
                iconWidget as Widget,
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 13.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // COUNTDOWN TIMER PILL ROW ("⏱️ 11:59:59")
  // -------------------------------------------------------------
  Widget _buildTimerRow() {
    return HookBuilder(
      builder: (context) {
        final targetMs = SplashService.serverTime.leaderboardTimeLeft;
        final timeLeftMillis = useState<int>(
          (targetMs - DateTime.now().millisecondsSinceEpoch).clamp(0, double.infinity).toInt(),
        );

        useEffect(() {
          final timer = Timer.periodic(const Duration(seconds: 1), (_) {
            final remaining = targetMs - DateTime.now().millisecondsSinceEpoch;
            timeLeftMillis.value = remaining.clamp(0, double.infinity).toInt();
          });
          return timer.cancel;
        }, [targetMs]);

        final duration = Duration(milliseconds: timeLeftMillis.value);
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        final seconds = duration.inSeconds.remainder(60);

        final timerString =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(100.r),
            border: Border.all(
              color: const Color(0xFFF3E8FF),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                color: const Color(0xFFAB31DE),
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                timerString,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TOP 3 WINNERS PODIUM (MATCHING UPLOADED REFERENCE DESIGN 1-TO-1)
  // -------------------------------------------------------------
  Widget _buildTopThreePodium(List<LeaderboardModel> topThree, bool isReferralTab) {
    final rank1 = topThree.isNotEmpty ? topThree[0] : null;
    final rank2 = topThree.length > 1 ? topThree[1] : null;
    final rank3 = topThree.length > 2 ? topThree[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rank 2 (Left)
        Expanded(
          child: rank2 != null
              ? _buildPodiumCard(
                  rank: 2,
                  user: rank2,
                  avatarSize: 58.w,
                  ringColor: const Color(0xFF94A3B8),
                  badgeColor: const Color(0xFF94A3B8),
                  isReferralTab: isReferralTab,
                  isCenter: false,
                )
              : const SizedBox.shrink(),
        ),

        SizedBox(width: 8.w),

        // Rank 1 (Center - Elevated & Golden Crown on Top)
        Expanded(
          child: rank1 != null
              ? _buildPodiumCard(
                  rank: 1,
                  user: rank1,
                  avatarSize: 66.w,
                  ringColor: const Color(0xFFFFB800),
                  badgeColor: const Color(0xFFFFB800),
                  isReferralTab: isReferralTab,
                  isCenter: true,
                )
              : const SizedBox.shrink(),
        ),

        SizedBox(width: 8.w),

        // Rank 3 (Right)
        Expanded(
          child: rank3 != null
              ? _buildPodiumCard(
                  rank: 3,
                  user: rank3,
                  avatarSize: 58.w,
                  ringColor: const Color(0xFFD97706),
                  badgeColor: const Color(0xFFD97706),
                  isReferralTab: isReferralTab,
                  isCenter: false,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildPodiumCard({
    required int rank,
    required LeaderboardModel user,
    required double avatarSize,
    required Color ringColor,
    required Color badgeColor,
    required bool isReferralTab,
    required bool isCenter,
  }) {
    final scoreStr = isReferralTab
        ? '${user.totalReferrals}'
        : '${user.totalCoins.toInt()}';

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Golden Crown for Rank 1 (Matching snippet 1-to-1)
        if (isCenter)
          Positioned(
            top: -18.h,
            child: SizedBox(
              width: 32.w,
              height: 20.h,
              child: const CustomPaint(
                painter: _GoldenCrownPainter(),
              ),
            ),
          ),

        // Outer 3D Pink/Purple Base Container (Matching Demo Image 1-to-1)
        Container(
          margin: EdgeInsets.only(top: isCenter ? 10.h : 20.h),
          padding: EdgeInsets.only(bottom: 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFFC88BE2),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFAB31DE).withValues(alpha: isCenter ? 0.15 : 0.08),
                blurRadius: isCenter ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(8.w, 12.h, 8.w, 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: isCenter ? 4.h : 0),

                // Avatar Circle with Ring & Overlapping Hexagon Badge
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ringColor,
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ringColor.withValues(alpha: 0.40),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: InternetImage(
                          url: user.photoUrl,
                          height: avatarSize,
                          width: avatarSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    // Overlapping Vertical Hexagon Badge (Matching close-up snippet 1-to-1)
                    Positioned(
                      bottom: -11.h,
                      child: _HexagonBadge(
                        rank: rank,
                        fillColor: rank == 1
                            ? const Color(0xFFFFEA00)
                            : (rank == 2 ? const Color(0xFF94A3B8) : const Color(0xFFD97706)),
                        borderColor: rank == 1
                            ? const Color(0xFFFFF59D)
                            : (rank == 2 ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A)),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // User Name
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: isCenter ? 13.5.sp : 12.sp,
                    fontWeight: isCenter ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),

                SizedBox(height: 3.h),

                // Score Count (Referrals / Coins)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isReferralTab) ...[
                      Icon(
                        Icons.people_alt_rounded,
                        color: const Color(0xFFAB31DE),
                        size: 13.sp,
                      ),
                      SizedBox(width: 4.w),
                    ] else ...[
                      Image.asset(
                        'assets/icons/coin.png',
                        width: 13.w,
                        height: 13.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Text(
                      scoreStr,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TABLE HEADER ROW (Rank | User | Reward)
  // -------------------------------------------------------------
  Widget _buildTableHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: Row(
        children: [
          SizedBox(
            width: 44.w,
            child: Text(
              'Rank',
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'User',
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Reward',
            style: GoogleFonts.outfit(
              color: const Color(0xFFAB31DE),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // RANK LIST ITEM (RANKS 4 TO 100)
  // -------------------------------------------------------------
  Widget _buildRankListItem(int rank, LeaderboardModel item, bool isReferralTab) {
    int rewardCoins = 0;
    if (rank == 4) {
      rewardCoins = 100;
    } else if (rank == 5) {
      rewardCoins = 80;
    } else if (rank == 6) {
      rewardCoins = 60;
    } else if (rank == 7) {
      rewardCoins = 40;
    } else if (rank == 8) {
      rewardCoins = 20;
    } else if (rank == 9) {
      rewardCoins = 10;
    } else {
      rewardCoins = 0;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      child: Row(
        children: [
          // Rank Badge Pill Circle
          Container(
            width: 26.w,
            height: 26.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFAF5FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: GoogleFonts.outfit(
                color: const Color(0xFFAB31DE),
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          SizedBox(width: 14.w),

          // User Avatar
          Container(
            width: 32.w,
            height: 32.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF1F5F9),
            ),
            child: ClipOval(
              child: InternetImage(
                url: item.photoUrl,
                width: 32.w,
                height: 32.w,
                fit: BoxFit.cover,
              ),
            ),
          ),

          SizedBox(width: 10.w),

          // User Name
          Expanded(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E1B4B),
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Reward Coins Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/coin.png',
                width: 14.w,
                height: 14.w,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 4.w),
              Text(
                '$rewardCoins',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // FIXED BOTTOM "YOU" RANK STICKY BAR
  // -------------------------------------------------------------
  Widget _buildUserStickyRankBar({
    required BuildContext context,
    required int userRank,
    required String userName,
    required String photoUrl,
    required int score,
    required bool isReferralTab,
    required double bottomPadding,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        16.w,
        0,
        16.w,
        bottomPadding > 0 ? bottomPadding + 8.h : 14.h,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: const Color(0xFFE9D5FF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // User Rank Pill Number
          Text(
            userRank > 0 ? '$userRank' : '-',
            style: GoogleFonts.outfit(
              color: const Color(0xFFAB31DE),
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
            ),
          ),

          SizedBox(width: 14.w),

          // User Avatar
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFAB31DE),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: InternetImage(
                url: photoUrl,
                width: 36.w,
                height: 36.w,
                fit: BoxFit.cover,
              ),
            ),
          ),

          SizedBox(width: 10.w),

          // "You" Title + Encouragement Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFAB31DE),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  "Keep going, You're doing great!",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // User Score + Reward
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFAB31DE),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/coin.png',
                    width: 13.w,
                    height: 13.w,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    '0',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isReferralTab) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            color: const Color(0xFF94A3B8),
            size: 48.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'No Leaderboard Data Yet',
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: const Color(0xFFEF4444),
            size: 44.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'Failed to load leaderboard',
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// SHIMMER SKELETON
// -------------------------------------------------------------
class _LeaderboardShimmer extends StatelessWidget {
  const _LeaderboardShimmer();

  static const Color _shimmerBase = Color(0xFFF8FAFC);
  static const Color _shimmerHighlight = Color(0xFFF1F5F9);

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double borderRadius = 12.0,
  }) {
    return ShimmerTag(
      type: ShimmerType.pulse,
      baseColor: _shimmerBase,
      highlightColor: _shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSkeletonBox(width: 95.w, height: 130.h, borderRadius: 20.r),
            SizedBox(width: 10.w),
            _buildSkeletonBox(width: 110.w, height: 150.h, borderRadius: 22.r),
            SizedBox(width: 10.w),
            _buildSkeletonBox(width: 95.w, height: 130.h, borderRadius: 20.r),
          ],
        ),
        SizedBox(height: 20.h),
        for (int i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(height: 10.h),
          _buildSkeletonBox(width: double.infinity, height: 50.h, borderRadius: 14.r),
        ],
      ],
    );
  }
}

// -------------------------------------------------------------
// GOLDEN CROWN PAINTER (MATCHING SNIPPET 1-TO-1)
// -------------------------------------------------------------
class _GoldenCrownPainter extends CustomPainter {
  const _GoldenCrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE066), Color(0xFFFFB800), Color(0xFFD97706)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.45);
    path.lineTo(size.width * 0.2, size.height);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(size.width, size.height * 0.45);
    path.lineTo(size.width * 0.72, size.height * 0.65);
    path.lineTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.28, size.height * 0.65);
    path.close();

    canvas.drawPath(path, paint);

    final ballPaint = Paint()
      ..color = const Color(0xFFFFE066)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, 0), 2.5, ballPaint);
    canvas.drawCircle(Offset(0, size.height * 0.45), 2.0, ballPaint);
    canvas.drawCircle(Offset(size.width, size.height * 0.45), 2.0, ballPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// HEXAGON BADGE WIDGET & PAINTER (MATCHING CLOSE-UP SNIPPET 1-TO-1)
// -------------------------------------------------------------
class _HexagonBadge extends StatelessWidget {
  final int rank;
  final Color fillColor;
  final Color borderColor;

  const _HexagonBadge({
    required this.rank,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20.w,
      height: 22.h,
      child: CustomPaint(
        painter: _HexagonPainter(
          fillColor: fillColor,
          borderColor: borderColor,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 1.h),
            child: Text(
              '$rank',
              style: GoogleFonts.outfit(
                color: rank == 1 ? const Color(0xFF1B0B3B) : Colors.white,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  const _HexagonPainter({
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.3), 3, false);
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor || oldDelegate.borderColor != borderColor;
}
