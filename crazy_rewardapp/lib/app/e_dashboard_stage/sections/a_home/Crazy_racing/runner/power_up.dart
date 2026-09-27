import 'dart:math';
import 'package:flutter/material.dart';
import 'player.dart';

/// ============================================================================
/// TURBO RACER: MODULAR POWER-UP SUBSYSTEM (6 CORE POWER-UPS)
/// ============================================================================
/// 1. Shield: Protective cyan energy bubble / force field absorbing crash
/// 2. Magnet: Pulsating electromagnetic flux pulling all road coins directly
/// 3. Coin Multiplier (2X): Electric golden aura doubling coin points
/// 4. Speed Boost: Nitro rocket burst with volumetric speed lines & motion blur
/// 5. Slow Motion: Chrono-dilation slowing traffic and hazards by 50%
/// 6. Invincibility: Supercharged golden star overdrive smashing obstacles safely
/// ============================================================================

enum PowerUpType {
  shield,
  magnet,
  coinMultiplier,
  speedBoost,
  slowMotion,
  invincibility,
}

/// Power-Up Configuration Metadata
class PowerUpConfig {
  final PowerUpType type;
  final String name;
  final String shortCode;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;
  final double duration;
  final String activationText;
  final String expirationText;

  const PowerUpConfig({
    required this.type,
    required this.name,
    required this.shortCode,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
    required this.duration,
    required this.activationText,
    required this.expirationText,
  });

  // 1. SHIELD
  static const PowerUpConfig shield = PowerUpConfig(
    type: PowerUpType.shield,
    name: "Energy Shield",
    shortCode: "SHIELD",
    icon: Icons.shield_rounded,
    primaryColor: Color(0xFF38BDF8), // Cyan
    secondaryColor: Color(0xFF0284C7),
    glowColor: Color(0xFF00F2FE),
    duration: 10.0,
    activationText: "SHIELD UP! 🛡️",
    expirationText: "SHIELD EXPIRED",
  );

  // 2. MAGNET
  static const PowerUpConfig magnet = PowerUpConfig(
    type: PowerUpType.magnet,
    name: "Coin Magnet",
    shortCode: "MAGNET",
    icon: Icons.all_inclusive_rounded,
    primaryColor: Color(0xFFEF4444), // Crimson
    secondaryColor: Color(0xFFB91C1C),
    glowColor: Color(0xFFFF0055),
    duration: 8.5,
    activationText: "MAGNET ENGAGED! 🧲",
    expirationText: "MAGNET DEPLETED",
  );

  // 3. COIN MULTIPLIER (2X)
  static const PowerUpConfig coinMultiplier = PowerUpConfig(
    type: PowerUpType.coinMultiplier,
    name: "2X Multiplier",
    shortCode: "2X COIN",
    icon: Icons.bolt_rounded,
    primaryColor: Color(0xFFA855F7), // Hyper Violet
    secondaryColor: Color(0xFF7E22CE),
    glowColor: Color(0xFFFFD700),
    duration: 9.0,
    activationText: "2X SCORE BOOST! ⚡",
    expirationText: "2X MULTIPLIER ENDED",
  );

  // 4. SPEED BOOST
  static const PowerUpConfig speedBoost = PowerUpConfig(
    type: PowerUpType.speedBoost,
    name: "Nitro Boost",
    shortCode: "NITRO",
    icon: Icons.speed_rounded,
    primaryColor: Color(0xFFF97316), // Blazing Orange
    secondaryColor: Color(0xFFEA580C),
    glowColor: Color(0xFFFACC15),
    duration: 6.0,
    activationText: "NITRO BOOST! 🔥",
    expirationText: "NITRO FADING",
  );

  // 5. SLOW MOTION
  static const PowerUpConfig slowMotion = PowerUpConfig(
    type: PowerUpType.slowMotion,
    name: "Time Warp",
    shortCode: "SLOW-MO",
    icon: Icons.hourglass_bottom_rounded,
    primaryColor: Color(0xFF06B6D4), // Teal / Chrono
    secondaryColor: Color(0xFF0E7490),
    glowColor: Color(0xFF67E8F9),
    duration: 7.0,
    activationText: "SLOW MOTION! ⏳",
    expirationText: "TIME RESTORED",
  );

  // 6. INVINCIBILITY
  static const PowerUpConfig invincibility = PowerUpConfig(
    type: PowerUpType.invincibility,
    name: "Invincible Overdrive",
    shortCode: "OVERDRIVE",
    icon: Icons.star_rounded,
    primaryColor: Color(0xFFFFD700), // Pure Gold
    secondaryColor: Color(0xFFD97706),
    glowColor: Color(0xFFFFFBEB),
    duration: 6.5,
    activationText: "INVINCIBLE OVERDRIVE! ⭐",
    expirationText: "OVERDRIVE OVER",
  );

  static PowerUpConfig fromType(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        return shield;
      case PowerUpType.magnet:
        return magnet;
      case PowerUpType.coinMultiplier:
        return coinMultiplier;
      case PowerUpType.speedBoost:
        return speedBoost;
      case PowerUpType.slowMotion:
        return slowMotion;
      case PowerUpType.invincibility:
        return invincibility;
    }
  }
}

/// ============================================================================
/// POWER-UP VISUAL RENDERER (3D ON-ROAD CAPSULE ORBS & IN-GAME AURAS)
/// ============================================================================
class PowerUpVisual {
  /// Draws the 3D rotating power-up capsule orb on the track
  static void drawPowerUpOrb(
    Canvas canvas,
    PowerUpType type,
    double cx,
    double cy,
    double animTimer,
  ) {
    final cfg = PowerUpConfig.fromType(type);
    canvas.save();
    canvas.translate(cx, cy);

    // Floating bobbing animation
    final double bobOffset = sin(animTimer * 4.0) * 3.5;
    canvas.translate(0, bobOffset);

    // 1. Soft Glowing Ambient Aura
    final auraPaint = Paint()
      ..color = cfg.glowColor.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
    canvas.drawCircle(Offset.zero, 20.0, auraPaint);

    // 2. Rotating Outer Plasma Ring
    final ringPaint = Paint()
      ..color = cfg.primaryColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double ringRot = animTimer * 2.5;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: 21.0),
      ringRot,
      4.2,
      false,
      ringPaint,
    );

    // 3. Metallic Sphere Base Orb
    final orbRect = Rect.fromCircle(center: Offset.zero, radius: 17.0);
    final orbPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          cfg.primaryColor,
          cfg.secondaryColor,
          const Color(0xFF0F172A),
        ],
        stops: const [0.0, 0.3, 0.75, 1.0],
      ).createShader(orbRect);

    canvas.drawCircle(Offset.zero, 16.5, orbPaint);

    // 4. Stamped Emblem Icon
    _drawEmblem(canvas, type, animTimer);

    // 5. Specular Glint Highlight
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawOval(
      const Rect.fromLTWH(-10, -12, 10, 5),
      shinePaint,
    );

    canvas.restore();
  }

  static void _drawEmblem(Canvas canvas, PowerUpType type, double animTimer) {
    final whitePaint = Paint()..color = Colors.white;

    switch (type) {
      // 1. Shield Emblem
      case PowerUpType.shield:
        final Path sPath = Path()
          ..moveTo(0, -7.5)
          ..lineTo(6.5, -3.5)
          ..lineTo(4.5, 5.5)
          ..lineTo(0, 8.5)
          ..lineTo(-4.5, 5.5)
          ..lineTo(-6.5, -3.5)
          ..close();
        canvas.drawPath(sPath, whitePaint);
        break;

      // 2. Magnet Horseshoe
      case PowerUpType.magnet:
        final mPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.square;

        final Path mPath = Path()
          ..moveTo(-5.5, -5.5)
          ..lineTo(-5.5, 2.0)
          ..arcToPoint(const Offset(5.5, 2.0), radius: const Radius.circular(5.5))
          ..lineTo(5.5, -5.5);
        canvas.drawPath(mPath, mPaint);
        break;

      // 3. 2X Multiplier Lightning Bolt
      case PowerUpType.coinMultiplier:
        final Path bPath = Path()
          ..moveTo(1.0, -8.0)
          ..lineTo(-5.0, 0.5)
          ..lineTo(-0.5, 0.5)
          ..lineTo(-2.0, 8.0)
          ..lineTo(5.0, -0.5)
          ..lineTo(0.5, -0.5)
          ..close();
        canvas.drawPath(bPath, whitePaint);
        break;

      // 4. Speed Boost Nitro Flame
      case PowerUpType.speedBoost:
        final Path fPath = Path()
          ..moveTo(0, -8.5)
          ..cubicTo(5.5, -3.0, 6.0, 4.0, 2.5, 7.5)
          ..cubicTo(0.0, 8.5, -2.5, 8.0, -4.5, 6.0)
          ..cubicTo(-6.5, 3.0, -5.0, -2.0, 0, -8.5)
          ..close();
        canvas.drawPath(fPath, whitePaint);
        break;

      // 5. Slow Motion Hourglass
      case PowerUpType.slowMotion:
        final Path hPath = Path()
          ..moveTo(-6.0, -7.0)
          ..lineTo(6.0, -7.0)
          ..lineTo(0.0, 0.0)
          ..lineTo(6.0, 7.0)
          ..lineTo(-6.0, 7.0)
          ..lineTo(0.0, 0.0)
          ..close();
        canvas.drawPath(hPath, whitePaint);
        break;

      // 6. Invincibility Star
      case PowerUpType.invincibility:
        final Path star = Path();
        const int pts = 5;
        for (int i = 0; i < pts * 2; i++) {
          final double r = (i % 2 == 0) ? 7.5 : 3.5;
          final double a = i * pi / pts - pi / 2;
          final double x = cos(a) * r;
          final double y = sin(a) * r;
          if (i == 0) {
            star.moveTo(x, y);
          } else {
            star.lineTo(x, y);
          }
        }
        star.close();
        canvas.drawPath(star, whitePaint);
        break;
    }
  }

  // --------------------------------------------------------------------------
  // ACTIVE IN-GAME PLAYER AURAS
  // --------------------------------------------------------------------------

  /// 1. Cyan Forcefield Bubble (Shield)
  static void drawShieldAura(Canvas canvas, Player player) {
    final double pulse = 48.0 + sin(player.runCycle * 4 * pi) * 1.5;

    // Outer Glow Dome
    final glow = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
    canvas.drawCircle(const Offset(0, -6), pulse, glow);

    // Hexagonal / Orbiting Forcefield Rings
    final ring = Paint()
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawCircle(const Offset(0, -6), pulse, ring);

    // Orbiting Plasma Node
    final double nodeAngle = player.runCycle * 3 * pi;
    final nodeOffset = Offset(
      cos(nodeAngle) * pulse,
      -6.0 + sin(nodeAngle) * pulse,
    );
    canvas.drawCircle(nodeOffset, 3.5, Paint()..color = Colors.white);
  }

  /// 2. Crimson Pulsing Magnetic Flux Waves (Magnet)
  static void drawMagnetAura(Canvas canvas, Player player) {
    final double pulse = 44.0 + sin(player.runCycle * 6 * pi) * 4.0;
    final ringPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(const Offset(0, -6), pulse, ringPaint);
    canvas.drawCircle(
      const Offset(0, -6),
      pulse + 8.0,
      Paint()
        ..color = const Color(0xFFF87171).withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  /// 3. Golden Electric Lightning Sparks (2X Multiplier)
  static void drawMultiplierAura(Canvas canvas, Player player) {
    final double pulse = 46.0 + cos(player.runCycle * 4 * pi) * 3.5;
    final goldGlow = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(const Offset(0, -6), pulse, goldGlow);

    // Crackling Lightning Arcs
    final sparkPaint = Paint()
      ..color = const Color(0xFFFFF9C4)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final double phase = player.runCycle * 10 * pi;
    final Path lightning = Path()
      ..moveTo(cos(phase) * 35, -6 + sin(phase) * 35)
      ..lineTo(cos(phase + 0.5) * 45, -6 + sin(phase + 0.5) * 45)
      ..lineTo(cos(phase + 1.0) * 40, -6 + sin(phase + 1.0) * 40);
    canvas.drawPath(lightning, sparkPaint);
  }

  /// 4. Volumetric Speed Lines & Motion Blur (Speed Boost)
  static void drawSpeedBoostAura(Canvas canvas, Player player, Size size) {
    final Random rnd = Random();

    // Rushing Forward Nitro Lines
    final speedLinePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Color(0xFFF97316),
          Color(0xFFFDE047),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(-60, -120, 120, 240))
      ..strokeWidth = 2.2;

    for (int i = 0; i < 8; i++) {
      final double lx = (rnd.nextDouble() - 0.5) * 70.0;
      final double ly = -70.0 + rnd.nextDouble() * 140.0;
      final double len = 35.0 + rnd.nextDouble() * 45.0;
      canvas.drawLine(Offset(lx, ly), Offset(lx, ly + len), speedLinePaint);
    }
  }

  /// 5. Chrono-Warp Time Dilation Ring (Slow Motion)
  static void drawSlowMotionAura(Canvas canvas, Player player) {
    final double radius = 50.0 + sin(player.runCycle * 2 * pi) * 6.0;
    final chronoPaint = Paint()
      ..color = const Color(0xFF06B6D4).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawCircle(const Offset(0, -6), radius, chronoPaint);
  }

  /// 6. Shimmering Rainbow / Golden Overdrive Halo (Invincibility)
  static void drawInvincibilityAura(Canvas canvas, Player player) {
    final double radius = 52.0;
    final double rot = player.runCycle * 4 * pi;

    final haloPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0xFFFF0055),
          Color(0xFFFFD700),
          Color(0xFF00F2FE),
          Color(0xFFA855F7),
          Color(0xFFFF0055),
        ],
        transform: GradientRotation(rot),
      ).createShader(Rect.fromCircle(center: const Offset(0, -6), radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawCircle(const Offset(0, -6), radius, haloPaint);
  }
}
