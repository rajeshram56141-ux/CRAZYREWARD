// ignore_for_file: depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/launch_url.dart';
import '../../widgets/common/custom_loading.dart';
import '../../widgets/common/custom_status_popup.dart';
import '../b_splash_stage/splash_service.dart';
import 'authentication_service.dart';

@RoutePage()
class AuthenticationScreen extends HookWidget {
  const AuthenticationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isGuestLoading = useState<bool>(false);
    final isGoogleLoading = useState<bool>(false);
    final isGooglePressed = useState<bool>(false);
    final isGuestPressed = useState<bool>(false);

    final termsRecognizer = useMemoized(() => TapGestureRecognizer()..onTap = () {
      LaunchUrl.inWeb(
        url: SplashService.urlConfig.termsOfService,
        context: context,
      );
    });
    final privacyRecognizer = useMemoized(() => TapGestureRecognizer()..onTap = () {
      LaunchUrl.inWeb(
        url: SplashService.urlConfig.privacyPolicy,
        context: context,
      );
    });

    useEffect(() {
      return () {
        termsRecognizer.dispose();
        privacyRecognizer.dispose();
      };
    }, [termsRecognizer, privacyRecognizer]);

    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          CustomStatusPopup.showAppExit(context: context);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFF1F5F9),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          resizeToAvoidBottomInset: true,
          body: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: Stack(
              children: [
                // 1. Ambient Pastel Glow Blobs for depth
                Positioned(
                  top: -60.h,
                  right: -40.w,
                  child: Container(
                    width: 220.w,
                    height: 220.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF9333EA).withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 60.h,
                  left: -50.w,
                  child: Container(
                    width: 200.w,
                    height: 200.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.07),
                    ),
                  ),
                ),

                // 2. Main Login Content
                Positioned.fill(
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 8.h),

                            // Top Hero Section: 3D App Logo + Branding
                            const _AuthSingleHeroSection(),

                            SizedBox(height: 28.h),

                            // Elevated Auth Card Container
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFF9333EA).withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Card Title
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 24.w,
                                        height: 2.h,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Colors.transparent, Color(0xFF9333EA)],
                                          ),
                                          borderRadius: BorderRadius.circular(2.r),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                                        child: Text(
                                          'Get Started',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1E1B2E),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 24.w,
                                        height: 2.h,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF9333EA), Colors.transparent],
                                          ),
                                          borderRadius: BorderRadius.circular(2.r),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Choose your preferred login method',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  SizedBox(height: 20.h),

                                  // 1. Google Login Button
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (_) {
                                      isGooglePressed.value = true;
                                      HapticFeedback.lightImpact();
                                    },
                                    onTapCancel: () {
                                      isGooglePressed.value = false;
                                    },
                                    onTap: () async {
                                      isGooglePressed.value = false;
                                      if (isGoogleLoading.value || isGuestLoading.value) return;
                                      isGoogleLoading.value = true;
                                      try {
                                        await AuthenticationService.signInWithGoogle(context);
                                      } finally {
                                        isGoogleLoading.value = false;
                                      }
                                    },
                                    child: AnimatedScale(
                                      scale: isGooglePressed.value ? 0.97 : 1.0,
                                      duration: const Duration(milliseconds: 100),
                                      curve: Curves.easeInOut,
                                      child: Container(
                                        height: 52.h,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16.r),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0F172A).withValues(
                                                alpha: isGooglePressed.value ? 0.04 : 0.08,
                                              ),
                                              blurRadius: isGooglePressed.value ? 4 : 10,
                                              offset: Offset(0, isGooglePressed.value ? 2 : 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (isGoogleLoading.value) ...[
                                              const GlowLightingSpinner(
                                                size: 22,
                                                colors: [
                                                  Color(0xFF7C3AED),
                                                  Color(0xFFAB31DE),
                                                  Color(0xFF5C1B78),
                                                  Color(0xFF7C3AED),
                                                ],
                                              ),
                                              SizedBox(width: 10.w),
                                              Text(
                                                'Connecting...',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF1E293B),
                                                ),
                                              ),
                                            ] else ...[
                                              Image.asset(
                                                'assets/icons/google.png',
                                                height: 22.h,
                                                errorBuilder: (_, __, ___) => Icon(
                                                  Icons.g_mobiledata_rounded,
                                                  size: 26.sp,
                                                  color: const Color(0xFF4285F4),
                                                ),
                                              ),
                                              SizedBox(width: 12.w),
                                              Text(
                                                'Continue with Google',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF1E293B),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: 12.h),

                                  // 2. Guest Login Button
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (_) {
                                      isGuestPressed.value = true;
                                      HapticFeedback.lightImpact();
                                    },
                                    onTapCancel: () {
                                      isGuestPressed.value = false;
                                    },
                                    onTap: () async {
                                      isGuestPressed.value = false;
                                      if (isGuestLoading.value || isGoogleLoading.value) return;
                                      isGuestLoading.value = true;
                                      try {
                                        await AuthenticationService.signInAnonymously(context);
                                      } finally {
                                        isGuestLoading.value = false;
                                      }
                                    },
                                    child: AnimatedScale(
                                      scale: isGuestPressed.value ? 0.97 : 1.0,
                                      duration: const Duration(milliseconds: 100),
                                      curve: Curves.easeInOut,
                                      child: Container(
                                        height: 52.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF5FF),
                                          borderRadius: BorderRadius.circular(16.r),
                                          border: Border.all(
                                            color: const Color(0xFFD8B4FE),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF9333EA).withValues(
                                                alpha: isGuestPressed.value ? 0.04 : 0.08,
                                              ),
                                              blurRadius: isGuestPressed.value ? 4 : 8,
                                              offset: Offset(0, isGuestPressed.value ? 2 : 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (isGuestLoading.value) ...[
                                              const GlowLightingSpinner(
                                                size: 22,
                                                colors: [
                                                  Color(0xFFC084FC),
                                                  Color(0xFFAB31DE),
                                                  Color(0xFF5C1B78),
                                                  Color(0xFFC084FC),
                                                ],
                                              ),
                                              SizedBox(width: 10.w),
                                              Text(
                                                'Entering as Guest...',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF7C3AED),
                                                ),
                                              ),
                                            ] else ...[
                                              Container(
                                                padding: EdgeInsets.all(4.w),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.person_rounded,
                                                  color: const Color(0xFF7C3AED),
                                                  size: 18.sp,
                                                ),
                                              ),
                                              SizedBox(width: 10.w),
                                              Text(
                                                'Continue as Guest',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF7C3AED),
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 24.h),

                            // Contact Support
                            GestureDetector(
                              onTap: () => LaunchUrl.openSupportMail(
                                context: context,
                                subject: 'Login Problem - Crazyreward',
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.headset_mic_rounded,
                                      size: 15.sp,
                                      color: const Color(0xFF7C3AED),
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      '${'problem-in-login'.tr()} ',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.sp,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'contact-us'.tr(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7C3AED),
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: 16.h),

                            // Terms & Privacy disclosure
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Text.rich(
                                TextSpan(
                                  text: 'By continuing, you agree to our ',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.sp,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Terms',
                                      recognizer: termsRecognizer,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7C3AED),
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color(0xFF7C3AED),
                                      ),
                                    ),
                                    const TextSpan(text: ' & '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      recognizer: privacyRecognizer,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF7C3AED),
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            SizedBox(height: 12.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthSingleHeroSection extends StatelessWidget {
  const _AuthSingleHeroSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Glowing 3D App Icon
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9333EA).withValues(alpha: 0.18),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Image.asset(
            'assets/icons/crazy_reward_logo.png',
            width: 100.w,
            height: 100.w,
            fit: BoxFit.contain,
          ),
        ),

        SizedBox(height: 16.h),

        // Brand Title (Matching Hot Offers KaushanScript Style)
        Text(
          'Crazyreward',
          textAlign: TextAlign.center,
          style: GoogleFonts.kaushanScript(
            fontSize: 32.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E1B2E),
            letterSpacing: 0.5,
          ),
        ),

        SizedBox(height: 6.h),

        // Tagline Pill
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFFD8B4FE),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9333EA).withValues(alpha: 0.06),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            'PLAY GAMES • WIN REWARDS',
            style: GoogleFonts.outfit(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7C3AED),
              letterSpacing: 1.2,
            ),
          ),
        ),

        SizedBox(height: 10.h),

        // Description
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Play exciting games, complete fun tasks, compete on the leaderboard, and unlock daily prizes!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
