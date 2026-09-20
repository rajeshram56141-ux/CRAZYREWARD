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

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
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


            // 3. Main Center Splash Content
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 4),

                    // Floating App Logo with Glowing Violet Card
                    AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _floatAnimation.value),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24.r),
                            child: Image.asset(
                              'assets/icons/LOGO_SPLASHS.png',
                              width: 120.w,
                              height: 120.w,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 24.h),

                    // App Title
                    Text(
                      'Crazyreward',
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
                      'PLAY GAMES',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFA78BFA),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Brand New Futuristic Cyber Plasma Energy Loader
                    const _SplashFuturisticCyberLoader(),

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

// -------------------------------------------------------------
// BRAND NEW FUTURISTIC CYBER PLASMA ENERGY LOADER
// -------------------------------------------------------------
class _SplashFuturisticCyberLoader extends StatefulWidget {
  const _SplashFuturisticCyberLoader();

  @override
  State<_SplashFuturisticCyberLoader> createState() => _SplashFuturisticCyberLoaderState();
}

class _SplashFuturisticCyberLoaderState extends State<_SplashFuturisticCyberLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
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
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final value = _controller.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(value * 3.0 - 1.5, 0),
                      end: Alignment(value * 3.0 - 0.5, 0),
                      colors: [
                        Colors.transparent,
                        const Color(0xFFAB31DE).withValues(alpha: 0.3),
                        const Color(0xFFA78BFA),
                        Colors.white,
                        const Color(0xFFA78BFA),
                        const Color(0xFFAB31DE).withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.2, 0.45, 0.5, 0.55, 0.8, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(height: 12.h),
        // Subtle Animated Loading Text
        Text(
          'LOADING...',
          style: GoogleFonts.poppins(
            color: const Color(0xFFA78BFA).withValues(alpha: 0.8),
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}
