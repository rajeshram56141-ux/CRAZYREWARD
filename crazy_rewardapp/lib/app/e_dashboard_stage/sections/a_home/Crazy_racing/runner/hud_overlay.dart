import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'nitro_system.dart';
import 'player.dart';
import 'score_manager.dart';
import 'near_miss_system.dart';
import 'storage_service.dart';

/// ============================================================================
/// MODERN PORTRAIT RACING GAMEPLAY HUD
/// ============================================================================
/// Layout:
/// - TOP LEFT: Score (Animated Rolling Counter + High Score Celebration)
/// - TOP CENTER: Distance (Meters / Kilometers Pill)
/// - TOP RIGHT: Pause Button (Large Touch Target + Glassmorphic Circle)
/// - SECOND ROW LEFT: Coins (Animated Coin Pickup Bounce)
/// - SECOND ROW RIGHT: Speed (Dynamic Tachometer / KM/H Speedometer)
/// - MID-CHIPS: Active Power-Ups Drain Gauge Chips (Shield, Magnet, 2X, etc.)
/// - BOTTOM: Nitro Meter & Tactical Boost Button + Action Controls
/// ============================================================================

class RunnerHudOverlay extends StatefulWidget {
  final int score;
  final int targetScore;
  final int coins;
  final int earnedGems;
  final double distanceMeters;
  final double currentSpeed;
  final Player player;
  final NitroController? nitroController;
  final ScoreManager? scoreManager;
  final NearMissController? nearMissController;
  final VoidCallback onPause;

  const RunnerHudOverlay({
    super.key,
    required this.score,
    required this.targetScore,
    required this.coins,
    required this.earnedGems,
    required this.distanceMeters,
    this.currentSpeed = 420.0,
    required this.player,
    this.nitroController,
    this.scoreManager,
    this.nearMissController,
    required this.onPause,
  });

  @override
  State<RunnerHudOverlay> createState() => _RunnerHudOverlayState();
}

class _RunnerHudOverlayState extends State<RunnerHudOverlay> with TickerProviderStateMixin {
  // Coin Pickup Micro-Animation Controller
  late AnimationController _coinBounceController;
  late Animation<double> _coinScaleAnim;
  int _lastCoins = 0;

  // High Score Halo Pulse Controller
  late AnimationController _highScorePulseController;

  @override
  void initState() {
    super.initState();
    _lastCoins = widget.coins;

    _coinBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _coinScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOutBack)), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 55),
    ]).animate(_coinBounceController);

    _highScorePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant RunnerHudOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coins > _lastCoins) {
      _lastCoins = widget.coins;
      _coinBounceController.forward(from: 0.0);
    } else {
      _lastCoins = widget.coins;
    }
  }

  @override
  void dispose() {
    _coinBounceController.dispose();
    _highScorePulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dist = widget.scoreManager != null ? widget.scoreManager!.distance : widget.distanceMeters;
    final double speed = widget.currentSpeed;
    final bool isBoosting = widget.nitroController?.isBurning ?? false;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        child: Column(
          children: [
            // ================================================================
            // ROW 1: TOP LEFT (Score) | TOP CENTER (Distance) | TOP RIGHT (Pause)
            // ================================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP LEFT: Animated Score Counter
                _buildTopLeftScore(),

                // TOP CENTER: Distance Pill
                _buildTopCenterDistance(dist),

                // TOP RIGHT: Modern Large-Target Pause Button
                _buildTopRightPauseBtn(),
              ],
            ),

            SizedBox(height: 8.h),

            // ================================================================
            // ROW 2: SECOND ROW LEFT (Coins) | SECOND ROW RIGHT (Speedometer)
            // ================================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // SECOND ROW LEFT: Coins Module
                _buildSecondRowCoins(),

                // SECOND ROW RIGHT: Speedometer Module
                _buildSecondRowSpeedometer(speed, isBoosting),
              ],
            ),

            SizedBox(height: 6.h),

            // ================================================================
            // ROW 3: Active Power-Ups Timers & Gauges (Center floating, minimal)
            // ================================================================
            _buildActivePowerUpsBar(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP LEFT: SCORE MODULE (With High-Score Flash & Multiplier Tag)
  // --------------------------------------------------------------------------
  Widget _buildTopLeftScore() {
    final sm = widget.scoreManager;
    final int displayScore = sm != null ? sm.displayScore : widget.score;
    final bool isNewBest = sm?.isNewHighScore ?? false;
    final bool has2x = widget.player.isMultiplierActive;

    return AnimatedBuilder(
      animation: _highScorePulseController,
      builder: (context, _) {
        final double pulse = isNewBest ? _highScorePulseController.value : 0.0;
        final Color borderColor = isNewBest
            ? Color.lerp(const Color(0xFFFFD700), const Color(0xFF00FF66), pulse)!
            : const Color(0xFFFFD700).withValues(alpha: 0.9);

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: borderColor,
              width: isNewBest ? 2.0 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: isNewBest ? 0.55 : 0.25),
                blurRadius: isNewBest ? 14 : 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy / Crown Icon
              Icon(
                isNewBest ? Icons.workspace_premium_rounded : Icons.emoji_events_rounded,
                color: borderColor,
                size: 17.sp,
              ),
              SizedBox(width: 6.w),

              // Formatted Rolling Score
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNewBest)
                    Text(
                      'BEST SCORE!',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00FF66),
                        fontSize: 7.5.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatNumber(displayScore),
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (widget.targetScore > 0) ...[
                        Text(
                          ' / ${_formatNumber(widget.targetScore)}',
                          style: GoogleFonts.fredoka(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.85),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Active 2X Multiplier Badge
              if (has2x) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(6.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '2X',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // TOP CENTER: DISTANCE MODULE
  // --------------------------------------------------------------------------
  Widget _buildTopCenterDistance(double distMeters) {
    final String distText = (distMeters >= 1000)
        ? '${(distMeters / 1000).toStringAsFixed(1)} KM'
        : '${distMeters.toInt()} M';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.85),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.near_me_rounded,
            color: const Color(0xFF38BDF8),
            size: 15.sp,
          ),
          SizedBox(width: 5.w),
          Text(
            distText,
            style: GoogleFonts.fredoka(
              color: const Color(0xFF38BDF8),
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP RIGHT: PAUSE BUTTON (Large Accessible Hit Area)
  // --------------------------------------------------------------------------
  Widget _buildTopRightPauseBtn() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onPause();
      },
      child: Container(
        width: 44.w,
        height: 44.w,
        alignment: Alignment.center,
        child: Container(
          width: 38.w,
          height: 38.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.pause_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SECOND ROW LEFT: COINS (With Bounce Micro-Animation)
  // --------------------------------------------------------------------------
  Widget _buildSecondRowCoins() {
    return ScaleTransition(
      scale: _coinScaleAnim,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.75),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.25),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gold Coin Icon with Glow
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                ),
              ),
              child: Icon(
                Icons.monetization_on_rounded,
                color: Colors.white,
                size: 14.sp,
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              '${widget.coins}',
              style: GoogleFonts.fredoka(
                color: const Color(0xFFFFD700),
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SECOND ROW RIGHT: SPEEDOMETER MODULE (KM/H + Color Shifting)
  // --------------------------------------------------------------------------
  Widget _buildSecondRowSpeedometer(double worldSpeed, bool isBoosting) {
    // Convert world velocity (120 - 260 px/s) to realistic racing speedometer (75 - 190 KM/H)
    final int kmh = ((worldSpeed / 120.0) * 75.0 * (isBoosting ? 1.28 : 1.0)).clamp(40.0, 300.0).toInt();
    final bool showFps = RunnerStorageService.isShowFpsEnabled();

    final Color speedColor = isBoosting
        ? const Color(0xFFFF3D00)
        : (kmh >= 220)
            ? const Color(0xFFFFD700)
            : const Color(0xFF38BDF8);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFps) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                width: 1.0,
              ),
            ),
            child: Text(
              '60 FPS',
              style: GoogleFonts.blackOpsOne(
                color: const Color(0xFF22C55E),
                fontSize: 10.sp,
              ),
            ),
          ),
          SizedBox(width: 6.w),
        ],
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: speedColor.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: speedColor.withValues(alpha: isBoosting ? 0.5 : 0.25),
                blurRadius: isBoosting ? 10 : 6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBoosting ? Icons.local_fire_department_rounded : Icons.speed_rounded,
                color: speedColor,
                size: 14.sp,
              ),
              SizedBox(width: 5.w),
              Text(
                '$kmh KM/H',
                style: GoogleFonts.fredoka(
                  color: speedColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // ACTIVE POWER-UP CHIPS BAR (Shield, Magnet, 2X, Nitro, Slow-Mo, Overdrive)
  // --------------------------------------------------------------------------
  Widget _buildActivePowerUpsBar() {
    final player = widget.player;
    final bool hasPowerUp = player.hasShield ||
        player.isMagnetActive ||
        player.isMultiplierActive ||
        player.isSpeedBoostActive ||
        player.isSlowMoActive ||
        player.isInvincible;

    if (!hasPowerUp) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6.w,
      runSpacing: 4.h,
      children: [
        if (player.hasShield)
          _buildPowerUpChip(
            title: 'SAFETY WALL ${player.shieldTimer.toStringAsFixed(1)}s',
            color: const Color(0xFF38BDF8),
            icon: Icons.shield_rounded,
            progress: (player.shieldTimer / player.maxShieldDuration).clamp(0.0, 1.0),
            isExpiring: player.shieldTimer < 2.5,
          ),
        if (player.isMagnetActive)
          _buildPowerUpChip(
            title: 'MAGNET ${player.magnetTimer.toStringAsFixed(1)}s',
            color: const Color(0xFFEF4444),
            icon: Icons.all_inclusive_rounded,
            progress: (player.magnetTimer / player.maxMagnetDuration).clamp(0.0, 1.0),
            isExpiring: player.magnetTimer < 2.0,
          ),
        if (player.isMultiplierActive)
          _buildPowerUpChip(
            title: '2X COIN ${player.multiplierTimer.toStringAsFixed(1)}s',
            color: const Color(0xFFA855F7),
            icon: Icons.bolt_rounded,
            progress: (player.multiplierTimer / player.maxMultiplierDuration).clamp(0.0, 1.0),
            isExpiring: player.multiplierTimer < 2.0,
          ),
        if (player.isSpeedBoostActive)
          _buildPowerUpChip(
            title: 'NITRO ${player.speedBoostTimer.toStringAsFixed(1)}s',
            color: const Color(0xFFF97316),
            icon: Icons.speed_rounded,
            progress: (player.speedBoostTimer / player.maxSpeedBoostDuration).clamp(0.0, 1.0),
            isExpiring: player.speedBoostTimer < 2.0,
          ),
        if (player.isSlowMoActive)
          _buildPowerUpChip(
            title: 'SLOW-MO ${player.slowMoTimer.toStringAsFixed(1)}s',
            color: const Color(0xFF06B6D4),
            icon: Icons.hourglass_bottom_rounded,
            progress: (player.slowMoTimer / player.maxSlowMoDuration).clamp(0.0, 1.0),
            isExpiring: player.slowMoTimer < 2.0,
          ),
        if (player.isInvincible)
          _buildPowerUpChip(
            title: 'OVERDRIVE ${player.invincibleTimer.toStringAsFixed(1)}s',
            color: const Color(0xFFFFD700),
            icon: Icons.star_rounded,
            progress: (player.invincibleTimer / player.maxInvincibleDuration).clamp(0.0, 1.0),
            isExpiring: player.invincibleTimer < 2.0,
          ),
      ],
    );
  }

  Widget _buildPowerUpChip({
    required String title,
    required Color color,
    required IconData icon,
    required double progress,
    bool isExpiring = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: isExpiring
            ? color.withValues(alpha: 0.38)
            : const Color(0xFF0F172A).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isExpiring ? Colors.white : color,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isExpiring ? 0.6 : 0.25),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 11.sp),
          SizedBox(width: 4.w),
          Text(
            title,
            style: GoogleFonts.fredoka(
              color: Colors.white,
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 10000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else if (number >= 1000) {
      final int thousands = number ~/ 1000;
      final int remainder = number % 1000;
      return '$thousands,${remainder.toString().padLeft(3, '0')}';
    }
    return '$number';
  }
}
