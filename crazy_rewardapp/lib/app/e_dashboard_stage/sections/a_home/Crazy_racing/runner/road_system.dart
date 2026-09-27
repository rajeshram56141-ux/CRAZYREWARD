import 'dart:math';
import 'package:flutter/material.dart';

/// ============================================================================
/// TURBO RACER: DYNAMIC SKY & 4-LAYER PARALLAX BACKGROUND SYSTEM
/// ============================================================================
/// 4 DISTINCT PARALLAX DEPTH LAYERS:
/// - LAYER 1 (Speed ~0.02x): Sky Gradient & Celestial Bodies (Sun, Moon, Stars, Corona)
/// - LAYER 2 (Speed ~0.12x): Multi-Tier Clouds (High Wispy Cirrus & Puffy Cumulus)
/// - LAYER 3 (Speed ~0.35x): Distant Mountains & City Skyline with Lateral Steering Parallax & Atmospheric Fog
/// - LAYER 4 (Speed ~1.00x): Roadside Objects, Sidewalks, Guardrails, & 3D Curbs
///
/// TIME-OF-DAY CYCLE:
/// 1. Morning (Golden Dawn Sunrise)
/// 2. Day (Bright Azure Sky & Solar Flare)
/// 3. Evening (Fiery Crimson/Orange Sunset)
/// 4. Night (Midnight Navy, Lunar Corona & Starfield)
///
/// OPTIMIZED FOR 60 FPS ON MOBILE (Zero-Allocation Object Pooling Engine)
/// ============================================================================

/// 4 Core Time-of-Day States
enum TimeOfDayState {
  morning,
  day,
  evening,
  night;

  String get displayName {
    switch (this) {
      case TimeOfDayState.morning:
        return 'Morning';
      case TimeOfDayState.day:
        return 'Day';
      case TimeOfDayState.evening:
        return 'Evening';
      case TimeOfDayState.night:
        return 'Night';
    }
  }

  TimeOfDayState get next {
    switch (this) {
      case TimeOfDayState.morning:
        return TimeOfDayState.day;
      case TimeOfDayState.day:
        return TimeOfDayState.evening;
      case TimeOfDayState.evening:
        return TimeOfDayState.night;
      case TimeOfDayState.night:
        return TimeOfDayState.morning;
    }
  }
}

/// Transition Trigger Mode for Day/Night Cycle
enum DayNightTransitionMode {
  automaticDistance, // Cycles based on distance traveled (e.g. every 1600m)
  automaticTime,     // Cycles based on real-time elapsed seconds
  fixed,             // Fixed manually locked state
}

/// Road Lane Enum
enum RoadLane {
  left,
  center,
  right;

  int get laneIndex => index;
}

/// Road Imperfection Types
enum RoadImperfectionType {
  tarCrack,
  skidMark,
  oilSlick,
  speedChevron,
  manholeCover,
}

/// Roadside Environment Categories
enum RoadsideCategory {
  nature,
  roadside,
  city,
}

/// All 16 Roadside Environment Object Types
enum RoadsidePropType {
  // --- Nature (5 Types) ---
  tree(RoadsideCategory.nature, 'Tree'),
  bush(RoadsideCategory.nature, 'Bush'),
  grass(RoadsideCategory.nature, 'Grass'),
  rock(RoadsideCategory.nature, 'Rock'),
  flowers(RoadsideCategory.nature, 'Flowers'),

  // --- Roadside (6 Types) ---
  streetLight(RoadsideCategory.roadside, 'Street Light'),
  roadSign(RoadsideCategory.roadside, 'Road Sign'),
  guardRail(RoadsideCategory.roadside, 'Guard Rail'),
  billboard(RoadsideCategory.roadside, 'Billboard'),
  fence(RoadsideCategory.roadside, 'Fence'),
  utilityPole(RoadsideCategory.roadside, 'Utility Pole'),

  // --- City (5 Types) ---
  building(RoadsideCategory.city, 'Building'),
  shop(RoadsideCategory.city, 'Shop'),
  parkingArea(RoadsideCategory.city, 'Parking Area'),
  trafficLight(RoadsideCategory.city, 'Traffic Light'),
  bridge(RoadsideCategory.city, 'Bridge');

  final RoadsideCategory category;
  final String label;
  const RoadsidePropType(this.category, this.label);
}

/// Backward compatibility alias
typedef RoadSceneryType = RoadsidePropType;

/// A localized road defect or marking on a road segment
class RoadImperfection {
  final double normalizedY;
  final double laneProgress;
  final RoadImperfectionType type;
  final double scale;
  final double rotation;

  const RoadImperfection({
    required this.normalizedY,
    required this.laneProgress,
    required this.type,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

/// ============================================================================
/// COMPREHENSIVE DYNAMIC ENVIRONMENT THEME (LERPABLE)
/// ============================================================================
class RoadEnvironmentTheme {
  final String name;
  final TimeOfDayState timeState;
  final List<Color> skyGradient;
  final List<double> skyStops;
  final Color celestialBodyColor;
  final double celestialBodyRadius;
  final Offset celestialNormalizedPos;
  final double solarRaysOpacity;
  final double lunarHaloOpacity;
  final Color mountainFarColor;
  final Color mountainMidColor;
  final Color horizonSkylineColor;
  final Color distantSkylineColor;
  final Color horizonAtmosphericFog;
  final List<Color> windowGlowColors;
  final double windowGlowIntensity;
  final List<Color> asphaltGradient;
  final Color asphaltSpecularReflection;
  final Color tireTrackShade;
  final Color laneStripeColor;
  final Color curbColorA;
  final Color curbColorB;
  final Color sidewalkBaseColor;
  final Color sidewalkTileColor;
  final List<Color> shoulderGradient;
  final Color guardrailColor;
  final Color guardrailPostColor;
  final Color ambientNeonUnderglow;
  final Color natureFoliageColor;
  final Color streetLightGlowColor;
  final double streetLightIntensity;
  final double headlightIntensity;
  final double neonSignIntensity;
  final Offset shadowOffset;
  final double shadowOpacity;

  const RoadEnvironmentTheme({
    required this.name,
    required this.timeState,
    required this.skyGradient,
    required this.skyStops,
    required this.celestialBodyColor,
    required this.celestialBodyRadius,
    required this.celestialNormalizedPos,
    required this.solarRaysOpacity,
    required this.lunarHaloOpacity,
    required this.mountainFarColor,
    required this.mountainMidColor,
    required this.horizonSkylineColor,
    required this.distantSkylineColor,
    required this.horizonAtmosphericFog,
    required this.windowGlowColors,
    required this.windowGlowIntensity,
    required this.asphaltGradient,
    required this.asphaltSpecularReflection,
    required this.tireTrackShade,
    required this.laneStripeColor,
    required this.curbColorA,
    required this.curbColorB,
    required this.sidewalkBaseColor,
    required this.sidewalkTileColor,
    required this.shoulderGradient,
    required this.guardrailColor,
    required this.guardrailPostColor,
    required this.ambientNeonUnderglow,
    required this.natureFoliageColor,
    required this.streetLightGlowColor,
    required this.streetLightIntensity,
    required this.headlightIntensity,
    required this.neonSignIntensity,
    required this.shadowOffset,
    required this.shadowOpacity,
  });

  // 1. MORNING (Dawn Sunrise / Golden Amber Awakening)
  static const RoadEnvironmentTheme morning = RoadEnvironmentTheme(
    name: "Morning Dawn",
    timeState: TimeOfDayState.morning,
    skyGradient: [
      Color(0xFF2E1065),
      Color(0xFF701A75),
      Color(0xFFC026D3),
      Color(0xFFFDE047),
    ],
    skyStops: [0.0, 0.35, 0.7, 1.0],
    celestialBodyColor: Color(0xFFFEF08A),
    celestialBodyRadius: 18.0,
    celestialNormalizedPos: Offset(0.72, 0.58),
    solarRaysOpacity: 0.55,
    lunarHaloOpacity: 0.0,
    mountainFarColor: Color(0xFF581C87),
    mountainMidColor: Color(0xFF3B0764),
    horizonSkylineColor: Color(0xFF2E1065),
    distantSkylineColor: Color(0x77581C87),
    horizonAtmosphericFog: Color(0x66FDE047),
    windowGlowColors: [Color(0xFFFEF08A), Color(0xFFFDE047), Color(0xFFFFFFFF)],
    windowGlowIntensity: 0.35,
    asphaltGradient: [
      Color(0xFF2A2030),
      Color(0xFF1E1624),
      Color(0xFF140D18),
    ],
    asphaltSpecularReflection: Color(0x35FDE047),
    tireTrackShade: Color(0x35000000),
    laneStripeColor: Color(0xFFFEF08A),
    curbColorA: Color(0xFFFFFFFF),
    curbColorB: Color(0xFFE11D48),
    sidewalkBaseColor: Color(0xFF475569),
    sidewalkTileColor: Color(0xFF64748B),
    shoulderGradient: [
      Color(0xFF332042),
      Color(0xFF22132D),
      Color(0xFF140A1C),
    ],
    guardrailColor: Color(0xFF94A3B8),
    guardrailPostColor: Color(0xFF475569),
    ambientNeonUnderglow: Color(0xFFF59E0B),
    natureFoliageColor: Color(0xFF16A34A),
    streetLightGlowColor: Color(0xFFFEF08A),
    streetLightIntensity: 0.20,
    headlightIntensity: 0.30,
    neonSignIntensity: 0.40,
    shadowOffset: Offset(10.0, 6.0),
    shadowOpacity: 0.32,
  );

  // 2. DAY (Bright Noon Metropolis / Crisp High Visibility)
  static const RoadEnvironmentTheme day = RoadEnvironmentTheme(
    name: "Daylight Metropolis",
    timeState: TimeOfDayState.day,
    skyGradient: [
      Color(0xFF0284C7),
      Color(0xFF38BDF8),
      Color(0xFF7DD3FC),
      Color(0xFFE0F2FE),
    ],
    skyStops: [0.0, 0.4, 0.75, 1.0],
    celestialBodyColor: Color(0xFFFFFBEB),
    celestialBodyRadius: 22.0,
    celestialNormalizedPos: Offset(0.50, 0.28),
    solarRaysOpacity: 0.85,
    lunarHaloOpacity: 0.0,
    mountainFarColor: Color(0xFF0369A1),
    mountainMidColor: Color(0xFF0C4A6E),
    horizonSkylineColor: Color(0xFF0F172A),
    distantSkylineColor: Color(0x660284C7),
    horizonAtmosphericFog: Color(0x3338BDF8),
    windowGlowColors: [Color(0xFF38BDF8), Color(0xFFE0F2FE), Color(0xFFFFFFFF)],
    windowGlowIntensity: 0.15,
    asphaltGradient: [
      Color(0xFF334155),
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ],
    asphaltSpecularReflection: Color(0x28FFFFFF),
    tireTrackShade: Color(0x45000000),
    laneStripeColor: Color(0xFFF8FAFC),
    curbColorA: Color(0xFFFFFFFF),
    curbColorB: Color(0xFFEF4444),
    sidewalkBaseColor: Color(0xFF64748B),
    sidewalkTileColor: Color(0xFF94A3B8),
    shoulderGradient: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
      Color(0xFF020617),
    ],
    guardrailColor: Color(0xFF94A3B8),
    guardrailPostColor: Color(0xFF475569),
    ambientNeonUnderglow: Color(0xFF38BDF8),
    natureFoliageColor: Color(0xFF22C55E),
    streetLightGlowColor: Color(0xFFFEF08A),
    streetLightIntensity: 0.0,
    headlightIntensity: 0.10,
    neonSignIntensity: 0.15,
    shadowOffset: Offset(0.0, 4.0),
    shadowOpacity: 0.42,
  );

  // 3. EVENING (Sunset Boulevard / Golden Hour & Long Shadows)
  static const RoadEnvironmentTheme evening = RoadEnvironmentTheme(
    name: "Sunset Boulevard",
    timeState: TimeOfDayState.evening,
    skyGradient: [
      Color(0xFF1E1B4B),
      Color(0xFF831843),
      Color(0xFFBE185D),
      Color(0xFFEA580C),
    ],
    skyStops: [0.0, 0.35, 0.7, 1.0],
    celestialBodyColor: Color(0xFFF97316),
    celestialBodyRadius: 26.0,
    celestialNormalizedPos: Offset(0.24, 0.68),
    solarRaysOpacity: 0.70,
    lunarHaloOpacity: 0.0,
    mountainFarColor: Color(0xFF4A044E),
    mountainMidColor: Color(0xFF2E0854),
    horizonSkylineColor: Color(0xFF2A0822),
    distantSkylineColor: Color(0x77BE185D),
    horizonAtmosphericFog: Color(0x77EA580C),
    windowGlowColors: [Color(0xFFFDE047), Color(0xFFFB923C), Color(0xFFFFFFFF)],
    windowGlowIntensity: 0.85,
    asphaltGradient: [
      Color(0xFF2E2430),
      Color(0xFF201824),
      Color(0xFF120C14),
    ],
    asphaltSpecularReflection: Color(0x40EA580C),
    tireTrackShade: Color(0x35000000),
    laneStripeColor: Color(0xFFFEF08A),
    curbColorA: Color(0xFFFFFFFF),
    curbColorB: Color(0xFFF97316),
    sidewalkBaseColor: Color(0xFF334155),
    sidewalkTileColor: Color(0xFF475569),
    shoulderGradient: [
      Color(0xFF2A1028),
      Color(0xFF1C0A1A),
      Color(0xFF0F040E),
    ],
    guardrailColor: Color(0xFF94A3B8),
    guardrailPostColor: Color(0xFF475569),
    ambientNeonUnderglow: Color(0xFFF59E0B),
    natureFoliageColor: Color(0xFF15803D),
    streetLightGlowColor: Color(0xFFFDE047),
    streetLightIntensity: 0.75,
    headlightIntensity: 0.80,
    neonSignIntensity: 0.85,
    shadowOffset: Offset(-14.0, 8.0),
    shadowOpacity: 0.38,
  );

  // 4. NIGHT (Midnight Cyber Metropolis / Glowing Lights & Headlights)
  static const RoadEnvironmentTheme night = RoadEnvironmentTheme(
    name: "Midnight Metropolis",
    timeState: TimeOfDayState.night,
    skyGradient: [
      Color(0xFF030712),
      Color(0xFF0B0F19),
      Color(0xFF111827),
      Color(0xFF1E1B4B),
    ],
    skyStops: [0.0, 0.4, 0.75, 1.0],
    celestialBodyColor: Color(0xFFE2E8F0),
    celestialBodyRadius: 16.0,
    celestialNormalizedPos: Offset(0.80, 0.32),
    solarRaysOpacity: 0.0,
    lunarHaloOpacity: 0.85,
    mountainFarColor: Color(0xFF0F172A),
    mountainMidColor: Color(0xFF090D16),
    horizonSkylineColor: Color(0xFF0F172A),
    distantSkylineColor: Color(0x661E293B),
    horizonAtmosphericFog: Color(0x5538BDF8),
    windowGlowColors: [
      Color(0xFF00F2FE),
      Color(0xFFFBBF24),
      Color(0xFFFF0055),
      Color(0xFFFFFFFF),
    ],
    windowGlowIntensity: 1.0,
    asphaltGradient: [
      Color(0xFF1E2430),
      Color(0xFF131720),
      Color(0xFF0A0C10),
    ],
    asphaltSpecularReflection: Color(0x3500F2FE),
    tireTrackShade: Color(0x40000000),
    laneStripeColor: Color(0xFF00F2FE),
    curbColorA: Color(0xFF00F2FE),
    curbColorB: Color(0xFFFF0055),
    sidewalkBaseColor: Color(0xFF1E293B),
    sidewalkTileColor: Color(0xFF334155),
    shoulderGradient: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
      Color(0xFF020617),
    ],
    guardrailColor: Color(0xFF8B5CF6),
    guardrailPostColor: Color(0xFF4C1D95),
    ambientNeonUnderglow: Color(0xFFFF007F),
    natureFoliageColor: Color(0xFF06B6D4),
    streetLightGlowColor: Color(0xFF00F2FE),
    streetLightIntensity: 1.0,
    headlightIntensity: 1.0,
    neonSignIntensity: 1.0,
    shadowOffset: Offset(0.0, 2.0),
    shadowOpacity: 0.45,
  );

  static const RoadEnvironmentTheme cityNight = night;
  static const RoadEnvironmentTheme neonCyber = night;
  static const RoadEnvironmentTheme sunsetCoast = evening;
  static const RoadEnvironmentTheme desertHighway = day;

  // LERP INTERPOLATION
  static RoadEnvironmentTheme lerp(RoadEnvironmentTheme a, RoadEnvironmentTheme b, double t) {
    final double clampedT = t.clamp(0.0, 1.0);
    final double smoothT = clampedT * clampedT * (3.0 - 2.0 * clampedT);

    List<Color> lerpColorList(List<Color> listA, List<Color> listB) {
      final int len = max(listA.length, listB.length);
      final List<Color> result = [];
      for (int i = 0; i < len; i++) {
        final Color ca = listA[min(i, listA.length - 1)];
        final Color cb = listB[min(i, listB.length - 1)];
        result.add(Color.lerp(ca, cb, smoothT) ?? ca);
      }
      return result;
    }

    return RoadEnvironmentTheme(
      name: "${a.name} -> ${b.name}",
      timeState: smoothT < 0.5 ? a.timeState : b.timeState,
      skyGradient: lerpColorList(a.skyGradient, b.skyGradient),
      skyStops: a.skyStops,
      celestialBodyColor: Color.lerp(a.celestialBodyColor, b.celestialBodyColor, smoothT) ?? a.celestialBodyColor,
      celestialBodyRadius: a.celestialBodyRadius + (b.celestialBodyRadius - a.celestialBodyRadius) * smoothT,
      celestialNormalizedPos: Offset.lerp(a.celestialNormalizedPos, b.celestialNormalizedPos, smoothT) ?? a.celestialNormalizedPos,
      solarRaysOpacity: a.solarRaysOpacity + (b.solarRaysOpacity - a.solarRaysOpacity) * smoothT,
      lunarHaloOpacity: a.lunarHaloOpacity + (b.lunarHaloOpacity - a.lunarHaloOpacity) * smoothT,
      mountainFarColor: Color.lerp(a.mountainFarColor, b.mountainFarColor, smoothT) ?? a.mountainFarColor,
      mountainMidColor: Color.lerp(a.mountainMidColor, b.mountainMidColor, smoothT) ?? a.mountainMidColor,
      horizonSkylineColor: Color.lerp(a.horizonSkylineColor, b.horizonSkylineColor, smoothT) ?? a.horizonSkylineColor,
      distantSkylineColor: Color.lerp(a.distantSkylineColor, b.distantSkylineColor, smoothT) ?? a.distantSkylineColor,
      horizonAtmosphericFog: Color.lerp(a.horizonAtmosphericFog, b.horizonAtmosphericFog, smoothT) ?? a.horizonAtmosphericFog,
      windowGlowColors: lerpColorList(a.windowGlowColors, b.windowGlowColors),
      windowGlowIntensity: a.windowGlowIntensity + (b.windowGlowIntensity - a.windowGlowIntensity) * smoothT,
      asphaltGradient: lerpColorList(a.asphaltGradient, b.asphaltGradient),
      asphaltSpecularReflection: Color.lerp(a.asphaltSpecularReflection, b.asphaltSpecularReflection, smoothT) ?? a.asphaltSpecularReflection,
      tireTrackShade: Color.lerp(a.tireTrackShade, b.tireTrackShade, smoothT) ?? a.tireTrackShade,
      laneStripeColor: Color.lerp(a.laneStripeColor, b.laneStripeColor, smoothT) ?? a.laneStripeColor,
      curbColorA: Color.lerp(a.curbColorA, b.curbColorA, smoothT) ?? a.curbColorA,
      curbColorB: Color.lerp(a.curbColorB, b.curbColorB, smoothT) ?? a.curbColorB,
      sidewalkBaseColor: Color.lerp(a.sidewalkBaseColor, b.sidewalkBaseColor, smoothT) ?? a.sidewalkBaseColor,
      sidewalkTileColor: Color.lerp(a.sidewalkTileColor, b.sidewalkTileColor, smoothT) ?? a.sidewalkTileColor,
      shoulderGradient: lerpColorList(a.shoulderGradient, b.shoulderGradient),
      guardrailColor: Color.lerp(a.guardrailColor, b.guardrailColor, smoothT) ?? a.guardrailColor,
      guardrailPostColor: Color.lerp(a.guardrailPostColor, b.guardrailPostColor, smoothT) ?? a.guardrailPostColor,
      ambientNeonUnderglow: Color.lerp(a.ambientNeonUnderglow, b.ambientNeonUnderglow, smoothT) ?? a.ambientNeonUnderglow,
      natureFoliageColor: Color.lerp(a.natureFoliageColor, b.natureFoliageColor, smoothT) ?? a.natureFoliageColor,
      streetLightGlowColor: Color.lerp(a.streetLightGlowColor, b.streetLightGlowColor, smoothT) ?? a.streetLightGlowColor,
      streetLightIntensity: a.streetLightIntensity + (b.streetLightIntensity - a.streetLightIntensity) * smoothT,
      headlightIntensity: a.headlightIntensity + (b.headlightIntensity - a.headlightIntensity) * smoothT,
      neonSignIntensity: a.neonSignIntensity + (b.neonSignIntensity - a.neonSignIntensity) * smoothT,
      shadowOffset: Offset.lerp(a.shadowOffset, b.shadowOffset, smoothT) ?? a.shadowOffset,
      shadowOpacity: a.shadowOpacity + (b.shadowOpacity - a.shadowOpacity) * smoothT,
    );
  }
}

/// Reusable Pooled Road Segment
class RoadSegment {
  int index;
  double relativeYOffset;
  final List<RoadImperfection> imperfections = [];

  RoadSegment({required this.index, required this.relativeYOffset});

  void reset(int newIndex, double newYOffset, Random random) {
    index = newIndex;
    relativeYOffset = newYOffset;
    imperfections.clear();

    if (random.nextDouble() < 0.45) {
      final type = RoadImperfectionType.values[random.nextInt(RoadImperfectionType.values.length)];
      imperfections.add(RoadImperfection(
        normalizedY: 0.15 + random.nextDouble() * 0.7,
        laneProgress: (random.nextInt(3)).toDouble() + (random.nextDouble() * 0.4 - 0.2),
        type: type,
        scale: 0.8 + random.nextDouble() * 0.4,
        rotation: (random.nextDouble() - 0.5) * 0.4,
      ));
    }
  }
}

/// A Reusable Pooled Roadside Environment Prop Object
class RoadsideProp {
  double y;
  RoadsidePropType type;
  int variant;
  double scale;
  double lateralOffset;
  bool isLeftSide;
  double rotation;
  double extraData;
  bool active;

  RoadsideProp({
    required this.y,
    required this.type,
    this.variant = 0,
    this.scale = 1.0,
    this.lateralOffset = 30.0,
    required this.isLeftSide,
    this.rotation = 0.0,
    this.extraData = 0.0,
    this.active = true,
  });

  void reset({
    required double newY,
    required RoadsidePropType newType,
    required int newVariant,
    required double newScale,
    required double newLateralOffset,
    required bool newIsLeftSide,
    required double newRotation,
    double newExtraData = 0.0,
  }) {
    y = newY;
    type = newType;
    variant = newVariant;
    scale = newScale;
    lateralOffset = newLateralOffset;
    isLeftSide = newIsLeftSide;
    rotation = newRotation;
    extraData = newExtraData;
    active = true;
  }
}

/// Backward compatibility alias
typedef RoadSceneryProp = RoadsideProp;

/// Multi-Tier Parallax Cloud Object (Layer 2)
class ParallaxCloud {
  double x;
  double y;
  double width;
  double speed;
  double opacity;
  int tier; // 0 = High Wispy Cirrus, 1 = Puffy Cumulus

  ParallaxCloud({
    required this.x,
    required this.y,
    required this.width,
    required this.speed,
    required this.opacity,
    this.tier = 1,
  });
}

/// Backward compatibility alias
typedef RoadCloud = ParallaxCloud;

/// ============================================================================
/// 4-LAYER PARALLAX CONTROLLER & ROAD ENVIRONMENT ENGINE
/// ============================================================================
class EndlessRoadSystem {
  // Current active dynamic theme (interpolated every frame)
  RoadEnvironmentTheme theme = RoadEnvironmentTheme.morning;

  // Day/Night Cycle Configuration
  DayNightTransitionMode transitionMode = DayNightTransitionMode.automaticDistance;
  double cycleDistance = 1600.0;
  double cycleDurationSeconds = 75.0;
  double timeOfDayProgress = 0.0;
  TimeOfDayState activeTimeState = TimeOfDayState.morning;

  // Track & Parallax Accumulators
  double roadScrollOffset = 0.0;
  double mountainScrollOffset = 0.0; // Layer 3 Parallax Accumulator (~0.35x speed)
  double totalDistance = 0.0;
  double animationTimer = 0.0;
  static const double segmentLength = 220.0;
  static const int pooledSegmentCount = 6;

  // Roadside Props Pool Parameters (Layer 4)
  static const int pooledPropsPerSide = 22;
  static const double minPropSpacing = 85.0;
  static const double maxPropSpacing = 145.0;

  final List<RoadSegment> _segmentPool = [];
  final List<RoadsideProp> _leftProps = [];
  final List<RoadsideProp> _rightProps = [];
  final List<ParallaxCloud> _clouds = [];
  final Random _random = Random();

  void init({
    RoadEnvironmentTheme? initialTheme,
    DayNightTransitionMode mode = DayNightTransitionMode.automaticDistance,
  }) {
    transitionMode = mode;
    if (initialTheme != null) {
      theme = initialTheme;
      activeTimeState = initialTheme.timeState;
    } else {
      theme = RoadEnvironmentTheme.morning;
      activeTimeState = TimeOfDayState.morning;
    }

    _segmentPool.clear();
    _leftProps.clear();
    _rightProps.clear();
    _clouds.clear();
    animationTimer = 0.0;
    timeOfDayProgress = 0.0;
    mountainScrollOffset = 0.0;

    // 1. Initialize Pooled Road Segments
    for (int i = 0; i < pooledSegmentCount; i++) {
      final seg = RoadSegment(index: i, relativeYOffset: i * segmentLength);
      seg.reset(i, i * segmentLength, _random);
      _segmentPool.add(seg);
    }

    // 2. Initialize Left & Right City Roadside Props Pool (Layer 4)
    for (int i = 0; i < pooledPropsPerSide; i++) {
      final initialYLeft = i * 95.0;
      final initialYRight = i * 95.0 + 48.0;

      final leftProp = RoadsideProp(
        y: initialYLeft,
        type: _getCityBiasedPropType(),
        variant: _random.nextInt(4),
        scale: 0.85 + _random.nextDouble() * 0.35,
        lateralOffset: 16.0 + _random.nextDouble() * 50.0,
        isLeftSide: true,
        rotation: (_random.nextDouble() - 0.5) * 0.08,
        extraData: _random.nextDouble() * 100.0,
      );
      _leftProps.add(leftProp);

      final rightProp = RoadsideProp(
        y: initialYRight,
        type: _getCityBiasedPropType(),
        variant: _random.nextInt(4),
        scale: 0.85 + _random.nextDouble() * 0.35,
        lateralOffset: 16.0 + _random.nextDouble() * 50.0,
        isLeftSide: false,
        rotation: (_random.nextDouble() - 0.5) * 0.08,
        extraData: _random.nextDouble() * 100.0,
      );
      _rightProps.add(rightProp);
    }

    // 3. Initialize Multi-Tier Parallax Clouds (Layer 2)
    // Tier 0: High-Altitude Wispy Cirrus (3 Clouds)
    for (int i = 0; i < 3; i++) {
      _clouds.add(ParallaxCloud(
        x: _random.nextDouble() * 450.0,
        y: 6.0 + _random.nextDouble() * 35.0,
        width: 80.0 + _random.nextDouble() * 90.0,
        speed: 6.0 + _random.nextDouble() * 10.0,
        opacity: 0.20 + _random.nextDouble() * 0.25,
        tier: 0,
      ));
    }
    // Tier 1: Mid-Altitude Puffy Cumulus (4 Clouds)
    for (int i = 0; i < 4; i++) {
      _clouds.add(ParallaxCloud(
        x: _random.nextDouble() * 450.0,
        y: 28.0 + _random.nextDouble() * 55.0,
        width: 55.0 + _random.nextDouble() * 65.0,
        speed: 14.0 + _random.nextDouble() * 18.0,
        opacity: 0.35 + _random.nextDouble() * 0.35,
        tier: 1,
      ));
    }
  }

  void setTimeOfDay(TimeOfDayState state) {
    transitionMode = DayNightTransitionMode.fixed;
    activeTimeState = state;
    switch (state) {
      case TimeOfDayState.morning:
        theme = RoadEnvironmentTheme.morning;
        timeOfDayProgress = 0.0;
        break;
      case TimeOfDayState.day:
        theme = RoadEnvironmentTheme.day;
        timeOfDayProgress = 1.0;
        break;
      case TimeOfDayState.evening:
        theme = RoadEnvironmentTheme.evening;
        timeOfDayProgress = 2.0;
        break;
      case TimeOfDayState.night:
        theme = RoadEnvironmentTheme.night;
        timeOfDayProgress = 3.0;
        break;
    }
  }

  void setTransitionMode(DayNightTransitionMode mode) {
    transitionMode = mode;
  }

  RoadsidePropType _getCityBiasedPropType() {
    final roll = _random.nextDouble();
    if (roll < 0.22) return RoadsidePropType.building;
    if (roll < 0.40) return RoadsidePropType.shop;
    if (roll < 0.54) return RoadsidePropType.streetLight;
    if (roll < 0.68) return RoadsidePropType.billboard;
    if (roll < 0.78) return RoadsidePropType.trafficLight;
    if (roll < 0.86) return RoadsidePropType.bridge;
    if (roll < 0.93) return RoadsidePropType.parkingArea;
    if (roll < 0.97) return RoadsidePropType.guardRail;
    return RoadsidePropType.tree;
  }

  /// 60 FPS Parallax Update Loop
  void update(double dt, double speed, double screenHeight, double screenWidth) {
    final double moveDelta = speed * dt;
    totalDistance += moveDelta * 0.18;
    animationTimer += dt;

    // 1. Dynamic Day/Night Cycle Smooth Interpolation
    _updateDayNightCycle();

    // 2. Continuous Road Lane Scroll (Layer 4: 1.00x speed)
    roadScrollOffset = (roadScrollOffset + moveDelta) % segmentLength;

    // 3. Mountains / Distant Skyline Parallax (Layer 3: 0.35x speed)
    mountainScrollOffset = (mountainScrollOffset + moveDelta * 0.35) % 480.0;

    // 4. Update and cycle pooled road segments
    for (int i = 0; i < _segmentPool.length; i++) {
      final seg = _segmentPool[i];
      seg.relativeYOffset += moveDelta;
      if (seg.relativeYOffset > screenHeight + segmentLength) {
        double minY = double.infinity;
        for (final s in _segmentPool) {
          if (s.relativeYOffset < minY) minY = s.relativeYOffset;
        }
        final newY = minY - segmentLength;
        seg.reset(seg.index + pooledSegmentCount, newY, _random);
      }
    }

    // 5. Update & Recycle Roadside Props (Layer 4)
    _updateRoadsideList(_leftProps, moveDelta, screenHeight, true);
    _updateRoadsideList(_rightProps, moveDelta, screenHeight, false);

    // 6. Update Parallax Clouds (Layer 2: Wind + Parallax forward drift)
    for (final c in _clouds) {
      final double forwardCloudSpeed = (c.tier == 0) ? 0.06 : 0.14;
      c.x += (c.speed + speed * forwardCloudSpeed) * dt;
      if (c.x > screenWidth + 140.0) {
        c.x = -c.width - 60.0;
        c.y = (c.tier == 0) ? (6.0 + _random.nextDouble() * 35.0) : (28.0 + _random.nextDouble() * 55.0);
      }
    }
  }

  void _updateDayNightCycle() {
    if (transitionMode == DayNightTransitionMode.fixed) return;

    if (transitionMode == DayNightTransitionMode.automaticDistance) {
      timeOfDayProgress = (totalDistance / cycleDistance * 4.0) % 4.0;
    } else if (transitionMode == DayNightTransitionMode.automaticTime) {
      timeOfDayProgress = (animationTimer / cycleDurationSeconds * 4.0) % 4.0;
    }

    final int baseIndex = timeOfDayProgress.floor() % 4;
    final double progress = timeOfDayProgress - timeOfDayProgress.floor();

    final states = [
      RoadEnvironmentTheme.morning,
      RoadEnvironmentTheme.day,
      RoadEnvironmentTheme.evening,
      RoadEnvironmentTheme.night,
    ];

    final themeA = states[baseIndex];
    final themeB = states[(baseIndex + 1) % 4];

    theme = RoadEnvironmentTheme.lerp(themeA, themeB, progress);
    activeTimeState = theme.timeState;
  }

  void _updateRoadsideList(List<RoadsideProp> props, double moveDelta, double screenHeight, bool isLeft) {
    for (int i = 0; i < props.length; i++) {
      final prop = props[i];
      prop.y += moveDelta;

      if (prop.y > screenHeight + 120.0) {
        double minY = double.infinity;
        for (final p in props) {
          if (p.y < minY) minY = p.y;
        }
        final double spawnSpacing = minPropSpacing + _random.nextDouble() * (maxPropSpacing - minPropSpacing);
        final double newY = minY - spawnSpacing;

        prop.reset(
          newY: newY,
          newType: _getCityBiasedPropType(),
          newVariant: _random.nextInt(4),
          newScale: 0.85 + _random.nextDouble() * 0.35,
          newLateralOffset: 16.0 + _random.nextDouble() * 50.0,
          newIsLeftSide: isLeft,
          newRotation: (_random.nextDouble() - 0.5) * 0.08,
          newExtraData: _random.nextDouble() * 100.0,
        );
      }
    }
  }

  List<RoadSegment> get segments => _segmentPool;
  List<RoadsideProp> get leftProps => _leftProps;
  List<RoadsideProp> get rightProps => _rightProps;
  List<RoadSceneryProp> get leftScenery => _leftProps;
  List<RoadSceneryProp> get rightScenery => _rightProps;
  List<ParallaxCloud> get clouds => _clouds;
}

/// ============================================================================
/// PERSPECTIVE PROJECTION & 4-LAYER PARALLAX RENDERER
/// ============================================================================
class RoadVisualRenderer {
  static void drawCompleteRoadEnvironment({
    required Canvas canvas,
    required Size size,
    required EndlessRoadSystem roadSystem,
    required double horizonY,
    required double roadTopWidth,
    required double roadBottomWidth,
    required double roadLeft,
    required double roadRight,
    required double laneWidth,
    double laneProgress = 0.0, // Used for Layer 3 lateral steering parallax
  }) {
    final theme = roadSystem.theme;

    // ------------------------------------------------------------------------
    // PARALLAX LAYER 1: Sky Gradient, Sun/Moon, Solar Flares & Starfield (0.02x)
    // ------------------------------------------------------------------------
    _drawParallaxLayer1Sky(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      theme: theme,
      time: roadSystem.animationTimer,
    );

    // ------------------------------------------------------------------------
    // PARALLAX LAYER 2: Multi-Tier Clouds (0.12x speed)
    // ------------------------------------------------------------------------
    _drawParallaxLayer2Clouds(
      canvas: canvas,
      horizonY: horizonY,
      clouds: roadSystem.clouds,
      theme: theme,
    );

    // ------------------------------------------------------------------------
    // PARALLAX LAYER 3: Mountains, Skyline & Atmospheric Fog (0.35x speed + lateral parallax)
    // ------------------------------------------------------------------------
    _drawParallaxLayer3MountainsAndSkyline(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      theme: theme,
      laneProgress: laneProgress,
      mountainOffset: roadSystem.mountainScrollOffset,
      time: roadSystem.animationTimer,
    );

    // ------------------------------------------------------------------------
    // PARALLAX LAYER 4: Roadside Objects, Sidewalks, Guardrails, & 3D Curbs (1.00x)
    // ------------------------------------------------------------------------
    _drawParallaxLayer4RoadAndShoulders(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      roadLeft: roadLeft,
      roadRight: roadRight,
      roadTopWidth: roadTopWidth,
      roadBottomWidth: roadBottomWidth,
      laneWidth: laneWidth,
      roadSystem: roadSystem,
      theme: theme,
    );
  }

  // ==========================================================================
  // PARALLAX LAYER 1: SKY & CELESTIAL BODIES (SUN / MOON / STARS)
  // ==========================================================================
  static void _drawParallaxLayer1Sky({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required RoadEnvironmentTheme theme,
    required double time,
  }) {
    // 1. Dynamic 4-Stop Sky Gradient
    final Rect skyRect = Rect.fromLTWH(0, 0, size.width, horizonY + 35);
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: theme.skyGradient,
        stops: theme.skyStops,
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // 2. Stars Field in Night & Morning
    if (theme.timeState == TimeOfDayState.night || theme.timeState == TimeOfDayState.morning) {
      final double starAlpha = (theme.timeState == TimeOfDayState.night) ? 0.75 : 0.35;
      final starsPaint = Paint()..color = Colors.white.withValues(alpha: starAlpha);
      for (int i = 0; i < 24; i++) {
        final sx = (i * 49.0 + 17) % size.width;
        final sy = (i * 21.0 + 9) % (horizonY * 0.65);
        final r = (i % 4 == 0) ? 1.6 : 1.0;
        canvas.drawCircle(Offset(sx, sy), r, starsPaint);
      }
    }

    // 3. Sun or Moon Celestial Rendering
    final double cx = size.width * theme.celestialNormalizedPos.dx;
    final double cy = horizonY * theme.celestialNormalizedPos.dy;
    final double r = theme.celestialBodyRadius;

    if (theme.timeState == TimeOfDayState.night) {
      // Lunar Halo & Crescent/Full Moon
      if (theme.lunarHaloOpacity > 0.05) {
        final haloPaint = Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: theme.lunarHaloOpacity * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
        canvas.drawCircle(Offset(cx, cy), r * 2.2, haloPaint);
      }
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = theme.celestialBodyColor);
      canvas.drawCircle(Offset(cx + 4.5, cy - 2.5), r * 0.85, Paint()..color = theme.skyGradient[0]);
    } else {
      // Radiant Sun with Solar Corona & Flare Rays
      if (theme.solarRaysOpacity > 0.05) {
        final coronaPaint = Paint()
          ..color = theme.celestialBodyColor.withValues(alpha: theme.solarRaysOpacity * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
        canvas.drawCircle(Offset(cx, cy), r * 2.4, coronaPaint);

        final rayPaint = Paint()
          ..color = theme.celestialBodyColor.withValues(alpha: theme.solarRaysOpacity * 0.20)
          ..strokeWidth = 2.0;
        for (int i = 0; i < 8; i++) {
          final angle = (i * pi / 4) + time * 0.2;
          final p1 = Offset(cx + cos(angle) * (r + 4), cy + sin(angle) * (r + 4));
          final p2 = Offset(cx + cos(angle) * (r + 22), cy + sin(angle) * (r + 22));
          canvas.drawLine(p1, p2, rayPaint);
        }
      }
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = theme.celestialBodyColor);
    }
  }

  // ==========================================================================
  // PARALLAX LAYER 2: MULTI-TIER PARALLAX CLOUDS (0.12x)
  // ==========================================================================
  static void _drawParallaxLayer2Clouds({
    required Canvas canvas,
    required double horizonY,
    required List<ParallaxCloud> clouds,
    required RoadEnvironmentTheme theme,
  }) {
    for (final cloud in clouds) {
      if (cloud.y > horizonY + 15) continue;

      if (cloud.tier == 0) {
        // High-Altitude Wispy Cirrus (Soft Elongated Streaks)
        final cirrusPaint = Paint()
          ..color = Colors.white.withValues(alpha: cloud.opacity * 0.45);
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cloud.x, cloud.y, cloud.width, 10.0),
          const Radius.circular(5.0),
        );
        canvas.drawRRect(rrect, cirrusPaint);
      } else {
        // Mid-Altitude 3D Puffy Cumulus (Multi-Lobe Shading)
        final baseColor = Colors.white.withValues(alpha: cloud.opacity * 0.65);
        final shadowColor = theme.timeState == TimeOfDayState.evening
            ? const Color(0xFFF97316).withValues(alpha: cloud.opacity * 0.5)
            : const Color(0xFF94A3B8).withValues(alpha: cloud.opacity * 0.4);

        final double cx = cloud.x;
        final double cy = cloud.y;
        final double cw = cloud.width;

        // Cloud Base Shadow
        final baseRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx, cy + 6, cw, 14.0),
          const Radius.circular(8.0),
        );
        canvas.drawRRect(baseRRect, Paint()..color = shadowColor);

        // Multi-Lobe Puff Domes
        canvas.drawCircle(Offset(cx + cw * 0.25, cy + 6), 12.0, Paint()..color = baseColor);
        canvas.drawCircle(Offset(cx + cw * 0.50, cy + 2), 16.0, Paint()..color = baseColor);
        canvas.drawCircle(Offset(cx + cw * 0.75, cy + 7), 11.0, Paint()..color = baseColor);
      }
    }
  }

  // ==========================================================================
  // PARALLAX LAYER 3: MOUNTAINS, DISTANT SKYLINE & ATMOSPHERIC FOG (0.35x)
  // ==========================================================================
  static void _drawParallaxLayer3MountainsAndSkyline({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required RoadEnvironmentTheme theme,
    required double laneProgress,
    required double mountainOffset,
    required double time,
  }) {
    // Lateral steering parallax offset (Moves background realistically when player steers)
    final double steerParallax = -laneProgress * 22.0;

    // 1. Far Mountain Ridge (Jagged Peaks with Depth Fog)
    final farMountainPaint = Paint()..color = theme.mountainFarColor;
    final Path farMountains = Path()..moveTo(-50 + steerParallax, horizonY);

    const int peakCount = 12;
    final double peakW = (size.width + 100) / (peakCount - 1);
    for (int i = 0; i < peakCount; i++) {
      final double px = -50 + steerParallax + i * peakW;
      final double ph = 32.0 + (sin(i * 1.5 + 0.4) * 22.0).abs();
      farMountains.lineTo(px, horizonY - ph);
    }
    farMountains.lineTo(size.width + 50 + steerParallax, horizonY);
    farMountains.close();
    canvas.drawPath(farMountains, farMountainPaint);

    // 2. Mid-Distance Foothills / City Skyline
    final midSkylinePaint = Paint()..color = theme.mountainMidColor;
    for (int i = 0; i < 16; i++) {
      final double bx = steerParallax + (i * (size.width / 14)) - 20;
      final double bw = size.width / 15 + 6;
      final double bh = 22.0 + (sin(i * 1.9 + 1.2) * 20.0).abs();
      canvas.drawRect(Rect.fromLTWH(bx, horizonY - bh, bw, bh + 14), midSkylinePaint);

      // Lit Windows on Skyline Buildings
      if (i % 2 == 0 && theme.windowGlowIntensity > 0.05) {
        final winColor = theme.windowGlowColors[i % theme.windowGlowColors.length];
        final winPaint = Paint()..color = winColor.withValues(alpha: (0.75 * theme.windowGlowIntensity).clamp(0.0, 1.0));
        for (int row = 0; row < 3; row++) {
          canvas.drawCircle(Offset(bx + bw * 0.45, horizonY - bh + 6 + row * 7), 1.2, winPaint);
        }
      }
    }

    // 3. Atmospheric Horizon Fog (Seamlessly blends background into road)
    final fogPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          theme.horizonAtmosphericFog,
          theme.horizonAtmosphericFog.withValues(alpha: 0.1),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, horizonY - 25, size.width, 45));

    canvas.drawRect(Rect.fromLTWH(0, horizonY - 25, size.width, 45), fogPaint);
  }

  // ==========================================================================
  // PARALLAX LAYER 4: ROADSIDE OBJECTS, SIDEWALKS, ASPHALT & CURBS (1.00x)
  // ==========================================================================
  static void _drawParallaxLayer4RoadAndShoulders({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required double roadLeft,
    required double roadRight,
    required double roadTopWidth,
    required double roadBottomWidth,
    required double laneWidth,
    required EndlessRoadSystem roadSystem,
    required RoadEnvironmentTheme theme,
  }) {
    // 1. Concrete Sidewalks & Road Shoulders
    _drawSidewalksAndShoulders(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      roadLeft: roadLeft,
      roadRight: roadRight,
      roadTopWidth: roadTopWidth,
      roadBottomWidth: roadBottomWidth,
      theme: theme,
      roadScrollOffset: roadSystem.roadScrollOffset,
    );

    // 2. Main 3-Lane Asphalt Highway Surface & Specular Reflections
    _drawAsphaltHighway(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      roadTopWidth: roadTopWidth,
      roadBottomWidth: roadBottomWidth,
      roadLeft: roadLeft,
      roadRight: roadRight,
      laneWidth: laneWidth,
      theme: theme,
    );

    // 3. Segment Imperfections (Tar Cracks, Skid Marks, Oil Slicks, Manholes)
    _drawRoadImperfections(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      roadTopWidth: roadTopWidth,
      roadBottomWidth: roadBottomWidth,
      roadLeft: roadLeft,
      roadRight: roadRight,
      laneWidth: laneWidth,
      segments: roadSystem.segments,
    );

    // 4. Perspective-Scaled White Dashed Lane Dividers (Zero Seams)
    _drawLaneDividerMarkings(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      roadTopWidth: roadTopWidth,
      roadBottomWidth: roadBottomWidth,
      roadLeft: roadLeft,
      roadRight: roadRight,
      laneWidth: laneWidth,
      roadScrollOffset: roadSystem.roadScrollOffset,
      theme: theme,
    );

    // 5. 3D Beveled Racing Curbs (Red & White Alternating)
    _drawBeveledRacingCurbs(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      roadTopWidth: roadTopWidth,
      roadBottomWidth: roadBottomWidth,
      roadLeft: roadLeft,
      roadRight: roadRight,
      roadScrollOffset: roadSystem.roadScrollOffset,
      theme: theme,
    );

    // 6. Procedural City & Roadside Objects (All 16 Types with 1.00x Parallax)
    _drawCityBlockProps(
      canvas: canvas,
      size: size,
      horizonY: horizonY,
      roadLeft: roadLeft,
      roadRight: roadRight,
      roadTopWidth: roadTopWidth,
      roadBottomWidth: roadBottomWidth,
      theme: theme,
      leftProps: roadSystem.leftProps,
      rightProps: roadSystem.rightProps,
      time: roadSystem.animationTimer,
    );
  }

  // --------------------------------------------------------------------------
  // SIDEWALKS & SHOULDERS
  // --------------------------------------------------------------------------
  static void _drawSidewalksAndShoulders({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required double roadLeft,
    required double roadRight,
    required double roadTopWidth,
    required double roadBottomWidth,
    required RoadEnvironmentTheme theme,
    required double roadScrollOffset,
  }) {
    final double roadTopLeft = (size.width - roadTopWidth) / 2;
    final double roadTopRight = roadTopLeft + roadTopWidth;
    final double roadHeight = size.height - horizonY;

    final Path leftSidewalk = Path()
      ..moveTo(0, horizonY)
      ..lineTo(roadTopLeft, horizonY)
      ..lineTo(roadLeft, size.height)
      ..lineTo(0, size.height)
      ..close();

    final Paint sidewalkPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: theme.shoulderGradient,
      ).createShader(Rect.fromLTWH(0, horizonY, size.width, roadHeight));

    canvas.drawPath(leftSidewalk, sidewalkPaint);

    final Path rightSidewalk = Path()
      ..moveTo(roadTopRight, horizonY)
      ..lineTo(size.width, horizonY)
      ..lineTo(size.width, size.height)
      ..lineTo(roadRight, size.height)
      ..close();

    canvas.drawPath(rightSidewalk, sidewalkPaint);

    final paverPaint = Paint()
      ..color = theme.sidewalkTileColor.withValues(alpha: 0.35)
      ..strokeWidth = 1.4;

    const int paverSteps = 16;
    final double stepY = roadHeight / paverSteps;

    for (int i = 0; i < paverSteps + 2; i++) {
      final double y = horizonY + ((i * stepY + roadScrollOffset) % (roadHeight + stepY));
      if (y < horizonY || y > size.height) continue;
      final double p = ((y - horizonY) / roadHeight).clamp(0.0, 1.0);

      final double xl = roadTopLeft + (roadLeft - roadTopLeft) * p;
      final double xr = roadTopRight + (roadRight - roadTopRight) * p;

      canvas.drawLine(Offset(0, y), Offset(xl, y), paverPaint);
      canvas.drawLine(Offset(xr, y), Offset(size.width, y), paverPaint);

      if (i % 4 == 0) {
        final gratePaint = Paint()..color = const Color(0xFF1E293B);
        final grateW = 10.0 + p * 14.0;
        final grateH = 3.0 + p * 4.0;
        canvas.drawRect(Rect.fromLTWH(xl - grateW - 2, y, grateW, grateH), gratePaint);
        canvas.drawRect(Rect.fromLTWH(xr + 2, y, grateW, grateH), gratePaint);
      }
    }
  }

  // --------------------------------------------------------------------------
  // ASPHALT HIGHWAY SURFACE & SPECULAR REFLECTIONS
  // --------------------------------------------------------------------------
  static void _drawAsphaltHighway({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required double roadTopWidth,
    required double roadBottomWidth,
    required double roadLeft,
    required double roadRight,
    required double laneWidth,
    required RoadEnvironmentTheme theme,
  }) {
    final double roadTopLeft = (size.width - roadTopWidth) / 2;
    final double roadTopRight = roadTopLeft + roadTopWidth;

    final Path roadPath = Path()
      ..moveTo(roadTopLeft, horizonY)
      ..lineTo(roadTopRight, horizonY)
      ..lineTo(roadRight, size.height)
      ..lineTo(roadLeft, size.height)
      ..close();

    final Paint roadPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: theme.asphaltGradient,
      ).createShader(Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY));

    canvas.drawPath(roadPath, roadPaint);

    final tireTrackPaint = Paint()
      ..color = theme.tireTrackShade
      ..strokeWidth = 8.0;

    for (int lane = 0; lane < 3; lane++) {
      for (final double offsetFactor in [-0.22, 0.22]) {
        final double topX = roadTopLeft + (lane + 0.5 + offsetFactor) * (roadTopWidth / 3);
        final double botX = roadLeft + (lane + 0.5 + offsetFactor) * laneWidth;
        canvas.drawLine(Offset(topX, horizonY), Offset(botX, size.height), tireTrackPaint);
      }
    }

    final specularPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          theme.asphaltSpecularReflection,
          theme.asphaltSpecularReflection.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(roadTopLeft, horizonY, roadTopWidth, size.height - horizonY));

    final Path specPath = Path()
      ..moveTo(roadTopLeft + roadTopWidth * 0.3, horizonY)
      ..lineTo(roadTopRight - roadTopWidth * 0.3, horizonY)
      ..lineTo(roadRight - roadBottomWidth * 0.2, size.height)
      ..lineTo(roadLeft + roadBottomWidth * 0.2, size.height)
      ..close();

    canvas.drawPath(specPath, specularPaint);
  }

  // --------------------------------------------------------------------------
  // ROAD IMPERFECTIONS
  // --------------------------------------------------------------------------
  static void _drawRoadImperfections({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required double roadTopWidth,
    required double roadBottomWidth,
    required double roadLeft,
    required double roadRight,
    required double laneWidth,
    required List<RoadSegment> segments,
  }) {
    final double roadTopLeft = (size.width - roadTopWidth) / 2;

    for (final seg in segments) {
      for (final imp in seg.imperfections) {
        final double y = seg.relativeYOffset + imp.normalizedY * EndlessRoadSystem.segmentLength;
        if (y < horizonY || y > size.height) continue;

        final double p = ((y - horizonY) / (size.height - horizonY)).clamp(0.0, 1.0);
        final double currentRoadLeft = roadTopLeft + (roadLeft - roadTopLeft) * p;
        final double currentLaneWidth = (roadTopWidth + (roadBottomWidth - roadTopWidth) * p) / 3;
        final double ix = currentRoadLeft + (imp.laneProgress + 0.5) * currentLaneWidth;
        final double scale = imp.scale * (0.45 + p * 0.65);

        canvas.save();
        canvas.translate(ix, y);
        canvas.rotate(imp.rotation);
        canvas.scale(scale);

        switch (imp.type) {
          case RoadImperfectionType.tarCrack:
            final crackPaint = Paint()
              ..color = Colors.black.withValues(alpha: 0.55)
              ..strokeWidth = 1.8
              ..strokeCap = StrokeCap.round;
            final Path crack = Path()
              ..moveTo(-12, -4)
              ..lineTo(-4, 0)
              ..lineTo(4, -3)
              ..lineTo(14, 5);
            canvas.drawPath(crack, crackPaint);
            break;

          case RoadImperfectionType.skidMark:
            final skidPaint = Paint()
              ..color = Colors.black.withValues(alpha: 0.45)
              ..strokeWidth = 3.5
              ..strokeCap = StrokeCap.round;
            canvas.drawLine(const Offset(-8, -16), const Offset(-6, 16), skidPaint);
            canvas.drawLine(const Offset(8, -16), const Offset(10, 16), skidPaint);
            break;

          case RoadImperfectionType.oilSlick:
            final oilPaint = Paint()
              ..shader = const RadialGradient(
                colors: [Color(0x669333EA), Color(0x4406B6D4), Colors.transparent],
              ).createShader(const Rect.fromLTWH(-16, -10, 32, 20));
            canvas.drawOval(const Rect.fromLTWH(-16, -10, 32, 20), oilPaint);
            break;

          case RoadImperfectionType.speedChevron:
            final chevPaint = Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..strokeWidth = 3.0
              ..style = PaintingStyle.stroke;
            final Path chev = Path()
              ..moveTo(-12, 6)
              ..lineTo(0, -6)
              ..lineTo(12, 6);
            canvas.drawPath(chev, chevPaint);
            break;

          case RoadImperfectionType.manholeCover:
            canvas.drawCircle(Offset.zero, 10.0, Paint()..color = const Color(0xFF334155));
            canvas.drawCircle(
              Offset.zero,
              10.0,
              Paint()
                ..color = const Color(0xFF64748B)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
            break;
        }

        canvas.restore();
      }
    }
  }

  // --------------------------------------------------------------------------
  // WHITE DASHED LANE DIVIDERS
  // --------------------------------------------------------------------------
  static void _drawLaneDividerMarkings({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required double roadTopWidth,
    required double roadBottomWidth,
    required double roadLeft,
    required double roadRight,
    required double laneWidth,
    required double roadScrollOffset,
    required RoadEnvironmentTheme theme,
  }) {
    final double roadTopLeft = (size.width - roadTopWidth) / 2;
    final double roadHeight = size.height - horizonY;

    const int stripeSteps = 20;
    final double baseSpacing = roadHeight / stripeSteps;

    for (int lineIndex = 1; lineIndex <= 2; lineIndex++) {
      for (int i = 0; i < stripeSteps + 4; i++) {
        final double rawY = horizonY + ((i * baseSpacing + roadScrollOffset) % (roadHeight + baseSpacing));
        final double p = ((rawY - horizonY) / roadHeight).clamp(0.0, 1.0);

        final double perspectiveProgress = pow(p, 1.4).toDouble();
        final double sy = horizonY + roadHeight * perspectiveProgress;

        if (sy < horizonY + 2 || sy > size.height) continue;

        final double stripeLength = (8.0 + perspectiveProgress * 28.0);
        final double strokeW = (1.2 + perspectiveProgress * 3.2);

        final double currentRoadLeft = roadTopLeft + (roadLeft - roadTopLeft) * perspectiveProgress;
        final double currentLaneWidth = (roadTopWidth + (roadBottomWidth - roadTopWidth) * perspectiveProgress) / 3;
        final double lx = currentRoadLeft + lineIndex * currentLaneWidth;

        final stripePaint = Paint()
          ..color = theme.laneStripeColor.withValues(alpha: (0.4 + perspectiveProgress * 0.55).clamp(0.0, 1.0))
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(
          Offset(lx, sy),
          Offset(lx, sy + stripeLength),
          stripePaint,
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // 3D BEVELED RACING CURBS
  // --------------------------------------------------------------------------
  static void _drawBeveledRacingCurbs({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required double roadTopWidth,
    required double roadBottomWidth,
    required double roadLeft,
    required double roadRight,
    required double roadScrollOffset,
    required RoadEnvironmentTheme theme,
  }) {
    final double roadTopLeft = (size.width - roadTopWidth) / 2;
    final double roadTopRight = roadTopLeft + roadTopWidth;
    final double roadHeight = size.height - horizonY;

    final int curbCount = 18;
    final double curbStep = roadHeight / curbCount;

    for (int i = 0; i < curbCount + 2; i++) {
      final double y1 = horizonY + ((i * curbStep + roadScrollOffset) % (roadHeight + curbStep));
      final double y2 = y1 + curbStep;

      final double p1 = ((y1 - horizonY) / roadHeight).clamp(0.0, 1.0);
      final double p2 = ((y2 - horizonY) / roadHeight).clamp(0.0, 1.0);

      final double xl1 = roadTopLeft + (roadLeft - roadTopLeft) * p1;
      final double xl2 = roadTopLeft + (roadLeft - roadTopLeft) * p2;
      final double xr1 = roadTopRight + (roadRight - roadTopRight) * p1;
      final double xr2 = roadTopRight + (roadRight - roadTopRight) * p2;

      final double curbWidth = 4.0 + p1 * 7.0;

      final bool isColorA = ((i + (roadScrollOffset / curbStep).floor()) % 2 == 0);
      final curbColor = isColorA ? theme.curbColorA : theme.curbColorB;
      final curbPaint = Paint()..color = curbColor;

      final Path leftCurbPath = Path()
        ..moveTo(xl1 - curbWidth, y1)
        ..lineTo(xl1, y1)
        ..lineTo(xl2, y2)
        ..lineTo(xl2 - curbWidth, y2)
        ..close();
      canvas.drawPath(leftCurbPath, curbPaint);

      final Path rightCurbPath = Path()
        ..moveTo(xr1, y1)
        ..lineTo(xr1 + curbWidth, y1)
        ..lineTo(xr2 + curbWidth, y2)
        ..lineTo(xr2, y2)
        ..close();
      canvas.drawPath(rightCurbPath, curbPaint);
    }
  }

  // --------------------------------------------------------------------------
  // PROCEDURAL CITY & ROADSIDE PROPS
  // --------------------------------------------------------------------------
  static void _drawCityBlockProps({
    required Canvas canvas,
    required Size size,
    required double horizonY,
    required double roadLeft,
    required double roadRight,
    required double roadTopWidth,
    required double roadBottomWidth,
    required RoadEnvironmentTheme theme,
    required List<RoadsideProp> leftProps,
    required List<RoadsideProp> rightProps,
    required double time,
  }) {
    final double roadTopLeft = (size.width - roadTopWidth) / 2;
    final double roadTopRight = roadTopLeft + roadTopWidth;

    final List<RoadsideProp> visibleLeft = leftProps
        .where((p) => p.y >= horizonY - 30.0 && p.y <= size.height + 70.0)
        .toList()
      ..sort((a, b) => a.y.compareTo(b.y));

    final List<RoadsideProp> visibleRight = rightProps
        .where((p) => p.y >= horizonY - 30.0 && p.y <= size.height + 70.0)
        .toList()
      ..sort((a, b) => a.y.compareTo(b.y));

    for (final prop in visibleLeft) {
      final double p = ((prop.y - horizonY) / (size.height - horizonY)).clamp(0.0, 1.2);
      final double currentRoadLeft = roadTopLeft + (roadLeft - roadTopLeft) * p;
      final double px = currentRoadLeft - (prop.lateralOffset * (0.7 + 0.4 * p) + 24.0 * (0.6 + 0.4 * p));
      final double depthScale = prop.scale * (0.35 + 0.65 * pow(p, 1.15).toDouble());

      _drawRoadsideProp(
        canvas: canvas,
        x: px,
        y: prop.y,
        prop: prop,
        depthScale: depthScale,
        isLeftSide: true,
        theme: theme,
        time: time,
      );
    }

    for (final prop in visibleRight) {
      final double p = ((prop.y - horizonY) / (size.height - horizonY)).clamp(0.0, 1.2);
      final double currentRoadRight = roadTopRight + (roadRight - roadTopRight) * p;
      final double px = currentRoadRight + (prop.lateralOffset * (0.7 + 0.4 * p) + 24.0 * (0.6 + 0.4 * p));
      final double depthScale = prop.scale * (0.35 + 0.65 * pow(p, 1.15).toDouble());

      _drawRoadsideProp(
        canvas: canvas,
        x: px,
        y: prop.y,
        prop: prop,
        depthScale: depthScale,
        isLeftSide: false,
        theme: theme,
        time: time,
      );
    }
  }

  static void _drawRoadsideProp({
    required Canvas canvas,
    required double x,
    required double y,
    required RoadsideProp prop,
    required double depthScale,
    required bool isLeftSide,
    required RoadEnvironmentTheme theme,
    required double time,
  }) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(prop.rotation);
    canvas.scale(depthScale);

    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: theme.shadowOpacity);
    canvas.drawOval(
      Rect.fromCenter(
        center: theme.shadowOffset,
        width: 34 + theme.shadowOffset.dx.abs(),
        height: 10,
      ),
      shadowPaint,
    );

    switch (prop.type) {
      case RoadsidePropType.building:
        _drawBuilding(canvas, prop.variant, isLeftSide, theme);
        break;
      case RoadsidePropType.shop:
        _drawShop(canvas, prop.variant, isLeftSide, time, theme);
        break;
      case RoadsidePropType.parkingArea:
        _drawParkingArea(canvas, prop.variant, isLeftSide);
        break;
      case RoadsidePropType.trafficLight:
        _drawTrafficLight(canvas, prop.variant, isLeftSide, time);
        break;
      case RoadsidePropType.bridge:
        _drawBridge(canvas, prop.variant, isLeftSide);
        break;
      case RoadsidePropType.streetLight:
        _drawStreetLight(canvas, prop.variant, isLeftSide, time, theme);
        break;
      case RoadsidePropType.roadSign:
        _drawRoadSign(canvas, prop.variant, isLeftSide);
        break;
      case RoadsidePropType.guardRail:
        _drawGuardRail(canvas, prop.variant, isLeftSide, theme);
        break;
      case RoadsidePropType.billboard:
        _drawBillboard(canvas, prop.variant, isLeftSide, time, theme);
        break;
      case RoadsidePropType.fence:
        _drawFence(canvas, prop.variant, isLeftSide);
        break;
      case RoadsidePropType.utilityPole:
        _drawUtilityPole(canvas, prop.variant, isLeftSide);
        break;
      case RoadsidePropType.tree:
        _drawTree(canvas, prop.variant, theme);
        break;
      case RoadsidePropType.bush:
        _drawBush(canvas, prop.variant, theme);
        break;
      case RoadsidePropType.grass:
        _drawGrass(canvas, prop.variant, theme);
        break;
      case RoadsidePropType.rock:
        _drawRock(canvas, prop.variant);
        break;
      case RoadsidePropType.flowers:
        _drawFlowers(canvas, prop.variant);
        break;
    }

    canvas.restore();
  }

  // ==========================================================================
  // OBJECT VECTOR RENDERERS
  // ==========================================================================
  static void _drawBuilding(Canvas canvas, int variant, bool isLeftSide, RoadEnvironmentTheme theme) {
    final double bWidth = 34.0;
    final double bHeight = 74.0 + (variant % 3) * 16.0;

    switch (variant % 3) {
      case 0:
        final glassRect = Rect.fromLTWH(-bWidth / 2, -bHeight, bWidth, bHeight);
        final glassPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.skyGradient[1].withValues(alpha: 0.9),
              theme.skyGradient[0].withValues(alpha: 0.9),
              const Color(0xFF0F172A),
            ],
          ).createShader(glassRect);

        canvas.drawRRect(RRect.fromRectAndRadius(glassRect, const Radius.circular(3.0)), glassPaint);

        final glossPath = Path()
          ..moveTo(-bWidth / 2, -bHeight * 0.7)
          ..lineTo(bWidth / 2, -bHeight * 0.9)
          ..lineTo(bWidth / 2, -bHeight * 0.75)
          ..lineTo(-bWidth / 2, -bHeight * 0.55)
          ..close();
        canvas.drawPath(glossPath, Paint()..color = Colors.white.withValues(alpha: 0.25));

        final floorPaint = Paint()..color = theme.laneStripeColor.withValues(alpha: 0.35)..strokeWidth = 1.2;
        for (double fy = -bHeight + 10; fy < 0; fy += 10.0) {
          canvas.drawLine(Offset(-bWidth / 2, fy), Offset(bWidth / 2, fy), floorPaint);
        }
        break;

      case 1:
        final bRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(-bWidth / 2, -bHeight, bWidth, bHeight),
          const Radius.circular(3.0),
        );
        canvas.drawRRect(bRect, Paint()..color = const Color(0xFF1E293B));

        if (theme.windowGlowIntensity > 0.05) {
          final winColor = theme.windowGlowColors[variant % theme.windowGlowColors.length];
          final winPaint = Paint()..color = winColor.withValues(alpha: (0.8 * theme.windowGlowIntensity).clamp(0.0, 1.0));

          final int cols = 3;
          final int rows = (bHeight / 12).floor();
          for (int r = 1; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
              if ((r + c + variant) % 2 == 0) {
                final wx = -bWidth / 2 + 5.0 + c * 8.5;
                final wy = -bHeight + 6.0 + r * 11.0;
                canvas.drawRect(Rect.fromLTWH(wx, wy, 5.0, 6.0), winPaint);
              }
            }
          }
        }
        break;

      case 2:
      default:
        final bRect1 = Rect.fromLTWH(-bWidth / 2, -bHeight * 0.65, bWidth, bHeight * 0.65);
        final bRect2 = Rect.fromLTWH(-bWidth * 0.35, -bHeight, bWidth * 0.7, bHeight * 0.35);

        canvas.drawRect(bRect1, Paint()..color = const Color(0xFF334155));
        canvas.drawRect(bRect2, Paint()..color = const Color(0xFF1E293B));

        canvas.drawLine(
          Offset(-bWidth * 0.35, -bHeight),
          Offset(bWidth * 0.35, -bHeight),
          Paint()..color = theme.laneStripeColor..strokeWidth = 2.0,
        );
        break;
    }

    canvas.drawLine(
      Offset(0, -bHeight),
      Offset(0, -bHeight - 16.0),
      Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 2.0,
    );
    canvas.drawCircle(Offset(0, -bHeight - 16.0), 2.0, Paint()..color = const Color(0xFFEF4444));
  }

  static void _drawShop(Canvas canvas, int variant, bool isLeftSide, double time, RoadEnvironmentTheme theme) {
    final sRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-22, -44, 44, 44),
      const Radius.circular(3.0),
    );
    canvas.drawRRect(sRect, Paint()..color = const Color(0xFF334155));

    final colors = [const Color(0xFFEF4444), Colors.white];
    final awningW = 48.0;
    final int stripes = 6;
    final double stripeW = awningW / stripes;

    for (int i = 0; i < stripes; i++) {
      final color = colors[i % 2];
      final Path stripe = Path()
        ..moveTo(-awningW / 2 + i * stripeW, -24)
        ..lineTo(-awningW / 2 + (i + 1) * stripeW, -24)
        ..lineTo(-awningW / 2 + (i + 0.8) * stripeW, -14)
        ..lineTo(-awningW / 2 + (i - 0.2) * stripeW, -14)
        ..close();
      canvas.drawPath(stripe, Paint()..color = color);
    }

    final winRect = const Rect.fromLTWH(-16, -13, 32, 13);
    final double winAlpha = (0.3 + 0.55 * theme.windowGlowIntensity).clamp(0.0, 1.0);
    canvas.drawRect(winRect, Paint()..color = const Color(0xFFFEF08A).withValues(alpha: winAlpha));

    final names = ['DINER', 'MART', 'CAFE', 'TUNING'];
    final signText = names[variant % names.length];
    final signRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-16, -56, 32, 12),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(signRect, Paint()..color = const Color(0xFF0F172A));

    final neonAlpha = (0.2 + 0.8 * theme.neonSignIntensity).clamp(0.0, 1.0);
    final signColor = (variant % 2 == 0)
        ? const Color(0xFFFF0055).withValues(alpha: neonAlpha)
        : const Color(0xFF00F2FE).withValues(alpha: neonAlpha);

    final tp = TextPainter(
      text: TextSpan(
        text: signText,
        style: TextStyle(
          color: signColor,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -53));
  }

  static void _drawParkingArea(Canvas canvas, int variant, bool isLeftSide) {
    final padRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-24, -36, 48, 36),
      const Radius.circular(4.0),
    );
    canvas.drawRRect(padRect, Paint()..color = const Color(0xFF1E293B));

    final linePaint = Paint()..color = const Color(0xFFFDE047)..strokeWidth = 1.6;
    canvas.drawLine(const Offset(-22, -34), const Offset(-22, -2), linePaint);
    canvas.drawLine(const Offset(0, -34), const Offset(0, -2), linePaint);
    canvas.drawLine(const Offset(22, -34), const Offset(22, -2), linePaint);

    final carBody = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-16, -28, 12, 22),
      const Radius.circular(3.0),
    );
    final carPaint = Paint()..color = (variant % 2 == 0) ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
    canvas.drawRRect(carBody, carPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -22, 8, 8), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF0F172A),
    );
  }

  static void _drawTrafficLight(Canvas canvas, int variant, bool isLeftSide, double time) {
    final polePaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final double dir = isLeftSide ? 1.0 : -1.0;

    canvas.drawLine(const Offset(0, 0), const Offset(0, -56), polePaint);
    canvas.drawLine(const Offset(0, -52), Offset(dir * 14, -52), polePaint);

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(dir * 14, -52), width: 10, height: 26),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(boxRect, Paint()..color = const Color(0xFF0F172A));

    final redActive = Paint()..color = const Color(0xFFEF4444);
    final yellowDim = Paint()..color = const Color(0xFF451A03);
    final greenDim = Paint()..color = const Color(0xFF064E3B);

    canvas.drawCircle(Offset(dir * 14, -60), 3.0, redActive);
    canvas.drawCircle(Offset(dir * 14, -52), 3.0, yellowDim);
    canvas.drawCircle(Offset(dir * 14, -44), 3.0, greenDim);
  }

  static void _drawBridge(Canvas canvas, int variant, bool isLeftSide) {
    final double dir = isLeftSide ? 1.0 : -1.0;

    final colRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-12, -64, 24, 64),
      const Radius.circular(3.0),
    );
    canvas.drawRRect(colRect, Paint()..color = const Color(0xFF475569));

    final beamRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-12, -72, dir * 42, 10),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(beamRect, Paint()..color = const Color(0xFF64748B));

    final trussPaint = Paint()..color = const Color(0xFFDC2626)..strokeWidth = 2.4;
    canvas.drawLine(const Offset(-10, -64), Offset(dir * 20, -72), trussPaint);
    canvas.drawLine(Offset(dir * 20, -64), Offset(dir * 20, -72), trussPaint);
  }

  static void _drawStreetLight(
    Canvas canvas,
    int variant,
    bool isLeftSide,
    double time,
    RoadEnvironmentTheme theme,
  ) {
    final polePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double dir = isLeftSide ? 1.0 : -1.0;

    final Path polePath = Path()
      ..moveTo(0, 0)
      ..lineTo(0, -46)
      ..quadraticBezierTo(0, -62, dir * 18, -62);
    canvas.drawPath(polePath, polePaint);

    canvas.drawRect(
      Rect.fromCenter(center: Offset(dir * 18, -62), width: 7.0, height: 4.0),
      Paint()..color = const Color(0xFF334155),
    );

    if (theme.streetLightIntensity > 0.05) {
      final lightColor = theme.streetLightGlowColor;
      final bulbPaint = Paint()
        ..color = lightColor.withValues(alpha: theme.streetLightIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(dir * 18, -60), 6.0, bulbPaint);

      final conePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            lightColor.withValues(alpha: 0.35 * theme.streetLightIntensity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(dir * 4, -8, dir * 28, 20));
      canvas.drawOval(Rect.fromCenter(center: Offset(dir * 18, 0), width: 36, height: 14), conePaint);
    }
  }

  static void _drawRoadSign(Canvas canvas, int variant, bool isLeftSide) {
    final polePaint = Paint()..color = const Color(0xFF64748B)..strokeWidth = 3.0;
    canvas.drawLine(const Offset(0, 0), const Offset(0, -42), polePaint);

    switch (variant % 4) {
      case 0:
        canvas.drawCircle(const Offset(0, -48), 13.0, Paint()..color = const Color(0xFFEF4444));
        canvas.drawCircle(const Offset(0, -48), 10.5, Paint()..color = Colors.white);
        final tp = TextPainter(
          text: const TextSpan(
            text: '120',
            style: TextStyle(color: Colors.black, fontSize: 8.5, fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -48 - tp.height / 2));
        break;

      case 1:
        final signRect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-11, -58, 22, 18),
          const Radius.circular(3.0),
        );
        canvas.drawRRect(signRect, Paint()..color = const Color(0xFFFBBF24));
        final chevronPath = Path()
          ..moveTo(isLeftSide ? -4 : 4, -54)
          ..lineTo(isLeftSide ? 4 : -4, -49)
          ..lineTo(isLeftSide ? -4 : 4, -44);
        canvas.drawPath(
          chevronPath,
          Paint()
            ..color = Colors.black
            ..strokeWidth = 3.2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
        break;

      case 2:
        final shieldPath = Path()
          ..moveTo(-12, -60)
          ..lineTo(12, -60)
          ..lineTo(12, -48)
          ..quadraticBezierTo(0, -38, 0, -36)
          ..quadraticBezierTo(0, -38, -12, -48)
          ..close();
        canvas.drawPath(shieldPath, Paint()..color = const Color(0xFF1D4ED8));
        canvas.drawPath(
          shieldPath,
          Paint()..color = Colors.white..strokeWidth = 1.2..style = PaintingStyle.stroke,
        );
        final tp = TextPainter(
          text: const TextSpan(
            text: '99',
            style: TextStyle(color: Colors.white, fontSize: 8.0, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, -54));
        break;

      case 3:
      default:
        canvas.save();
        canvas.translate(0, -48);
        canvas.rotate(pi / 4);
        canvas.drawRect(
          const Rect.fromLTWH(-9, -9, 18, 18),
          Paint()..color = const Color(0xFFF97316),
        );
        canvas.restore();
        canvas.drawCircle(const Offset(0, -43), 1.5, Paint()..color = Colors.black);
        canvas.drawLine(
          const Offset(0, -52),
          const Offset(0, -46),
          Paint()..color = Colors.black..strokeWidth = 2.4..strokeCap = StrokeCap.round,
        );
        break;
    }
  }

  static void _drawGuardRail(Canvas canvas, int variant, bool isLeftSide, RoadEnvironmentTheme theme) {
    final postPaint = Paint()..color = const Color(0xFF475569)..strokeWidth = 4.0;
    canvas.drawLine(const Offset(-16, 0), const Offset(-16, -20), postPaint);
    canvas.drawLine(const Offset(16, 0), const Offset(16, -20), postPaint);

    final railRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-24, -22, 48, 10),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(railRect, Paint()..color = const Color(0xFF94A3B8));

    canvas.drawLine(
      const Offset(-24, -17),
      const Offset(24, -17),
      Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 2.0,
    );

    final reflector = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(const Offset(-16, -17), 2.0, reflector);
    canvas.drawCircle(const Offset(16, -17), 2.0, reflector);
  }

  static void _drawBillboard(Canvas canvas, int variant, bool isLeftSide, double time, RoadEnvironmentTheme theme) {
    final postPaint = Paint()..color = const Color(0xFF334155)..strokeWidth = 3.5;
    canvas.drawLine(const Offset(-12, 0), const Offset(-12, -42), postPaint);
    canvas.drawLine(const Offset(12, 0), const Offset(12, -42), postPaint);

    canvas.drawLine(
      const Offset(-12, -15),
      const Offset(12, -35),
      Paint()..color = const Color(0xFF475569)..strokeWidth = 1.5,
    );

    final boardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-28, -72, 56, 30),
      const Radius.circular(4.0),
    );
    canvas.drawRRect(boardRect, Paint()..color = const Color(0xFF0F172A));

    final titles = ['TURBO', 'NITRO', 'DRIFT', 'APEX'];
    final gradients = [
      [const Color(0xFFFF0055), const Color(0xFFFF7A00)],
      [const Color(0xFF00F2FE), const Color(0xFF4FACFE)],
      [const Color(0xFFFEE140), const Color(0xFFFA709A)],
      [const Color(0xFF10B981), const Color(0xFF06B6D4)],
    ];
    final selectedGrad = gradients[variant % gradients.length];
    final selectedTitle = titles[variant % titles.length];

    final innerRect = Rect.fromLTWH(-26, -70, 52, 26);
    final boardPaint = Paint()..shader = LinearGradient(colors: selectedGrad).createShader(innerRect);
    canvas.drawRRect(RRect.fromRectAndRadius(innerRect, const Radius.circular(2.5)), boardPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: selectedTitle,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -62));

    if (theme.streetLightIntensity > 0.05) {
      for (final fx in [-20.0, 0.0, 20.0]) {
        canvas.drawCircle(
          Offset(fx, -74),
          2.5,
          Paint()..color = const Color(0xFFFEF08A).withValues(alpha: theme.streetLightIntensity),
        );
      }
    }
  }

  static void _drawFence(Canvas canvas, int variant, bool isLeftSide) {
    final woodPost = Paint()..color = const Color(0xFF78350F)..strokeWidth = 3.5;
    switch (variant % 3) {
      case 0:
        canvas.drawLine(const Offset(-16, 0), const Offset(-16, -22), woodPost);
        canvas.drawLine(const Offset(0, 0), const Offset(0, -22), woodPost);
        canvas.drawLine(const Offset(16, 0), const Offset(16, -22), woodPost);

        final railPaint = Paint()..color = const Color(0xFF92400E)..strokeWidth = 2.4;
        canvas.drawLine(const Offset(-22, -16), const Offset(22, -16), railPaint);
        canvas.drawLine(const Offset(-22, -8), const Offset(22, -8), railPaint);
        break;

      case 1:
        final steelPost = Paint()..color = const Color(0xFF64748B)..strokeWidth = 2.8;
        canvas.drawLine(const Offset(-18, 0), const Offset(-18, -26), steelPost);
        canvas.drawLine(const Offset(18, 0), const Offset(18, -26), steelPost);
        canvas.drawLine(const Offset(-20, -24), const Offset(20, -24), steelPost);

        final meshPaint = Paint()..color = const Color(0xFF94A3B8).withValues(alpha: 0.5)..strokeWidth = 1.0;
        for (int i = -16; i <= 16; i += 6) {
          canvas.drawLine(Offset(i.toDouble(), 0), Offset((i + 6).toDouble(), -24), meshPaint);
          canvas.drawLine(Offset((i + 6).toDouble(), 0), Offset(i.toDouble(), -24), meshPaint);
        }
        break;

      case 2:
      default:
        final picketPaint = Paint()..color = Colors.white;
        for (int i = -18; i <= 18; i += 7) {
          final Path picket = Path()
            ..moveTo(i - 2.5, 0)
            ..lineTo(i - 2.5, -18)
            ..lineTo(i.toDouble(), -22)
            ..lineTo(i + 2.5, -18)
            ..lineTo(i + 2.5, 0)
            ..close();
          canvas.drawPath(picket, picketPaint);
        }
        break;
    }
  }

  static void _drawUtilityPole(Canvas canvas, int variant, bool isLeftSide) {
    final polePaint = Paint()
      ..color = const Color(0xFF52331C)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, 0), const Offset(0, -62), polePaint);

    final armPaint = Paint()..color = const Color(0xFF382312)..strokeWidth = 3.5;
    canvas.drawLine(const Offset(-18, -52), const Offset(18, -52), armPaint);

    final insulator = Paint()..color = const Color(0xFF0284C7);
    canvas.drawCircle(const Offset(-16, -56), 2.2, insulator);
    canvas.drawCircle(const Offset(0, -56), 2.2, insulator);
    canvas.drawCircle(const Offset(16, -56), 2.2, insulator);

    if (variant % 2 == 0) {
      final transRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, -48, 8, 14),
        const Radius.circular(2.0),
      );
      canvas.drawRRect(transRect, Paint()..color = const Color(0xFF475569));
    }
  }

  static void _drawTree(Canvas canvas, int variant, RoadEnvironmentTheme theme) {
    final trunkPaint = Paint()
      ..color = const Color(0xFF5C2C16)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(0, 0), const Offset(0, -42), trunkPaint);

    final leafDark = Paint()..color = const Color(0xFF065F46);
    canvas.drawCircle(const Offset(-12, -44), 16.0, leafDark);
    canvas.drawCircle(const Offset(12, -44), 16.0, leafDark);
    canvas.drawCircle(const Offset(0, -56), 20.0, leafDark);

    final leafLight = Paint()..color = theme.natureFoliageColor;
    canvas.drawCircle(const Offset(-8, -48), 13.0, leafLight);
    canvas.drawCircle(const Offset(8, -48), 13.0, leafLight);
    canvas.drawCircle(const Offset(0, -58), 16.0, leafLight);
  }

  static void _drawBush(Canvas canvas, int variant, RoadEnvironmentTheme theme) {
    final bushPaint1 = Paint()..color = const Color(0xFF065F46);
    final bushPaint2 = Paint()..color = theme.natureFoliageColor;

    canvas.drawCircle(const Offset(-12, -8), 11.0, bushPaint1);
    canvas.drawCircle(const Offset(12, -8), 11.0, bushPaint1);
    canvas.drawCircle(const Offset(0, -14), 14.0, bushPaint1);

    canvas.drawCircle(const Offset(-8, -10), 9.0, bushPaint2);
    canvas.drawCircle(const Offset(8, -10), 9.0, bushPaint2);
    canvas.drawCircle(const Offset(0, -15), 11.0, bushPaint2);
  }

  static void _drawGrass(Canvas canvas, int variant, RoadEnvironmentTheme theme) {
    final bladePaint = Paint()
      ..color = theme.natureFoliageColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(0, 0), const Offset(-12, -18), bladePaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, -26), bladePaint);
    canvas.drawLine(const Offset(0, 0), const Offset(13, -16), bladePaint);
  }

  static void _drawRock(Canvas canvas, int variant) {
    final baseRock = Paint()..color = const Color(0xFF475569);
    final darkFace = Paint()..color = const Color(0xFF334155);
    final lightFace = Paint()..color = const Color(0xFF94A3B8);

    final Path rockPath = Path()
      ..moveTo(-16, 0)
      ..lineTo(-18, -10)
      ..lineTo(-8, -20)
      ..lineTo(8, -18)
      ..lineTo(18, -8)
      ..lineTo(16, 0)
      ..close();
    canvas.drawPath(rockPath, baseRock);

    final Path darkPlane = Path()
      ..moveTo(-16, 0)
      ..lineTo(-18, -10)
      ..lineTo(-8, -20)
      ..lineTo(0, -8)
      ..close();
    canvas.drawPath(darkPlane, darkFace);

    final Path topFacet = Path()
      ..moveTo(-8, -20)
      ..lineTo(8, -18)
      ..lineTo(0, -8)
      ..close();
    canvas.drawPath(topFacet, lightFace);
  }

  static void _drawFlowers(Canvas canvas, int variant) {
    final stemPaint = Paint()
      ..color = const Color(0xFF15803D)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(-8, 0), const Offset(-10, -16), stemPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, -20), stemPaint);
    canvas.drawLine(const Offset(8, 0), const Offset(9, -15), stemPaint);

    final flowerColor = const Color(0xFFEF4444);
    for (final offset in [const Offset(-10, -16), const Offset(0, -20), const Offset(9, -15)]) {
      canvas.drawCircle(offset, 4.5, Paint()..color = flowerColor);
      canvas.drawCircle(offset, 2.0, Paint()..color = const Color(0xFFFDE047));
    }
  }
}
