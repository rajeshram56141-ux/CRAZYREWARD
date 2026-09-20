import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../utils/routes/routes_import.gr.dart';

@RoutePage()
class BattleArenaSplashScreen extends StatefulWidget {
  const BattleArenaSplashScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  final String userId;
  final String email;

  @override
  State<BattleArenaSplashScreen> createState() =>
      _BattleArenaSplashScreenState();
}

class _BattleArenaSplashScreenState extends State<BattleArenaSplashScreen>
    with TickerProviderStateMixin {
  double _progress = 0.0;
  Timer? _progressTimer;
  Timer? _navTimer;

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Floating animation for the battle card
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // Pulsing concentric rings animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Progress Bar Stepper
    const totalSteps = 40;
    const stepDuration = Duration(milliseconds: 55);
    _progressTimer = Timer.periodic(stepDuration, (timer) {
      if (!mounted) return;
      setState(() {
        _progress += (1.0 / totalSteps);
        if (_progress >= 1.0) _progress = 1.0;
      });
    });

    // Auto Navigation
    _navTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      AutoRouter.of(context).replace(
        BattleArenaScreenRoute(
          userId: widget.userId,
          email: widget.email,
        ),
      );
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _navTimer?.cancel();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Full App Wallpaper Background
            Positioned.fill(
              child: Image.asset(
                'assets/icons/Splash (2).png',
                fit: BoxFit.cover,
              ),
            ),

            // 2. Main Center Content
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 4),

                    // Floating App Logo / Battle Icon with Concentric Purple Pulse Rings (Fixed size to prevent layout shifting)
                    SizedBox(
                      width: 155.w,
                      height: 155.w,
                      child: AnimatedBuilder(
                        animation: _floatAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatAnimation.value),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulse Ring 1
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final val = _pulseController.value;
                                    return Container(
                                      width: 100.w + (val * 48.w),
                                      height: 100.w + (val * 48.w),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFAB31DE).withValues(alpha: (1.0 - val) * 0.4),
                                          width: 1.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Pulse Ring 2
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final val = (_pulseController.value + 0.5) % 1.0;
                                    return Container(
                                      width: 100.w + (val * 48.w),
                                      height: 100.w + (val * 48.w),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFAB31DE).withValues(alpha: (1.0 - val) * 0.2),
                                          width: 1.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Battle Icon Container with violet glow
                                Container(
                                  width: 100.w,
                                  height: 100.w,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF201B30),
                                        Color(0xFF291E42),
                                        Color(0xFF382060),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  padding: EdgeInsets.all(16.r),
                                  child: child,
                                ),
                              ],
                            ),
                          );
                        },
                        child: Image.asset(
                          'assets/icons/battle.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/icons/battle game.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.sports_esports_rounded,
                              color: const Color(0xFFAB31DE),
                              size: 48.sp,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // App Title (Battle Panda)
                    Text(
                      'Battle Panda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Neogen',
                        color: const Color(0xFFAB31DE),
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),

                    SizedBox(height: 6.h),

                    // App Subtitle Tagline
                    Text(
                      '1V1 REAL-TIME QUIZ CLASH',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFA78BFA),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Futuristic Cyber Progress Capsule Loader (Main App Matching Style)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Outer Capsule Track with Neon Glow
                        Container(
                          width: 180.w,
                          height: 8.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF140D2B),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.4),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: Stack(
                              children: [
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _progress.clamp(0.02, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFAB31DE),
                                          Color(0xFFA78BFA),
                                          Colors.white,
                                          Color(0xFFA78BFA),
                                          Color(0xFFAB31DE),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // Loading text with progress percentage
                        Text(
                          'LOADING... ${(_progress * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFA78BFA).withValues(alpha: 0.8),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
