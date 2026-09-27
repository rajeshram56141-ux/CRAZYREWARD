import 'package:flutter/material.dart';

class GameConfig {
  // Lane Configuration (3 Lanes: 0 = Left, 1 = Center, 2 = Right)
  static const int totalLanes = 3;
  static const double laneLeft = 0.0;
  static const double laneCenter = 1.0;
  static const double laneRight = 2.0;

  // Speed Parameters (Ultra-comfortable, super slow & controllable arcade racing speeds)
  static const double initialSpeed = 120.0; // Very slow, relaxed starting speed (px/s)
  static const double baseStageMaxSpeed = 180.0; // Early stage top speed (<10,000 score)
  static const double milestone10kScore = 10000.0; // 10,000 score milestone trigger
  static const double earlySpeedIncrement = 0.8; // Ultra gentle acceleration early on (px/s)
  static const double turboSpeedIncrement = 1.5; // Smooth gradual acceleration after 10k score
  static const double speedIncreaseRate = 1.5; // Speed increase alias
  static const double speedIncrement = 1.5; // Speed increase alias
  static const double maximumSpeed = 260.0; // Dynamic controlled comfortable top speed ceiling
  static const double laneSwitchSpeed = 16.0; // Responsive lane interpolation factor

  // Player Dimensions & Hitboxes
  static const double playerWidth = 74.0;
  static const double playerHeight = 104.0;
  static const double playerSlideHeight = 54.0;
  static const double jumpDuration = 0.65;
  static const double jumpMaxHeight = 85.0;
  static const double slideDuration = 0.85;

  // Spawning Distances & Timing
  static const double minSpawnDistance = 340.0;
  static const double maxSpawnDistance = 580.0;
  static const double coinPatternSpacing = 72.0;

  // Power-Up Durations (seconds)
  static const double magnetDuration = 8.0;
  static const double shieldDuration = 10.0;
  static const double multiplierDuration = 8.0;

  // Chances / Lives
  static const int defaultLives = 3;

  // Scoring
  static const int coinScore = 10;
  static const int gemScore = 50;
  static const double distanceScoreMultiplier = 0.12;

  // Visual Palette
  static const Color roadColor = Color(0xFF1E2028);
  static const Color roadCurbsColor = Color(0xFFDC2626);
  static const Color roadCurbsWhite = Color(0xFFFFFFFF);
  static const Color laneDividerColor = Color(0xFFFBBF24);
  static const Color skyTopColor = Color(0xFF0F172A);
  static const Color skyBottomColor = Color(0xFF312E81);

  // Storage Keys
  static const String keyBestScore = 'crazy_runner_best_score';
  static const String keyTotalCoins = 'crazy_runner_total_coins';
  static const String keySoundEnabled = 'crazy_runner_sound_enabled';
  static const String keyMusicEnabled = 'crazy_runner_music_enabled';
  static const String keyVibrateEnabled = 'crazy_runner_vibrate_enabled';
  static const String keyTutorialDone = 'crazy_runner_tutorial_done';
  static const String keyTutorialEnabled = 'crazy_runner_tutorial_enabled';
  static const String keyGraphicsQuality = 'crazy_runner_graphics_quality';
  static const String keyShowFps = 'crazy_runner_show_fps';
}
