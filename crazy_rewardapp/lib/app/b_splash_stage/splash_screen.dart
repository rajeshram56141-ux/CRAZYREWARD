// ignore_for_file: depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../services/local_storage.dart';
import '../../services/security_service.dart';
import '../../utils/routes/routes_import.gr.dart';
import '../../widgets/screens/account_blocked_screen.dart';
import '../../widgets/screens/account_deleted_screen.dart';
import '../../widgets/screens/no_internet_screen.dart';
import '../../widgets/screens/unsecure_device_screen.dart';
import 'splash_service.dart';

@RoutePage()
class SplashScreen extends HookConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityStatus = useState<SecurityStatus?>(null);

    useEffect(() {
      SecurityService.checkSecurity().then((status) {
        securityStatus.value = status;
      });
      return null;
    }, []);

    // 1. If security check is in progress, show loading splash screen
    if (securityStatus.value == null) {
      return const SplashView();
    }

    // 2. If device is unsecure (rooted, emulator, or developer mode), block execution
    if (!securityStatus.value!.isSecure) {
      return UnsecureDeviceScreen(status: securityStatus.value!);
    }

    // 3. Device is secure, proceed with normal initialization flow
    final appDataAsync = ref.watch(SplashService.appDataProvider);

    // If remote configuration data is loading or failed
    if (appDataAsync.isLoading && !appDataAsync.hasValue) {
      return const SplashView();
    }

    if (appDataAsync.hasError) {
      return NoInternetScreen(
        onRetry: () {
          ref.invalidate(SplashService.appDataProvider);
        },
      );
    }

    // Check Authentication state
    final authAsync = ref.watch(SplashService.authProvider);

    if ((authAsync.isLoading && !authAsync.hasValue) || authAsync.hasError) {
      return const SplashView();
    }

    final UserCheckResult check = authAsync.value!;
    if (check.isDeleted) {
      return const AccountDeletedScreen();
    }
    if (check.isBlocked) {
      return const AccountBlockedScreen();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      if (check.user != null && check.user!.uid.isNotEmpty) {
        LocalStorage.setOnboardingCompleted();
        AutoRouter.of(context).replace(DashboardScreenRoute(userId: check.user!.uid));
      } else if (!LocalStorage.isOnboardingCompleted()) {
        AutoRouter.of(context).replace(const OnboardingScreenRoute());
      } else {
        AutoRouter.of(context).replace(const AuthenticationScreenRoute());
      }
    });

    return const SplashView();
  }
}

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Main Center Splash Content
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 4),

                    // Floating App Logo (Original Large Size with Elegant Soft Aura)
                    AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9333EA).withValues(alpha: 0.16),
                                  blurRadius: 36,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/icons/crazy_reward_logo.png',
                              width: 140.w,
                              height: 140.w,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 24.h),

                    // App Title (Matching Hot Offers KaushanScript Style)
                    Text(
                      'Crazyreward',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.kaushanScript(
                        color: const Color(0xFF1E1B2E),
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // App Subtitle Tagline Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFD8B4FE),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'PLAY GAMES • WIN REWARDS',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF7C3AED),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Clean Modern Loader for White Theme
                    const _SplashModernLoader(),

                    SizedBox(height: 28.h),
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

// -------------------------------------------------------------
// CLEAN MODERN LOADER FOR WHITE THEME
// -------------------------------------------------------------
class _SplashModernLoader extends StatefulWidget {
  const _SplashModernLoader();

  @override
  State<_SplashModernLoader> createState() => _SplashModernLoaderState();
}

class _SplashModernLoaderState extends State<_SplashModernLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer Track
        Container(
          width: 160.w,
          height: 6.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final value = _controller.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(value * 3.0 - 1.5, 0),
                      end: Alignment(value * 3.0 - 0.5, 0),
                      colors: const [
                        Colors.transparent,
                        Color(0xFFE9D5FF),
                        Color(0xFF9333EA),
                        Color(0xFF7C3AED),
                        Color(0xFFE9D5FF),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.65, 0.85, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 10.h),
        // Loading Text
        Text(
          'LOADING...',
          style: GoogleFonts.poppins(
            color: const Color(0xFF94A3B8),
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
          ),
        ),
      ],
    );
  }
}
