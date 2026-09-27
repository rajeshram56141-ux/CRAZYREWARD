import 'package:flutter/material.dart';
import 'player_car.dart';

/// ============================================================================
/// MODULAR CAR GARAGE DATA MODEL & REGISTRY
/// ============================================================================
/// Allows easy addition of new cars with preview themes, categories,
/// customizable performance stats, progression curves, and upgrade costs.
/// ============================================================================

enum CarCategory {
  starter,
  sports,
  superCar,
  muscle,
  hyper,
}

extension CarCategoryExt on CarCategory {
  String get displayName {
    switch (this) {
      case CarCategory.starter:
        return "Starter";
      case CarCategory.sports:
        return "Sports";
      case CarCategory.superCar:
        return "Super";
      case CarCategory.muscle:
        return "Muscle";
      case CarCategory.hyper:
        return "Hyper";
    }
  }

  Color get color {
    switch (this) {
      case CarCategory.starter:
        return const Color(0xFFEF4444); // Red
      case CarCategory.sports:
        return const Color(0xFF00F2FE); // Cyan Blue
      case CarCategory.superCar:
        return const Color(0xFFFFD700); // Gold
      case CarCategory.muscle:
        return const Color(0xFF22C55E); // Green
      case CarCategory.hyper:
        return const Color(0xFFA855F7); // Purple
    }
  }

  IconData get icon {
    switch (this) {
      case CarCategory.starter:
        return Icons.directions_car_rounded;
      case CarCategory.sports:
        return Icons.speed_rounded;
      case CarCategory.superCar:
        return Icons.bolt_rounded;
      case CarCategory.muscle:
        return Icons.local_fire_department_rounded;
      case CarCategory.hyper:
        return Icons.military_tech_rounded;
    }
  }
}

class GarageCarConfig {
  final String id;
  final String name;
  final CarCategory category;
  final String subtitle;
  final String description;

  // Base Performance Normalized Stats (0.0 to 1.0)
  final double baseSpeed;
  final double baseHandling;
  final double baseAcceleration;
  final double baseBraking;
  final double baseNitro;

  // Real-world Display Specs
  final String topSpeedDisplay;
  final String accelerationDisplay;
  final String handlingDisplay;
  final String brakingDisplay;
  final String specialPerk;

  // Paint / Visual Theme
  final PlayerCarTheme theme;

  // Unlock Requirements
  final bool isDefaultUnlocked;
  final int unlockPriceCoins;
  final int unlockScoreRequirement;

  // Upgrades Configuration
  final int maxUpgradeLevel;
  final int baseUpgradeCost;
  final double speedPerLevel;
  final double handlingPerLevel;
  final double accelPerLevel;
  final double brakingPerLevel;
  final double nitroPerLevel;

  const GarageCarConfig({
    required this.id,
    required this.name,
    required this.category,
    required this.subtitle,
    required this.description,
    required this.baseSpeed,
    required this.baseHandling,
    required this.baseAcceleration,
    this.baseBraking = 0.65,
    required this.baseNitro,
    required this.topSpeedDisplay,
    required this.accelerationDisplay,
    required this.handlingDisplay,
    this.brakingDisplay = "DISC BRAKES",
    required this.specialPerk,
    required this.theme,
    this.isDefaultUnlocked = false,
    this.unlockPriceCoins = 0,
    this.unlockScoreRequirement = 0,
    this.maxUpgradeLevel = 5,
    this.baseUpgradeCost = 250,
    this.speedPerLevel = 0.05,
    this.handlingPerLevel = 0.04,
    this.accelPerLevel = 0.05,
    this.brakingPerLevel = 0.05,
    this.nitroPerLevel = 0.05,
  });

  /// Calculates effective stat at a given upgrade level (1 = Base Stock, 5 = Max)
  double getEffectiveSpeed(int level) =>
      (baseSpeed + ((level - 1).clamp(0, maxUpgradeLevel) * speedPerLevel)).clamp(0.1, 1.0);

  double getEffectiveHandling(int level) =>
      (baseHandling + ((level - 1).clamp(0, maxUpgradeLevel) * handlingPerLevel)).clamp(0.1, 1.0);

  double getEffectiveAcceleration(int level) =>
      (baseAcceleration + ((level - 1).clamp(0, maxUpgradeLevel) * accelPerLevel)).clamp(0.1, 1.0);

  double getEffectiveBraking(int level) =>
      (baseBraking + ((level - 1).clamp(0, maxUpgradeLevel) * brakingPerLevel)).clamp(0.1, 1.0);

  double getEffectiveNitro(int level) =>
      (baseNitro + ((level - 1).clamp(0, maxUpgradeLevel) * nitroPerLevel)).clamp(0.1, 1.0);

  /// Upgrade cost scales per level: Level 1->2 = 250, Level 2->3 = 400, etc.
  int getUpgradeCost(int currentLevel) {
    if (currentLevel >= maxUpgradeLevel) return 0;
    return baseUpgradeCost + ((currentLevel - 1).clamp(0, maxUpgradeLevel) * 150);
  }

  // ===========================================================================
  // MODULAR CAR REGISTRY (5 Built-in Cars + Easily Extensible!)
  // ===========================================================================
  static const List<GarageCarConfig> allCars = [
    // 1. STARTER CAR
    GarageCarConfig(
      id: "starter_apex",
      name: "Apex Cruiser",
      category: CarCategory.starter,
      subtitle: "Daily Highway Street Machine",
      description: "Balanced, reliable, and perfectly tuned for rookie street racers.",
      baseSpeed: 0.62,
      baseHandling: 0.70,
      baseAcceleration: 0.65,
      baseNitro: 0.60,
      topSpeedDisplay: "310 KM/H",
      accelerationDisplay: "3.4s 0-100",
      handlingDisplay: "BALANCED",
      specialPerk: "Fast lane switch stability",
      theme: PlayerCarTheme.red,
      isDefaultUnlocked: true,
      unlockPriceCoins: 0,
      unlockScoreRequirement: 0,
      baseUpgradeCost: 200,
    ),

    // 2. SPORTS CAR
    GarageCarConfig(
      id: "sports_volt",
      name: "Volt GT Turbo",
      category: CarCategory.sports,
      subtitle: "High-Revving Precision Coupe",
      description: "Aggressive aerodynamics with ultra-responsive electric nitro boost.",
      baseSpeed: 0.74,
      baseHandling: 0.82,
      baseAcceleration: 0.78,
      baseNitro: 0.75,
      topSpeedDisplay: "345 KM/H",
      accelerationDisplay: "2.9s 0-100",
      handlingDisplay: "HIGH AGILITY",
      specialPerk: "+15% Nitro charge refill speed",
      theme: PlayerCarTheme.blue,
      isDefaultUnlocked: false,
      unlockPriceCoins: 500,
      unlockScoreRequirement: 800,
      baseUpgradeCost: 350,
    ),

    // 3. SUPER CAR
    GarageCarConfig(
      id: "super_solar",
      name: "Solar Apex V10",
      category: CarCategory.superCar,
      subtitle: "Exotic Mid-Engine Track Predator",
      description: "Carbon fiber monocoque chassis engineered for blistering highway speeds.",
      baseSpeed: 0.85,
      baseHandling: 0.80,
      baseAcceleration: 0.86,
      baseNitro: 0.82,
      topSpeedDisplay: "370 KM/H",
      accelerationDisplay: "2.5s 0-100",
      handlingDisplay: "TRACK TUNED",
      specialPerk: "+25% Coin magnet radius",
      theme: PlayerCarTheme.yellow,
      isDefaultUnlocked: false,
      unlockPriceCoins: 1500,
      unlockScoreRequirement: 2500,
      baseUpgradeCost: 500,
    ),

    // 4. MUSCLE CAR
    GarageCarConfig(
      id: "muscle_viper",
      name: "Viper V8 Muscle",
      category: CarCategory.muscle,
      subtitle: "Supercharged Heavy Torque Beast",
      description: "Raw American horsepower designed to smash through speed traps with roaring thunder.",
      baseSpeed: 0.88,
      baseHandling: 0.68,
      baseAcceleration: 0.92,
      baseNitro: 0.88,
      topSpeedDisplay: "380 KM/H",
      accelerationDisplay: "2.2s 0-100",
      handlingDisplay: "HEAVY DRIFT",
      specialPerk: "+20% Crash impact resilience",
      theme: PlayerCarTheme.green,
      isDefaultUnlocked: false,
      unlockPriceCoins: 3000,
      unlockScoreRequirement: 5000,
      baseUpgradeCost: 750,
    ),

    // 5. HYPER CAR
    GarageCarConfig(
      id: "hyper_spectre",
      name: "Phantom Spectre",
      category: CarCategory.hyper,
      subtitle: "Next-Gen Quantum Hypercar",
      description: "The pinnacle of speed technology with quad-turbo hybrid power and slipstream cloaking.",
      baseSpeed: 0.96,
      baseHandling: 0.94,
      baseAcceleration: 0.98,
      baseNitro: 0.96,
      topSpeedDisplay: "415 KM/H",
      accelerationDisplay: "1.8s 0-100",
      handlingDisplay: "ULTIMATE AGILITY",
      specialPerk: "Double Combo multiplier duration",
      theme: PlayerCarTheme.purple,
      isDefaultUnlocked: false,
      unlockPriceCoins: 6000,
      unlockScoreRequirement: 10000,
      baseUpgradeCost: 1000,
    ),
  ];

  static GarageCarConfig getById(String id) {
    return allCars.firstWhere(
      (c) => c.id == id,
      orElse: () => allCars.first,
    );
  }

  static GarageCarConfig getByIndex(int index) {
    if (index >= 0 && index < allCars.length) {
      return allCars[index];
    }
    return allCars.first;
  }
}
