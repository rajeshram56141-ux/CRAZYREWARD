import 'dart:math';
import 'package:flutter/material.dart';
import 'game_config.dart';
import 'player_car.dart';

enum PlayerActionState {
  running,
  jumping,
  sliding,
  hit,
  dead,
}

class Player {
  // Lane positions: 0 = Left, 1 = Center, 2 = Right
  int currentLane = 1;
  int targetLane = 1;
  double laneProgress = 1.0; // 0.0 -> 1.0 -> 2.0 smooth position

  // Physics & Animation States
  PlayerActionState state = PlayerActionState.running;
  double jumpTimer = 0.0;
  double jumpY = 0.0;
  double slideTimer = 0.0;
  double runCycle = 0.0; // 0.0 to 1.0 step cycle
  double hitFlashTimer = 0.0;
  double invulnerableTimer = 0.0;

  // Car Physics Dynamics
  double laneTilt = 0.0; // Dynamic banking roll angle (-0.24 to +0.24 rad)
  double steerAngle = 0.0; // Front wheel steer angle
  double wheelRotation = 0.0; // 0 to 2*pi rotating wheel cycle
  double suspensionBounce = 0.0; // Vertical micro bounce
  double laneSwitchSpeed = GameConfig.laneSwitchSpeed;
  PlayerCarTheme carTheme = PlayerCarTheme.red;

  // Crash Physics & Shudder Dynamics
  double crashTimer = 0.0;
  double crashSpinAngle = 0.0;
  double crashShakeX = 0.0;
  double crashShakeY = 0.0;
  bool crashSpinLeft = true;

  // 6 Core Power-Ups State (Safety Wall Shield, Magnet, Multiplier, Nitro, Slow-Mo, Invincible)
  double shieldTimer = 0.0;
  double maxShieldDuration = 10.0;
  bool get hasShield => shieldTimer > 0;
  set hasShield(bool value) {
    if (value) {
      activateShield(10.0);
    } else {
      shieldTimer = 0.0;
    }
  }

  double magnetTimer = 0.0;
  double maxMagnetDuration = 8.5;
  double multiplierTimer = 0.0;
  double maxMultiplierDuration = 9.0;
  double speedBoostTimer = 0.0;
  double maxSpeedBoostDuration = 6.0;
  double slowMoTimer = 0.0;
  double maxSlowMoDuration = 7.0;
  double invincibleTimer = 0.0;
  double maxInvincibleDuration = 6.5;

  // Lives / Chances
  int lives = GameConfig.defaultLives;

  void reset() {
    currentLane = 1;
    targetLane = 1;
    laneProgress = 1.0;
    state = PlayerActionState.running;
    jumpTimer = 0.0;
    jumpY = 0.0;
    slideTimer = 0.0;
    runCycle = 0.0;
    hitFlashTimer = 0.0;
    invulnerableTimer = 0.0;
    laneTilt = 0.0;
    steerAngle = 0.0;
    wheelRotation = 0.0;
    suspensionBounce = 0.0;
    crashTimer = 0.0;
    crashSpinAngle = 0.0;
    crashShakeX = 0.0;
    crashShakeY = 0.0;
    crashSpinLeft = true;
    shieldTimer = 0.0;
    magnetTimer = 0.0;
    multiplierTimer = 0.0;
    speedBoostTimer = 0.0;
    slowMoTimer = 0.0;
    invincibleTimer = 0.0;
    lives = GameConfig.defaultLives;
  }

  void resetAfterRevive() {
    state = PlayerActionState.running;
    jumpTimer = 0.0;
    jumpY = 0.0;
    slideTimer = 0.0;
    runCycle = 0.0;
    hitFlashTimer = 0.0;
    crashTimer = 0.0;
    crashSpinAngle = 0.0;
    crashShakeX = 0.0;
    crashShakeY = 0.0;
    laneTilt = 0.0;
    steerAngle = 0.0;
    suspensionBounce = 0.0;
    invulnerableTimer = 3.5; // 3.5s invulnerability so player doesn't instantly crash again
    activateShield(10.0); // 10s safety wall protection upon revive
    lives = GameConfig.defaultLives;
  }

  void moveLeft() {
    if (state == PlayerActionState.dead) return;
    if (targetLane > 0) {
      targetLane--;
    }
  }

  void moveRight() {
    if (state == PlayerActionState.dead) return;
    if (targetLane < GameConfig.totalLanes - 1) {
      targetLane++;
    }
  }

  bool jump() {
    if (state == PlayerActionState.dead) return false;
    if (state == PlayerActionState.jumping) return false;

    state = PlayerActionState.jumping;
    jumpTimer = 0.0;
    jumpY = 0.0;
    slideTimer = 0.0; // Cancel slide if jumping
    return true;
  }

  bool slide() {
    if (state == PlayerActionState.dead) return false;
    if (state == PlayerActionState.sliding) return false;

    // Fast-drop if in air
    if (state == PlayerActionState.jumping) {
      jumpY = 0.0;
      jumpTimer = GameConfig.jumpDuration;
    }

    state = PlayerActionState.sliding;
    slideTimer = GameConfig.slideDuration;
    return true;
  }

  // ----------------------------------------------------
  // Power-Up Activations
  // ----------------------------------------------------
  void activateShield([double durationSeconds = 10.0]) {
    maxShieldDuration = durationSeconds;
    shieldTimer = durationSeconds;
  }

  void consumeShield() {
    shieldTimer = 0.0;
    invulnerableTimer = 1.0;
    hitFlashTimer = 0.4;
  }

  void activateMagnet(double durationSeconds) {
    maxMagnetDuration = durationSeconds;
    magnetTimer = max(magnetTimer, durationSeconds);
  }

  void activateMultiplier(double durationSeconds) {
    maxMultiplierDuration = durationSeconds;
    multiplierTimer = max(multiplierTimer, durationSeconds);
  }

  void activateSpeedBoost(double durationSeconds) {
    maxSpeedBoostDuration = durationSeconds;
    speedBoostTimer = max(speedBoostTimer, durationSeconds);
  }

  void activateSlowMo(double durationSeconds) {
    maxSlowMoDuration = durationSeconds;
    slowMoTimer = max(slowMoTimer, durationSeconds);
  }

  void activateInvincibility(double durationSeconds) {
    maxInvincibleDuration = durationSeconds;
    invincibleTimer = max(invincibleTimer, durationSeconds);
  }

  void triggerSpinout({double duration = 0.8}) {
    if (state == PlayerActionState.dead || isInvincible) return;
    laneTilt = 0.24;
    steerAngle = -0.30;
    hitFlashTimer = 0.3;
    invulnerableTimer = duration;
  }

  void triggerSuspensionJolt({double force = 4.5}) {
    if (state == PlayerActionState.dead) return;
    suspensionBounce = force;
  }

  void triggerCrash({bool spinLeft = true}) {
    state = PlayerActionState.dead;
    crashTimer = 0.0;
    crashSpinAngle = 0.0;
    crashShakeX = 0.0;
    crashShakeY = 0.0;
    crashSpinLeft = spinLeft;
    hitFlashTimer = 0.8;
  }

  bool takeDamage({bool spinLeft = true}) {
    if (isInvincible || isInvulnerable || state == PlayerActionState.dead) return false;

    if (hasShield) {
      consumeShield(); // Safety wall / shield absorbs hit and gets immediately removed!
      return false; // Shield absorbed damage!
    }

    lives = 0;
    triggerCrash(spinLeft: spinLeft);
    return true;
  }

  bool get isInvincible => invincibleTimer > 0;
  bool get isInvulnerable => invulnerableTimer > 0 || isInvincible;
  bool get isMagnetActive => magnetTimer > 0;
  bool get isMultiplierActive => multiplierTimer > 0;
  bool get isSpeedBoostActive => speedBoostTimer > 0;
  bool get isSlowMoActive => slowMoTimer > 0;

  /// Dynamic 7-state Car Animation Status
  CarAnimationState get carAnimationState {
    if (state == PlayerActionState.dead) {
      return CarAnimationState.destroyed;
    }
    if (hitFlashTimer > 0) {
      return CarAnimationState.collision;
    }
    if (state == PlayerActionState.sliding) {
      return CarAnimationState.braking;
    }
    if (laneTilt < -0.04) {
      return CarAnimationState.laneChangeLeft;
    }
    if (laneTilt > 0.04) {
      return CarAnimationState.laneChangeRight;
    }
    return CarAnimationState.driving;
  }

  void update(double dt, double worldSpeed) {
    // 0. Crash Physics Dynamics (Rapid high-frequency chassis shudder & spinout)
    if (state == PlayerActionState.dead) {
      crashTimer += dt;
      final double intensity = max(0.0, 1.0 - (crashTimer / 0.85));
      crashShakeX = sin(crashTimer * 58.0) * 8.0 * intensity;
      crashShakeY = cos(crashTimer * 46.0) * 5.0 * intensity;

      final double spinSpeed = max(0.0, 14.0 * (1.0 - (crashTimer / 0.85)));
      crashSpinAngle += (crashSpinLeft ? -1.0 : 1.0) * spinSpeed * dt;

      laneTilt *= 0.92;
      steerAngle *= 0.90;
      suspensionBounce = 0.0;
      wheelRotation = (wheelRotation + dt * (worldSpeed / 7.0)) % (2 * pi);
      return;
    }

    // 1. Smooth Lane Interpolation & Dynamic Banking Roll Tilt
    final double diff = targetLane.toDouble() - laneProgress;
    if (diff.abs() > 0.001) {
      laneProgress += diff * min(1.0, dt * laneSwitchSpeed);
      if ((targetLane.toDouble() - laneProgress).abs() < 0.01) {
        laneProgress = targetLane.toDouble();
        currentLane = targetLane;
      }
    }

    // Vehicle Dynamic Roll Tilt (leans into the lane direction)
    final double targetTilt = (diff * 0.22).clamp(-0.22, 0.22);
    laneTilt += (targetTilt - laneTilt) * min(1.0, dt * 14.0);

    // Front Wheel Steering Angle
    final double targetSteer = (diff * 0.35).clamp(-0.30, 0.30);
    steerAngle += (targetSteer - steerAngle) * min(1.0, dt * 16.0);

    // 2. Wheel Rim Rotation Cycle
    wheelRotation = (wheelRotation + dt * (worldSpeed / 7.0)) % (2 * pi);

    // 3. Subtle Smooth Suspension Bounce Oscillation (No jitter/shake)
    if (state != PlayerActionState.dead) {
      suspensionBounce = sin(runCycle * 2 * pi) * (worldSpeed > 0 ? 0.35 : 0.1);
    } else {
      suspensionBounce = 0.0;
    }

    // 4. Running Step Animation Cycle
    runCycle = (runCycle + dt * (worldSpeed / 60.0)) % 1.0;

    // 5. Jump Physics Arc (Sinusoidal smooth parabola)
    if (state == PlayerActionState.jumping) {
      jumpTimer += dt;
      final double t = (jumpTimer / GameConfig.jumpDuration).clamp(0.0, 1.0);
      jumpY = sin(t * pi) * GameConfig.jumpMaxHeight;

      if (jumpTimer >= GameConfig.jumpDuration) {
        jumpTimer = 0.0;
        jumpY = 0.0;
        if (state != PlayerActionState.dead) {
          state = PlayerActionState.running;
        }
      }
    }

    // 6. Slide / Braking Timer
    if (state == PlayerActionState.sliding) {
      slideTimer -= dt;
      if (slideTimer <= 0.0) {
        slideTimer = 0.0;
        if (state != PlayerActionState.dead) {
          state = PlayerActionState.running;
        }
      }
    }

    // 7. Hit State Timer
    if (state == PlayerActionState.hit) {
      hitFlashTimer -= dt;
      if (hitFlashTimer <= 0.0 && state != PlayerActionState.dead) {
        state = PlayerActionState.running;
      }
    }

    // 8. Invulnerability & Power-Ups Countdown (Safety Wall, Magnet, Multipliers, Nitro, Slow-Mo)
    if (shieldTimer > 0) {
      shieldTimer -= dt;
      if (shieldTimer <= 0) {
        shieldTimer = 0.0;
      }
    }
    if (invulnerableTimer > 0) {
      invulnerableTimer -= dt;
    }
    if (magnetTimer > 0) {
      magnetTimer -= dt;
    }
    if (multiplierTimer > 0) {
      multiplierTimer -= dt;
    }
    if (speedBoostTimer > 0) {
      speedBoostTimer -= dt;
    }
    if (slowMoTimer > 0) {
      slowMoTimer -= dt;
    }
    if (invincibleTimer > 0) {
      invincibleTimer -= dt;
    }
  }

  // Get current effective hitbox for collision detection (Accurate to visible car chassis)
  Rect getHitbox(double playerCenterX, double playerCenterY, double laneWidth) {
    final double width = GameConfig.playerWidth * 0.78; // ~57.7 px (true body width)
    final double height = (state == PlayerActionState.sliding)
        ? GameConfig.playerSlideHeight * 0.75
        : GameConfig.playerHeight * 0.75; // ~78.0 px (true body length)

    final double centerY = playerCenterY - jumpY;
    return Rect.fromCenter(
      center: Offset(playerCenterX, centerY),
      width: width,
      height: height,
    );
  }
}

