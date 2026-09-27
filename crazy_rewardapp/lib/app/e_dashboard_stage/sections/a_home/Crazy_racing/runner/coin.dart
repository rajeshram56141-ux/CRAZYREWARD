import 'dart:math';
import 'package:flutter/material.dart';
import 'player.dart';

/// ============================================================================
/// TURBO RACER: PREMIUM COLLECTIBLE COIN & POWER-UP SYSTEM
/// ============================================================================
/// Features:
/// 1. Premium Golden Racing Coin visual with continuous 3D rotation, metallic
///    gradient sheen, edge grooves, stamped star crest, specular glint & glow.
/// 2. 6 Spawning Patterns: Straight Line, Left-to-Right, Right-to-Left,
///    Zig-zag, Curved, Lane-Switch, and Jump Arcs.
/// 3. High-performance Object Pooling (Zero-allocation runtime GC optimization).
/// 4. Magnet attraction physics and forgiving collection hitboxes.
/// ============================================================================

enum CollectibleType {
  goldCoin,
  gem,
  shield,
  magnet,
  multiplier2x,
  speedBoost,
  slowMotion,
  invincibility,
  nitroCanister,
}

enum CoinPatternType {
  straightLine,
  leftToRight,
  rightToLeft,
  zigzag,
  curved,
  laneSwitch,
  jumpArc,
}

/// Runtime Collectible Item Instance (Reusable via Object Pool)
class CollectibleItem {
  CollectibleType type;
  int lane; // 0 = Left, 1 = Center, 2 = Right
  double y; // Road coordinate
  double horizontalOffset; // Sub-lane offset (-0.5 to +0.5 for curved paths)
  double heightOffset; // Elevation for airborne jump arcs
  double spinPhase; // 3D rotation angle
  bool collected;
  bool active;

  CollectibleItem({
    this.type = CollectibleType.goldCoin,
    this.lane = 1,
    this.y = 0.0,
    this.horizontalOffset = 0.0,
    this.heightOffset = 0.0,
    this.spinPhase = 0.0,
    this.collected = false,
    this.active = false,
  });

  void reset({
    required CollectibleType type,
    required int lane,
    required double y,
    double horizontalOffset = 0.0,
    double heightOffset = 0.0,
    double spinPhase = 0.0,
  }) {
    this.type = type;
    this.lane = lane;
    this.y = y;
    this.horizontalOffset = horizontalOffset;
    this.heightOffset = heightOffset;
    this.spinPhase = spinPhase;
    collected = false;
    active = true;
  }

  void update(
    double dt,
    double worldSpeed,
    Player player,
    double laneWidth,
    double roadLeft,
    double playerY,
  ) {
    if (!active || collected) return;

    // Advance along road with speed
    y += worldSpeed * dt;

    // Continuous 3D rotation animation
    spinPhase = (spinPhase + dt * 5.0) % (2 * pi);

    // MAGNET ATTRACTION PHYSICS
    if (player.isMagnetActive && type == CollectibleType.goldCoin) {
      final double currentItemX = roadLeft + (lane + 0.5 + horizontalOffset) * laneWidth;
      final double playerX = roadLeft + (player.laneProgress + 0.5) * laneWidth;

      final double dx = playerX - currentItemX;
      final double dy = playerY - y;
      final double dist = sqrt(dx * dx + dy * dy);

      if (dist < 400.0 && dist > 1.0) {
        // Accelerating pull force towards car
        final double pullForce = (1.0 - (dist / 400.0)).clamp(0.2, 1.0);
        final double pullSpeed = (550.0 + pullForce * 400.0) * dt;

        y += (dy / dist) * pullSpeed;

        final double laneDiff = (player.laneProgress - (lane + horizontalOffset));
        if (laneDiff.abs() > 0.05) {
          horizontalOffset += (laneDiff > 0 ? 1.0 : -1.0) * dt * 3.5;
          if (horizontalOffset > 0.6 && lane < 2) {
            lane++;
            horizontalOffset -= 1.0;
          } else if (horizontalOffset < -0.6 && lane > 0) {
            lane--;
            horizontalOffset += 1.0;
          }
        }
      }
    }
  }

  bool checkCollection(
    Player player,
    double laneWidth,
    double roadLeft,
    double playerY,
  ) {
    if (!active || collected) return false;

    final double itemX = roadLeft + (lane + 0.5 + horizontalOffset) * laneWidth;
    final double itemY = y - heightOffset;

    final double playerX = roadLeft + (player.laneProgress + 0.5) * laneWidth;
    final double playerCurrentY = playerY - player.jumpY;

    // Generous and responsive collection radius
    final double collectionRadius = (type == CollectibleType.goldCoin) ? 40.0 : 46.0;

    final double dx = playerX - itemX;
    final double dy = playerCurrentY - itemY;
    final double dist = sqrt(dx * dx + dy * dy);

    if (dist <= collectionRadius) {
      collected = true;
      return true;
    }
    return false;
  }
}

/// ============================================================================
/// OBJECT POOL FOR COLLECTIBLES (HIGH-PERFORMANCE ZERO-ALLOCATION)
/// ============================================================================
class CoinPool {
  final List<CollectibleItem> _pool = [];

  CoinPool({int initialCapacity = 60}) {
    for (int i = 0; i < initialCapacity; i++) {
      _pool.add(CollectibleItem(active: false));
    }
  }

  CollectibleItem acquire({
    required CollectibleType type,
    required int lane,
    required double y,
    double horizontalOffset = 0.0,
    double heightOffset = 0.0,
    double spinPhase = 0.0,
  }) {
    CollectibleItem item;
    if (_pool.isNotEmpty) {
      item = _pool.removeLast();
    } else {
      item = CollectibleItem();
    }

    item.reset(
      type: type,
      lane: lane,
      y: y,
      horizontalOffset: horizontalOffset,
      heightOffset: heightOffset,
      spinPhase: spinPhase,
    );
    return item;
  }

  void release(CollectibleItem item) {
    item.active = false;
    item.collected = true;
    if (_pool.length < 120) {
      _pool.add(item);
    }
  }

  void releaseAll(List<CollectibleItem> items) {
    for (final it in items) {
      release(it);
    }
    items.clear();
  }
}

/// ============================================================================
/// PROCEDURAL COIN PATTERN GENERATOR
/// ============================================================================
class CoinPatternGenerator {
  static final Random _random = Random();

  /// Spawns a structured coin pattern from the 6 supported formations:
  /// 1. Straight Line
  /// 2. Left-to-Right
  /// 3. Right-to-Left
  /// 4. Zig-zag
  /// 5. Curved (S-curve)
  /// 6. Lane-Switch (Chicane)
  /// + Jump Arc
  static void spawnPattern(
    CoinPatternType pattern, {
    required CoinPool pool,
    required List<CollectibleItem> targetList,
    required double spawnY,
    int? forcedStartLane,
    int coinCount = 5,
    double spacing = 38.0,
  }) {
    final int startLane = forcedStartLane ?? _random.nextInt(3);

    switch (pattern) {
      // 1. STRAIGHT LINE PATTERN (3-6 coins in a single lane)
      case CoinPatternType.straightLine:
        for (int i = 0; i < coinCount; i++) {
          targetList.add(pool.acquire(
            type: CollectibleType.goldCoin,
            lane: startLane,
            y: spawnY + i * spacing,
            spinPhase: i * 0.45,
          ));
        }
        break;

      // 2. LEFT-TO-RIGHT DIAGONAL PATTERN (Lane 0 -> Lane 1 -> Lane 2)
      case CoinPatternType.leftToRight:
        const lanes = [0, 0, 1, 1, 2, 2];
        final int count = min(coinCount, lanes.length);
        for (int i = 0; i < count; i++) {
          targetList.add(pool.acquire(
            type: CollectibleType.goldCoin,
            lane: lanes[i],
            y: spawnY + i * spacing,
            spinPhase: i * 0.45,
          ));
        }
        break;

      // 3. RIGHT-TO-LEFT DIAGONAL PATTERN (Lane 2 -> Lane 1 -> Lane 0)
      case CoinPatternType.rightToLeft:
        const lanes = [2, 2, 1, 1, 0, 0];
        final int count = min(coinCount, lanes.length);
        for (int i = 0; i < count; i++) {
          targetList.add(pool.acquire(
            type: CollectibleType.goldCoin,
            lane: lanes[i],
            y: spawnY + i * spacing,
            spinPhase: i * 0.45,
          ));
        }
        break;

      // 4. ZIG-ZAG PATTERN (Alternating across lanes: 0 -> 1 -> 2 -> 1 -> 0)
      case CoinPatternType.zigzag:
        final bool startLeft = _random.nextBool();
        final List<int> zigLanes = startLeft ? [0, 1, 2, 1, 0, 1] : [2, 1, 0, 1, 2, 1];
        final int count = min(coinCount, zigLanes.length);
        for (int i = 0; i < count; i++) {
          targetList.add(pool.acquire(
            type: CollectibleType.goldCoin,
            lane: zigLanes[i],
            y: spawnY + i * (spacing * 1.1),
            spinPhase: i * 0.5,
          ));
        }
        break;

      // 5. CURVED S-CURVE PATTERN (Smooth parabolic transition across road)
      case CoinPatternType.curved:
        for (int i = 0; i < coinCount; i++) {
          final double t = i / (coinCount - 1); // 0.0 -> 1.0
          // Smooth sine arc across lanes centered at Lane 1
          final double curveOffset = sin(t * pi) * 0.75 * (_random.nextBool() ? 1.0 : -1.0);
          targetList.add(pool.acquire(
            type: CollectibleType.goldCoin,
            lane: 1,
            y: spawnY + i * spacing,
            horizontalOffset: curveOffset,
            spinPhase: i * 0.4,
          ));
        }
        break;

      // 6. LANE-SWITCH CHICANE PATTERN (Rapid 2-stage lane change)
      case CoinPatternType.laneSwitch:
        final int fromLane = startLane;
        final int toLane = (fromLane == 1) ? (_random.nextBool() ? 0 : 2) : 1;
        for (int i = 0; i < 6; i++) {
          final int l = (i < 3) ? fromLane : toLane;
          targetList.add(pool.acquire(
            type: CollectibleType.goldCoin,
            lane: l,
            y: spawnY + i * spacing,
            spinPhase: i * 0.45,
          ));
        }
        break;

      // JUMP ARC PATTERN (Parabolic height arc for jump evasion)
      case CoinPatternType.jumpArc:
        for (int i = -2; i <= 2; i++) {
          final double h = (i == 0) ? 65.0 : ((i.abs() == 1) ? 46.0 : 18.0);
          targetList.add(pool.acquire(
            type: CollectibleType.goldCoin,
            lane: startLane,
            y: spawnY + i * 36.0,
            heightOffset: h,
            spinPhase: i * 0.35,
          ));
        }
        break;
    }
  }

  /// Randomly selects one of the 6 core coin patterns
  static CoinPatternType randomPattern() {
    const patterns = [
      CoinPatternType.straightLine,
      CoinPatternType.leftToRight,
      CoinPatternType.rightToLeft,
      CoinPatternType.zigzag,
      CoinPatternType.curved,
      CoinPatternType.laneSwitch,
    ];
    return patterns[_random.nextInt(patterns.length)];
  }
}

/// ============================================================================
/// PREMIUM GOLDEN RACING COIN VISUAL RENDERER (60 FPS VECTOR)
/// ============================================================================
class CoinVisual {
  /// Draws a stunning, shiny 3D golden racing coin with continuous rotation,
  /// metallic gradient highlights, edge bevels, stamped star crest & glow.
  static void drawCoin(
    Canvas canvas,
    double cx,
    double cy,
    double spinPhase, {
    double heightOffset = 0.0,
    double scale = 1.0,
  }) {
    canvas.save();
    canvas.translate(cx, cy - heightOffset);
    if (scale != 1.0) {
      canvas.scale(scale, scale);
    }

    // 1. Perspective Spin Scale (cosine oscillation)
    final double rawCos = cos(spinPhase);
    final double scaleX = rawCos.abs().clamp(0.18, 1.0);
    final bool isFacingForward = rawCos >= 0;

    const double radius = 14.5;
    const double coinH = radius * 2.0;
    final double coinW = coinH * scaleX;

    // 2. Glowing Golden Aura Bloom
    final auraPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: coinW + 12, height: coinH + 12),
      auraPaint,
    );

    // 3. 3D Coin Edge Extrusion / Thickness (visible during horizontal rotation)
    if (scaleX < 0.85) {
      final double edgeOffset = (isFacingForward ? 2.5 : -2.5) * (1.0 - scaleX);
      final edgePaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB45309), Color(0xFF78350F), Color(0xFF451A03)],
        ).createShader(Rect.fromCenter(center: Offset(edgeOffset, 0), width: coinW, height: coinH));

      canvas.drawOval(
        Rect.fromCenter(center: Offset(edgeOffset, 0), width: coinW, height: coinH),
        edgePaint,
      );
    }

    // 4. Outer Metallic Gold Rim (Multi-Stop Gradient)
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFBEB), // Top specular highlight
          Color(0xFFFDE047), // Bright yellow gold
          Color(0xFFF59E0B), // Vivid amber gold
          Color(0xFFD97706), // Deep burnished gold
          Color(0xFF92400E), // Shadow rim
        ],
        stops: [0.0, 0.25, 0.55, 0.82, 1.0],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: coinW, height: coinH));

    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: coinW, height: coinH),
      rimPaint,
    );

    // 5. Inner Inset Recess Disc
    final innerW = (coinW - 5.0 * scaleX).clamp(2.0, 30.0);
    final innerH = coinH - 5.0;
    final innerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFEF08A),
          Color(0xFFFBBF24),
          Color(0xFFD97706),
        ],
      ).createShader(Rect.fromCenter(center: Offset.zero, width: innerW, height: innerH));

    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: innerW, height: innerH),
      innerPaint,
    );

    // 6. Stamped 5-Point Racing Star Crest in Center
    if (scaleX > 0.35) {
      final starPaint = Paint()..color = const Color(0xFF78350F);
      final Path star = _createStarPath(5.5 * scaleX, 2.6 * scaleX);
      canvas.drawPath(star, starPaint);

      // Star bright golden stroke
      final starStroke = Paint()
        ..color = const Color(0xFFFFFBEB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawPath(star, starStroke);
    }

    // 7. Glossy Specular Gleam Glint
    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCenter(center: Offset(-coinW * 0.2, -coinH * 0.2), width: coinW * 0.6, height: coinH * 0.5));

    canvas.drawOval(
      Rect.fromCenter(center: Offset(-coinW * 0.15, -coinH * 0.2), width: coinW * 0.55, height: coinH * 0.4),
      shinePaint,
    );

    canvas.restore();
  }

  /// Creates a 5-pointed star path for the inner coin crest
  static Path _createStarPath(double rOuter, double rInner) {
    final Path path = Path();
    const int points = 5;
    final double step = pi / points;

    for (int i = 0; i < points * 2; i++) {
      final double r = (i % 2 == 0) ? rOuter : rInner;
      final double angle = i * step - pi / 2;
      final double x = cos(angle) * r;
      final double y = sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}
