import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:auto_route/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../b_splash_stage/splash_service.dart';
import '../../../../../services/ad_manager.dart';
import '../../../provider/dashboard_provider.dart';
import 'crazy_racing_provider.dart';
import 'game_popup.dart';

// Turbo Racer Engine Modules
import 'runner/audio_service.dart';
import 'runner/car_upgrade_model.dart';
import 'runner/coin.dart';
import 'runner/crazy_runner_painter.dart';
import 'runner/game_config.dart';
import 'runner/garage_car_model.dart';
import 'runner/garage_dialog.dart';
import 'runner/hud_overlay.dart';
import 'runner/near_miss_system.dart';
import 'runner/nitro_system.dart';
import 'runner/obstacle.dart';
import 'runner/particle_manager.dart';
import 'runner/pause_overlay.dart';
import 'runner/player.dart';
import 'runner/player_car.dart';
import 'runner/road_environment.dart';
import 'runner/score_manager.dart';
import 'runner/settings_dialog.dart';
import 'runner/spawn_manager.dart';
import 'runner/storage_service.dart';
import 'runner/touch_controls_manager.dart';
import 'runner/traffic_manager.dart';
import 'runner/tutorial_dialog.dart';

enum RunnerGameState {
  start,
  countdown,
  playing,
  crashing,
  paused,
  gameOver,
  won,
}

@RoutePage()
class CrazyRacingScreen extends ConsumerStatefulWidget {
  const CrazyRacingScreen({
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
  ConsumerState<CrazyRacingScreen> createState() => _CrazyRacingScreenState();
}

class _HeroCarData {
  final String id;
  final String name;
  final String subtitle;
  final Color glowColor;
  final Color accentColor;
  final PlayerCarTheme theme;

  const _HeroCarData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.glowColor,
    required this.accentColor,
    required this.theme,
  });
}

class _CrazyRacingScreenState extends ConsumerState<CrazyRacingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final Random _random = Random();

  // ----------------------------------------------------
  // Hero Arcade Gaming Supercars Definition
  // ----------------------------------------------------
  static const List<_HeroCarData> _heroCars = [
    _HeroCarData(
      id: 'apex_red',
      name: 'APEX TURBO GT',
      subtitle: 'TWIN TURBO • S-CLASS',
      glowColor: Color(0xFFFF1744),
      accentColor: Color(0xFFFF5252),
      theme: PlayerCarTheme.red,
    ),
    _HeroCarData(
      id: 'velocita_blue',
      name: 'CYBER VELOCITA',
      subtitle: 'HYPER ELECTRIC • PRO DRIFT',
      glowColor: Color(0xFF00E5FF),
      accentColor: Color(0xFF38BDF8),
      theme: PlayerCarTheme.blue,
    ),
    _HeroCarData(
      id: 'aurum_gold',
      name: 'AURUM GOLD GT',
      subtitle: 'CUSTOM V10 • GOLD OVERDRIVE',
      glowColor: Color(0xFFFFD700),
      accentColor: Color(0xFFFFB703),
      theme: PlayerCarTheme.yellow,
    ),
    _HeroCarData(
      id: 'viper_green',
      name: 'VIPER TRACK PRO',
      subtitle: 'V8 NITRO • TRACK SPECIAL',
      glowColor: Color(0xFF10B981),
      accentColor: Color(0xFF4ADE80),
      theme: PlayerCarTheme.green,
    ),
    _HeroCarData(
      id: 'hyper_purple',
      name: 'HYPER PURPLE GT',
      subtitle: 'TWIN NITRO • HYPER SPECIAL',
      glowColor: Color(0xFFD946EF),
      accentColor: Color(0xFFC084FC),
      theme: PlayerCarTheme.purple,
    ),
  ];

  int _selectedHeroCarIndex = 0;

  void _selectHeroCar(int index) {
    _audioService.playClick();
    HapticFeedback.selectionClick();
    setState(() {
      _selectedHeroCarIndex = (index + _heroCars.length) % _heroCars.length;
      _player.carTheme = _heroCars[_selectedHeroCarIndex].theme;
    });
  }

  // ----------------------------------------------------
  // Core Subsystems
  // ----------------------------------------------------
  late final Player _player;
  late final RoadEnvironment _roadEnvironment;
  late final TrafficManager _trafficManager;
  late final ParticleManager _particleManager;
  late final SpawnManager _spawnManager;
  late final RunnerAudioService _audioService;
  late final NitroController _nitroController;
  late final ScoreManager _scoreManager;
  late final NearMissController _nearMissController;
  ui.Image? _pandaTrackImage;

  final List<Obstacle> _obstacles = [];
  final List<CollectibleItem> _collectibles = [];

  // ----------------------------------------------------
  // Game State Variables
  // ----------------------------------------------------
  RunnerGameState _gameState = RunnerGameState.start;
  double _gameSpeed = GameConfig.initialSpeed;
  double _distance = 0.0;
  int _score = 0;
  int _targetScore = 30;
  int _highScore = 0;
  int _lastGemsMilestone = 0;
  bool _surpassed10kMilestone = false;

  // Crash Dynamics & Camera FX
  double _cameraShakeTrauma = 0.0;
  double _impactFlashOpacity = 0.0;
  double _crashDurationTimer = 0.0;
  double _smokeEmitTimer = 0.0;
  double _animTime = 0.0;
  String? _lastCrashCause;

  // Countdown & Initial Swipe Tutorial State
  int _countdownNumber = 3;
  Timer? _countdownTimer;
  bool _showStartTutorialGuide = false;
  Timer? _tutorialGuideTimer;

  // ----------------------------------------------------
  // 60 FPS VSYNC Game Loop Engine
  // ----------------------------------------------------
  late final Ticker _ticker;
  final ValueNotifier<int> _gameTickNotifier = ValueNotifier<int>(0);
  Duration _lastFrameDuration = Duration.zero;

  // Animation Controllers for UI
  late AnimationController _pulseAnim;
  late AnimationController _countdownAnim;
  late AnimationController _mascotFloatAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Immersive mode for seamless arcade gameplay
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Preload track Panda image
    _loadPandaTrackImage();

    // Pre-fetch Diamond Catch daily limits & preload ads in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.userId.isNotEmpty) {
        ref.read(diamondCatchVerifierProvider(widget.userId));
      }
      AdManager().preloadRewarded();
      AdManager().preloadInterstitial();
    });

    // Subsystems initialization
    _player = Player();
    _roadEnvironment = RoadEnvironment()..init();
    _trafficManager = TrafficManager()..init();
    _particleManager = ParticleManager();
    _spawnManager = SpawnManager();
    _audioService = RunnerAudioService();
    _scoreManager = ScoreManager();
    _nearMissController = NearMissController();

    _nitroController = NitroController(
      onIgnition: () {
        _audioService.playPowerUp();
      },
      onDepleted: () {
        if (_audioService.vibrationEnabled) {
          HapticFeedback.lightImpact();
        }
      },
    );

    _loadStoredData();

    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _mascotFloatAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _countdownAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    );

    // 60 FPS Rock-Solid Ticker Game Engine
    _ticker = createTicker(_onTick);
    _ticker.start();

    _initTargetScore();
  }

  Future<void> _loadPandaTrackImage() async {
    try {
      final byteData = await rootBundle.load('assets/icons/panda 2.png');
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _pandaTrackImage = frame.image;
        });
      }
    } catch (_) {}
  }

  void _loadStoredData() {
    _scoreManager.loadBestScore();
    _highScore = _scoreManager.bestScore;
    final savedCarId = RunnerStorageService.getSelectedCarId();
    final carConfig = GarageCarConfig.getById(savedCarId);
    _player.carTheme = carConfig.theme;
    _audioService.init(
      sound: RunnerStorageService.isSoundEnabled(),
      music: RunnerStorageService.isMusicEnabled(),
      vibration: RunnerStorageService.isVibrationEnabled(),
    );
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_gameState == RunnerGameState.playing) {
        _pauseGame();
      }
      _audioService.pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      if (_gameState == RunnerGameState.playing) {
        _audioService.resumeBgm();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _tutorialGuideTimer?.cancel();
    _audioService.stopBgm();
    _ticker.dispose();
    _gameTickNotifier.dispose();
    _pulseAnim.dispose();
    _mascotFloatAnim.dispose();
    _countdownAnim.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  // ----------------------------------------------------
  // Target Score & Setup (Synchronized with Admin Config)
  // ----------------------------------------------------
  void _initTargetScore() {
    final config = SplashService.superOfferConfig;

    // 1. Direct targetScores configured in Admin panel (e.g. Games Configuration -> Diamond Catch -> Target Scores)
    final rawTargetScores = config['targetScores'];
    List<int> validScores = [];
    if (rawTargetScores is List) {
      validScores = rawTargetScores
          .map((item) => int.tryParse(item.toString()) ?? 0)
          .where((n) => n > 0)
          .toList();
    } else if (rawTargetScores is String && rawTargetScores.trim().isNotEmpty) {
      validScores = rawTargetScores
          .split(',')
          .map((item) => int.tryParse(item.trim()) ?? 0)
          .where((n) => n > 0)
          .toList();
    }

    if (validScores.isNotEmpty) {
      if (validScores.length == 1) {
        _targetScore = validScores.first;
      } else {
        _targetScore = validScores[_random.nextInt(validScores.length)];
      }
      return;
    }

    // 2. Direct reachedScore / targetScore / gameTargetScore from Admin config
    final int adminScore = (config['reachedScore'] as num?)?.toInt() ??
        (config['targetScore'] as num?)?.toInt() ??
        (config['gameTargetScore'] as num?)?.toInt() ??
        (int.tryParse(config['reachedScore']?.toString() ?? '') ??
            int.tryParse(config['targetScore']?.toString() ?? '') ??
            int.tryParse(config['gameTargetScore']?.toString() ?? '') ?? 0);
    if (adminScore > 0) {
      _targetScore = adminScore;
      return;
    }

    // 3. Direct gemsRequired / target score passed from route or Admin config
    if (widget.gemsRequired > 0) {
      _targetScore = widget.gemsRequired;
      return;
    }

    final int adminGemsReq = (config['gemsRequired'] as num?)?.toInt() ??
        (int.tryParse(config['gemsRequired']?.toString() ?? '') ?? 0);
    if (adminGemsReq > 0) {
      _targetScore = adminGemsReq;
      return;
    }

    // 4. Default fallback to gameGems or 25
    _targetScore = widget.gameGems > 0 ? widget.gameGems : 25;
  }

  void _setupNewGame() {
    _initTargetScore();
    _player.reset();
    _scoreManager.reset();
    _nearMissController.reset();
    _obstacles.clear();
    _trafficManager.reset();
    _spawnManager.reset(_collectibles);
    _particleManager.clear();
    _nitroController.reset(initialCharge: 70.0);

    // Apply Active Car Upgrade Modifiers
    final savedCarId = RunnerStorageService.getSelectedCarId();
    final int speedLvl = RunnerStorageService.getCategoryUpgradeLevel(savedCarId, 'speed');
    final int handlingLvl = RunnerStorageService.getCategoryUpgradeLevel(savedCarId, 'handling');

    final speedMultiplier = CarUpgradeSystem.getTier(UpgradeCategory.speed, speedLvl).statMultiplier;
    final handlingMultiplier = CarUpgradeSystem.getTier(UpgradeCategory.handling, handlingLvl).statMultiplier;

    _gameSpeed = GameConfig.initialSpeed * speedMultiplier;
    _player.laneSwitchSpeed = GameConfig.laneSwitchSpeed * handlingMultiplier;

    _distance = 0.0;
    _score = 0;
    _lastGemsMilestone = 0;
    _surpassed10kMilestone = false;
    _cameraShakeTrauma = 0.0;
    _impactFlashOpacity = 0.0;
    _crashDurationTimer = 0.0;
    _smokeEmitTimer = 0.0;
    _lastCrashCause = null;
    _lastFrameDuration = Duration.zero;
  }

  // ----------------------------------------------------
  // Game Flow Control
  // ----------------------------------------------------
  void _startCountdown() {
    _countdownTimer?.cancel();
    _setupNewGame();
    setState(() {
      _gameState = RunnerGameState.countdown;
      _countdownNumber = 3;
    });

    _audioService.playCountdownBeep();
    _countdownAnim.forward(from: 0.0);

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 580), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownNumber > 1) {
        setState(() {
          _countdownNumber--;
        });
        _audioService.playCountdownBeep();
        _countdownAnim.forward(from: 0.0);
      } else if (_countdownNumber == 1) {
        setState(() {
          _countdownNumber = 0; // "GO!"
        });
        _audioService.playCountdownGo();
        final double screenWidth = 1.0.sw;
        final double screenHeight = 1.0.sh;
        _particleManager.spawnCountdownGoBurst(screenWidth / 2, screenHeight * 0.44);
        _countdownAnim.forward(from: 0.0);
      } else {
        timer.cancel();
        _beginRunning();
      }
    });
  }

  void _beginRunning() {
    final double screenHeight = 1.0.sh;
    final double playerCenterY = screenHeight * 0.82;
    _trafficManager.reset();
    _obstacles.clear();
    _trafficManager.clearImmediateHazards(playerCenterY, safeRadius: 650.0);
    _obstacles.removeWhere((obs) => (obs.y - playerCenterY).abs() < 650.0 || obs.y >= playerCenterY - 120.0);
    _player.invulnerableTimer = 2.0; // 2.0s clean race start grace period

    _showStartTutorialGuide = false;
    _tutorialGuideTimer?.cancel();

    setState(() {
      _lastFrameDuration = Duration.zero;
      _gameState = RunnerGameState.playing;
    });
    _audioService.playGameplayMusic();
    _audioService.startCarEngine(initialSpeedRatio: _gameSpeed / GameConfig.maximumSpeed);
  }

  void _triggerCrashSequence(double impactX, double impactY, {bool spinLeft = true}) {
    if (_gameState == RunnerGameState.crashing || _gameState == RunnerGameState.gameOver) return;

    setState(() {
      _gameState = RunnerGameState.crashing;
      _cameraShakeTrauma = 1.0;
      _impactFlashOpacity = 0.85;
      _crashDurationTimer = 0.0;
      _smokeEmitTimer = 0.0;
    });

    _audioService.playCrash();
    _nearMissController.resetOnCollision();
    _player.triggerCrash(spinLeft: spinLeft);
    _particleManager.spawnCarCrashFX(impactX, impactY);
    _particleManager.spawnFloatingText(impactX, impactY, "CRASH!", const Color(0xFFFF4D4D));
  }

  void _pauseGame() {
    if (_gameState != RunnerGameState.playing) return;
    setState(() {
      _gameState = RunnerGameState.paused;
    });
    _audioService.pauseBgm();
    _audioService.playClick();
  }

  void _resumeGame() {
    if (_gameState != RunnerGameState.paused) return;
    final double screenHeight = 1.0.sh;
    final double playerCenterY = screenHeight * 0.82;
    _trafficManager.clearImmediateHazards(playerCenterY, safeRadius: 550.0);
    _obstacles.removeWhere((obs) => (obs.y - playerCenterY).abs() < 550.0 || obs.y >= playerCenterY - 120.0);
    setState(() {
      _lastFrameDuration = Duration.zero;
      _cameraShakeTrauma = 0.0;
      _impactFlashOpacity = 0.0;
      if (_gameSpeed <= 0.0) {
        _gameSpeed = GameConfig.initialSpeed;
      }
      _gameState = RunnerGameState.playing;
    });
    // 10-Second Safety Wall upon Resume: protects against 1 obstacle/traffic hit and breaks on contact
    _player.activateShield(10.0);
    _audioService.resumeBgm();
    _audioService.playClick();
  }

  void _restartGame() {
    _audioService.playClick();
    _startCountdown();
  }

  void _returnToMenu() {
    _countdownTimer?.cancel();
    _audioService.playClick();
    _audioService.stopCarEngine();
    _audioService.stopNitroSound();
    _audioService.playMenuMusic();
    if (_scoreManager.coinsCollected > 0) {
      _saveStats();
    }
    setState(() {
      _gameState = RunnerGameState.start;
      _setupNewGame();
      _loadStoredData();
    });
  }

  // ----------------------------------------------------
  // 60 FPS Vsync Game Tick Method
  // ----------------------------------------------------
  void _onTick(Duration elapsed) {
    if (!mounted) return;

    if (_lastFrameDuration == Duration.zero) {
      _lastFrameDuration = elapsed;
      return;
    }

    final double dt = ((elapsed - _lastFrameDuration).inMicroseconds / 1000000.0).clamp(0.001, 0.05);
    _lastFrameDuration = elapsed;
    _animTime += dt;

    final double screenWidth = 1.0.sw;
    final double screenHeight = 1.0.sh;

    if (_gameState == RunnerGameState.playing) {
      _updateActiveGameplay(dt, screenWidth, screenHeight);
    } else if (_gameState == RunnerGameState.crashing) {
      _updateCrashSequence(dt, screenWidth, screenHeight);
    } else if (_gameState == RunnerGameState.start) {
      // Smooth ambient environment drift & active Panda running on start menu
      _roadEnvironment.update(dt, 90.0, screenHeight, screenWidth);
      _player.update(dt, 260.0); // Active continuous running animation on menu!
      _particleManager.update();
    } else if (_gameState == RunnerGameState.countdown) {
      // Synchronized idle warm-up drift for road and player (no traffic spawns during countdown)
      const double idleSpeed = 130.0;
      _roadEnvironment.update(dt, idleSpeed, screenHeight, screenWidth);
      _player.update(dt, idleSpeed);
      _particleManager.update();
    }

    _gameTickNotifier.value++;
  }

  void _updateCrashSequence(double dt, double screenWidth, double screenHeight) {
    _crashDurationTimer += dt;
    final double roadBottomWidth = screenWidth * 0.94;
    final double roadLeft = (screenWidth - roadBottomWidth) / 2;
    final double laneWidth = roadBottomWidth / GameConfig.totalLanes;
    final double playerCenterY = screenHeight * 0.82;
    final double px = roadLeft + (_player.laneProgress + 0.5) * laneWidth;
    final double py = playerCenterY - _player.jumpY;

    // 1. Rapidly decelerate world velocity with smooth friction
    _gameSpeed = max(0.0, _gameSpeed - 750.0 * dt);

    // 2. Decay camera trauma and impact flash smoothly
    _cameraShakeTrauma = max(0.0, _cameraShakeTrauma - 1.45 * dt);
    _impactFlashOpacity = max(0.0, _impactFlashOpacity - 4.5 * dt);

    // 3. Update player car spin & crash shudder dynamics
    _player.update(dt, _gameSpeed);

    // 4. Update environment & traffic at decaying speed
    _roadEnvironment.update(dt, _gameSpeed, screenHeight, screenWidth);
    _trafficManager.update(
      dt: dt,
      worldSpeed: _gameSpeed * 0.6,
      screenHeight: screenHeight,
      horizonY: screenHeight * 0.18,
    );

    // 5. Continuous smoke and sparks emission during car crash slide
    _smokeEmitTimer += dt;
    if (_smokeEmitTimer >= 0.05) {
      _smokeEmitTimer = 0.0;
      if (_crashDurationTimer < 0.65) {
        _particleManager.particles.add(GameParticle(
          x: px + (_random.nextDouble() - 0.5) * 20.0,
          y: py + (_random.nextDouble() - 0.5) * 20.0,
          vx: (_random.nextDouble() - 0.5) * 2.5,
          vy: -1.5 - _random.nextDouble() * 2.0,
          color: const Color(0xFF1E293B),
          size: 10.0 + _random.nextDouble() * 10.0,
          decay: 0.028,
          isSmoke: true,
        ));
      }
    }

    // 6. Update Particles
    _particleManager.update();

    // 7. Responsive transition to Game Over after ~0.85s crash drama
    if (_crashDurationTimer >= 0.85) {
      _handleGameOver();
    }
  }

  void _updateActiveGameplay(double dt, double screenWidth, double screenHeight) {
    final double horizonY = screenHeight * 0.18;
    final double roadTopWidth = screenWidth * 0.44;
    final double roadBottomWidth = screenWidth * 0.94;
    final double playerCenterY = screenHeight * 0.82;
    final double playerP = ((playerCenterY - horizonY) / (screenHeight - horizonY)).clamp(0.0, 1.0);
    final double roadTopLeft = (screenWidth - roadTopWidth) / 2;
    final double roadBottomLeft = (screenWidth - roadBottomWidth) / 2;
    final double roadLeft = roadTopLeft + (roadBottomLeft - roadTopLeft) * playerP;
    final double roadWidthAtPlayer = roadTopWidth + (roadBottomWidth - roadTopWidth) * playerP;
    final double laneWidth = roadWidthAtPlayer / GameConfig.totalLanes;

    // 0. Update Nitro & Near Miss / Combo Controllers
    _nitroController.update(dt, _gameSpeed);
    _nearMissController.update(dt);

    // Effective dynamic speeds based on active Speed Boost, Nitro Boost & Slow Motion
    final double nitroMultiplier = 1.0 + (_nitroController.nitroIntensity * (_nitroController.config.speedMultiplier - 1.0));
    final double baseSpeed = _player.isSpeedBoostActive ? _gameSpeed * 1.55 : _gameSpeed;
    final double effectiveSpeed = baseSpeed * nitroMultiplier;
    final double hazardSpeed = _player.isSlowMoActive ? effectiveSpeed * 0.48 : effectiveSpeed;

    // 1. Update Player (Running cycle, jumping arc, sliding timer)
    _player.update(dt, effectiveSpeed);

    // Running dust & nitro particles
    if (_player.state == PlayerActionState.running) {
      if (_random.nextDouble() < (_player.isSpeedBoostActive ? 0.75 : 0.28)) {
        final double px = roadLeft + (_player.laneProgress + 0.5) * laneWidth;
        _particleManager.spawnRunningDust(px, playerCenterY + 28);
      }
    }

    // 2. Update Multi-Factor Scoring & Distance Engine
    _scoreManager.update(
      dt: dt,
      currentSpeed: effectiveSpeed,
      isPlaying: true,
      is2xMultiplierActive: _player.isMultiplierActive,
      isNitroActive: _nitroController.nitroIntensity > 0.2,
    );
    _distance = _scoreManager.distance;
    _score = _scoreManager.currentScore;

    // 3. Dynamic Progressive Speed Scaling:
    // - Before 10,000 pts: Start very relaxed and slow (~120 px/s) with gentle progression up to ~180 px/s
    // - After 10,000 pts: Trigger Speed Surge alert and smoothly accelerate speed further
    if (_score < GameConfig.milestone10kScore) {
      if (_gameSpeed < GameConfig.baseStageMaxSpeed) {
        _gameSpeed += GameConfig.earlySpeedIncrement * dt;
      }
    } else {
      // One-time 10,000 Points Milestone Surge Alert & Fanfare
      if (!_surpassed10kMilestone) {
        _surpassed10kMilestone = true;
        _audioService.playPowerUp();
        if (_audioService.vibrationEnabled) {
          HapticFeedback.heavyImpact();
        }
        _particleManager.spawnFloatingText(
          screenWidth / 2,
          playerCenterY - 70,
          "⚡ SPEED SURGE! ⚡\n10,000 PTS!",
          const Color(0xFFFFD700),
        );
      }

      // Continuous acceleration past 10,000:
      // Minimum dynamic speed floor based on points above 10k + continuous time scaling
      final double scoreAbove10k = (_score - GameConfig.milestone10kScore).toDouble();
      final double scoreBasedFloor = 185.0 + (scoreAbove10k * 0.002);
      if (_gameSpeed < scoreBasedFloor) {
        _gameSpeed = scoreBasedFloor;
      }

      if (_gameSpeed < GameConfig.maximumSpeed) {
        _gameSpeed += GameConfig.turboSpeedIncrement * dt;
      }
    }

    // Continuously update engine audio pitch to reflect current driving speed
    _audioService.updateEnginePitch((_gameSpeed / GameConfig.maximumSpeed).clamp(0.0, 1.0));

    // 3b. 200 Meter Milestone Reward Tracker: 1 Gem for every 200 meters run!
    final int currentMilestone = (_distance / 200.0).floor();
    if (currentMilestone > _lastGemsMilestone) {
      _lastGemsMilestone = currentMilestone;
      final int totalEarned = currentMilestone;
      _audioService.playGem();
      final double roadCenterX = roadLeft + 1.5 * laneWidth;
      _particleManager.spawnGemPickup(roadCenterX, playerCenterY - 40);
      _particleManager.spawnFloatingText(
        roadCenterX,
        playerCenterY - 60,
        "+1 GEM! ($totalEarned GEMS)",
        const Color(0xFF38BDF8),
      );
      if (_audioService.vibrationEnabled) {
        HapticFeedback.lightImpact();
      }
    }

    // 4. Update Road & Scenery Parallax
    _roadEnvironment.update(dt, effectiveSpeed, screenHeight, screenWidth);

    // 4b. Update AI Traffic Vehicles (Affected by Slow Motion, coordinated with active obstacles)
    _trafficManager.update(
      dt: dt,
      worldSpeed: hazardSpeed,
      screenHeight: screenHeight,
      horizonY: horizonY,
      obstacles: _obstacles,
    );

    // 4c. Check Traffic Vehicle Collisions
    final collidedVehicle = _trafficManager.checkCollisions(_player, laneWidth, roadLeft, playerCenterY);
    if (collidedVehicle != null) {
      collidedVehicle.cleared = true;
      final double vx = roadLeft + (collidedVehicle.lane + 0.5) * laneWidth;
      final double vy = collidedVehicle.y;

      if (_player.isInvincible) {
        // Invincible Overdrive: Smash through traffic!
        _scoreManager.addSmashBonus();
        _score = _scoreManager.currentScore;
        _audioService.playHit();
        _particleManager.spawnCrashImpact(vx, vy);
        _particleManager.spawnFloatingText(vx, vy, "SMASH! +50 ⭐", const Color(0xFFFFD700));
        if (_audioService.vibrationEnabled) {
          HapticFeedback.heavyImpact();
        }
      } else {
        final bool tookDamage = _player.takeDamage();
        if (tookDamage) {
          _lastCrashCause = collidedVehicle.config.displayName;
          final bool spinLeft = (collidedVehicle.lane <= _player.currentLane);
          _triggerCrashSequence(vx, vy, spinLeft: spinLeft);
          return;
        } else {
          // Shield absorbed or invulnerable -> immediately remove vehicle so it doesn't linger
          collidedVehicle.active = false;
          collidedVehicle.cleared = true;
          collidedVehicle.y = -300.0;
          _audioService.playShieldBreak();
          _particleManager.spawnGemPickup(vx, vy);
          _particleManager.spawnFloatingText(vx, vy, "SHIELD BLOCKED!", const Color(0xFF38BDF8));
        }
      }
    }

    // 4d. Check Near-Miss Overtakes with Traffic (Awards Nitro + Bonus Score & Combo Increment!)
    final nearMissVehicle = _trafficManager.checkNearMiss(
      _player,
      laneWidth,
      roadLeft,
      playerCenterY,
      proximityDistanceY: _nearMissController.config.proximityThresholdY,
    );
    if (nearMissVehicle != null) {
      final result = _nearMissController.registerNearMiss(
        worldX: roadLeft + (nearMissVehicle.lane + 0.5) * laneWidth,
        worldY: nearMissVehicle.y,
        playerLane: _player.currentLane,
        vehicleLane: nearMissVehicle.lane,
        is2xMultiplierActive: _player.isMultiplierActive,
      );

      if (result != null) {
        // Sync with ScoreManager
        _scoreManager.addNearMissScore(
          points: result.scoreBonus,
          comboLevel: result.comboLevel,
          label: "+${result.scoreBonus} PTS",
        );
        _scoreManager.comboMultiplier = result.comboMultiplier;
        _scoreManager.comboTimer = _nearMissController.comboTimeoutDuration;
        _score = _scoreManager.currentScore;

        if (result.coinsAwarded > 0) {
          _scoreManager.coinsCollected += result.coinsAwarded;
        }

        if (result.nitroRefill > 0) {
          _nitroController.addNitro(result.nitroRefill);
        }

        // Play Ascending Combo / Near Miss Chimes
        if (result.comboLevel > 1) {
          _audioService.playCombo(result.comboLevel);
        } else {
          _audioService.playNearMiss();
        }

        // Particle sparks & Floating Text between the two overtakers
        final double vx = roadLeft + (nearMissVehicle.lane + 0.5) * laneWidth;
        final double vy = nearMissVehicle.y;
        final double px = roadLeft + (_player.laneProgress + 0.5) * laneWidth;
        final double midX = (px + vx) / 2;
        _particleManager.spawnNearMissSparks(midX, vy, color: result.accentColor);
        _particleManager.spawnFloatingText(
          midX,
          vy - 10,
          "+${result.scoreBonus} PTS",
          result.accentColor,
        );
      }
    }

    // 5. Procedural Obstacles & Collectibles Spawning (Coordinated with AI Traffic)
    _spawnManager.update(
      dt: dt,
      worldSpeed: effectiveSpeed,
      distanceTraveled: _distance,
      obstacles: _obstacles,
      collectibles: _collectibles,
      spawnY: horizonY,
      trafficVehicles: _trafficManager.activeVehicles,
    );

    // 6. Update Obstacles & Check Collisions (Modular Collision Effects)
    for (int i = _obstacles.length - 1; i >= 0; i--) {
      final obs = _obstacles[i];
      obs.update(dt, hazardSpeed);

      if (!obs.cleared && obs.checkCollision(_player, laneWidth, roadLeft, playerCenterY)) {
        obs.cleared = true;
        final double px = roadLeft + (obs.lane + 0.5) * laneWidth;
        final double py = obs.y;
        final cfg = obs.config;

        if (_player.isInvincible) {
          // Invincible Overdrive: Smash through obstacles!
          _scoreManager.addSmashBonus();
          _score = _scoreManager.currentScore;
          _audioService.playHit();
          _particleManager.spawnCrashImpact(px, py);
          _particleManager.spawnFloatingText(px, py, "SMASH! +50 ⭐", const Color(0xFFFFD700));
          if (_audioService.vibrationEnabled) {
            HapticFeedback.mediumImpact();
          }
        } else {
          switch (cfg.collisionEffect) {
            case ObstacleCollisionEffect.fatalCrash:
              final bool tookDamage = _player.takeDamage();
              if (tookDamage) {
                _lastCrashCause = obs.config.name;
                final bool spinLeft = (obs.lane <= _player.currentLane);
                _triggerCrashSequence(px, py, spinLeft: spinLeft);
                return;
              } else {
                // Shield absorbed or invulnerable
                _audioService.playShieldBreak();
                _particleManager.spawnGemPickup(px, py);
                _particleManager.spawnFloatingText(px, py, "SHIELD BROKEN!", const Color(0xFF38BDF8));
              }
              break;

            case ObstacleCollisionEffect.scorePenalty:
              if (_player.hasShield) {
                _player.consumeShield();
                _audioService.playShieldBreak();
                _particleManager.spawnGemPickup(px, py);
                _particleManager.spawnFloatingText(px, py, "SHIELD BLOCKED!", const Color(0xFF38BDF8));
              } else {
                // Traffic cone knockdown / minor penalty
                _scoreManager.applyPenalty(cfg.scorePenalty);
                _nearMissController.resetOnCollision();
                _score = _scoreManager.currentScore;
                _audioService.playHit();
                _particleManager.spawnCrashImpact(px, py);
                _particleManager.spawnFloatingText(px, py, "-${cfg.scorePenalty} PTS!", const Color(0xFFFB923C));
                if (_audioService.vibrationEnabled) {
                  HapticFeedback.lightImpact();
                }
              }
              break;

            case ObstacleCollisionEffect.spinout:
              if (_player.hasShield) {
                _player.consumeShield();
                _audioService.playShieldBreak();
                _particleManager.spawnGemPickup(px, py);
                _particleManager.spawnFloatingText(px, py, "SHIELD BLOCKED!", const Color(0xFF38BDF8));
              } else {
                // Slippery oil spill -> fishtail traction slip & momentary slowdown
                _gameSpeed = max(GameConfig.initialSpeed, _gameSpeed * (1.0 - cfg.speedReductionPercent));
                _nearMissController.resetOnCollision();
                _player.triggerSpinout(duration: 0.9);
                _audioService.playSlide();
                _particleManager.spawnRunningDust(px, py);
                _particleManager.spawnFloatingText(px, py, "SLIP!", const Color(0xFFC084FC));
                if (_audioService.vibrationEnabled) {
                  HapticFeedback.mediumImpact();
                }
              }
              break;

            case ObstacleCollisionEffect.suspensionBump:
              if (_player.hasShield) {
                _player.consumeShield();
                _audioService.playShieldBreak();
                _particleManager.spawnGemPickup(px, py);
                _particleManager.spawnFloatingText(px, py, "SHIELD BLOCKED!", const Color(0xFF38BDF8));
              } else {
                // Speed bump -> suspension jolt & slight speed scrub
                _gameSpeed = max(GameConfig.initialSpeed, _gameSpeed * (1.0 - cfg.speedReductionPercent));
                _player.triggerSuspensionJolt(force: 5.0);
                _audioService.playJump();
                _particleManager.spawnFloatingText(px, py, "BUMP!", const Color(0xFFFBBF24));
                if (_audioService.vibrationEnabled) {
                  HapticFeedback.lightImpact();
                }
              }
              break;

            case ObstacleCollisionEffect.slowdown:
              if (_player.hasShield) {
                _player.consumeShield();
                _audioService.playShieldBreak();
                _particleManager.spawnGemPickup(px, py);
                _particleManager.spawnFloatingText(px, py, "SHIELD BLOCKED!", const Color(0xFF38BDF8));
              } else {
                _gameSpeed = max(GameConfig.initialSpeed, _gameSpeed * (1.0 - cfg.speedReductionPercent));
                _audioService.playHit();
                _particleManager.spawnFloatingText(px, py, "SLOW!", const Color(0xFFF97316));
                if (_audioService.vibrationEnabled) {
                  HapticFeedback.lightImpact();
                }
              }
              break;
          }
        }
      }

      // Remove off-screen obstacles
      if (obs.y > screenHeight + 80.0) {
        _obstacles.removeAt(i);
      }
    }

    // 7. Update Collectibles & Magnet Attraction (Object Pooled)
    for (int i = _collectibles.length - 1; i >= 0; i--) {
      final item = _collectibles[i];
      item.update(dt, effectiveSpeed, _player, laneWidth, roadLeft, playerCenterY);

      if (!item.collected && item.checkCollection(_player, laneWidth, roadLeft, playerCenterY)) {
        _onItemCollected(item, roadLeft, laneWidth);
      }

      if (item.y > screenHeight + 80.0 || item.collected) {
        _spawnManager.coinPool.release(item);
        _collectibles.removeAt(i);
      }
    }

    // 8. Update Visual Particle Effects
    _particleManager.update();

    // 9. Check Target Score Win Condition
    if (_score >= _targetScore && _gameState == RunnerGameState.playing) {
      _handleGameWon();
      return;
    }
  }

  void _onItemCollected(CollectibleItem item, double roadLeft, double laneWidth) {
    final double px = roadLeft + (item.lane + 0.5 + item.horizontalOffset) * laneWidth;
    final double py = item.y - item.heightOffset;

    switch (item.type) {
      case CollectibleType.goldCoin:
        _scoreManager.addCoin(isMultiplierActive: _player.isMultiplierActive);
        _score = _scoreManager.currentScore;
        _nitroController.addNitro(_nitroController.config.coinRefillAmount);
        _audioService.playCoin();
        _particleManager.spawnCoinPickup(px, py);
        final String coinText = _player.isMultiplierActive ? "+20 ⚡" : "+10";
        _particleManager.spawnFloatingText(px, py, coinText, const Color(0xFFFFD700));
        break;

      case CollectibleType.gem:
        _scoreManager.addGem(isMultiplierActive: _player.isMultiplierActive);
        _score = _scoreManager.currentScore;
        _audioService.playGem();
        _particleManager.spawnGemPickup(px, py);
        final String gemText = _player.isMultiplierActive ? "+100 GEM!" : "+50 GEM!";
        _particleManager.spawnFloatingText(px, py, gemText, const Color(0xFF38BDF8));
        break;

      case CollectibleType.shield:
        _player.activateShield();
        _scoreManager.addPowerUpBonus(name: "SHIELD");
        _score = _scoreManager.currentScore;
        _audioService.playPowerUp();
        _particleManager.spawnGemPickup(px, py);
        _particleManager.spawnFloatingText(px, py, "SHIELD UP! 🛡️", const Color(0xFF38BDF8));
        break;

      case CollectibleType.magnet:
        _player.activateMagnet(8.5);
        _scoreManager.addPowerUpBonus(name: "MAGNET");
        _score = _scoreManager.currentScore;
        _audioService.playPowerUp();
        _particleManager.spawnCoinPickup(px, py);
        _particleManager.spawnFloatingText(px, py, "MAGNET ENGAGED! 🧲", const Color(0xFFEF4444));
        break;

      case CollectibleType.multiplier2x:
        _player.activateMultiplier(9.0);
        _scoreManager.addPowerUpBonus(name: "2X COINS");
        _score = _scoreManager.currentScore;
        _audioService.playPowerUp();
        _particleManager.spawnCoinPickup(px, py);
        _particleManager.spawnFloatingText(px, py, "2X COIN BOOST! ⚡", const Color(0xFFA855F7));
        break;

      case CollectibleType.speedBoost:
        _player.activateSpeedBoost(6.0);
        _scoreManager.addPowerUpBonus(name: "NITRO");
        _score = _scoreManager.currentScore;
        _audioService.playPowerUp();
        _particleManager.spawnCoinPickup(px, py);
        _particleManager.spawnFloatingText(px, py, "NITRO BOOST! 🔥", const Color(0xFFF97316));
        break;

      case CollectibleType.slowMotion:
        _player.activateSlowMo(7.0);
        _scoreManager.addPowerUpBonus(name: "SLOW-MO");
        _score = _scoreManager.currentScore;
        _audioService.playPowerUp();
        _particleManager.spawnGemPickup(px, py);
        _particleManager.spawnFloatingText(px, py, "SLOW MOTION! ⏳", const Color(0xFF06B6D4));
        break;

      case CollectibleType.invincibility:
        _player.activateInvincibility(6.5);
        _scoreManager.addPowerUpBonus(name: "OVERDRIVE");
        _score = _scoreManager.currentScore;
        _audioService.playPowerUp();
        _particleManager.spawnGemPickup(px, py);
        _particleManager.spawnFloatingText(px, py, "INVINCIBLE OVERDRIVE! ⭐", const Color(0xFFFFD700));
        break;

      case CollectibleType.nitroCanister:
        _nitroController.addNitro(_nitroController.config.canisterRefillAmount);
        _scoreManager.addPowerUpBonus(name: "NITRO CANISTER");
        _score = _scoreManager.currentScore;
        _audioService.playPowerUp();
        _particleManager.spawnCountdownGoBurst(px, py);
        _particleManager.spawnFloatingText(px, py, "+40% NITRO ⚡", const Color(0xFF00F2FE));
        if (_audioService.vibrationEnabled) {
          HapticFeedback.heavyImpact();
        }
        break;
    }
  }

  int get _effectiveGameGems {
    final liveConfig = SplashService.superOfferConfig;
    final configVal = (liveConfig['gameGems'] as num?)?.toInt();
    if (configVal != null && configVal > 0) return configVal;
    if (widget.gameGems > 0) return widget.gameGems;
    return 10;
  }

  int get _effectiveInstallGems {
    final liveConfig = SplashService.superOfferConfig;
    final configVal = (liveConfig['installGems'] as num?)?.toInt();
    if (configVal != null && configVal > 0) return configVal;
    if (widget.installGems > 0) return widget.installGems;
    return 10;
  }

  // ----------------------------------------------------
  // Win / Game Over Handlers
  // ----------------------------------------------------
  void _handleGameWon() {
    _saveStats();
    setState(() {
      _gameState = RunnerGameState.won;
    });
    _audioService.stopCarEngine();
    _audioService.stopNitroSound();
    _audioService.playHighScore();
    AdManager().preloadRewarded();
    AdManager().preloadInterstitial();

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => GameResultPopup(
        isWin: true,
        score: _score,
        stars: 3,
        gameGems: _effectiveGameGems,
        installGems: _effectiveInstallGems,
        dailyGems: _effectiveGameGems,
        dailyGemsForInstall: widget.dailyGemsForInstall,
        onRestart: _restartGame,
        onHome: _returnToMenu,
        carTheme: _player.carTheme,
      ),
    );
  }

  void _handleGameOver() {
    _saveStats();
    setState(() {
      _gameState = RunnerGameState.gameOver;
    });
    _audioService.stopCarEngine();
    _audioService.stopNitroSound();
    _audioService.playGameOverSound();
    _audioService.playGameOverMusic();
    AdManager().preloadRewarded();
    AdManager().preloadInterstitial();

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => GameResultPopup(
        isWin: false,
        score: _score,
        stars: 0,
        gameGems: _effectiveGameGems,
        installGems: _effectiveInstallGems,
        dailyGems: _effectiveGameGems,
        dailyGemsForInstall: widget.dailyGemsForInstall,
        onRestart: _restartGame,
        onHome: _returnToMenu,
        onResume: _resumeAfterAd,
        crashCause: _lastCrashCause,
        carTheme: _player.carTheme,
      ),
    );
  }

  void _resumeAfterAd() {
    final double screenHeight = 1.0.sh;
    final double playerCenterY = screenHeight * 0.82;

    setState(() {
      _lastFrameDuration = Duration.zero;
      _gameSpeed = GameConfig.initialSpeed;
      _crashDurationTimer = 0.0;
      _cameraShakeTrauma = 0.0;
      _impactFlashOpacity = 0.0;
      _gameState = RunnerGameState.playing;
    });

    _player.resetAfterRevive();
    _trafficManager.clearImmediateHazards(playerCenterY, safeRadius: 600.0);
    _obstacles.removeWhere((obs) => (obs.y - playerCenterY).abs() < 600.0 || obs.y >= playerCenterY - 120.0);
    _audioService.playPowerUp();
    _audioService.playGameplayMusic();
    _audioService.startCarEngine(initialSpeedRatio: _gameSpeed / GameConfig.maximumSpeed);

    final double screenWidth = 1.0.sw;
    _particleManager.spawnGemPickup(screenWidth / 2, playerCenterY);
    _particleManager.spawnFloatingText(
      screenWidth / 2,
      screenHeight * 0.75,
      "REVIVED! 🛡️",
      const Color(0xFF38BDF8),
    );
  }

  void _saveStats() {
    _scoreManager.saveBestScore();
    RunnerStorageService.addCoins(_scoreManager.coinsCollected);
    _highScore = _scoreManager.bestScore;
  }

  // ----------------------------------------------------
  // Player Controls (Swipes & Gestures)
  // ----------------------------------------------------
  void _dismissTutorialGuide() {
    if (_showStartTutorialGuide) {
      _tutorialGuideTimer?.cancel();
      setState(() {
        _showStartTutorialGuide = false;
      });
    }
  }

  void _moveLeft() {
    if (_gameState != RunnerGameState.playing) return;
    _dismissTutorialGuide();
    _player.moveLeft();
    _audioService.playSwipe();
  }

  void _moveRight() {
    if (_gameState != RunnerGameState.playing) return;
    _dismissTutorialGuide();
    _player.moveRight();
    _audioService.playSwipe();
  }

  void _jump() {
    if (_gameState != RunnerGameState.playing) return;
    _dismissTutorialGuide();
    if (_player.jump()) {
      _audioService.playJump();
    }
  }

  void _slide() {
    if (_gameState != RunnerGameState.playing) return;
    _dismissTutorialGuide();
    if (_player.slide()) {
      _audioService.playSlide();
    }
  }

  void _onPanStart(DragStartDetails details) {
    TouchControlsManager().onPanStart(details);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_gameState != RunnerGameState.playing) return;
    TouchControlsManager().onPanUpdate(
      details: details,
      player: _player,
      onMoveLeft: _moveLeft,
      onMoveRight: _moveRight,
      onJump: _jump,
      onSlide: _slide,
    );
  }

  void _onPanEnd(DragEndDetails details) {
    TouchControlsManager().onPanEnd(details);
  }

  void _onPanCancel() {
    TouchControlsManager().onPanCancel();
  }

  // ----------------------------------------------------
  // Dialog Openers
  // ----------------------------------------------------
  void _openGarage() {
    _audioService.playClick();
    RunnerGarageDialog.show(
      context,
      onCarEquipped: (theme) {
        setState(() {
          _player.carTheme = theme;
        });
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _loadStoredData();
        });
      }
    });
  }

  void _openTutorial() {
    _audioService.playClick();
    showDialog(
      context: context,
      builder: (_) => const RunnerTutorialDialog(),
    );
  }

  void _openSettings() {
    _audioService.playClick();
    showDialog(
      context: context,
      builder: (_) => RunnerSettingsDialog(
        onDataReset: () {
          setState(() {
            _loadStoredData();
          });
        },
        onAudioSettingsChanged: () {
          setState(() {
            _loadStoredData();
          });
        },
      ),
    );
  }

  // ----------------------------------------------------
  // Main Build
  // ----------------------------------------------------
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
      canPop: _gameState == RunnerGameState.start,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_gameState == RunnerGameState.playing) {
            _pauseGame();
          } else if (_gameState == RunnerGameState.paused) {
            _returnToMenu();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onPanCancel: _onPanCancel,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // 1. High-Performance 2.5D CustomPainter World (60 FPS Animated)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _gameTickNotifier,
                  builder: (context, _) => RepaintBoundary(
                    child: CustomPaint(
                      painter: CrazyRunnerPainter(
                        repaint: _gameTickNotifier,
                        player: _player,
                        obstacles: _obstacles,
                        trafficVehicles: _trafficManager.vehicles,
                        collectibles: _collectibles,
                        environment: _roadEnvironment,
                        particleManager: _particleManager,
                        pandaImage: _pandaTrackImage,
                        worldSpeed: _gameSpeed,
                        score: _score.toDouble(),
                        distance: _distance,
                        isPlaying: _gameState == RunnerGameState.playing ||
                            _gameState == RunnerGameState.crashing,
                        nitroIntensity: _nitroController.nitroIntensity,
                        nitroAnimPhase: _nitroController.animPhase,
                        cameraShakeTrauma: _cameraShakeTrauma,
                        impactFlashOpacity: _impactFlashOpacity,
                        nearMissPulseIntensity: _nearMissController.screenPulseIntensity,
                        nearMissPulseColor: _nearMissController.screenPulseColor,
                        nearMissOvertakeSide: _nearMissController.overtakeSide,
                        animTime: _animTime,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Modern Portrait Gameplay HUD (Score, Distance, Pause, Coins, Speed, Power-Ups)
              if (_gameState == RunnerGameState.playing ||
                  _gameState == RunnerGameState.paused)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _gameTickNotifier,
                    builder: (context, _) {
                      final int currentEarnedGems = _effectiveGameGems;
                      return RunnerHudOverlay(
                        score: _scoreManager.currentScore,
                        targetScore: _targetScore,
                        coins: _scoreManager.coinsCollected,
                        earnedGems: currentEarnedGems,
                        distanceMeters: _scoreManager.distance,
                        currentSpeed: _gameSpeed,
                        player: _player,
                        nitroController: _nitroController,
                        scoreManager: _scoreManager,
                        nearMissController: _nearMissController,
                        onPause: _pauseGame,
                      );
                    },
                  ),
                ),

              // 2b. Animated Near Miss & Combo Announcement Banner (Disabled by default to avoid screen distraction)
              if ((_gameState == RunnerGameState.playing ||
                      _gameState == RunnerGameState.paused) &&
                  _nearMissController.config.showBannerPopup)
                Positioned(
                  top: 130.h,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _gameTickNotifier,
                    builder: (context, _) => NearMissBannerWidget(
                      controller: _nearMissController,
                    ),
                  ),
                ),

              // 3. Start-of-Game Animated Swipe Tutorial Guide (Clean & Non-Intrusive)
              if (_gameState == RunnerGameState.playing && _showStartTutorialGuide)
                Positioned.fill(
                  child: _buildStartGameplayGuide(),
                ),

              // 4. Start Screen Menu
              if (_gameState == RunnerGameState.start)
                Positioned.fill(
                  child: _buildStartScreen(userGems),
                ),

              // 5. Countdown 3-2-1 Overlay
              if (_gameState == RunnerGameState.countdown)
                Positioned.fill(
                  child: _buildCountdownOverlay(),
                ),

              // 6. Pause Menu Overlay
              if (_gameState == RunnerGameState.paused)
                Positioned.fill(
                  child: RunnerPauseOverlay(
                    currentScore: _scoreManager.currentScore,
                    distanceMeters: _scoreManager.distance,
                    coins: _scoreManager.coinsCollected,
                    comboMultiplier: _scoreManager.comboMultiplier,
                    onResume: _resumeGame,
                    onRestart: _restartGame,
                    onHome: _returnToMenu,
                    onSettings: () {
                      _audioService.playClick();
                      RunnerSettingsDialog.show(
                        context,
                        onDataReset: () {
                          _scoreManager.loadBestScore();
                          setState(() {});
                        },
                        onAudioSettingsChanged: () {
                          setState(() {});
                        },
                      );
                    },
                    isSoundOn: _audioService.soundEnabled,
                    isMusicOn: _audioService.musicEnabled,
                    isVibrateOn: _audioService.vibrationEnabled,
                    onToggleSound: (val) {
                      _audioService.setSoundEnabled(val);
                      RunnerStorageService.setSoundEnabled(val);
                      setState(() {});
                    },
                    onToggleMusic: (val) {
                      _audioService.setMusicEnabled(val);
                      RunnerStorageService.setMusicEnabled(val);
                      setState(() {});
                    },
                    onToggleVibrate: (val) {
                      _audioService.setVibrationEnabled(val);
                      RunnerStorageService.setVibrationEnabled(val);
                      setState(() {});
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Start Screen UI - Solid Grey Background & Clean Transparent Car Showcase
  // ----------------------------------------------------
  Widget _buildStartScreen(int userGems) {
    final int currentBestScore = _scoreManager.bestScore > 0 ? _scoreManager.bestScore : _highScore;
    final currentCar = _heroCars[_selectedHeroCarIndex];

    return Container(
      color: const Color(0xFFF1F5F9), // Solid Neutral Light-Grey background so no transparent bleed
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
          child: Column(
            children: [
              // 1. Top Bar: Back Button, User Gems Capsule, Sound Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCircleIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () {
                      _audioService.playClick();
                      Navigator.maybePop(context);
                    },
                  ),
                  // Dual Capsule Pill: In-Game Racing Coins & App Gems
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // In-Game Racing Coins (Used for Garage & Tuning)
                      GestureDetector(
                        onTap: _openGarage,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B2F08), Color(0xFF1E293B)],
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.monetization_on_rounded,
                                color: const Color(0xFFFFD700),
                                size: 16.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                "${RunnerStorageService.getTotalCoins()}",
                                style: GoogleFonts.blackOpsOne(
                                  color: const Color(0xFFFFD700),
                                  fontSize: 12.5.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),

                      // App Reward Gems
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: const Color(0xFF0284C7),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/icons/gems.png',
                              width: 16.w,
                              height: 16.w,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.diamond_rounded,
                                color: const Color(0xFF38BDF8),
                                size: 16.sp,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              "$userGems",
                              style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _buildCircleIconButton(
                    icon: _audioService.soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    onTap: () {
                      _audioService.playClick();
                      final next = !_audioService.soundEnabled;
                      _audioService.setSoundEnabled(next);
                      RunnerStorageService.setSoundEnabled(next);
                      setState(() {});
                    },
                  ),
                ],
              ),

              SizedBox(height: 8.h),

              // 2. Title & Slogan Banner
              Text(
                "CRAZY RACING",
                textAlign: TextAlign.center,
                style: GoogleFonts.blackOpsOne(
                  fontSize: 34.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF0284C7),
                        Color(0xFF2563EB),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ).createShader(const Rect.fromLTWH(0, 0, 320, 50)),
                  shadows: [
                    Shadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                      blurRadius: 14,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),

              // 3. Stats Badge: BEST SCORE
              Container(
                padding: EdgeInsets.symmetric(vertical: 7.h, horizontal: 20.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_rounded, color: const Color(0xFFFFD700), size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      "HIGH SCORE: $currentBestScore",
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 4. Centerpiece: Supercar Showcase with TRANSPARENT Background
              AnimatedBuilder(
                animation: _mascotFloatAnim,
                builder: (context, child) {
                  final floatOffset = sin(_mascotFloatAnim.value * 2 * pi) * 6.0;
                  return Transform.translate(
                    offset: Offset(0, floatOffset),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left Arrow
                    GestureDetector(
                      onTap: () => _selectHeroCar(_selectedHeroCarIndex - 1),
                      child: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: currentCar.accentColor.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                    ),

                    // Car Display with Transparent Background & Soft Shadow
                    SizedBox(
                      width: 240.w,
                      height: 180.h,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Soft ground shadow on grey surface
                          Positioned(
                            bottom: 8.h,
                            child: Container(
                              width: 170.w,
                              height: 24.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(Radius.elliptical(170.w, 24.h)),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.35),
                                    currentCar.glowColor.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 2.5D Stylized Gaming Supercar
                          CustomPaint(
                            size: Size(180.w, 160.h),
                            painter: _ShowcaseGamingCarPainter(
                              theme: currentCar.theme,
                              animPhase: _mascotFloatAnim.value,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Arrow
                    GestureDetector(
                      onTap: () => _selectHeroCar(_selectedHeroCarIndex + 1),
                      child: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: currentCar.accentColor.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 8.h),

              // Car Name & Specs Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: currentCar.accentColor.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7.r,
                      height: 7.r,
                      decoration: BoxDecoration(
                        color: currentCar.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: currentCar.accentColor,
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "${currentCar.name} • ${currentCar.subtitle}",
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // 6. GIANT 3D Arcade Play Button
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.03).animate(
                  CurvedAnimation(parent: _pulseAnim, curve: Curves.easeInOut),
                ),
                child: _PopScaleButton(
                  onTap: () {
                    _audioService.playClick();
                    HapticFeedback.heavyImpact();
                    _startCountdown();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 52.h,
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
                          color: const Color(0xFF15803D).withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(5.r),
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

              SizedBox(height: 10.h),

              // 7. Clean Bottom Actions (Garage, Tutorial & Settings)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _openGarage,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.garage_rounded, color: const Color(0xFFFFD700), size: 14.sp),
                          SizedBox(width: 5.w),
                          Text(
                            "Garage",
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  GestureDetector(
                    onTap: _openTutorial,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sports_esports_rounded, color: const Color(0xFFFFD54F), size: 14.sp),
                          SizedBox(width: 5.w),
                          Text(
                            "How to Play",
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  GestureDetector(
                    onTap: _openSettings,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings_rounded, color: const Color(0xFF38BDF8), size: 14.sp),
                          SizedBox(width: 5.w),
                          Text(
                            "Settings",
                            style: GoogleFonts.fredoka(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20.sp),
      ),
    );
  }

  // ----------------------------------------------------
  // Countdown Overlay (3 - 2 - 1 - GO!)
  // ----------------------------------------------------
  Widget _buildCountdownOverlay() {
    final bool isGo = _countdownNumber == 0;
    final String mainText = isGo ? "GO!" : "$_countdownNumber";
    final String subText = switch (_countdownNumber) {
      3 => "REV ENGINES",
      2 => "GET READY",
      1 => "SET...",
      _ => "PEDAL TO THE METAL!",
    };

    final List<Color> textGradient = isGo
        ? const [Color(0xFF00FF66), Color(0xFF00F2FE), Color(0xFFFFFFFF)]
        : switch (_countdownNumber) {
            3 => const [Color(0xFFFF1744), Color(0xFFFF5252), Color(0xFFFF9100)],
            2 => const [Color(0xFFFF9100), Color(0xFFFFAB00), Color(0xFFFFD600)],
            _ => const [Color(0xFFFFD600), Color(0xFF00E5FF), Color(0xFF18FFFF)],
          };

    final Color primaryColor = isGo
        ? const Color(0xFF00FF66)
        : switch (_countdownNumber) {
            3 => const Color(0xFFFF1744),
            2 => const Color(0xFFFF9100),
            _ => const Color(0xFFFFD600),
          };

    final Animation<double> scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.25, end: 1.25).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_countdownAnim);

    final Animation<double> opacityAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_countdownAnim);

    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: AnimatedBuilder(
          animation: _countdownAnim,
          builder: (context, child) {
            return Opacity(
              opacity: opacityAnimation.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grand Prix Starting Light Cluster (3 Racing LEDs)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStartingLight(
                            active: true,
                            color: isGo
                                ? const Color(0xFF00FF66)
                                : const Color(0xFFFF1744),
                          ),
                          SizedBox(width: 14.w),
                          _buildStartingLight(
                            active: _countdownNumber <= 2,
                            color: isGo
                                ? const Color(0xFF00FF66)
                                : const Color(0xFFFF9100),
                          ),
                          SizedBox(width: 14.w),
                          _buildStartingLight(
                            active: _countdownNumber <= 1,
                            color: isGo
                                ? const Color(0xFF00FF66)
                                : const Color(0xFFFFD600),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 18.h),

                    // Big Number / "GO!" with Radial Energy Burst Aura
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient Radial Burst Glow
                        Container(
                          width: isGo ? 260.w : 220.w,
                          height: isGo ? 260.w : 220.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                primaryColor.withValues(alpha: isGo ? 0.5 : 0.3),
                                primaryColor.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        // Main Text (Large Number / GO!)
                        Text(
                          mainText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.blackOpsOne(
                            fontSize: isGo ? 102.sp : 110.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: isGo ? 4.0 : 0.0,
                            foreground: Paint()
                              ..shader = LinearGradient(
                                colors: textGradient,
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(
                                const Rect.fromLTWH(0, 0, 300, 120),
                              ),
                            shadows: [
                              Shadow(
                                color: primaryColor.withValues(alpha: 0.9),
                                blurRadius: isGo ? 36 : 24,
                                offset: const Offset(0, 4),
                              ),
                              Shadow(
                                color: Colors.white.withValues(alpha: 0.6),
                                blurRadius: 10,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8.h),

                    // Subtitle Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        subText,
                        style: GoogleFonts.outfit(
                          color: primaryColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStartingLight({required bool active, required Color color}) {
    return Container(
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : const Color(0xFF334155),
        border: Border.all(
          color: active ? Colors.white : const Color(0xFF475569),
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.85),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: active
          ? Center(
              child: Container(
                width: 6.w,
                height: 6.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  // ----------------------------------------------------
  // Initial Gameplay Swipe Tutorial Guide Overlay
  // ----------------------------------------------------
  Widget _buildStartGameplayGuide() {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.88 + 0.12 * value,
                child: child,
              ),
            );
          },
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 26.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E293B),
                  Color(0xFF070B14),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      color: const Color(0xFFFFD700),
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "SWIPE CONTROLS",
                      style: GoogleFonts.blackOpsOne(
                        color: const Color(0xFFFFD700),
                        fontSize: 16.sp,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Steer Guide Row
                _buildGuideRow(
                  icon: Icons.swipe_rounded,
                  action: "SWIPE LEFT / RIGHT",
                  description: "Steer & Switch Highway Lanes",
                  color: const Color(0xFF38BDF8),
                ),
                SizedBox(height: 8.h),

                // Dodge Guide Row
                _buildGuideRow(
                  icon: Icons.directions_car_rounded,
                  action: "DODGE TRAFFIC & HAZARDS",
                  description: "Avoid Cars, Trucks & Roadblocks",
                  color: const Color(0xFFF87171),
                ),
                SizedBox(height: 8.h),

                // Collect Guide Row
                _buildGuideRow(
                  icon: Icons.diamond_rounded,
                  action: "COLLECT COINS & GEMS",
                  description: "1 Gem Every 200M + Speed Power-ups!",
                  color: const Color(0xFFFFD700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideRow({
    required IconData icon,
    required String action,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
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
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOutBack,
        child: widget.child,
      ),
    );
  }
}

class _ShowcaseGamingCarPainter extends CustomPainter {
  final PlayerCarTheme theme;
  final double animPhase;

  const _ShowcaseGamingCarPainter({
    required this.theme,
    required this.animPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double bounce = sin(animPhase * 2 * pi) * 1.8;
    final params = CarRenderParams(
      state: CarAnimationState.driving,
      speed: 150.0,
      laneTilt: sin(animPhase * 2 * pi) * 0.04,
      steerAngle: 0.0,
      suspensionBounce: bounce,
      wheelRotation: animPhase * 2 * pi,
      theme: theme,
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1.75, 1.75);
    canvas.translate(-30.0, -45.0);

    PlayerCarVisual.drawCar(
      canvas,
      const Size(60, 90),
      params,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShowcaseGamingCarPainter oldDelegate) {
    return oldDelegate.theme != theme || oldDelegate.animPhase != animPhase;
  }
}

// Backward compatibility alias for DiamondCatchScreen
typedef DiamondCatchScreen = CrazyRacingScreen;
