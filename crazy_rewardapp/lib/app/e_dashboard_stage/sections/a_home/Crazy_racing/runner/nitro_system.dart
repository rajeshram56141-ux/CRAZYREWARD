import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'player_car.dart';

/// ============================================================================
/// TURBO RACER: MODULAR & CONFIGURABLE NITRO BOOST SYSTEM
/// ============================================================================
/// Features:
/// 1. Highly Configurable Physics & Gameplay Tuning ([NitroConfig])
/// 2. Stateful Reactive Controller ([NitroController]) with smooth 60 FPS
///    activation/deactivation lerp animations
/// 3. Visual FX Subsystem:
///    - Dynamic High-Speed Streaks & Speed Lines
///    - Edge Radial Motion Blur & Chromatic Vignette Aura
///    - Twin/Quad Hypercharged Exhaust Jet Flames & Plasma Trails
///    - Subtle Camera Perspective FOV Zoom
/// 4. Multiple Nitro Acquisition Channels:
///    - Canister Pickups (+40%)
///    - Coin Pickups (+6%)
///    - Near-Miss Overtakes with Traffic (+20%)
///    - Continuous Passive Drip Refill (+3.5%/s)
/// 5. Premium Arcade UI ([NitroMeterWidget] & [NitroButtonWidget])
/// ============================================================================

/// Configuration settings for the Nitro Boost System
class NitroConfig {
  /// Maximum capacity of the Nitro tank (0.0 to 100.0)
  final double maxNitro;

  /// Drain rate per second while actively boosting (e.g. 22.0 = ~4.5 seconds full burn)
  final double drainRate;

  /// Passive auto-refill rate per second when not boosting (e.g. 3.5 = ~28 seconds full refill)
  final double passiveRefillRate;

  /// Nitro gained when collecting a golden coin
  final double coinRefillAmount;

  /// Nitro gained when collecting a dedicated Nitro Canister power-up
  final double canisterRefillAmount;

  /// Nitro gained for performing a daring near-miss overtake with traffic
  final double nearMissRefillAmount;

  /// Speed boost multiplier applied to base game speed during full boost (e.g. 1.75x)
  final double speedMultiplier;

  /// Camera FOV zoom scale factor when boosting (e.g. 1.06 = 6% zoom)
  final double cameraZoomFactor;

  /// Minimum Nitro percentage required to ignite boost (e.g. 8.0%)
  final double minActivationThreshold;

  /// Interpolation speed for smooth activation and deactivation transitions
  final double animationLerpSpeed;

  const NitroConfig({
    this.maxNitro = 100.0,
    this.drainRate = 22.0,
    this.passiveRefillRate = 3.5,
    this.coinRefillAmount = 6.0,
    this.canisterRefillAmount = 40.0,
    this.nearMissRefillAmount = 20.0,
    this.speedMultiplier = 1.75,
    this.cameraZoomFactor = 1.06,
    this.minActivationThreshold = 8.0,
    this.animationLerpSpeed = 7.5,
  });

  /// Default production racing configuration
  static const NitroConfig defaultConfig = NitroConfig();

  /// Supercharged arcade configuration with fast refill & higher speed
  static const NitroConfig arcadeExtreme = NitroConfig(
    maxNitro: 100.0,
    drainRate: 18.0,
    passiveRefillRate: 5.5,
    coinRefillAmount: 10.0,
    canisterRefillAmount: 50.0,
    nearMissRefillAmount: 30.0,
    speedMultiplier: 1.95,
    cameraZoomFactor: 1.09,
    minActivationThreshold: 5.0,
    animationLerpSpeed: 9.0,
  );
}

/// Reactive Controller managing the runtime state of Nitro Boost
class NitroController {
  final NitroConfig config;

  /// Current Nitro charge (0.0 to [config.maxNitro])
  double currentNitro;

  /// Whether the user is actively pressing / requesting boost
  bool isPressed = false;

  /// Smooth 0.0 -> 1.0 animation intensity value for visual fx & speed scaling
  double nitroIntensity = 0.0;

  /// Animation cycle for pulsing flames & speed lines
  double animPhase = 0.0;

  /// Callback for audio/haptics when boost ignites or ends
  VoidCallback? onIgnition;
  VoidCallback? onDepleted;

  NitroController({
    this.config = NitroConfig.defaultConfig,
    double initialCharge = 70.0,
    this.onIgnition,
    this.onDepleted,
  }) : currentNitro = initialCharge;

  /// Is Nitro actively burning right now?
  bool get isBurning => isPressed && currentNitro > 0.5;

  /// Fill percentage ratio (0.0 to 1.0)
  double get fillPercentage => (currentNitro / config.maxNitro).clamp(0.0, 1.0);

  /// Is the tank completely full?
  bool get isFull => currentNitro >= config.maxNitro - 0.5;

  /// Is Nitro available to fire?
  bool get canActivate => currentNitro >= config.minActivationThreshold;

  /// Start Nitro Boost (Hold or Toggle)
  bool startBoost() {
    if (!canActivate && !isBurning) return false;
    isPressed = true;
    onIgnition?.call();
    return true;
  }

  /// Stop Nitro Boost
  void stopBoost() {
    isPressed = false;
  }

  /// Toggle Nitro Boost
  bool toggleBoost() {
    if (isPressed) {
      stopBoost();
      return false;
    } else {
      return startBoost();
    }
  }

  /// Add Nitro fuel (from pickups, coins, or near misses)
  void addNitro(double amount) {
    currentNitro = (currentNitro + amount).clamp(0.0, config.maxNitro);
  }

  /// Reset Nitro to initial state on new run
  void reset({double initialCharge = 70.0}) {
    currentNitro = initialCharge;
    isPressed = false;
    nitroIntensity = 0.0;
    animPhase = 0.0;
  }

  /// 60 FPS Game Loop Update Method
  void update(double dt, double worldSpeed) {
    animPhase = (animPhase + dt * 8.0) % (2 * pi);

    if (isBurning) {
      // 1. Drain fuel while burning
      currentNitro -= config.drainRate * dt;
      if (currentNitro <= 0.0) {
        currentNitro = 0.0;
        isPressed = false;
        onDepleted?.call();
      }
    } else {
      // 2. Passive gradual refill when idle
      if (currentNitro < config.maxNitro) {
        currentNitro = min(
          config.maxNitro,
          currentNitro + config.passiveRefillRate * dt,
        );
      }
    }

    // 3. Smoothly interpolate animation intensity (Ease-In / Ease-Out)
    final double targetIntensity = isBurning ? 1.0 : 0.0;
    final double lerpFactor = (dt * config.animationLerpSpeed).clamp(0.0, 1.0);
    nitroIntensity += (targetIntensity - nitroIntensity) * lerpFactor;

    if (nitroIntensity < 0.001) nitroIntensity = 0.0;
    if (nitroIntensity > 0.999) nitroIntensity = 1.0;
  }
}

/// ============================================================================
/// NITRO VISUAL FX RENDERER (SPEED LINES, MOTION BLUR, EXHAUST FLAMES)
/// ============================================================================
class NitroVisualRenderer {
  /// 1. Dynamic Speed Lines shooting from horizon outward to screen boundaries
  static void drawSpeedLines(
    Canvas canvas,
    Size size,
    double intensity,
    double horizonY,
    double animPhase,
  ) {
    if (intensity < 0.02) return;

    final double width = size.width;
    final double originX = width / 2;
    final double originY = horizonY;

    final int lineCount = (14 + intensity * 26).toInt();

    for (int i = 0; i < lineCount; i++) {
      // Fixed pseudo-random distribution around outer screen borders
      final double seed = (i * 37.13 + animPhase * 3.5) % 1.0;
      final double angle = (i / lineCount) * 2 * pi;

      // Only draw lines traveling toward sides and bottom (not straight up)
      if (sin(angle) < -0.15) continue;

      final double startDistance = 60.0 + seed * 120.0;
      final double lineLength = (90.0 + (1.0 - seed) * 160.0) * intensity;

      final double startX = originX + cos(angle) * startDistance;
      final double startY = originY + sin(angle) * startDistance;
      final double endX = originX + cos(angle) * (startDistance + lineLength);
      final double endY = originY + sin(angle) * (startDistance + lineLength);

      final Color lineColor = (i % 3 == 0)
          ? const Color(0xFF00F2FE) // Electric Cyan
          : (i % 3 == 1)
              ? const Color(0xFF00FF66) // Neon Green
              : Colors.white; // Pure White Spark

      final double alpha = ((0.35 + (1.0 - seed) * 0.55) * intensity).clamp(0.0, 0.9);

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            lineColor.withValues(alpha: alpha),
            lineColor.withValues(alpha: alpha * 0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)))
        ..strokeWidth = (1.5 + (i % 4) * 0.8) * intensity
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  /// 2. Motion Blur Screen Edge Vignette & Chromatic Blur Aura
  static void drawMotionBlurAura(Canvas canvas, Size size, double intensity) {
    if (intensity < 0.04) return;

    final double width = size.width;
    final double height = size.height;

    // Edge radial speed vignette
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.9,
        colors: [
          Colors.transparent,
          const Color(0xFF00F2FE).withValues(alpha: 0.08 * intensity),
          const Color(0xFF0066FF).withValues(alpha: 0.22 * intensity),
          Colors.black.withValues(alpha: 0.35 * intensity),
        ],
        stops: const [0.55, 0.78, 0.92, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), vignettePaint);

    // Lateral Speed Streaks on left and right screen borders
    final borderStreakPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFF00F2FE).withValues(alpha: 0.25 * intensity),
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF00F2FE).withValues(alpha: 0.25 * intensity),
        ],
        stops: const [0.0, 0.08, 0.92, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), borderStreakPaint);
  }

  /// 3. Twin/Quad Hypercharged Exhaust Jet Flames
  static void drawNitroExhaustFlames(
    Canvas canvas,
    CarRenderParams params,
    double intensity,
    double animPhase,
  ) {
    if (intensity < 0.02) return;

    final double flickerA = sin(animPhase * 3.0) * 0.15;
    final double flickerB = cos(animPhase * 4.5) * 0.15;

    // Quad exhaust tips at car rear
    final List<double> exhaustXPositions = [-14.0, -8.5, 8.5, 14.0];
    final double baseY = 36.0;

    for (int i = 0; i < exhaustXPositions.length; i++) {
      final double ox = exhaustXPositions[i];
      final double flicker = (i % 2 == 0) ? flickerA : flickerB;
      final double flameLength = (26.0 + flicker * 12.0 + (i.isOdd ? 8.0 : 0.0)) * intensity;
      final double flameWidth = (5.5 + flicker * 2.0) * intensity;

      // 1. Outer Volumetric Nitro Plasma Flame (Cyan to Violet to Transparent)
      final outerFlamePath = Path()
        ..moveTo(ox - flameWidth / 2, baseY)
        ..quadraticBezierTo(ox - flameWidth * 0.8, baseY + flameLength * 0.5, ox, baseY + flameLength)
        ..quadraticBezierTo(ox + flameWidth * 0.8, baseY + flameLength * 0.5, ox + flameWidth / 2, baseY)
        ..close();

      final outerFlamePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF00F2FE).withValues(alpha: 0.95 * intensity),
            const Color(0xFF3B82F6).withValues(alpha: 0.85 * intensity),
            const Color(0xFFA855F7).withValues(alpha: 0.45 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ).createShader(Rect.fromLTWH(ox - flameWidth, baseY, flameWidth * 2, flameLength));

      canvas.drawPath(outerFlamePath, outerFlamePaint);

      // 2. Inner Superheated Blazing Flame (Cyan to White-Gold)
      final innerFlamePath = Path()
        ..moveTo(ox - flameWidth * 0.3, baseY)
        ..quadraticBezierTo(ox - flameWidth * 0.4, baseY + flameLength * 0.35, ox, baseY + flameLength * 0.7)
        ..quadraticBezierTo(ox + flameWidth * 0.4, baseY + flameLength * 0.35, ox + flameWidth * 0.3, baseY)
        ..close();

      final innerFlamePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.95 * intensity),
            const Color(0xFF00F2FE).withValues(alpha: 0.90 * intensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(ox - flameWidth, baseY, flameWidth * 2, flameLength * 0.7));

      canvas.drawPath(innerFlamePath, innerFlamePaint);

      // 3. White-Hot Ignition Core
      final corePath = Path()
        ..moveTo(ox - 1.5, baseY)
        ..lineTo(ox, baseY + flameLength * 0.35)
        ..lineTo(ox + 1.5, baseY)
        ..close();
      canvas.drawPath(corePath, Paint()..color = Colors.white.withValues(alpha: intensity));

      // 4. Heat Distortion Rings / Shock Diamonds
      if (intensity > 0.65) {
        final shockPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.75 * intensity)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(ox, baseY + flameLength * 0.4), width: flameWidth * 0.6, height: 3.0),
          shockPaint,
        );
      }
    }
  }

  /// 4. Draw Nitro Canister Collectible Pickup
  static void drawNitroCanister(Canvas canvas, double cx, double cy, double spinPhase) {
    canvas.save();
    canvas.translate(cx, cy);

    final double scale = 1.0 + sin(spinPhase) * 0.08;
    canvas.scale(scale, scale);

    // Glowing Radial Halo
    final haloPaint = Paint()
      ..color = const Color(0xFF00F2FE).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset.zero, 24.0, haloPaint);

    // Metallic Nitrogen Gas Cylinder Body
    final cylinderRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-11, -16, 22, 32),
      const Radius.circular(8.0),
    );

    final cylinderPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF00F2FE),
          Color(0xFF0284C7),
          Color(0xFF0369A1),
          Color(0xFF082F49),
        ],
        stops: [0.0, 0.3, 0.7, 1.0],
      ).createShader(const Rect.fromLTWH(-11, -16, 22, 32));

    canvas.drawRRect(cylinderRect, cylinderPaint);

    // Metallic Neck & Valve Nozzle
    final valveRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-4, -22, 8, 6),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(valveRect, Paint()..color = const Color(0xFFE2E8F0));

    // Valve Gauge Dial
    canvas.drawCircle(const Offset(0, -22), 3.0, Paint()..color = const Color(0xFFEF4444));

    // "NOS" Racing Decal Badge
    final badgePaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.85);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -4, 18, 12), const Radius.circular(4.0)),
      badgePaint,
    );

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: "NOS",
        style: GoogleFonts.blackOpsOne(
          color: const Color(0xFF00F2FE),
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2 + 2));

    // Specular Highlight Glint
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-8, -12), const Offset(-8, 10), shinePaint);

    canvas.restore();
  }
}

/// ============================================================================
/// NITRO UI COMPONENTS: [NitroMeterWidget] & [NitroButtonWidget]
/// ============================================================================

/// Sleek arcade Nitro Meter displaying the fuel gauge & fill percentage
class NitroMeterWidget extends StatelessWidget {
  final NitroController controller;
  final double width;
  final double height;

  const NitroMeterWidget({
    super.key,
    required this.controller,
    this.width = 160.0,
    this.height = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final double pct = controller.fillPercentage;
    final bool isBurning = controller.isBurning;
    final bool isFull = controller.isFull;

    final Color primaryColor = isBurning
        ? const Color(0xFF00FF66) // Burning Neon Green
        : isFull
            ? const Color(0xFF00F2FE) // Full Electric Cyan
            : const Color(0xFF38BDF8); // Standard Sky Blue

    return Container(
      width: width.w,
      height: height.h,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: primaryColor.withValues(alpha: isBurning ? 0.9 : 0.5),
          width: isBurning ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isBurning ? 0.45 : 0.2),
            blurRadius: isBurning ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Background Track
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),

          // Glowing Progress Fill Bar
          FractionallySizedBox(
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                gradient: LinearGradient(
                  colors: isBurning
                      ? const [
                          Color(0xFF00FF66),
                          Color(0xFF00F2FE),
                          Color(0xFFFFFFFF),
                        ]
                      : const [
                          Color(0xFF0284C7),
                          Color(0xFF00F2FE),
                          Color(0xFF38BDF8),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),

          // Foreground Info: Icon & Percentage Text
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: isBurning ? const Color(0xFF00FF66) : Colors.white,
                      size: 13.sp,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      isBurning ? "BOOSTING!" : "NITRO",
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Text(
                  "${(pct * 100).toInt()}%",
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
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

/// Tactical On-Screen Nitro Boost Arcade Button (Hold-to-Boost & Tap Support)
class NitroButtonWidget extends StatelessWidget {
  final NitroController controller;
  final VoidCallback? onActivate;
  final VoidCallback? onDeactivate;

  const NitroButtonWidget({
    super.key,
    required this.controller,
    this.onActivate,
    this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final double pct = controller.fillPercentage;
    final bool isBurning = controller.isBurning;
    final bool canActivate = controller.canActivate;

    final Color glowColor = isBurning
        ? const Color(0xFF00FF66)
        : canActivate
            ? const Color(0xFF00F2FE)
            : const Color(0xFF64748B);

    return GestureDetector(
      onTapDown: (_) {
        if (canActivate) {
          controller.startBoost();
          onActivate?.call();
          HapticFeedback.heavyImpact();
        }
      },
      onTapUp: (_) {
        controller.stopBoost();
        onDeactivate?.call();
      },
      onTapCancel: () {
        controller.stopBoost();
        onDeactivate?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 54.w,
        height: 54.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: isBurning
                ? [
                    const Color(0xFF00FF66).withValues(alpha: 0.95),
                    const Color(0xFF059669),
                    const Color(0xFF064E3B),
                  ]
                : canActivate
                    ? [
                        const Color(0xFF00F2FE).withValues(alpha: 0.85),
                        const Color(0xFF0284C7),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFF334155),
                        const Color(0xFF1E293B),
                      ],
          ),
          border: Border.all(
            color: isBurning ? Colors.white : glowColor,
            width: isBurning ? 2.5 : 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: isBurning ? 0.7 : 0.35),
              blurRadius: isBurning ? 18 : 8,
              spreadRadius: isBurning ? 3 : 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Circular Progress Indicator around bezel
            SizedBox(
              width: 46.w,
              height: 46.w,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 2.2.w,
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isBurning ? Colors.white : const Color(0xFF00FF66),
                ),
              ),
            ),

            // Button Icon & Label
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
                Text(
                  isBurning ? "BOOST" : "NITRO",
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 7.5.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
