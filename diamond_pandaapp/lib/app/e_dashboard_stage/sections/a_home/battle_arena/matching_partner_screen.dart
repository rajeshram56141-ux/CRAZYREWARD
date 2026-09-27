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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

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
          matchId: actualMatchId, // Pass the sub-match team ID!
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
        child: CircularProgressIndicator(color: Color(0xFF6B4FD8)),
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
         // debugPrint('🔥 Error cancelling match on dispose: $err');
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
                  width: 54.w,
                  height: 54.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC084FC).withValues(alpha: 0.8), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: avatar.isNotEmpty
                        ? AvatarInternetImage(
                            url: avatar,
                            size: 54,
                            borderWidth: 0,
                          )
                        : CircleAvatar(
                            radius: 27.r,
                            backgroundColor: const Color(0xFF131033),
                            child: Icon(Icons.person_rounded, color: const Color(0xFFC084FC), size: 24.sp),
                          ),
                  ),
                ),
                SizedBox(height: 4.h),
                SizedBox(
                  width: 60.w,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
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
                  width: 54.w,
                  height: 54.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF141235),
                    border: Border.all(color: const Color(0xFFC084FC).withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '?',
                      style: TextStyle(
                        color: const Color(0xFFC084FC).withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                SizedBox(
                  width: 60.w,
                  child: Text(
                    'Waiting...',
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: 9.sp,
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
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleManualCancel();
          },
          child: Scaffold(
            backgroundColor: Colors.white,
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

                              // Top Header (Executive Back Button + Title)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: _handleManualCancel,
                                    child: Container(
                                      width: 40.w,
                                      height: 40.w,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF5FF),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFF3E8FF),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.arrow_back_rounded,
                                          color: const Color(0xFFAB31DE),
                                          size: 20.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _isMatchFound ? 'MATCH FOUND!' : 'MATCHMAKING',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF1E1B4B),
                                      fontSize: 18.5.sp,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 40.w),
                                ],
                              ),

                              SizedBox(height: 16.h),

                              // Battle Room Header Badge
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                                      blurRadius: 10,
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
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF1E1B4B),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                      decoration: BoxDecoration(
                                        color: widget.entryFee == 0
                                            ? const Color(0xFFF0FDF4)
                                            : const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(8.r),
                                        border: Border.all(
                                          color: widget.entryFee == 0
                                              ? const Color(0xFFBBF7D0)
                                              : const Color(0xFFFECDD3),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        widget.entryFee == 0 ? 'FREE' : '${widget.entryFee} COINS',
                                        style: GoogleFonts.outfit(
                                          color: widget.entryFee == 0 ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // Main Battle Matchmaking Stage (VS Duel or Multi-Player Grid)
                              if (_capacity > 2)
                                SizedBox(
                                  height: 240.w,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (!_isMatchFound) const RadarRippleEffect(),
                                      _buildMatchingGrid(),
                                    ],
                                  ),
                                )
                              else
                                // 2-Player Matchmaker Stage (Head-to-Head Duel)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                                              colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFAB31DE).withValues(alpha: 0.30),
                                                blurRadius: 16,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: myPhotoUrl.isNotEmpty
                                              ? AvatarInternetImage(
                                                  url: myPhotoUrl,
                                                  size: 78,
                                                  borderWidth: 0,
                                                )
                                              : CircleAvatar(
                                                  radius: 39.r,
                                                  backgroundColor: const Color(0xFFFAF5FF),
                                                  child: Icon(Icons.person_rounded, color: const Color(0xFFAB31DE), size: 38.sp),
                                                ),
                                        ),
                                        SizedBox(height: 10.h),
                                        Container(
                                          width: 95.w,
                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10.r),
                                            border: Border.all(
                                              color: const Color(0xFFF1F5F9),
                                              width: 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            myName,
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF1E1B4B),
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Center VS Badge (3D Glossy Ruby Slanted Badge)
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 18.w),
                                      child: Transform(
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
                                                color: const Color(0xFFE11D48).withValues(alpha: 0.4),
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
                                              style: GoogleFonts.outfit(
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
                                    ),

                                    // Right Fighter: Opponent (Radar Search / Matched Reveal)
                                    SizedBox(
                                      width: 105.w,
                                      height: 130.h,
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
                                                          colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                                            blurRadius: 16,
                                                            spreadRadius: 2,
                                                          ),
                                                        ],
                                                      ),
                                                      child: opponentAvatar.isNotEmpty
                                                          ? AvatarInternetImage(
                                                              url: opponentAvatar,
                                                              size: 78,
                                                              borderWidth: 0,
                                                            )
                                                          : CircleAvatar(
                                                              radius: 39.r,
                                                              backgroundColor: const Color(0xFFF0F9FF),
                                                              child: Icon(Icons.sports_esports_rounded, color: const Color(0xFF0284C7), size: 38.sp),
                                                            ),
                                                    ),
                                                    SizedBox(height: 10.h),
                                                    Container(
                                                      width: 95.w,
                                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(10.r),
                                                        border: Border.all(
                                                          color: const Color(0xFFBAE6FD),
                                                          width: 1.0,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        opponentName,
                                                        textAlign: TextAlign.center,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.outfit(
                                                          color: const Color(0xFF0369A1),
                                                          fontSize: 12.sp,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Column(
                                                  key: const ValueKey<String>('searching'),
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width: 84.w,
                                                      height: 84.w,
                                                      child: Stack(
                                                        alignment: Alignment.center,
                                                        children: [
                                                          AnimatedBuilder(
                                                            animation: _rotationController,
                                                            builder: (ctx, child) {
                                                              return CustomPaint(
                                                                size: Size(84.w, 84.w),
                                                                painter: _MatchingSpinnerPainter(_rotationController.value),
                                                              );
                                                            },
                                                          ),
                                                          CircleAvatar(
                                                            radius: 28.r,
                                                            backgroundColor: const Color(0xFFFAF5FF),
                                                            child: Icon(
                                                              Icons.person_search_rounded,
                                                              color: const Color(0xFFAB31DE),
                                                              size: 26.sp,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(height: 8.h),
                                                    Container(
                                                      width: 95.w,
                                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(10.r),
                                                        border: Border.all(
                                                          color: const Color(0xFFF1F5F9),
                                                          width: 1.0,
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Text(
                                                        'Searching...',
                                                        textAlign: TextAlign.center,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.outfit(
                                                          color: const Color(0xFFAB31DE),
                                                          fontSize: 11.sp,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              const Spacer(),

                              // Matchmaking Status & Timer Hub
                              if (_isMatchFound) ...[
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: const Color(0xFFBAE6FD),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Matched with: $opponentName',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF0369A1),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.sp,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                  child: Text(
                                    '$_startCountdown',
                                    key: ValueKey<int>(_startCountdown),
                                    style: GoogleFonts.outfit(
                                      fontSize: 68.sp,
                                      color: const Color(0xFFE11D48),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                // Searching Countdown Pill
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(
                                      color: const Color(0xFFF1F5F9),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        color: const Color(0xFFAB31DE),
                                        size: 16.sp,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        'SEARCHING OPPONENT : ${_secondsLeft}s',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF1E1B4B),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12.5.sp,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(height: 28.h),

                              // Cancel Battle Action Button (Super Offer Style Red Action Button)
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
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.30),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'CANCEL BATTLE',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
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
      ),
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  const _GridBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
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

class _DynamicDomeHeaderPainter extends CustomPainter {
  final Color strokeColor;
  final double flattenProgress;

  const _DynamicDomeHeaderPainter({
    this.strokeColor = const Color(0xFF6B4FD8),
    this.flattenProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double effectiveProgress = flattenProgress.clamp(0.0, 1.0);
    final double arcControlY = (size.height * 0.1) * (1.0 - effectiveProgress);

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.5, arcControlY, size.width, size.height * 0.7);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, fillPaint);

    final arcPath = Path();
    arcPath.moveTo(0, size.height * 0.7);
    arcPath.quadraticBezierTo(size.width * 0.5, arcControlY, size.width, size.height * 0.7);
    canvas.drawPath(arcPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _DynamicDomeHeaderPainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor || oldDelegate.flattenProgress != flattenProgress;
  }
}

class _ShimmeringHotGamesTitle extends StatefulWidget {
  const _ShimmeringHotGamesTitle({required this.titleText, this.fontSize});

  final String titleText;
  final double? fontSize;

  @override
  State<_ShimmeringHotGamesTitle> createState() => _ShimmeringHotGamesTitleState();
}

class _ShimmeringHotGamesTitleState extends State<_ShimmeringHotGamesTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
        final double value = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment(value * 3.6 - 1.8, -1.0),
              end: Alignment(value * 3.6 - 0.6, 1.0),
              colors: const [
                Color(0xFF9E8CF2),
                Color(0xFF6B4FD8),
                Color(0xFFFFFFFF),
                Color(0xFFC4B5FD),
                Color(0xFF6B4FD8),
                Color(0xFF9E8CF2),
              ],
              stops: const [0.0, 0.3, 0.5, 0.6, 0.8, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            widget.titleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.mysteryQuest(
              fontSize: widget.fontSize ?? 22.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
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

class _ShimmeringTitle extends StatefulWidget {
  const _ShimmeringTitle({required this.titleText, this.fontSize = 26});

  final String titleText;
  final double fontSize;

  @override
  State<_ShimmeringTitle> createState() => _ShimmeringTitleState();
}

class _ShimmeringTitleState extends State<_ShimmeringTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
        final double value = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment(value * 3.6 - 1.8, -1.0),
              end: Alignment(value * 3.6 - 0.6, 1.0),
              colors: const [
                Color(0xFFFDA4AF),
                Color(0xFFE11D48),
                Color(0xFFFFFFFF),
                Color(0xFFFCA5A5),
                Color(0xFFE11D48),
                Color(0xFFFDA4AF),
              ],
              stops: const [0.0, 0.3, 0.5, 0.6, 0.8, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            widget.titleText,
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: widget.fontSize.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        );
      },
    );
  }
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

    // 1. Draw horizontal and vertical subtle crosshairs (low opacity)
    final crossPaint = Paint()
      ..color = const Color(0xFFC084FC).withValues(alpha: 0.1)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crossPaint);

    // 2. Draw Outer dashed circular track
    final outerTrackPaint = Paint()
      ..color = const Color(0xFFC084FC).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Draw outer circle track
    canvas.drawCircle(center, radius * 0.95, outerTrackPaint);
    
    // 3. Draw Inner track
    final innerTrackPaint = Paint()
      ..color = const Color(0xFFBA4FFF).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.70, innerTrackPaint);

    // 4. Draw Rotating Gradient Arc (Outer Ring - Clockwise)
    final rectOuter = Rect.fromCircle(center: center, radius: radius * 0.95);
    final outerArcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFFBA4FFF).withValues(alpha: 0.8),
          const Color(0xFFC084FC).withValues(alpha: 0.0),
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
          const Color(0xFFF472B6).withValues(alpha: 0.7),
          const Color(0xFFF472B6).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4],
        transform: GradientRotation(-rotation * 2 * math.pi),
      ).createShader(rectInner)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(rectInner, 0, math.pi * 0.8, false, innerArcPaint);

    // 6. Draw Orbiting Glowing Particles
    // Particle 1 (Outer - clockwise)
    final double angle1 = rotation * 2 * math.pi;
    final pos1 = Offset(
      center.dx + radius * 0.95 * math.cos(angle1),
      center.dy + radius * 0.95 * math.sin(angle1),
    );
    final pPaint1 = Paint()
      ..color = const Color(0xFFC084FC)
      ..style = PaintingStyle.fill;
    final pGlow1 = Paint()
      ..color = const Color(0xFFC084FC).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos1, 6, pGlow1);
    canvas.drawCircle(pos1, 2.5, pPaint1);

    // Particle 2 (Inner - counter-clockwise, offset by 180 degrees)
    final double angle2 = -rotation * 2 * math.pi + math.pi;
    final pos2 = Offset(
      center.dx + radius * 0.70 * math.cos(angle2),
      center.dy + radius * 0.70 * math.sin(angle2),
    );
    final pPaint2 = Paint()
      ..color = const Color(0xFFF472B6)
      ..style = PaintingStyle.fill;
    final pGlow2 = Paint()
      ..color = const Color(0xFFF472B6).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos2, 5, pGlow2);
    canvas.drawCircle(pos2, 2.0, pPaint2);
    
    // Particle 3 (Trailing Outer particle, offset by 90 degrees)
    final double angle3 = rotation * 2 * math.pi - (math.pi / 2);
    final pos3 = Offset(
      center.dx + radius * 0.95 * math.cos(angle3),
      center.dy + radius * 0.95 * math.sin(angle3),
    );
    final pPaint3 = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final pGlow3 = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pos3, 4, pGlow3);
    canvas.drawCircle(pos3, 1.5, pPaint3);
  }

  @override
  bool shouldRepaint(covariant _MatchingSpinnerPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

class _HomeBackgroundCreativePainter extends CustomPainter {
  const _HomeBackgroundCreativePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF9333EA).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Left grid dots
    for (double x = 20; x < 120; x += 20) {
      for (double y = 200; y < 450; y += 20) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }

    // Right grid dots
    for (double x = size.width - 120; x < size.width - 10; x += 20) {
      for (double y = 500; y < 850; y += 20) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

// ---------------------------------------------------------------------------
// 3D GLOSSY RED TAPERED BUTTON PAINTER FOR CANCEL BATTLE
// ---------------------------------------------------------------------------
class _RedTaperedButtonPainter extends CustomPainter {
  final double taper;
  final double radius;

  const _RedTaperedButtonPainter({
    this.taper = 7.0,
    this.radius = 16.0,
  });

  Path getButtonPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final t = taper;
    final r = radius;

    final topWidth = w;
    final bottomWidth = w - (t * 2);

    final topLeft = Offset(0, 0);
    final topRight = Offset(topWidth, 0);
    final bottomRight = Offset(topWidth - t, h);
    final bottomLeft = Offset(t, h);

    path.moveTo(topLeft.dx + r, topLeft.dy);

    path.lineTo(topRight.dx - r, topRight.dy);
    path.quadraticBezierTo(topRight.dx, topRight.dy, topRight.dx - (r * 0.3), topRight.dy + (r * 0.5));

    path.lineTo(bottomRight.dx + (r * 0.3), bottomRight.dy - (r * 0.5));
    path.quadraticBezierTo(bottomRight.dx, bottomRight.dy, bottomRight.dx - r, bottomRight.dy);

    path.lineTo(bottomLeft.dx + r, bottomLeft.dy);
    path.quadraticBezierTo(bottomLeft.dx, bottomLeft.dy, bottomLeft.dx - (r * 0.3), bottomLeft.dy - (r * 0.5));

    path.lineTo(topLeft.dx + (r * 0.3), topLeft.dy + (r * 0.5));
    path.quadraticBezierTo(topLeft.dx, topLeft.dy, topLeft.dx + r, topLeft.dy);

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = getButtonPath(size);

    // 1. Bottom 3D Shadow
    final shadowPath = Path();
    shadowPath.addPath(path, const Offset(0, 5));
    final shadowPaint = Paint()
      ..color = const Color(0xFF7F1D1D).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shadowPath, shadowPaint);

    // 2. Main Body Gradient (Shiny Red Alert Gloss)
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFCA5A5),
          Color(0xFFF87171),
          Color(0xFFEF4444),
          Color(0xFFDC2626),
          Color(0xFF991B1B),
        ],
        stops: [0.0, 0.20, 0.50, 0.80, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, bodyPaint);

    // 3. Top Rim Highlight Stroke
    final highlightPath = Path();
    highlightPath.moveTo(radius, 1.5);
    highlightPath.lineTo(size.width - radius, 1.5);

    final highlightPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.70),
          Colors.white.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _RedTaperedButtonPainter oldDelegate) => false;
}

class _PopScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;

  const _PopScaleButton({
    required this.child,
    required this.onTap,
    this.scaleDown = 0.94,
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
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
