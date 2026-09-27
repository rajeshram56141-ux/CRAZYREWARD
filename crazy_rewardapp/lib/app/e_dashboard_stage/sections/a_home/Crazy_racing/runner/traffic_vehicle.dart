import 'dart:math';
import 'package:flutter/material.dart';
import 'player.dart';

/// ============================================================================
/// TURBO RACER: TRAFFIC VEHICLE SYSTEM (7 DISTINCT AI VEHICLES)
/// ============================================================================
/// 1. Small Hatchback (Agile, compact city car)
/// 2. Sedan (Executive 3-box commuter car)
/// 3. SUV (Tall, muscular adventure vehicle with roof rails)
/// 4. Sports Car (Low aerodynamic supercar with rear wing)
/// 5. Taxi (Iconic yellow cab with illuminated roof sign & checkers)
/// 6. Truck (Heavy commercial cargo truck with trailer/cab)
/// 7. Van (Boxy delivery/cargo van with rear barn doors)
/// ============================================================================

/// 7 Distinct AI Traffic Vehicle Types
enum TrafficVehicleType {
  hatchback,
  sedan,
  suv,
  sportsCar,
  taxi,
  truck,
  van,
}

/// Vehicle Specs & Configuration
class TrafficVehicleConfig {
  final TrafficVehicleType type;
  final String displayName;
  final double width;
  final double length;
  final double relativeSpeed; // Relative to world speed (+ is faster, - is slower)
  final int rarityWeight; // Higher = more common
  final List<Color> colorPalette;

  const TrafficVehicleConfig({
    required this.type,
    required this.displayName,
    required this.width,
    required this.length,
    required this.relativeSpeed,
    required this.rarityWeight,
    required this.colorPalette,
  });

  /// 1. Small Hatchback
  static const TrafficVehicleConfig hatchback = TrafficVehicleConfig(
    type: TrafficVehicleType.hatchback,
    displayName: "Hatchback",
    width: 38.0,
    length: 56.0,
    relativeSpeed: -3.0,
    rarityWeight: 22,
    colorPalette: [
      Color(0xFF10B981), // Mint Green
      Color(0xFFF59E0B), // Amber Orange
      Color(0xFF06B6D4), // Cyan
      Color(0xFFEC4899), // Coral Pink
    ],
  );

  /// 2. Sedan
  static const TrafficVehicleConfig sedan = TrafficVehicleConfig(
    type: TrafficVehicleType.sedan,
    displayName: "Sedan",
    width: 40.0,
    length: 68.0,
    relativeSpeed: 0.0,
    rarityWeight: 25,
    colorPalette: [
      Color(0xFF64748B), // Slate Silver
      Color(0xFF1E3A8A), // Royal Navy
      Color(0xFF334155), // Graphite
      Color(0xFF991B1B), // Burgundy Red
    ],
  );

  /// 3. SUV
  static const TrafficVehicleConfig suv = TrafficVehicleConfig(
    type: TrafficVehicleType.suv,
    displayName: "SUV",
    width: 44.0,
    length: 74.0,
    relativeSpeed: -2.0,
    rarityWeight: 15,
    colorPalette: [
      Color(0xFF0F766E), // Dark Teal
      Color(0xFF3F3F46), // Dark Charcoal
      Color(0xFF854D0E), // Bronze Gold
      Color(0xFF1E293B), // Midnight Blue
    ],
  );

  /// 4. Sports Car
  static const TrafficVehicleConfig sportsCar = TrafficVehicleConfig(
    type: TrafficVehicleType.sportsCar,
    displayName: "Sports GT",
    width: 42.0,
    length: 70.0,
    relativeSpeed: 6.0, // Mild high-speed traffic racer
    rarityWeight: 6, // Rare
    colorPalette: [
      Color(0xFFEF4444), // Racing Red
      Color(0xFF8B5CF6), // Neon Violet
      Color(0xFFF97316), // Lava Orange
      Color(0xFFE11D48), // Crimson
    ],
  );

  /// 5. Taxi
  static const TrafficVehicleConfig taxi = TrafficVehicleConfig(
    type: TrafficVehicleType.taxi,
    displayName: "City Taxi",
    width: 40.0,
    length: 68.0,
    relativeSpeed: -1.0,
    rarityWeight: 16,
    colorPalette: [
      Color(0xFFFBBF24), // Iconic Taxi Yellow
    ],
  );

  /// 6. Heavy Truck
  static const TrafficVehicleConfig truck = TrafficVehicleConfig(
    type: TrafficVehicleType.truck,
    displayName: "Heavy Truck",
    width: 46.0,
    length: 104.0,
    relativeSpeed: -4.0, // Slow moving heavy barrier
    rarityWeight: 7, // Rare/Challenging
    colorPalette: [
      Color(0xFF2563EB), // Industrial Blue
      Color(0xFFDC2626), // Freight Red
      Color(0xFF059669), // Cargo Green
    ],
  );

  /// 7. Delivery Van
  static const TrafficVehicleConfig van = TrafficVehicleConfig(
    type: TrafficVehicleType.van,
    displayName: "Cargo Van",
    width: 42.0,
    length: 78.0,
    relativeSpeed: -2.5,
    rarityWeight: 9,
    colorPalette: [
      Color(0xFFE2E8F0), // Pure White Courier
      Color(0xFF0284C7), // Sky Express
      Color(0xFF475569), // Steel Cargo
    ],
  );

  static TrafficVehicleConfig fromType(TrafficVehicleType type) {
    switch (type) {
      case TrafficVehicleType.hatchback:
        return hatchback;
      case TrafficVehicleType.sedan:
        return sedan;
      case TrafficVehicleType.suv:
        return suv;
      case TrafficVehicleType.sportsCar:
        return sportsCar;
      case TrafficVehicleType.taxi:
        return taxi;
      case TrafficVehicleType.truck:
        return truck;
      case TrafficVehicleType.van:
        return van;
    }
  }
}

/// Pooled Traffic Vehicle Instance
class TrafficVehicle {
  TrafficVehicleType type;
  int lane; // 0, 1, 2
  double y; // Position along road
  double speedOffset; // Relative speed
  Color primaryColor;
  Color accentColor;
  bool active;
  bool cleared;
  bool nearMissTriggered;
  double wheelRotation;
  double brakeBlinkTimer;
  bool isBraking;

  TrafficVehicle({
    this.type = TrafficVehicleType.sedan,
    this.lane = 1,
    this.y = -200.0,
    this.speedOffset = 0.0,
    this.primaryColor = const Color(0xFF64748B),
    this.accentColor = const Color(0xFF94A3B8),
    this.active = false,
    this.cleared = false,
    this.nearMissTriggered = false,
    this.wheelRotation = 0.0,
    this.brakeBlinkTimer = 0.0,
    this.isBraking = false,
  });

  TrafficVehicleConfig get config => TrafficVehicleConfig.fromType(type);

  void spawn({
    required TrafficVehicleType vehicleType,
    required int targetLane,
    required double startY,
    required Random random,
  }) {
    type = vehicleType;
    lane = targetLane;
    y = startY;
    active = true;
    cleared = false;
    nearMissTriggered = false;
    wheelRotation = 0.0;
    brakeBlinkTimer = 0.0;
    isBraking = random.nextDouble() < 0.25; // 25% chance of braking lights

    final cfg = config;
    speedOffset = cfg.relativeSpeed + (random.nextDouble() * 1.5 - 0.75);
    primaryColor = cfg.colorPalette[random.nextInt(cfg.colorPalette.length)];
    accentColor = HSLColor.fromColor(primaryColor)
        .withLightness((HSLColor.fromColor(primaryColor).lightness * 1.25).clamp(0.0, 1.0))
        .toColor();
  }

  void update(double dt, double worldSpeed) {
    if (!active) return;

    // Movement: AI traffic is driving forward along the road in the same direction (~50-70% world speed)
    // The relative approach speed towards the player allows cars to stay visible cruising ahead
    final double cruiseFactor = (0.60 + speedOffset * 0.02).clamp(0.50, 0.72);
    final double approachSpeed = worldSpeed * cruiseFactor;
    y += approachSpeed * dt;

    // Wheel rotation reflecting true highway speed
    wheelRotation = (wheelRotation + dt * (worldSpeed / 7.0)) % (2 * pi);

    // Periodic braking lights
    brakeBlinkTimer += dt;
    if (brakeBlinkTimer > 3.5) {
      brakeBlinkTimer = 0.0;
      isBraking = !isBraking;
    }
  }

  /// Collision check against player (Accurate, Fair & Realistic Side & Head-on Collisions)
  bool checkCollision(Player player, double laneWidth, double roadLeft, double playerY) {
    if (!active || cleared || player.isInvulnerable || player.state == PlayerActionState.dead) {
      return false;
    }

    // 1. Never collide if vehicle is near horizon / not yet on driving road
    if (y < 100.0) return false;

    // 2. Auto-clear vehicles only after they have completely passed behind the player's rear bumper
    final double yDiff = y - playerY;
    if (yDiff > 90.0) {
      cleared = true;
      return false; // Safely passed behind player
    }

    // 3. Early exit if vehicle is still far ahead on the road
    if (yDiff < -110.0) {
      return false; // Far ahead
    }

    final cfg = config;
    final double vehicleX = roadLeft + (lane + 0.5) * laneWidth;
    final double playerX = roadLeft + (player.laneProgress + 0.5) * laneWidth;

    final double vWidth = cfg.width * 0.82;
    final double vHeight = cfg.length * 0.78;

    final Rect vehicleRect = Rect.fromCenter(
      center: Offset(vehicleX, y),
      width: vWidth,
      height: vHeight,
    );

    final Rect playerRect = player.getHitbox(playerX, playerY, laneWidth);

    return vehicleRect.overlaps(playerRect);
  }
}

/// ============================================================================
/// TRAFFIC VEHICLE VISUAL RENDERER (ALL 7 CAR DESIGNS AT 60 FPS)
/// ============================================================================
class TrafficVehicleVisual {
  static void drawVehicle(Canvas canvas, TrafficVehicle vehicle, double laneWidth) {
    canvas.save();
    canvas.translate(0, 0);

    // 1. Dynamic Contact Shadow
    _drawShadow(canvas, vehicle);

    // 2. Wheels
    _drawWheels(canvas, vehicle);

    // 3. Vehicle Body Geometry based on Type
    switch (vehicle.type) {
      case TrafficVehicleType.hatchback:
        _drawHatchback(canvas, vehicle);
        break;
      case TrafficVehicleType.sedan:
        _drawSedan(canvas, vehicle);
        break;
      case TrafficVehicleType.suv:
        _drawSUV(canvas, vehicle);
        break;
      case TrafficVehicleType.sportsCar:
        _drawSportsCar(canvas, vehicle);
        break;
      case TrafficVehicleType.taxi:
        _drawTaxi(canvas, vehicle);
        break;
      case TrafficVehicleType.truck:
        _drawTruck(canvas, vehicle);
        break;
      case TrafficVehicleType.van:
        _drawVan(canvas, vehicle);
        break;
    }

    // 4. Taillights & Headlights
    _drawLights(canvas, vehicle);

    canvas.restore();
  }

  // --------------------------------------------------------------------------
  // 1. DYNAMIC VEHICLE SHADOW
  // --------------------------------------------------------------------------
  static void _drawShadow(Canvas canvas, TrafficVehicle vehicle) {
    final cfg = vehicle.config;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 4), width: cfg.width * 1.08, height: cfg.length * 1.02),
        const Radius.circular(12),
      ),
      shadowPaint,
    );
  }

  // --------------------------------------------------------------------------
  // 2. VEHICLE WHEELS & RIMS
  // --------------------------------------------------------------------------
  static void _drawWheels(Canvas canvas, TrafficVehicle vehicle) {
    final cfg = vehicle.config;
    final double halfW = cfg.width / 2;
    final double frontY = -cfg.length * 0.32;
    final double rearY = cfg.length * 0.32;

    final tirePaint = Paint()..color = const Color(0xFF0F172A);

    void drawTire(double wx, double wy) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(wx, wy), width: 7.5, height: 18),
          const Radius.circular(3),
        ),
        tirePaint,
      );
    }

    drawTire(-halfW - 1, frontY);
    drawTire(halfW + 1, frontY);
    drawTire(-halfW - 1, rearY);
    drawTire(halfW + 1, rearY);
  }

  // --------------------------------------------------------------------------
  // 3. VEHICLE SPECIFIC DESIGNS
  // --------------------------------------------------------------------------

  // 1. SMALL HATCHBACK
  static void _drawHatchback(Canvas canvas, TrafficVehicle v) {
    const double w = 38.0;
    const double l = 56.0;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: l),
      const Radius.circular(12),
    );

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [v.accentColor, v.primaryColor, v.primaryColor.withValues(alpha: 0.85)],
      ).createShader(Rect.fromLTWH(-w / 2, -l / 2, w, l));

    canvas.drawRRect(bodyRect, bodyPaint);

    // Compact Windshield & Rear Hatch
    final glassPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -16, 26, 12), const Radius.circular(4)),
      glassPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-12, 10, 24, 10), const Radius.circular(3)),
      glassPaint,
    );

    // Roof Center Panel
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -3, 20, 12), const Radius.circular(2)),
      Paint()..color = v.primaryColor,
    );
  }

  // 2. SEDAN
  static void _drawSedan(Canvas canvas, TrafficVehicle v) {
    const double w = 40.0;
    const double l = 68.0;

    final bodyPath = Path()
      ..moveTo(-w / 2 + 5, -l / 2)
      ..lineTo(w / 2 - 5, -l / 2)
      ..lineTo(w / 2, -l / 2 + 10)
      ..lineTo(w / 2, l / 2 - 8)
      ..lineTo(w / 2 - 4, l / 2)
      ..lineTo(-w / 2 + 4, l / 2)
      ..lineTo(-w / 2, l / 2 - 8)
      ..lineTo(-w / 2, -l / 2 + 10)
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [v.accentColor, v.primaryColor, const Color(0xFF1E293B)],
      ).createShader(Rect.fromLTWH(-w / 2, -l / 2, w, l));

    canvas.drawPath(bodyPath, bodyPaint);

    // Front Hood Crease
    canvas.drawLine(Offset(-w / 2 + 6, -l / 2 + 14), Offset(w / 2 - 6, -l / 2 + 14), Paint()..color = Colors.white.withValues(alpha: 0.3));

    // Windshield & Rear Glass
    final glassPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -18, 28, 14), const Radius.circular(4)), glassPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, 12, 26, 12), const Radius.circular(4)), glassPaint);

    // Roof Center Panel & Sunroof
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-11, -3, 22, 14), const Radius.circular(2)), Paint()..color = const Color(0xFF1E293B));
  }

  // 3. SUV
  static void _drawSUV(Canvas canvas, TrafficVehicle v) {
    const double w = 44.0;
    const double l = 74.0;

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: l),
      const Radius.circular(10),
    );

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [v.accentColor, v.primaryColor, const Color(0xFF0F172A)],
      ).createShader(Rect.fromLTWH(-w / 2, -l / 2, w, l));

    canvas.drawRRect(bodyRect, bodyPaint);

    // Rugged Roof Rails
    final railPaint = Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 2.0;
    canvas.drawLine(const Offset(-16, -18), const Offset(-16, 22), railPaint);
    canvas.drawLine(const Offset(16, -18), const Offset(16, 22), railPaint);

    // Wide Windshield & Panoramic Roof
    final glassPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-15, -20, 30, 16), const Radius.circular(4)), glassPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 16, 28, 12), const Radius.circular(3)), glassPaint);
  }

  // 4. SPORTS CAR
  static void _drawSportsCar(Canvas canvas, TrafficVehicle v) {
    const double w = 42.0;
    const double l = 70.0;

    final bodyPath = Path()
      ..moveTo(0, -l / 2)
      ..lineTo(w / 2 - 4, -l / 2 + 4)
      ..lineTo(w / 2, -l / 2 + 18)
      ..lineTo(w / 2 - 2, l / 2 - 6)
      ..lineTo(w / 2 - 6, l / 2)
      ..lineTo(-w / 2 + 6, l / 2)
      ..lineTo(-w / 2 + 2, l / 2 - 6)
      ..lineTo(-w / 2, -l / 2 + 18)
      ..lineTo(-w / 2 + 4, -l / 2 + 4)
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [v.accentColor, v.primaryColor, const Color(0xFF7F1D1D)],
      ).createShader(Rect.fromLTWH(-w / 2, -l / 2, w, l));

    canvas.drawPath(bodyPath, bodyPaint);

    // Carbon Hood Vents
    canvas.drawRect(const Rect.fromLTWH(-9, -24, 4, 8), Paint()..color = const Color(0xFF0F172A));
    canvas.drawRect(const Rect.fromLTWH(5, -24, 4, 8), Paint()..color = const Color(0xFF0F172A));

    // Sleek Windshield
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-13, -14, 26, 22), const Radius.circular(6)), Paint()..color = const Color(0xFF0F172A));

    // Elevated Rear Spoiler Wing
    final spoilerPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2 + 1, l / 2 - 4, w - 2, 5), const Radius.circular(2)), spoilerPaint);
  }

  // 5. TAXI
  static void _drawTaxi(Canvas canvas, TrafficVehicle v) {
    _drawSedan(canvas, v); // Base Sedan body

    // Taxi Checkerboard Stripe down the roof
    final blackPaint = Paint()..color = Colors.black;
    final whitePaint = Paint()..color = Colors.white;

    for (int i = -3; i <= 3; i++) {
      final paint = (i % 2 == 0) ? blackPaint : whitePaint;
      canvas.drawRect(Rect.fromLTWH(i * 4.0 - 2, -28, 4, 3), paint);
    }

    // Illuminated "TAXI" Roof Sign Box
    final signRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -6, 20, 8),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      signRect,
      Paint()
        ..color = const Color(0xFFFEF08A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(signRect, Paint()..color = const Color(0xFFFEF08A));

    final tp = TextPainter(
      text: const TextSpan(
        text: 'TAXI',
        style: TextStyle(color: Colors.black, fontSize: 5.5, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -5));
  }

  // 6. HEAVY TRUCK
  static void _drawTruck(Canvas canvas, TrafficVehicle v) {
    const double w = 46.0;
    const double l = 104.0;

    // 1. Cargo Box (Rear Container)
    final cargoRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-w / 2 + 2, -l / 2 + 32, w - 4, l - 34),
      const Radius.circular(4),
    );
    final cargoPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [v.accentColor, v.primaryColor, v.primaryColor.withValues(alpha: 0.8)],
      ).createShader(Rect.fromLTWH(-w / 2, -l / 2 + 32, w, l - 34));

    canvas.drawRRect(cargoRect, cargoPaint);

    // Corrugated Container Ridges
    final linePaint = Paint()..color = Colors.black.withValues(alpha: 0.2)..strokeWidth = 1.2;
    for (double ry = -l / 2 + 42; ry < l / 2 - 6; ry += 8) {
      canvas.drawLine(Offset(-w / 2 + 4, ry), Offset(w / 2 - 4, ry), linePaint);
    }

    // 2. Front Cab
    final cabRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-w / 2 + 1, -l / 2, w - 2, 30),
      const Radius.circular(6),
    );
    canvas.drawRRect(cabRect, Paint()..color = v.primaryColor);

    // Cab Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2 + 4, -l / 2 + 4, w - 8, 12), const Radius.circular(3)),
      Paint()..color = const Color(0xFF0F172A),
    );

    // Chrome Exhaust Stacks
    canvas.drawCircle(Offset(-w / 2 + 4, -l / 2 + 26), 2.2, Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawCircle(Offset(w / 2 - 4, -l / 2 + 26), 2.2, Paint()..color = const Color(0xFFE2E8F0));
  }

  // 7. DELIVERY VAN
  static void _drawVan(Canvas canvas, TrafficVehicle v) {
    const double w = 42.0;
    const double l = 78.0;

    final vanRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: l),
      const Radius.circular(8),
    );

    final vanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [v.accentColor, v.primaryColor, v.primaryColor],
      ).createShader(Rect.fromLTWH(-w / 2, -l / 2, w, l));

    canvas.drawRRect(vanRect, vanPaint);

    // Front Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-w / 2 + 4, -l / 2 + 6, w - 8, 14), const Radius.circular(3)),
      Paint()..color = const Color(0xFF0F172A),
    );

    // Rear Barn Doors Split Line
    canvas.drawLine(const Offset(0, -l / 2 + 26), Offset(0, l / 2 - 2), Paint()..color = const Color(0xFF334155)..strokeWidth = 1.2);
  }

  // --------------------------------------------------------------------------
  // 4. LIGHTS (HEADLIGHTS & TAILLIGHTS)
  // --------------------------------------------------------------------------
  static void _drawLights(Canvas canvas, TrafficVehicle vehicle) {
    final cfg = vehicle.config;
    final double halfW = cfg.width / 2;
    final double frontY = -cfg.length / 2;
    final double rearY = cfg.length / 2;

    // Glowing Front Headlights (Facing Forward)
    final headLightPaint = Paint()
      ..color = const Color(0xFFFEF08A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(-halfW + 5, frontY + 2), 2.5, headLightPaint);
    canvas.drawCircle(Offset(halfW - 5, frontY + 2), 2.5, headLightPaint);

    // Rear Dual Exhaust Pipes
    final exhaustPaint = Paint()..color = const Color(0xFF334155);
    canvas.drawCircle(Offset(-halfW + 7, rearY + 1), 2.2, exhaustPaint);
    canvas.drawCircle(Offset(halfW - 7, rearY + 1), 2.2, exhaustPaint);

    // Rear Taillights (Facing Backwards toward player) - Bright Vibrant LED
    final bool isBraking = vehicle.isBraking;
    final tailLightPaint = Paint()
      ..color = isBraking ? const Color(0xFFFF0055) : const Color(0xFFFF2222)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isBraking ? 6.0 : 4.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-halfW + 3, rearY - 4, 8, 4), const Radius.circular(1.5)),
      tailLightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(halfW - 11, rearY - 4, 8, 4), const Radius.circular(1.5)),
      tailLightPaint,
    );

    // Bright Core LED filament
    final corePaint = Paint()..color = const Color(0xFFFFCDD2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-halfW + 4, rearY - 3, 6, 2), const Radius.circular(1)),
      corePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(halfW - 10, rearY - 3, 6, 2), const Radius.circular(1)),
      corePaint,
    );
  }
}
