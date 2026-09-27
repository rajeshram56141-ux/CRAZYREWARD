import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// PREMIUM GAME OVER OVERLAY
/// ============================================================================
/// Displays:
/// - Title: GAME OVER (Arcade Crimson & Orange Neon Gradient)
/// - If new record: NEW HIGH SCORE! (Celebration Banner & Particles)
/// - SCORE (Animated Count-Up)
/// - BEST (All-Time High Score)
/// - COINS (Count-Up + Spinning/Pulsing Coin Animation)
/// - DISTANCE (Formatted in KM / M with Road Icon)
/// - Primary Action Buttons:
///   1. RETRY (Starts fresh race countdown)
///   2. HOME (Returns to Start Menu)
/// - Background: Gameplay visible behind a dark translucent blurred backdrop.
/// ============================================================================

class RunnerGameOverOverlay extends StatefulWidget {
  final int score;
  final int bestScore;
  final int previousBestScore;
  final int coins;
  final double distanceMeters;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const RunnerGameOverOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    this.previousBestScore = 0,
    required this.coins,
    required this.distanceMeters,
    required this.onRetry,
    required this.onHome,
  });

  @override
  State<RunnerGameOverOverlay> createState() => _RunnerGameOverOverlayState();
}

class _RunnerGameOverOverlayState extends State<RunnerGameOverOverlay>
    with TickerProviderStateMixin {
  // Main Entrance & Layout Animations
  late AnimationController _entranceAnimController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Score & Coin Count-Up Interpolation Controller
  late AnimationController _countUpController;
  late Animation<double> _scoreCountUpAnim;
  late Animation<double> _coinCountUpAnim;

  // Celebration Particles & Shimmer Animation
  late AnimationController _particlesController;
  final List<_CelebrationParticle> _particles = [];
  final Random _random = Random();

  bool get isNewHighScore =>
      widget.score > 0 &&
      (widget.score >= widget.bestScore || widget.score > widget.previousBestScore);

  @override
  void initState() {
    super.initState();

    // 1. Entrance Spring & Slide Animation
    _entranceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleAnim = CurvedAnimation(
      parent: _entranceAnimController,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceAnimController,
      curve: Curves.easeIn,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceAnimController,
      curve: Curves.easeOutCubic,
    ));

    // 2. Score & Coin Dynamic Ticker Count-Up Animation (1.2s Duration)
    _countUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scoreCountUpAnim = Tween<double>(
      begin: 0,
      end: widget.score.toDouble(),
    ).animate(CurvedAnimation(
      parent: _countUpController,
      curve: Curves.easeOutCubic,
    ));

    _coinCountUpAnim = Tween<double>(
      begin: 0,
      end: widget.coins.toDouble(),
    ).animate(CurvedAnimation(
      parent: _countUpController,
      curve: Curves.easeOutCubic,
    ));

    // 3. Ambient Celebration Particles & Shimmer Engine
    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _spawnInitialCelebrationParticles();

    // Start Choreography
    _entranceAnimController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _countUpController.forward();
      }
    });
  }

  void _spawnInitialCelebrationParticles() {
    final int count = isNewHighScore ? 50 : 25;
    final List<Color> colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFF00F2FE), // Cyan
      const Color(0xFFFF007A), // Hot Pink
      const Color(0xFF00FF66), // Emerald
      const Color(0xFFFFAA00), // Amber
      Colors.white,
    ];

    for (int i = 0; i < count; i++) {
      _particles.add(_CelebrationParticle(
        x: _random.nextDouble() * 360,
        y: _random.nextDouble() * 700,
        vx: (_random.nextDouble() - 0.5) * 45,
        vy: -30 - _random.nextDouble() * 60,
        color: colors[_random.nextInt(colors.length)],
        size: 4 + _random.nextDouble() * 6,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 4,
        isStar: _random.nextBool(),
      ));
    }
  }

  @override
  void dispose() {
    _entranceAnimController.dispose();
    _countUpController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  String _formatDistance(double meters) {
    if (meters >= 1000.0) {
      final double km = meters / 1000.0;
      return "${km.toStringAsFixed(2)} KM";
    } else {
      return "${meters.toInt()} M";
    }
  }

  @override
  Widget build(BuildContext context) {
    final int displayBestScore = max(widget.bestScore, widget.score);
    final int gemsEarned = (widget.distanceMeters / 200.0).floor();

    return Stack(
      children: [
        // 1. Semi-Transparent Dark Glass Backdrop (Keeping Gameplay Visible)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    const Color(0xFF0F172A).withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 2. Animated Celebration Confetti & Starfield Canvas
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _particlesController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CelebrationParticlesPainter(
                    particles: _particles,
                    animValue: _particlesController.value,
                  ),
                );
              },
            ),
          ),
        ),

        // 3. Main Centerpiece Card with Entrance Animation
        Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  width: 335.w,
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                  padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E293B),
                        Color(0xFF0F172A),
                        Color(0xFF070B14),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(28.r),
                    border: Border.all(
                      color: isNewHighScore
                          ? const Color(0xFFFFD700).withValues(alpha: 0.85)
                          : const Color(0xFFFF3366).withValues(alpha: 0.6),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isNewHighScore
                            ? const Color(0xFFFFD700).withValues(alpha: 0.35)
                            : const Color(0xFFFF0844).withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Subtitle / New High Score Ribbon
                      if (isNewHighScore) ...[
                        _buildNewHighScoreBanner(),
                        SizedBox(height: 8.h),
                      ] else ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 3.5.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0844).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: const Color(0xFFFF0844).withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            "⚡ RACE CONCLUDED ⚡",
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFF6B8B),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                      ],

                      // Main Title: "GAME OVER" with 3D Fire Shader
                      Text(
                        "GAME OVER",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.blackOpsOne(
                          fontSize: 38.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                Color(0xFFFF1744),
                                Color(0xFFFF5252),
                                Color(0xFFFF9100),
                                Color(0xFFFFD600),
                              ],
                              stops: [0.0, 0.35, 0.75, 1.0],
                            ).createShader(const Rect.fromLTWH(0, 0, 300, 60)),
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFF0844).withValues(alpha: 0.85),
                              blurRadius: 22,
                              offset: const Offset(0, 4),
                            ),
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14.h),

                      // 4-Card Metrics Display Grid (SCORE, BEST, COINS, DISTANCE)
                      AnimatedBuilder(
                        animation: _countUpController,
                        builder: (context, child) {
                          final int animatedScore = _scoreCountUpAnim.value.toInt();
                          final int animatedCoins = _coinCountUpAnim.value.toInt();

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Row: SCORE & BEST
                              Row(
                                children: [
                                  // SCORE CARD
                                  Expanded(
                                    child: _buildMetricCard(
                                      label: "SCORE",
                                      value: "$animatedScore",
                                      icon: Icons.speed_rounded,
                                      accentColor: const Color(0xFF00F2FE),
                                      gradientColors: const [Color(0xFF0F2B48), Color(0xFF0F172A)],
                                      isHero: true,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  // BEST CARD
                                  Expanded(
                                    child: _buildMetricCard(
                                      label: "BEST",
                                      value: "$displayBestScore",
                                      icon: Icons.emoji_events_rounded,
                                      accentColor: const Color(0xFFFFD700),
                                      gradientColors: const [Color(0xFF3B2F08), Color(0xFF0F172A)],
                                      badgeText: isNewHighScore ? "NEW!" : null,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 10.h),

                              // Bottom Row: COINS & DISTANCE
                              Row(
                                children: [
                                  // COINS CARD
                                  Expanded(
                                    child: _buildMetricCard(
                                      label: "COINS",
                                      value: "$animatedCoins",
                                      icon: Icons.monetization_on_rounded,
                                      accentColor: const Color(0xFFFFB703),
                                      gradientColors: const [Color(0xFF3A2800), Color(0xFF0F172A)],
                                      isAnimatedCoin: true,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  // DISTANCE CARD
                                  Expanded(
                                    child: _buildMetricCard(
                                      label: "DISTANCE",
                                      value: _formatDistance(widget.distanceMeters),
                                      icon: Icons.route_rounded,
                                      accentColor: const Color(0xFF22C55E),
                                      gradientColors: const [Color(0xFF0A331A), Color(0xFF0F172A)],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      // Optional Gems Reward Milestone Pill
                      if (gemsEarned > 0) ...[
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/icons/gems.png',
                                width: 18.w,
                                height: 18.w,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.diamond_rounded,
                                  color: Colors.white,
                                  size: 16.sp,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                "+$gemsEarned GEMS EARNED FOR RUN",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 18.h),

                      // Action Buttons: RETRY & HOME
                      Row(
                        children: [
                          // RETRY BUTTON (Main Highlight)
                          Expanded(
                            flex: 6,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                widget.onRetry();
                              },
                              child: Container(
                                height: 54.h,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00FF66),
                                      Color(0xFF16A34A),
                                      Color(0xFF059669),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(27.r),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 1.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00FF66).withValues(alpha: 0.5),
                                      blurRadius: 18,
                                      offset: const Offset(0, 5),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.replay_rounded,
                                      color: Colors.white,
                                      size: 26.sp,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      "RETRY",
                                      style: GoogleFonts.blackOpsOne(
                                        color: Colors.white,
                                        fontSize: 20.sp,
                                        letterSpacing: 1.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 10.w),

                          // HOME BUTTON
                          Expanded(
                            flex: 4,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onHome();
                              },
                              child: Container(
                                height: 54.h,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1E293B),
                                      Color(0xFF0F172A),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(27.r),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.home_rounded,
                                      color: const Color(0xFF38BDF8),
                                      size: 22.sp,
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      "HOME",
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewHighScoreBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFF9100),
            Color(0xFFFF3D00),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.6),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.white, size: 16.sp),
          SizedBox(width: 4.w),
          Text(
            "NEW HIGH SCORE!",
            style: GoogleFonts.blackOpsOne(
              color: Colors.white,
              fontSize: 13.sp,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          SizedBox(width: 4.w),
          Icon(Icons.star_rounded, color: Colors.white, size: 16.sp),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradientColors,
    String? badgeText,
    bool isHero = false,
    bool isAnimatedCoin = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradientColors[0].withValues(alpha: 0.85),
            gradientColors[1].withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            children: [
              // Icon Box with Pulse Glow
              Container(
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor,
                    width: 1.2,
                  ),
                ),
                child: isAnimatedCoin
                    ? Transform.rotate(
                        angle: _particlesController.value * 2 * pi,
                        child: Icon(icon, color: accentColor, size: 16.sp),
                      )
                    : Icon(icon, color: accentColor, size: 16.sp),
              ),

              SizedBox(width: 8.w),

              // Metric Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.blackOpsOne(
                        color: isHero ? const Color(0xFF00F2FE) : Colors.white,
                        fontSize: isHero ? 17.sp : 15.sp,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: accentColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Optional Mini Badge (e.g. "NEW!")
          if (badgeText != null)
            Positioned(
              top: -6.h,
              right: -4.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.white, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// CELEBRATION PARTICLES SIMULATOR
/// ============================================================================
class _CelebrationParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;
  bool isStar;

  _CelebrationParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.isStar,
  });
}

class _CelebrationParticlesPainter extends CustomPainter {
  final List<_CelebrationParticle> particles;
  final double animValue;

  _CelebrationParticlesPainter({
    required this.particles,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double dt = 0.016;

    for (final p in particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 28.0 * dt; // Light floating gravity
      p.rotation += p.rotationSpeed * dt;

      // Wrap around bounds
      if (p.y > size.height + 20) {
        p.y = -20;
        p.x = Random().nextDouble() * size.width;
        p.vy = 20 + Random().nextDouble() * 40;
      }
      if (p.x < -20) p.x = size.width + 20;
      if (p.x > size.width + 20) p.x = -20;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      if (p.isStar) {
        _drawStar(canvas, p.size, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size * 1.5, height: p.size * 0.75),
            const Radius.circular(2),
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double size, Paint paint) {
    final path = Path();
    final int points = 5;
    final double innerRadius = size * 0.45;
    final double outerRadius = size;
    final double angle = pi / points;

    for (int i = 0; i < 2 * points; i++) {
      final double r = i.isEven ? outerRadius : innerRadius;
      final double currAngle = i * angle - pi / 2;
      final double x = cos(currAngle) * r;
      final double y = sin(currAngle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CelebrationParticlesPainter oldDelegate) => true;
}
