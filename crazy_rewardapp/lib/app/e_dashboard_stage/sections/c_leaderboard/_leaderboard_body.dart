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
                color: const Color(0xFF26262B),
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
                      // Top Navigation Header: Back Button & Title
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

                      const ScreenBannerWidget(
                        screenKey: 'leaderboardScreen',
                        margin: EdgeInsets.only(top: 14.0, bottom: 2.0),
                      ),

                      SizedBox(height: 12.h),

                      // Segmented Tab Switcher (Top Earners vs Top Referrals)
                      _buildSegmentedTabBar(
                        selectedTab: selectedTab.value,
                        onTabChanged: (val) {
                          selectedTab.value = val;
                        },
                      ),

                      SizedBox(height: 18.h),

                      // Active Leaderboard Data
                      activeDataAsync.when(
                        loading: () => const _LeaderboardShimmer(),
                        error: (_, __) => _buildErrorState(ref),
                        data: (data) {
                          if (isCoinsTab) {
                            // Top Earners Tab: Shows 3D Arch Podium + Ranks 4 to 100
                            final topThree = data.take(3).toList();
                            final remaining = data.length > 3
                                ? data.sublist(3)
                                : <LeaderboardModel>[];

                            return Column(
                              children: [
                                // Top 3 Winners 3D Arch Podium (Using Ellipse 59, 60 & Group 28, 29, 30)
                                _buildTopThreePodium(topThree, false),

                                SizedBox(height: 14.h),

                                // Table Container Card (Timer + Table Header + Ranks 4-100)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 16.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      // Countdown Timer Pill ("11:59:59")
                                      _buildTimerRow(),

                                      SizedBox(height: 14.h),

                                      // Leaderboard Table Header
                                      _buildTableHeader(isReferralTab: false),

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
                                            return _buildRankListItem(
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
                            // Top Referrals Tab: Direct Clean List from Rank 1 to 100 (No Podium)
                            return Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 16.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Countdown Timer Pill ("11:59:59")
                                  _buildTimerRow(),

                                  SizedBox(height: 14.h),

                                  // Leaderboard Table Header
                                  _buildTableHeader(isReferralTab: true),

                                  SizedBox(height: 8.h),

                                  // Full Ranks 1 to 100 List
                                  if (data.isNotEmpty)
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      itemCount: data.length,
                                      separatorBuilder: (_, __) => const Divider(
                                        color: Color(0xFFF1F5F9),
                                        height: 1,
                                        thickness: 1,
                                      ),
                                      itemBuilder: (context, index) {
                                        final rank = index + 1;
                                        final item = data[index];
                                        return _buildRankListItem(
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
                            );
                          }
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
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
              color: isSelected ? const Color(0xFF16161A) : const Color(0xFF64748B),
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
                      Colors.white,
                      Color(0xFFE5E7EB),
                      Color(0xFFB0B5C2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF9CA3AF),
                    width: 1.0,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
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
                style: GoogleFonts.poppins(
                  color: isSelected
                      ? const Color(0xFF16161A)
                      : const Color(0xFF64748B),
                  fontSize: 13.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
          (targetMs - DateTime.now().millisecondsSinceEpoch)
              .clamp(0, double.infinity)
              .toInt(),
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
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(100.r),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                color: const Color(0xFF26262B),
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                timerString,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF26262B),
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
  // TOP 3 WINNERS 3D ARCH PODIUM (Matching Asset Reference 1-to-1)
  // -------------------------------------------------------------
  Widget _buildTopThreePodium(
      List<LeaderboardModel> topThree, bool isReferralTab) {
    final rank1 = topThree.isNotEmpty ? topThree[0] : null;
    final rank2 = topThree.length > 1 ? topThree[1] : null;
    final rank3 = topThree.length > 2 ? topThree[2] : null;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Background Arch 1 (Ellipse 59)
          Positioned(
            top: -10.h,
            child: Image.asset(
              'assets/Icons1/Ellipse 59.png',
              width: 340.w,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // Background Arch 2 (Ellipse 60)
          Positioned(
            top: 15.h,
            child: Image.asset(
              'assets/Icons1/Ellipse 60.png',
              width: 290.w,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // 3 Pillars Row (Group 30 [Rank 2], Group 29 [Rank 1], Group 28 [Rank 3])
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 6.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Rank 2 (Left - Group 30.png)
                _buildPodiumPillar(
                  rank: 2,
                  user: rank2,
                  pillarAsset: 'assets/Icons1/Group 30.png',
                  pillarWidth: 86.w,
                  pillarHeight: 124.h,
                  avatarSize: 38.w,
                  avatarTopOffset: 4.h,
                  isReferralTab: isReferralTab,
                  isCenter: false,
                ),

                SizedBox(width: 8.w),

                // Rank 1 (Center - Elevated - Group 29.png)
                _buildPodiumPillar(
                  rank: 1,
                  user: rank1,
                  pillarAsset: 'assets/Icons1/Group 29.png',
                  pillarWidth: 100.w,
                  pillarHeight: 144.h,
                  avatarSize: 44.w,
                  avatarTopOffset: 4.h,
                  isReferralTab: isReferralTab,
                  isCenter: true,
                ),

                SizedBox(width: 8.w),

                // Rank 3 (Right - Group 28.png)
                _buildPodiumPillar(
                  rank: 3,
                  user: rank3,
                  pillarAsset: 'assets/Icons1/Group 28.png',
                  pillarWidth: 86.w,
                  pillarHeight: 124.h,
                  avatarSize: 38.w,
                  avatarTopOffset: 4.h,
                  isReferralTab: isReferralTab,
                  isCenter: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPillar({
    required int rank,
    required LeaderboardModel? user,
    required String pillarAsset,
    required double pillarWidth,
    required double pillarHeight,
    required double avatarSize,
    required double avatarTopOffset,
    required bool isReferralTab,
    required bool isCenter,
  }) {
    if (user == null) {
      return SizedBox(
        width: pillarWidth,
        height: pillarHeight,
        child: Image.asset(
          pillarAsset,
          fit: BoxFit.contain,
        ),
      );
    }

    final scoreStr = isReferralTab
        ? '${user.totalReferrals}'
        : '${user.totalCoins.toInt()}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 3D Pillar with Avatar Overlay inside the top circle
        SizedBox(
          width: pillarWidth,
          height: pillarHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // 1. Pillar Graphic
              Positioned.fill(
                child: Image.asset(
                  pillarAsset,
                  fit: BoxFit.contain,
                ),
              ),

              // 2. User Avatar perfectly positioned inside top ring
              Positioned(
                top: avatarTopOffset,
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: InternetImage(
                      url: user.photoUrl,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 6.h),

        // User Name
        SizedBox(
          width: pillarWidth + 10.w,
          child: Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: isCenter ? 12.5.sp : 11.5.sp,
              fontWeight: isCenter ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),

        SizedBox(height: 2.h),

        // Score Row (Coins / Referrals)
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isReferralTab) ...[
              Icon(
                Icons.people_alt_rounded,
                color: const Color(0xFF26262B),
                size: 12.sp,
              ),
              SizedBox(width: 3.w),
            ] else ...[
              Image.asset(
                'assets/icons/coin.png',
                width: 12.w,
                height: 12.w,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 3.w),
            ],
            Text(
              scoreStr,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TABLE HEADER ROW (Rank | User | Reward / Referrals)
  // -------------------------------------------------------------
  Widget _buildTableHeader({required bool isReferralTab}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Row(
        children: [
          SizedBox(
            width: 44.w,
            child: Text(
              'Rank',
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'User',
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            isReferralTab ? 'Referrals' : 'Reward',
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // RANK LIST ITEM
  // -------------------------------------------------------------
  Widget _buildRankListItem({
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

    Widget rankBadge;
    if (rank == 1) {
      rankBadge = Container(
        width: 26.w,
        height: 26.w,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFFEF3C7),
          shape: BoxShape.circle,
        ),
        child: Text(
          '1',
          style: GoogleFonts.poppins(
            color: const Color(0xFFD97706),
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else if (rank == 2) {
      rankBadge = Container(
        width: 26.w,
        height: 26.w,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Text(
          '2',
          style: GoogleFonts.poppins(
            color: const Color(0xFF475569),
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else if (rank == 3) {
      rankBadge = Container(
        width: 26.w,
        height: 26.w,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFFFEDD5),
          shape: BoxShape.circle,
        ),
        child: Text(
          '3',
          style: GoogleFonts.poppins(
            color: const Color(0xFFC2410C),
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else {
      rankBadge = Container(
        width: 26.w,
        height: 26.w,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$rank',
          style: GoogleFonts.poppins(
            color: const Color(0xFF26262B),
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
      child: Row(
        children: [
          // Rank Badge Pill Circle
          rankBadge,

          SizedBox(width: 12.w),

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
              style: GoogleFonts.poppins(
                color: const Color(0xFF26262B),
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Right Metric (Referrals Count or Reward Coins)
          if (isReferralTab)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_alt_rounded,
                  color: const Color(0xFF26262B),
                  size: 15.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  '${item.totalReferrals}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
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
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // User Rank Pill Number
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
                color: const Color(0xFFE2E8F0),
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
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Keep going, You're doing great!",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
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
                  if (isReferralTab) ...[
                    Icon(
                      Icons.people_alt_rounded,
                      color: const Color(0xFF64748B),
                      size: 13.sp,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      'Ref',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else ...[
                    Image.asset(
                      'assets/icons/coin.png',
                      width: 13.w,
                      height: 13.w,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      '0',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
          children: [
            _buildSkeletonBox(width: 86.w, height: 124.h, borderRadius: 20.r),
            SizedBox(width: 10.w),
            _buildSkeletonBox(width: 100.w, height: 144.h, borderRadius: 22.r),
            SizedBox(width: 10.w),
            _buildSkeletonBox(width: 86.w, height: 124.h, borderRadius: 20.r),
          ],
        ),
        SizedBox(height: 20.h),
        for (int i = 0; i < 5; i++) ...[
          if (i > 0) SizedBox(height: 10.h),
          _buildSkeletonBox(
              width: double.infinity, height: 50.h, borderRadius: 14.r),
        ],
      ],
    );
  }
}
