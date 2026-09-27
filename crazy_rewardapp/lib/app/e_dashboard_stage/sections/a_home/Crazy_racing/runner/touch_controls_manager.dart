import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'haptic_service.dart';
import 'nitro_system.dart';
import 'player.dart';
import 'storage_service.dart';

enum ControlMode {
  hybrid, // Both Swipes + On-Screen Buttons
  swipeOnly, // Fullscreen Swipes Only
  buttonsOnly, // On-screen Buttons Only
}

enum SwipeSensitivity {
  high, // 14px threshold
  normal, // 22px threshold
  low, // 34px threshold
}

/// ============================================================================
/// CRAZY RACING RESPONSIVE TOUCH & SWIPE CONTROLS MANAGER
/// ============================================================================
/// Features:
/// - Swipe Left: Move car to left lane
/// - Swipe Right: Move car to right lane
/// - Swipe Up: Jump / Obstacle Dodge
/// - Swipe Down: Slide / Duck under barriers
/// - Fast response with instant lane target engagement
/// - Anti-double-swipe debounce protection
/// - Micro-jitter & tiny movement deadzone filter
/// - Safe area & multi-screen size compatibility
/// - Configurable modes: Hybrid, Swipe Only, Buttons Only
/// - Configurable sensitivity: High, Normal, Low
/// ============================================================================
class TouchControlsManager {
  static final TouchControlsManager _instance = TouchControlsManager._internal();
  factory TouchControlsManager() => _instance;
  TouchControlsManager._internal();

  ControlMode controlMode = ControlMode.hybrid;
  SwipeSensitivity sensitivity = SwipeSensitivity.normal;

  Offset? _dragStartOffset;
  int _lastSwipeTimestamp = 0;
  bool _strokeConsumed = false;

  // Configuration Thresholds
  double get _swipeThreshold {
    switch (sensitivity) {
      case SwipeSensitivity.high:
        return 14.0;
      case SwipeSensitivity.normal:
        return 22.0;
      case SwipeSensitivity.low:
        return 34.0;
    }
  }

  static const double _deadzoneThreshold = 8.0;
  static const int _debounceCooldownMs = 110;

  void init() {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final modeStr = RunnerStorageService.getControlMode();
    controlMode = switch (modeStr) {
      'swipeOnly' => ControlMode.swipeOnly,
      'buttonsOnly' => ControlMode.buttonsOnly,
      _ => ControlMode.hybrid,
    };

    final sensStr = RunnerStorageService.getSwipeSensitivity();
    sensitivity = switch (sensStr) {
      'High' => SwipeSensitivity.high,
      'Low' => SwipeSensitivity.low,
      _ => SwipeSensitivity.normal,
    };
  }

  void setControlMode(ControlMode mode) {
    controlMode = mode;
    final val = switch (mode) {
      ControlMode.swipeOnly => 'swipeOnly',
      ControlMode.buttonsOnly => 'buttonsOnly',
      ControlMode.hybrid => 'hybrid',
    };
    RunnerStorageService.setControlMode(val);
  }

  void setSensitivity(SwipeSensitivity sens) {
    sensitivity = sens;
    final val = switch (sens) {
      SwipeSensitivity.high => 'High',
      SwipeSensitivity.low => 'Low',
      SwipeSensitivity.normal => 'Normal',
    };
    RunnerStorageService.setSwipeSensitivity(val);
  }

  // ----------------------------------------------------
  // Gesture Input Handlers
  // ----------------------------------------------------
  void onPanStart(DragStartDetails details) {
    if (controlMode == ControlMode.buttonsOnly) return;
    _dragStartOffset = details.localPosition;
    _strokeConsumed = false;
  }

  void onPanUpdate({
    required DragUpdateDetails details,
    required Player player,
    required VoidCallback onMoveLeft,
    required VoidCallback onMoveRight,
    required VoidCallback onJump,
    required VoidCallback onSlide,
  }) {
    if (controlMode == ControlMode.buttonsOnly) return;
    if (_dragStartOffset == null || _strokeConsumed) return;

    final double dx = details.localPosition.dx - _dragStartOffset!.dx;
    final double dy = details.localPosition.dy - _dragStartOffset!.dy;

    // 1. Ignore tiny accidental tremors / micro-movements
    if (dx.abs() < _deadzoneThreshold && dy.abs() < _deadzoneThreshold) {
      return;
    }

    final double threshold = _swipeThreshold;

    // 2. Check if horizontal swipe exceeds sensitivity threshold
    if (dx.abs() >= threshold) {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 3. Debounce: Prevent accidental repeated swipes in rapid succession
      if (now - _lastSwipeTimestamp < _debounceCooldownMs) {
        return;
      }
      _lastSwipeTimestamp = now;
      _strokeConsumed = true; // Mark stroke as handled

      // 4. Horizontal Lane Steering (Left / Right)
      if (dx > 0) {
        onMoveRight();
      } else {
        onMoveLeft();
      }
    }
  }

  void onPanEnd(DragEndDetails details) {
    _dragStartOffset = null;
    _strokeConsumed = false;
  }

  void onPanCancel() {
    _dragStartOffset = null;
    _strokeConsumed = false;
  }
}

/// ============================================================================
/// ON-SCREEN TOUCH CONTROLS OVERLAY (ERGONOMIC SAFE-AREA CONTROLS)
/// ============================================================================
class OnScreenControlsWidget extends StatelessWidget {
  final Player player;
  final NitroController nitroController;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onJump;
  final VoidCallback onSlide;
  final bool showActionButtons;

  const OnScreenControlsWidget({
    super.key,
    required this.player,
    required this.nitroController,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onJump,
    required this.onSlide,
    this.showActionButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    final mode = TouchControlsManager().controlMode;
    if (mode == ControlMode.swipeOnly) {
      // In Swipe Only mode, render only the Nitro trigger at the bottom
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NitroMeterWidget(
                controller: nitroController,
                width: double.infinity,
                height: 20.h,
              ),
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.bottomCenter,
                child: NitroButtonWidget(controller: nitroController),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sleek Nitro Fuel Gauge Meter
            NitroMeterWidget(
              controller: nitroController,
              width: double.infinity,
              height: 20.h,
            ),
            SizedBox(height: 8.h),

            // Tactical Control Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Steer Left & Right
                Row(
                  children: [
                    _buildSteerButton(
                      icon: Icons.arrow_back_rounded,
                      label: "LEFT",
                      onTap: onMoveLeft,
                    ),
                    SizedBox(width: 8.w),
                    _buildSteerButton(
                      icon: Icons.arrow_forward_rounded,
                      label: "RIGHT",
                      onTap: onMoveRight,
                    ),
                  ],
                ),

                // Nitro Boost Button
                NitroButtonWidget(
                  controller: nitroController,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSteerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        CrazyHapticManager().laneShift();
        onTap();
      },
      child: Container(
        width: 54.w,
        height: 54.w,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF38BDF8), size: 24.sp),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 8.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
