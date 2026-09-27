import 'dart:math';
import 'package:flutter/material.dart';
import 'player.dart';

/// ============================================================================
/// TURBO RACER: REUSABLE MODULAR OBSTACLE SYSTEM (9 OBSTACLE TYPES)
/// ============================================================================
/// 1. Road Barrier (Concrete barrier with hazard chevron stripes)
/// 2. Traffic Cone (High-vis orange pylon - knocks away with score penalty)
/// 3. Construction Barricade (A-frame hazard board with flashing amber lights)
/// 4. Roadblock (Reinforced concrete barricade with red flashing beacon)
/// 5. Broken-down Vehicle (Stalled smoking sedan with active hazard blinkers)
/// 6. Oil Spill (Slippery chromatic oil slick causing loss of traction & spin)
/// 7. Speed Bump (Raised asphalt hump causing violent suspension rebound)
/// 8. Construction Zone (Roadworks zone with animated flashing detour arrow)
/// 9. Fallen Object (Fallen wooden cargo crate on the asphalt)
/// ============================================================================

/// 9 Obstacle Types + Legacy Compatibility
enum ObstacleType {
  roadBarrier,
  trafficCone,
  constructionBarricade,
  roadBlock,
  brokenDownVehicle,
  oilSpill,
  speedBump,
  constructionZone,
  fallenObject,

  // Legacy runner compatibility
  lowBarrier,
  overheadBarrier,
  vehicle,
  movingBarrier,
}

/// Collision Impact Effect
enum ObstacleCollisionEffect {
  fatalCrash,     // Causes crash (instant death or shield break)
  slowdown,       // Temporarily reduces player speed by 25-30%
  spinout,        // Triggers drift fishtail slip & loss of steering for 1s
  scorePenalty,   // Deducts minor points (-20 pts) without dying
  suspensionBump, // Causes strong vertical suspension bounce & haptic jolt
}

/// Configuration Profile for Each Obstacle Type
class ObstacleConfig {
  final ObstacleType type;
  final String name;
  final double widthRatio; // Width as ratio of laneWidth
  final double height;
  final ObstacleCollisionEffect collisionEffect;
  final int scorePenalty;
  final double speedReductionPercent; // e.g. 0.3 = 30% slowdown
  final bool hasAnimation;
  final bool canJumpOver;
  final bool canSlideUnder;

  const ObstacleConfig({
    required this.type,
    required this.name,
    required this.widthRatio,
    required this.height,
    required this.collisionEffect,
    this.scorePenalty = 0,
    this.speedReductionPercent = 0.0,
    this.hasAnimation = false,
    this.canJumpOver = false,
    this.canSlideUnder = false,
  });

  // 1. Road Barrier
  static const ObstacleConfig roadBarrier = ObstacleConfig(
    type: ObstacleType.roadBarrier,
    name: "Road Barrier",
    widthRatio: 0.84,
    height: 54.0,
    collisionEffect: ObstacleCollisionEffect.fatalCrash,
    canJumpOver: true,
  );

  // 2. Traffic Cone
  static const ObstacleConfig trafficCone = ObstacleConfig(
    type: ObstacleType.trafficCone,
    name: "Traffic Cone",
    widthRatio: 0.45,
    height: 38.0,
    collisionEffect: ObstacleCollisionEffect.scorePenalty,
    scorePenalty: 25,
    speedReductionPercent: 0.10,
    hasAnimation: true,
    canJumpOver: true,
    canSlideUnder: true,
  );

  // 3. Construction Barricade
  static const ObstacleConfig constructionBarricade = ObstacleConfig(
    type: ObstacleType.constructionBarricade,
    name: "Construction Barricade",
    widthRatio: 0.88,
    height: 48.0,
    collisionEffect: ObstacleCollisionEffect.fatalCrash,
    hasAnimation: true,
    canJumpOver: true,
    canSlideUnder: true,
  );

  // 4. Roadblock
  static const ObstacleConfig roadBlock = ObstacleConfig(
    type: ObstacleType.roadBlock,
    name: "Reinforced Roadblock",
    widthRatio: 0.86,
    height: 60.0,
    collisionEffect: ObstacleCollisionEffect.fatalCrash,
    hasAnimation: true,
    canJumpOver: false,
  );

  // 5. Broken-down Vehicle
  static const ObstacleConfig brokenDownVehicle = ObstacleConfig(
    type: ObstacleType.brokenDownVehicle,
    name: "Broken-Down Vehicle",
    widthRatio: 0.82,
    height: 76.0,
    collisionEffect: ObstacleCollisionEffect.fatalCrash,
    hasAnimation: true,
    canJumpOver: false,
  );

  // 6. Oil Spill
  static const ObstacleConfig oilSpill = ObstacleConfig(
    type: ObstacleType.oilSpill,
    name: "Oil Spill",
    widthRatio: 0.78,
    height: 46.0,
    collisionEffect: ObstacleCollisionEffect.spinout,
    speedReductionPercent: 0.30,
    hasAnimation: true,
    canJumpOver: true,
  );

  // 7. Speed Bump
  static const ObstacleConfig speedBump = ObstacleConfig(
    type: ObstacleType.speedBump,
    name: "Speed Bump",
    widthRatio: 0.94,
    height: 32.0,
    collisionEffect: ObstacleCollisionEffect.suspensionBump,
    speedReductionPercent: 0.15,
    hasAnimation: false,
    canJumpOver: true,
  );

  // 8. Construction Zone
  static const ObstacleConfig constructionZone = ObstacleConfig(
    type: ObstacleType.constructionZone,
    name: "Construction Zone",
    widthRatio: 0.90,
    height: 66.0,
    collisionEffect: ObstacleCollisionEffect.fatalCrash,
    hasAnimation: true,
    canJumpOver: false,
  );

  // 9. Fallen Object
  static const ObstacleConfig fallenObject = ObstacleConfig(
    type: ObstacleType.fallenObject,
    name: "Fallen Cargo Crate",
    widthRatio: 0.65,
    height: 48.0,
    collisionEffect: ObstacleCollisionEffect.fatalCrash,
    canJumpOver: true,
  );

  static ObstacleConfig fromType(ObstacleType type) {
    switch (type) {
      case ObstacleType.roadBarrier:
      case ObstacleType.lowBarrier:
        return roadBarrier;
      case ObstacleType.trafficCone:
        return trafficCone;
      case ObstacleType.constructionBarricade:
        return constructionBarricade;
      case ObstacleType.roadBlock:
        return roadBlock;
      case ObstacleType.brokenDownVehicle:
      case ObstacleType.vehicle:
        return brokenDownVehicle;
      case ObstacleType.oilSpill:
        return oilSpill;
      case ObstacleType.speedBump:
        return speedBump;
      case ObstacleType.constructionZone:
      case ObstacleType.overheadBarrier:
        return constructionZone;
      case ObstacleType.fallenObject:
      case ObstacleType.movingBarrier:
        return fallenObject;
    }
  }
}

/// Obstacle Runtime Instance
class Obstacle {
  ObstacleType type;
  int lane; // 0 = Left, 1 = Center, 2 = Right
  double y; // Y coordinate along track
  double horizontalOffset; // Sweeping offset
  double moveSpeed;
  bool moveDirectionRight;
  bool cleared;
  double animTimer;

  Obstacle({
    required this.type,
    required this.lane,
    required this.y,
    this.horizontalOffset = 0.0,
    this.moveSpeed = 0.0,
    this.moveDirectionRight = true,
    this.cleared = false,
    this.animTimer = 0.0,
  });

  ObstacleConfig get config => ObstacleConfig.fromType(type);

  void update(double dt, double worldSpeed) {
    y += (worldSpeed + moveSpeed) * dt;
    animTimer += dt;

    // Moving barrier horizontal oscillation
    if (type == ObstacleType.movingBarrier) {
      if (moveDirectionRight) {
        horizontalOffset += dt * 1.5;
        if (horizontalOffset >= 0.7) {
          horizontalOffset = 0.7;
          moveDirectionRight = false;
        }
      } else {
        horizontalOffset -= dt * 1.5;
        if (horizontalOffset <= -0.7) {
          horizontalOffset = -0.7;
          moveDirectionRight = true;
        }
      }
    }
  }

  /// Collision Check with Player (Accurate, Fair & Realistic Collisions)
  bool checkCollision(Player player, double laneWidth, double roadLeft, double playerY) {
    if (cleared || player.isInvulnerable || player.state == PlayerActionState.dead) {
      return false;
    }

    // 1. Never collide if object is near horizon / not yet on driving asphalt
    if (y < 100.0) return false;

    // 2. Auto-clear obstacles only after they have completely passed behind the player's rear bumper
    final double yDiff = y - playerY;
    if (yDiff > 80.0) {
      cleared = true;
      return false; // Safely passed behind player
    }

    // 3. Early exit if obstacle is still far ahead on the road
    if (yDiff < -100.0) {
      return false; // Far ahead
    }

    // 4. JUMP evasion check
    if (player.state == PlayerActionState.jumping || player.jumpY > 12.0) {
      if (config.canJumpOver || player.jumpY > 20.0) {
        return false; // Safely vaulted in mid-air over obstacle
      }
    }

    // 5. SLIDE evasion check
    if (player.state == PlayerActionState.sliding || player.slideTimer > 0.0) {
      if (config.canSlideUnder) {
        return false; // Safely ducked/slid under obstacle
      }
    }

    final double effectiveObsLane = lane.toDouble() + horizontalOffset;
    final double obstacleX = roadLeft + (effectiveObsLane + 0.5) * laneWidth;
    final double playerX = roadLeft + (player.laneProgress + 0.5) * laneWidth;

    final double obsWidth = laneWidth * config.widthRatio * 0.78;
    final double obsHeight = config.height * 0.72;

    final Rect obsRect = Rect.fromCenter(
      center: Offset(obstacleX, y),
      width: obsWidth,
      height: obsHeight,
    );

    final Rect playerRect = player.getHitbox(playerX, playerY, laneWidth);

    return obsRect.overlaps(playerRect);
  }
}

/// ============================================================================
/// MODULAR OBSTACLE VISUAL RENDERER (ALL 9 OBSTACLES AT 60 FPS)
/// ============================================================================
class ObstacleVisual {
  static void drawObstacle(Canvas canvas, Obstacle obs, double laneWidth) {
    canvas.save();

    final cfg = obs.config;
    final double w = laneWidth * cfg.widthRatio;

    switch (obs.type) {
      case ObstacleType.roadBarrier:
      case ObstacleType.lowBarrier:
        _drawRoadBarrier(canvas, w, obs.animTimer);
        break;
      case ObstacleType.trafficCone:
        _drawTrafficCone(canvas, w, obs.animTimer);
        break;
      case ObstacleType.constructionBarricade:
        _drawConstructionBarricade(canvas, w, obs.animTimer);
        break;
      case ObstacleType.roadBlock:
        _drawRoadblock(canvas, w, obs.animTimer);
        break;
      case ObstacleType.brokenDownVehicle:
      case ObstacleType.vehicle:
        _drawBrokenDownVehicle(canvas, w, obs.animTimer);
        break;
      case ObstacleType.oilSpill:
        _drawOilSpill(canvas, w, obs.animTimer);
        break;
      case ObstacleType.speedBump:
        _drawSpeedBump(canvas, w, obs.animTimer);
        break;
      case ObstacleType.constructionZone:
      case ObstacleType.overheadBarrier:
        _drawConstructionZone(canvas, w, obs.animTimer);
        break;
      case ObstacleType.fallenObject:
      case ObstacleType.movingBarrier:
        _drawFallenObject(canvas, w, obs.animTimer);
        break;
    }

    canvas.restore();
  }

  // --------------------------------------------------------------------------
  // 1. ROAD BARRIER (Concrete with Hazard Stripes)
  // --------------------------------------------------------------------------
  static void _drawRoadBarrier(Canvas canvas, double w, double animTimer) {
    // Ground Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 16), width: w * 1.05, height: 12),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Concrete Block Base
    final blockRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: 32),
      const Radius.circular(6.0),
    );

    final blockPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF64748B), Color(0xFF334155), Color(0xFF1E293B)],
      ).createShader(Rect.fromLTWH(-w / 2, -16, w, 32));

    canvas.drawRRect(blockRect, blockPaint);

    // Yellow Hazard Diagonal Stripes
    final stripePaint = Paint()
      ..color = const Color(0xFFFACC15)
      ..strokeWidth = 5.0;

    for (double sx = -w / 2 + 10; sx < w / 2 - 4; sx += 14.0) {
      canvas.drawLine(Offset(sx, 12), Offset(sx + 8, -12), stripePaint);
    }
  }

  // --------------------------------------------------------------------------
  // 2. TRAFFIC CONE (Orange Pylon with Reflective Bands)
  // --------------------------------------------------------------------------
  static void _drawTrafficCone(Canvas canvas, double w, double animTimer) {
    // Ground Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 12), width: 26, height: 8),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // Square Base Plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-11, 8, 22, 6), const Radius.circular(2)),
      Paint()..color = const Color(0xFFEA580C),
    );

    // Orange Cone Body
    final Path conePath = Path()
      ..moveTo(-9, 8)
      ..lineTo(-3, -16)
      ..lineTo(3, -16)
      ..lineTo(9, 8)
      ..close();

    final conePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFB923C), Color(0xFFEA580C), Color(0xFFC2410C)],
      ).createShader(const Rect.fromLTWH(-9, -16, 18, 24));

    canvas.drawPath(conePath, conePaint);

    // White Reflective Wrap Bands
    final whitePaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawRect(const Rect.fromLTWH(-6, -4, 12, 4.5), whitePaint);
    canvas.drawRect(const Rect.fromLTWH(-4.5, -12, 9, 3.5), whitePaint);
  }

  // --------------------------------------------------------------------------
  // 3. CONSTRUCTION BARRICADE (A-Frame with Blinking Amber Lights)
  // --------------------------------------------------------------------------
  static void _drawConstructionBarricade(Canvas canvas, double w, double animTimer) {
    // Ground Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 18), width: w * 0.95, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // A-Frame Leg Stands
    final legPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(-w / 2 + 8, 16), Offset(-w / 2 + 8, -16), legPaint);
    canvas.drawLine(Offset(w / 2 - 8, 16), Offset(w / 2 - 8, -16), legPaint);

    // Hazard Striped Horizontal Bar
    final barRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -6), width: w, height: 16),
      const Radius.circular(3.0),
    );

    final barPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFFFFFFF), Color(0xFFEF4444), Color(0xFFFFFFFF)],
        stops: [0.0, 0.33, 0.66, 1.0],
      ).createShader(Rect.fromLTWH(-w / 2, -14, w, 16));

    canvas.drawRRect(barRect, barPaint);

    // Flashing Amber Warning Beacons on Top
    final bool isBlinkOn = ((animTimer * 5).floor() % 2 == 0);
    final amberGlow = Paint()
      ..color = (isBlinkOn ? const Color(0xFFFBBF24) : const Color(0xFF78350F))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isBlinkOn ? 8.0 : 0.0);

    canvas.drawCircle(Offset(-w / 2 + 10, -20), 4.5, amberGlow);
    canvas.drawCircle(Offset(w / 2 - 10, -20), 4.5, amberGlow);
    canvas.drawCircle(Offset(-w / 2 + 10, -20), 2.5, Paint()..color = isBlinkOn ? Colors.white : const Color(0xFFD97706));
    canvas.drawCircle(Offset(w / 2 - 10, -20), 2.5, Paint()..color = isBlinkOn ? Colors.white : const Color(0xFFD97706));
  }

  // --------------------------------------------------------------------------
  // 4. ROADBLOCK (Reinforced Block with Red Flashing Warning Light)
  // --------------------------------------------------------------------------
  static void _drawRoadblock(Canvas canvas, double w, double animTimer) {
    // Heavy Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 24), width: w * 1.05, height: 16),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    // 3D Concrete Base
    final blockRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: 44),
      const Radius.circular(8.0),
    );

    final blockPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF475569), Color(0xFF334155), Color(0xFF1E293B)],
      ).createShader(Rect.fromLTWH(-w / 2, -22, w, 44));

    canvas.drawRRect(blockRect, blockPaint);

    // Yellow Hazard Diagonal Lines
    final stripePaint = Paint()
      ..color = const Color(0xFFFACC15)
      ..strokeWidth = 5.5;

    for (double sx = -w / 2 + 8; sx < w / 2 - 4; sx += 14.0) {
      canvas.drawLine(Offset(sx, 16), Offset(sx + 10, -16), stripePaint);
    }

    // Flashing Red Warning Beacon Light
    final bool isFlash = ((animTimer * 6).floor() % 2 == 0);
    final beaconPaint = Paint()
      ..color = (isFlash ? const Color(0xFFFF0055) : const Color(0xFF7F1D1D))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isFlash ? 10.0 : 2.0);

    canvas.drawCircle(const Offset(0, -28), 6.0, beaconPaint);
    canvas.drawCircle(const Offset(0, -28), 3.0, Paint()..color = isFlash ? Colors.white : const Color(0xFFDC2626));
  }

  // --------------------------------------------------------------------------
  // 5. BROKEN-DOWN VEHICLE (Smoking Car with Hazard Blinkers)
  // --------------------------------------------------------------------------
  static void _drawBrokenDownVehicle(Canvas canvas, double w, double animTimer) {
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 34), width: w * 1.1, height: 18),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Car Body
    final carRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * 0.88, height: 68),
      const Radius.circular(10.0),
    );

    final carPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF64748B), Color(0xFF475569), Color(0xFF1E293B)],
      ).createShader(Rect.fromLTWH(-w * 0.44, -34, w * 0.88, 68));

    canvas.drawRRect(carRect, carPaint);

    // Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -14, 28, 20), const Radius.circular(4)),
      Paint()..color = const Color(0xFF0F172A),
    );

    // Flashing Emergency Hazard Lights
    final bool isBlink = ((animTimer * 4).floor() % 2 == 0);
    final blinkPaint = Paint()
      ..color = (isBlink ? const Color(0xFFFBBF24) : const Color(0xFF78350F))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isBlink ? 6.0 : 0.0);

    canvas.drawCircle(Offset(-w * 0.35, 30), 3.5, blinkPaint);
    canvas.drawCircle(Offset(w * 0.35, 30), 3.5, blinkPaint);

    // Billowing Engine Smoke Puffs from Hood
    final smokePaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    final double smokeShift1 = sin(animTimer * 3) * 6.0;
    final double smokeShift2 = cos(animTimer * 4) * 8.0;
    canvas.drawCircle(Offset(-4 + smokeShift1, -38 - (animTimer * 12 % 20)), 9.0, smokePaint);
    canvas.drawCircle(Offset(6 + smokeShift2, -44 - (animTimer * 10 % 24)), 11.0, smokePaint);
  }

  // --------------------------------------------------------------------------
  // 6. OIL SPILL (Chromatic Sheen Puddle)
  // --------------------------------------------------------------------------
  static void _drawOilSpill(Canvas canvas, double w, double animTimer) {
    final Path oilPath = Path()
      ..moveTo(0, -18)
      ..cubicTo(w * 0.4, -22, w * 0.5, 4, w * 0.35, 18)
      ..cubicTo(0, 24, -w * 0.4, 20, -w * 0.45, 2)
      ..cubicTo(-w * 0.4, -14, -w * 0.2, -20, 0, -18)
      ..close();

    final oilPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xCC9333EA), // Purple iridescence
          Color(0xAA06B6D4), // Cyan sheen
          Color(0x88F59E0B), // Golden edge
          Colors.transparent,
        ],
        stops: [0.0, 0.45, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(-w / 2, -22, w, 44));

    canvas.drawPath(oilPath, oilPaint);

    // Glossy Specular Highlight
    final shinePaint = Paint()..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawOval(const Rect.fromLTWH(-8, -10, 16, 6), shinePaint);
  }

  // --------------------------------------------------------------------------
  // 7. SPEED BUMP (Yellow/Black Raised Asphalt Hump)
  // --------------------------------------------------------------------------
  static void _drawSpeedBump(Canvas canvas, double w, double animTimer) {
    // 3D Ramp Body
    final bumpRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: 18),
      const Radius.circular(5.0),
    );

    final bumpPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEAB308), Color(0xFFCA8A04), Color(0xFF713F12)],
      ).createShader(Rect.fromLTWH(-w / 2, -9, w, 18));

    canvas.drawRRect(bumpRect, bumpPaint);

    // Black Chevron Teeth Markings
    final toothPaint = Paint()..color = const Color(0xFF0F172A);
    for (double tx = -w / 2 + 8; tx < w / 2 - 8; tx += 16.0) {
      final Path tooth = Path()
        ..moveTo(tx - 4, 8)
        ..lineTo(tx, -8)
        ..lineTo(tx + 4, 8)
        ..close();
      canvas.drawPath(tooth, toothPaint);
    }
  }

  // --------------------------------------------------------------------------
  // 8. CONSTRUCTION ZONE (Roadworks with Blinking Detour Arrow)
  // --------------------------------------------------------------------------
  static void _drawConstructionZone(Canvas canvas, double w, double animTimer) {
    // Sign Board
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: 38),
      const Radius.circular(6.0),
    );

    final boardPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFC2410C), Color(0xFF7C2D12)],
      ).createShader(Rect.fromLTWH(-w / 2, -19, w, 38));

    canvas.drawRRect(boardRect, boardPaint);

    // Flashing Yellow Neon Detour Arrow: "◀ ◀ ◀"
    final bool isArrowPhase = ((animTimer * 4).floor() % 2 == 0);
    final arrowPaint = Paint()
      ..color = isArrowPhase ? const Color(0xFFFEF08A) : const Color(0xFFFDE047)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int i = -1; i <= 1; i++) {
      final double ax = i * 16.0;
      final Path arrow = Path()
        ..moveTo(ax + 4, -8)
        ..lineTo(ax - 4, 0)
        ..lineTo(ax + 4, 8);
      canvas.drawPath(
        arrow,
        arrowPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }
  }

  // --------------------------------------------------------------------------
  // 9. FALLEN OBJECT (Wooden Cargo Crate)
  // --------------------------------------------------------------------------
  static void _drawFallenObject(Canvas canvas, double w, double animTimer) {
    const double size = 32.0;

    // Ground Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 14), width: size * 1.2, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // Wooden Crate Body
    final crateRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: size, height: size),
      const Radius.circular(4.0),
    );

    final cratePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB45309), Color(0xFF92400E), Color(0xFF78350F)],
      ).createShader(const Rect.fromLTWH(-size / 2, -size / 2, size, size));

    canvas.drawRRect(crateRect, cratePaint);

    // Diagonal Metal Reinforcement Cross Straps
    final strapPaint = Paint()
      ..color = const Color(0xFF451A03)
      ..strokeWidth = 2.5;

    canvas.drawLine(const Offset(-size / 2 + 3, -size / 2 + 3), const Offset(size / 2 - 3, size / 2 - 3), strapPaint);
    canvas.drawLine(const Offset(size / 2 - 3, -size / 2 + 3), const Offset(-size / 2 + 3, size / 2 - 3), strapPaint);

    // Outer Frame Border
    canvas.drawRRect(
      crateRect,
      Paint()
        ..color = const Color(0xFF451A03)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
