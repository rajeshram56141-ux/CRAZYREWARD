import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ============================================================================
/// NEAR MISS & COMBO SYSTEM CONFIGURATION
/// ============================================================================
class NearMissConfig {
  /// Master toggle to enable or disable the Near Miss & Combo system
  final bool enabled;

  /// Base points awarded for the 1st near-miss overtake
  final int baseScore;

  /// Score increment added per combo tier (+50, +100, +150, +200...)
  final int comboScoreStep;

  /// Whether near-misses also award bonus coins
  final bool awardCoins;

  /// Bonus coins awarded per combo level (e.g. 1 coin at x1/x2, 2 coins at x3/x4...)
  final int coinsPerComboTier;

  /// Whether near-miss overtakes replenish tactical Nitro Boost fuel
  final bool awardNitro;

  /// Amount of Nitro fuel restored (0.0 to 1.0)
  final double nitroRefillAmount;

  /// Time window in seconds before an active combo chain expires
  final double comboTimeoutSeconds;

  /// Maximum combo tier ceiling (e.g. 10)
  final int maxComboLevel;

  /// Vertical Y proximity threshold in pixels to register a near-miss
  final double proximityThresholdY;

  /// Whether to render the neon screen edge pulse vignette
  final bool enableScreenEffect;

  /// Duration of screen edge flash in seconds
  final double screenFlashDuration;

  /// Whether to play audio sound effects for near-misses & combos
  final bool enableSound;

  /// Whether to trigger haptic feedback vibrations
  final bool enableHaptics;

  /// Whether to show the on-screen combo/near-miss banner popup during racing
  final bool showBannerPopup;

  const NearMissConfig({
    this.enabled = true,
    this.showBannerPopup = false,
    this.baseScore = 50,
    this.comboScoreStep = 50,
    this.awardCoins = true,
    this.coinsPerComboTier = 1,
    this.awardNitro = true,
    this.nitroRefillAmount = 0.08,
    this.comboTimeoutSeconds = 3.2,
    this.maxComboLevel = 10,
    this.proximityThresholdY = 56.0,
    this.enableScreenEffect = true,
    this.screenFlashDuration = 0.35,
    this.enableSound = true,
    this.enableHaptics = true,
  });

  NearMissConfig copyWith({
    bool? enabled,
    bool? showBannerPopup,
    int? baseScore,
    int? comboScoreStep,
    bool? awardCoins,
    int? coinsPerComboTier,
    bool? awardNitro,
    double? nitroRefillAmount,
    double? comboTimeoutSeconds,
    int? maxComboLevel,
    double? proximityThresholdY,
    bool? enableScreenEffect,
    double? screenFlashDuration,
    bool? enableSound,
    bool? enableHaptics,
  }) {
    return NearMissConfig(
      enabled: enabled ?? this.enabled,
      showBannerPopup: showBannerPopup ?? this.showBannerPopup,
      baseScore: baseScore ?? this.baseScore,
      comboScoreStep: comboScoreStep ?? this.comboScoreStep,
      awardCoins: awardCoins ?? this.awardCoins,
      coinsPerComboTier: coinsPerComboTier ?? this.coinsPerComboTier,
      awardNitro: awardNitro ?? this.awardNitro,
      nitroRefillAmount: nitroRefillAmount ?? this.nitroRefillAmount,
      comboTimeoutSeconds: comboTimeoutSeconds ?? this.comboTimeoutSeconds,
      maxComboLevel: maxComboLevel ?? this.maxComboLevel,
      proximityThresholdY: proximityThresholdY ?? this.proximityThresholdY,
      enableScreenEffect: enableScreenEffect ?? this.enableScreenEffect,
      screenFlashDuration: screenFlashDuration ?? this.screenFlashDuration,
      enableSound: enableSound ?? this.enableSound,
      enableHaptics: enableHaptics ?? this.enableHaptics,
    );
  }
}

/// ============================================================================
/// NEAR MISS REWARD RESULT MODEL
/// ============================================================================
class NearMissRewardResult {
  final String title;
  final String subtitle;
  final int scoreBonus;
  final int coinsAwarded;
  final int comboLevel;
  final double comboMultiplier;
  final double nitroRefill;
  final Color accentColor;
  final int overtakeSide; // -1: Left, 1: Right

  const NearMissRewardResult({
    required this.title,
    required this.subtitle,
    required this.scoreBonus,
    required this.coinsAwarded,
    required this.comboLevel,
    required this.comboMultiplier,
    required this.nitroRefill,
    required this.accentColor,
    this.overtakeSide = 0,
  });
}

/// ============================================================================
/// ACTIVE NEAR MISS EVENT
/// ============================================================================
class NearMissEvent {
  final String title;
  final String subtitle;
  final int scoreBonus;
  final int coinsAwarded;
  final int comboLevel;
  final double comboMultiplier;
  final Color accentColor;
  final int overtakeSide;
  final double initialDuration;
  double remainingDuration;

  NearMissEvent({
    required this.title,
    required this.subtitle,
    required this.scoreBonus,
    required this.coinsAwarded,
    required this.comboLevel,
    required this.comboMultiplier,
    required this.accentColor,
    this.overtakeSide = 0,
    this.initialDuration = 1.25,
  }) : remainingDuration = initialDuration;

  double get progress => (1.0 - (remainingDuration / initialDuration)).clamp(0.0, 1.0);
  bool get isFinished => remainingDuration <= 0.0;
}

/// ============================================================================
/// MODULAR NEAR MISS & COMBO CONTROLLER (ENGINE)
/// ============================================================================
class NearMissController extends ChangeNotifier {
  NearMissConfig config;

  // Active Combo State
  int _comboLevel = 0;
  double _comboTimer = 0.0;
  double _comboMultiplier = 1.0;

  // Active Announcement Banner Event
  NearMissEvent? _activeEvent;

  // Screen Effect State
  double _screenPulseIntensity = 0.0;
  Color _screenPulseColor = const Color(0xFF00FF66);
  int _overtakeSide = 0; // -1: Left, 1: Right

  // Cumulative Race Statistics
  int _totalNearMisses = 0;
  int _highestCombo = 0;
  int _totalScoreEarned = 0;
  int _totalCoinsEarned = 0;

  NearMissController({this.config = const NearMissConfig()});

  // Getters
  bool get isEnabled => config.enabled;
  int get comboLevel => _comboLevel;
  bool get hasActiveCombo => _comboLevel > 0 && _comboTimer > 0.0;
  double get comboTimer => _comboTimer;
  double get comboTimeoutDuration => config.comboTimeoutSeconds;
  double get comboProgress => (config.comboTimeoutSeconds > 0)
      ? (_comboTimer / config.comboTimeoutSeconds).clamp(0.0, 1.0)
      : 0.0;
  double get comboMultiplier => _comboMultiplier;
  NearMissEvent? get activeEvent => _activeEvent;
  double get screenPulseIntensity => _screenPulseIntensity;
  Color get screenPulseColor => _screenPulseColor;
  int get overtakeSide => _overtakeSide;

  int get totalNearMisses => _totalNearMisses;
  int get highestCombo => _highestCombo;
  int get totalScoreEarned => _totalScoreEarned;
  int get totalCoinsEarned => _totalCoinsEarned;

  /// Update config dynamically (e.g. from user settings)
  void updateConfig(NearMissConfig newConfig) {
    config = newConfig;
    notifyListeners();
  }

  /// Full reset for fresh race
  void reset() {
    _comboLevel = 0;
    _comboTimer = 0.0;
    _comboMultiplier = 1.0;
    _activeEvent = null;
    _screenPulseIntensity = 0.0;
    _overtakeSide = 0;
    _totalNearMisses = 0;
    _highestCombo = 0;
    _totalScoreEarned = 0;
    _totalCoinsEarned = 0;
    notifyListeners();
  }

  /// Reset combo streak on vehicle/obstacle collision
  void resetOnCollision() {
    if (_comboLevel > 0) {
      _comboLevel = 0;
      _comboTimer = 0.0;
      _comboMultiplier = 1.0;
      _screenPulseIntensity = 0.0;
      _activeEvent = null;
      notifyListeners();
    }
  }

  /// 60 FPS update loop
  void update(double dt) {
    if (!config.enabled) return;

    bool stateChanged = false;

    // 1. Decay Screen Edge Pulse
    if (_screenPulseIntensity > 0.0) {
      final double decayRate = 1.0 / max(0.1, config.screenFlashDuration);
      _screenPulseIntensity = max(0.0, _screenPulseIntensity - dt * decayRate);
      stateChanged = true;
    }

    // 2. Update Active Announcement Event
    if (_activeEvent != null) {
      _activeEvent!.remainingDuration -= dt;
      if (_activeEvent!.isFinished) {
        _activeEvent = null;
      }
      stateChanged = true;
    }

    // 3. Count Down Combo Timeout
    if (_comboTimer > 0.0) {
      _comboTimer -= dt;
      if (_comboTimer <= 0.0) {
        _comboTimer = 0.0;
        _comboLevel = 0;
        _comboMultiplier = 1.0;
      }
      stateChanged = true;
    }

    if (stateChanged) {
      notifyListeners();
    }
  }

  /// Registers a successful Near-Miss overtake and advances the combo chain
  NearMissRewardResult? registerNearMiss({
    required double worldX,
    required double worldY,
    required int playerLane,
    required int vehicleLane,
    bool is2xMultiplierActive = false,
  }) {
    if (!config.enabled) return null;

    // 1. Advance Combo Chain
    _comboLevel = min(config.maxComboLevel, _comboLevel + 1);
    if (_comboLevel > _highestCombo) {
      _highestCombo = _comboLevel;
    }
    _totalNearMisses++;

    // 2. Calculate Dynamic Multiplier
    // Tier 1 (Near Miss): 1.2x
    // Tier 2 (Combo x2): 1.5x
    // Tier 3 (Combo x3): 2.0x
    // Tier 4 (Combo x4): 2.5x
    // Tier 5+ (Combo x5+): 3.0x - 4.0x
    _comboMultiplier = 1.0 + (_comboLevel * 0.25);

    // 3. Calculate Scaling Score Bonus (+50, +100, +150, +200...)
    final int basePts = config.baseScore + (_comboLevel - 1) * config.comboScoreStep;
    final int finalScore = is2xMultiplierActive ? basePts * 2 : basePts;
    _totalScoreEarned += finalScore;

    // 4. Calculate Optional Bonus Coins
    int coinsAwarded = 0;
    if (config.awardCoins) {
      // 1 coin for Near Miss & Combo x2, 2 coins for Combo x3/x4, 3 coins for Combo x5+
      coinsAwarded = max(1, (_comboLevel / 2).ceil()) * config.coinsPerComboTier;
      if (is2xMultiplierActive) coinsAwarded *= 2;
      _totalCoinsEarned += coinsAwarded;
    }

    // 5. Reset Combo Timeout Countdown
    _comboTimer = config.comboTimeoutSeconds;

    // 6. Determine Tier Visual Details & Theme Colors
    final (title, subtitle, accentColor) = _getTierVisuals(_comboLevel, finalScore, coinsAwarded);

    // 7. Overtake Side Direction
    _overtakeSide = (vehicleLane > playerLane) ? 1 : -1;

    // 8. Trigger Screen Flash Pulse
    if (config.enableScreenEffect) {
      _screenPulseIntensity = 1.0;
      _screenPulseColor = accentColor;
    }

    // 9. Create Active Event Banner
    _activeEvent = NearMissEvent(
      title: title,
      subtitle: subtitle,
      scoreBonus: finalScore,
      coinsAwarded: coinsAwarded,
      comboLevel: _comboLevel,
      comboMultiplier: _comboMultiplier,
      accentColor: accentColor,
      overtakeSide: _overtakeSide,
      initialDuration: 1.25,
    );

    notifyListeners();

    return NearMissRewardResult(
      title: title,
      subtitle: subtitle,
      scoreBonus: finalScore,
      coinsAwarded: coinsAwarded,
      comboLevel: _comboLevel,
      comboMultiplier: _comboMultiplier,
      nitroRefill: config.awardNitro ? config.nitroRefillAmount : 0.0,
      accentColor: accentColor,
      overtakeSide: _overtakeSide,
    );
  }

  /// Visual theme metadata per combo tier
  (String title, String subtitle, Color color) _getTierVisuals(int level, int score, int coins) {
    String scoreStr = "+$score";
    String coinStr = coins > 0 ? " • +$coins 🪙" : "";
    String subtitle = "$scoreStr$coinStr";

    switch (level) {
      case 1:
        return (
          "NEAR MISS!",
          subtitle,
          const Color(0xFF00FF66), // Neon Lime Green
        );
      case 2:
        return (
          "COMBO x2!",
          subtitle,
          const Color(0xFF38BDF8), // Electric Cyan
        );
      case 3:
        return (
          "COMBO x3! 🔥",
          subtitle,
          const Color(0xFFFFD700), // Blazing Gold
        );
      case 4:
        return (
          "MEGA COMBO x4! ⚡",
          subtitle,
          const Color(0xFFF97316), // High-Energy Orange
        );
      case 5:
        return (
          "ULTRA COMBO x5! 💥",
          subtitle,
          const Color(0xFFEC4899), // Hot Magenta
        );
      default:
        return (
          "UNSTOPPABLE x$level! 👑",
          subtitle,
          const Color(0xFFA855F7), // Royal Electric Purple
        );
    }
  }
}

/// ============================================================================
/// NEAR MISS VISUAL PAINTER (SCREEN EDGE VIGNETTE & SPEED STREAKS)
/// ============================================================================
class NearMissVisualRenderer {
  /// Renders neon radial screen-edge flash vignette when a near miss triggers
  static void drawScreenPulse(Canvas canvas, Size size, double intensity, Color color) {
    if (intensity <= 0.005) return;

    final double width = size.width;
    final double height = size.height;
    final double clampedIntensity = intensity.clamp(0.0, 1.0);

    // Outer screen glow border thickness
    final double borderSize = 28.0 * clampedIntensity;

    // Top Border Pulse
    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.45 * clampedIntensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, borderSize * 1.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, borderSize * 1.5), topPaint);

    // Bottom Border Pulse
    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: 0.45 * clampedIntensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, height - borderSize * 1.5, width, borderSize * 1.5));
    canvas.drawRect(Rect.fromLTWH(0, height - borderSize * 1.5, width, borderSize * 1.5), bottomPaint);

    // Left Border Pulse
    final leftPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.55 * clampedIntensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, borderSize * 1.8, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, borderSize * 1.8, height), leftPaint);

    // Right Border Pulse
    final rightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          color.withValues(alpha: 0.55 * clampedIntensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(width - borderSize * 1.8, 0, borderSize * 1.8, height));
    canvas.drawRect(Rect.fromLTWH(width - borderSize * 1.8, 0, borderSize * 1.8, height), rightPaint);

    // Corner Neon Accent Lines
    final cornerPaint = Paint()
      ..color = color.withValues(alpha: 0.75 * clampedIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * clampedIntensity;

    const double cornerLen = 42.0;
    // Top-Left
    canvas.drawLine(const Offset(8, 8), const Offset(8 + cornerLen, 8), cornerPaint);
    canvas.drawLine(const Offset(8, 8), const Offset(8, 8 + cornerLen), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(width - 8, 8), Offset(width - 8 - cornerLen, 8), cornerPaint);
    canvas.drawLine(Offset(width - 8, 8), Offset(width - 8, 8 + cornerLen), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(8, height - 8), Offset(8 + cornerLen, height - 8), cornerPaint);
    canvas.drawLine(Offset(8, height - 8), Offset(8, height - 8 - cornerLen), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(width - 8, height - 8), Offset(width - 8 - cornerLen, height - 8), cornerPaint);
    canvas.drawLine(Offset(width - 8, height - 8), Offset(width - 8, height - 8 - cornerLen), cornerPaint);
  }

  /// Renders air-drag friction streaks along the vehicle overtake line
  static void drawOvertakeStreaks({
    required Canvas canvas,
    required Size size,
    required double intensity,
    required Color color,
    required double playerY,
    required int overtakeSide,
    required double animTime,
  }) {
    if (intensity <= 0.05 || overtakeSide == 0) return;

    final double width = size.width;
    final double flankX = (overtakeSide > 0) ? width * 0.72 : width * 0.28;
    final Random rnd = Random(42);

    final streakPaint = Paint()
      ..color = color.withValues(alpha: 0.65 * intensity)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 6; i++) {
      final double xOffset = (rnd.nextDouble() - 0.5) * 40.0;
      final double yOffset = (rnd.nextDouble() - 0.5) * 80.0 + (sin(animTime * 20.0 + i) * 10.0);
      final double streakLen = 25.0 + rnd.nextDouble() * 35.0;

      canvas.drawLine(
        Offset(flankX + xOffset, playerY + yOffset - streakLen),
        Offset(flankX + xOffset, playerY + yOffset + streakLen),
        streakPaint,
      );
    }
  }
}

/// ============================================================================
/// ANIMATED NEAR MISS & COMBO ANNOUNCEMENT BANNER WIDGET
/// ============================================================================
class NearMissBannerWidget extends StatelessWidget {
  final NearMissController controller;

  const NearMissBannerWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final event = controller.activeEvent;
        if (event == null) return const SizedBox.shrink();

        // Dynamic Animation Curve: Elastic Spring Pop In -> Float & Glow -> Fade Out
        final double progress = event.progress; // 0.0 -> 1.0
        double scale = 1.0;
        double opacity = 1.0;
        double translateY = 0.0;

        if (progress < 0.25) {
          // Spring bounce entrance (0.0 to 1.25 to 1.0)
          final double t = progress / 0.25;
          scale = Curves.easeOutBack.transform(t);
          opacity = t.clamp(0.0, 1.0);
          translateY = (1.0 - t) * -24.0;
        } else if (progress > 0.75) {
          // Smooth fade out & rise
          final double t = (progress - 0.75) / 0.25;
          scale = 1.0 - (t * 0.15);
          opacity = (1.0 - t).clamp(0.0, 1.0);
          translateY = -t * 18.0;
        } else {
          // Mid-flight subtle floating breathing pulse
          final double midT = (progress - 0.25) / 0.5;
          scale = 1.0 + sin(midT * pi) * 0.06;
          opacity = 1.0;
          translateY = 0.0;
        }

        final Color accentColor = event.accentColor;

        return Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 24.w),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F172A).withValues(alpha: 0.94),
                          const Color(0xFF1E293B).withValues(alpha: 0.92),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: accentColor,
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Main Announcement Header (e.g. NEAR MISS! or COMBO x3! 🔥)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              event.comboLevel > 1 ? Icons.bolt_rounded : Icons.flash_on_rounded,
                              color: accentColor,
                              size: 20.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              event.title,
                              style: GoogleFonts.fredoka(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: accentColor.withValues(alpha: 0.8),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(
                              event.comboLevel > 1 ? Icons.bolt_rounded : Icons.flash_on_rounded,
                              color: accentColor,
                              size: 20.sp,
                            ),
                          ],
                        ),

                        SizedBox(height: 4.h),

                        // Score & Bonus Coins Capsule
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.6),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "+${event.scoreBonus} PTS",
                                style: GoogleFonts.fredoka(
                                  color: accentColor,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              if (event.coinsAwarded > 0) ...[
                                SizedBox(width: 6.w),
                                Container(
                                  width: 4.w,
                                  height: 4.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.monetization_on_rounded,
                                      color: const Color(0xFFFFD700),
                                      size: 13.sp,
                                    ),
                                    SizedBox(width: 2.w),
                                    Text(
                                      "+${event.coinsAwarded}",
                                      style: GoogleFonts.fredoka(
                                        color: const Color(0xFFFFD700),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Active Combo Timeout Fuse Bar
                        if (controller.hasActiveCombo) ...[
                          SizedBox(height: 6.h),
                          SizedBox(
                            width: 140.w,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4.r),
                              child: LinearProgressIndicator(
                                value: controller.comboProgress,
                                minHeight: 4.h,
                                backgroundColor: const Color(0xFF334155),
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

/// ============================================================================
/// DYNAMIC COMBO MULTIPLIER BADGE (FOR HUD DISPLAY)
/// ============================================================================
class ComboMultiplierBadgeWidget extends StatelessWidget {
  final NearMissController controller;

  const ComboMultiplierBadgeWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.hasActiveCombo) return const SizedBox.shrink();

        final Color color = (controller.comboLevel >= 4)
            ? const Color(0xFFFF3D00)
            : (controller.comboLevel >= 2)
                ? const Color(0xFFFFD700)
                : const Color(0xFF00FF66);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.35),
                const Color(0xFF0F172A).withValues(alpha: 0.90),
              ],
            ),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: color,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini Circular Progress Countdown Ring
              SizedBox(
                width: 12.w,
                height: 12.w,
                child: CircularProgressIndicator(
                  value: controller.comboProgress,
                  strokeWidth: 2.2,
                  backgroundColor: const Color(0xFF334155),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              SizedBox(width: 5.w),
              Text(
                'x${controller.comboMultiplier.toStringAsFixed(1)} COMBO',
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
