import 'dart:async';
import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../../utils/helper/helper.dart';
import '../../../../../../widgets/common/custom_loading.dart';
import '../../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../../../widgets/common/shimmer_tag.dart';
import '../../../provider/dashboard_provider.dart';
import '../../d_profile/_profile_body.dart';
import '../wallet/model/redeem_history_model.dart';
import '../wallet/provider/redeem_history_provider.dart';
import 'battle_arena_provider.dart';
import 'battle_leaderboard_history_screen.dart';
import 'battle_leaderboard_screen.dart';
import 'battle_room_details_screen.dart';
import 'matching_partner_screen.dart';
import 'my_matches_screen.dart';

@RoutePage()
class BattleArenaScreen extends HookConsumerWidget {
  const BattleArenaScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  final String userId;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = useState<int>(0); // 0: Games/Arena, 1: Leaderboard
    final refreshCounter = useState<int>(0);
    final topPadding = MediaQuery.of(context).padding.top;
    final userAsync = ref.watch(DashboardService.userDataProvider(userId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Solid Clean White Background
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: RefreshIndicator(
                edgeOffset: topPadding + 60.h,
                onRefresh: () async {
                  refreshCounter.value++;
                  await Future.delayed(const Duration(milliseconds: 700));
                },
                color: const Color(0xFFAB31DE),
                backgroundColor: Colors.white,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Container(
                          width: double.infinity,
                          color: Colors.transparent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Executive Top Header Bar (Back button, "Battle Quiz" Kaushan Header, User Profile on Right)
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16.w,
                                  topPadding + 8.h,
                                  16.w,
                                  12.h,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Left: Back Arrow
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.of(context).maybePop();
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

                                    // Center Title: "Battle Quiz" (Exact Home Screen Style)
                                    Text(
                                      'Battle Quiz',
                                      style: GoogleFonts.kaushanScript(
                                        color: const Color(0xFF26262B),
                                        fontSize: 28.sp,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),

                                    // Right: Profile Avatar Button
                                    userAsync.when(
                                      loading: () => SizedBox(width: 40.w),
                                      error: (_, __) => SizedBox(width: 40.w),
                                      data: (user) {
                                        final photoUrl = user.photoUrl;

                                        return GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => Scaffold(
                                                  backgroundColor: const Color(0xFFF8FAFC),
                                                  appBar: AppBar(
                                                    backgroundColor: Colors.white,
                                                    surfaceTintColor: Colors.transparent,
                                                    elevation: 0,
                                                    leading: IconButton(
                                                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF26262B)),
                                                      onPressed: () => Navigator.of(context).pop(),
                                                    ),
                                                    title: Text(
                                                      'My Career & Profile',
                                                      style: GoogleFonts.kaushanScript(
                                                        color: const Color(0xFF26262B),
                                                        fontSize: 22.sp,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                  body: SingleChildScrollView(
                                                    physics: const BouncingScrollPhysics(),
                                                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 32.h),
                                                    child: _MyHistoryTabView(userId: userId),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 40.w,
                                            height: 40.w,
                                            padding: EdgeInsets.all(2.r),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0xFF26262B),
                                              border: Border.all(
                                                color: const Color(0xFFE2E8F0),
                                                width: 1.2,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              backgroundColor: const Color(0xFFFAF5FF),
                                              backgroundImage: photoUrl.isNotEmpty
                                                  ? NetworkImage(photoUrl)
                                                  : const AssetImage('assets/icons/DIAMONDPANDA_LOGO.png') as ImageProvider,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // FEATURED HERO BANNER CARD (Home Screen Rectangle 13 Style)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Container(
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
                                            // Top Tag
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
                                                    Icons.sports_esports_rounded,
                                                    color: const Color(0xFFF97316),
                                                    size: 12.sp,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    '1V1 QUIZ CLASH',
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

                                            // Headline
                                            Text(
                                              'Live Battle Arena',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w700,
                                                height: 1.15,
                                              ),
                                            ),
                                            SizedBox(height: 3.h),

                                            // Subtitle
                                            Text(
                                              'Play 1v1 quizzes & win coin prize pools',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF9E9EA7),
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            SizedBox(height: 8.h),

                                            // Coin Balance Pill
                                            userAsync.maybeWhen(
                                              data: (u) => Row(
                                                children: [
                                                  Text(
                                                    'Your Balance: ',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontSize: 9.sp,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  _HeroCoinBadge(coins: u.coins),
                                                ],
                                              ),
                                              orElse: () => const SizedBox.shrink(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8.w),

                                      // 3D Battle Graphic
                                      Image.asset(
                                        'assets/Icons1/battle-3d-icon-png-download-11623292 3.png',
                                        width: 76.w,
                                        height: 76.w,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Image.asset(
                                          'assets/icons/battle.png',
                                          width: 70.w,
                                          height: 70.w,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              SizedBox(height: 14.h),

                              // Screen Banner (Admin Configurable 700x200 with AD badge)
                              const ScreenBannerWidget(
                                screenKey: 'battleScreen',
                                margin: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                              ),

                              // Main Body View (Arena Games / Battle Rooms)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: _BattleTabView(
                                  userId: userId,
                                  refreshCounter: refreshCounter.value,
                                ),
                              ),

                              SizedBox(height: 110.h),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BattleArenaNavbar(
          selectedTab: selectedTab,
          userId: userId,
        ),
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// HERO COIN BADGE (Exact Home Screen Style)
// ---------------------------------------------------------------------------
class _HeroCoinBadge extends StatelessWidget {
  const _HeroCoinBadge({required this.coins});
  final num coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
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
          Container(
            width: 11.w,
            height: 11.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
              ),
            ),
            padding: EdgeInsets.all(1.w),
            child: Image.asset(
              'assets/icons/coin.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.monetization_on,
                color: Color(0xFFFBBF24),
                size: 9,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            coins.toInt().formatCoins(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BATTLE TAB VIEW (EXECUTIVE WHITE THEME)
// ---------------------------------------------------------------------------
class _BattleTabView extends StatefulWidget {
  const _BattleTabView({
    required this.userId,
    required this.refreshCounter,
  });

  final String userId;
  final int refreshCounter;

  @override
  State<_BattleTabView> createState() => _BattleTabViewState();
}

class _BattleTabViewState extends State<_BattleTabView> {
  late Future<Map<String, dynamic>> _roomsFuture;
  Timer? _matchesPollTimer;
  bool _isNavigatingToMatch = false;
  int _selectedCategoryIndex = 0; // 0: Free Battles, 1: Coin Battles

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _startJoinedMatchesPolling();
  }

  @override
  void didUpdateWidget(covariant _BattleTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshCounter != oldWidget.refreshCounter) {
      _loadRooms();
    }
  }

  void _startJoinedMatchesPolling() {
    _matchesPollTimer?.cancel();
    _matchesPollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _isNavigatingToMatch) return;
      _checkJoinedMatches();
    });
  }

  Future<void> _checkJoinedMatches() async {
    try {
      final resp = await BattleArenaService.instance.fetchMyMatches(
        widget.userId,
      );
      if (resp['success'] == true && resp['joined'] != null) {
        final List<dynamic> joined = resp['joined'];
        if (joined.isNotEmpty) {
          final activeSession = joined.first;
          final String sessionId = activeSession['sessionId']?.toString() ?? '';
          final String roomTitle =
              activeSession['roomTitle']?.toString() ?? 'Battle Room';
          final int secondsRemaining = activeSession['secondsRemaining'] is num
              ? (activeSession['secondsRemaining'] as num).toInt()
              : 0;

          if (!mounted) return;
          final bool isCurrentRoute =
              ModalRoute.of(context)?.isCurrent ?? false;
          if (isCurrentRoute &&
              secondsRemaining <= 1 &&
              !_isNavigatingToMatch) {
            _isNavigatingToMatch = true;
            _matchesPollTimer?.cancel();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => MatchingPartnerScreen(
                  userId: widget.userId,
                  matchId: sessionId,
                  roomTitle: roomTitle,
                  matchingTimeoutSec: 35,
                ),
              ),
            );
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _matchesPollTimer?.cancel();
    super.dispose();
  }

  void _loadRooms() {
    setState(() {
      _roomsFuture = BattleArenaService.instance.fetchActiveRooms(
        widget.userId,
      );
    });
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerTag(
                type: ShimmerType.pulse,
                baseColor: const Color(0xFFF1F5F9),
                highlightColor: const Color(0xFFE2E8F0),
                child: Container(
                  width: 140.w,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ),
              ShimmerTag(
                type: ShimmerType.pulse,
                baseColor: const Color(0xFFF1F5F9),
                highlightColor: const Color(0xFFE2E8F0),
                child: Container(
                  width: 70.w,
                  height: 22.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ShimmerTag(
            type: ShimmerType.pulse,
            baseColor: const Color(0xFFF1F5F9),
            highlightColor: const Color(0xFFE2E8F0),
            child: Container(
              width: double.infinity,
              height: 44.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _roomsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: [
              _buildSkeletonCard(),
              _buildSkeletonCard(),
            ],
          );
        }

        final data = snapshot.data;
        final List<dynamic> rawRooms =
            (data != null && data['success'] == true && data['rooms'] != null)
                ? data['rooms']
                : [];

        if (rawRooms.isEmpty) {
          return _buildEmptyState(
            title: 'No Active Battle Rooms',
            subtitle: 'No matches created yet. Pull down to refresh!',
          );
        }

        final matches = rawRooms.map((r) {
          final String roomId =
              r['roomId']?.toString() ?? r['_id']?.toString() ?? '';
          final String title = r['title']?.toString() ?? '1v1 Battle Clash';
          final String gameTitle = r['assignedGameTitle']?.toString() ??
              r['category']?.toString() ??
              'General Quiz Clash';
          final String subtitle = (r['subtitle'] != null && r['subtitle'].toString().trim().isNotEmpty)
              ? r['subtitle'].toString().trim()
              : (r['description'] != null && r['description'].toString().trim().isNotEmpty)
                  ? r['description'].toString().trim()
                  : gameTitle;
          final int prize = (r['netPrizePoolCoins'] as num?)?.toInt() ??
              (r['prize'] as num?)?.toInt() ??
              0;
          final int entryFee = (r['entryFeeCoins'] as num?)?.toInt() ??
              (r['entryFee'] as num?)?.toInt() ??
              0;
          final String entryType =
              r['entryType']?.toString() ?? (entryFee == 0 ? 'Free' : 'Paid');
          final int capacity = (r['capacity'] as num?)?.toInt() ?? 2;
          final int qCount = (r['questionCount'] as num?)?.toInt() ?? 7;
          final int timePerQ = (r['timePerQuestionSec'] as num?)?.toInt() ?? 15;
          final String catTag = r['category']?.toString() ?? 'quiz';
          final String badge = entryType.toLowerCase() == 'free' ? 'FREE' : 'COIN';
          final int countdownSec = (r['countdownSec'] as num?)?.toInt() ?? 0;

          return {
            'roomId': roomId,
            'title': title,
            'subtitle': subtitle,
            'assignedGameTitle': gameTitle,
            'description': subtitle,
            'prize': prize > 0 ? '$prize Coins' : 'Rank Points',
            'fee': entryType.toLowerCase() == 'free' || entryFee == 0
                ? 'FREE'
                : '$entryFee Coins',
            'entryFeeCoins': entryFee,
            'entryFee': entryFee,
            'entryType': entryType,
            'netPrizePoolCoins': prize,
            'category': catTag,
            'badge': badge,
            'adType': r['adType']?.toString() ?? 'None',
            'skipAdMatches': (r['skipAdMatches'] as num?)?.toInt() ??
                (int.tryParse(r['skipAdMatches']?.toString() ?? '0') ?? 0),
            'capacity': capacity,
            'questionCount': qCount,
            'timePerQuestionSec': timePerQ,
            'matchingTimeoutSec':
                (r['matchingTimeoutSec'] as num?)?.toInt() ?? 35,
            'countdownSec': countdownSec,
            'raw': r,
          };
        }).toList();

        final freeMatches = matches.where((m) {
          final String entryType = m['entryType']?.toString() ??
              m['raw']['entryType']?.toString() ??
              'Paid';
          return entryType.toLowerCase() == 'free';
        }).toList();

        final paidMatches = matches.where((m) {
          final String entryType = m['entryType']?.toString() ??
              m['raw']['entryType']?.toString() ??
              'Paid';
          return entryType.toLowerCase() == 'paid';
        }).toList();

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -150) {
                // Swipe Left -> Coin Battles
                if (_selectedCategoryIndex != 1) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCategoryIndex = 1;
                  });
                }
              } else if (details.primaryVelocity! > 150) {
                // Swipe Right -> Free Battles
                if (_selectedCategoryIndex != 0) {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedCategoryIndex = 0;
                  });
                }
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Executive Category Filter Chips Row (Matching Daily Task Category Chips 1-to-1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Free Battles (${freeMatches.length})',
                      isSelected: _selectedCategoryIndex == 0,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedCategoryIndex = 0;
                        });
                      },
                    ),
                    SizedBox(width: 8.w),
                    _FilterChip(
                      label: 'Coin Battles (${paidMatches.length})',
                      isSelected: _selectedCategoryIndex == 1,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _selectedCategoryIndex = 1;
                        });
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Instant Tab Content Switcher
              _selectedCategoryIndex == 0
                  ? Column(
                      children: [
                        if (freeMatches.isEmpty)
                          _buildEmptyState(
                            title: 'No Active Free Battles',
                            subtitle: 'Check back in a few minutes for new rooms!',
                          )
                        else
                          ...freeMatches.map((m) {
                            return _BattleRoomCard(
                              userId: widget.userId,
                              room: m,
                            );
                          }),
                      ],
                    )
                  : Column(
                      children: [
                        if (paidMatches.isEmpty)
                          _buildEmptyState(
                            title: 'No Active Coin Battles',
                            subtitle: 'Check back in a few minutes for new rooms!',
                          )
                        else
                          ...paidMatches.map((m) {
                            return _BattleRoomCard(
                              userId: widget.userId,
                              room: m,
                            );
                          }),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 36.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: const Color(0xFF26262B),
              borderRadius: BorderRadius.circular(16.r),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.sports_esports_rounded,
              color: Colors.white,
              size: 28.sp,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFF1E1B4B),
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EXECUTIVE CATEGORY FILTER CHIP (Instant Selection, Zero Animation)
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF26262B) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF26262B) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : const Color(0xFF26262B),
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EXECUTIVE WHITE BATTLE ROOM CARD WIDGET
// ---------------------------------------------------------------------------
class _BattleRoomCard extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> room;

  const _BattleRoomCard({
    required this.userId,
    required this.room,
  });

  @override
  State<_BattleRoomCard> createState() => _BattleRoomCardState();
}

class _BattleRoomCardState extends State<_BattleRoomCard> with SingleTickerProviderStateMixin {
  late DateTime _nextStartTime;
  late int _autoRepeatIntervalMinutes;
  int _secondsRemaining = 0;
  Timer? _timer;

  late AnimationController _buttonAnimController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _parseTimes();
    _startTimer();

    _buttonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeOutCubic),
    );
  }

  void _parseTimes() {
    final nextStartStr = widget.room['nextStartTime']?.toString();
    final nextStart = nextStartStr != null
        ? DateTime.tryParse(nextStartStr)?.toLocal()
        : null;
    _autoRepeatIntervalMinutes =
        widget.room['autoRepeatIntervalMinutes'] is num
            ? (widget.room['autoRepeatIntervalMinutes'] as num).toInt()
            : 2;

    if (nextStart != null) {
      _nextStartTime = nextStart;
      _secondsRemaining = _nextStartTime.difference(DateTime.now()).inSeconds;
      if (_secondsRemaining < 0) {
        final now = DateTime.now();
        final elapsedSinceStart = now.difference(_nextStartTime).inSeconds;
        final intervalSec = _autoRepeatIntervalMinutes * 60;
        final cyclesToSkip = (elapsedSinceStart / intervalSec).ceil();
        _nextStartTime = _nextStartTime.add(
          Duration(seconds: cyclesToSkip * intervalSec),
        );
        _secondsRemaining = _nextStartTime.difference(now).inSeconds;
      }
    } else {
      _nextStartTime = DateTime.now().add(
        Duration(minutes: _autoRepeatIntervalMinutes),
      );
      _secondsRemaining = _autoRepeatIntervalMinutes * 60;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _parseTimes();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _buttonAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.room;
    final isFree = m['fee'].toString().toLowerCase().contains('free');

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Header Section of Card
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: Row(
              children: [
                // Icon + Game Title & Subtitle
                Expanded(
                  child: Row(
                    children: [
                      // Executive Dark Icon Dish
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFF26262B),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Icon(
                          Icons.sports_esports_rounded,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['title'].toString(),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 14.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              m['subtitle'].toString(),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF64748B),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),

                // Live Players Capacity Badge Tag
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group_rounded,
                        color: const Color(0xFF475569),
                        size: 13.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${m['capacity'] ?? 2} Players',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF334155),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider Line
          Container(
            height: 1,
            color: const Color(0xFFF1F5F9),
            margin: EdgeInsets.symmetric(horizontal: 16.w),
          ),

          // 2-Metric Boxes Row (ENTRY FEE & PRIZE POOL) & Join CTA Button
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
            child: Column(
              children: [
                Row(
                  children: [
                    // Box 1: Entry Fee
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'ENTRY FEE',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF64748B),
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!isFree) ...[
                                    Image.asset(
                                      'assets/icons/coin.png',
                                      width: 13.w,
                                      height: 13.w,
                                      fit: BoxFit.contain,
                                    ),
                                    SizedBox(width: 3.w),
                                  ],
                                  Text(
                                    isFree ? 'FREE' : m['fee'].toString().replaceAll(' Coins', ''),
                                    style: GoogleFonts.poppins(
                                      color: isFree ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),

                    // Box 2: Winner Reward / Prize Pool
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFFFEF3C7),
                          ),
                        ),
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'PRIZE POOL',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF92400E),
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/icons/coin.png',
                                    width: 13.w,
                                    height: 13.w,
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    m['prize'].toString().replaceAll(' Coins', ''),
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFD97706),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 14.h),

                // JOIN BATTLE METALLIC CTA BUTTON
                ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: GestureDetector(
                    onTapDown: (_) {
                      _buttonAnimController.forward();
                      HapticFeedback.lightImpact();
                    },
                    onTapUp: (_) => _buttonAnimController.reverse(),
                    onTapCancel: () => _buttonAnimController.reverse(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BattleRoomDetailsScreen(
                            userId: widget.userId,
                            match: m,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 46.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Color(0xFFE5E7EB),
                            Color(0xFFB0B5C2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFF9CA3AF),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'JOIN BATTLE',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF16161A),
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: const Color(0xFF16161A),
                            size: 16.sp,
                          ),
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
    );
  }
}

// ---------------------------------------------------------------------------
// PLAYER PROFILE & HISTORY TAB VIEW (WHITE THEME)
// ---------------------------------------------------------------------------
class _MyHistoryTabView extends StatefulWidget {
  final String userId;

  const _MyHistoryTabView({required this.userId});

  @override
  State<_MyHistoryTabView> createState() => _MyHistoryTabViewState();
}

class _MyHistoryTabViewState extends State<_MyHistoryTabView> {
  List<dynamic> _completedMatches = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final resp = await BattleArenaService.instance.fetchMyMatches(widget.userId);
      if (resp['success'] == true && mounted) {
        setState(() {
          _completedMatches = resp['completed'] ?? [];
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final userAsync = ref.watch(DashboardService.userDataProvider(widget.userId));
        final redeemHistoryAsync = ref.watch(payoutHistoryProvider(widget.userId));
        final int redeemCount = redeemHistoryAsync.value
                ?.where((p) => p.status == PayoutStatus.successful)
                .length ??
            0;
        final badge = ProfileBadgeHelper.getBadge(redeemCount);

        final totalMatches = _completedMatches.length;
        final totalWins = _completedMatches.where((m) => m['winnerUserId'] == widget.userId).length;
        final totalLosses = _completedMatches.where((m) => m['winnerUserId'] != widget.userId && m['winnerUserId'] != null).length;
        final winRate = totalMatches > 0 ? ((totalWins / totalMatches) * 100).toInt() : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),

            // 1. EXECUTIVE PLAYER PROFILE CARD (DARK OBSIDIAN THEME)
            userAsync.when(
              loading: () => Container(
                height: 80.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF222226),
                      Color(0xFF131316),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: const Color(0xFF2E2E36),
                    width: 1.0,
                  ),
                ),
                child: const Center(child: GlowLightingSpinner(size: 20)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (user) {
                final photoUrl = user.photoUrl;
                final name = user.name.isNotEmpty ? user.name : 'User';

                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(18.r),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF222226),
                        Color(0xFF131316),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(
                      color: const Color(0xFF2E2E36),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular Avatar
                      Container(
                        padding: EdgeInsets.all(2.5.r),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 32.r,
                          backgroundColor: const Color(0xFF1E1B2E),
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : const AssetImage('assets/icons/DIAMONDPANDA_LOGO.png') as ImageProvider,
                        ),
                      ),
                      SizedBox(height: 10.h),

                      // User Name
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 2.h),

                      // User Email
                      Text(
                        user.email,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF9E9EA7),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),

                      // Badge Pill + Copy UID Pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // User Badge Pill
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E2E38),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: const Color(0xFF3E3E4C),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  badge.iconPath,
                                  width: 14.w,
                                  height: 14.w,
                                  fit: BoxFit.contain,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  badge.title,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFFBBF24),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),

                          // Player UID Pill with Copy Action
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(ClipboardData(text: widget.userId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Player UID copied!',
                                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12.sp),
                                  ),
                                  backgroundColor: const Color(0xFF1E1B4B),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E2E38),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: const Color(0xFF3E3E4C),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'UID: ${widget.userId.length > 8 ? '${widget.userId.substring(0, 8)}...' : widget.userId}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 5.w),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 12.sp,
                                    color: const Color(0xFF38BDF8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 24.h),

            // 2. CAREER BATTLE STATS (4-GRID SYSTEM)
            Row(
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
                  'Career Battle Stats',
                  style: GoogleFonts.kaushanScript(
                    color: const Color(0xFF26262B),
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            Row(
              children: [
                // Card 1: Total Battles
                Expanded(
                  child: _buildWhiteStatCard(
                    iconWidget: Icon(
                      Icons.sports_esports_rounded,
                      color: const Color(0xFFAB31DE),
                      size: 18.sp,
                    ),
                    value: '$totalMatches',
                    label: 'Battles',
                  ),
                ),
                SizedBox(width: 8.w),

                // Card 2: Victories
                Expanded(
                  child: _buildWhiteStatCard(
                    iconWidget: Icon(
                      Icons.emoji_events_rounded,
                      color: const Color(0xFFFBBF24),
                      size: 18.sp,
                    ),
                    value: '$totalWins',
                    label: 'Wins',
                  ),
                ),
                SizedBox(width: 8.w),

                // Card 3: Defeats
                Expanded(
                  child: _buildWhiteStatCard(
                    iconWidget: Icon(
                      Icons.cancel_rounded,
                      color: const Color(0xFFEF4444),
                      size: 18.sp,
                    ),
                    value: '$totalLosses',
                    label: 'Losses',
                  ),
                ),
                SizedBox(width: 8.w),

                // Card 4: Win Rate
                Expanded(
                  child: _buildWhiteStatCard(
                    iconWidget: Icon(
                      Icons.analytics_rounded,
                      color: const Color(0xFF38BDF8),
                      size: 18.sp,
                    ),
                    value: '$winRate%',
                    label: 'Win Rate',
                  ),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // 3. QUICK ACTIONS MENU OPTIONS
            Row(
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
                  'Quick Actions',
                  style: GoogleFonts.kaushanScript(
                    color: const Color(0xFF26262B),
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF222226),
                    Color(0xFF131316),
                  ],
                ),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: const Color(0xFF2E2E36),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildMenuTile(
                    icon: Icons.emoji_events_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    title: 'Leaderboard History',
                    subtitle: 'View past champion cycles & winners',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BattleLeaderboardHistoryScreen(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                  _buildMenuDivider(),
                  _buildMenuTile(
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFFAB31DE),
                    title: 'Match History',
                    subtitle: 'Review all your past battles & scores',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MyMatchesScreen(userId: widget.userId),
                        ),
                      );
                    },
                  ),
                  _buildMenuDivider(),
                  _buildMenuTile(
                    icon: Icons.share_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    title: 'Share Battle Arena',
                    subtitle: 'Invite friends & challenge them to quiz clash',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Share.share(
                        '⚔️ Challenge me in the Crazyreward 1v1 Battle Arena! Play quizzes and win real coins. Download now: https://play.google.com/store/apps/details?id=com.crazyreward.games',
                      );
                    },
                  ),
                  _buildMenuDivider(),
                  _buildMenuTile(
                    icon: Icons.exit_to_app_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Exit Battle Arena',
                    subtitle: 'Leave Battle Panda & return to main dashboard',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E38),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: const Color(0xFF3E3E4C),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 21.sp),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9E9EA7),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFF9E9EA7),
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuDivider() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 1,
      color: const Color(0xFF2E2E38),
    );
  }

  Widget _buildWhiteStatCard({
    required Widget iconWidget,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF222226),
            Color(0xFF131316),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF2E2E36),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: const Color(0xFF2E2E38),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: const Color(0xFF3E3E4C),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: iconWidget,
          ),
          SizedBox(height: 7.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF9E9EA7),
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2-SLOT BOTTOM NOTCHED NAVBAR (SLOT 0: GAMES, SLOT 1: LEADERBOARD)
// ---------------------------------------------------------------------------
class _BattleArenaNavbar extends StatelessWidget {
  final ValueNotifier<int> selectedTab;
  final String userId;

  const _BattleArenaNavbar({
    required this.selectedTab,
    required this.userId,
  });

  _BattleNavItemData _getItem(int slotIndex) {
    switch (slotIndex) {
      case 0:
        return const _BattleNavItemData(
          icon: Icons.sports_esports_rounded,
          label: 'Games',
          tabIndex: 0,
        );
      case 1:
        return const _BattleNavItemData(
          icon: Icons.emoji_events_rounded,
          label: 'Leaderboard',
          tabIndex: 1,
        );
      default:
        return const _BattleNavItemData(
          icon: Icons.sports_esports_rounded,
          label: 'Games',
          tabIndex: 0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double navBarHeight = 44.h + bottomPadding;
    final double totalHeight = navBarHeight + 14.h;

    return ValueListenableBuilder<int>(
      valueListenable: selectedTab,
      builder: (context, activeTab, _) {
        final int activeSlotIndex = activeTab == 0 ? 0 : 1;
        final activeItem = _getItem(activeSlotIndex);

        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final double slotWidth = width / 2.0;

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: activeSlotIndex.toDouble(),
                end: activeSlotIndex.toDouble(),
              ),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              builder: (context, animatedSlot, _) {
                final double cx = (animatedSlot + 0.5) * slotWidth;

                return SizedBox(
                  width: width,
                  height: totalHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 1. Curved Navigation Bar with Dynamic Sliding Notch
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: navBarHeight,
                        child: CustomPaint(
                          painter: _BattleNotchedNavPainter(cx: cx),
                          child: ClipPath(
                            clipper: _BattleNotchedNavClipper(cx: cx),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white,
                                    Color(0xFFF8FAFC),
                                    Color(0xFFFAF5FF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. Base Side Navigation Slots (2 Slots: Games & Leaderboard)
                      Positioned(
                        bottom: bottomPadding + 2.h,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: List.generate(2, (slotIndex) {
                            final item = _getItem(slotIndex);
                            final isCurrentActive = slotIndex == activeSlotIndex;

                            return Expanded(
                              child: _BattleNavScaleTap(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (slotIndex == 1) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => BattleLeaderboardScreen(userId: userId),
                                      ),
                                    );
                                  } else {
                                    selectedTab.value = item.tabIndex;
                                  }
                                },
                                child: Container(
                                  height: 38.h,
                                  color: Colors.transparent,
                                  child: Center(
                                    child: AnimatedOpacity(
                                      duration: const Duration(milliseconds: 180),
                                      opacity: isCurrentActive ? 0.0 : 1.0,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            item.icon,
                                            size: 20.sp,
                                            color: const Color(0xFF9E9EA7),
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            item.label,
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF9E9EA7),
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // 3. Floating Active Button
                      Positioned(
                        left: cx - 23.w,
                        top: 0,
                        child: _BattleElevatedActiveButton(
                          icon: activeItem.icon,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _BattleNavItemData {
  final IconData icon;
  final String label;
  final int tabIndex;

  const _BattleNavItemData({
    required this.icon,
    required this.label,
    required this.tabIndex,
  });
}

class _BattleElevatedActiveButton extends StatelessWidget {
  const _BattleElevatedActiveButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _BattleNavScaleTap(
      onTap: onTap,
      child: SizedBox(
        width: 46.w,
        height: 46.w,
        child: Container(
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
            border: Border.all(
              color: const Color(0xFF9CA3AF),
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
          child: Center(
            child: Icon(
              icon,
              size: 21.sp,
              color: const Color(0xFF16161A),
            ),
          ),
        ),
      ),
    );
  }
}

Path _buildBattleNotchedPath(Size size, double cx) {
  final double w = size.width;
  final double h = size.height;

  final double cornerRadius = 16.0;
  final double notchWidth = 32.0;
  final double notchDepth = 18.0;
  final double transitionWidth = 12.0;

  final double notchStart = cx - notchWidth - transitionWidth;
  final double notchEnd = cx + notchWidth + transitionWidth;

  final path = Path();

  path.moveTo(0, cornerRadius);
  path.quadraticBezierTo(0, 0, cornerRadius, 0);

  if (notchStart > cornerRadius) {
    path.lineTo(notchStart, 0);
  }

  path.cubicTo(
    cx - notchWidth,
    0,
    cx - notchWidth + 4.5,
    notchDepth * 0.40,
    cx - notchWidth * 0.65,
    notchDepth * 0.86,
  );

  path.cubicTo(
    cx - notchWidth * 0.32,
    notchDepth,
    cx + notchWidth * 0.32,
    notchDepth,
    cx + notchWidth * 0.65,
    notchDepth * 0.86,
  );

  path.cubicTo(
    cx + notchWidth - 4.5,
    notchDepth * 0.40,
    cx + notchWidth,
    0,
    notchEnd,
    0,
  );

  if (notchEnd < w - cornerRadius) {
    path.lineTo(w - cornerRadius, 0);
  }

  path.quadraticBezierTo(w, 0, w, cornerRadius);
  path.lineTo(w, h);
  path.lineTo(0, h);
  path.close();

  return path;
}

class _BattleNotchedNavPainter extends CustomPainter {
  const _BattleNotchedNavPainter({required this.cx});

  final double cx;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildBattleNotchedPath(size, cx);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, shadowPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFE2E8F0);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BattleNotchedNavPainter oldDelegate) {
    return oldDelegate.cx != cx;
  }
}

class _BattleNotchedNavClipper extends CustomClipper<Path> {
  const _BattleNotchedNavClipper({required this.cx});

  final double cx;

  @override
  Path getClip(Size size) {
    return _buildBattleNotchedPath(size, cx);
  }

  @override
  bool shouldReclip(covariant _BattleNotchedNavClipper oldClipper) {
    return oldClipper.cx != cx;
  }
}

class _BattleNavScaleTap extends StatefulWidget {
  const _BattleNavScaleTap({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_BattleNavScaleTap> createState() => _BattleNavScaleTapState();
}

class _BattleNavScaleTapState extends State<_BattleNavScaleTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
