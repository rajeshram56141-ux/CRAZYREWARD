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
        systemNavigationBarColor: Color(0xFFF1F5F9),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Stack(
          children: [
            // 1. Ambient Pastel Glow Blobs (Matching Auth Screen 1-to-1)
            Positioned(
              top: -60.h,
              right: -40.w,
              child: Container(
                width: 220.w,
                height: 220.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF9333EA).withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              bottom: 60.h,
              left: -50.w,
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.07),
                ),
              ),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: RefreshIndicator(
                color: const Color(0xFF7C3AED),
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
                    0,
                    topPadding + 10.h,
                    0,
                    bottomPadding + 110.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Top Navigation Header: Back Button & Title
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
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

                            Text(
                              'Leaderboard',
                              style: GoogleFonts.kaushanScript(
                                color: const Color(0xFF26262B),
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),

                            SizedBox(width: 40.w),
                          ],
                        ),
                      ),

                      const ScreenBannerWidget(
                        screenKey: 'leaderboardScreen',
                        margin: EdgeInsets.only(top: 14.0, bottom: 2.0),
                      ),

                      SizedBox(height: 12.h),

                      // Horizontal Filter Switcher Pills (Auth Inspired Styling)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: _buildFilterPills(
                          selectedTab: selectedTab.value,
                          onTabChanged: (val) {
                            selectedTab.value = val;
                          },
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // Active Leaderboard Data
                      activeDataAsync.when(
                        loading: () => const _LeaderboardShimmer(),
                        error: (_, __) => _buildErrorState(ref),
                        data: (data) {
                          if (isCoinsTab) {
                            final topThree = data.take(3).toList();
                            final remaining = data.length > 3
                                ? data.sublist(3)
                                : <LeaderboardModel>[];

                            return Column(
                              children: [
                                // Top 3 Winners 3D Block Podium
                                _buildTopThree3DPodium(topThree, false),

                                SizedBox(height: 20.h),

                                // Ranks 4 to 100 Elevated White Bottom Container Card
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(28.r),
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                        blurRadius: 20,
                                        offset: const Offset(0, -4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Top Handle Line
                                      Container(
                                        width: 36.w,
                                        height: 4.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCBD5E1),
                                          borderRadius: BorderRadius.circular(2.r),
                                        ),
                                      ),

                                      SizedBox(height: 12.h),

                                      // Timer Row Pill
                                      _buildTimerRow(),

                                      SizedBox(height: 14.h),

                                      // Ranks List Cards (4 to 100)
                                      if (remaining.isNotEmpty)
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          itemCount: remaining.length,
                                          separatorBuilder: (_, __) => SizedBox(height: 10.h),
                                          itemBuilder: (context, index) {
                                            final rank = index + 4;
                                            final item = remaining[index];
                                            return _buildRankCardItem(
                                              rank: rank,
                                              item: item,
                                              isReferralTab: false,
                                            );
                                          },
                                        )
                                      else
                                        _buildEmptyState(false),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // Top Referrals Tab List
                            final topThree = data.take(3).toList();
                            final remaining = data.length > 3
                                ? data.sublist(3)
                                : <LeaderboardModel>[];

                            return Column(
                              children: [
                                // Top 3 Winners 3D Block Podium for Referrals
                                _buildTopThree3DPodium(topThree, true),

                                SizedBox(height: 20.h),

                                // Ranks 4 to 100 Elevated White Bottom Container Card
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(28.r),
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                        blurRadius: 20,
                                        offset: const Offset(0, -4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Top Handle Line
                                      Container(
                                        width: 36.w,
                                        height: 4.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCBD5E1),
                                          borderRadius: BorderRadius.circular(2.r),
                                        ),
                                      ),

                                      SizedBox(height: 12.h),

                                      _buildTimerRow(),

                                      SizedBox(height: 14.h),

                                      if (remaining.isNotEmpty)
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: EdgeInsets.zero,
                                          itemCount: remaining.length,
                                          separatorBuilder: (_, __) => SizedBox(height: 10.h),
                                          itemBuilder: (context, index) {
                                            final rank = index + 4;
                                            final item = remaining[index];
                                            return _buildRankCardItem(
                                              rank: rank,
                                              item: item,
                                              isReferralTab: true,
                                            );
                                          },
                                        )
                                      else
                                        _buildEmptyState(true),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Fixed Bottom "You" Rank Sticky Bar (Shown only if user rank is 4 or lower)
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
                            m.name.toLowerCase() ==
                                currentUserName.toLowerCase()));
                    if (idx != -1) {
                      userRank = idx + 1;
                      userScore = isCoinsTab
                          ? data[idx].totalCoins.toInt()
                          : data[idx].totalReferrals;
                    }
                  }

                  if (userRank == 0 && currentUid.isNotEmpty) {
                    final userModel = ref
                        .watch(DashboardService.userDataProvider(currentUid))
                        .value;
                    if (userModel != null) {
                      userScore = isCoinsTab ? userModel.coins.toInt() : 0;
                    }
                  }

                  // If user is already in Top 3 podium or not on leaderboard, hide sticky bar
                  if (userRank == 0 || userRank <= 3) {
                    return const SizedBox.shrink();
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
  // HORIZONTAL FILTER PILLS (Matching Auth Screen Style)
  // -------------------------------------------------------------
  Widget _buildFilterPills({
    required int selectedTab,
    required ValueChanged<int> onTabChanged,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildPillItem(
            label: 'Top Earners',
            isSelected: selectedTab == 0,
            onTap: () => onTabChanged(0),
          ),
          SizedBox(width: 8.w),
          _buildPillItem(
            label: 'Top Referrals',
            isSelected: selectedTab == 1,
            onTap: () => onTabChanged(1),
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C3AED)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 13.5.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
          (targetMs - DateTime.now().millisecondsSinceEpoch)
              .clamp(0, double.infinity)
              .toInt(),
        );

        useEffect(() {
          final timer = Timer.periodic(const Duration(seconds: 1), (_) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final remaining = (targetMs - nowMs).clamp(0, double.infinity).toInt();
            timeLeftMillis.value = remaining;
          });
          return timer.cancel;
        }, [targetMs]);

        final secondsTotal = (timeLeftMillis.value / 1000).floor();
        final hours = (secondsTotal / 3600).floor();
        final minutes = ((secondsTotal % 3600) / 60).floor();
        final seconds = secondsTotal % 60;

        final timerString =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(100.r),
            border: Border.all(
              color: const Color(0xFFD8B4FE),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                color: const Color(0xFF7C3AED),
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                timerString,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF7C3AED),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
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
  // TOP 3 WINNERS 3D BLOCK PODIUM
  // -------------------------------------------------------------
  Widget _buildTopThree3DPodium(
      List<LeaderboardModel> topThree, bool isReferralTab) {
    final rank1 = topThree.isNotEmpty ? topThree[0] : null;
    final rank2 = topThree.length > 1 ? topThree[1] : null;
    final rank3 = topThree.length > 2 ? topThree[2] : null;

    return Padding(
      padding: EdgeInsets.only(top: 10.h, left: 16.w, right: 16.w),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // 3D Blocks Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rank 2 (Left 3D Block)
              _buildSinglePodiumColumn(
                rank: 2,
                user: rank2,
                blockWidth: 94.w,
                blockHeight: 90.h,
                isReferralTab: isReferralTab,
                blockColor: const Color(0xFF7A7A8A),
                topFaceColor: const Color(0xFFA2A2B2),
              ),

              SizedBox(width: 6.w),

              // Rank 1 (Center Elevated 3D Block)
              _buildSinglePodiumColumn(
                rank: 1,
                user: rank1,
                blockWidth: 108.w,
                blockHeight: 120.h,
                isReferralTab: isReferralTab,
                blockColor: const Color(0xFF9090A0),
                topFaceColor: const Color(0xFFBDBDCF),
              ),

              SizedBox(width: 6.w),

              // Rank 3 (Right 3D Block)
              _buildSinglePodiumColumn(
                rank: 3,
                user: rank3,
                blockWidth: 94.w,
                blockHeight: 70.h,
                isReferralTab: isReferralTab,
                blockColor: const Color(0xFF666675),
                topFaceColor: const Color(0xFF8B8B9B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePodiumColumn({
    required int rank,
    required LeaderboardModel? user,
    required double blockWidth,
    required double blockHeight,
    required bool isReferralTab,
    required Color blockColor,
    required Color topFaceColor,
  }) {
    Color badgeColor;
    Color nameColor;

    if (rank == 1) {
      badgeColor = const Color(0xFFEAB308);
      nameColor = const Color(0xFFDC2626);
    } else if (rank == 2) {
      badgeColor = const Color(0xFF64748B);
      nameColor = const Color(0xFF26262B);
    } else {
      badgeColor = const Color(0xFFD97706);
      nameColor = const Color(0xFF26262B);
    }

    final scoreStr = user != null
        ? (isReferralTab
            ? '${user.totalReferrals}'
            : '${user.totalCoins.toInt()}')
        : '0';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top User Section (Avatar + Rank Badge + Name + Score)
        if (user != null) ...[
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Circular Avatar Container
              Container(
                width: rank == 1 ? 52.w : 44.w,
                height: rank == 1 ? 52.w : 44.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badgeColor,
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: InternetImage(
                    url: user.photoUrl,
                    width: rank == 1 ? 52.w : 44.w,
                    height: rank == 1 ? 52.w : 44.w,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Top-Right Rank Badge Number Circle
              Positioned(
                top: -3.h,
                right: -3.w,
                child: Container(
                  width: 18.w,
                  height: 18.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '$rank',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 4.h),

          // User Name
          SizedBox(
            width: blockWidth + 8.w,
            child: Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: nameColor,
                fontSize: rank == 1 ? 13.sp : 11.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          SizedBox(height: 1.h),

          // Score Badge Row (Star + Score)
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: const Color(0xFF7C3AED),
                size: 11.sp,
              ),
              SizedBox(width: 3.w),
              Text(
                scoreStr,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF7C3AED),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          SizedBox(height: 6.h),
        ],

        // 3D Block Geometry Stand
        Container(
          width: blockWidth,
          height: blockHeight,
          decoration: BoxDecoration(
            color: blockColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(8.r),
            ),
            gradient: LinearGradient(
              colors: [
                topFaceColor,
                blockColor,
                blockColor.withValues(alpha: 0.85),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: rank == 1 ? 52.sp : (rank == 2 ? 44.sp : 38.sp),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // RANK LIST CARD ITEM (Ranks 4-100)
  // -------------------------------------------------------------
  Widget _buildRankCardItem({
    required int rank,
    required LeaderboardModel item,
    required bool isReferralTab,
  }) {
    int rewardCoins = 0;
    if (!isReferralTab) {
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
    }

    final scoreDisplay = isReferralTab
        ? '${item.totalReferrals}'
        : (rewardCoins > 0 ? '$rewardCoins' : '${item.totalCoins.toInt()}');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Large Stylized Rank Number (Matching reference screenshot)
          SizedBox(
            width: 42.w,
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                color: const Color(0xFFCBD5E1),
                fontSize: 34.sp,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),

          SizedBox(width: 8.w),

          // User Avatar
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: ClipOval(
              child: InternetImage(
                url: item.photoUrl,
                width: 44.w,
                height: 44.w,
                fit: BoxFit.cover,
              ),
            ),
          ),

          SizedBox(width: 12.w),

          // User Name + Score Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: const Color(0xFF7C3AED),
                      size: 13.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      scoreDisplay,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF7C3AED),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFF7C3AED),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9333EA).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // User Rank Number
          Text(
            userRank > 0 ? '$userRank' : '-',
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
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
                color: const Color(0xFF7C3AED),
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

          // "You" Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Keep going, You're doing great!",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF7C3AED),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // User Score + Metric Icon
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF26262B),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: const Color(0xFF7C3AED),
                    size: 13.sp,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    isReferralTab ? 'Ref' : 'Coins',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF7C3AED),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
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
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
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
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
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
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildSkeletonBox(width: 90.w, height: 90.h, borderRadius: 12.r),
            SizedBox(width: 10.w),
            _buildSkeletonBox(width: 104.w, height: 120.h, borderRadius: 12.r),
            SizedBox(width: 10.w),
            _buildSkeletonBox(width: 90.w, height: 70.h, borderRadius: 12.r),
          ],
        ),
        SizedBox(height: 20.h),
        for (int i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(height: 10.h),
          _buildSkeletonBox(
              width: double.infinity, height: 60.h, borderRadius: 18.r),
        ],
      ],
    );
  }
}
