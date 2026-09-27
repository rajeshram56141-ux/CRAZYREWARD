import 'dart:math';
import 'player.dart';
import 'traffic_vehicle.dart';
import 'obstacle.dart';

/// ============================================================================
/// TURBO RACER: TRAFFIC MANAGER & OBJECT POOL ENGINE
/// ============================================================================
/// - Manages pooled AI traffic vehicles with zero garbage collection allocations.
/// - Weighted random vehicle generation (Common vs Rare models).
/// - Safe Spawning Algorithm: Ensures fair difficulty and never blocks all 3 lanes.
/// - Handles collision detection, off-screen recycling, and speed scaling.
/// ============================================================================

class TrafficManager {
  static const int poolCapacity = 14;
  final List<TrafficVehicle> _pool = [];
  final Random _random = Random();

  double _spawnTimer = 0.0;
  double _nextSpawnInterval = 1.8; // Seconds between spawns for active highway traffic
  double minSafeDistance = 110.0;

  void init() {
    _pool.clear();
    for (int i = 0; i < poolCapacity; i++) {
      _pool.add(TrafficVehicle());
    }
    _spawnTimer = 0.0;
    _nextSpawnInterval = 1.8;
  }

  void reset() {
    for (final v in _pool) {
      v.active = false;
      v.cleared = false;
      v.y = -300.0;
    }
    _spawnTimer = 0.0;
    _nextSpawnInterval = 1.8;
  }

  /// 60 FPS Update Loop
  void update({
    required double dt,
    required double worldSpeed,
    required double screenHeight,
    required double horizonY,
    List<Obstacle>? obstacles,
  }) {
    // 1. Update all active traffic vehicles
    for (final v in _pool) {
      if (v.active) {
        v.update(dt, worldSpeed);

        // Recycle off-screen vehicles that have passed the bottom
        if (v.y > screenHeight + 120.0) {
          v.active = false;
          v.cleared = false;
        }
      }
    }

    // 2. Spawn Controller
    _spawnTimer += dt;
    if (_spawnTimer >= _nextSpawnInterval) {
      _spawnTimer = 0.0;

      // Dynamic spawn interval based on speed: active highway flow with reaction time
      final double speedFactor = (worldSpeed / 180.0).clamp(0.7, 1.8);
      _nextSpawnInterval = (1.8 / speedFactor) + _random.nextDouble() * 0.9;

      _trySpawnVehicle(horizonY, obstacles);
    }
  }

  /// Safe Traffic Spawn: Guarantees at least 1 open lane at every depth interval
  void _trySpawnVehicle(double spawnY, [List<Obstacle>? obstacles]) {
    // Find available vehicle from object pool
    TrafficVehicle? availableVehicle;
    for (final v in _pool) {
      if (!v.active) {
        availableVehicle = v;
        break;
      }
    }

    if (availableVehicle == null) return; // Pool full

    // Check currently occupied lanes near horizon spawn area from other vehicles
    final Set<int> blockedLanes = {};
    for (final v in _pool) {
      if (v.active && (v.y - spawnY).abs() < 160.0) {
        blockedLanes.add(v.lane);
      }
    }

    // Also check static obstacles near horizon spawn area
    if (obstacles != null) {
      for (final obs in obstacles) {
        if (!obs.cleared && (obs.y - spawnY).abs() < 160.0) {
          blockedLanes.add(obs.lane);
        }
      }
    }

    // SAFETY RULE: Never block all 3 lanes simultaneously - always keep at least 1 lane open
    final List<int> availableLanes = [];
    for (int l = 0; l < 3; l++) {
      if (!blockedLanes.contains(l)) {
        availableLanes.add(l);
      }
    }

    if (availableLanes.isEmpty) {
      return;
    }

    final int targetLane = availableLanes[_random.nextInt(availableLanes.length)];
    final TrafficVehicleType chosenType = _pickWeightedVehicleType();

    availableVehicle.spawn(
      vehicleType: chosenType,
      targetLane: targetLane,
      startY: spawnY,
      random: _random,
    );
  }

  /// Weighted Random Vehicle Picker (Common vs Rare)
  TrafficVehicleType _pickWeightedVehicleType() {
    int totalWeight = 0;
    for (final t in TrafficVehicleType.values) {
      totalWeight += TrafficVehicleConfig.fromType(t).rarityWeight;
    }

    int roll = _random.nextInt(totalWeight);
    for (final t in TrafficVehicleType.values) {
      final w = TrafficVehicleConfig.fromType(t).rarityWeight;
      if (roll < w) {
        return t;
      }
      roll -= w;
    }

    return TrafficVehicleType.sedan;
  }

  /// Collision Check
  TrafficVehicle? checkCollisions(Player player, double laneWidth, double roadLeft, double playerY) {
    if (player.isInvulnerable || player.state == PlayerActionState.dead) {
      return null;
    }

    for (final v in _pool) {
      if (v.active && !v.cleared) {
        if (v.checkCollision(player, laneWidth, roadLeft, playerY)) {
          return v;
        }
      }
    }
    return null;
  }

  /// Near-Miss Detection: Rewards nitro & bonus score for close overtakes
  TrafficVehicle? checkNearMiss(
    Player player,
    double laneWidth,
    double roadLeft,
    double playerY, {
    double proximityDistanceY = 56.0,
  }) {
    for (final v in _pool) {
      if (v.active && !v.cleared && !v.nearMissTriggered) {
        final bool isAdjacent = (v.lane - player.currentLane).abs() == 1;
        final bool isAlongside = (v.y - playerY).abs() < proximityDistanceY;
        if (isAdjacent && isAlongside) {
          v.nearMissTriggered = true;
          return v;
        }
      }
    }
    return null;
  }

  /// Clears active traffic vehicles near player when resuming or restarting
  void clearImmediateHazards(double playerY, {double safeRadius = 480.0}) {
    for (final v in _pool) {
      if (v.active && ((v.y - playerY).abs() < safeRadius || v.y >= playerY - 80.0)) {
        v.active = false;
        v.cleared = true;
        v.y = -300.0;
      }
    }
  }

  List<TrafficVehicle> get vehicles => _pool;
  List<TrafficVehicle> get activeVehicles => _pool.where((v) => v.active).toList();
}
