import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../../services/local_storage.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../../widgets/common/custom_toast.dart';
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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    AnalyticsService.logScreenView('QuizResultReportScreen');

    final userAsync = ref.watch(DashboardService.userDataProvider(userId));
    final String activeReferralCode = referralCode.isNotEmpty
        ? referralCode
        : (userAsync.value?.referralCode ?? '');

    final double accuracy = totalQuestions > 0
        ? ((correctCount / totalQuestions) * 100).clamp(0.0, 100.0)
        : 0.0;

    final int totalAnswered = correctCount + wrongCount + skippedCount;
    final double avgSpeedSec = totalAnswered > 0 ? (totalTimeTakenSec / totalAnswered) : 0.0;

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
          'correct': p['correctCount'] is num ? (p['correctCount'] as num).toInt() : 0,
          'wrong': p['wrongCount'] is num ? (p['wrongCount'] as num).toInt() : 0,
          'skipped': p['skippedCount'] is num ? (p['skippedCount'] as num).toInt() : 0,
          'time': p['totalTimeTakenSec'] is num ? (p['totalTimeTakenSec'] as num).toInt() : 0,
          'prizeAwarded': p['prizeAwarded'] is num ? (p['prizeAwarded'] as num).toInt() : 0,
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 8.h),

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
                          width: 38.w,
                          height: 38.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFAF5FF),
                            border: Border.all(
                              color: const Color(0xFFF3E8FF),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: const Color(0xFFAB31DE),
                            size: 20.sp,
                          ),
                        ),
                      ),
                      Text(
                        'Match Summary',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
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
                          width: 38.w,
                          height: 38.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFAF5FF),
                            border: Border.all(
                              color: const Color(0xFFF3E8FF),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.share_rounded,
                            color: const Color(0xFFAB31DE),
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
                        // Victory / Defeat Header Card
                        _buildOutcomeHeader(context),

                        SizedBox(height: 20.h),

                        // Performance 3-Grid Metric Cards
                        _buildPerformanceGrid(accuracy, avgSpeedSec),

                        SizedBox(height: 20.h),

                        // Participant Standings Header Tag
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
                            child: Text(
                              'MATCH LEADERBOARD',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFAB31DE),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),

                        // Participant Rank Cards
                        ...ranks.map((r) => _buildParticipantCard(context, r)),

                        SizedBox(height: 16.h),

                        // In-Page Interactive Share Match Result Card
                        _buildShareMatchCard(
                          context: context,
                          activeReferralCode: activeReferralCode,
                          accuracy: accuracy,
                          avgSpeedSec: avgSpeedSec,
                        ),

                        SizedBox(height: 24.h),
                      ],
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
  // IN-PAGE SHARE MATCH CARD
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
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
            blurRadius: 16,
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
                  color: Color(0xFFFAF5FF),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: const Color(0xFFAB31DE),
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
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
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
              height: 44.h,
              decoration: BoxDecoration(
                color: const Color(0xFFAB31DE),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 16.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'SHARE RESULT WITH FRIENDS',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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
  // 1. OUTCOME HEADER BANNER
  // ---------------------------------------------------------------------------
  Widget _buildOutcomeHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 22.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isWinner ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Emoji / Icon Badge Container
          Container(
            width: 74.w,
            height: 74.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isWinner ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              border: Border.all(
                color: isWinner ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isWinner ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.20),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/icons/smile.png',
                width: 46.w,
                height: 46.w,
                fit: BoxFit.contain,
              ),
            ),
          ),

          SizedBox(height: 12.h),

          // Victory / Good Try Title
          Text(
            isWinner ? 'VICTORY!' : 'GOOD TRY!',
            style: GoogleFonts.outfit(
              fontSize: 26.sp,
              fontWeight: FontWeight.w900,
              color: isWinner ? const Color(0xFF059669) : const Color(0xFFE11D48),
              letterSpacing: 2.0,
            ),
          ),

          SizedBox(height: 4.h),

          // Subtitle Message
          Text(
            isWinner
                ? 'Outstanding performance! You won the battle match!'
                : 'You gave a tough fight! Better luck in the next round!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),

          SizedBox(height: 10.h),

          // Prize / Penalty Pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isWinner ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isWinner ? const Color(0xFFFCD34D) : const Color(0xFFFCA5A5),
                width: 1.1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/coin.png',
                  width: 15.w,
                  height: 15.w,
                ),
                SizedBox(width: 6.w),
                Text(
                  isWinner ? '+$prizeAwarded COINS' : '-$entryFeeCoins COINS',
                  style: GoogleFonts.outfit(
                    color: isWinner ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PERFORMANCE 4-GRID DASHBOARD
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
        SizedBox(width: 10.w),
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
        SizedBox(width: 10.w),
        // Metric 3: Correct
        Expanded(
          child: _buildMetricCard(
            title: 'CORRECT',
            value: '$correctCount / $totalQuestions',
            icon: Icons.check_circle_outline_rounded,
            accentColor: const Color(0xFFAB31DE),
            bgColor: const Color(0xFFFAF5FF),
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
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.30),
          width: 1.0,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 20.sp),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. PARTICIPANT LEADERBOARD CARD
  // ---------------------------------------------------------------------------
  Widget _buildParticipantCard(BuildContext context, Map<String, dynamic> rankData) {
    final int rank = rankData['rank'] as int;
    final String name = rankData['name'] as String;
    final String avatar = rankData['avatar'] as String;
    final int points = rankData['points'] as int;
    final bool isMe = rankData['isMe'] as bool;
    final int pCoins = rankData['prizeAwarded'] is num ? (rankData['prizeAwarded'] as num).toInt() : 0;

    final Color cardBorderColor = rank == 1 ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: cardBorderColor,
            width: rank == 1 ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFAB31DE).withValues(alpha: 0.05),
              blurRadius: 10,
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
                color: rank == 1 ? const Color(0xFFFFFBEB) : const Color(0xFFFAF5FF),
                border: Border.all(
                  color: rank == 1 ? const Color(0xFFF59E0B) : const Color(0xFFF3E8FF),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: GoogleFonts.outfit(
                    color: rank == 1 ? const Color(0xFFD97706) : const Color(0xFFAB31DE),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
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
                  backgroundColor: const Color(0xFFFAF5FF),
                  child: avatar.isNotEmpty && avatar != 'null'
                      ? AvatarInternetImage(
                          url: avatar,
                          size: 34,
                        )
                      : Icon(Icons.person_rounded, color: const Color(0xFFAB31DE), size: 18.sp),
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
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text(
                        '$points Pts',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
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
                        style: GoogleFonts.outfit(
                          color: pCoins > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // View Stats Glossy Action Button
            _PopScaleButton(
              onTap: () => _showStatsBottomSheet(context, rankData),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: const Color(0xFFF3E8FF),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  'View Stats',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFAB31DE),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
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
  // 4. STATS MODAL SHEET
  // ---------------------------------------------------------------------------
  void _showStatsBottomSheet(BuildContext context, Map<String, dynamic> rankData) {
    final String name = rankData['name'] as String;
    final int points = rankData['points'] as int;
    final int correct = rankData['correct'] as int;
    final int wrong = rankData['wrong'] as int;
    final int skipped = rankData['skipped'] as int;
    final int time = rankData['time'] as int;
    final String avatar = rankData['avatar']?.toString() ?? '';

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
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
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
                SizedBox(height: 16.h),

                // Avatar
                Container(
                  padding: EdgeInsets.all(2.r),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFAF5FF),
                  ),
                  child: CircleAvatar(
                    radius: 34.r,
                    backgroundColor: const Color(0xFFFAF5FF),
                    child: avatar.isNotEmpty && avatar != 'null'
                        ? AvatarInternetImage(
                            url: avatar,
                            size: 64,
                          )
                        : Icon(Icons.person_rounded, color: const Color(0xFFAB31DE), size: 32.sp),
                  ),
                ),
                SizedBox(height: 10.h),

                Text(
                  "${name.toUpperCase()}'S STATS",
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E1B4B),
                    letterSpacing: 0.8,
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                  child: Column(
                    children: [
                      _buildStatRow('Total Score', '$points Pts', Icons.emoji_events_rounded, const Color(0xFFD97706)),
                      _buildStatRow('Correct Answers', '$correct Qs', Icons.check_circle_rounded, const Color(0xFF10B981)),
                      _buildStatRow('Wrong Answers', '$wrong Qs', Icons.cancel_rounded, const Color(0xFFEF4444)),
                      _buildStatRow('Skipped Answers', '$skipped Qs', Icons.skip_next_rounded, const Color(0xFF3B82F6)),
                      _buildStatRow('Average Time / Q', avgTimeStr, Icons.timer_rounded, const Color(0xFFAB31DE)),

                      SizedBox(height: 20.h),

                      _PopScaleButton(
                        onTap: () => Navigator.of(modalCtx).pop(),
                        child: Container(
                          width: double.infinity,
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFAB31DE),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'CLOSE',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
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
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color iconColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18.sp),
              SizedBox(width: 10.w),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 13.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOM PAINTERS & BUTTON WIDGETS
// ---------------------------------------------------------------------------
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
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _FadingCardBorderPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _BottomSheetFadingBorderPainter extends CustomPainter {
  final double borderRadius;
  final Color borderColor;

  const _BottomSheetFadingBorderPainter({
    required this.borderRadius,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = borderRadius;

    final path = Path();
    path.moveTo(0, h);
    path.lineTo(0, r);
    path.arcToPoint(
      Offset(r, 0),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.lineTo(w - r, 0);
    path.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    path.lineTo(w, h);

    final rect = Offset.zero & size;
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BottomSheetFadingBorderPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.borderRadius != borderRadius;
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
