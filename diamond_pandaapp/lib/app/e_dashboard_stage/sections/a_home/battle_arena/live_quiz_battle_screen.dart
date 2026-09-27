import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../widgets/common/custom_toast.dart';
import '../../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../../services/local_storage.dart';
import 'battle_arena_provider.dart';
import 'quiz_result_report_screen.dart';
import '../../../provider/dashboard_provider.dart';
import '../../../../../widgets/common/internet_image.dart';
import '../../../../../../services/analytics_service.dart';

class LiveQuizBattleScreen extends ConsumerStatefulWidget {
  const LiveQuizBattleScreen({
    super.key,
    required this.userId,
    required this.matchId,
    required this.roomTitle,
    required this.questions,
    required this.opponentName,
    required this.opponentAvatar,
    this.matchDurationSec = 60,
  });

  final String userId;
  final String matchId;
  final String roomTitle;
  final List<dynamic> questions;
  final String opponentName;
  final String opponentAvatar;
  final int matchDurationSec;

  @override
  ConsumerState<LiveQuizBattleScreen> createState() => _LiveQuizBattleScreenState();
}

class _LiveQuizBattleScreenState extends ConsumerState<LiveQuizBattleScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _mySpeedScore = 0;
  int _opponentSpeedScore = 0;

  int _timerSeconds = 60;
  Timer? _matchTimer;
  Timer? _liveScorePollTimer;
  DateTime? _questionStartTime;

  int? _selectedOptionIndex;
  int? _correctOptionIndex;
  bool _isSubmitting = false;
  bool _isPreparingResult = false;
  bool _isFinishing = false;

  int _correctCount = 0;
  int _wrongCount = 0;
  int _skippedCount = 0;
  int _totalTimeTakenSec = 0;

  final List<Map<String, dynamic>> _floatingPopups = [];
  final List<Map<String, dynamic>> _opponentFloatingPopups = [];

  String? _opponentName;
  String? _opponentAvatar;
  String? _opponentUserId;
  final Map<String, int> _opponentsScores = {};

  bool _canExit = false;
  bool _isExitPopupShowing = false;

  @override
  void initState() {
    super.initState();
    LocalStorage.setFreeBattleAdPass(false);
    _opponentName = widget.opponentName;
    _opponentAvatar = widget.opponentAvatar;
    _opponentUserId = '';
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    WidgetsBinding.instance.addObserver(this);
    _timerSeconds = widget.matchDurationSec;
    _startMatchTimer();
    _startLiveScorePolling();
    _loadCurrentQuestion();
    AnalyticsService.logScreenView('LiveQuizBattleScreen');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchTimer?.cancel();
    _liveScorePollTimer?.cancel();
    super.dispose();
  }

  /// Anti-Cheat Lifecycle Observer: Auto-Forfeit on App Switch / Minimization
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // User switched apps to search answer on Google! Penalize question.
      if (!_isSubmitting && !_isPreparingResult) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App switch detected! Question forfeited.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3),
          ),
        );
        _handleAnswerSelection(-1); // Forfeit question
      }
    }
  }

  void _startMatchTimer() {
    _matchTimer?.cancel();
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timerSeconds > 1) {
        setState(() {
          _timerSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _timerSeconds = 0;
        });
        _finishMatchAndShowResults();
      }
    });
  }

  void _loadCurrentQuestion() {
    setState(() {
      _selectedOptionIndex = null;
      _correctOptionIndex = null;
      _isSubmitting = false;
    });
    _questionStartTime = DateTime.now();
  }

  Future<void> _handleAnswerSelection(int optionIndex) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _selectedOptionIndex = optionIndex;
    });

    final timeTakenMs = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds
        : 1000;

    _totalTimeTakenSec += (timeTakenMs / 1000).round();

    final currentQuestion = widget.questions[_currentIndex % widget.questions.length];
    final questionId = currentQuestion['questionId'] ?? '';

    final result = await BattleArenaService.instance.submitAnswer(
      userId: widget.userId,
      matchId: widget.matchId,
      questionId: questionId,
      selectedOptionIndex: optionIndex,
      timeTakenMs: timeTakenMs,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final bool isCorrect = result['isCorrect'] == true;
      final int pointsEarned = NumberUtils.parseInt(result['pointsEarned'], 0);
      final int streakBonus = NumberUtils.parseInt(result['streakBonus'], 0);
      final int correctIdx = NumberUtils.parseInt(result['correctIndex'], -1);

      int finalPoints = pointsEarned;
      if (isCorrect) {
        _correctCount++;
        if (finalPoints <= 0) {
          finalPoints = 100;
        }
      } else if (optionIndex == -1) {
        _skippedCount++;
      } else {
        _wrongCount++;
        finalPoints = -100; // Deduct 100 points for wrong answer!
      }

      setState(() {
        _mySpeedScore = _mySpeedScore + finalPoints;
        if (_mySpeedScore < 0) _mySpeedScore = 0;

        _correctOptionIndex = isCorrect ? optionIndex : (correctIdx != -1 ? correctIdx : null);
      });

      // Trigger floating text animation
      _triggerFloatingPopup(finalPoints, isCorrect);

      if (streakBonus > 0 && mounted) {
        CustomToast.showToast(context, msg: '🔥 Streak Bonus: +$streakBonus Pts!');
      }
    } else {
      if (mounted) {
        CustomToast.showToast(context, msg: result['message']?.toString() ?? 'Submission failed');
      }
      setState(() {
        _correctOptionIndex = null;
      });
    }

    // Snappy delay of 800ms for visual feedback
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    setState(() {
      _currentIndex++;
    });
    _loadCurrentQuestion();
  }

  void _startLiveScorePolling() {
    _liveScorePollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_isPreparingResult) return;
      try {
        final data = await BattleArenaService.instance.checkMatchStatus(
          userId: widget.userId,
          matchId: widget.matchId,
        );
        if (data['success'] == true && data['status'] == 'IN_PROGRESS') {
          final opponent = data['opponent'];
          if (opponent != null) {
            final oppUserId = opponent['userId']?.toString() ?? '';
            final oppScore = opponent['speedScore'] is num ? (opponent['speedScore'] as num).toInt() : 0;
            final oppName = opponent['name']?.toString() ?? 'Opponent';
            final oppAvatar = opponent['avatar']?.toString() ?? '';
            
            int diff = 0;
            if (_opponentsScores.containsKey(oppUserId)) {
              diff = oppScore - _opponentsScores[oppUserId]!;
            }
            _opponentsScores[oppUserId] = oppScore;

            if (oppUserId != _opponentUserId || oppScore != _opponentSpeedScore) {
              setState(() {
                _opponentUserId = oppUserId;
                _opponentSpeedScore = oppScore;
                _opponentName = oppName;
                _opponentAvatar = oppAvatar;
              });
              if (diff != 0) {
                _triggerOpponentFloatingPopup(diff, diff > 0);
              }
            }
          }
        }
      } catch (e) {
         // debugPrint('🔥 Error polling live score: $e');
      }
    });
  }

  Future<void> _finishMatchAndShowResults() async {
    if (_isFinishing) return;
    _isFinishing = true;

    setState(() {
      _isPreparingResult = true;
    });

    _liveScorePollTimer?.cancel(); // Stop gameplay live score poll

    Map<String, dynamic> finishData = {};
    bool isCompleted = false;
    final DateTime startTime = DateTime.now();

    // Keep polling /finish-match until status is COMPLETED
    while (!isCompleted && mounted) {
      finishData = await BattleArenaService.instance.finishMatch(
        userId: widget.userId,
        matchId: widget.matchId,
      );

      if (finishData['success'] == true && finishData['status'] == 'COMPLETED') {
        isCompleted = true;
      } else {
        // Wait 2 seconds before polling again
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!mounted) return;

    // Ensure the Preparing Result overlay is shown for at least 2.5 seconds
    final int elapsedMs = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsedMs < 2500) {
      await Future.delayed(Duration(milliseconds: 2500 - elapsedMs));
    }

    if (!mounted) return;

    final bool isWinner = finishData['isWinner'] == true;
    final int prizeAwarded = finishData['prizeAwarded'] is num ? (finishData['prizeAwarded'] as num).toInt() : 0;
    final int entryFeeCoins = finishData['entryFeeCoins'] is num ? (finishData['entryFeeCoins'] as num).toInt() : 0;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultReportScreen(
          userId: widget.userId,
          matchId: widget.matchId,
          isWinner: isWinner,
          myPoints: _mySpeedScore,
          opponentPoints: finishData['opponentStats']?['score'] is num
              ? (finishData['opponentStats']?['score'] as num).toInt()
              : 0,
          correctCount: _correctCount,
          wrongCount: _wrongCount,
          skippedCount: _skippedCount,
          totalTimeTakenSec: _totalTimeTakenSec,
          totalQuestions: _correctCount + _wrongCount + _skippedCount,
          prizeAwarded: prizeAwarded,
          entryFeeCoins: entryFeeCoins,
          opponentCorrectCount: finishData['opponentStats']?['correctCount'] is num
              ? (finishData['opponentStats']?['correctCount'] as num).toInt()
              : 0,
          opponentWrongCount: finishData['opponentStats']?['wrongCount'] is num
              ? (finishData['opponentStats']?['wrongCount'] as num).toInt()
              : 0,
          opponentSkippedCount: finishData['opponentStats']?['skippedCount'] is num
              ? (finishData['opponentStats']?['skippedCount'] as num).toInt()
              : 0,
          opponentTotalTimeTakenSec: finishData['opponentStats']?['totalTimeTakenSec'] is num
              ? (finishData['opponentStats']?['totalTimeTakenSec'] as num).toInt()
              : 0,
          myAvatar: finishData['myStats']?['avatar'] ?? '',
          myName: finishData['myStats']?['name'] ?? 'You',
          opponentAvatar: finishData['opponentStats']?['avatar'] ?? '',
          opponentName: finishData['opponentStats']?['name'] ?? 'Opponent',
          players: finishData['players'] is List ? (finishData['players'] as List) : const [],
        ),
      ),
    );
  }

  void _triggerFloatingPopup(int points, bool isCorrect) {
    if (points == 0) return;
    final String popupId = UniqueKey().toString();
    setState(() {
      _floatingPopups.add({
        'id': popupId,
        'points': points,
        'isCorrect': isCorrect,
      });
    });
  }

  void _triggerOpponentFloatingPopup(int points, bool isCorrect) {
    if (points == 0) return;
    final String popupId = UniqueKey().toString();
    setState(() {
      _opponentFloatingPopups.add({
        'id': popupId,
        'points': points,
        'isCorrect': isCorrect,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentQ = widget.questions.isNotEmpty ? widget.questions[_currentIndex % widget.questions.length] : {};
    final List<dynamic> options = currentQ['options'] ?? ['Option 1', 'Option 2', 'Option 3', 'Option 4'];
    final int matchDuration = widget.matchDurationSec > 0 ? widget.matchDurationSec : 60;
    final double progressValue = matchDuration > 0 ? (_timerSeconds / matchDuration) : 0.0;

    final userAsyncValue = ref.watch(DashboardService.userDataProvider(widget.userId));
    final userProfile = userAsyncValue.value;
    final String myName = userProfile?.name ?? 'You';
    final String myPhotoUrl = userProfile?.photoUrl ?? '';

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: PopScope(
        canPop: _canExit,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          _showForfeitConfirmationPopup(context);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              // Main Screen View
              Positioned.fill(
                child: SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 8.h),

                      // Top Header Row: Exit Button + Clean Quiz Counter Tag
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Exit / Forfeit Action Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _showForfeitConfirmationPopup(context);
                              },
                              child: Container(
                                width: 36.w,
                                height: 36.w,
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
                                  Icons.close_rounded,
                                  color: const Color(0xFFAB31DE),
                                  size: 20.sp,
                                ),
                              ),
                            ),

                            // Clean Quiz Counter Tag
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: const Color(0xFFF3E8FF),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                'Quiz ${_currentIndex + 1}',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFAB31DE),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),

                            // Balance Spacer for perfect centering
                            SizedBox(width: 36.w),
                          ],
                        ),
                      ),

                      SizedBox(height: 12.h),

                      // Executive Floating 1v1 Duel Arena Card (Green vs Red Theme)
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 16.w),
                        padding: EdgeInsets.all(14.w),
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
                            // Top Row: User Profile (Green) - Central Timer - Opponent Profile (Red)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // User Profile & Points (Left Side - Emerald Green Theme)
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(2.r),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF34D399), Color(0xFF059669)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: myPhotoUrl.isNotEmpty
                                            ? AvatarInternetImage(
                                                url: myPhotoUrl,
                                                size: 38,
                                                borderWidth: 0,
                                              )
                                            : CircleAvatar(
                                                radius: 19.r,
                                                backgroundColor: const Color(0xFFFAF5FF),
                                                child: Icon(Icons.person_rounded, color: const Color(0xFF10B981), size: 20.sp),
                                              ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              myName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF64748B),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '$_mySpeedScore Pts',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF059669),
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Central Circular Countdown Timer
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 48.w,
                                        height: 48.w,
                                        child: CircularProgressIndicator(
                                          value: progressValue,
                                          strokeWidth: 4.0,
                                          backgroundColor: const Color(0xFFFAF5FF),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            _timerSeconds > 5 ? const Color(0xFFAB31DE) : const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$_timerSeconds',
                                        style: GoogleFonts.outfit(
                                          color: _timerSeconds > 5 ? const Color(0xFF1E1B4B) : const Color(0xFFEF4444),
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Opponent Profile & Points (Right Side - Flame Red Theme)
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _opponentName ?? 'Opponent',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF64748B),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '$_opponentSpeedScore Pts',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFFE11D48),
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.all(2.r),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFE11D48).withValues(alpha: 0.25),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: (_opponentAvatar ?? '').isNotEmpty
                                            ? AvatarInternetImage(
                                                url: _opponentAvatar!,
                                                size: 38,
                                                borderWidth: 0,
                                              )
                                            : CircleAvatar(
                                                radius: 19.r,
                                                backgroundColor: const Color(0xFFFFF1F2),
                                                child: Icon(Icons.person_rounded, color: const Color(0xFFE11D48), size: 20.sp),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 12.h),

                            // Tug-of-War Green vs Red Energy Split Bar
                            Container(
                              height: 8.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(
                                  color: const Color(0xFFF3E8FF),
                                  width: 0.8,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6.r),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: _mySpeedScore == 0 && _opponentSpeedScore == 0 ? 50 : _mySpeedScore,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF34D399), Color(0xFF059669)],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(width: 2.w, color: Colors.white), // center divider
                                    Expanded(
                                      flex: _mySpeedScore == 0 && _opponentSpeedScore == 0 ? 50 : _opponentSpeedScore,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Color(0xFFF87171), Color(0xFFE11D48)],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14.h),

                      // Scrollable Quiz Section (Question + 2x2 Executive Option Cards)
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Executive White Question Card
                              Container(
                                width: double.infinity,
                                constraints: BoxConstraints(minHeight: 95.h),
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22.r),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.07),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    currentQ['question']?.toString() ?? 'Question Loading...',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16.5.sp,
                                      color: const Color(0xFF1E1B4B),
                                      fontWeight: FontWeight.w800,
                                      height: 1.38,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 14.h),

                              // 2x2 Clean Executive Option Cards Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: options.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12.h,
                                  crossAxisSpacing: 12.w,
                                  childAspectRatio: 1.65,
                                ),
                                itemBuilder: (context, optIdx) {
                                  final isSelected = _selectedOptionIndex == optIdx;
                                  final hasSelected = _selectedOptionIndex != null;
                                  final isCorrectOpt = _correctOptionIndex == optIdx;

                                  Color cardBgColor = const Color(0xFFFAF5FF);
                                  Color cardBorderColor = const Color(0xFFF3E8FF);
                                  Color badgeBgColor = const Color(0xFFF3E8FF);
                                  Color badgeTextColor = const Color(0xFFAB31DE);
                                  Color textColor = const Color(0xFF1E1B4B);
                                  Widget? statusIcon;

                                  if (hasSelected) {
                                    if (isCorrectOpt) {
                                      cardBgColor = const Color(0xFFF0FDF4);
                                      cardBorderColor = const Color(0xFF10B981);
                                      badgeBgColor = const Color(0xFF10B981);
                                      badgeTextColor = Colors.white;
                                      textColor = const Color(0xFF15803D);
                                      statusIcon = Icon(Icons.check_circle_rounded, color: const Color(0xFF10B981), size: 18.sp);
                                    } else if (isSelected && !isCorrectOpt) {
                                      cardBgColor = const Color(0xFFFEF2F2);
                                      cardBorderColor = const Color(0xFFEF4444);
                                      badgeBgColor = const Color(0xFFEF4444);
                                      badgeTextColor = Colors.white;
                                      textColor = const Color(0xFFB91C1C);
                                      statusIcon = Icon(Icons.cancel_rounded, color: const Color(0xFFEF4444), size: 18.sp);
                                    } else {
                                      cardBgColor = const Color(0xFFF8FAFC);
                                      cardBorderColor = const Color(0xFFF1F5F9);
                                      badgeBgColor = const Color(0xFFF1F5F9);
                                      badgeTextColor = const Color(0xFF94A3B8);
                                      textColor = const Color(0xFF94A3B8);
                                    }
                                  } else {
                                    if (isSelected) {
                                      cardBgColor = const Color(0xFFAB31DE);
                                      cardBorderColor = const Color(0xFFE39FFF);
                                      badgeBgColor = Colors.white;
                                      badgeTextColor = const Color(0xFFAB31DE);
                                      textColor = Colors.white;
                                    }
                                  }

                                  return GestureDetector(
                                    onTap: () => _handleAnswerSelection(optIdx),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                                      decoration: BoxDecoration(
                                        color: cardBgColor,
                                        borderRadius: BorderRadius.circular(16.r),
                                        border: Border.all(
                                          color: cardBorderColor,
                                          width: isSelected || (hasSelected && isCorrectOpt) ? 1.8 : 1.0,
                                        ),
                                        boxShadow: [
                                          if (hasSelected && isCorrectOpt)
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.20),
                                              blurRadius: 8,
                                            )
                                          else if (hasSelected && isSelected && !isCorrectOpt)
                                            BoxShadow(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.20),
                                              blurRadius: 8,
                                            )
                                          else if (isSelected)
                                            BoxShadow(
                                              color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                                              blurRadius: 8,
                                            ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Letter Badge (A, B, C, D)
                                          Container(
                                            width: 26.w,
                                            height: 26.w,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: badgeBgColor,
                                            ),
                                            child: Text(
                                              optIdx == 0 ? 'A' : optIdx == 1 ? 'B' : optIdx == 2 ? 'C' : 'D',
                                              style: GoogleFonts.outfit(
                                                color: badgeTextColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12.5.sp,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),

                                          // Option Text
                                          Expanded(
                                            child: Text(
                                              options[optIdx].toString(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.outfit(
                                                color: textColor,
                                                fontSize: 12.5.sp,
                                                fontWeight: FontWeight.w800,
                                                height: 1.25,
                                              ),
                                            ),
                                          ),
                                          if (statusIcon != null) ...[
                                            SizedBox(width: 4.w),
                                            statusIcon,
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 14.h),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Executive "Preparing Result" Clean White Overlay
              if (_isPreparingResult)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.90),
                    child: Center(
                      child: Container(
                        width: 295.w,
                        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                              blurRadius: 30,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Centerpiece Icon Container
                            Container(
                              width: 60.w,
                              height: 60.w,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFAF5FF),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.sports_esports_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 32.sp,
                              ),
                            ),
                            SizedBox(height: 18.h),
                            Text(
                              'CALCULATING RESULTS...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'Comparing final speed points with your opponent...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF64748B),
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            SizedBox(height: 20.h),
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFFAB31DE),
                                strokeWidth: 2.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // User Floating Score Popups
              ..._floatingPopups.map((p) {
                return Positioned(
                  top: 50.h,
                  left: 40.w,
                  child: FloatingScoreText(
                    key: ValueKey(p['id']),
                    points: p['points'] as int,
                    isCorrect: p['isCorrect'] as bool,
                    onComplete: () {
                      setState(() {
                        _floatingPopups.removeWhere((x) => x['id'] == p['id']);
                      });
                    },
                  ),
                );
              }),

              // Opponent Floating Score Popups
              ..._opponentFloatingPopups.map((p) {
                return Positioned(
                  top: 50.h,
                  right: 40.w,
                  child: FloatingScoreText(
                    key: ValueKey(p['id']),
                    points: p['points'] as int,
                    isCorrect: p['isCorrect'] as bool,
                    onComplete: () {
                      setState(() {
                        _opponentFloatingPopups.removeWhere((x) => x['id'] == p['id']);
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForfeitConfirmationPopup(BuildContext context) async {
    if (_isExitPopupShowing || _canExit || _isPreparingResult || _isFinishing) return;
    _isExitPopupShowing = true;
    bool didConfirmForfeit = false;

    try {
      await CustomStatusPopup.showWarning(
        context: context,
        tag: 'Quit Battle',
        title: 'Leave Battle?',
        message: 'If you leave now, you will forfeit this match and your entry fee coins will not be refunded. Are you sure you want to exit?',
        primaryButtonText: 'CONTINUE PLAYING',
        onPrimaryTap: () {
          // Dismiss dialog and stay
        },
        secondaryButtonText: 'FORFEIT & EXIT',
        onSecondaryTap: () {
          HapticFeedback.lightImpact();
          didConfirmForfeit = true;
        },
      );
    } finally {
      _isExitPopupShowing = false;
    }

    if (didConfirmForfeit && mounted) {
      _handleForfeitAndExit();
    }
  }

  void _handleForfeitAndExit() {
    _matchTimer?.cancel();
    _liveScorePollTimer?.cancel();

    // Notify backend in background to finish match as forfeited
    BattleArenaService.instance.finishMatch(
      userId: widget.userId,
      matchId: widget.matchId,
    );

    setState(() {
      _canExit = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
}

class FloatingScoreText extends StatefulWidget {
  final int points;
  final bool isCorrect;
  final VoidCallback onComplete;

  const FloatingScoreText({
    super.key,
    required this.points,
    required this.isCorrect,
    required this.onComplete,
  });

  @override
  State<FloatingScoreText> createState() => _FloatingScoreTextState();
}

class _FloatingScoreTextState extends State<FloatingScoreText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: widget.isCorrect ? -70.0 : 70.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
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
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Text(
              widget.isCorrect
                  ? '+${widget.points} Pts'
                  : '${widget.points} Pts',
              style: GoogleFonts.outfit(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: widget.isCorrect ? Colors.greenAccent : Colors.redAccent,
                shadows: [
                  const Shadow(
                    blurRadius: 10,
                    color: Colors.black,
                    offset: Offset(0, 4),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class NumberUtils {
  static int parseInt(dynamic val, int def) {
    if (val == null) return def;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? def;
  }
}

class _DynamicDomeHeaderPainter extends CustomPainter {
  final Color strokeColor;
  final double flattenProgress;

  const _DynamicDomeHeaderPainter({
    required this.strokeColor,
    required this.flattenProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final startY = lerpDouble(size.height, 0.0, flattenProgress)!;
    final controlY = lerpDouble(-4.0, 0.0, flattenProgress)!;

    final blackPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final bottomBlackPath = Path();
    bottomBlackPath.moveTo(0, startY);
    bottomBlackPath.quadraticBezierTo(size.width / 2, controlY, size.width, startY);
    bottomBlackPath.lineTo(size.width, size.height);
    bottomBlackPath.lineTo(0, size.height);
    bottomBlackPath.close();

    canvas.drawPath(bottomBlackPath, blackPaint);

    final strokePath = Path();
    strokePath.moveTo(0, startY);
    strokePath.quadraticBezierTo(size.width / 2, controlY, size.width, startY);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final shader = LinearGradient(
      colors: [
        Colors.transparent,
        strokeColor.withValues(alpha: 0.3),
        strokeColor,
        strokeColor.withValues(alpha: 0.3),
        Colors.transparent,
      ],
      stops: const [0.08, 0.28, 0.5, 0.72, 0.92],
    ).createShader(rect);

    final shadowPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(strokePath, shadowPaint);

    final strokePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _DynamicDomeHeaderPainter oldDelegate) {
    return oldDelegate.flattenProgress != flattenProgress || oldDelegate.strokeColor != strokeColor;
  }
}

class _GridBackgroundPainter extends CustomPainter {
  const _GridBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.8;

    const double step = 22.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    // Start on the left vertical side (fading starts below the curve)
    path.moveTo(0, h);
    path.lineTo(0, r);
    // Top-left arc
    path.arcToPoint(
      Offset(r, 0),
      radius: Radius.circular(r),
      clockwise: true,
    );
    // Top horizontal line
    path.lineTo(w - r, 0);
    // Top-right arc
    path.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
      clockwise: true,
    );
    // Right vertical side
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

class _ChipGlossyOverlayPainter extends CustomPainter {
  const _ChipGlossyOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final wavePath = Path();
    wavePath.moveTo(0, 0);
    wavePath.lineTo(w, 0);
    wavePath.lineTo(w, h * 0.35);
    wavePath.quadraticBezierTo(
      w * 0.50,
      h * 0.58,
      0,
      h * 0.42,
    );
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.38),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.60));

    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NotchedCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final tabH = 15.0;     
    final tabW = w * 0.72; 
    final cornerR = 16.0;  
    final bottomR = 20.0;
    
    final leftX = (w - tabW) / 2;
    final rightX = leftX + tabW;
    
    final transitionW = 20.0; 
    
    final path = Path();
    path.moveTo(0, tabH + cornerR);
    path.quadraticBezierTo(0, tabH, cornerR, tabH);
    path.lineTo(leftX - transitionW, tabH);
    path.cubicTo(
      leftX - transitionW * 0.45, tabH, 
      leftX - transitionW * 0.15, 0,    
      leftX + transitionW * 0.6, 0,     
    );
    path.lineTo(rightX - transitionW * 0.6, 0);
    path.cubicTo(
      rightX - transitionW * 0.15, 0,    
      rightX + transitionW * 0.45, tabH, 
      rightX + transitionW, tabH,        
    );
    path.lineTo(w - cornerR, tabH);
    path.quadraticBezierTo(w, tabH, w, tabH + cornerR);
    path.lineTo(w, h - bottomR);
    path.quadraticBezierTo(w, h, w - bottomR, h);
    path.lineTo(bottomR, h);
    path.quadraticBezierTo(0, h, 0, h - bottomR);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _NotchedCardPainter extends CustomPainter {
  final Color borderColor;

  const _NotchedCardPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tabH = 15.0;     
    final tabW = w * 0.72; 
    final cornerR = 16.0;  
    final bottomR = 20.0;
    
    final leftX = (w - tabW) / 2;
    final rightX = leftX + tabW;
    
    final transitionW = 20.0; 

    final path = Path();
    path.moveTo(0, tabH + cornerR);
    path.quadraticBezierTo(0, tabH, cornerR, tabH);
    path.lineTo(leftX - transitionW, tabH);
    path.cubicTo(
      leftX - transitionW * 0.45, tabH, 
      leftX - transitionW * 0.15, 0,    
      leftX + transitionW * 0.6, 0,     
    );
    path.lineTo(rightX - transitionW * 0.6, 0);
    path.cubicTo(
      rightX - transitionW * 0.15, 0,    
      rightX + transitionW * 0.45, tabH, 
      rightX + transitionW, tabH,        
    );
    path.lineTo(w - cornerR, tabH);
    path.quadraticBezierTo(w, tabH, w, tabH + cornerR);
    path.lineTo(w, h - bottomR);
    path.quadraticBezierTo(w, h, w - bottomR, h);
    path.lineTo(bottomR, h);
    path.quadraticBezierTo(0, h, 0, h - bottomR);
    path.close();

    final rect = Rect.fromLTWH(0, 0, w, h);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        borderColor.withValues(alpha: 0.75),
        borderColor.withValues(alpha: 0.35),
        borderColor.withValues(alpha: 0.1),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 0.75, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchedCardPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor;
  }
}

class _CornerBracketPainter extends CustomPainter {
  final Color bracketColor;
  final double strokeWidth;
  final double bracketLength;
  final double borderRadius;

  const _CornerBracketPainter({
    required this.bracketColor,
    this.strokeWidth = 2.0,
    this.bracketLength = 14.0,
    this.borderRadius = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = bracketColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final L = bracketLength;
    final r = borderRadius;

    // Top-Left corner bracket
    final pathTL = Path()
      ..moveTo(0, L)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true)
      ..lineTo(L, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right corner bracket
    final pathTR = Path()
      ..moveTo(w - L, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true)
      ..lineTo(w, L);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left corner bracket
    final pathBL = Path()
      ..moveTo(0, h - L)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r), clockwise: false)
      ..lineTo(L, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right corner bracket
    final pathBR = Path()
      ..moveTo(w - L, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r), clockwise: false)
      ..lineTo(w, h - L);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) {
    return oldDelegate.bracketColor != bracketColor ||
        oldDelegate.bracketLength != bracketLength ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

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
