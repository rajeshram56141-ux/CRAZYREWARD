import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// ============================================================================
/// TURBO RACER: MODULAR PLAYER SPORTS CAR SYSTEM
/// ============================================================================
/// High-performance, modular 3D/cartoon sports racing car for Flutter mobile.
/// Supports 7 animation states, dynamic banking roll tilt, wheel rim rotation,
/// suspension bounce, volumetric headlights, front honeycomb grille, side mirrors,
/// rear GT spoiler, shiny metallic reflections, and optional sprite asset replacement.
/// ============================================================================

/// 7 Core Gameplay & Visual Animation States
enum CarAnimationState {
  idle,
  driving,
  laneChangeLeft,
  laneChangeRight,
  braking,
  collision,
  destroyed,
}

/// Customizable Theme / Paint Palette for Modular Player Car
class PlayerCarTheme {
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color stripeColor;
  final Color rimColor;
  final Color neonGlowColor;
  final Color glassColor;

  const PlayerCarTheme({
    this.name = "Red GT",
    this.primaryColor = const Color(0xFFEF4444), // Vibrant Racing Red (Hero)
    this.secondaryColor = const Color(0xFFB91C1C), // Deep Crimson Shadow
    this.accentColor = const Color(0xFFF87171), // Bright Highlight
    this.stripeColor = Colors.white, // Dual White Racing Stripes
    this.rimColor = const Color(0xFF1E293B), // Sport Dark Rims
    this.neonGlowColor = const Color(0xFFFF0055), // Red / Magenta Underglow
    this.glassColor = const Color(0xFF0F172A), // Dark Tinted Glass
  });

  /// 1. Hero Red Racing Theme (Matches Reference Sheet)
  static const PlayerCarTheme red = PlayerCarTheme(
    name: "Red",
    primaryColor: Color(0xFFEF4444),
    secondaryColor: Color(0xFFB91C1C),
    accentColor: Color(0xFFF87171),
    stripeColor: Colors.white,
    rimColor: Color(0xFF1E293B),
    neonGlowColor: Color(0xFFFF0055),
    glassColor: Color(0xFF0F172A),
  );

  /// 2. Blue Racing Theme
  static const PlayerCarTheme blue = PlayerCarTheme(
    name: "Blue",
    primaryColor: Color(0xFF2563EB),
    secondaryColor: Color(0xFF1E40AF),
    accentColor: Color(0xFF60A5FA),
    stripeColor: Colors.white,
    rimColor: Color(0xFF1E293B),
    neonGlowColor: Color(0xFF00F2FE),
    glassColor: Color(0xFF0F172A),
  );

  /// 3. Yellow Hypercar Theme
  static const PlayerCarTheme yellow = PlayerCarTheme(
    name: "Yellow",
    primaryColor: Color(0xFFEAB308),
    secondaryColor: Color(0xFFA16207),
    accentColor: Color(0xFFFDE047),
    stripeColor: Colors.white,
    rimColor: Color(0xFF1E293B),
    neonGlowColor: Color(0xFFFFD700),
    glassColor: Color(0xFF090D16),
  );

  /// 4. Green Track Edition Theme
  static const PlayerCarTheme green = PlayerCarTheme(
    name: "Green",
    primaryColor: Color(0xFF22C55E),
    secondaryColor: Color(0xFF15803D),
    accentColor: Color(0xFF4ADE80),
    stripeColor: Colors.white,
    rimColor: Color(0xFF1E293B),
    neonGlowColor: Color(0xFF10B981),
    glassColor: Color(0xFF0F172A),
  );

  /// 5. Purple Hypercar Theme
  static const PlayerCarTheme purple = PlayerCarTheme(
    name: "Purple",
    primaryColor: Color(0xFFA855F7),
    secondaryColor: Color(0xFF7E22CE),
    accentColor: Color(0xFFC084FC),
    stripeColor: Colors.white,
    rimColor: Color(0xFF1E293B),
    neonGlowColor: Color(0xFFD946EF),
    glassColor: Color(0xFF0F172A),
  );

  // Aliases for backwards compatibility
  static const PlayerCarTheme crimsonGT = red;
  static const PlayerCarTheme cyberBlue = blue;
  static const PlayerCarTheme solarGold = yellow;

  static const List<PlayerCarTheme> allThemes = [
    red,
    blue,
    yellow,
    green,
    purple,
  ];
}

/// Rendering parameters passed into the modular car renderer on each frame
class CarRenderParams {
  final CarAnimationState state;
  final double speed; // Current speed (determines wheel rotation & flame length)
  final double laneTilt; // Dynamic banking roll angle in radians (-0.25 to +0.25)
  final double steerAngle; // Front wheel steer angle in radians
  final double suspensionBounce; // Vertical oscillation offset in pixels
  final double wheelRotation; // 0.0 to 2*pi rotation cycle
  final double hitFlashProgress; // 0.0 to 1.0 hit flash opacity
  final double jumpElevation; // 0.0 to 1.0 jump height ratio
  final bool isShieldActive;
  final bool isMagnetActive;
  final bool isMultiplierActive;
  final double nitroIntensity;
  final bool isNitroActive;
  final double crashSpinAngle;
  final double crashShakeX;
  final double crashShakeY;
  final PlayerCarTheme theme;
  final ui.Image? customSpriteImage; // Optional 2D/3D sprite override

  const CarRenderParams({
    this.state = CarAnimationState.driving,
    this.speed = 100.0,
    this.laneTilt = 0.0,
    this.steerAngle = 0.0,
    this.suspensionBounce = 0.0,
    this.wheelRotation = 0.0,
    this.hitFlashProgress = 0.0,
    this.jumpElevation = 0.0,
    this.isShieldActive = false,
    this.isMagnetActive = false,
    this.isMultiplierActive = false,
    this.nitroIntensity = 0.0,
    this.isNitroActive = false,
    this.crashSpinAngle = 0.0,
    this.crashShakeX = 0.0,
    this.crashShakeY = 0.0,
    this.theme = PlayerCarTheme.cyberBlue,
    this.customSpriteImage,
  });
}

/// ============================================================================
/// MODULAR CAR PAINTER / RENDERER (60 FPS HARDWARE ACCELERATED)
/// ============================================================================
class PlayerCarVisual {
  /// Main modular draw entry point for [CrazyRunnerPainter] or [PlayerCarWidget]
  static void drawCar(Canvas canvas, Size size, CarRenderParams params) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    canvas.save();
    canvas.translate(cx, cy);

    // 1. Dynamic Contact Ground Shadow (Adapts to roll tilt, jump, & suspension)
    _drawGroundShadow(canvas, params);

    // 2. Headlight Volumetric Forward Cones
    _drawVolumetricHeadlightBeams(canvas, params);

    // 3. Apply Vehicle Dynamics (Suspension Bounce, Banking Roll Tilt, Jump Scale, Crash Spin & Shudder)
    final double rollTilt = params.laneTilt;
    final double verticalBounce = params.suspensionBounce;
    final double jumpScale = 1.0 + params.jumpElevation * 0.12;

    canvas.translate(params.crashShakeX, verticalBounce + params.crashShakeY);
    canvas.rotate(rollTilt + params.crashSpinAngle);
    canvas.scale(jumpScale, jumpScale);

    // Collision Shudder Offset (Subtle & strictly gated by active hit flash)
    if (params.state == CarAnimationState.collision && params.hitFlashProgress > 0) {
      final double shudderIntensity = params.hitFlashProgress.clamp(0.0, 1.0);
      final double shudderX = (sin(params.wheelRotation * 6) * 1.5 * shudderIntensity);
      final double shudderY = (cos(params.wheelRotation * 6) * 1.0 * shudderIntensity);
      canvas.translate(shudderX, shudderY);
    }

    // 4. Check if a custom 2D/3D Sprite Asset is provided
    if (params.customSpriteImage != null) {
      _drawCustomSprite(canvas, params);
    } else {
      // 5. Render High-Performance 3D/Cartoon Vector Sports Car
      _drawVectorSportsCar(canvas, params);
    }

    // 6. Draw State FX Overlays (Nitro Exhausts, Brake Hazards, Sparks, Smoke)
    _drawStateEffects(canvas, params);

    canvas.restore();
  }

  // --------------------------------------------------------------------------
  // 1. DYNAMIC GROUND SHADOW
  // --------------------------------------------------------------------------
  static void _drawGroundShadow(Canvas canvas, CarRenderParams params) {
    final double elevationScale = (1.0 - params.jumpElevation * 0.45).clamp(0.4, 1.0);
    final double shadowWidth = 62.0 * elevationScale;
    final double shadowHeight = 84.0 * elevationScale;
    final double shadowOffsetY = 6.0 + params.jumpElevation * 32.0;

    // Outer soft ambient shadow
    final softShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38 * elevationScale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(params.laneTilt * 12.0, shadowOffsetY),
        width: shadowWidth * 1.15,
        height: shadowHeight * 1.05,
      ),
      softShadowPaint,
    );

    // Sharp contact patch shadow directly under chassis
    final hardShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55 * elevationScale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(params.laneTilt * 6.0, shadowOffsetY),
          width: shadowWidth * 0.82,
          height: shadowHeight * 0.88,
        ),
        const Radius.circular(16.0),
      ),
      hardShadowPaint,
    );

    // Neon Underglow Aura
    final underglowPaint = Paint()
      ..color = params.theme.neonGlowColor.withValues(alpha: 0.28 * elevationScale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, shadowOffsetY - 2.0),
        width: shadowWidth * 0.95,
        height: shadowHeight * 0.95,
      ),
      underglowPaint,
    );
  }

  // --------------------------------------------------------------------------
  // 2. VOLUMETRIC FORWARD HEADLIGHT BEAMS
  // --------------------------------------------------------------------------
  static void _drawVolumetricHeadlightBeams(Canvas canvas, CarRenderParams params) {
    if (params.state == CarAnimationState.destroyed) return;

    final double beamLength = (params.state == CarAnimationState.idle) ? 70.0 : 130.0;
    final double beamSpread = 34.0;
    final double alpha = (params.state == CarAnimationState.idle) ? 0.18 : 0.32;

    void drawSingleBeam(double startX, double angleOffset) {
      final beamPath = Path()
        ..moveTo(startX - 6, -34)
        ..lineTo(startX - beamSpread + angleOffset, -34 - beamLength)
        ..lineTo(startX + beamSpread + angleOffset, -34 - beamLength)
        ..lineTo(startX + 6, -34)
        ..close();

      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFE0F2FE).withValues(alpha: alpha),
            const Color(0xFF38BDF8).withValues(alpha: alpha * 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(startX - beamSpread, -34 - beamLength, beamSpread * 2, beamLength));

      canvas.drawPath(beamPath, beamPaint);
    }

    final double steerBias = params.steerAngle * 40.0;
    drawSingleBeam(-16.0, steerBias);
    drawSingleBeam(16.0, steerBias);
  }

  // --------------------------------------------------------------------------
  // 3. VECTOR SPORTS CAR MODEL (DETAILED 3D/CARTOON ART)
  // --------------------------------------------------------------------------
  static void _drawVectorSportsCar(Canvas canvas, CarRenderParams params) {
    final bool isFlashing = params.hitFlashProgress > 0 &&
        ((params.hitFlashProgress * 15).floor() % 2 == 0);

    final Color bodyColor = isFlashing
        ? const Color(0xFFFF4D4D)
        : params.theme.primaryColor;
    final Color highlightColor = isFlashing
        ? const Color(0xFFFFCDD2)
        : params.theme.accentColor;
    final Color shadeColor = isFlashing
        ? const Color(0xFF991B1B)
        : params.theme.secondaryColor;

    // A. 4 Wide Tires & Rotating Alloy Wheels
    _drawAllWheels(canvas, params);

    // B. Aerodynamic Carbon Underbody Splitter & Side Skirts
    _drawAeroSplitterAndSkirts(canvas, params);

    // C. Main Low Aerodynamic Sculpted Body Shell
    _drawMainChassisBody(canvas, params, bodyColor, highlightColor, shadeColor);

    // D. Front Honeycomb Grille & Air Intakes
    _drawFrontGrille(canvas, params);

    // E. Dual Aerodynamic Side Wing Mirrors
    _drawSideMirrors(canvas, params, bodyColor, highlightColor);

    // F. Dual Racing Stripes & Aerodynamic Hood Vents
    _drawRacingStripesAndHoodVents(canvas, params);

    // G. Polycarbonate Cockpit Windshield & Glass Canopy with Specular Glare
    _drawCockpitWindshield(canvas, params);

    // H. Front Projector Headlights & LED DRL Eyebrows
    _drawHeadlightUnits(canvas, params);

    // I. Rear LED Taillight Bar & Diffuser
    _drawRearTaillights(canvas, params);

    // J. High-Downforce Carbon Rear GT Wing Spoiler
    _drawGTSpoiler(canvas, params, bodyColor);
  }

  // --------------------------------------------------------------------------
  // A. WIDE TIRES & ROTATING ALLOY WHEELS
  // --------------------------------------------------------------------------
  static void _drawAllWheels(Canvas canvas, CarRenderParams params) {
    // 4 Wheel Locations: Front-Left, Front-Right, Rear-Left, Rear-Right
    final List<_WheelData> wheels = [
      _WheelData(x: -25.0, y: -19.0, isFront: true),
      _WheelData(x: 25.0, y: -19.0, isFront: true),
      _WheelData(x: -26.0, y: 19.0, isFront: false),
      _WheelData(x: 26.0, y: 19.0, isFront: false),
    ];

    for (final w in wheels) {
      canvas.save();
      canvas.translate(w.x, w.y);

      // Steer front wheels when changing lanes
      if (w.isFront) {
        canvas.rotate(params.steerAngle);
      }

      // Tire Rubber Profile (Matte High-Performance Racing Slick)
      final double tireWidth = w.isFront ? 9.5 : 11.0;
      final double tireHeight = w.isFront ? 24.0 : 26.0;

      final tireRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: tireWidth, height: tireHeight),
        const Radius.circular(4.5),
      );

      final tirePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF0B0F19), Color(0xFF1E293B), Color(0xFF090D16)],
        ).createShader(Rect.fromLTWH(-tireWidth / 2, -tireHeight / 2, tireWidth, tireHeight));

      canvas.drawRRect(tireRect, tirePaint);

      // Inner Wheel-Well Shadow
      final bool isLeftSide = w.x < 0;
      final double innerX = isLeftSide ? tireWidth / 2 - 1.5 : -tireWidth / 2 + 1.5;
      canvas.drawLine(
        Offset(innerX, -tireHeight / 2 + 2),
        Offset(innerX, tireHeight / 2 - 2),
        Paint()
          ..color = const Color(0xFF020617)
          ..strokeWidth = 2.0,
      );

      // Tread Grooves (Clean dark racing grip lines)
      final treadPaint = Paint()
        ..color = const Color(0xFF050811)
        ..strokeWidth = 1.3;
      for (double ty = -8.0; ty <= 8.0; ty += 5.0) {
        final double animTy = ((ty + params.wheelRotation * 6.0) % 18.0) - 9.0;
        canvas.drawLine(Offset(-tireWidth / 2 + 1.5, animTy), Offset(tireWidth / 2 - 1.5, animTy), treadPaint);
      }

      // Sleek Outer Rim Edge Accent (Flush with sidewall, no floating white circles)
      final double outerX = isLeftSide ? -tireWidth / 2 + 1.0 : tireWidth / 2 - 1.0;
      final rimAccentPaint = Paint()
        ..color = params.theme.rimColor.withValues(alpha: 0.75)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      final double animShift = ((params.wheelRotation * 6.0) % 10.0) - 5.0;
      canvas.drawLine(
        Offset(outerX, animShift - 3.5),
        Offset(outerX, animShift + 3.5),
        rimAccentPaint,
      );

      canvas.restore();
    }
  }

  // --------------------------------------------------------------------------
  // B. UNDERBODY SPLITTER & SIDE SKIRTS
  // --------------------------------------------------------------------------
  static void _drawAeroSplitterAndSkirts(Canvas canvas, CarRenderParams params) {
    // Carbon Fiber Splitter Extension
    final Path splitterPath = Path()
      ..moveTo(-20, -38)
      ..lineTo(20, -38)
      ..lineTo(24, -34)
      ..lineTo(-24, -34)
      ..close();

    final splitterPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawPath(splitterPath, splitterPaint);

    // Neon Accent Lip on Front Splitter
    final lipPaint = Paint()
      ..color = params.theme.neonGlowColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-18, -38), const Offset(18, -38), lipPaint);
  }

  // --------------------------------------------------------------------------
  // C. MAIN CHASSIS AERODYNAMIC BODY SHELL
  // --------------------------------------------------------------------------
  static void _drawMainChassisBody(
    Canvas canvas,
    CarRenderParams params,
    Color bodyColor,
    Color highlightColor,
    Color shadeColor,
  ) {
    // Sculpted Widebody Silhouette
    final Path bodyPath = Path()
      ..moveTo(0, -38) // Front Nose Center
      ..cubicTo(14, -38, 21, -33, 22, -26) // Front Right Corner
      ..lineTo(21, -11) // Front Wheel Arch Inset
      ..cubicTo(24, 0, 25, 12, 26, 26) // Muscular Rear Fender Right
      ..lineTo(23, 34) // Rear Bumper Right
      ..lineTo(14, 35) // Rear Diffuser Edge Right
      ..lineTo(-14, 35) // Rear Diffuser Edge Left
      ..lineTo(-23, 34) // Rear Bumper Left
      ..cubicTo(-25, 12, -24, 0, -21, -11) // Muscular Rear Fender Left
      ..lineTo(-22, -26) // Front Wheel Arch Inset
      ..cubicTo(-21, -33, -14, -38, 0, -38) // Front Left Corner
      ..close();

    // High-Gloss Metallic 3D Curvature Shader
    final bodyShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        highlightColor,
        bodyColor,
        shadeColor,
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(const Rect.fromLTWH(-26, -38, 52, 74));

    canvas.drawPath(bodyPath, Paint()..shader = bodyShader);

    // Specular Highlight Stroke on Outer Edges
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(bodyPath, edgePaint);

    // Sculpted Door Air Intake Creases
    final intakePaint = Paint()
      ..color = const Color(0xFF090D16).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Right Side Intake
    final rightIntake = Path()
      ..moveTo(17, 3)
      ..lineTo(21, 6)
      ..lineTo(20, 18)
      ..lineTo(16, 15)
      ..close();
    canvas.drawPath(rightIntake, intakePaint);

    // Left Side Intake
    final leftIntake = Path()
      ..moveTo(-17, 3)
      ..lineTo(-21, 6)
      ..lineTo(-20, 18)
      ..lineTo(-16, 15)
      ..close();
    canvas.drawPath(leftIntake, intakePaint);
  }

  // --------------------------------------------------------------------------
  // D. FRONT HONEYCOMB GRILLE & AIR INTAKES
  // --------------------------------------------------------------------------
  static void _drawFrontGrille(Canvas canvas, CarRenderParams params) {
    // Honeycomb Lower Grille Cavity
    final grilleRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-11, -37, 22, 6.5),
      const Radius.circular(3.0),
    );

    canvas.drawRRect(grilleRect, Paint()..color = const Color(0xFF090D16));

    // Honeycomb Mesh Lattice Lines
    final meshPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 0.8;

    for (double gx = -9.0; gx <= 9.0; gx += 3.0) {
      canvas.drawLine(Offset(gx, -37), Offset(gx + 1.5, -30.5), meshPaint);
      canvas.drawLine(Offset(gx + 1.5, -37), Offset(gx, -30.5), meshPaint);
    }

    // Chrome/Gold Emblem Badge on Grille Center
    final badgePaint = Paint()..color = const Color(0xFFFFD700);
    final badgePath = Path()
      ..moveTo(0, -36.5)
      ..lineTo(2.2, -34.5)
      ..lineTo(0, -32.5)
      ..lineTo(-2.2, -34.5)
      ..close();
    canvas.drawPath(badgePath, badgePaint);
  }

  // --------------------------------------------------------------------------
  // E. DUAL SIDE MIRRORS
  // --------------------------------------------------------------------------
  static void _drawSideMirrors(
    Canvas canvas,
    CarRenderParams params,
    Color bodyColor,
    Color highlightColor,
  ) {
    void drawMirror(double mx, bool isLeft) {
      canvas.save();
      canvas.translate(mx, -11.0);

      // Mirror Arm
      final armPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset.zero, Offset(isLeft ? -4.5 : 4.5, -2.5), armPaint);

      // Aerodynamic Mirror Shell Housing
      final mirrorHousing = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(isLeft ? -5.5 : 5.5, -2.5),
          width: 5.5,
          height: 8.5,
        ),
        const Radius.circular(2.5),
      );

      canvas.drawRRect(mirrorHousing, Paint()..color = bodyColor);
      canvas.drawRRect(
        mirrorHousing,
        Paint()
          ..color = highlightColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      // Glass Reflective Mirror Surface
      final glassRect = Rect.fromLTWH(
        isLeft ? -7.0 : 4.0,
        -5.0,
        1.6,
        5.5,
      );
      canvas.drawRect(glassRect, Paint()..color = const Color(0xFF38BDF8));

      canvas.restore();
    }

    drawMirror(-17.0, true);
    drawMirror(17.0, false);
  }

  // --------------------------------------------------------------------------
  // F. DUAL RACING STRIPES & HOOD VENTS
  // --------------------------------------------------------------------------
  static void _drawRacingStripesAndHoodVents(Canvas canvas, CarRenderParams params) {
    // Dual Racing Stripes running down the hood and roof
    final stripePaint = Paint()
      ..color = params.theme.stripeColor.withValues(alpha: 0.92);

    // Left Stripe
    canvas.drawRect(const Rect.fromLTWH(-4.8, -36, 3.4, 20), stripePaint);
    // Right Stripe
    canvas.drawRect(const Rect.fromLTWH(1.4, -36, 3.4, 20), stripePaint);

    // Rear Deck Stripes
    canvas.drawRect(const Rect.fromLTWH(-4.8, 14, 3.4, 18), stripePaint);
    canvas.drawRect(const Rect.fromLTWH(1.4, 14, 3.4, 18), stripePaint);

    // Twin Carbon Hood Heat Extractor Vents
    final ventPaint = Paint()..color = const Color(0xFF090D16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-11.5, -27, 4.0, 7.0), const Radius.circular(1.5)),
      ventPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(7.5, -27, 4.0, 7.0), const Radius.circular(1.5)),
      ventPaint,
    );
  }

  // --------------------------------------------------------------------------
  // G. POLYCARBONATE COCKPIT WINDSHIELD & GLASS CANOPY
  // --------------------------------------------------------------------------
  static void _drawCockpitWindshield(Canvas canvas, CarRenderParams params) {
    // Teardrop Cockpit Glass Frame
    final Path glassPath = Path()
      ..moveTo(0, -16) // Front Windshield Top Center
      ..cubicTo(11, -16, 14, -8, 15, 6) // Right Canopy Edge
      ..lineTo(14, 13) // Rear Window Right
      ..lineTo(-14, 13) // Rear Window Left
      ..lineTo(-15, 6) // Left Canopy Edge
      ..cubicTo(-14, -8, -11, -16, 0, -16) // Front Windshield Top Left
      ..close();

    final glassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0284C7),
          Color(0xFF0F172A),
          Color(0xFF020617),
        ],
        stops: [0.0, 0.4, 1.0],
      ).createShader(const Rect.fromLTWH(-15, -16, 30, 29));

    canvas.drawPath(glassPath, glassPaint);

    // Dynamic White Glare Reflection Stripe across Windshield
    final Path glarePath = Path()
      ..moveTo(-11, -14)
      ..lineTo(-2, -14)
      ..lineTo(5, 10)
      ..lineTo(-4, 10)
      ..close();

    final glarePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawPath(glarePath, glarePaint);

    // Collision Windshield Spiderweb Cracks (Animation State 6: Collision)
    if (params.state == CarAnimationState.collision || (params.hitFlashProgress > 0 && params.state != CarAnimationState.destroyed)) {
      final crackPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final crackPath = Path()
        ..moveTo(-4, -4)
        ..lineTo(-10, -11)
        ..moveTo(-4, -4)
        ..lineTo(4, -12)
        ..moveTo(-4, -4)
        ..lineTo(-2, 6)
        ..moveTo(-4, -4)
        ..lineTo(8, -1)
        ..moveTo(-10, -11)
        ..lineTo(-13, -8)
        ..moveTo(4, -12)
        ..lineTo(7, -14);
      canvas.drawPath(crackPath, crackPaint);
    }

    // Black Roof Rib Center Panel
    final roofPanel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -5, 20, 14),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(roofPanel, Paint()..color = const Color(0xFF090D16));
  }

  // --------------------------------------------------------------------------
  // H. FRONT PROJECTOR HEADLIGHTS & LED DRLs
  // --------------------------------------------------------------------------
  static void _drawHeadlightUnits(Canvas canvas, CarRenderParams params) {
    final bool isDestroyed = params.state == CarAnimationState.destroyed;
    final lightAuraPaint = Paint()
      ..color = isDestroyed
          ? Colors.transparent
          : const Color(0xFF00F2FE).withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final lensCorePaint = Paint()
      ..color = isDestroyed ? const Color(0xFF334155) : const Color(0xFFFFFFFF);

    void drawHeadlight(double hx) {
      // Angular Aggressive Headlight Housing
      final Path housingPath = Path()
        ..moveTo(hx - 5, -34)
        ..lineTo(hx + 5, -31)
        ..lineTo(hx + 3, -27)
        ..lineTo(hx - 4, -29)
        ..close();

      canvas.drawPath(housingPath, Paint()..color = const Color(0xFF090D16));

      // Projector Lens Glow
      if (!isDestroyed) {
        canvas.drawCircle(Offset(hx, -31.5), 3.8, lightAuraPaint);
        canvas.drawCircle(Offset(hx, -31.5), 2.2, lensCorePaint);
      }

      // Continuous Daytime Running Light (DRL) Brow
      final drlPaint = Paint()
        ..color = isDestroyed ? const Color(0xFF475569) : const Color(0xFF00F2FE)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(hx - 4.5, -34.5), Offset(hx + 4.5, -31.5), drlPaint);
    }

    drawHeadlight(-14.0);
    drawHeadlight(14.0);
  }

  // --------------------------------------------------------------------------
  // I. REAR TAILLIGHTS, DIFFUSER & QUAD ROUND EXHAUST TIPS
  // --------------------------------------------------------------------------
  static void _drawRearTaillights(Canvas canvas, CarRenderParams params) {
    final bool isBraking = params.state == CarAnimationState.braking;

    // Full-Width Continuous Cyber LED Lightbar
    final taillightRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-20, 31, 40, 4.5),
      const Radius.circular(2.0),
    );

    // Glowing Neon Bloom
    final bloomPaint = Paint()
      ..color = (isBraking ? const Color(0xFFFF0055) : const Color(0xFFEF4444))
          .withValues(alpha: isBraking ? 0.95 : 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isBraking ? 8.0 : 4.0);

    canvas.drawRRect(taillightRect, bloomPaint);

    // Solid Lightbar
    canvas.drawRRect(
      taillightRect,
      Paint()..color = isBraking ? const Color(0xFFFF1744) : const Color(0xFFDC2626),
    );

    // Center Hot White/Amber Brake Glow
    if (isBraking) {
      final innerBrakeRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, 32, 28, 2.5),
        const Radius.circular(1.0),
      );
      canvas.drawRRect(innerBrakeRect, Paint()..color = const Color(0xFFFFF9C4));
    }

    // Quad Round Chrome Exhaust Tips (Matching Multi-Angle Rear View)
    final exhaustTipPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final exhaustCorePaint = Paint()..color = const Color(0xFF0F172A);

    for (final ex in [-14.0, -9.0, 9.0, 14.0]) {
      canvas.drawCircle(Offset(ex, 35.5), 2.4, exhaustCorePaint);
      canvas.drawCircle(Offset(ex, 35.5), 2.4, exhaustTipPaint);
    }
  }

  // --------------------------------------------------------------------------
  // J. HIGH-DOWNFORCE CARBON REAR GT SPOILER
  // --------------------------------------------------------------------------
  static void _drawGTSpoiler(Canvas canvas, CarRenderParams params, Color bodyColor) {
    // Twin Upright Struts
    final strutPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(-14, 25), const Offset(-14, 37), strutPaint);
    canvas.drawLine(const Offset(14, 25), const Offset(14, 37), strutPaint);

    // Aerodynamic Wing Blade
    final wingRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-25, 36, 50, 5.5),
      const Radius.circular(2.5),
    );

    final wingPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          params.theme.accentColor,
          const Color(0xFF0F172A),
          params.theme.accentColor,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(const Rect.fromLTWH(-25, 36, 50, 5.5));

    canvas.drawRRect(wingRect, wingPaint);

    // Vertical Aero Endplates
    final endplatePaint = Paint()..color = params.theme.accentColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-26, 33, 2.5, 9.5), const Radius.circular(1.2)),
      endplatePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(23.5, 33, 2.5, 9.5), const Radius.circular(1.2)),
      endplatePaint,
    );
  }

  // --------------------------------------------------------------------------
  // 4. CUSTOM SPRITE IMAGE RENDERING (FOR PNG/WEBP ASSET REPLACEMENT)
  // --------------------------------------------------------------------------
  static void _drawCustomSprite(Canvas canvas, CarRenderParams params) {
    final image = params.customSpriteImage!;
    const double targetWidth = 54.0;
    const double targetHeight = 80.0;

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromCenter(center: Offset.zero, width: targetWidth, height: targetHeight);

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    if (params.hitFlashProgress > 0 && ((params.hitFlashProgress * 15).floor() % 2 == 0)) {
      paint.colorFilter = const ColorFilter.mode(Color(0xFFFF4D4D), BlendMode.srcATop);
    }

    canvas.drawImageRect(image, srcRect, dstRect, paint);
  }

  // --------------------------------------------------------------------------
  // 6. STATE FX OVERLAYS (EXHAUST FLAMES, BRAKE SMOKE, CRASH SPARKS)
  // --------------------------------------------------------------------------
  static void _drawStateEffects(Canvas canvas, CarRenderParams params) {
    // A. Driving / Nitro Exhaust Flames (Quad Exhaust Jet Plumes)
    if (params.state == CarAnimationState.driving ||
        params.state == CarAnimationState.laneChangeLeft ||
        params.state == CarAnimationState.laneChangeRight) {
      final double nitro = params.nitroIntensity;
      final double flameFlicker = (sin(params.wheelRotation * (16 + nitro * 12)) * (4.0 + nitro * 6.0)).abs();
      final double flameLength = 14.0 + flameFlicker + (params.speed * 0.035) + (nitro * 32.0);
      final double flameWidth = 2.8 + nitro * 2.2;

      void drawExhaustFlame(double ox, int idx) {
        final double lengthBonus = (idx == 1 || idx == 2) ? nitro * 8.0 : 0.0;
        final double totalLength = flameLength + lengthBonus;

        final flamePath = Path()
          ..moveTo(ox - flameWidth, 36)
          ..quadraticBezierTo(ox - flameWidth * 0.8, 36 + totalLength * 0.5, ox, 36 + totalLength)
          ..quadraticBezierTo(ox + flameWidth * 0.8, 36 + totalLength * 0.5, ox + flameWidth, 36)
          ..close();

        final flamePaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: nitro > 0.3
                ? [
                    const Color(0xFF00FF66), // Neon Green
                    const Color(0xFF00F2FE), // Electric Cyan
                    const Color(0xFF8B5CF6), // Hyper Violet
                    Colors.transparent,
                  ]
                : [
                    const Color(0xFF00F2FE),
                    const Color(0xFF3B82F6),
                    Colors.transparent,
                  ],
            stops: nitro > 0.3 ? const [0.0, 0.3, 0.7, 1.0] : const [0.0, 0.6, 1.0],
          ).createShader(Rect.fromLTWH(ox - flameWidth, 36, flameWidth * 2, totalLength));

        canvas.drawPath(flamePath, flamePaint);

        // White-hot plasma flame core
        final coreWidth = flameWidth * 0.45;
        final coreLength = totalLength * (0.45 + nitro * 0.2);
        final corePath = Path()
          ..moveTo(ox - coreWidth, 36)
          ..lineTo(ox, 36 + coreLength)
          ..lineTo(ox + coreWidth, 36)
          ..close();
        canvas.drawPath(corePath, Paint()..color = Colors.white.withValues(alpha: 0.95));

        // Shock diamonds during intense nitro burn
        if (nitro > 0.5) {
          final shockDiamondPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.8 * nitro)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          canvas.drawOval(
            Rect.fromCenter(center: Offset(ox, 36 + totalLength * 0.42), width: flameWidth * 1.2, height: 3.5),
            shockDiamondPaint,
          );
        }
      }

      final List<double> exhaustTips = [-14.0, -9.0, 9.0, 14.0];
      for (int i = 0; i < exhaustTips.length; i++) {
        drawExhaustFlame(exhaustTips[i], i);
      }
    }

    // B. Braking Tire Smoke & Friction Lines
    if (params.state == CarAnimationState.braking) {
      final smokePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

      canvas.drawCircle(const Offset(-22, 28), 8.0, smokePaint);
      canvas.drawCircle(const Offset(22, 28), 8.0, smokePaint);

      // Yellow sparks
      final sparkPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = 2.0;
      canvas.drawLine(const Offset(-22, 30), const Offset(-30, 42), sparkPaint);
      canvas.drawLine(const Offset(22, 30), const Offset(30, 42), sparkPaint);
    }

    // C. Collision Arc Sparks
    if (params.state == CarAnimationState.collision) {
      final arcPaint = Paint()
        ..color = const Color(0xFF00F2FE)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      final Path sparkArc = Path()
        ..moveTo(-24, -20)
        ..lineTo(-18, -26)
        ..lineTo(-26, -32);
      canvas.drawPath(sparkArc, arcPaint);
    }

    // D. Destroyed State: Fire Explosion Core, Dense Smoke Plumes & Chassis Sparks
    if (params.state == CarAnimationState.destroyed) {
      // Fire explosion core
      final firePaint = Paint()
        ..color = const Color(0xFFFF3D00).withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawCircle(const Offset(0, -4), 28.0, firePaint);

      final yellowCorePaint = Paint()
        ..color = const Color(0xFFFFD700).withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawCircle(const Offset(0, -4), 14.0, yellowCorePaint);

      // Dark Billowing Smoke Plumes
      final smokePaint = Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
      canvas.drawCircle(const Offset(-12, -18), 24.0, smokePaint);
      canvas.drawCircle(const Offset(14, 12), 22.0, smokePaint);
      canvas.drawCircle(const Offset(-6, 16), 18.0, smokePaint);

      // Arcing Friction Sparks on damaged chassis
      final sparkPaint = Paint()
        ..color = const Color(0xFFFFD700)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-18, -22), const Offset(-28, -32), sparkPaint);
      canvas.drawLine(const Offset(18, -18), const Offset(28, -28), sparkPaint);
      canvas.drawLine(const Offset(-22, 16), const Offset(-32, 24), sparkPaint);
      canvas.drawLine(const Offset(20, 18), const Offset(30, 26), sparkPaint);
    }
  }
}

class _WheelData {
  final double x;
  final double y;
  final bool isFront;
  const _WheelData({required this.x, required this.y, required this.isFront});
}

/// ============================================================================
/// REUSABLE FLUTTER WIDGET WRAPPER: [PlayerCarWidget]
/// ============================================================================
/// Use this widget in menus, shop/garage screens, or previews.
class PlayerCarWidget extends StatefulWidget {
  final CarAnimationState state;
  final double width;
  final double height;
  final PlayerCarTheme theme;
  final ui.Image? customSpriteImage;
  final bool autoAnimate;

  const PlayerCarWidget({
    super.key,
    this.state = CarAnimationState.driving,
    this.width = 120.0,
    this.height = 160.0,
    this.theme = PlayerCarTheme.cyberBlue,
    this.customSpriteImage,
    this.autoAnimate = true,
  });

  @override
  State<PlayerCarWidget> createState() => _PlayerCarWidgetState();
}

class _PlayerCarWidgetState extends State<PlayerCarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.autoAnimate) {
      _controller.repeat();
    }
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
        final double anim = _controller.value;
        final double wheelRot = anim * 2 * pi;
        final double suspension = (widget.state == CarAnimationState.idle)
            ? sin(anim * 2 * pi) * 1.5
            : sin(anim * 6 * pi) * 2.0;

        double tilt = 0.0;
        double steer = 0.0;
        if (widget.state == CarAnimationState.laneChangeLeft) {
          tilt = -0.18;
          steer = -0.22;
        } else if (widget.state == CarAnimationState.laneChangeRight) {
          tilt = 0.18;
          steer = 0.22;
        }

        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _PlayerCarStandalonePainter(
            params: CarRenderParams(
              state: widget.state,
              speed: widget.state == CarAnimationState.idle ? 0.0 : 120.0,
              laneTilt: tilt,
              steerAngle: steer,
              suspensionBounce: suspension,
              wheelRotation: wheelRot,
              theme: widget.theme,
              customSpriteImage: widget.customSpriteImage,
            ),
          ),
        );
      },
    );
  }
}

class _PlayerCarStandalonePainter extends CustomPainter {
  final CarRenderParams params;
  _PlayerCarStandalonePainter({required this.params});

  @override
  void paint(Canvas canvas, Size size) {
    PlayerCarVisual.drawCar(canvas, size, params);
  }

  @override
  bool shouldRepaint(covariant _PlayerCarStandalonePainter oldDelegate) => true;
}
