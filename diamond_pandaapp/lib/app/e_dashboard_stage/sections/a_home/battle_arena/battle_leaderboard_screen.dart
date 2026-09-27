import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../widgets/common/internet_image.dart';
import '../../../../../../widgets/common/shimmer_tag.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'battle_arena_provider.dart';
import 'battle_leaderboard_history_screen.dart';

class BattleLeaderboardScreen extends StatefulWidget {
  const BattleLeaderboardScreen({super.key, required this.userId});
  final String userId;

  @override
  State<BattleLeaderboardScreen> createState() => _BattleLeaderboardScreenState();
}

class _BattleLeaderboardScreenState extends State<BattleLeaderboardScreen> {
  int _activeTab = 0; // 0: Prize Pool, 1: Leaderboard
  late Future<List<dynamic>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = BattleArenaService.instance.fetchWeeklyLeaderboard(widget.userId);
  }

  int _getRewardCoinsForRank(int rank, List<dynamic> tiers) {
    for (final t in tiers) {
      if (t is Map) {
        final int start = (t['rankStart'] as num?)?.toInt() ?? 0;
        final int end = (t['rankEnd'] as num?)?.toInt() ?? 0;
        if (rank >= start && rank <= end) {
          return (t['coins'] as num?)?.toInt() ?? 0;
        }
      }
    }
    return 0;
  }

  Map<String, dynamic>? _getRewardTierForRank(int rank, List<dynamic> tiers) {
    for (final t in tiers) {
      if (t is Map) {
        final int start = (t['rankStart'] as num?)?.toInt() ?? 0;
        final int end = (t['rankEnd'] as num?)?.toInt() ?? 0;
        if (rank >= start && rank <= end) {
          return Map<String, dynamic>.from(t);
        }
      }
    }
    return null;
  }

  String _formatCoins(dynamic coins) {
    final double val = (coins is num) ? coins.toDouble() : 0.0;
    if (val >= 1000) {
      final double kVal = val / 1000.0;
      if (kVal % 1 == 0) {
        return '${kVal.toInt()}k';
      }
      return '${kVal.toStringAsFixed(1)}k';
    }
    return '${val.toInt()}';
  }

  Widget _buildTopHeroBanner(String headerTitle) {
    return Column(
      children: [
        // Trophy Illustration Box with Purple Laurel Glow
        SizedBox(
          height: 90.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140.w,
                height: 70.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE39FFF).withValues(alpha: 0.22),
                ),
              ),
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
          headerTitle,
          textAlign: TextAlign.center,
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

  Widget _buildSegmentedTabBar() {
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
            label: 'PRIZE POOL',
            icon: Icons.emoji_events_rounded,
            tabIndex: 0,
          ),
          _buildTabItem(
            label: 'LEADERBOARD',
            icon: Icons.leaderboard_rounded,
            tabIndex: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required IconData icon,
    required int tabIndex,
  }) {
    final isSelected = _activeTab == tabIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_activeTab != tabIndex) {
            HapticFeedback.selectionClick();
            setState(() => _activeTab = tabIndex);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.30),
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
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 16.sp,
              ),
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

  Widget _buildLeaderboardInstructionBanner({String? endTime}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: EdgeInsets.all(10.r),
            child: Image.asset(
              'assets/icons/coin.png',
              width: 32.w,
              height: 32.w,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'WIN HIGH REWARDS!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFFAB31DE),
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Play Free Battles, climb up the Leaderboard and win exciting Coin Rewards!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (endTime != null) ...[
            SizedBox(height: 14.h),
            _LeaderboardCountdownPill(endTimeStr: endTime),
          ],
        ],
      ),
    );
  }

  Widget _buildTopThreePodium({
    required dynamic rank1,
    required dynamic rank2,
    required dynamic rank3,
    required String reward1,
    required String reward2,
    required String reward3,
    String? rewardIcon1,
    String? rewardIcon2,
    String? rewardIcon3,
    required bool isPrizePool,
    required bool showWinnersOnly,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 18.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rank 2 (Left)
          Expanded(
            child: _buildPodiumCard(
              rank: 2,
              player: rank2,
              rewardText: reward2,
              rewardIcon: rewardIcon2,
              avatarSize: 58.w,
              ringColor: const Color(0xFF94A3B8),
              isPrizePool: isPrizePool,
              showWinnersOnly: showWinnersOnly,
              isCenter: false,
            ),
          ),

          SizedBox(width: 8.w),

          // Rank 1 (Center - Elevated & Crown on Top)
          Expanded(
            child: _buildPodiumCard(
              rank: 1,
              player: rank1,
              rewardText: reward1,
              rewardIcon: rewardIcon1,
              avatarSize: 66.w,
              ringColor: const Color(0xFFFFB800),
              isPrizePool: isPrizePool,
              showWinnersOnly: showWinnersOnly,
              isCenter: true,
            ),
          ),

          SizedBox(width: 8.w),

          // Rank 3 (Right)
          Expanded(
            child: _buildPodiumCard(
              rank: 3,
              player: rank3,
              rewardText: reward3,
              rewardIcon: rewardIcon3,
              avatarSize: 58.w,
              ringColor: const Color(0xFFD97706),
              isPrizePool: isPrizePool,
              showWinnersOnly: showWinnersOnly,
              isCenter: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumCard({
    required int rank,
    required dynamic player,
    required String rewardText,
    String? rewardIcon,
    required double avatarSize,
    required Color ringColor,
    required bool isPrizePool,
    required bool showWinnersOnly,
    required bool isCenter,
  }) {
    final String rawName = player?['userName']?.toString() ?? '-';
    final String name = rawName.trim().isNotEmpty ? rawName.trim().split(' ').first : '-';
    final int winsCount = player?['winsCount'] ?? 0;
    final int totalSpeedPoints = player?['totalSpeedPoints'] ?? 0;
    final bool hasPlayer = player != null;

    final bool isWinsBased = BattleArenaService.instance.rankingBasis == 'wins';
    final String badgeText = isWinsBased
        ? (hasPlayer ? '$winsCount Wins' : '0 Wins')
        : (hasPlayer ? '$totalSpeedPoints Pts' : '0 Pts');

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Golden Crown for Rank 1
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

        // Outer 3D Pink/Purple Base Container
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
                        child: Container(
                          color: const Color(0xFFFAF5FF),
                          child: (() {
                            if (isPrizePool) {
                              return Center(
                                child: (rewardIcon != null && rewardIcon.isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: rewardIcon,
                                        height: rank == 1 ? 36.r : 30.r,
                                        width: rank == 1 ? 36.r : 30.r,
                                        fit: BoxFit.contain,
                                        errorWidget: (_, __, ___) => Image.asset(
                                          'assets/icons/coin.png',
                                          height: rank == 1 ? 36.r : 30.r,
                                          width: rank == 1 ? 36.r : 30.r,
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/icons/coin.png',
                                        height: rank == 1 ? 36.r : 30.r,
                                        width: rank == 1 ? 36.r : 30.r,
                                      ),
                              );
                            }
                            if (!hasPlayer) {
                              return Icon(
                                Icons.person_rounded,
                                color: const Color(0xFFAB31DE),
                                size: rank == 1 ? 26.sp : 22.sp,
                              );
                            }
                            final String avatarUrl = player['avatar']?.toString() ?? '';
                            return avatarUrl.isNotEmpty && avatarUrl != 'null'
                                ? AvatarInternetImage(
                                    url: avatarUrl,
                                    size: avatarSize,
                                  )
                                : Center(
                                    child: Text(
                                      name.substring(0, name.isNotEmpty ? 1 : 0).toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFFAB31DE),
                                        fontSize: rank == 1 ? 18.sp : 15.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                          })(),
                        ),
                      ),
                    ),

                    // Overlapping Vertical Hexagon Badge
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

                // Name or Rank Tag
                Text(
                  isPrizePool ? 'Rank #$rank' : name,
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

                // Reward / Stats Subtitle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (rewardIcon != null && rewardIcon.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: 4.w),
                        child: CachedNetworkImage(
                          imageUrl: rewardIcon,
                          width: 13.w,
                          height: 13.w,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Image.asset(
                            'assets/icons/coin.png',
                            width: 13.w,
                            height: 13.w,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    else ...[
                      Image.asset(
                        'assets/icons/coin.png',
                        width: 13.w,
                        height: 13.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 4.w),
                    ],
                    Flexible(
                      child: Text(
                        isPrizePool ? rewardText : badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildRewardTiersSection(List<dynamic> tiers) {
    if (tiers.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 30.h),
        child: Column(
          children: [
            Icon(Icons.emoji_events_outlined, color: const Color(0xFF94A3B8), size: 40.sp),
            SizedBox(height: 8.h),
            Text(
              'No reward tiers configured.',
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: tiers.length,
          itemBuilder: (context, index) {
            final tier = tiers[index];
            final int start = (tier['rankStart'] as num?)?.toInt() ?? (index + 1);
            final int end = (tier['rankEnd'] as num?)?.toInt() ?? start;
            final int coins = (tier['coins'] as num?)?.toInt() ?? 0;
            final String? iconUrl = tier['iconUrl']?.toString().trim();
            final String? customText = tier['customText']?.toString().trim();
            final String rangeText = start == end ? 'Rank #$start' : 'Rank #$start – #$end';
            final String displayRewardText = (customText != null && customText.isNotEmpty)
                ? customText
                : '${_formatCoins(coins)} Coins';

            Color rankColor = const Color(0xFFAB31DE);
            Color bgColor = const Color(0xFFFAF5FF);
            Color borderColor = const Color(0xFFF3E8FF);

            if (start == 1) {
              rankColor = const Color(0xFFD97706);
              bgColor = const Color(0xFFFFFBEB);
              borderColor = const Color(0xFFFCD34D);
            } else if (start == 2) {
              rankColor = const Color(0xFF475569);
              bgColor = const Color(0xFFF8FAFC);
              borderColor = const Color(0xFFCBD5E1);
            } else if (start == 3) {
              rankColor = const Color(0xFFC2410C);
              bgColor = const Color(0xFFFFF7ED);
              borderColor = const Color(0xFFFDBA74);
            }

            return Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Text(
                          rangeText,
                          style: GoogleFonts.outfit(
                            color: rankColor,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (iconUrl != null && iconUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: CachedNetworkImage(
                              imageUrl: iconUrl,
                              width: 20.w,
                              height: 20.w,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => Image.asset(
                                'assets/icons/coin.png',
                                width: 18.w,
                                height: 18.w,
                              ),
                            ),
                          )
                        else
                          Image.asset(
                            'assets/icons/coin.png',
                            width: 18.w,
                            height: 18.w,
                          ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            displayRewardText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }

  Widget _buildRankListItem(
    int rankNum,
    dynamic player,
    int rwCoins,
    bool showWinnersOnly, {
    String? rwIcon,
    String? rwCustomText,
  }) {
    final String pName = player['userName']?.toString() ?? 'Player';
    final int pts = player['totalSpeedPoints'] ?? 0;
    final int wins = player['winsCount'] ?? 0;
    final String pAvatar = player['avatar']?.toString() ?? '';
    final bool isMe = player['userId']?.toString() == widget.userId;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFAF5FF) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isMe ? const Color(0xFFAB31DE) : const Color(0xFFF1F5F9),
          width: isMe ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isMe
                ? const Color(0xFFAB31DE).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge Pill
          Container(
            width: 28.w,
            height: 28.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFAB31DE) : const Color(0xFFFAF5FF),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rankNum',
              style: GoogleFonts.outfit(
                color: isMe ? Colors.white : const Color(0xFFAB31DE),
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          SizedBox(width: 12.w),

          // User Avatar
          CircleAvatar(
            radius: 17.r,
            backgroundColor: const Color(0xFFFAF5FF),
            child: pAvatar.isNotEmpty && pAvatar != 'null'
                ? ClipOval(
                    child: AvatarInternetImage(
                      url: pAvatar,
                      size: 34.r,
                    ),
                  )
                : Text(
                    pName.substring(0, pName.isNotEmpty ? 1 : 0).toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFAB31DE),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),

          SizedBox(width: 10.w),

          // Name & Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  (BattleArenaService.instance.rankingBasis == 'wins') ? '$wins Wins' : '$pts Speed Points',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Reward Pill
          if ((rwCustomText != null && rwCustomText.isNotEmpty) || rwCoins > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (rwIcon != null && rwIcon.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3.r),
                    child: CachedNetworkImage(
                      imageUrl: rwIcon,
                      width: 15.w,
                      height: 15.w,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/icons/coin.png',
                        width: 14.w,
                        height: 14.w,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  Image.asset(
                    'assets/icons/coin.png',
                    width: 14.w,
                    height: 14.w,
                    fit: BoxFit.contain,
                  ),
                SizedBox(width: 4.w),
                Text(
                  (rwCustomText != null && rwCustomText.isNotEmpty)
                      ? rwCustomText
                      : '+${_formatCoins(rwCoins)}',
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

  Widget _buildUserStickyRankBar({
    required int userRank,
    required String userName,
    required String photoUrl,
    required int score,
    required int winsCount,
    required bool showWinnersOnly,
  }) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
            color: const Color(0xFFAB31DE).withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // User Rank Number
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
              child: photoUrl.isNotEmpty
                  ? AvatarInternetImage(
                      url: photoUrl,
                      size: 36.w,
                    )
                  : CircleAvatar(
                      backgroundColor: const Color(0xFFFAF5FF),
                      child: Text(
                        userName.substring(0, userName.isNotEmpty ? 1 : 0).toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                  "Keep playing & climbing up!",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // User Score
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/coin.png',
                width: 15.w,
                height: 15.w,
                fit: BoxFit.contain,
              ),
              SizedBox(width: 4.w),
              Text(
                (BattleArenaService.instance.rankingBasis == 'wins') ? '$winsCount Wins' : '$score Pts',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double borderRadius = 8.0,
  }) {
    return ShimmerTag(
      type: ShimmerType.pulse,
      baseColor: const Color(0xFFF1F5F9),
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }

  Widget _buildLeaderboardShimmer() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSkeletonBox(width: 40.w, height: 40.w, borderRadius: 14.r),
                  _buildSkeletonBox(width: 140.w, height: 24.h, borderRadius: 8.r),
                  _buildSkeletonBox(width: 40.w, height: 40.w, borderRadius: 14.r),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _buildSkeletonBox(width: double.infinity, height: 44.h, borderRadius: 14.r),
            ),
            SizedBox(height: 20.h),
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
            SizedBox(height: 24.h),
            ...List.generate(4, (index) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: _buildSkeletonBox(width: double.infinity, height: 52.h, borderRadius: 14.r),
            )),
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActiveLeaderboardState({required double topPadding, required double bottomPadding}) {
    return RefreshIndicator(
      color: const Color(0xFFAB31DE),
      backgroundColor: Colors.white,
      edgeOffset: topPadding + 60.h,
      onRefresh: () async {
        setState(() {
          _leaderboardFuture = BattleArenaService.instance.fetchWeeklyLeaderboard(widget.userId);
        });
        await _leaderboardFuture;
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          16.w,
          topPadding + 14.h,
          16.w,
          bottomPadding + 40.h,
        ),
        child: Column(
          children: [
            // Top Navigation Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BattleLeaderboardHistoryScreen(userId: widget.userId),
                      ),
                    );
                  },
                  child: Container(
                    width: 40.w,
                    height: 40.w,
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
                    child: Center(
                      child: Icon(
                        Icons.history_rounded,
                        color: const Color(0xFFAB31DE),
                        size: 21.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 36.h),

            // No Active Leaderboard Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 34.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(28.r),
                border: Border.all(
                  color: const Color(0xFFF3E8FF),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Illustration with Glow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 110.w,
                        height: 110.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE39FFF).withValues(alpha: 0.22),
                        ),
                      ),
                      Image.asset(
                        'assets/icons/leader.png',
                        height: 85.h,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.leaderboard_rounded,
                          size: 60.sp,
                          color: const Color(0xFFAB31DE),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20.h),

                  // Heading
                  Text(
                    'No Active Leaderboard',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  // Description
                  Text(
                    'There is currently no active leaderboard cycle running. Stay tuned! New exciting reward tournaments will start soon.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // History Action Chip
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BattleLeaderboardHistoryScreen(userId: widget.userId),
                        ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: const Color(0xFFAB31DE),
                            size: 16.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'View Past Cycle Winners',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 12.5.sp,
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

            SizedBox(height: 24.h),

            // Refresh / Check Again Button
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                setState(() {
                  _leaderboardFuture = BattleArenaService.instance.fetchWeeklyLeaderboard(widget.userId);
                });
                await _leaderboardFuture;
              },
              child: Container(
                width: double.infinity,
                height: 50.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Check Again',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
            // 1. Scrollable Main Content
            Positioned.fill(
              child: FutureBuilder<List<dynamic>>(
                future: _leaderboardFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLeaderboardShimmer();
                  }

                  final bool isLeaderboardActive = BattleArenaService.instance.isLeaderboardActive;
                  final standings = snapshot.data ?? [];
                  final List<dynamic> tiers = BattleArenaService.instance.rewardTiers;

                  // If no leaderboard is active
                  if (!isLeaderboardActive) {
                    return _buildNoActiveLeaderboardState(
                      topPadding: topPadding,
                      bottomPadding: bottomPadding,
                    );
                  }

                  final String? endTime = BattleArenaService.instance.nextPayoutTime;
                  final int cycleDays = BattleArenaService.instance.cycleDays;
                  final bool showWinnersOnly = BattleArenaService.instance.showWinnersOnly;
                  final String rawTitle = BattleArenaService.instance.leaderboardTitle.trim();
                  final String headerTitle = rawTitle.isNotEmpty && rawTitle.toLowerCase() != 'null'
                      ? rawTitle
                      : (cycleDays == 1
                          ? 'Daily Leaderboard'
                          : (cycleDays == 30 ? 'Monthly Leaderboard' : 'Weekly Leaderboard'));

                  // Podium rankers
                  final rank1 = standings.firstWhere((p) => p['rank'] == 1, orElse: () => null);
                  final rank2 = standings.firstWhere((p) => p['rank'] == 2, orElse: () => null);
                  final rank3 = standings.firstWhere((p) => p['rank'] == 3, orElse: () => null);
                  final restRankers = standings.where((p) => (p['rank'] ?? 0) > 3).toList();

                  // Podium rewards
                  final t1 = tiers.firstWhere((t) => t['rankStart'] == 1 && t['rankEnd'] == 1, orElse: () => null);
                  final t2 = tiers.firstWhere((t) => t['rankStart'] == 2 && t['rankEnd'] == 2, orElse: () => null);
                  final t3 = tiers.firstWhere((t) => t['rankStart'] == 3 && t['rankEnd'] == 3, orElse: () => null);

                  final r1Custom = t1?['customText']?.toString().trim();
                  final r2Custom = t2?['customText']?.toString().trim();
                  final r3Custom = t3?['customText']?.toString().trim();

                  final r1Text = (r1Custom != null && r1Custom.isNotEmpty)
                      ? r1Custom
                      : (t1 != null ? _formatCoins(t1['coins']) : '0');
                  final r2Text = (r2Custom != null && r2Custom.isNotEmpty)
                      ? r2Custom
                      : (t2 != null ? _formatCoins(t2['coins']) : '0');
                  final r3Text = (r3Custom != null && r3Custom.isNotEmpty)
                      ? r3Custom
                      : (t3 != null ? _formatCoins(t3['coins']) : '0');

                  final r1Icon = t1?['iconUrl']?.toString().trim();
                  final r2Icon = t2?['iconUrl']?.toString().trim();
                  final r3Icon = t3?['iconUrl']?.toString().trim();

                  return RefreshIndicator(
                    color: const Color(0xFFAB31DE),
                    backgroundColor: Colors.white,
                    edgeOffset: topPadding + 60.h,
                    onRefresh: () async {
                      setState(() {
                        _leaderboardFuture = BattleArenaService.instance.fetchWeeklyLeaderboard(widget.userId);
                      });
                      await _leaderboardFuture;
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        topPadding + 8.h,
                        16.w,
                        bottomPadding + 90.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top Navigation Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
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

                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BattleLeaderboardHistoryScreen(userId: widget.userId),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 40.w,
                                  height: 40.w,
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
                                  child: Center(
                                    child: Icon(
                                      Icons.history_rounded,
                                      color: const Color(0xFFAB31DE),
                                      size: 21.sp,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 12.h),

                          // Top Graphic Hero Banner
                          _buildTopHeroBanner(headerTitle),

                          SizedBox(height: 16.h),

                          // Segmented Tab Switcher
                          _buildSegmentedTabBar(),

                          SizedBox(height: 20.h),

                          // Top Section: Instruction Banner (Tab 0) vs Top 3 Podium Cards (Tab 1)
                          if (_activeTab == 0) ...[
                            _buildLeaderboardInstructionBanner(endTime: endTime),
                          ] else ...[
                            _buildTopThreePodium(
                              rank1: rank1,
                              rank2: rank2,
                              rank3: rank3,
                              reward1: r1Text,
                              reward2: r2Text,
                              reward3: r3Text,
                              rewardIcon1: r1Icon,
                              rewardIcon2: r2Icon,
                              rewardIcon3: r3Icon,
                              isPrizePool: false,
                              showWinnersOnly: showWinnersOnly,
                            ),
                          ],

                          SizedBox(height: 16.h),

                          // Countdown Timer Pill Row (Only visible on Leaderboard tab)
                          if (_activeTab == 1 && endTime != null) ...[
                            _LeaderboardCountdownPill(endTimeStr: endTime),
                            SizedBox(height: 18.h),
                          ],

                          // Tab Content: Reward Tiers Breakdown (Tab 0) vs Leaderboard Standings (Tab 1)
                          if (_activeTab == 0) ...[
                            _buildRewardTiersSection(tiers),
                          ] else ...[
                            // Table Header
                            _buildTableHeader(),

                            SizedBox(height: 8.h),

                            // Rank 4+ List
                            if (restRankers.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: restRankers.length,
                                itemBuilder: (context, index) {
                                  final item = restRankers[index];
                                  final int rankNum = item['rank'] ?? (index + 4);
                                  final tierMatch = _getRewardTierForRank(rankNum, tiers);
                                  final int rwCoins = (tierMatch?['coins'] as num?)?.toInt() ?? 0;
                                  final String? rwIcon = tierMatch?['iconUrl']?.toString().trim();
                                  final String? rwCustomText = tierMatch?['customText']?.toString().trim();

                                  return _buildRankListItem(
                                    rankNum,
                                    item,
                                    rwCoins,
                                    showWinnersOnly,
                                    rwIcon: rwIcon,
                                    rwCustomText: rwCustomText,
                                  );
                                },
                              )
                            else
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.h),
                                child: Text(
                                  'No rankers active yet.',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 2. Fixed Bottom "You" Rank Sticky Bar (Only visible on Leaderboard tab when active)
            if (_activeTab == 1 && BattleArenaService.instance.isLeaderboardActive)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
              child: FutureBuilder<List<dynamic>>(
                future: _leaderboardFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !BattleArenaService.instance.isLeaderboardActive) return const SizedBox.shrink();
                  final standings = snapshot.data!;
                  final idx = standings.indexWhere((p) => p['userId']?.toString() == widget.userId);
                  if (idx == -1) return const SizedBox.shrink();

                  final myUserObj = standings[idx];
                  final int myRank = myUserObj['rank'] ?? (idx + 1);
                  final String myName = myUserObj['userName']?.toString() ?? 'You';
                  final String myPhoto = myUserObj['avatar']?.toString() ?? '';
                  final int myPoints = myUserObj['totalSpeedPoints'] ?? 0;

                  final int myWins = myUserObj['winsCount'] ?? 0;
                  final bool isWinnersOnly = BattleArenaService.instance.showWinnersOnly;

                  return _buildUserStickyRankBar(
                    userRank: myRank,
                    userName: myName,
                    photoUrl: myPhoto,
                    score: myPoints,
                    winsCount: myWins,
                    showWinnersOnly: isWinnersOnly,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// COUNTDOWN TIMER PILL ROW ("⏱️ 11:59:59")
// -------------------------------------------------------------
class _LeaderboardCountdownPill extends StatefulWidget {
  const _LeaderboardCountdownPill({required this.endTimeStr});
  final String endTimeStr;

  @override
  State<_LeaderboardCountdownPill> createState() => _LeaderboardCountdownPillState();
}

class _LeaderboardCountdownPillState extends State<_LeaderboardCountdownPill> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateTimeLeft();
        });
      }
    });
  }

  void _calculateTimeLeft() {
    try {
      final end = DateTime.parse(widget.endTimeStr).toLocal();
      final diff = end.difference(DateTime.now());
      _timeLeft = diff.isNegative ? Duration.zero : diff;
    } catch (e) {
      _timeLeft = Duration.zero;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours.remainder(24);
    final minutes = _timeLeft.inMinutes.remainder(60);
    final seconds = _timeLeft.inSeconds.remainder(60);

    final String timerString = days > 0
        ? '${days}d : ${hours.toString().padLeft(2, '0')}h : ${minutes.toString().padLeft(2, '0')}m : ${seconds.toString().padLeft(2, '0')}s'
        : '${hours.toString().padLeft(2, '0')}h : ${minutes.toString().padLeft(2, '0')}m : ${seconds.toString().padLeft(2, '0')}s';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
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
            size: 14.sp,
          ),
          SizedBox(width: 5.w),
          Text(
            timerString,
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// GOLDEN CROWN PAINTER
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
// HEXAGON BADGE WIDGET & PAINTER
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
