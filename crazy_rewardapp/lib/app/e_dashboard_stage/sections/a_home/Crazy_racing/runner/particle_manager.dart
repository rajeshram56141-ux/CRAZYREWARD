import 'dart:math';
import 'package:flutter/material.dart';

class GameParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double life; // 1.0 -> 0.0
  double decay;
  bool isStar;
  bool isSmoke;
  bool isDebris;
  double rotation;
  double vRotation;

  GameParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    this.life = 1.0,
    this.decay = 0.04,
    this.isStar = false,
    this.isSmoke = false,
    this.isDebris = false,
    this.rotation = 0.0,
    this.vRotation = 0.0,
  });

  void update() {
    x += vx;
    y += vy;
    rotation += vRotation;

    if (isSmoke) {
      vy -= 0.04; // Smoke gently rises
      size += 0.22; // Smoke expands as it billows
      vx *= 0.96; // Air drag
    } else if (isDebris) {
      vy += 0.22; // Heavy gravity on shards
      vx *= 0.98;
    } else {
      vy += 0.15; // Standard Gravity
    }

    life -= decay;
  }
}

class FloatingScoreText {
  double x;
  double y;
  final String text;
  final Color color;
  double opacity;
  double life;

  FloatingScoreText({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    this.opacity = 1.0,
    this.life = 1.0,
  });

  void update() {
    y -= 1.8;
    life -= 0.035;
    opacity = (life * 1.5).clamp(0.0, 1.0);
  }
}

class ParticleManager {
  final List<GameParticle> particles = [];
  final List<FloatingScoreText> floatingTexts = [];
  final Random _random = Random();

  void clear() {
    particles.clear();
    floatingTexts.clear();
  }

  void update() {
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.update();
      if (p.life <= 0) {
        particles.removeAt(i);
      }
    }

    for (int i = floatingTexts.length - 1; i >= 0; i--) {
      final f = floatingTexts[i];
      f.update();
      if (f.life <= 0) {
        floatingTexts.removeAt(i);
      }
    }
  }

  void spawnCoinPickup(double x, double y) {
    const palette = [
      Color(0xFFFFD700),
      Color(0xFFFFF7C2),
      Color(0xFFFFB300),
      Color(0xFFFFA000),
      Color(0xFFFFFFFF),
    ];

    for (int i = 0; i < 12; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 2.5 + _random.nextDouble() * 5.0;
      particles.add(GameParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 1.5,
        color: palette[_random.nextInt(palette.length)],
        size: 3.5 + _random.nextDouble() * 3.5,
        decay: 0.045,
        isStar: _random.nextBool(),
      ));
    }
  }

  void spawnGemPickup(double x, double y) {
    const palette = [
      Color(0xFF38BDF8),
      Color(0xFF818CF8),
      Color(0xFFC084FC),
      Color(0xFFE0F2FE),
      Color(0xFFFFFFFF),
    ];

    for (int i = 0; i < 18; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.5 + _random.nextDouble() * 6.5;
      particles.add(GameParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 2.0,
        color: palette[_random.nextInt(palette.length)],
        size: 4.5 + _random.nextDouble() * 4.0,
        decay: 0.04,
        isStar: true,
      ));
    }
  }

  void spawnRunningDust(double x, double y) {
    if (particles.length > 60) return;
    for (int i = 0; i < 2; i++) {
      particles.add(GameParticle(
        x: x + (_random.nextDouble() - 0.5) * 16.0,
        y: y,
        vx: (_random.nextDouble() - 0.5) * 2.0,
        vy: -0.5 - _random.nextDouble() * 1.5,
        color: Colors.white.withValues(alpha: 0.35),
        size: 2.5 + _random.nextDouble() * 3.0,
        decay: 0.08,
      ));
    }
  }

  void spawnJumpDust(double x, double y) {
    for (int i = 0; i < 8; i++) {
      final vx = (_random.nextDouble() - 0.5) * 5.0;
      particles.add(GameParticle(
        x: x,
        y: y,
        vx: vx,
        vy: -0.8 - _random.nextDouble() * 2.0,
        color: Colors.white.withValues(alpha: 0.5),
        size: 3.5 + _random.nextDouble() * 3.5,
        decay: 0.06,
      ));
    }
  }

  void spawnCrashImpact(double x, double y) {
    spawnCarCrashFX(x, y);
  }

  /// Polished Comprehensive Car Crash Effects:
  /// Sparks + Billowing Smoke Plumes + Metal/Bumper Shards + Explosion Embers
  void spawnCarCrashFX(double x, double y) {
    // 1. High-Velocity Fiery Friction Sparks
    const sparkPalette = [
      Color(0xFFFFD700), // Electric Gold
      Color(0xFFFF9100), // Blazing Amber
      Color(0xFFFF3D00), // Fiery Orange
      Color(0xFFFFFFFF), // White-Hot Core
    ];

    for (int i = 0; i < 30; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 4.5 + _random.nextDouble() * 9.5;
      particles.add(GameParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 2.8,
        color: sparkPalette[_random.nextInt(sparkPalette.length)],
        size: 3.2 + _random.nextDouble() * 3.8,
        decay: 0.038,
        isStar: _random.nextBool(),
      ));
    }

    // 2. Heavy Billowing Smoke Plumes
    const smokePalette = [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
      Color(0xFF334155),
      Color(0xFF475569),
    ];

    for (int i = 0; i < 18; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 1.0 + _random.nextDouble() * 3.2;
      particles.add(GameParticle(
        x: x + (_random.nextDouble() - 0.5) * 24.0,
        y: y + (_random.nextDouble() - 0.5) * 16.0,
        vx: cos(angle) * speed,
        vy: -1.2 - _random.nextDouble() * 2.2,
        color: smokePalette[_random.nextInt(smokePalette.length)],
        size: 14.0 + _random.nextDouble() * 12.0,
        decay: 0.024,
        isSmoke: true,
      ));
    }

    // 3. Small Metallic / Carbon Debris Shards (Spinning Fragments)
    const debrisPalette = [
      Color(0xFFEF4444), // Red bodywork fragment
      Color(0xFF0F172A), // Carbon fiber black
      Color(0xFF94A3B8), // Aluminum bumper silver
      Color(0xFFE2E8F0), // Chrome trim
    ];

    for (int i = 0; i < 16; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 3.5 + _random.nextDouble() * 7.5;
      particles.add(GameParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 3.8,
        color: debrisPalette[_random.nextInt(debrisPalette.length)],
        size: 5.5 + _random.nextDouble() * 4.5,
        decay: 0.032,
        rotation: _random.nextDouble() * 2 * pi,
        vRotation: (_random.nextDouble() - 0.5) * 10.0,
        isDebris: true,
      ));
    }
  }

  void spawnCountdownGoBurst(double x, double y) {
    const palette = [
      Color(0xFF00FF66), // Neon High-Energy Green
      Color(0xFF22C55E), // Emerald Green
      Color(0xFF00F2FE), // Electric Cyan
      Color(0xFFFFD700), // Gold Sparkle
      Color(0xFFFFFFFF), // Pure White
    ];

    for (int i = 0; i < 36; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 4.5 + _random.nextDouble() * 10.0;
      particles.add(GameParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 1.0,
        color: palette[_random.nextInt(palette.length)],
        size: 5.0 + _random.nextDouble() * 5.0,
        decay: 0.038,
        isStar: _random.nextBool(),
      ));
    }
  }

  void spawnNearMissSparks(double x, double y, {Color color = const Color(0xFF00FF66)}) {
    for (int i = 0; i < 14; i++) {
      final double angle = _random.nextDouble() * 2 * pi;
      final double speed = 3.0 + _random.nextDouble() * 5.5;
      particles.add(GameParticle(
        x: x + (_random.nextDouble() - 0.5) * 12.0,
        y: y + (_random.nextDouble() - 0.5) * 20.0,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 1.5,
        color: color,
        size: 3.5 + _random.nextDouble() * 3.0,
        decay: 0.05,
        isStar: _random.nextBool(),
      ));
    }
  }

  void spawnFloatingText(double x, double y, String text, Color color) {
    if (floatingTexts.length > 8) return;
    floatingTexts.add(FloatingScoreText(
      x: x,
      y: y - 20.0,
      text: text,
      color: color,
    ));
  }
}

