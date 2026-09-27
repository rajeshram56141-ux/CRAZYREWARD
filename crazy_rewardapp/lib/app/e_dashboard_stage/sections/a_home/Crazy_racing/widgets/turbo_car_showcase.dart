import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../runner/player_car.dart';

/// Ultra-Modern 3D Vector Cyber Supercar Showcase & Badge Components
/// Powered by the authentic in-game [PlayerCarVisual] 3D arcade sports car.
/// High-octane arcade racing visual design with live animations at 60 FPS.

class TurboSupercarShowcase extends StatefulWidget {
  const TurboSupercarShowcase({
    super.key,
    this.width,
    this.height,
    this.showPedestal = true,
    this.showSpecs = true,
    this.theme,
    this.badgeText,
  });

  final double? width;
  final double? height;
  final bool showPedestal;
  final bool showSpecs;
  final PlayerCarTheme? theme;
  final String? badgeText;

  @override
  State<TurboSupercarShowcase> createState() => _TurboSupercarShowcaseState();
}

class _TurboSupercarShowcaseState extends State<TurboSupercarShowcase>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double targetWidth = widget.width ?? 260.w;
    final double targetHeight = widget.height ?? 160.h;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final double animValue = _animController.value;
        final double floatOffset = sin(animValue * 2 * pi) * 4.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3D Car & Pedestal Stage
            SizedBox(
              width: targetWidth,
              height: targetHeight,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Glowing Cyber Orbital Rings & Ground Pedestal
                  if (widget.showPedestal)
                    Positioned(
                      bottom: 8.h,
                      child: CustomPaint(
                        size: Size(targetWidth * 0.9, 46.h),
                        painter: _PedestalPainter(
                          animValue: animValue,
                          glowColor: widget.theme?.neonGlowColor,
                        ),
                      ),
                    ),

                  // 2. Exact In-Game 3D Supercar Vector Canvas with Floating Engine Vibration
                  Transform.translate(
                    offset: Offset(0, floatOffset),
                    child: CustomPaint(
                      size: Size(targetWidth * 0.85, targetHeight * 0.82),
                      painter: _SupercarVectorPainter(
                        animValue: animValue,
                        theme: widget.theme,
                      ),
                    ),
                  ),

                  // 3. Floating Nitro Boost Badge
                  Positioned(
                    top: 0,
                    right: 12.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.theme?.neonGlowColor ?? const Color(0xFF00F2FE),
                            widget.theme?.primaryColor ?? const Color(0xFF4FACFE),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.theme?.neonGlowColor ?? const Color(0xFF00F2FE)).withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: Colors.white, size: 12.sp),
                          SizedBox(width: 2.w),
                          Text(
                            widget.badgeText ?? (widget.theme?.name != null ? "${widget.theme!.name.toUpperCase()} GT" : "NITRO GT"),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (widget.showSpecs) ...[
              SizedBox(height: 8.h),
              // Dynamic Specs Strip
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSpecTag(Icons.speed_rounded, "TOP SPEED", "340 KM/H", const Color(0xFFFF4D4D)),
                  SizedBox(width: 10.w),
                  _buildSpecTag(Icons.local_fire_department_rounded, "NITRO BOOST", "+100%", const Color(0xFF38BDF8)),
                  SizedBox(width: 10.w),
                  _buildSpecTag(Icons.diamond_rounded, "REWARD RATE", "1 GEM / 200M", const Color(0xFFFFD700)),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSpecTag(IconData icon, String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 11.sp),
          SizedBox(width: 4.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF94A3B8),
                  fontSize: 7.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact 3D Cyber Arcade Gaming Car Badge for Popups, Dialogs, and Trophy Badges
/// Renders the exact in-game supercar with live engine vibration, glowing lights and custom themes.
class TurboCarBadge extends StatefulWidget {
  const TurboCarBadge({
    super.key,
    this.size = 80.0,
    this.theme,
    this.isCrashed = false,
  });

  final double size;
  final PlayerCarTheme? theme;
  final bool isCrashed;

  @override
  State<TurboCarBadge> createState() => _TurboCarBadgeState();
}

class _TurboCarBadgeState extends State<TurboCarBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double w = widget.size * 1.55;
    final double h = widget.size * 1.15;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double anim = _controller.value;
        final double floatOffset = sin(anim * 2 * pi) * (widget.isCrashed ? 1.0 : 3.0);

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Under-car ground shadow
              Positioned(
                bottom: 4,
                child: Container(
                  width: w * 0.75,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(w * 0.75, 12)),
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        (widget.theme?.neonGlowColor ?? const Color(0xFFFF0055)).withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Exact 3D Arcade In-Game Vector Car with Engine Floating Bob
              Transform.translate(
                offset: Offset(0, floatOffset),
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _SupercarVectorPainter(
                    animValue: anim,
                    compactMode: true,
                    theme: widget.theme,
                    isCrashed: widget.isCrashed,
                  ),
                ),
              ),

              // If Crashed, show subtle cartoon collision sparks / smoke puff
              if (widget.isCrashed)
                Positioned(
                  top: 2,
                  right: 14,
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.85),
                    size: 20.sp,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// PAINTER: DELEGATES TO AUTHENTIC IN-GAME [PlayerCarVisual] (60 FPS)
// =============================================================================
class _SupercarVectorPainter extends CustomPainter {
  _SupercarVectorPainter({
    required this.animValue,
    this.compactMode = false,
    this.theme,
    this.isCrashed = false,
  });

  final double animValue;
  final bool compactMode;
  final PlayerCarTheme? theme;
  final bool isCrashed;

  @override
  void paint(Canvas canvas, Size size) {
    final activeTheme = theme ?? PlayerCarTheme.red;
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Subtle idle engine suspension bounce & slight dynamic tilt
    final double bounce = isCrashed ? 0.0 : (sin(animValue * 2 * pi) * 1.8);
    final double tilt = isCrashed ? -0.08 : (sin(animValue * 2 * pi) * 0.03);

    final params = CarRenderParams(
      state: isCrashed ? CarAnimationState.collision : CarAnimationState.driving,
      speed: isCrashed ? 0.0 : 160.0,
      laneTilt: tilt,
      steerAngle: 0.0,
      suspensionBounce: bounce,
      wheelRotation: animValue * 2 * pi,
      theme: activeTheme,
      isNitroActive: !isCrashed,
      nitroIntensity: isCrashed ? 0.0 : 0.85,
    );

    canvas.save();
    canvas.translate(cx, cy);

    // Target in-game car base size is 60x90. Scale smoothly to fit widget container.
    final double scale = min(size.width / 84.0, size.height / 115.0) * (compactMode ? 1.05 : 1.22);
    canvas.scale(scale, scale);
    canvas.translate(-30.0, -45.0);

    // Render the identical gaming car as seen in the active gameplay runner
    PlayerCarVisual.drawCar(
      canvas,
      const Size(60, 90),
      params,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SupercarVectorPainter oldDelegate) {
    return oldDelegate.animValue != animValue ||
        oldDelegate.theme != theme ||
        oldDelegate.isCrashed != isCrashed ||
        oldDelegate.compactMode != compactMode;
  }
}

// =============================================================================
// PAINTER: CYBER GROUND PEDESTAL & REVOLVING SPEED RINGS
// =============================================================================
class _PedestalPainter extends CustomPainter {
  _PedestalPainter({
    required this.animValue,
    this.glowColor,
  });

  final double animValue;
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final Color primaryGlow = glowColor ?? const Color(0xFF00F2FE);

    // Glowing Neon Platform Oval
    final baseRect = Rect.fromCenter(center: Offset(cx, cy), width: size.width, height: size.height);

    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryGlow.withValues(alpha: 0.85),
          primaryGlow.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(baseRect);

    canvas.drawOval(baseRect, basePaint);

    // Animated Rotating Hologram Speed Rings
    final ringPaint = Paint()
      ..color = primaryGlow.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final double startAngle = animValue * 2 * pi;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.88, height: size.height * 0.7),
      startAngle,
      pi * 1.2,
      false,
      ringPaint,
    );

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: size.width * 0.65, height: size.height * 0.5),
      -startAngle,
      pi * 1.4,
      false,
      ringPaint..color = const Color(0xFFFFD700).withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _PedestalPainter oldDelegate) {
    return oldDelegate.animValue != animValue || oldDelegate.glowColor != glowColor;
  }
}
