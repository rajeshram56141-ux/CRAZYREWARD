import 'package:flutter/material.dart';

/// ============================================================================
/// CAR UPGRADE SYSTEM: 5 CORE UPGRADE CATEGORIES & MULTI-LEVEL TIERS
/// ============================================================================
/// Categories:
/// 1. SPEED (Base max speed & cruising power)
/// 2. ACCELERATION (0-100 sprint response & overtake burst)
/// 3. HANDLING (Steering agility, lane switch fluidity & drift stability)
/// 4. BRAKING (Deceleration bite, obstacle avoidance & slide control)
/// 5. NITRO (Boost velocity multiplier & nitrous burn longevity)
/// ============================================================================

enum UpgradeCategory {
  speed,
  acceleration,
  handling,
  braking,
  nitro,
}

extension UpgradeCategoryExt on UpgradeCategory {
  String get displayName {
    switch (this) {
      case UpgradeCategory.speed:
        return "SPEED";
      case UpgradeCategory.acceleration:
        return "ACCELERATION";
      case UpgradeCategory.handling:
        return "HANDLING";
      case UpgradeCategory.braking:
        return "BRAKING";
      case UpgradeCategory.nitro:
        return "NITRO";
    }
  }

  String get description {
    switch (this) {
      case UpgradeCategory.speed:
        return "Increases maximum top cruising speed & highway velocity.";
      case UpgradeCategory.acceleration:
        return "Rapid throttle response, faster recovery and instant burst.";
      case UpgradeCategory.handling:
        return "Ultra-responsive lane switches and high-speed cornering.";
      case UpgradeCategory.braking:
        return "Instant emergency deceleration, slide control and grip recovery.";
      case UpgradeCategory.nitro:
        return "Higher nitrous boost multiplier and longer burn duration.";
    }
  }

  IconData get icon {
    switch (this) {
      case UpgradeCategory.speed:
        return Icons.speed_rounded;
      case UpgradeCategory.acceleration:
        return Icons.flash_on_rounded;
      case UpgradeCategory.handling:
        return Icons.tune_rounded;
      case UpgradeCategory.braking:
        return Icons.pan_tool_alt_rounded;
      case UpgradeCategory.nitro:
        return Icons.local_fire_department_rounded;
    }
  }

  Color get primaryColor {
    switch (this) {
      case UpgradeCategory.speed:
        return const Color(0xFFFF3366); // Neon Crimson
      case UpgradeCategory.acceleration:
        return const Color(0xFF00F2FE); // Electric Cyan
      case UpgradeCategory.handling:
        return const Color(0xFF22C55E); // Emerald Neon
      case UpgradeCategory.braking:
        return const Color(0xFFF59E0B); // Amber Orange
      case UpgradeCategory.nitro:
        return const Color(0xFFA855F7); // Violet Plasma
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case UpgradeCategory.speed:
        return const [Color(0xFFFF3366), Color(0xFFFF5E3A)];
      case UpgradeCategory.acceleration:
        return const [Color(0xFF00F2FE), Color(0xFF4FACFE)];
      case UpgradeCategory.handling:
        return const [Color(0xFF22C55E), Color(0xFF10B981)];
      case UpgradeCategory.braking:
        return const [Color(0xFFF59E0B), Color(0xFFD97706)];
      case UpgradeCategory.nitro:
        return const [Color(0xFFA855F7), Color(0xFFEC4899)];
    }
  }

  String get unit {
    switch (this) {
      case UpgradeCategory.speed:
        return "KM/H";
      case UpgradeCategory.acceleration:
        return "PTS";
      case UpgradeCategory.handling:
        return "AGILITY";
      case UpgradeCategory.braking:
        return "GRIP";
      case UpgradeCategory.nitro:
        return "BOOST";
    }
  }
}

/// Level Tier Data for a specific upgrade step
class UpgradeTierData {
  final int level;
  final int value;
  final int costToNext;
  final String label;
  final double statMultiplier;

  const UpgradeTierData({
    required this.level,
    required this.value,
    required this.costToNext,
    required this.label,
    required this.statMultiplier,
  });

  bool get isMaxLevel => costToNext == 0;
}

/// Car Upgrade Registry and Configuration for all 5 categories
class CarUpgradeSystem {
  static const int maxLevel = 5;

  // ===========================================================================
  // 5 CATEGORIES DEFINED WITH PRECISE PROGRESSION LEVELS (Level 1 -> Level 5)
  // ===========================================================================

  /// 1. SPEED UPGRADE TIERS:
  /// Level 1: 100 (Stock)
  /// Level 2: 110 (+10)
  /// Level 3: 120 (+20)
  /// Level 4: 135 (+35)
  /// Level 5: 150 (+50)
  static const List<UpgradeTierData> speedTiers = [
    UpgradeTierData(level: 1, value: 100, costToNext: 150, label: "Stock Velocity", statMultiplier: 1.00),
    UpgradeTierData(level: 2, value: 110, costToNext: 300, label: "ECU Remap Stage 1", statMultiplier: 1.10),
    UpgradeTierData(level: 3, value: 120, costToNext: 500, label: "High-Flow Intake", statMultiplier: 1.20),
    UpgradeTierData(level: 4, value: 135, costToNext: 800, label: "Twin-Scroll Turbo", statMultiplier: 1.35),
    UpgradeTierData(level: 5, value: 150, costToNext: 0, label: "Racing Camshaft Max", statMultiplier: 1.50),
  ];

  /// 2. ACCELERATION UPGRADE TIERS:
  /// Level 1: 100 (Stock 3.5s)
  /// Level 2: 115 (+15, 3.1s)
  /// Level 3: 130 (+30, 2.7s)
  /// Level 4: 150 (+50, 2.3s)
  /// Level 5: 175 (+75, 1.8s)
  static const List<UpgradeTierData> accelerationTiers = [
    UpgradeTierData(level: 1, value: 100, costToNext: 150, label: "Stock Gearbox", statMultiplier: 1.00),
    UpgradeTierData(level: 2, value: 115, costToNext: 300, label: "Lightweight Flywheel", statMultiplier: 1.15),
    UpgradeTierData(level: 3, value: 130, costToNext: 500, label: "Short-Throw Shifter", statMultiplier: 1.30),
    UpgradeTierData(level: 4, value: 150, costToNext: 800, label: "Dual-Clutch Transmission", statMultiplier: 1.50),
    UpgradeTierData(level: 5, value: 175, costToNext: 0, label: "Launch Control Pro", statMultiplier: 1.75),
  ];

  /// 3. HANDLING UPGRADE TIERS:
  /// Level 1: 100 (Stock)
  /// Level 2: 112 (+12)
  /// Level 3: 125 (+25)
  /// Level 4: 140 (+40)
  /// Level 5: 160 (+60)
  static const List<UpgradeTierData> handlingTiers = [
    UpgradeTierData(level: 1, value: 100, costToNext: 120, label: "Stock Struts", statMultiplier: 1.00),
    UpgradeTierData(level: 2, value: 112, costToNext: 250, label: "Sport Sway Bars", statMultiplier: 1.12),
    UpgradeTierData(level: 3, value: 125, costToNext: 450, label: "Adjustable Coilovers", statMultiplier: 1.25),
    UpgradeTierData(level: 4, value: 140, costToNext: 750, label: "Active Aero Spoiler", statMultiplier: 1.40),
    UpgradeTierData(level: 5, value: 160, costToNext: 0, label: "Track Slick Telemetry", statMultiplier: 1.60),
  ];

  /// 4. BRAKING UPGRADE TIERS:
  /// Level 1: 100 (Stock)
  /// Level 2: 115 (+15)
  /// Level 3: 130 (+30)
  /// Level 4: 145 (+45)
  /// Level 5: 165 (+65)
  static const List<UpgradeTierData> brakingTiers = [
    UpgradeTierData(level: 1, value: 100, costToNext: 100, label: "OEM Disc Brakes", statMultiplier: 1.00),
    UpgradeTierData(level: 2, value: 115, costToNext: 220, label: "Slotted Rotors", statMultiplier: 1.15),
    UpgradeTierData(level: 3, value: 130, costToNext: 400, label: "Semi-Metallic Pads", statMultiplier: 1.30),
    UpgradeTierData(level: 4, value: 145, costToNext: 700, label: "6-Piston Calipers", statMultiplier: 1.45),
    UpgradeTierData(level: 5, value: 165, costToNext: 0, label: "Carbon Ceramic Matrix", statMultiplier: 1.65),
  ];

  /// 5. NITRO UPGRADE TIERS:
  /// Level 1: 100 (Stock)
  /// Level 2: 115 (+15)
  /// Level 3: 135 (+35)
  /// Level 4: 155 (+55)
  /// Level 5: 180 (+80)
  static const List<UpgradeTierData> nitroTiers = [
    UpgradeTierData(level: 1, value: 100, costToNext: 180, label: "Single Bottle 50HP", statMultiplier: 1.00),
    UpgradeTierData(level: 2, value: 115, costToNext: 350, label: "High-Flow Solenoid", statMultiplier: 1.15),
    UpgradeTierData(level: 3, value: 135, costToNext: 600, label: "Twin Bottle Stage 2", statMultiplier: 1.35),
    UpgradeTierData(level: 4, value: 155, costToNext: 950, label: "Cryogenic Intercooler", statMultiplier: 1.55),
    UpgradeTierData(level: 5, value: 180, costToNext: 0, label: "Hyper-Quantum Injector", statMultiplier: 1.80),
  ];

  /// Retrieve tier list for any category
  static List<UpgradeTierData> getTiersForCategory(UpgradeCategory category) {
    switch (category) {
      case UpgradeCategory.speed:
        return speedTiers;
      case UpgradeCategory.acceleration:
        return accelerationTiers;
      case UpgradeCategory.handling:
        return handlingTiers;
      case UpgradeCategory.braking:
        return brakingTiers;
      case UpgradeCategory.nitro:
        return nitroTiers;
    }
  }

  /// Get tier data for a specific level (1 to 5)
  static UpgradeTierData getTier(UpgradeCategory category, int level) {
    final tiers = getTiersForCategory(category);
    final index = (level - 1).clamp(0, tiers.length - 1);
    return tiers[index];
  }

  /// Get the cost to upgrade from current level to next level
  static int getUpgradeCost(UpgradeCategory category, int currentLevel) {
    if (currentLevel >= maxLevel) return 0;
    return getTier(category, currentLevel).costToNext;
  }

  /// Get the next level tier data (or null if max)
  static UpgradeTierData? getNextTier(UpgradeCategory category, int currentLevel) {
    if (currentLevel >= maxLevel) return null;
    return getTier(category, currentLevel + 1);
  }

  /// Calculate combined power index rating (out of 100)
  static int calculateOverallRating({
    required int speedLvl,
    required int accelLvl,
    required int handlingLvl,
    required int brakingLvl,
    required int nitroLvl,
  }) {
    final totalLevels = speedLvl + accelLvl + handlingLvl + brakingLvl + nitroLvl;
    // Total ranges from 5 (all lvl 1) to 25 (all lvl 5)
    final percentage = (totalLevels - 5) / 20.0;
    return (50 + (percentage * 50)).round();
  }
}
