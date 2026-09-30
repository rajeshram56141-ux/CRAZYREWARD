import 'dart:async';
import 'dart:math';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../services/analytics_service.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import '../../../../../widgets/common/custom_toast.dart';
import 'crazy_racing_provider.dart';
import 'game_popup.dart';

// ==========================================
// 1. DATA MODELS & PARTICLES
// ==========================================

class _SparkParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double life;
  double size;

  _SparkParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    this.life = 1.0,
    required this.size,
  });
}

class _FloatingScore {
  double x;
  double y;
  final String text;
  final Color color;
  double opacity;
  double life;

  _FloatingScore({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.opacity = 1.0,
    this.life = 1.0,
  });
}

enum _VehicleType {
  yellowCar,
  purpleCar,
  orangeCar,
  redScooter,
  blueCar,
}

class _TrafficVehicle {
  double y; // Relative Y position (0.0 top to 1.1 bottom)
  int lane; // 0 = Left, 1 = Center, 2 = Right
  double speed;
  _VehicleType type;

  _TrafficVehicle({
    required this.y,
    required this.lane,
    required this.speed,
    required this.type,
  });
}

// ==========================================
// 2. MAIN CRAZY RACING SCREEN
// ==========================================

@RoutePage()
class DiamondCatchScreen extends ConsumerStatefulWidget {
  const DiamondCatchScreen({
    super.key,
    required this.userId,
    required this.gameGems,
    required this.installGems,
    required this.dailyGemsForInstall,
    required this.gemsRequired,
  });

  final String userId;
  final int gameGems;
  final int installGems;
  final int dailyGemsForInstall;
  final int gemsRequired;

  @override
  ConsumerState<DiamondCatchScreen> createState() => _DiamondCatchScreenState();
}

class _DiamondCatchScreenState extends ConsumerState<DiamondCatchScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final Random _random = Random();

  // Highway Racing State
  int _playerLane = 1; // 0 = Left, 1 = Center, 2 = Right
  double _playerCurrentX = 0.5; // Smooth lane transition position
  double _roadScroll = 0.0;
  final List<_TrafficVehicle> _trafficVehicles = [];
  int _spawnTimerCounter = 0;

  bool _isCountingDown = false;
  int _countdownNumber = 3;

  // Game Progress State
  bool _gameStarted = false;
  bool _isGameOver = false;
  bool _isGameWon = false;
  int _score = 0;
  int _targetScore = 100;
  int _movesLeft = 5; // Lives / Chances

  // Settings
  final bool _isVibrateOn = true;

  // Visual Effects Lists
  final List<_SparkParticle> _sparks = [];
  final List<_FloatingScore> _floatingScores = [];

  // Animation Controllers
  late AnimationController _gameLoopController;
  late AnimationController _startScreenEntranceController;
  late AnimationController _buttonPulseController;
  late Animation<double> _buttonScaleAnimation;
  late AnimationController _countdownAnimController;
  late Animation<double> _countdownScaleAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.userId.isNotEmpty) {
        ref.read(diamondCatchVerifierProvider(widget.userId));
      }
    });

    _startScreenEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOut),
    );

    _countdownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _countdownScaleAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _countdownAnimController, curve: Curves.elasticOut),
    );

    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateGameEngine);
    _gameLoopController.repeat();

    _setupNewGameRound();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _countdownAnimController.dispose();
    _gameLoopController.dispose();
    _startScreenEntranceController.dispose();
    _buttonPulseController.dispose();
    super.dispose();
  }

  void _pickRandomTargetScore() {
    final config = SplashService.superOfferConfig;
    final rawTargetScores = config['targetScores'];
    List<int> scoresList = [10, 20, 30];

    if (rawTargetScores is List) {
      scoresList = rawTargetScores
          .map((item) => int.tryParse(item.toString()) ?? 0)
          .where((n) => n > 0)
          .toList();
    } else if (rawTargetScores is String) {
      scoresList = rawTargetScores
          .split(',')
          .map((item) => int.tryParse(item.trim()) ?? 0)
          .where((n) => n > 0)
          .toList();
    }

    if (scoresList.isEmpty) {
      scoresList = [10, 20, 30];
    }

    final chosen = scoresList[_random.nextInt(scoresList.length)];
    _targetScore = chosen > 0 ? chosen : 10;
  }

  void _setupNewGameRound() {
    _pickRandomTargetScore();
    _movesLeft = 5;
    _score = 0;
    _isGameOver = false;
    _isGameWon = false;
    _playerLane = 1;
    _playerCurrentX = 0.5;
    _roadScroll = 0.0;
    _trafficVehicles.clear();
    _sparks.clear();
    _floatingScores.clear();
    _spawnTimerCounter = 0;
  }

  void _moveLeft() {
    if (!_gameStarted || _isCountingDown || _isGameOver || _isGameWon) return;
    if (_playerLane > 0) {
      setState(() {
        _playerLane--;
      });
      _triggerHaptic(HapticFeedbackType.light);
    }
  }

  void _moveRight() {
    if (!_gameStarted || _isCountingDown || _isGameOver || _isGameWon) return;
    if (_playerLane < 2) {
      setState(() {
        _playerLane++;
      });
      _triggerHaptic(HapticFeedbackType.light);
    }
  }

  void _startGame() {
    final verifier = ref.read(diamondCatchVerifierProvider(widget.userId)).value;
    if (verifier != null && verifier.gameEligible == false) {
      CustomToast.showToast(context, msg: 'Today game limit over, come tomorrow!');
      return;
    }
    AnalyticsService.logCustomEvent('crazy_racing_game_started');
    _triggerHaptic(HapticFeedbackType.medium);
    _setupNewGameRound();

    setState(() {
      _gameStarted = true;
      _isCountingDown = true;
      _countdownNumber = 3;
    });

    _countdownAnimController.forward(from: 0.0);

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_gameStarted) {
        timer.cancel();
        return;
      }

      if (_countdownNumber > 1) {
        setState(() {
          _countdownNumber--;
        });
        _triggerHaptic(HapticFeedbackType.light);
        _countdownAnimController.forward(from: 0.0);
      } else {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
        });
        _triggerHaptic(HapticFeedbackType.heavy);
      }
    });
  }

  void _triggerHaptic(HapticFeedbackType type) {
    if (!_isVibrateOn) return;
    switch (type) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
  }

  void _onGameWon() {
    for (int i = 0; i < 45; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.0 + _random.nextDouble() * 9.0;
      _sparks.add(
        _SparkParticle(
          x: 0.5.sw,
          y: 0.4.sh,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 2.0,
          color: _neonPalette[_random.nextInt(_neonPalette.length)],
          size: 5.0,
        ),
      );
    }
    _showResultPopup(isWin: true);
  }

  void _onGameOver() {
    _showResultPopup(isWin: false);
  }

  void _showResultPopup({required bool isWin}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameResultPopup(
        isWin: isWin,
        score: _score,
        stars: isWin ? 3 : 1,
        gameGems: widget.gameGems,
        installGems: widget.installGems,
        dailyGems: 0,
        dailyGemsForInstall: widget.dailyGemsForInstall,
        isInstallTask: false,
        onResume: !isWin
            ? () {
                setState(() {
                  _movesLeft = max(_movesLeft, 0) + 5;
                  _isGameOver = false;
                  _gameStarted = true;
                });
              }
            : null,
        onRestart: () {
          setState(() {
            _setupNewGameRound();
            _gameStarted = false;
          });
        },
        onHome: () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  static const List<Color> _neonPalette = [
    Color(0xFF38BDF8),
    Color(0xFF818CF8),
    Color(0xFFA855F7),
    Color(0xFFFBBF24),
    Color(0xFF34D399),
  ];

  void _spawnCrashSparks(double originX, double originY) {
    for (int i = 0; i < 22; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 4.0 + _random.nextDouble() * 8.0;
      _sparks.add(
        _SparkParticle(
          x: originX,
          y: originY,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: i % 2 == 0 ? const Color(0xFFFF3333) : const Color(0xFFFFD700),
          size: 5.5,
        ),
      );
    }
  }

  void _spawnScoreText(double originX, double originY, String text, Color color) {
    if (_floatingScores.length > 5) return;
    _floatingScores.add(
      _FloatingScore(
        x: originX,
        y: originY - 20,
        text: text,
        color: color,
      ),
    );
  }

  void _updateGameEngine() {
    if (!mounted) return;

    bool stateChanged = false;

    for (int i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.x += s.vx;
      s.y += s.vy;
      s.vy += 0.2;
      s.life -= 0.045;
      if (s.life <= 0) {
        _sparks.removeAt(i);
      }
    }

    for (int i = _floatingScores.length - 1; i >= 0; i--) {
      final f = _floatingScores[i];
      f.y -= 1.0;
      f.life -= 0.04;
      f.opacity = (f.life * 1.5).clamp(0.0, 1.0);
      if (f.life <= 0) {
        _floatingScores.removeAt(i);
      }
    }

    if (_gameStarted && !_isCountingDown && !_isGameOver && !_isGameWon) {
      _roadScroll = (_roadScroll + 0.016) % 1.0;

      final double targetX = _playerLane == 0
          ? 0.26
          : (_playerLane == 1 ? 0.50 : 0.74);
      _playerCurrentX += (targetX - _playerCurrentX) * 0.25;

      _spawnTimerCounter++;
      if (_spawnTimerCounter >= 36) {
        _spawnTimerCounter = 0;

        final lane = _random.nextInt(3);
        final types = _VehicleType.values;
        final type = types[_random.nextInt(types.length)];
        final speed = 0.009 + _random.nextDouble() * 0.007;

        bool blocked = _trafficVehicles.any((v) => v.lane == lane && v.y < 0.25);
        if (!blocked) {
          _trafficVehicles.add(_TrafficVehicle(
            y: -0.15,
            lane: lane,
            speed: speed,
            type: type,
          ));
        }
      }

      final double playerY = 0.78;

      for (int i = _trafficVehicles.length - 1; i >= 0; i--) {
        final vehicle = _trafficVehicles[i];
        vehicle.y += vehicle.speed;

        final double vehicleX = vehicle.lane == 0 ? 0.26 : (vehicle.lane == 1 ? 0.50 : 0.74);
        final double xDist = (_playerCurrentX - vehicleX).abs();
        final double yDist = (playerY - vehicle.y).abs();

        if (xDist < 0.14 && yDist < 0.10) {
          _trafficVehicles.removeAt(i);
          _movesLeft--;
          stateChanged = true;
          _triggerHaptic(HapticFeedbackType.heavy);

          final double px = _playerCurrentX * 1.0.sw;
          final double py = playerY * 1.0.sh;

          _spawnCrashSparks(px, py);
          _spawnScoreText(px, py, "CRASH! -1 CHANCE", const Color(0xFFFF3333));

          if (_movesLeft <= 0) {
            _isGameOver = true;
            _onGameOver();
          }
          continue;
        }

        if (vehicle.y > 1.05) {
          _trafficVehicles.removeAt(i);
          _score += 10;
          stateChanged = true;

          final double px = _playerCurrentX * 1.0.sw;
          _spawnScoreText(px, 0.65.sh, "+10", const Color(0xFFFFD700));

          if (_score >= _targetScore) {
            _isGameWon = true;
            _onGameWon();
          }
        }
      }
    }

    if (stateChanged || _gameStarted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = widget.userId.isNotEmpty
        ? widget.userId
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    final userGemsAsync = currentUid.isNotEmpty
        ? ref.watch(DashboardService.userGemsProvider(currentUid))
        : null;
    final int userGems = userGemsAsync?.value ?? widget.gemsRequired;

    return PopScope(
      canPop: !_gameStarted && !_isCountingDown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _gameStarted && !_isCountingDown) {
          setState(() {
            _gameStarted = false;
          });
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF15202B),
          body: Stack(
            children: [
              Positioned.fill(
                child: _gameStarted
                    ? _buildGameBoard()
                    : _buildStartScreen(userGems),
              ),

              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ParticleOverlayPainter(
                      sparks: _sparks,
                      floatingScores: _floatingScores,
                    ),
                  ),
                ),
              ),

              if (_isCountingDown)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65),
                    child: Center(
                      child: ScaleTransition(
                        scale: _countdownScaleAnim,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '$_countdownNumber',
                              style: GoogleFonts.fredoka(
                                fontSize: 130.sp,
                                fontWeight: FontWeight.w900,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 16
                                  ..color = const Color(0xFF0F172A),
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFFFD700),
                                  Color(0xFFFF9100),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Text(
                                '$_countdownNumber',
                                style: GoogleFonts.fredoka(
                                  fontSize: 130.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameBoard() {
    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _moveLeft,
                  child: Container(color: Colors.transparent),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _moveRight,
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),

        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _HighwayRacingCanvasPainter(
                playerX: _playerCurrentX,
                roadScroll: _roadScroll,
                trafficVehicles: _trafficVehicles,
                score: _score,
              ),
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PopScaleButton(
                  onTap: () {
                    if (_isCountingDown) return;
                    _triggerHaptic(HapticFeedbackType.light);
                    setState(() {
                      _gameStarted = false;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                ),

                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_rounded, color: const Color(0xFFFF4D4D), size: 16.sp),
                      SizedBox(width: 6.w),
                      Text(
                        '$_movesLeft LIVES',
                        style: GoogleFonts.fredoka(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'GOAL: $_targetScore',
                        style: GoogleFonts.fredoka(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartScreen(int userGems) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HighwayRacingCanvasPainter(
              playerX: 0.5,
              roadScroll: 0.0,
              trafficVehicles: [
                _TrafficVehicle(y: 0.22, lane: 0, speed: 0, type: _VehicleType.purpleCar),
                _TrafficVehicle(y: 0.75, lane: 2, speed: 0, type: _VehicleType.yellowCar),
              ],
              score: 0,
            ),
          ),
        ),

        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.72),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PopScaleButton(
                        onTap: () {
                          _triggerHaptic(HapticFeedbackType.light);
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1.5),
                          ),
                          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20.sp),
                        ),
                      ),

                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/icons/gems.png',
                              width: 22.w,
                              height: 22.w,
                              errorBuilder: (_, __, ___) => Icon(Icons.diamond_rounded, color: Colors.amber, size: 18.sp),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              '$userGems',
                              style: GoogleFonts.fredoka(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // 3D CRAZY RACING Logo Title
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CRAZY',
                      style: GoogleFonts.fredoka(
                        fontSize: 48.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        color: const Color(0xFFFF2222),
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                    ),
                    Text(
                      'RACING',
                      style: GoogleFonts.fredoka(
                        fontSize: 52.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 12, offset: const Offset(0, 5)),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 36.h),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: const Color(0xFF334155), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Tap left\nto move left',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Icon(Icons.touch_app_rounded, color: const Color(0xFFFFD700), size: 36.sp),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: 16.w),

                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: const Color(0xFF334155), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Tap right\nto move right',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.fredoka(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Transform.flip(
                              flipX: true,
                              child: Icon(Icons.touch_app_rounded, color: const Color(0xFFFFD700), size: 36.sp),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: _PopScaleButton(
                    onTap: () {
                      _triggerHaptic(HapticFeedbackType.medium);
                      _startGame();
                    },
                    child: Container(
                      width: 84.w,
                      height: 84.w,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFB703),
                            Color(0xFFFB8500),
                            Color(0xFFD00000),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFB8500).withValues(alpha: 0.8),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 48.sp,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. HIGHWAY RACING CANVAS PAINTER
// ==========================================

class _HighwayRacingCanvasPainter extends CustomPainter {
  final double playerX;
  final double roadScroll;
  final List<_TrafficVehicle> trafficVehicles;
  final int score;

  _HighwayRacingCanvasPainter({
    required this.playerX,
    required this.roadScroll,
    required this.trafficVehicles,
    required this.score,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double roadWidth = size.width * 0.68;
    final double roadLeft = (size.width - roadWidth) / 2;
    final double roadRight = roadLeft + roadWidth;
    final double laneWidth = roadWidth / 3;

    // 1. Draw Side Grass / Environment
    final grassPaint = Paint()..color = const Color(0xFF9CA3AF); // Light grass backdrop
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), grassPaint);

    final greenGrassLeft = Paint()..color = const Color(0xFFA3E635);
    canvas.drawRect(Rect.fromLTWH(0, 0, roadLeft, size.height), greenGrassLeft);

    final greenGrassRight = Paint()..color = const Color(0xFFA3E635);
    canvas.drawRect(Rect.fromLTWH(roadRight, 0, size.width - roadRight, size.height), greenGrassRight);

    // Environment Side Details
    _drawEnvironmentDetails(canvas, size, roadLeft, roadRight);

    // 2. Draw Side Curbs / Sidewalk Blocks
    final curbWidth = 14.0;
    final curbPaintLeft = Paint()..color = const Color(0xFF65A30D);
    canvas.drawRect(Rect.fromLTWH(roadLeft - curbWidth, 0, curbWidth, size.height), curbPaintLeft);

    final curbPaintRight = Paint()..color = const Color(0xFF65A30D);
    canvas.drawRect(Rect.fromLTWH(roadRight, 0, curbWidth, size.height), curbPaintRight);

    // Segmented Curb White Stripes
    final curbStripePaint = Paint()..color = Colors.white70;
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawRect(Rect.fromLTWH(roadLeft - curbWidth, y, curbWidth, 16), curbStripePaint);
      canvas.drawRect(Rect.fromLTWH(roadRight, y, curbWidth, 16), curbStripePaint);
    }

    // 3. Draw Road Asphalt Surface
    final roadPaint = Paint()..color = const Color(0xFF334155);
    canvas.drawRect(Rect.fromLTWH(roadLeft, 0, roadWidth, size.height), roadPaint);

    // 4. Draw White Dashed Lane Dividers (Scrolling Vertically)
    final laneDashPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final dashHeight = 36.0;
    final gapHeight = 24.0;
    final totalDashCycle = dashHeight + gapHeight;
    final scrollOffset = roadScroll * totalDashCycle;

    for (int laneIdx = 1; laneIdx <= 2; laneIdx++) {
      final double lx = roadLeft + (laneIdx * laneWidth);
      for (double y = -totalDashCycle + scrollOffset; y < size.height + totalDashCycle; y += totalDashCycle) {
        canvas.drawLine(Offset(lx, y), Offset(lx, y + dashHeight), laneDashPaint);
      }
    }

    // 5. Draw Top-Left Score Badge
    _drawScoreBadge(canvas, size, score);

    // 6. Draw Traffic Vehicles
    for (final vehicle in trafficVehicles) {
      final vx = roadLeft + (vehicle.lane + 0.5) * laneWidth;
      final vy = vehicle.y * size.height;
      _drawCar(canvas, position: Offset(vx, vy), type: vehicle.type, isPlayer: false);
    }

    // 7. Draw Player Car
    final px = playerX * size.width;
    final py = size.height * 0.78;
    _drawCar(canvas, position: Offset(px, py), type: _VehicleType.blueCar, isPlayer: true);
  }

  void _drawScoreBadge(Canvas canvas, Size size, int score) {
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 12, 110, 42),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, bgPaint);

    final scoreStr = '$score'.split('').join(' ');
    final textSpan = TextSpan(
      text: scoreStr,
      style: GoogleFonts.fredoka(
        fontSize: 22.sp,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 2.0,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(24, 18));
  }

  void _drawEnvironmentDetails(Canvas canvas, Size size, double roadLeft, double roadRight) {
    // Left Side Trees & Rocks
    final treePaint = Paint()..color = const Color(0xFF15803D);
    canvas.drawCircle(Offset(roadLeft - 45, 140), 28, treePaint);
    canvas.drawCircle(Offset(roadLeft - 30, 180), 22, treePaint);

    final rockPaint = Paint()..color = const Color(0xFF64748B);
    canvas.drawCircle(Offset(roadLeft - 40, 420), 18, rockPaint);
    canvas.drawCircle(Offset(roadLeft - 24, 435), 14, rockPaint);

    // Pedestrian with Dog on Left Side
    final pedPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(Offset(roadLeft - 35, 600), 7, pedPaint);

    // Right Side Beach Umbrellas & Parking Slots
    final umbrellaPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawCircle(Offset(roadRight + 45, 540), 26, umbrellaPaint);
    final umbrellaInner = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(roadRight + 45, 540), 12, umbrellaInner);

    final parkingSlotPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(Rect.fromLTWH(roadRight + 20, 30, 48, 28), parkingSlotPaint);
    canvas.drawRect(Rect.fromLTWH(roadRight + 20, 64, 48, 28), parkingSlotPaint);
    canvas.drawRect(Rect.fromLTWH(roadRight + 20, 98, 48, 28), parkingSlotPaint);
  }

  void _drawCar(
    Canvas canvas, {
    required Offset position,
    required _VehicleType type,
    required bool isPlayer,
  }) {
    canvas.save();
    canvas.translate(position.dx, position.dy);

    if (type == _VehicleType.redScooter) {
      final scooterPaint = Paint()..color = const Color(0xFFEF4444);
      final riderPaint = Paint()..color = const Color(0xFF2563EB);
      final helmetPaint = Paint()..color = const Color(0xFFFBBF24);
      final packPaint = Paint()..color = const Color(0xFF38BDF8);

      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-7, -18, 14, 36), const Radius.circular(7)), scooterPaint);
      canvas.drawCircle(const Offset(0, 0), 8, riderPaint);
      canvas.drawCircle(const Offset(0, -6), 6, helmetPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, 3, 10, 8), const Radius.circular(3)), packPaint);
      canvas.restore();
      return;
    }

    Color mainColor;
    Color darkColor;
    switch (type) {
      case _VehicleType.purpleCar:
        mainColor = const Color(0xFFA855F7);
        darkColor = const Color(0xFF7E22CE);
        break;
      case _VehicleType.yellowCar:
        mainColor = const Color(0xFFFACC15);
        darkColor = const Color(0xFFCA8A04);
        break;
      case _VehicleType.orangeCar:
        mainColor = const Color(0xFFF97316);
        darkColor = const Color(0xFFC2410C);
        break;
      case _VehicleType.blueCar:
      default:
        mainColor = const Color(0xFF2563EB);
        darkColor = const Color(0xFF1E40AF);
        break;
    }

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-19, -33, 38, 66), const Radius.circular(12)), shadowPaint);

    // Side Rear-view Mirrors (Exact Crop Image Match!)
    final mirrorPaint = Paint()..color = darkColor;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-22, -14, 5, 8), const Radius.circular(2)), mirrorPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(17, -14, 5, 8), const Radius.circular(2)), mirrorPaint);

    // Main Curved Convertible Body (Exact Crop Image Match!)
    final bodyPaint = Paint()..color = mainColor;
    final path = Path();
    path.moveTo(-14, -30);
    path.quadraticBezierTo(0, -35, 14, -30);
    path.quadraticBezierTo(19, -15, 19, 10);
    path.quadraticBezierTo(18, 28, 14, 31);
    path.quadraticBezierTo(0, 34, -14, 31);
    path.quadraticBezierTo(-18, 28, -19, 10);
    path.quadraticBezierTo(-19, -15, -14, -30);
    path.close();
    canvas.drawPath(path, bodyPaint);

    // Front Headlights
    final headlightPaint = Paint()..color = const Color(0xFFF8FAFC);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-15, -31, 5, 10), const Radius.circular(3)), headlightPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(10, -31, 5, 10), const Radius.circular(3)), headlightPaint);

    // Tinted Green Windshield Glass (Exact Crop Image Match!)
    final windshieldBorder = Paint()
      ..color = darkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final windshieldGlass = Paint()..color = const Color(0xFF4ADE80).withValues(alpha: 0.85);

    final wsPath = Path();
    wsPath.moveTo(-15, -19);
    wsPath.quadraticBezierTo(0, -22, 15, -19);
    wsPath.lineTo(13, -11);
    wsPath.quadraticBezierTo(0, -13, -13, -11);
    wsPath.close();
    canvas.drawPath(wsPath, windshieldGlass);
    canvas.drawPath(wsPath, windshieldBorder);

    // Open Cockpit Black Interior (Exact Crop Image Match!)
    final cockpitPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -10, 28, 26), const Radius.circular(5)), cockpitPaint);

    // Dual Black Leather Bucket Seats
    final seatPaint = Paint()..color = const Color(0xFF1E293B);
    final seatHighlight = Paint()..color = const Color(0xFF334155);

    // Left Seat
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -7, 10, 15), const Radius.circular(3)), seatPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -5, 8, 5), const Radius.circular(2)), seatHighlight);

    // Right Seat
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(2, -7, 10, 15), const Radius.circular(3)), seatPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3, -5, 8, 5), const Radius.circular(2)), seatHighlight);

    // Center Console
    final consolePaint = Paint()..color = mainColor;
    canvas.drawRect(const Rect.fromLTWH(-2, -7, 4, 18), consolePaint);

    // Rear Ribbed Engine Deck / Trunk Lid (Exact Crop Image Match!)
    final trunkPaint = Paint()..color = darkColor;
    for (double y = 18; y <= 28; y += 3.5) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-13, y, 26, 2), const Radius.circular(1)), trunkPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ParticleOverlayPainter extends CustomPainter {
  final List<_SparkParticle> sparks;
  final List<_FloatingScore> floatingScores;

  _ParticleOverlayPainter({
    required this.sparks,
    required this.floatingScores,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparks) {
      final paint = Paint()
        ..color = s.color.withValues(alpha: (s.life * 1.5).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(s.x, s.y), s.size * s.life, paint);
    }

    for (final f in floatingScores) {
      final textSpan = TextSpan(
        text: f.text,
        style: GoogleFonts.fredoka(
          fontSize: 16.sp,
          fontWeight: FontWeight.w900,
          color: f.color.withValues(alpha: f.opacity),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(f.x - textPainter.width / 2, f.y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PopScaleButton extends StatefulWidget {
  const _PopScaleButton({
    required this.onTap,
    required this.child,
    this.scaleDown = 0.92,
  });

  final VoidCallback onTap;
  final Widget child;
  final double scaleDown;

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
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOutBack,
        child: widget.child,
      ),
    );
  }
}

enum HapticFeedbackType { light, medium, heavy }
