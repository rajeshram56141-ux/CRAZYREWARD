import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'storage_service.dart';

/// ============================================================================
/// CONFIGURATION FOR THE SCORING & COMBO ENGINE
/// ============================================================================
class ScoreConfig {
  final double distanceRate; // Distance in meters per world speed unit
  final double distancePointsPerMeter; // Score per meter travelled
  final double timeSurvivalPointsPerSecond; // Passive score per second survived
  final double speedBonusThreshold; // Speed above which velocity bonus applies
  final double speedBonusMultiplier; // Multiplier for high-speed bonus points
  final int baseCoinPoints; // Base points per collected gold coin
  final int baseGemPoints; // Base points per crystal gem
  final int nearMissBasePoints; // Base points per high-speed near-miss overtake
  final int powerUpCollectPoints; // Base points for power-up discovery
  final int smashObstaclePoints; // Base points for overdrive obstacle smash
  final double comboDurationSeconds; // Time window before combo decay
  final double maxComboMultiplier; // Peak combo limit
  final double comboStep; // Increment per consecutive near-miss / streak

  const ScoreConfig({
    this.distanceRate = 0.18,
    this.distancePointsPerMeter = 0.75,
    this.timeSurvivalPointsPerSecond = 6.0,
    this.speedBonusThreshold = 160.0,
    this.speedBonusMultiplier = 0.016,
    this.baseCoinPoints = 10,
    this.baseGemPoints = 50,
    this.nearMissBasePoints = 25,
    this.powerUpCollectPoints = 30,
    this.smashObstaclePoints = 50,
    this.comboDurationSeconds = 3.5,
    this.maxComboMultiplier = 4.0,
    this.comboStep = 0.2,
  });
}

/// ============================================================================
/// MODULAR REUSABLE SCORE MANAGER
/// ============================================================================
/// Manages real-time multi-factor scoring:
/// - Distance travelled (continuous)
/// - Time survived (continuous)
/// - Speed bonus (continuous when driving fast)
/// - Coins, Gems & Power-ups collected
/// - Near-miss overtakes with dynamic combo multipliers
/// - Local best score persistence
/// - 60 FPS smooth interpolation for animated HUD display
/// ============================================================================
class ScoreManager extends ChangeNotifier {
  final ScoreConfig config;

  // Running Metrics
  double _rawScore = 0.0;
  int currentScore = 0;
  double animatedScore = 0.0;
  int bestScore = 0;
  bool isNewHighScore = false;

  // Granular Run Stats
  double distance = 0.0; // Distance in meters
  double timeSurvived = 0.0; // Active driving seconds
  int coinsCollected = 0;
  int gemsCollected = 0;
  int nearMissCount = 0;
  int powerUpsCollected = 0;

  // Continuous Score Factor Accumulators
  double _distanceScoreAccumulator = 0.0;
  double _timeScoreAccumulator = 0.0;
  double _speedScoreAccumulator = 0.0;
  int _bonusEventsScore = 0;

  // Combo & Streak System
  double comboMultiplier = 1.0;
  int comboCount = 0;
  double comboTimer = 0.0;
  String? lastBonusLabel;
  int lastBonusPoints = 0;
  double bonusPopupTimer = 0.0;

  ScoreManager({this.config = const ScoreConfig()}) {
    loadBestScore();
  }

  /// Load best score from local persistent storage
  void loadBestScore() {
    bestScore = RunnerStorageService.getBestScore();
    notifyListeners();
  }

  /// Reset all metrics for a fresh race
  void reset() {
    _rawScore = 0.0;
    currentScore = 0;
    animatedScore = 0.0;
    isNewHighScore = false;
    distance = 0.0;
    timeSurvived = 0.0;
    coinsCollected = 0;
    gemsCollected = 0;
    nearMissCount = 0;
    powerUpsCollected = 0;
    _distanceScoreAccumulator = 0.0;
    _timeScoreAccumulator = 0.0;
    _speedScoreAccumulator = 0.0;
    _bonusEventsScore = 0;
    comboMultiplier = 1.0;
    comboCount = 0;
    comboTimer = 0.0;
    lastBonusLabel = null;
    lastBonusPoints = 0;
    bonusPopupTimer = 0.0;
    bestScore = RunnerStorageService.getBestScore();
    notifyListeners();
  }

  /// Update continuous factors every frame (60 FPS)
  void update({
    required double dt,
    required double currentSpeed,
    bool isPlaying = true,
    bool is2xMultiplierActive = false,
    bool isNitroActive = false,
  }) {
    if (!isPlaying) return;

    // 1. Time Survived Accumulation
    timeSurvived += dt;

    // 2. Distance Travelled Accumulation
    final double deltaDistance = currentSpeed * dt * config.distanceRate;
    distance += deltaDistance;

    // Active Multipliers: 2X Coin Multiplier Power-up + Nitro Boost Multiplier + Combo Multiplier
    final double powerUpMulti = is2xMultiplierActive ? 2.0 : 1.0;
    final double nitroMulti = isNitroActive ? 1.35 : 1.0;
    final double activeMulti = comboMultiplier * powerUpMulti * nitroMulti;

    // Continuous Factor A: Distance Points
    final double distPoints = (deltaDistance * config.distancePointsPerMeter) * activeMulti;
    _distanceScoreAccumulator += distPoints;

    // Continuous Factor B: Survival Time Points
    final double timePoints = (dt * config.timeSurvivalPointsPerSecond) * activeMulti;
    _timeScoreAccumulator += timePoints;

    // Continuous Factor C: High Velocity Speed Points Bonus
    if (currentSpeed > config.speedBonusThreshold) {
      final double excessSpeed = currentSpeed - config.speedBonusThreshold;
      final double speedBonus = (excessSpeed * config.speedBonusMultiplier * dt) * activeMulti;
      _speedScoreAccumulator += speedBonus;
    }

    // Combine all score channels
    _rawScore = _distanceScoreAccumulator +
        _timeScoreAccumulator +
        _speedScoreAccumulator +
        _bonusEventsScore;
    currentScore = _rawScore.toInt();

    // Smoothly animate score changes (Exponential Lerp for smooth 60 FPS rolling counter)
    final double scoreDiff = currentScore.toDouble() - animatedScore;
    if (scoreDiff.abs() > 0.01) {
      animatedScore += scoreDiff * min(1.0, dt * 14.0);
    } else {
      animatedScore = currentScore.toDouble();
    }

    // Real-Time High Score Detection
    if (currentScore > bestScore) {
      bestScore = currentScore;
      if (!isNewHighScore) {
        isNewHighScore = true;
      }
    }

    // 3. Update Combo Countdown Timer & Decay
    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) {
        comboTimer = 0.0;
        comboCount = 0;
        comboMultiplier = 1.0;
      }
    }

    // 4. Update Bonus Popup Banner Timer
    if (bonusPopupTimer > 0) {
      bonusPopupTimer -= dt;
      if (bonusPopupTimer <= 0) {
        lastBonusLabel = null;
      }
    }
  }

  /// Adds score for collecting a gold racing coin
  void addCoin({int? basePoints, bool isMultiplierActive = false}) {
    coinsCollected++;
    final int points = (basePoints ?? config.baseCoinPoints);
    _applyBonusEvent(
      basePoints: points,
      isMultiplierActive: isMultiplierActive,
      label: "+$points COIN",
      extendCombo: true,
    );
  }

  /// Adds score for collecting a crystal gem
  void addGem({int? basePoints, bool isMultiplierActive = false}) {
    gemsCollected++;
    final int points = (basePoints ?? config.baseGemPoints);
    _applyBonusEvent(
      basePoints: points,
      isMultiplierActive: isMultiplierActive,
      label: "+$points GEM!",
      extendCombo: true,
    );
  }

  /// Adds score and increments combo for high-speed near-miss overtakes
  void addNearMiss({int? basePoints, bool isMultiplierActive = false}) {
    nearMissCount++;
    comboCount++;

    // Increment combo multiplier up to maximum ceiling
    comboMultiplier = min(config.maxComboMultiplier, comboMultiplier + config.comboStep);
    comboTimer = config.comboDurationSeconds;

    final int points = (basePoints ?? config.nearMissBasePoints);
    _applyBonusEvent(
      basePoints: points,
      isMultiplierActive: isMultiplierActive,
      label: "NEAR MISS! x${comboMultiplier.toStringAsFixed(1)}",
      extendCombo: true,
    );
  }

  /// Adds precise near-miss score and combo level from NearMissController
  void addNearMissScore({
    required int points,
    int? comboLevel,
    String? label,
  }) {
    nearMissCount++;
    if (comboLevel != null) {
      comboCount = comboLevel;
    } else {
      comboCount++;
    }
    _bonusEventsScore += points;
    _rawScore += points;
    currentScore = _rawScore.toInt();
    lastBonusLabel = label ?? "NEAR MISS! +$points";
    lastBonusPoints = points;
    bonusPopupTimer = 1.2;
    notifyListeners();
  }

  /// Adds score for picking up a modular power-up
  void addPowerUpBonus({int? basePoints, String name = "POWER-UP"}) {
    powerUpsCollected++;
    final int points = (basePoints ?? config.powerUpCollectPoints);
    _applyBonusEvent(
      basePoints: points,
      label: "$name +$points",
      extendCombo: false,
    );
  }

  /// Adds score for smashing through traffic/obstacles during Invincible Overdrive
  void addSmashBonus({int? basePoints}) {
    final int points = (basePoints ?? config.smashObstaclePoints);
    _applyBonusEvent(
      basePoints: points,
      label: "SMASH! +$points ⭐",
      extendCombo: true,
    );
  }

  /// Deducts penalty points (e.g. hitting minor speed cones)
  void applyPenalty(int penaltyPoints) {
    _bonusEventsScore = max(0, _bonusEventsScore - penaltyPoints);
    _rawScore = max(0.0, _rawScore - penaltyPoints);
    currentScore = _rawScore.toInt();

    // Reset combo on penalty hit
    comboMultiplier = 1.0;
    comboCount = 0;
    comboTimer = 0.0;
  }

  void _applyBonusEvent({
    required int basePoints,
    bool isMultiplierActive = false,
    required String label,
    bool extendCombo = false,
  }) {
    final double powerUpMulti = isMultiplierActive ? 2.0 : 1.0;
    final int awardedPoints = (basePoints * comboMultiplier * powerUpMulti).round();
    _bonusEventsScore += awardedPoints;
    _rawScore += awardedPoints;
    currentScore = _rawScore.toInt();

    lastBonusLabel = label;
    lastBonusPoints = awardedPoints;
    bonusPopupTimer = 1.2;

    if (extendCombo) {
      comboTimer = max(comboTimer, config.comboDurationSeconds);
    }
  }

  /// Saves the current best score to persistent storage
  void saveBestScore() {
    RunnerStorageService.saveBestScore(currentScore);
    bestScore = RunnerStorageService.getBestScore();
  }

  // Helper Getters
  bool get hasActiveCombo => comboMultiplier > 1.0 && comboTimer > 0;
  double get comboProgress => (comboTimer / config.comboDurationSeconds).clamp(0.0, 1.0);
  int get displayScore => animatedScore.round();
}

/// ============================================================================
/// SMOOTH ANIMATED SCORE DISPLAY WIDGET
/// ============================================================================
class AnimatedScoreWidget extends StatelessWidget {
  final ScoreManager scoreManager;
  final bool showBestScore;
  final bool isMultiplierActive;

  const AnimatedScoreWidget({
    super.key,
    required this.scoreManager,
    this.showBestScore = true,
    this.isMultiplierActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final int display = scoreManager.displayScore;
    final bool isNewBest = scoreManager.isNewHighScore;
    final bool hasCombo = scoreManager.hasActiveCombo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Animated Score Box
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isNewBest ? const Color(0xFF00FF66) : const Color(0xFFFFD700),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isNewBest ? const Color(0xFF00FF66) : const Color(0xFFFFD700))
                    .withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: isNewBest ? const Color(0xFF00FF66) : const Color(0xFFFFD700),
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                '$display',
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              if (isMultiplierActive) ...[
                SizedBox(width: 5.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    '2X',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Active Combo Multiplier Badge with Countdown Meter
        if (hasCombo) ...[
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
              ),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: const Color(0xFFFDA4AF),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 12.sp),
                    SizedBox(width: 3.w),
                    Text(
                      'COMBO x${scoreManager.comboMultiplier.toStringAsFixed(1)}',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.r),
                  child: SizedBox(
                    width: 64.w,
                    height: 3.h,
                    child: LinearProgressIndicator(
                      value: scoreManager.comboProgress,
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Best Score Badge
        if (showBestScore && !hasCombo) ...[
          SizedBox(height: 3.h),
          Padding(
            padding: EdgeInsets.only(left: 4.w),
            child: Text(
              isNewBest ? '⭐ NEW BEST!' : 'BEST: ${scoreManager.bestScore}',
              style: GoogleFonts.fredoka(
                color: isNewBest ? const Color(0xFF00FF66) : const Color(0xFF94A3B8),
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
