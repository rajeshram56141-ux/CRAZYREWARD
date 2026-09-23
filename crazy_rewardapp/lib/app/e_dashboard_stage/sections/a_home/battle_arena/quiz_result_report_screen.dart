import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../../services/local_storage.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../../widgets/common/internet_image.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import '../../../../../../services/analytics_service.dart';

class QuizResultReportScreen extends ConsumerWidget {
  const QuizResultReportScreen({
    super.key,
    required this.userId,
    required this.matchId,
    required this.isWinner,
    required this.myPoints,
    required this.opponentPoints,
    required this.correctCount,
    required this.wrongCount,
    required this.skippedCount,
    required this.totalTimeTakenSec,
    required this.totalQuestions,
    required this.prizeAwarded,
    this.entryFeeCoins = 0,
    this.opponentCorrectCount = 0,
    this.opponentWrongCount = 0,
    this.opponentSkippedCount = 0,
    this.opponentTotalTimeTakenSec = 0,
    this.myName = 'You',
    this.myAvatar = '',
    this.opponentName = 'Opponent',
    this.opponentAvatar = '',
    this.players = const [],
    this.referralCode = '',
  });

  final String userId;
  final String matchId;
  final bool isWinner;
  final int myPoints;
  final int opponentPoints;
  final int correctCount;
  final int wrongCount;
  final int skippedCount;
  final int totalTimeTakenSec;
  final int totalQuestions;
  final int prizeAwarded;
  final int entryFeeCoins;
  final int opponentCorrectCount;
  final int opponentWrongCount;
  final int opponentSkippedCount;
  final int opponentTotalTimeTakenSec;
  final String myName;
  final String myAvatar;
  final String opponentName;
  final String opponentAvatar;
  final List<dynamic> players;
  final String referralCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LocalStorage.setFreeBattleAdPass(false);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    AnalyticsService.logScreenView('QuizResultReportScreen');

    final userAsync = ref.watch(DashboardService.userDataProvider(userId));
    final String activeReferralCode = referralCode.isNotEmpty
        ? referralCode
        : (userAsync.value?.referralCode ?? '');

    final double accuracy = totalQuestions > 0
        ? ((correctCount / totalQuestions) * 100).clamp(0.0, 100.0)
        : 0.0;

    final int totalAnswered = correctCount + wrongCount + skippedCount;
    final double avgSpeedSec =
        totalAnswered > 0 ? (totalTimeTakenSec / totalAnswered) : 0.0;

    // Prepare participants list
    final List<Map<String, dynamic>> ranks = [];
    if (players.isNotEmpty) {
      for (int i = 0; i < players.length; i++) {
        final p = players[i];
        ranks.add({
          'rank': i + 1,
          'name': p['name']?.toString() ?? 'Player',
          'avatar': p['avatar']?.toString() ?? '',
          'points': p['score'] is num ? (p['score'] as num).toInt() : 0,
          'isMe': p['isMe'] == true || p['userId']?.toString() == userId,
          'correct':
              p['correctCount'] is num ? (p['correctCount'] as num).toInt() : 0,
          'wrong':
              p['wrongCount'] is num ? (p['wrongCount'] as num).toInt() : 0,
          'skipped':
              p['skippedCount'] is num ? (p['skippedCount'] as num).toInt() : 0,
          'time': p['totalTimeTakenSec'] is num
              ? (p['totalTimeTakenSec'] as num).toInt()
              : 0,
          'prizeAwarded':
              p['prizeAwarded'] is num ? (p['prizeAwarded'] as num).toInt() : 0,
        });
      }
    } else {
      if (myPoints >= opponentPoints) {
        ranks.add({
          'rank': 1,
          'name': myName,
          'avatar': myAvatar,
          'points': myPoints,
          'isMe': true,
          'correct': correctCount,
          'wrong': wrongCount,
          'skipped': skippedCount,
          'time': totalTimeTakenSec,
          'prizeAwarded': prizeAwarded,
        });
        ranks.add({
          'rank': 2,
          'name': opponentName,
          'avatar': opponentAvatar,
          'points': opponentPoints,
          'isMe': false,
          'correct': opponentCorrectCount,
          'wrong': opponentWrongCount,
          'skipped': opponentSkippedCount,
          'time': opponentTotalTimeTakenSec,
          'prizeAwarded': 0,
        });
      } else {
        ranks.add({
          'rank': 1,
          'name': opponentName,
          'avatar': opponentAvatar,
          'points': opponentPoints,
          'isMe': false,
          'correct': opponentCorrectCount,
          'wrong': opponentWrongCount,
          'skipped': opponentSkippedCount,
          'time': opponentTotalTimeTakenSec,
          'prizeAwarded': prizeAwarded,
        });
        ranks.add({
          'rank': 2,
          'name': myName,
          'avatar': myAvatar,
          'points': myPoints,
          'isMe': true,
          'correct': correctCount,
          'wrong': wrongCount,
          'skipped': skippedCount,
          'time': totalTimeTakenSec,
          'prizeAwarded': 0,
        });
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 10.h),

            // Top Navigation Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PopScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).maybePop();
                    },
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFF26262B),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: const Color(0xFF26262B),
                        size: 18.sp,
                      ),
                    ),
                  ),
                  Text(
                    'Match Summary',
                    style: GoogleFonts.kaushanScript(
                      color: const Color(0xFF26262B),
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  _PopScaleButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _handleShareResult(
                        context: context,
                        activeReferralCode: activeReferralCode,
                        accuracy: accuracy,
                        avgSpeedSec: avgSpeedSec,
                      );
                    },
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFF26262B),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.share_rounded,
                        color: const Color(0xFF26262B),
                        size: 18.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12.h),

            // Scrollable Body Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    // 1. Dual Clash Arena Hero Card (1v1 Layout)
                    _buildDuelClashCard(context),

                    SizedBox(height: 14.h),

                    // 2. Performance Analytics Dashboard (3-Metric Grid)
                    _buildPerformanceGrid(accuracy, avgSpeedSec),

                    SizedBox(height: 14.h),

                    // 3. Question Breakdown Visual Segment Bar
                    _buildBreakdownSegmentCard(),

                    SizedBox(height: 16.h),

                    // 4. Leaderboard Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28.w,
                              height: 28.w,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF26262B), Color(0xFF18181B)],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.emoji_events_rounded,
                                color: const Color(0xFFF59E0B),
                                size: 15.sp,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'MATCH LEADERBOARD',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF26262B),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${ranks.length} Players',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10.h),

                    // 5. Participant Standings Cards
                    ...ranks.map((r) => _buildParticipantCard(context, r)),

                    SizedBox(height: 14.h),

                    // 6. In-Page Interactive Share Match Card
                    _buildShareMatchCard(
                      context: context,
                      activeReferralCode: activeReferralCode,
                      accuracy: accuracy,
                      avgSpeedSec: avgSpeedSec,
                    ),

                    SizedBox(height: 16.h),

                    // 7. Return to Arena Bottom Action
                    _PopScaleButton(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.of(context).maybePop();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 50.h,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF26262B), Color(0xFF18181B)],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF26262B).withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sports_esports_rounded,
                                color: const Color(0xFFFCD34D), size: 20.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'BACK TO BATTLE ARENA',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. DUAL CLASH ARENA HERO CARD (NEW 1v1 LAYOUT)
  // ---------------------------------------------------------------------------
  Widget _buildDuelClashCard(BuildContext context) {
    final Color outcomeColor =
        isWinner ? const Color(0xFF059669) : const Color(0xFFE11D48);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isWinner ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isWinner ? const Color(0xFF10B981) : Colors.black).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Outcome Status Ribbon
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: isWinner ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              border: Border(
                bottom: BorderSide(
                  color: isWinner ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isWinner ? Icons.emoji_events_rounded : Icons.military_tech_rounded,
                      color: outcomeColor,
                      size: 18.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      isWinner ? 'VICTORY MATCH' : 'BATTLE FINISHED',
                      style: GoogleFonts.poppins(
                        color: outcomeColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                // Coin Pill Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF26262B), Color(0xFF18181B)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/coin.png',
                        width: 13.w,
                        height: 13.w,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        isWinner ? '+$prizeAwarded COINS' : '-$entryFeeCoins COINS',
                        style: GoogleFonts.poppins(
                          color: isWinner ? const Color(0xFFFCD34D) : const Color(0xFFFCA5A5),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 1v1 Clash Avatar Duel Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Player 1 (You)
                _buildDuelPlayerColumn(
                  name: myName.isNotEmpty ? myName : 'You',
                  avatar: myAvatar,
                  score: myPoints,
                  isWinner: isWinner,
                  isMe: true,
                ),

                // Center VS Clash Badge
                Column(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF26262B), Color(0xFF18181B)],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFCD34D),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF26262B).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'VS',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFCD34D),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'CLASH',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),

                // Player 2 (Opponent)
                _buildDuelPlayerColumn(
                  name: opponentName.isNotEmpty ? opponentName : 'Opponent',
                  avatar: opponentAvatar,
                  score: opponentPoints,
                  isWinner: !isWinner && (players.isNotEmpty ? false : true),
                  isMe: false,
                ),
              ],
            ),
          ),

          // Subtitle Message Banner
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
            child: Text(
              isWinner
                  ? '🏆 Outstanding performance! You defeated your opponent!'
                  : '⚔️ You put up a fierce fight! Better luck in the next battle round!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuelPlayerColumn({
    required String name,
    required String avatar,
    required int score,
    required bool isWinner,
    required bool isMe,
  }) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(2.5.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isWinner
                    ? const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                      ),
                boxShadow: isWinner
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: 28.r,
                backgroundColor: const Color(0xFFF8FAFC),
                child: avatar.isNotEmpty && avatar != 'null'
                    ? AvatarInternetImage(url: avatar, size: 56)
                    : Icon(
                        Icons.person_rounded,
                        color: const Color(0xFF26262B),
                        size: 26.sp,
                      ),
              ),
            ),
            if (isWinner)
              Positioned(
                top: -9.h,
                child: Image.asset(
                  'assets/icons/trophy-cup.png',
                  width: 18.w,
                  height: 18.w,
                ),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        SizedBox(
          width: 90.w,
          child: Text(
            name + (isMe ? ' (You)' : ''),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: 3.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            '$score Pts',
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PERFORMANCE 3-GRID METRIC DASHBOARD
  // ---------------------------------------------------------------------------
  Widget _buildPerformanceGrid(double accuracy, double avgSpeedSec) {
    return Row(
      children: [
        // Metric 1: Accuracy
        Expanded(
          child: _buildMetricCard(
            title: 'ACCURACY',
            value: '${accuracy.toInt()}%',
            icon: Icons.track_changes_rounded,
            accentColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFF0FDF4),
          ),
        ),
        SizedBox(width: 8.w),
        // Metric 2: Avg Speed
        Expanded(
          child: _buildMetricCard(
            title: 'AVG SPEED',
            value: '${avgSpeedSec.toStringAsFixed(1)}s',
            icon: Icons.timer_outlined,
            accentColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
        SizedBox(width: 8.w),
        // Metric 3: Score Ratio
        Expanded(
          child: _buildMetricCard(
            title: 'CORRECT',
            value: '$correctCount / $totalQuestions',
            icon: Icons.check_circle_outline_rounded,
            accentColor: const Color(0xFF26262B),
            bgColor: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 20.sp),
          SizedBox(height: 5.h),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. ANSWER BREAKDOWN VISUAL SEGMENT BAR (NEW LAYOUT)
  // ---------------------------------------------------------------------------
  Widget _buildBreakdownSegmentCard() {
    final int safeTotal = totalQuestions > 0 ? totalQuestions : 1;
    final double correctFlex = (correctCount / safeTotal).clamp(0.0, 1.0);
    final double wrongFlex = (wrongCount / safeTotal).clamp(0.0, 1.0);
    final double skippedFlex = (skippedCount / safeTotal).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'QUESTION BREAKDOWN',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF26262B),
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '$totalQuestions Total Qs',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: SizedBox(
              height: 8.h,
              child: Row(
                children: [
                  if (correctFlex > 0)
                    Expanded(
                      flex: (correctFlex * 100).toInt(),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (wrongFlex > 0)
                    Expanded(
                      flex: (wrongFlex * 100).toInt(),
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                  if (skippedFlex > 0)
                    Expanded(
                      flex: (skippedFlex * 100).toInt(),
                      child: Container(color: const Color(0xFF3B82F6)),
                    ),
                  if (correctFlex == 0 && wrongFlex == 0 && skippedFlex == 0)
                    Expanded(
                      child: Container(color: const Color(0xFFE2E8F0)),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          // Legend Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendChip(
                label: 'Correct',
                count: correctCount,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFF0FDF4),
              ),
              _buildLegendChip(
                label: 'Wrong',
                count: wrongCount,
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
              ),
              _buildLegendChip(
                label: 'Skipped',
                count: skippedCount,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChip({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            '$label: $count',
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. PARTICIPANT LEADERBOARD CARD
  // ---------------------------------------------------------------------------
  Widget _buildParticipantCard(
      BuildContext context, Map<String, dynamic> rankData) {
    final int rank = rankData['rank'] as int;
    final String name = rankData['name'] as String;
    final String avatar = rankData['avatar'] as String;
    final int points = rankData['points'] as int;
    final bool isMe = rankData['isMe'] as bool;
    final int pCoins = rankData['prizeAwarded'] is num
        ? (rankData['prizeAwarded'] as num).toInt()
        : 0;

    final Color cardBorderColor =
        rank == 1 ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: cardBorderColor,
            width: rank == 1 ? 1.5 : 1.1,
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
          children: [
            // Rank Pill
            Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: rank == 1
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: rank == 1
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFCBD5E1),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: GoogleFonts.poppins(
                    color: rank == 1
                        ? const Color(0xFFD97706)
                        : const Color(0xFF26262B),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            // Avatar
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 19.r,
                  backgroundColor: const Color(0xFFF1F5F9),
                  child: avatar.isNotEmpty && avatar != 'null'
                      ? AvatarInternetImage(
                          url: avatar,
                          size: 34,
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: const Color(0xFF26262B),
                          size: 18.sp,
                        ),
                ),
                if (rank == 1)
                  Positioned(
                    top: -9.h,
                    child: Image.asset(
                      'assets/icons/trophy-cup.png',
                      width: 15.w,
                      height: 15.w,
                    ),
                  ),
              ],
            ),
            SizedBox(width: 10.w),
            // Name & Score
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name + (isMe ? ' (You)' : ''),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26262B),
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text(
                        '$points Pts',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF26262B),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Image.asset(
                        'assets/icons/coin.png',
                        width: 12.w,
                        height: 12.w,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        pCoins > 0 ? '+$pCoins' : '-$entryFeeCoins',
                        style: GoogleFonts.poppins(
                          color: pCoins > 0
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // View Stats Action Button
            _PopScaleButton(
              onTap: () => _showStatsBottomSheet(context, rankData),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF26262B), Color(0xFF18181B)],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF26262B).withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'View Stats',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10.sp,
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

  // ---------------------------------------------------------------------------
  // 5. IN-PAGE SHARE MATCH CARD
  // ---------------------------------------------------------------------------
  Widget _buildShareMatchCard({
    required BuildContext context,
    required String activeReferralCode,
    required double accuracy,
    required double avgSpeedSec,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
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
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF26262B), Color(0xFF18181B)],
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: const Color(0xFFFCD34D),
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Challenge Your Friends',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF26262B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Share your match score & invite friends with your referral link!',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          _PopScaleButton(
            onTap: () => _handleShareResult(
              context: context,
              activeReferralCode: activeReferralCode,
              accuracy: accuracy,
              avgSpeedSec: avgSpeedSec,
            ),
            child: Container(
              width: double.infinity,
              height: 46.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF26262B), Color(0xFF18181B)],
                ),
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF26262B).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'SHARE RESULT WITH FRIENDS',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARE RESULT HANDLER
  // ---------------------------------------------------------------------------
  void _handleShareResult({
    required BuildContext context,
    required String activeReferralCode,
    required double accuracy,
    required double avgSpeedSec,
  }) {
    HapticFeedback.mediumImpact();
    final String refCode = activeReferralCode.trim();
    final String referralLink = refCode.isNotEmpty
        ? '${AppConst.appBaseUrl}${SplashService.packageName}&referrer=$refCode'
        : 'https://play.google.com/store/apps/details?id=${SplashService.packageName}';

    final String statusHeader = isWinner
        ? '🏆 I just WON a 1v1 Quiz Battle in Crazyreward!'
        : '⚔️ I just played an intense 1v1 Quiz Battle in Crazyreward!';

    final String prizeText = (isWinner && prizeAwarded > 0)
        ? '\n💰 Prize Won: +$prizeAwarded Coins'
        : (entryFeeCoins > 0 ? '\n🎟️ Battle Entry: $entryFeeCoins Coins' : '');

    final String refText = refCode.isNotEmpty
        ? '\n🎁 Join using my Referral Code: $refCode for instant bonus coins!'
        : '';

    final String shareMessage = '''$statusHeader

🎯 My Match Score: $myPoints Pts
📊 Accuracy: ${accuracy.toStringAsFixed(0)}% ($correctCount/$totalQuestions Correct)
⏱️ Avg Answer Speed: ${avgSpeedSec.toStringAsFixed(1)}s / question$prizeText

🔥 Can you beat my score? Challenge me in Crazyreward Quiz Battle Arena!$refText

📲 Download & Play now: $referralLink''';

    Share.share(
      shareMessage,
      subject: '⚔️ Crazyreward Quiz Battle Match Result',
    );
  }

  // ---------------------------------------------------------------------------
  // 6. STATS MODAL SHEET
  // ---------------------------------------------------------------------------
  void _showStatsBottomSheet(
      BuildContext context, Map<String, dynamic> rankData) {
    final int rank = rankData['rank'] as int? ?? 1;
    final String name = rankData['name'] as String? ?? 'Player';
    final int points = rankData['points'] as int? ?? 0;
    final int correct = rankData['correct'] as int? ?? 0;
    final int wrong = rankData['wrong'] as int? ?? 0;
    final int skipped = rankData['skipped'] as int? ?? 0;
    final int time = rankData['time'] as int? ?? 0;
    final String avatar = rankData['avatar']?.toString() ?? '';
    final bool isMe = rankData['isMe'] == true;

    final int totalAnswered = correct + wrong + skipped;
    final String avgTimeStr = totalAnswered > 0
        ? '${(time / totalAnswered).toStringAsFixed(1)}s'
        : '0.0s';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (modalCtx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
                // Drag handle bar
                Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 14.h),

                // Sheet Header with Title & Close Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32.w,
                            height: 32.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF26262B), Color(0xFF18181B)],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.analytics_rounded,
                              color: const Color(0xFFFCD34D),
                              size: 16.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Player Statistics',
                            style: GoogleFonts.kaushanScript(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF26262B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      _PopScaleButton(
                        onTap: () => Navigator.of(modalCtx).pop(),
                        child: Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close_rounded,
                            color: const Color(0xFF26262B),
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 14.h),

                // Player Profile Hero Banner
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: rank == 1
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFE2E8F0),
                        width: rank == 1 ? 1.4 : 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(2.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: rank == 1
                                    ? const LinearGradient(
                                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFF26262B), Color(0xFF18181B)],
                                      ),
                              ),
                              child: CircleAvatar(
                                radius: 24.r,
                                backgroundColor: Colors.white,
                                child: avatar.isNotEmpty && avatar != 'null'
                                    ? AvatarInternetImage(
                                        url: avatar,
                                        size: 48,
                                      )
                                    : Icon(
                                        Icons.person_rounded,
                                        color: const Color(0xFF26262B),
                                        size: 24.sp,
                                      ),
                              ),
                            ),
                            if (rank == 1)
                              Positioned(
                                top: -8.h,
                                child: Image.asset(
                                  'assets/icons/trophy-cup.png',
                                  width: 16.w,
                                  height: 16.w,
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name + (isMe ? ' (You)' : ''),
                                style: GoogleFonts.poppins(
                                  fontSize: 14.5.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF26262B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Match Rank #$rank • $points Pts Scored',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF26262B), Color(0xFF18181B)],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            '#$rank',
                            style: GoogleFonts.poppins(
                              color: rank == 1 ? const Color(0xFFFCD34D) : Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 14.h),

                // 2x2 Stats Matrix Cards
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridStatTile(
                              label: 'Total Score',
                              value: '$points Pts',
                              icon: Icons.emoji_events_rounded,
                              iconColor: const Color(0xFFD97706),
                              bgColor: const Color(0xFFFFFBEB),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _buildGridStatTile(
                              label: 'Correct Answers',
                              value: '$correct Qs',
                              icon: Icons.check_circle_rounded,
                              iconColor: const Color(0xFF10B981),
                              bgColor: const Color(0xFFF0FDF4),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridStatTile(
                              label: 'Wrong Answers',
                              value: '$wrong Qs',
                              icon: Icons.cancel_rounded,
                              iconColor: const Color(0xFFEF4444),
                              bgColor: const Color(0xFFFEF2F2),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _buildGridStatTile(
                              label: 'Skipped Answers',
                              value: '$skipped Qs',
                              icon: Icons.skip_next_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              bgColor: const Color(0xFFEFF6FF),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      // Average Speed Tile
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32.w,
                                  height: 32.w,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF26262B), Color(0xFF18181B)],
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.timer_rounded,
                                    color: Colors.white,
                                    size: 16.sp,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  'Average Response Speed',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF64748B),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              avgTimeStr,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF26262B),
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                // Close Action Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _PopScaleButton(
                    onTap: () => Navigator.of(modalCtx).pop(),
                    child: Container(
                      width: double.infinity,
                      height: 48.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF26262B), Color(0xFF18181B)],
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF26262B).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'CLOSE',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridStatTile({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
// POP SCALE BUTTON WIDGET
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

class _PopScaleButtonState extends State<_PopScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
