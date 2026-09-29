
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'game_config.dart';
import 'nitro_system.dart';
import 'player.dart';
import 'player_car.dart';
import 'traffic_vehicle.dart';
import 'obstacle.dart';
import 'coin.dart';
import 'power_up.dart';
import 'road_environment.dart';
import 'particle_manager.dart';
import 'near_miss_system.dart';

class CrazyRunnerPainter extends CustomPainter {
  final Player player;
  final List<Obstacle> obstacles;
  final List<TrafficVehicle>? trafficVehicles;
  final List<CollectibleItem> collectibles;
  final RoadEnvironment environment;
  final ParticleManager particleManager;
  final ui.Image? pandaImage;
  final double worldSpeed;
  final double score;
  final double distance;
  final bool isPlaying;
  final double nitroIntensity;
  final double nitroAnimPhase;
  final double cameraShakeTrauma;
  final double impactFlashOpacity;
  final double nearMissPulseIntensity;
  final Color nearMissPulseColor;
  final int nearMissOvertakeSide;
  final double animTime;

  CrazyRunnerPainter({
    super.repaint,
    required this.player,
    required this.obstacles,
    this.trafficVehicles,
    required this.collectibles,
    required this.environment,
    required this.particleManager,
    this.pandaImage,
    required this.worldSpeed,
    required this.score,
    required this.distance,
    required this.isPlaying,
    this.nitroIntensity = 0.0,
    this.nitroAnimPhase = 0.0,
    this.cameraShakeTrauma = 0.0,
    this.impactFlashOpacity = 0.0,
    this.nearMissPulseIntensity = 0.0,
    this.nearMissPulseColor = const Color(0xFF00FF66),
    this.nearMissOvertakeSide = 0,
    this.animTime = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Horizon line at ~18% from top
    final double horizonY = height * 0.18;
    final double roadTopWidth = width * 0.44;
    final double roadBottomWidth = width * 0.94;
    final double roadLeft = (width - roadBottomWidth) / 2;
    final double roadRight = roadLeft + roadBottomWidth;
    final double laneWidth = roadBottomWidth / GameConfig.totalLanes;
    final double playerY = height * 0.82;

    // 0. Camera Shake Trauma Dynamic Offset (High-Frequency Trauma Decay)
    final bool hasCameraShake = cameraShakeTrauma > 0.001;
    if (hasCameraShake) {
      canvas.save();
      final double traumaQuad = cameraShakeTrauma * cameraShakeTrauma;
      final double shakeMagnitude = traumaQuad * 18.0;
      final double shakeX = sin(animTime * 52.0) * shakeMagnitude;
      final double shakeY = cos(animTime * 42.0) * shakeMagnitude * 0.75;
      final double shakeRoll = sin(animTime * 36.0) * traumaQuad * 0.045;
      canvas.translate(width / 2, height / 2);
      canvas.rotate(shakeRoll);
      canvas.translate(-width / 2 + shakeX, -height / 2 + shakeY);
    }

    // Optional Camera FOV Zoom when Nitro Boost is engaged
    final bool hasCameraZoom = nitroIntensity > 0.001;
    if (hasCameraZoom) {
      canvas.save();
      final double zoom = 1.0 + nitroIntensity * 0.06;
      canvas.translate(width / 2, playerY);
      canvas.scale(zoom, zoom);
      canvas.translate(-width / 2, -playerY);
    }

    // 1-3. Draw Complete Modular Endless Road Environment (Sky, Shoulders, Asphalt, Imperfections, Dividers, Curbs)
    RoadVisualRenderer.drawCompleteRoadEnvironment(
      canvas: canvas,
      size: size,
      roadSystem: environment,
      horizonY: horizonY,
      roadTopWidth: roadTopWidth,
      roadBottomWidth: roadBottomWidth,
      roadLeft: roadLeft,
      roadRight: roadRight,
      laneWidth: laneWidth,
      laneProgress: player.laneProgress,
    );

    // 4. Draw Shadows & Collectibles (Coins, Gems, Power-ups, Nitro Canisters)
    _drawCollectibles(canvas, width, height, horizonY, roadTopWidth, roadBottomWidth);

    // 4b. Dynamic Forward Headlight Beam Projections (Evening / Night Visibility)
    _drawPlayerHeadlightBeams(canvas, width, height, horizonY, roadTopWidth, roadBottomWidth, playerY);

    // 5. Draw Obstacles (Hurdles, Overhead Beams, Roadblocks)
    _drawObstacles(canvas, width, height, horizonY, roadTopWidth, roadBottomWidth);

    // 5b. Draw AI Traffic Vehicles (7 Distinct Types) - Kept strictly within road lanes
    _drawTrafficVehicles(canvas, width, height, horizonY, roadTopWidth, roadBottomWidth);

    // 6. Draw Player Runner Character
    _drawPlayer(canvas, width, height, horizonY, roadTopWidth, roadBottomWidth, playerY);

    // 7. Draw Particle Effects & Floating Scores
    _drawParticles(canvas);

    // Restore Camera Zoom
    if (hasCameraZoom) {
      canvas.restore();
    }

    // Restore Camera Shake
    if (hasCameraShake) {
      canvas.restore();
    }

    // 8. Screen-Space Motion Blur Aura & Radial Speed Lines (Drawn in unscaled screen coordinates)
    if (nitroIntensity > 0.001) {
      NitroVisualRenderer.drawMotionBlurAura(canvas, size, nitroIntensity);
      NitroVisualRenderer.drawSpeedLines(canvas, size, nitroIntensity, horizonY, nitroAnimPhase);
    }

    // 9. Full-Screen White / Amber Impact Flash (Responsive Crash Shockwave)
    if (impactFlashOpacity > 0.005) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: impactFlashOpacity.clamp(0.0, 1.0));
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), flashPaint);
    }

    // 10. Near Miss & Combo Screen Edge Pulse Vignette & Overtake Speed Streaks
    if (nearMissPulseIntensity > 0.005) {
      NearMissVisualRenderer.drawScreenPulse(
        canvas,
        size,
        nearMissPulseIntensity,
        nearMissPulseColor,
      );
      NearMissVisualRenderer.drawOvertakeStreaks(
        canvas: canvas,
        size: size,
        intensity: nearMissPulseIntensity,
        color: nearMissPulseColor,
        playerY: playerY,
        overtakeSide: nearMissOvertakeSide,
        animTime: animTime,
      );
    }
  }

  // ==========================================
  // ROAD PERSPECTIVE PROJECTION HELPERS
  // ==========================================
  double _getPerspectiveProgress(double y, double height, double horizonY) {
    return ((y - horizonY) / (height - horizonY)).clamp(0.0, 1.0);
  }

  double _getLaneX(
    double laneProgress,
    double y,
    double width,
    double height,
    double horizonY,
    double roadTopWidth,
    double roadBottomWidth,
  ) {
    final double p = _getPerspectiveProgress(y, height, horizonY);
    final double roadTopLeft = (width - roadTopWidth) / 2;
    final double roadBottomLeft = (width - roadBottomWidth) / 2;
    final double currentRoadLeft = roadTopLeft + (roadBottomLeft - roadTopLeft) * p;
    final double currentRoadWidth = roadTopWidth + (roadBottomWidth - roadTopWidth) * p;
    final double currentLaneWidth = currentRoadWidth / GameConfig.totalLanes;
    return currentRoadLeft + (laneProgress + 0.5) * currentLaneWidth;
  }

  double _getLaneWidth(
    double y,
    double width,
    double height,
    double horizonY,
    double roadTopWidth,
    double roadBottomWidth,
  ) {
    final double p = _getPerspectiveProgress(y, height, horizonY);
    final double currentRoadWidth = roadTopWidth + (roadBottomWidth - roadTopWidth) * p;
    return currentRoadWidth / GameConfig.totalLanes;
  }

  double _getPerspectiveScale(double y, double height, double horizonY) {
    final double p = _getPerspectiveProgress(y, height, horizonY);
    // Smooth readable arcade perspective: clear, distinct vehicles in far distance (~0.42) scaling cleanly to 1.0 at player depth
    return (0.42 + 0.58 * (p * 0.70 + p * p * 0.30)).clamp(0.40, 1.0);
  }

  void _drawPlayerHeadlightBeams(
    Canvas canvas,
    double width,
    double height,
    double horizonY,
    double roadTopWidth,
    double roadBottomWidth,
    double playerY,
  ) {
    final double intensity = environment.theme.headlightIntensity;
    if (intensity < 0.08) return;

    final double px = _getLaneX(player.laneProgress, playerY, width, height, horizonY, roadTopWidth, roadBottomWidth);
    final double py = playerY - player.jumpY;

    final Color beamColor = (environment.theme.timeState == TimeOfDayState.night)
        ? const Color(0xFF00F2FE)
        : const Color(0xFFFEF08A);

    final Paint beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          beamColor.withValues(alpha: 0.38 * intensity),
          beamColor.withValues(alpha: 0.12 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(px - 70, py - 260, 140, 260));

    final Path leftBeam = Path()
      ..moveTo(px - 18, py - 35)
      ..lineTo(px - 60, py - 240)
      ..lineTo(px - 6, py - 240)
      ..lineTo(px - 8, py - 35)
      ..close();
    canvas.drawPath(leftBeam, beamPaint);

    final Path rightBeam = Path()
      ..moveTo(px + 8, py - 35)
      ..lineTo(px + 6, py - 240)
      ..lineTo(px + 60, py - 240)
      ..lineTo(px + 18, py - 35)
      ..close();
    canvas.drawPath(rightBeam, beamPaint);
  }

  void _drawTrafficVehicles(
    Canvas canvas,
    double width,
    double height,
    double horizonY,
    double roadTopWidth,
    double roadBottomWidth,
  ) {
    if (trafficVehicles == null) return;
    for (final v in trafficVehicles!) {
      if (!v.active || v.y < horizonY - 10.0) continue;
      final double vy = v.y;
      final double vx = _getLaneX(v.lane.toDouble(), vy, width, height, horizonY, roadTopWidth, roadBottomWidth);
      final double currentLaneWidth = _getLaneWidth(vy, width, height, horizonY, roadTopWidth, roadBottomWidth);
      final double scale = _getPerspectiveScale(vy, height, horizonY) * 1.22;

      canvas.save();
      canvas.translate(vx, vy);
      canvas.scale(scale, scale);
      TrafficVehicleVisual.drawVehicle(canvas, v, currentLaneWidth / scale);
      canvas.restore();
    }
  }

  // ==========================================
  // 4. COLLECTIBLES & POWER-UPS
  // ==========================================
  void _drawCollectibles(
    Canvas canvas,
    double width,
    double height,
    double horizonY,
    double roadTopWidth,
    double roadBottomWidth,
  ) {
    for (final item in collectibles) {
      if (item.collected || !item.active) continue;

      final double cy = item.y - item.heightOffset;
      final double cx = _getLaneX(item.lane + item.horizontalOffset, item.y, width, height, horizonY, roadTopWidth, roadBottomWidth);
      final double scale = _getPerspectiveScale(item.y, height, horizonY);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale, scale);

      // Ground Shadow (scales & fades based on height elevation)
      final double shadowAlpha = (0.35 * (1.0 - (item.heightOffset / 100.0))).clamp(0.08, 0.35);
      final double shadowScale = (1.0 - (item.heightOffset / 140.0)).clamp(0.4, 1.0);
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: shadowAlpha);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, item.heightOffset + 12), width: 28 * shadowScale, height: 10 * shadowScale),
        shadowPaint,
      );

      // Draw Collectible Type
      switch (item.type) {
        case CollectibleType.goldCoin:
          CoinVisual.drawCoin(canvas, 0, 0, item.spinPhase);
          break;
        case CollectibleType.gem:
          _drawCrystalGem(canvas, 0, 0);
          break;
        case CollectibleType.shield:
          PowerUpVisual.drawPowerUpOrb(canvas, PowerUpType.shield, 0, 0, item.spinPhase);
          break;
        case CollectibleType.magnet:
          PowerUpVisual.drawPowerUpOrb(canvas, PowerUpType.magnet, 0, 0, item.spinPhase);
          break;
        case CollectibleType.multiplier2x:
          PowerUpVisual.drawPowerUpOrb(canvas, PowerUpType.coinMultiplier, 0, 0, item.spinPhase);
          break;
        case CollectibleType.speedBoost:
          PowerUpVisual.drawPowerUpOrb(canvas, PowerUpType.speedBoost, 0, 0, item.spinPhase);
          break;
        case CollectibleType.slowMotion:
          PowerUpVisual.drawPowerUpOrb(canvas, PowerUpType.slowMotion, 0, 0, item.spinPhase);
          break;
        case CollectibleType.invincibility:
          PowerUpVisual.drawPowerUpOrb(canvas, PowerUpType.invincibility, 0, 0, item.spinPhase);
          break;
        case CollectibleType.nitroCanister:
          NitroVisualRenderer.drawNitroCanister(canvas, 0, 0, item.spinPhase);
          break;
      }
      canvas.restore();
    }
  }

  void _drawCrystalGem(Canvas canvas, double cx, double cy) {
    canvas.save();
    canvas.translate(cx, cy);

    // Glowing Radial Aura (Zero MaskFilter GPU offscreen cost)
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.5),
          const Color(0xFF38BDF8).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: 24.0));
    canvas.drawCircle(Offset.zero, 24.0, auraPaint);

    // Diamond Polygon Path
    final Path gemPath = Path()
      ..moveTo(0, -16)
      ..lineTo(14, -4)
      ..lineTo(0, 16)
      ..lineTo(-14, -4)
      ..close();

    final gemPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0284C7)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(-14, -16, 28, 32));

    canvas.drawPath(gemPath, gemPaint);

    // White Specular Highlight
    final shinePaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final Path shinePath = Path()
      ..moveTo(0, -14)
      ..lineTo(10, -4)
      ..lineTo(0, 0)
      ..lineTo(-10, -4)
      ..close();
    canvas.drawPath(shinePath, shinePaint);

    canvas.restore();
  }

  // ==========================================
  // 5. OBSTACLES (MODULAR 9-TYPE 3D VECTORS)
  // ==========================================
  void _drawObstacles(
    Canvas canvas,
    double width,
    double height,
    double horizonY,
    double roadTopWidth,
    double roadBottomWidth,
  ) {
    for (final obs in obstacles) {
      if (obs.cleared || obs.y < horizonY - 10.0) continue;
      final double oy = obs.y;
      final double ox = _getLaneX(obs.lane + obs.horizontalOffset, oy, width, height, horizonY, roadTopWidth, roadBottomWidth);
      final double currentLaneWidth = _getLaneWidth(oy, width, height, horizonY, roadTopWidth, roadBottomWidth);
      final double scale = _getPerspectiveScale(oy, height, horizonY) * 1.15;

      canvas.save();
      canvas.translate(ox, oy);
      canvas.scale(scale, scale);
      ObstacleVisual.drawObstacle(canvas, obs, currentLaneWidth / scale);
      canvas.restore();
    }
  }

  // ==========================================
  // 6. PLAYER SPORTS CAR (MODULAR 60 FPS RENDERER)
  // ==========================================
  void _drawPlayer(
    Canvas canvas,
    double width,
    double height,
    double horizonY,
    double roadTopWidth,
    double roadBottomWidth,
    double playerY,
  ) {
    final double px = _getLaneX(player.laneProgress, playerY, width, height, horizonY, roadTopWidth, roadBottomWidth);
    final double py = playerY - player.jumpY;

    canvas.save();
    canvas.translate(px, py);

    // 1. Running ground dust particles
    if (player.state == PlayerActionState.running && isPlaying) {
      particleManager.spawnRunningDust(px, playerY + 32.0);
    }

    // 2. Active Power-Up In-Game Auras
    if (player.hasShield) {
      PowerUpVisual.drawShieldAura(canvas, player);
    }

    if (player.isMagnetActive) {
      PowerUpVisual.drawMagnetAura(canvas, player);
    }

    if (player.isMultiplierActive) {
      PowerUpVisual.drawMultiplierAura(canvas, player);
    }

    if (player.isSpeedBoostActive) {
      PowerUpVisual.drawSpeedBoostAura(canvas, player, const Size(60, 90));
    }

    if (player.isSlowMoActive) {
      PowerUpVisual.drawSlowMotionAura(canvas, player);
    }

    if (player.isInvincible) {
      PowerUpVisual.drawInvincibilityAura(canvas, player);
    }

    // 3. Delegate to Modular PlayerCarVisual
    final double jumpRatio = (player.jumpY / GameConfig.jumpMaxHeight).clamp(0.0, 1.0);
    final params = CarRenderParams(
      state: player.carAnimationState,
      speed: isPlaying ? worldSpeed : 0.0,
      laneTilt: player.laneTilt,
      steerAngle: player.steerAngle,
      suspensionBounce: player.suspensionBounce,
      wheelRotation: player.wheelRotation,
      hitFlashProgress: (player.hitFlashTimer > 0) ? 1.0 : 0.0,
      jumpElevation: jumpRatio,
      isShieldActive: player.hasShield,
      isMagnetActive: player.isMagnetActive,
      isMultiplierActive: player.isMultiplierActive,
      nitroIntensity: nitroIntensity,
      isNitroActive: nitroIntensity > 0.1,
      crashSpinAngle: player.crashSpinAngle,
      crashShakeX: player.crashShakeX,
      crashShakeY: player.crashShakeY,
      theme: player.carTheme,
      customSpriteImage: null, // Ready for custom sprite drop-in if needed
    );

    // 3. Delegate to Modular PlayerCarVisual (scaled up for bolder, premium arcade presence)
    canvas.save();
    canvas.scale(1.24, 1.24);
    canvas.translate(-30.0, -45.0);
    PlayerCarVisual.drawCar(
      canvas,
      const Size(60, 90),
      params,
    );
    canvas.restore();

    canvas.restore();
  }

  // ==========================================
  // 7. PARTICLES & FLOATING SCORES
  // ==========================================
  void _drawParticles(Canvas canvas) {
    // Draw High-Performance 60 FPS Particle FX
    for (final p in particleManager.particles) {
      if (p.isSmoke) {
        // Soft expanding smoke puff with efficient alpha
        final smokePaint = Paint()
          ..color = p.color.withValues(alpha: (p.life * 0.55).clamp(0.0, 0.75))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(p.x, p.y), p.size, smokePaint);
      } else if (p.isDebris) {
        // Metallic / Carbon Bodywork Tumbling Shard
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.rotation);
        final shardPath = Path()
          ..moveTo(-p.size * 0.6, -p.size * 0.35)
          ..lineTo(p.size * 0.7, -p.size * 0.2)
          ..lineTo(p.size * 0.45, p.size * 0.6)
          ..lineTo(-p.size * 0.5, p.size * 0.45)
          ..close();
        final debrisPaint = Paint()
          ..color = p.color.withValues(alpha: (p.life * 1.2).clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawPath(shardPath, debrisPaint);
        canvas.restore();
      } else if (p.isStar) {
        // High-energy electric spark / star
        final sparkPaint = Paint()
          ..color = p.color.withValues(alpha: (p.life * 1.5).clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(p.x, p.y), p.size * p.life, sparkPaint);
      } else {
        final regularPaint = Paint()
          ..color = p.color.withValues(alpha: (p.life * 1.5).clamp(0.0, 1.0))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(p.x, p.y), p.size * p.life, regularPaint);
      }
    }

    // Draw Floating Score Texts
    for (final f in particleManager.floatingTexts) {
      final textSpan = TextSpan(
        text: f.text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: f.color.withValues(alpha: f.opacity),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(f.x - textPainter.width / 2, f.y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CrazyRunnerPainter oldDelegate) => true;
}
