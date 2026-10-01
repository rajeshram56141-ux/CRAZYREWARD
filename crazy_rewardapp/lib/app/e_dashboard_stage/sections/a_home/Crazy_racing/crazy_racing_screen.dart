import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

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

class _EnvironmentImages {
  final ui.Image? leftGrass;
  final ui.Image? rightGrass;
  final ui.Image? palmTree;
  final ui.Image? rock;
  final ui.Image? bush;
  final ui.Image? parkingArea;
  final ui.Image? umbrella;
  final ui.Image? bigTree;
  final ui.Image? pedestrian;
  final ui.Image? womanSuitcase;
  final ui.Image? redScooter;
  final ui.Image? smallPlant;
  final ui.Image? yellowCar;
  final ui.Image? purpleCar;
  final ui.Image? cr20Car;

  _EnvironmentImages({
    this.leftGrass,
    this.rightGrass,
    this.palmTree,
    this.rock,
    this.bush,
    this.parkingArea,
    this.umbrella,
    this.bigTree,
    this.pedestrian,
    this.womanSuitcase,
    this.redScooter,
    this.smallPlant,
    this.yellowCar,
    this.purpleCar,
    this.cr20Car,
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

  ui.Image? _playerCarImage;
  _EnvironmentImages? _envImages;
  bool _isAssetsLoading = true;

  Future<ui.Image?> _loadFirstAvailableImage(List<String> paths) async {
    for (final path in paths) {
      try {
        final ByteData data = await rootBundle.load(path);
        final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final ui.FrameInfo fi = await codec.getNextFrame();
        return fi.image;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _loadPlayerCarImage() async {
    final img = await _loadFirstAvailableImage([
      'assets/Icons1/purple-car.png.png',
      'assets/Icons1/purple-car.png',
    ]);
    if (mounted && img != null) {
      setState(() {
        _playerCarImage = img;
      });
    }
  }

  Future<void> _loadEnvironmentImages() async {
    final results = await Future.wait([
      _loadFirstAvailableImage(['assets/Icons1/full_green_grass.png', 'assets/Icons1/left &right-grass.png(28).png', 'assets/Icons1/left-grass.png.png']),
      _loadFirstAvailableImage(['assets/Icons1/full_green_grass.png', 'assets/Icons1/left &right-grass.png(28).png', 'assets/Icons1/left-grass.png.png']),
      _loadFirstAvailableImage(['assets/Icons1/palm-tree.png', 'assets/Icons1/palm-tree (2).png']),
      _loadFirstAvailableImage(['assets/Icons1/rock.png']),
      _loadFirstAvailableImage(['assets/Icons1/bush.png']),
      _loadFirstAvailableImage(['assets/Icons1/parking-area.png']),
      _loadFirstAvailableImage(['assets/Icons1/umbrella.png', 'assets/Icons1/umbrella (2).png']),
      _loadFirstAvailableImage(['assets/Icons1/big-tree.png']),
      _loadFirstAvailableImage(['assets/Icons1/small-pedestrian.png', 'assets/Icons1/small-pedestrian (2).png']),
      _loadFirstAvailableImage(['assets/Icons1/woman-suitcase.png', 'assets/Icons1/woman-suitcase (2).png']),
      _loadFirstAvailableImage(['assets/Icons1/red-scooter.png', 'assets/Icons1/red-scooter (2).png']),
      _loadFirstAvailableImage(['assets/Icons1/small-plant.png', 'assets/Icons1/small-plant (2).png']),
      _loadFirstAvailableImage(['assets/Icons1/yellow-car.png.png', 'assets/Icons1/yellow-car.png']),
      _loadFirstAvailableImage(['assets/Icons1/purple-car.png.png', 'assets/Icons1/purple-car.png']),
      _loadFirstAvailableImage(['assets/Icons1/CR (20).png']),
    ]);

    if (mounted) {
      setState(() {
        _envImages = _EnvironmentImages(
          leftGrass: results[0],
          rightGrass: results[1] ?? results[0],
          palmTree: results[2],
          rock: results[3],
          bush: results[4],
          parkingArea: results[5],
          umbrella: results[6],
          bigTree: results[7],
          pedestrian: results[8],
          womanSuitcase: results[9],
          redScooter: results[10],
          smallPlant: results[11],
          yellowCar: results[12],
          purpleCar: results[13],
          cr20Car: results[14],
        );
        _isAssetsLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPlayerCarImage();
    _loadEnvironmentImages();
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
      if (_spawnTimerCounter >= 28) {
        _spawnTimerCounter = 0;

        final lane = _random.nextInt(3);
        final types = _VehicleType.values;
        final type = types[_random.nextInt(types.length)];
        final speed = 0.016 + _random.nextDouble() * 0.010;

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

    if (_isAssetsLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF09090E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90.w,
                height: 90.w,
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD700), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/Icons1/Crazy Racing.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.directions_car_rounded, color: Colors.amber, size: 44.sp),
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: 32.w,
                height: 32.w,
                child: const CircularProgressIndicator(
                  color: Color(0xFFFFD700),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'LOADING CRAZY RACING...',
                style: GoogleFonts.fredoka(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                playerCarImage: _playerCarImage,
                envImages: _envImages,
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
              playerCarImage: _playerCarImage,
              envImages: _envImages,
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
  final ui.Image? playerCarImage;
  final _EnvironmentImages? envImages;

  static final Paint _grassPaint = Paint()..color = const Color(0xFF2E7D32);
  static final Paint _greenGrassSide = Paint()..color = const Color(0xFF388E3C);
  static final Paint _roadPaint = Paint()..color = const Color(0xFF1E293B);
  static final Paint _laneDashPaint = Paint()
    ..color = const Color(0xFFF8FAFC)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;
  static final Paint _fastImgPaint = Paint()..filterQuality = FilterQuality.low;

  _HighwayRacingCanvasPainter({
    required this.playerX,
    required this.roadScroll,
    required this.trafficVehicles,
    required this.score,
    this.playerCarImage,
    this.envImages,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double roadWidth = size.width * 0.68;
    final double roadLeft = (size.width - roadWidth) / 2;
    final double roadRight = roadLeft + roadWidth;
    final double laneWidth = roadWidth / 3;

    // 1. Draw Side Grass / Environment
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _grassPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, roadLeft, size.height), _greenGrassSide);
    canvas.drawRect(Rect.fromLTWH(roadRight, 0, size.width - roadRight, size.height), _greenGrassSide);

    final double worldScrollY = roadScroll * size.height;

    // Draw Left Grass Panel
    if (envImages?.leftGrass != null) {
      final double leftSideWidth = roadLeft;
      final double drawWidth = leftSideWidth * 1.5;
      final double imgDrawHeight = drawWidth * (envImages!.leftGrass!.height / envImages!.leftGrass!.width);
      final double scrollY = worldScrollY % imgDrawHeight;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, leftSideWidth, size.height));
      final srcRect = Rect.fromLTWH(0, 0, envImages!.leftGrass!.width.toDouble(), envImages!.leftGrass!.height.toDouble());
      for (double y = -imgDrawHeight + scrollY; y < size.height + imgDrawHeight; y += imgDrawHeight) {
        if (y + imgDrawHeight >= 0 && y <= size.height) {
          canvas.drawImageRect(envImages!.leftGrass!, srcRect, Rect.fromLTWH(0, y, drawWidth, imgDrawHeight), _fastImgPaint);
        }
      }
      canvas.restore();
    }

    // Draw Right Grass Panel
    if (envImages?.rightGrass != null) {
      final double rightSideWidth = size.width - roadRight;
      final double drawWidth = rightSideWidth * 1.5;
      final double imgDrawHeight = drawWidth * (envImages!.rightGrass!.height / envImages!.rightGrass!.width);
      final double scrollY = worldScrollY % imgDrawHeight;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(roadRight, 0, rightSideWidth, size.height));
      final srcRect = Rect.fromLTWH(0, 0, envImages!.rightGrass!.width.toDouble(), envImages!.rightGrass!.height.toDouble());
      for (double y = -imgDrawHeight + scrollY; y < size.height + imgDrawHeight; y += imgDrawHeight) {
        if (y + imgDrawHeight >= 0 && y <= size.height) {
          canvas.drawImageRect(envImages!.rightGrass!, srcRect, Rect.fromLTWH(roadRight - (drawWidth - rightSideWidth), y, drawWidth, imgDrawHeight), _fastImgPaint);
        }
      }
      canvas.restore();
    }

    // Draw Side Props (Pedestrians, Parking area, Umbrellas, Trees, Scooter, Rocks)
    _drawSideAssets(canvas, size, roadLeft, roadRight, worldScrollY);

    // 3. Draw Road Asphalt Surface
    canvas.drawRect(Rect.fromLTWH(roadLeft, 0, roadWidth, size.height), _roadPaint);

    // 4. Draw White Dashed Lane Dividers
    final dashHeight = 36.0;
    final gapHeight = 24.0;
    final totalDashCycle = dashHeight + gapHeight;
    final scrollOffset = worldScrollY % totalDashCycle;

    for (int laneIdx = 1; laneIdx <= 2; laneIdx++) {
      final double lx = roadLeft + (laneIdx * laneWidth);
      for (double y = -totalDashCycle + scrollOffset; y < size.height + totalDashCycle; y += totalDashCycle) {
        if (y + dashHeight >= 0 && y <= size.height) {
          canvas.drawLine(Offset(lx, y), Offset(lx, y + dashHeight), _laneDashPaint);
        }
      }
    }

    // 6. Draw Traffic Vehicles
    for (final vehicle in trafficVehicles) {
      final vx = roadLeft + (vehicle.lane + 0.5) * laneWidth;
      final vy = vehicle.y * size.height;
      if (vy + 120 >= 0 && vy - 120 <= size.height) {
        _drawCar(canvas, position: Offset(vx, vy), type: vehicle.type, isPlayer: false);
      }
    }

    // 7. Draw Player Car
    final px = playerX * size.width;
    final py = size.height * 0.78;

    if (playerCarImage != null) {
      final double carHeight = 122.h;
      final double carWidth = carHeight * (playerCarImage!.width / playerCarImage!.height);

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(pi);

      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: carWidth,
        height: carHeight,
      );

      canvas.drawImageRect(
        playerCarImage!,
        Rect.fromLTWH(0, 0, playerCarImage!.width.toDouble(), playerCarImage!.height.toDouble()),
        rect,
        _fastImgPaint,
      );
      canvas.restore();
    } else {
      _drawCar(canvas, position: Offset(px, py), type: _VehicleType.blueCar, isPlayer: true);
    }
  }

  void _drawImage(
    Canvas canvas,
    ui.Image? img, {
    required double x,
    required double y,
    required double width,
    required double height,
    double screenHeight = 2000.0,
  }) {
    if (img == null) return;
    if (y + height < -50 || y > screenHeight + 50) return;
    final destRect = Rect.fromLTWH(x, y, width, height);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      destRect,
      _fastImgPaint,
    );
  }

  void _drawSideAssets(Canvas canvas, Size size, double roadLeft, double roadRight, double worldScrollY) {
    if (envImages == null) {
      _drawEnvironmentDetails(canvas, size, roadLeft, roadRight);
      return;
    }

    final double cycleHeight = size.height * 1.5;
    final double scrollY = worldScrollY % cycleHeight;

    for (int cycle = -1; cycle <= 1; cycle++) {
      final double baseOffset = cycle * cycleHeight + scrollY;

      // --- LEFT SIDE PROPS (Extra Large Coconut Palm Trees + Big Humans) ---
      // 1. Coconut Palm Tree 1 (Top Left)
      _drawImage(
        canvas,
        envImages!.palmTree,
        x: roadLeft - 195.w,
        y: baseOffset + (cycleHeight * 0.05),
        width: 265.w,
        height: 265.w,
      );

      // 2. Human: Pedestrian with luggage (Upper Mid Left - Extra Large)
      _drawImage(
        canvas,
        envImages!.pedestrian,
        x: roadLeft - 75.w,
        y: baseOffset + (cycleHeight * 0.28),
        width: 80.w,
        height: 80.w,
      );

      // 3. Coconut Palm Tree 2 (Mid Left)
      _drawImage(
        canvas,
        envImages!.palmTree,
        x: roadLeft - 195.w,
        y: baseOffset + (cycleHeight * 0.42),
        width: 265.w,
        height: 265.w,
      );

      // 4. Human: Woman with suitcase (Lower Mid Left - Extra Large)
      _drawImage(
        canvas,
        envImages!.womanSuitcase,
        x: roadLeft - 75.w,
        y: baseOffset + (cycleHeight * 0.65),
        width: 80.w,
        height: 105.h,
      );

      // 5. Coconut Palm Tree 3 (Bottom Left)
      _drawImage(
        canvas,
        envImages!.palmTree,
        x: roadLeft - 195.w,
        y: baseOffset + (cycleHeight * 0.82),
        width: 265.w,
        height: 265.w,
      );

      // --- RIGHT SIDE PROPS (Extra Large Coconut Palm Trees & Parked Scooter) ---
      // 1. Top Right Parking Lot with Cars (Extra Large)
      if (envImages!.parkingArea != null) {
        final img = envImages!.parkingArea!;
        final double aspect = img.width / img.height;
        final double parkW = 135.w;
        final double parkH = parkW / aspect;
        _drawImage(
          canvas,
          img,
          x: roadRight + 4.w,
          y: baseOffset + (cycleHeight * 0.06),
          width: parkW,
          height: parkH,
        );
      }

      // 2. Coconut Palm Tree 1 (Upper Right)
      _drawImage(
        canvas,
        envImages!.palmTree,
        x: roadRight - 20.w,
        y: baseOffset + (cycleHeight * 0.28),
        width: 265.w,
        height: 265.w,
      );

      // 3. Human: Beach Umbrella with Relaxing Person (Extra Large)
      _drawImage(
        canvas,
        envImages!.umbrella,
        x: roadRight + 8.w,
        y: baseOffset + (cycleHeight * 0.50),
        width: 160.w,
        height: 160.w,
      );

      // 4. Coconut Palm Tree 2 (Lower Mid Right)
      _drawImage(
        canvas,
        envImages!.palmTree,
        x: roadRight - 20.w,
        y: baseOffset + (cycleHeight * 0.68),
        width: 265.w,
        height: 265.w,
      );

      // 5. Parked Red Scooter (Extra Large & Bold)
      _drawImage(
        canvas,
        envImages!.redScooter,
        x: roadRight + 12.w,
        y: baseOffset + (cycleHeight * 0.86),
        width: 95.w,
        height: 155.h,
      );
    }
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
    // Vector circles removed completely
  }

  void _drawCar(
    Canvas canvas, {
    required Offset position,
    required _VehicleType type,
    required bool isPlayer,
  }) {
    ui.Image? vehicleImg;
    double carW = 60.w;
    double carH = 104.h;

    if (!isPlayer) {
      switch (type) {
        case _VehicleType.yellowCar:
          vehicleImg = envImages?.yellowCar;
          break;
        case _VehicleType.purpleCar:
          vehicleImg = envImages?.purpleCar;
          break;
        case _VehicleType.orangeCar:
          vehicleImg = envImages?.cr20Car;
          break;
        case _VehicleType.redScooter:
          vehicleImg = envImages?.redScooter;
          carW = 42.w;
          carH = 68.h;
          break;
        case _VehicleType.blueCar:
          vehicleImg = envImages?.cr20Car ?? envImages?.yellowCar ?? envImages?.purpleCar;
          break;
      }
    }

    if (vehicleImg != null) {
      final double imgRatio = vehicleImg.width / vehicleImg.height;
      if (type == _VehicleType.redScooter) {
        carH = 125.h;
        carW = carH * imgRatio;
      } else {
        carH = 108.h;
        carW = carH * imgRatio;
      }

      canvas.save();
      canvas.translate(position.dx, position.dy);
      if (!isPlayer) {
        canvas.rotate(pi);
      }

      final destRect = Rect.fromCenter(
        center: Offset.zero,
        width: carW,
        height: carH,
      );

      canvas.drawImageRect(
        vehicleImg,
        Rect.fromLTWH(0, 0, vehicleImg.width.toDouble(), vehicleImg.height.toDouble()),
        destRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      canvas.restore();
      return;
    }

    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (!isPlayer) {
      canvas.rotate(pi);
    }

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
