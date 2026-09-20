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
import 'diamond_catch_provider.dart';
import 'game_popup.dart';

// ==========================================
// 1. DATA STRUCTURES & PARTICLES
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

// ==========================================
// 2. MAIN DIAMOND CATCH SCREEN
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



  // Falling Catcher Game State
  double _pandaX = 0.5;
  final List<_FallingItem> _fallingItems = [];
  int _spawnCounter = 0;
  bool _isCountingDown = false;
  int _countdownNumber = 3;

  // Game Progress State
  bool _gameStarted = false;
  bool _isGameOver = false;
  bool _isGameWon = false;
  int _score = 0;
  int _targetScore = 100;
  int _movesLeft = 18;
  int _comboCount = 0;

  // Settings
  bool _isSoundOn = true;
  bool _isVibrateOn = true;

  // Visual Effects Lists
  final List<_SparkParticle> _sparks = [];
  final List<_FloatingScore> _floatingScores = [];

  // Animation Controllers
  late AnimationController _gameLoopController;
  late AnimationController _startScreenEntranceController;
  late AnimationController _buttonPulseController;
  late Animation<double> _buttonScaleAnimation;
  late AnimationController _scorePopController;
  late AnimationController _basketBounceController;
  late Animation<double> _basketScaleAnimation;
  late AnimationController _countdownAnimController;
  late Animation<double> _countdownScaleAnim;



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Hide status bar for immersive full-screen game experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Pre-fetch Diamond Catch daily limits so Redis & server state are ready immediately
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

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOut),
    );

    _scorePopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _basketBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _basketScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeInCubic)), weight: 50),
    ]).animate(_basketBounceController);

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
    )..addListener(_updateGameParticles);
    _gameLoopController.repeat();

    _setupNewGameRound();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore status bar on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _basketBounceController.dispose();
    _countdownAnimController.dispose();
    _gameLoopController.dispose();
    _startScreenEntranceController.dispose();
    _buttonPulseController.dispose();
    _scorePopController.dispose();
    super.dispose();
  }

  // ==========================================
  // 3. GAME INITIALIZATION & BOARD SETUP
  // ==========================================

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

    // Pick exact target score set in admin
    final chosen = scoresList[_random.nextInt(scoresList.length)];
    _targetScore = chosen > 0 ? chosen : 10;
  }

  void _setupNewGameRound() {
    _pickRandomTargetScore();
    _movesLeft = 5; // 18 Chances / Lives
    _score = 0;
    _comboCount = 0;
    _isGameOver = false;
    _isGameWon = false;
    _pandaX = 0.5;
    _fallingItems.clear();
    _spawnCounter = 0;
  }

  void _startGame() {
    final verifier = ref.read(diamondCatchVerifierProvider(widget.userId)).value;
    if (verifier != null && verifier.gameEligible == false) {
      CustomToast.showToast(context, msg: 'Today game limit over, come tomorrow!');
      return;
    }
    AnalyticsService.logCustomEvent('diamond_catch_game_started');
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
        // Countdown finished! Game starts!
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

  // ==========================================
  // 6. VICTORY & GAME OVER HANDLERS
  // ==========================================

  void _onGameWon() {
    // Victory celebration sparks
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
            _gameStarted = false; // Returns to Diamond Catch Splash/Start Screen
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

  // ==========================================
  // 7. PARTICLES & VISUAL EFFECTS
  // ==========================================

  static const List<Color> _neonPalette = [
    Color(0xFF38BDF8), // Cyan
    Color(0xFF818CF8), // Indigo
    Color(0xFFA855F7), // Purple
    Color(0xFFC084FC), // Lilac
    Color(0xFFE879F9), // Fuchsia
    Color(0xFFFBBF24), // Amber Gold
    Color(0xFF34D399), // Emerald
  ];



  static const List<Color> _diamondShatterPalette = [
    Color(0xFF38BDF8), // Bright Cyan Diamond
    Color(0xFFE0F2FE), // Pure Crystal White
    Color(0xFF7DD3FC), // Light Sky Blue
    Color(0xFFFFD700), // Sparkling Gold
    Color(0xFFFFFFFF), // Pure Specular White
  ];

  void _spawnDiamondShatterSparks(double originX, double originY) {
    if (_sparks.length > 22) return;
    for (int i = 0; i < 10; i++) {
      final angle = -pi / 2 + (_random.nextDouble() - 0.5) * 1.5; // Upward crystal shatter burst!
      final speed = 3.5 + _random.nextDouble() * 6.5;
      _sparks.add(
        _SparkParticle(
          x: originX,
          y: originY,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: _diamondShatterPalette[_random.nextInt(_diamondShatterPalette.length)],
          size: 3.5 + _random.nextDouble() * 3.0,
        ),
      );
    }
  }

  void _spawnCatchSparks(double originX, double originY, Color color) {
    if (_sparks.length > 20) return;
    for (int i = 0; i < 8; i++) {
      final angle = -pi / 2 + (_random.nextDouble() - 0.5) * 1.2;
      final speed = 3.5 + _random.nextDouble() * 5.5;
      _sparks.add(
        _SparkParticle(
          x: originX,
          y: originY,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: color,
          size: 4.5,
        ),
      );
    }
  }

  void _spawnCatchScore(double originX, double originY, String text, Color color) {
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

  void _updateGameParticles() {
    if (!mounted) return;

    bool stateChanged = false;

    // Update sparks
    for (int i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.x += s.vx;
      s.y += s.vy;
      s.vy += 0.25; // gravity
      s.life -= 0.045;
      if (s.life <= 0) {
        _sparks.removeAt(i);
      }
    }

    // Update floating score texts
    for (int i = _floatingScores.length - 1; i >= 0; i--) {
      final f = _floatingScores[i];
      f.y -= 1.0;
      f.life -= 0.04;
      f.opacity = (f.life * 1.5).clamp(0.0, 1.0);
      if (f.life <= 0) {
        _floatingScores.removeAt(i);
      }
    }

    // FALLING CRAZYREWARD CATCHER PHYSICS & COLLISION
    if (_gameStarted && !_isCountingDown && !_isGameOver && !_isGameWon) {
      _spawnCounter++;
      // Spawn new falling item every ~28 ticks
      if (_spawnCounter >= 28) {
        _spawnCounter = 0;
        final bool isBomb = _random.nextDouble() < 0.24; // 24% bomb, 76% diamond
        final double speed = 0.007 + _random.nextDouble() * 0.008;
        _fallingItems.add(_FallingItem(
          x: 0.10 + _random.nextDouble() * 0.80,
          y: 0.0,
          speed: speed,
          isBomb: isBomb,
          points: isBomb ? 0 : 10,
        ));
      }

      final double boardWidth = 0.92.sw;
      final double boardHeight = 0.58.sh;

      for (int i = _fallingItems.length - 1; i >= 0; i--) {
        final item = _fallingItems[i];
        item.y += item.speed;

        // Accurate Catch Collision Check Visible Right In Front of Panda Basket
        if (item.y >= 0.82 && item.y <= 0.90) {
          if ((item.x - _pandaX).abs() <= 0.15) {
            // CAUGHT ACCURATELY INSIDE BASKET!
            _fallingItems.removeAt(i);

            final px = 0.04.sw + item.x * boardWidth;
            final py = 0.28.sh + item.y * boardHeight;

            if (item.isBomb) {
              // BOMB CAUGHT! Deduct chance
              _movesLeft--;
              stateChanged = true;
              _triggerHaptic(HapticFeedbackType.heavy);
              _spawnCatchScore(px, py, "-1 CHANCE", const Color(0xFFFF4D4D));
              _spawnCatchSparks(px, py, const Color(0xFFFF4D4D));

              if (_movesLeft <= 0) {
                _isGameOver = true;
                _onGameOver();
              }
            } else {
              // GEM CAUGHT! Add +10 score
              _score += item.points;
              stateChanged = true;
              _triggerHaptic(HapticFeedbackType.light);
              _spawnCatchScore(px, py, "+10", const Color(0xFFFFD700));
              _spawnDiamondShatterSparks(px, py);

              if (_score >= _targetScore) {
                _isGameWon = true;
                _onGameWon();
              }
            }
            continue;
          }
        }

        // Missed item off bottom
        if (item.y > 1.05) {
          _fallingItems.removeAt(i);
        }
      }
    }

    if (stateChanged) {
      setState(() {});
    }
  }

  // ==========================================
  // 8. BUILD UI WIDGETS
  // ==========================================

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
          backgroundColor: const Color(0xFF101010),
          body: Stack(
            children: [
              // 1. Full Cartoon Nature Background Image (assets/icons/bg.png) - 100% Pure & Bright
              Positioned.fill(
                child: Image.asset(
                  'assets/icons/bg.png',
                  fit: BoxFit.cover,
                ),
              ),

              // 4. Safe Area Foreground Content
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(userGems),
                    Expanded(
                      child: _gameStarted
                          ? _buildGameBoard()
                          : _buildStartScreen(userGems),
                    ),
                  ],
                ),
              ),

              // 5. Particle FX Overlay
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

              // 6. 100% Fullscreen 3D Cartoon 3-2-1 Countdown Overlay (Blocks ALL Taps & Gestures)
              if (_isCountingDown)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    onPanStart: (_) {},
                    onPanUpdate: (_) {},
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Center(
                        child: ScaleTransition(
                          scale: _countdownScaleAnim,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 3D Shadow Stroke Outline
                              Text(
                                '$_countdownNumber',
                                style: GoogleFonts.fredoka(
                                  fontSize: 130.sp,
                                  fontWeight: FontWeight.w900,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 16
                                    ..color = const Color(0xFF3E1C03),
                                ),
                              ),
                              // Glossy Candy Gradient Text
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    Color(0xFFFFFFFF), // White Specular Shine
                                    Color(0xFFFFE082), // Soft Amber
                                    Color(0xFFFFB300), // Rich Gold
                                    Color(0xFFE65100), // Deep Warm Orange
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int userGems) {
    if (_gameStarted) return SizedBox(height: 8.h);
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 3D Cartoon Custom Back Button
          _PopScaleButton(
            onTap: () {
              _triggerHaptic(HapticFeedbackType.light);
              Navigator.of(context).pop();
            },
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF87171), // Top Gloss Red
                    Color(0xFFEF4444), // Vibrant Red
                    Color(0xFFB91C1C), // Deep 3D Shadow Red
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700), // Gold Rim
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),

          // Top-Right "YOUR GEMS" Badge Card
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: const Color(0xFF81C784),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/gems.png',
                  width: 24.w,
                  height: 24.w,
                ),
                SizedBox(width: 6.w),
                Text(
                  '$userGems',
                  style: GoogleFonts.fredoka(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 9. GAME BOARD & HUD (CANDY CRUSH STYLE)
  // ==========================================

  Widget _buildGameBoard() {
    final double targetProgress = (_score / _targetScore).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          SizedBox(height: 6.h),

          // 3D Cartoon Wooden HUD Banner with Integrated Back Button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6E370F), // Top Wood Highlight
                  Color(0xFF8B4513), // Mid Warm Wood
                  Color(0xFF532809), // Bottom Wood Shadow
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: const Color(0xFFFFD700), // Gold Beveled Rim
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // 3D Cartoon Custom Back Button inside HUD Banner
                    _PopScaleButton(
                      onTap: () {
                        if (_isCountingDown) return;
                        _triggerHaptic(HapticFeedbackType.light);
                        setState(() {
                          _gameStarted = false;
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(right: 6.w),
                        padding: EdgeInsets.all(7.r),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFF87171), // Top Gloss Red
                              Color(0xFFEF4444), // Vibrant Red
                              Color(0xFFB91C1C), // Deep 3D Shadow Red
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFD700), // Gold Rim
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Target Box
                          _buildHudStat(
                            label: 'TARGET SCORE',
                            value: '$_score / $_targetScore',
                            color: const Color(0xFFFFD700),
                            icon: Icons.emoji_events_rounded,
                          ),

                          // Chances Box
                          _buildHudStat(
                            label: 'CHANCE',
                            value: '$_movesLeft',
                            color: _movesLeft <= 1 ? const Color(0xFFFF4D4D) : const Color(0xFF4ADE80),
                            icon: Icons.favorite_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10.h),

                // 3D Candy Lime Progress Bar Slot
                Container(
                  padding: EdgeInsets.all(2.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C1607),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFF8B4513),
                      width: 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      height: 10.h,
                      color: const Color(0xFF1E0E04),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          widthFactor: targetProgress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFEF08A), // Top Candy Gloss
                                  Color(0xFFBEF264), // Bright Lime
                                  Color(0xFF22C55E), // Vivid Green
                                  Color(0xFF15803D), // Bottom Green Base
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.0, 0.25, 0.70, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(8.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.9),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Full-Screen Unboxed Falling Game Play Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double areaWidth = constraints.maxWidth;
                final double areaHeight = constraints.maxHeight;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) {
                    final dx = details.localPosition.dx;
                    _pandaX = (dx / areaWidth).clamp(0.08, 0.92);
                  },
                  onPanUpdate: (details) {
                    final dx = details.localPosition.dx;
                    _pandaX = (dx / areaWidth).clamp(0.08, 0.92);
                  },
                  child: AnimatedBuilder(
                    animation: _gameLoopController,
                    builder: (context, child) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Panda Basket Mascot at Bottom (Steady & Smooth)
                          Positioned(
                            left: _pandaX * areaWidth - 120.w,
                            bottom: 0.h,
                            child: Image.asset(
                              'assets/icons/diamondcatchpnda.png',
                              width: 240.w,
                              height: 240.w,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/icons/panda1.png',
                                width: 190.w,
                                height: 190.w,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          // 2. Render Falling Items (Diamonds & Bombs - Rendered IN FRONT of Panda)
                          for (final item in _fallingItems)
                            Positioned(
                              left: item.x * areaWidth - 22.w,
                              top: item.y * areaHeight - 22.w,
                              child: item.isBomb
                                  ? Container(
                                      width: 44.w,
                                      height: 44.w,
                                      alignment: Alignment.center,
                                      child: Text(
                                        '💣',
                                        style: TextStyle(fontSize: 32.sp),
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/icons/gems.png',
                                      width: 44.w,
                                      height: 44.w,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.diamond_rounded,
                                        color: const Color(0xFF38BDF8),
                                        size: 34.sp,
                                      ),
                                    ),
                            ),

                          // 3. Drag Guide Instruction Pill (shows initially)
                          if (_score == 0)
                            Positioned(
                              bottom: 115.h,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: const Color(0xFFFFD700),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app_rounded, color: const Color(0xFFFFD700), size: 14.sp),
                                      SizedBox(width: 6.w),
                                      Text(
                                        'Drag Panda to catch Gems! Avoid 💣!',
                                        style: GoogleFonts.fredoka(
                                          fontSize: 10.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 14.h),
        ],
      ),
    );
  }

  Widget _buildHudStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16.sp),
        SizedBox(width: 4.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.fredoka(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 10. START SCREEN
  // ==========================================

  Widget _buildStartScreen(int userGems) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.08),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _startScreenEntranceController,
          curve: Curves.easeOutCubic,
        ),
      ),
      child: FadeTransition(
        opacity: _startScreenEntranceController,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 1. Panda Mascot & 3D DIAMOND CATCH Logo Composite (Panda above with bottom fade)
              Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  // Fading Panda Mascot Icon on Top
                  Padding(
                    padding: EdgeInsets.only(bottom: 24.h),
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.black, Colors.transparent],
                          stops: [0.0, 0.55, 0.95],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        'assets/icons/panda1.png',
                        width: 200.w,
                        height: 200.w,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/gems.png',
                          width: 150.w,
                          height: 150.w,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // 3D Cartoon Game Logo Text (DIAMOND CATCH) Overlapping Faded Bottom
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 3D Shadow Stroke Outline
                      Text(
                        'DIAMOND CATCH',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fredoka(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          height: 1.1,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 6.5
                            ..color = const Color(0xFF3E1C03),
                        ),
                      ),
                      // Glossy Top Text
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF), // White Specular Shine
                            Color(0xFFFFF176), // Bright Yellow
                            Color(0xFFFFB300), // Rich Gold
                            Color(0xFFFB8C00), // Warm Orange Base
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.35, 0.75, 1.0],
                        ).createShader(bounds),
                        child: Text(
                          'DIAMOND CATCH',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fredoka(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.2,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 8.h),

              // 3D Wooden Slogan Ribbon
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF795548), Color(0xFF4E342E)],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'SWIPE • CLEAR GRID • WIN GEMS',
                  style: GoogleFonts.fredoka(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFECB3),
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              SizedBox(height: 28.h),

              SizedBox(height: 26.h),

              // 4. GIANT 3D Arcade Play Button
              ScaleTransition(
                scale: _buttonScaleAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: _PopScaleButton(
                    onTap: () {
                      _triggerHaptic(HapticFeedbackType.medium);
                      _startGame();
                    },
                    child: Container(
                      width: double.infinity,
                      height: 54.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF86EFAC), // Top Candy Gloss
                            Color(0xFF22C55E), // Vibrant Mid Green
                            Color(0xFF16A34A), // Rich Green
                            Color(0xFF15803D), // Bottom 3D Bevel Shadow
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.25, 0.70, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFFDCFCE7),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF15803D).withValues(alpha: 0.8),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(6.r),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: const Color(0xFF15803D),
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              'PLAY NOW',
                              maxLines: 1,
                              style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 11. CUSTOM PAINTERS & POP BUTTON WIDGETS
// ==========================================



class _ParticleOverlayPainter extends CustomPainter {
  final List<_SparkParticle> sparks;
  final List<_FloatingScore> floatingScores;

  _ParticleOverlayPainter({
    required this.sparks,
    required this.floatingScores,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Sparks
    for (final s in sparks) {
      final paint = Paint()
        ..color = s.color.withValues(alpha: (s.life * 1.5).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(s.x, s.y), s.size * s.life, paint);
    }

    // Draw Floating Scores
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

class _FallingItem {
  double x;
  double y;
  final double speed;
  final bool isBomb;
  final int points;

  _FallingItem({
    required this.x,
    required this.y,
    required this.speed,
    required this.isBomb,
    this.points = 5,
  });
}
