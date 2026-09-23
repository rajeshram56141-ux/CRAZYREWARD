import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'battle_arena_provider.dart';
import 'live_quiz_battle_screen.dart';
import '../../../provider/dashboard_provider.dart';
import '../../../../../widgets/common/internet_image.dart';
import '../../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../../services/local_storage.dart';

class MatchingPartnerScreen extends ConsumerStatefulWidget {
  const MatchingPartnerScreen({
    super.key,
    required this.userId,
    required this.matchId,
    required this.roomTitle,
    this.roomId,
    this.isAdSkipped = false,
    this.matchingTimeoutSec = 35,
    this.entryFee = 0,
  });

  final String userId;
  final String matchId;
  final String roomTitle;
  final String? roomId;
  final bool isAdSkipped;
  final int matchingTimeoutSec;
  final int entryFee;

  @override
  ConsumerState<MatchingPartnerScreen> createState() => _MatchingPartnerScreenState();
}

class _MatchingPartnerScreenState extends ConsumerState<MatchingPartnerScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  Timer? _pollTimer;
  int _secondsLeft = 35;
  Timer? _countdownTimer;

  List<dynamic> _matchingPlayers = [];
  int _capacity = 2;
  bool _isMatchFound = false;
  bool _isHandled = false;
  bool _isCancelling = false;
  int _startCountdown = 3;
  Map<String, dynamic>? _foundMatchData;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.matchingTimeoutSec > 0 ? widget.matchingTimeoutSec : 35;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        _pollMatchmaker(isTimeout: true);

        // Safety timeout pop after 2 seconds if match status is still not resolved
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isMatchFound && !_isHandled) {
            _isHandled = true;
            _pollTimer?.cancel();
            Navigator.of(context).pop("No online opponent joined in time. Don't worry, your entry coins have been refunded in full!");
          }
        });
      }
    });

    _pollMatchmaker();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _pollMatchmaker();
    });
  }

  Future<void> _pollMatchmaker({bool isTimeout = false}) async {
    if (_isMatchFound || _isHandled || _isCancelling) return;
    final statusData = await BattleArenaService.instance.checkMatchStatus(
      userId: widget.userId,
      matchId: widget.matchId,
      timeout: isTimeout,
    );

    if (!mounted || _isHandled || _isCancelling) return;

    if (statusData['status'] == 'WAITING' && statusData['matchingTimeoutSec'] is num) {
      final int serverTimeout = (statusData['matchingTimeoutSec'] as num).toInt();
      final List<dynamic> playersList = statusData['players'] is List ? statusData['players'] as List : [];
      final int roomCapacity = statusData['capacity'] is num ? (statusData['capacity'] as num).toInt() : 2;
      setState(() {
        _secondsLeft = serverTimeout;
        _matchingPlayers = playersList;
        _capacity = roomCapacity;
      });
    }

    if (statusData['success'] == false || (statusData['success'] == true && statusData['status'] == 'CANCELLED')) {
      _isHandled = true;
      _pollTimer?.cancel();
      _countdownTimer?.cancel();

      final String msg = statusData['message']?.toString() ?? "No online opponent joined in time. Don't worry, your entry coins have been refunded in full!";

      if (mounted) {
        Navigator.of(context).pop(msg);
      }
      return;
    }

    if (statusData['success'] == true && statusData['status'] == 'IN_PROGRESS') {
      _triggerStartCountdown(statusData);
    }
  }

  void _triggerStartCountdown(Map<String, dynamic> statusData) {
    if (_isMatchFound) return;
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    // Instantly invalidate/consume Free Battle Ad Pass when match pairing is confirmed!
    LocalStorage.setFreeBattleAdPass(false);

    setState(() {
      _isMatchFound = true;
      _foundMatchData = statusData;
      _startCountdown = 3;
    });

    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_startCountdown > 1) {
        setState(() => _startCountdown--);
      } else {
        t.cancel();
        _navigateToLiveBattle();
      }
    });
  }

  void _navigateToLiveBattle() {
    if (!mounted || _foundMatchData == null) return;
    final List<dynamic> questions = _foundMatchData!['questions'] ?? [];
    final Map<String, dynamic>? opponent = _foundMatchData!['opponent'];
    final String actualMatchId = _foundMatchData!['matchId']?.toString() ?? widget.matchId;

    final int duration = _foundMatchData!['matchDurationSec'] is num
        ? (_foundMatchData!['matchDurationSec'] as num).toInt()
        : 60;

    // Consume Free Battle Ad Pass since player successfully matched & started match!
    LocalStorage.setFreeBattleAdPass(false);
    if (widget.isAdSkipped && widget.roomId != null && widget.roomId!.isNotEmpty) {
      LocalStorage.consumeRoomAdSkipMatch(widget.userId, widget.roomId!);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LiveQuizBattleScreen(
          userId: widget.userId,
          matchId: actualMatchId,
          roomTitle: widget.roomTitle,
          questions: questions,
          opponentName: opponent?['name'] ?? 'Opponent',
          opponentAvatar: opponent?['avatar'] ?? '',
          matchDurationSec: duration,
        ),
      ),
    );
  }

  Future<void> _handleManualCancel() async {
    if (_isCancelling || _isMatchFound || _isHandled) return;

    setState(() {
      _isCancelling = true;
    });

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFAB31DE)),
      ),
    );

    try {
      final statusData = await BattleArenaService.instance.checkMatchStatus(
        userId: widget.userId,
        matchId: widget.matchId,
        timeout: true,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading spinner
      }

      if (statusData['success'] == false || 
          (statusData['success'] == true && statusData['status'] == 'CANCELLED')) {
        _isHandled = true;
        _pollTimer?.cancel();
        _countdownTimer?.cancel();

        if (mounted) {
          Navigator.of(context).pop();
        }
      } else if (statusData['success'] == true && statusData['status'] == 'IN_PROGRESS') {
        setState(() {
          _isCancelling = false;
        });
        _triggerStartCountdown(statusData);
      } else {
        setState(() {
          _isCancelling = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot cancel matchmaking. Opponent is currently joining!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading spinner
      }
      setState(() {
        _isCancelling = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel matchmaking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    // Safety cancel match on server if disposed before pairing is complete
    if (!_isMatchFound) {
      BattleArenaService.instance.checkMatchStatus(
        userId: widget.userId,
        matchId: widget.matchId,
        timeout: true,
      ).catchError((err) {
        return <String, dynamic>{};
      });
    }
    super.dispose();
  }

  Widget _buildMatchingGrid() {
    final int cap = _capacity > 0 ? _capacity : 2;
    return SizedBox(
      width: 280.w,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20.w,
        runSpacing: 20.h,
        children: List.generate(cap, (index) {
          if (index < _matchingPlayers.length) {
            final p = _matchingPlayers[index];
            final String name = p['name']?.toString() ?? 'Joined';
            final String avatar = p['avatar']?.toString() ?? '';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFAB31DE), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: avatar.isNotEmpty
                        ? AvatarInternetImage(
                            url: avatar,
                            size: 56,
                            borderWidth: 0,
                          )
                        : CircleAvatar(
                            radius: 28.r,
                            backgroundColor: const Color(0xFF2E2E38),
                            child: Icon(Icons.person_rounded, color: const Color(0xFFAB31DE), size: 24.sp),
                          ),
                  ),
                ),
                SizedBox(height: 6.h),
                SizedBox(
                  width: 65.w,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Empty placeholder slot
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E2E38),
                    border: Border.all(color: const Color(0xFF3E3E4C), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '?',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9E9EA7),
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                SizedBox(
                  width: 65.w,
                  child: Text(
                    'Waiting...',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF9E9EA7),
                      fontSize: 9.5.sp,
                    ),
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opponent = _foundMatchData?['opponent'];
    final opponentName = opponent?['name'] ?? 'Opponent Found';
    final opponentAvatar = opponent?['avatar']?.toString() ?? '';

    final userAsyncValue = ref.watch(DashboardService.userDataProvider(widget.userId));
    final userProfile = userAsyncValue.value;
    final String myName = userProfile?.name ?? 'You';
    final String myPhotoUrl = userProfile?.photoUrl ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleManualCancel();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Column(
                          children: [
                            SizedBox(height: 10.h),

                            // Top Navigation Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: _handleManualCancel,
                                  child: Container(
                                    width: 40.w,
                                    height: 40.w,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15.r),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
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
                                    child: Center(
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: const Color(0xFF26262B),
                                        size: 20.sp,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _isMatchFound ? 'Match Found!' : 'Matchmaking',
                                  style: GoogleFonts.kaushanScript(
                                    color: const Color(0xFF26262B),
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 40.w),
                              ],
                            ),

                            SizedBox(height: 16.h),

                            // Battle Room Info Header Capsule
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF222226),
                                    Color(0xFF131316),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20.r),
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sports_esports_rounded,
                                    color: const Color(0xFFAB31DE),
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    widget.roomTitle.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: widget.entryFee == 0
                                          ? const Color(0xFF10B981).withValues(alpha: 0.18)
                                          : const Color(0xFFFBBF24).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: widget.entryFee == 0
                                            ? const Color(0xFF10B981).withValues(alpha: 0.5)
                                            : const Color(0xFFFBBF24).withValues(alpha: 0.5),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      widget.entryFee == 0 ? 'FREE' : '${widget.entryFee} COINS',
                                      style: GoogleFonts.poppins(
                                        color: widget.entryFee == 0 ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // Main Battle Matchmaking Stage (Center Card)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF222226),
                                    Color(0xFF131316),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(28.r),
                                border: Border.all(
                                  color: _isMatchFound ? const Color(0xFF10B981).withValues(alpha: 0.6) : const Color(0xFF2E2E36),
                                  width: _isMatchFound ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _isMatchFound
                                        ? const Color(0xFF10B981).withValues(alpha: 0.20)
                                        : Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: _capacity > 2
                                  ? SizedBox(
                                      height: 240.w,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          if (!_isMatchFound) const RadarRippleEffect(),
                                          _buildMatchingGrid(),
                                        ],
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Left Fighter: My Profile
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(3.r),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFFAB31DE), Color(0xFF7928CA)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFFAB31DE).withValues(alpha: 0.40),
                                                    blurRadius: 14,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: myPhotoUrl.isNotEmpty
                                                  ? AvatarInternetImage(
                                                      url: myPhotoUrl,
                                                      size: 76,
                                                      borderWidth: 0,
                                                    )
                                                  : CircleAvatar(
                                                      radius: 38.r,
                                                      backgroundColor: const Color(0xFF2E2E38),
                                                      child: Icon(Icons.person_rounded, color: const Color(0xFFAB31DE), size: 36.sp),
                                                    ),
                                            ),
                                            SizedBox(height: 10.h),
                                            Container(
                                              width: 95.w,
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF2E2E38),
                                                borderRadius: BorderRadius.circular(10.r),
                                                border: Border.all(
                                                  color: const Color(0xFF3E3E4C),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Text(
                                                myName,
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 11.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 3.h),
                                            Text(
                                              'YOU',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF38BDF8),
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Center VS Badge
                                        Transform(
                                          transform: Matrix4.skewX(-0.16),
                                          alignment: Alignment.center,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFB7185),
                                                  Color(0xFFE11D48),
                                                  Color(0xFFBE123C),
                                                  Color(0xFF881337),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(10.r),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                width: 1.2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFE11D48).withValues(alpha: 0.45),
                                                  blurRadius: 14,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Transform(
                                              transform: Matrix4.skewX(0.16),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'VS',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 16.sp,
                                                  fontWeight: FontWeight.w900,
                                                  fontStyle: FontStyle.italic,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Right Fighter: Opponent (Radar Search / Matched Reveal)
                                        SizedBox(
                                          width: 100.w,
                                          child: Center(
                                            child: AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 350),
                                              transitionBuilder: (Widget child, Animation<double> animation) {
                                                return ScaleTransition(
                                                  scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                                                  child: FadeTransition(
                                                    opacity: animation,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              child: _isMatchFound
                                                  ? Column(
                                                      key: const ValueKey<String>('matched'),
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: EdgeInsets.all(3.r),
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            gradient: const LinearGradient(
                                                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                              begin: Alignment.topLeft,
                                                              end: Alignment.bottomRight,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                                                blurRadius: 14,
                                                                spreadRadius: 2,
                                                              ),
                                                            ],
                                                          ),
                                                          child: opponentAvatar.isNotEmpty
                                                              ? AvatarInternetImage(
                                                                  url: opponentAvatar,
                                                                  size: 76,
                                                                  borderWidth: 0,
                                                                )
                                                              : CircleAvatar(
                                                                  radius: 38.r,
                                                                  backgroundColor: const Color(0xFF2E2E38),
                                                                  child: Icon(Icons.sports_esports_rounded, color: const Color(0xFF34D399), size: 36.sp),
                                                                ),
                                                        ),
                                                        SizedBox(height: 10.h),
                                                        Container(
                                                          width: 95.w,
                                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF2E2E38),
                                                            borderRadius: BorderRadius.circular(10.r),
                                                            border: Border.all(
                                                              color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            opponentName,
                                                            textAlign: TextAlign.center,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: GoogleFonts.poppins(
                                                              color: Colors.white,
                                                              fontSize: 11.5.sp,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(height: 3.h),
                                                        Text(
                                                          'OPPONENT',
                                                          style: GoogleFonts.poppins(
                                                            color: const Color(0xFF34D399),
                                                            fontSize: 10.sp,
                                                            fontWeight: FontWeight.w800,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : Column(
                                                      key: const ValueKey<String>('searching'),
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(
                                                          width: 82.w,
                                                          height: 82.w,
                                                          child: Stack(
                                                            alignment: Alignment.center,
                                                            children: [
                                                              AnimatedBuilder(
                                                                animation: _rotationController,
                                                                builder: (ctx, child) {
                                                                  return CustomPaint(
                                                                    size: Size(82.w, 82.w),
                                                                    painter: _MatchingSpinnerPainter(_rotationController.value),
                                                                  );
                                                                },
                                                              ),
                                                              CircleAvatar(
                                                                radius: 28.r,
                                                                backgroundColor: const Color(0xFF2E2E38),
                                                                child: Icon(
                                                                  Icons.person_search_rounded,
                                                                  color: const Color(0xFFAB31DE),
                                                                  size: 26.sp,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        SizedBox(height: 10.h),
                                                        Container(
                                                          width: 95.w,
                                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF2E2E38),
                                                            borderRadius: BorderRadius.circular(10.r),
                                                            border: Border.all(
                                                              color: const Color(0xFF3E3E4C),
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            'Searching...',
                                                            textAlign: TextAlign.center,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: GoogleFonts.poppins(
                                                              color: const Color(0xFFAB31DE),
                                                              fontSize: 11.sp,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(height: 3.h),
                                                        Text(
                                                          'WAITING',
                                                          style: GoogleFonts.poppins(
                                                            color: const Color(0xFF9E9EA7),
                                                            fontSize: 10.sp,
                                                            fontWeight: FontWeight.w600,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),

                            const Spacer(),

                            // Matchmaking Status & Timer Hub
                            if (_isMatchFound) ...[
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  'Matched with: $opponentName',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.sp,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                child: Text(
                                  '$_startCountdown',
                                  key: ValueKey<int>(_startCountdown),
                                  style: GoogleFonts.poppins(
                                    fontSize: 64.sp,
                                    color: const Color(0xFFFBBF24),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Searching Countdown Pill
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF222226),
                                      Color(0xFF131316),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20.r),
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      color: const Color(0xFFFBBF24),
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'SEARCHING OPPONENT : ${_secondsLeft}s',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5.sp,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: 24.h),

                            // Cancel Battle Action Button
                            SizedBox(
                              width: 220.w,
                              height: 48.h,
                              child: _PopScaleButton(
                                onTap: _handleManualCancel,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF87171),
                                        Color(0xFFEF4444),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(16.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'CANCEL BATTLE',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13.5.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 24.h),
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
    );
  }
}

void showBattleRefundPopup(BuildContext context, String? customMsg, {bool shouldPopParent = false}) {
  CustomStatusPopup.showFailed(
    context: context,
    tag: 'Match Notice',
    title: 'Player Not Matched!',
    message: customMsg ?? "No online opponent joined in time. Don't worry, your entry coins have been refunded in full!",
    primaryButtonText: 'GOT IT',
    onPrimaryTap: () {
      if (shouldPopParent && context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    },
    onClose: () {
      if (shouldPopParent && context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    },
  );
}

class RadarRippleEffect extends StatefulWidget {
  const RadarRippleEffect({super.key});

  @override
  State<RadarRippleEffect> createState() => _RadarRippleEffectState();
}

class _RadarRippleEffectState extends State<RadarRippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (index) {
            final double delay = index * 0.33;
            double progress = _controller.value - delay;
            if (progress < 0.0) progress += 1.0;
            return Container(
              width: 100.w + (progress * 140.w),
              height: 100.w + (progress * 140.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFAB31DE).withValues(alpha: (1.0 - progress) * 0.15),
                border: Border.all(
                  color: const Color(0xFFAB31DE).withValues(alpha: (1.0 - progress) * 0.35),
                  width: 1.5,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MatchingSpinnerPainter extends CustomPainter {
  final double rotation;

  const _MatchingSpinnerPainter(this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw subtle crosshairs
    final crossPaint = Paint()
      ..color = const Color(0xFFAB31DE).withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crossPaint);

    // 2. Draw Outer circular track
    final outerTrackPaint = Paint()
      ..color = const Color(0xFFAB31DE).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius * 0.95, outerTrackPaint);

    // 3. Draw Inner track
    final innerTrackPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.70, innerTrackPaint);

    // 4. Draw Rotating Gradient Arc (Outer Ring - Clockwise)
    final rectOuter = Rect.fromCircle(center: center, radius: radius * 0.95);
    final outerArcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFFAB31DE).withValues(alpha: 0.85),
          const Color(0xFFAB31DE).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5],
        transform: GradientRotation(rotation * 2 * math.pi),
      ).createShader(rectOuter)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rectOuter, 0, math.pi, false, outerArcPaint);

    // 5. Draw Rotating Gradient Arc (Inner Ring - Counter Clockwise)
    final rectInner = Rect.fromCircle(center: center, radius: radius * 0.70);
    final innerArcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.75),
          const Color(0xFF38BDF8).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4],
        transform: GradientRotation(-rotation * 2 * math.pi),
      ).createShader(rectInner)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rectInner, 0, math.pi * 0.8, false, innerArcPaint);

    // 6. Orbiting Glowing Particles
    final double angle1 = rotation * 2 * math.pi;
    final pos1 = Offset(
      center.dx + radius * 0.95 * math.cos(angle1),
      center.dy + radius * 0.95 * math.sin(angle1),
    );
    final pPaint1 = Paint()
      ..color = const Color(0xFFAB31DE)
      ..style = PaintingStyle.fill;
    final pGlow1 = Paint()
      ..color = const Color(0xFFAB31DE).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos1, 6, pGlow1);
    canvas.drawCircle(pos1, 2.5, pPaint1);

    final double angle2 = -rotation * 2 * math.pi + math.pi;
    final pos2 = Offset(
      center.dx + radius * 0.70 * math.cos(angle2),
      center.dy + radius * 0.70 * math.sin(angle2),
    );
    final pPaint2 = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    final pGlow2 = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos2, 5, pGlow2);
    canvas.drawCircle(pos2, 2.0, pPaint2);
  }

  @override
  bool shouldRepaint(covariant _MatchingSpinnerPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

class _PopScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PopScaleButton({
    required this.child,
    required this.onTap,
  });

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 90),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
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
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) async {
        await _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
