import 'dart:math';
import 'game_config.dart';
import 'obstacle.dart';
import 'coin.dart';
import 'traffic_vehicle.dart';

/// ============================================================================
/// TURBO RACER: PROCEDURAL OBSTACLE & REWARD SPAWN ENGINE
/// ============================================================================
/// Curated procedural patterns incorporating:
/// 1. 6 Dedicated Coin Formations (Straight line, Left-to-Right, Right-to-Left,
///    Zig-zag, Curved S-curve, Lane-switch chicane)
/// 2. 9 Obstacle Types with guaranteed non-blocking 3-lane safe paths & jump arcs
/// 3. Zero-allocation Object Pool integration via `CoinPool`
/// ============================================================================

class SpawnManager {
  final Random _random = Random();
  final CoinPool coinPool = CoinPool();

  double _distanceSinceLastObstacle = 0.0;
  double _nextSpawnInterval = GameConfig.minSpawnDistance;

  void reset(List<CollectibleItem> activeCollectibles) {
    _distanceSinceLastObstacle = 0.0;
    _nextSpawnInterval = GameConfig.minSpawnDistance;
    coinPool.releaseAll(activeCollectibles);
  }

  void update({
    required double dt,
    required double worldSpeed,
    required double distanceTraveled,
    required List<Obstacle> obstacles,
    required List<CollectibleItem> collectibles,
    required double spawnY,
    List<TrafficVehicle>? trafficVehicles,
  }) {
    _distanceSinceLastObstacle += worldSpeed * dt;

    if (_distanceSinceLastObstacle >= _nextSpawnInterval) {
      _distanceSinceLastObstacle = 0.0;

      // Adjust spawn distance based on speed
      final double speedRatio = (worldSpeed - GameConfig.initialSpeed) /
          (GameConfig.maximumSpeed - GameConfig.initialSpeed);
      _nextSpawnInterval = GameConfig.minSpawnDistance +
          (1.0 - speedRatio.clamp(0.0, 1.0)) * 120.0 +
          _random.nextDouble() * 100.0;

      _spawnPattern(
        obstacles: obstacles,
        collectibles: collectibles,
        spawnY: spawnY,
        distanceTraveled: distanceTraveled,
        trafficVehicles: trafficVehicles,
      );
    }
  }

  void _spawnPattern({
    required List<Obstacle> obstacles,
    required List<CollectibleItem> collectibles,
    required double spawnY,
    required double distanceTraveled,
    List<TrafficVehicle>? trafficVehicles,
  }) {
    // Collect occupied lanes near horizon from traffic vehicles
    final Set<int> occupiedLanes = {};
    if (trafficVehicles != null) {
      for (final v in trafficVehicles) {
        if (v.active && (v.y - spawnY).abs() < 160.0) {
          occupiedLanes.add(v.lane);
        }
      }
    }

    // Determine safe open lanes
    final List<int> safeLanes = [];
    for (int l = 0; l < 3; l++) {
      if (!occupiedLanes.contains(l)) {
        safeLanes.add(l);
      }
    }

    // If 2 or more lanes already occupied by traffic, spawn only coins in the open safe lane
    if (safeLanes.length <= 1) {
      final int openLane = safeLanes.isNotEmpty ? safeLanes.first : 1;
      CoinPatternGenerator.spawnPattern(
        CoinPatternType.straightLine,
        pool: coinPool,
        targetList: collectibles,
        spawnY: spawnY - 20.0,
        forcedStartLane: openLane,
        coinCount: 4,
      );
      return;
    }
    // 50% chance of dedicated structured coin pattern vs obstacle-reward combo
    final bool isPureCoinRun = _random.nextDouble() < 0.35;

    if (isPureCoinRun) {
      // Spawn one of the 6 standalone coin patterns
      final CoinPatternType pattern = CoinPatternGenerator.randomPattern();
      CoinPatternGenerator.spawnPattern(
        pattern,
        pool: coinPool,
        targetList: collectibles,
        spawnY: spawnY,
        coinCount: 5 + _random.nextInt(3),
      );
      return;
    }

    // Curated Obstacle + Coin Reward Combinations
    final int patternType = _random.nextInt(9);

    switch (patternType) {
      // ----------------------------------------------------
      // Pattern 0: Construction Barricade with Safe Lane Coins
      // ----------------------------------------------------
      case 0:
        final int lane = _random.nextInt(3);
        obstacles.add(Obstacle(
          type: ObstacleType.constructionBarricade,
          lane: lane,
          y: spawnY,
        ));

        // Straight Coins in safe lane
        final int safeLane0 = (lane + 1 + _random.nextInt(2)) % 3;
        CoinPatternGenerator.spawnPattern(
          CoinPatternType.straightLine,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 20.0,
          forcedStartLane: safeLane0,
          coinCount: 5,
        );
        break;

      // ----------------------------------------------------
      // Pattern 1: Traffic Cones Slalom + Zig-Zag Coin Trail
      // ----------------------------------------------------
      case 1:
        final int coneLaneA = _random.nextInt(3);
        final int coneLaneB = (coneLaneA + 1 + _random.nextInt(2)) % 3;

        obstacles.add(Obstacle(
          type: ObstacleType.trafficCone,
          lane: coneLaneA,
          y: spawnY - 30.0,
        ));
        obstacles.add(Obstacle(
          type: ObstacleType.trafficCone,
          lane: coneLaneB,
          y: spawnY + 30.0,
        ));

        // Open safe lane straight coin stream
        final int openLane = [0, 1, 2].firstWhere((l) => l != coneLaneA && l != coneLaneB, orElse: () => 1);
        CoinPatternGenerator.spawnPattern(
          CoinPatternType.straightLine,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 20.0,
          forcedStartLane: openLane,
          coinCount: 4,
        );
        break;

      // ----------------------------------------------------
      // Pattern 2: Reinforced Roadblock + Straight Safe Lane Coins
      // ----------------------------------------------------
      case 2:
        final int blockLane = _random.nextInt(3);
        obstacles.add(Obstacle(
          type: ObstacleType.roadBlock,
          lane: blockLane,
          y: spawnY,
        ));

        // Safe lane coin trail in one of the 2 open lanes
        final int safeLane = (blockLane + 1) % 3;
        CoinPatternGenerator.spawnPattern(
          CoinPatternType.straightLine,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 40.0,
          forcedStartLane: safeLane,
          coinCount: 5,
        );
        break;

      // ----------------------------------------------------
      // Pattern 3: Broken-down Smoking Vehicle + Power-Up & Coins
      // ----------------------------------------------------
      case 3:
        final int stallLane = _random.nextInt(3);
        obstacles.add(Obstacle(
          type: ObstacleType.brokenDownVehicle,
          lane: stallLane,
          y: spawnY,
        ));

        // Power-Up in adjacent lane
        final int rewardLane = (stallLane + 1) % 3;
        collectibles.add(coinPool.acquire(
          type: _pickRandomPowerUp(),
          lane: rewardLane,
          y: spawnY,
        ));

        // Diagonal coin trail leading into the power-up
        CoinPatternGenerator.spawnPattern(
          stallLane == 0 ? CoinPatternType.leftToRight : CoinPatternType.rightToLeft,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 60.0,
          coinCount: 3,
        );
        break;

      // ----------------------------------------------------
      // Pattern 4: Slippery Oil Spill + Curved Coin Evasion
      // ----------------------------------------------------
      case 4:
        final int oilLane = _random.nextInt(3);
        obstacles.add(Obstacle(
          type: ObstacleType.oilSpill,
          lane: oilLane,
          y: spawnY,
        ));

        // High-value Gem in open lane
        final int gemLane = (oilLane + 1) % 3;
        collectibles.add(coinPool.acquire(
          type: CollectibleType.gem,
          lane: gemLane,
          y: spawnY,
        ));

        // Curved coin path guiding away from the oil
        CoinPatternGenerator.spawnPattern(
          CoinPatternType.curved,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 50.0,
          coinCount: 4,
        );
        break;

      // ----------------------------------------------------
      // Pattern 5: Speed Bump across lane + Safe Lane Coins
      // ----------------------------------------------------
      case 5:
        final int bumpLane = _random.nextInt(3);
        obstacles.add(Obstacle(
          type: ObstacleType.speedBump,
          lane: bumpLane,
          y: spawnY,
        ));

        // Straight coins in clear lane
        final int clearLane5 = (bumpLane + 1) % 3;
        CoinPatternGenerator.spawnPattern(
          CoinPatternType.straightLine,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 20.0,
          forcedStartLane: clearLane5,
          coinCount: 5,
        );
        break;

      // ----------------------------------------------------
      // Pattern 6: Construction Zone Roadworks + Lane-Switch Chicane
      // ----------------------------------------------------
      case 6:
        final int workLane = _random.nextBool() ? 0 : 2;
        obstacles.add(Obstacle(
          type: ObstacleType.constructionZone,
          lane: workLane,
          y: spawnY,
        ));

        // Lane-switch coin trail guiding driver safely around roadworks
        CoinPatternGenerator.spawnPattern(
          CoinPatternType.laneSwitch,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 40.0,
          forcedStartLane: (workLane == 0) ? 1 : 1,
          coinCount: 5,
        );
        break;

      // ----------------------------------------------------
      // Pattern 7: Fallen Cargo Crate + Safe Lane Coins
      // ----------------------------------------------------
      case 7:
        final int crateLane = _random.nextInt(3);
        obstacles.add(Obstacle(
          type: ObstacleType.fallenObject,
          lane: crateLane,
          y: spawnY,
        ));

        // Straight coins in safe clear lane
        final int clearLane7 = (crateLane + 1) % 3;
        CoinPatternGenerator.spawnPattern(
          CoinPatternType.straightLine,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 20.0,
          forcedStartLane: clearLane7,
          coinCount: 5,
        );
        break;

      // ----------------------------------------------------
      // Pattern 8: Road Barrier + Gem & Coin Trail
      // ----------------------------------------------------
      default:
        final int barrierLane = _random.nextInt(3);
        obstacles.add(Obstacle(
          type: ObstacleType.roadBarrier,
          lane: barrierLane,
          y: spawnY,
        ));

        final int clearLane = (barrierLane + 1) % 3;
        collectibles.add(coinPool.acquire(
          type: CollectibleType.gem,
          lane: clearLane,
          y: spawnY,
        ));

        CoinPatternGenerator.spawnPattern(
          CoinPatternType.straightLine,
          pool: coinPool,
          targetList: collectibles,
          spawnY: spawnY - 60.0,
          forcedStartLane: clearLane,
          coinCount: 4,
        );
        break;
    }
  }

  CollectibleType _pickRandomPowerUp() {
    final double r = _random.nextDouble();
    if (r < 0.16) {
      return CollectibleType.shield;
    } else if (r < 0.32) {
      return CollectibleType.magnet;
    } else if (r < 0.48) {
      return CollectibleType.multiplier2x;
    } else if (r < 0.62) {
      return CollectibleType.nitroCanister;
    } else if (r < 0.76) {
      return CollectibleType.speedBoost;
    } else if (r < 0.88) {
      return CollectibleType.slowMotion;
    } else {
      return CollectibleType.invincibility;
    }
  }
}
