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
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: true,
          body: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: Stack(
              children: [
                // 1. App Wallpaper Background (Fixed Fullscreen)
                Positioned(
                  left: 0,
                  top: 0,
                  width: screenSize.width,
                  height: screenSize.height,
                  child: Image.asset(
                    'assets/icons/Splash (2).png',
                    fit: BoxFit.cover,
                  ),
                ),


                // 3. Main Login Content
                Positioned.fill(
                  child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Hero Section: App Logo + Welcome Text + Subtitle
                          Padding(
                            padding: EdgeInsets.only(left: 24.w, right: 0.w),
                            child: const _AuthSingleHeroSection(),
                          ),

                          SizedBox(height: 24.h),

                          // Authentication Header
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: Row(
                              children: [
                                Container(
                                  width: 6.w,
                                  height: 20.h,
                                  decoration: const BoxDecoration(
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Authentication',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 16.h),

                          // Login Buttons Column
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: Column(
                              children: [
                              // 1. Google Login (Signature Daily Task Claim-Style Button)
                              Center(
                                child: GestureDetector(
                                  onTapDown: (_) {
                                    isGooglePressed.value = true;
                                    HapticFeedback.lightImpact();
                                  },
                                  onTapUp: (_) async {
                                    isGooglePressed.value = false;
                                    if (isGoogleLoading.value || isGuestLoading.value) return;
                                    isGoogleLoading.value = true;
                                    try {
                                      await AuthenticationService.signInWithGoogle(context);
                                    } finally {
                                      isGoogleLoading.value = false;
                                    }
                                  },
                                  onTapCancel: () {
                                    isGooglePressed.value = false;
                                  },
                                  child: AnimatedScale(
                                    scale: isGooglePressed.value ? 0.96 : 1.0,
                                    duration: const Duration(milliseconds: 100),
                                    curve: Curves.easeInOut,
                                    child: Container(
                                      width: 220.w,
                                      height: 52.h,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: isGooglePressed.value ? 0.05 : 0.08,
                                            ),
                                            blurRadius: isGooglePressed.value ? 6 : 12,
                                            offset: Offset(0, isGooglePressed.value ? 2 : 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 16.w),
                                          if (isGoogleLoading.value) ...[
                                            const GlowLightingSpinner(
                                              size: 20,
                                              colors: [
                                                Color(0xFFAB31DE),
                                                Color(0xFFAB31DE),
                                                Color(0xFF5C1B78),
                                                Color(0xFFAB31DE),
                                              ],
                                            ),
                                          ] else ...[
                                            Image.asset(
                                              'assets/icons/google.png',
                                              height: 20.h,
                                            ),
                                          ],
                                          const Spacer(),
                                          Text(
                                            'Google',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 13.sp,
                                            color: Colors.black54,
                                          ),
                                          SizedBox(width: 16.w),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 14.h),

                              // 2. Guest Login (Frosted Dark Violet Glass Button)
                              Center(
                                child: GestureDetector(
                                  onTapDown: (_) {
                                    isGuestPressed.value = true;
                                    HapticFeedback.lightImpact();
                                  },
                                  onTapUp: (_) async {
                                    isGuestPressed.value = false;
                                    if (isGuestLoading.value || isGoogleLoading.value) return;
                                    isGuestLoading.value = true;
                                    try {
                                      await AuthenticationService.signInAnonymously(context);
                                    } finally {
                                      isGuestLoading.value = false;
                                    }
                                  },
                                  onTapCancel: () {
                                    isGuestPressed.value = false;
                                  },
                                  child: AnimatedScale(
                                    scale: isGuestPressed.value ? 0.96 : 1.0,
                                    duration: const Duration(milliseconds: 100),
                                    curve: Curves.easeInOut,
                                    child: Container(
                                      width: 220.w,
                                      height: 52.h,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: isGuestPressed.value ? 0.05 : 0.08,
                                            ),
                                            blurRadius: isGuestPressed.value ? 6 : 12,
                                            offset: Offset(0, isGuestPressed.value ? 2 : 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 16.w),
                                          if (isGuestLoading.value) ...[
                                            const GlowLightingSpinner(
                                              size: 20,
                                              colors: [
                                                Color(0xFFAB31DE),
                                                Color(0xFFAB31DE),
                                                Color(0xFF5C1B78),
                                                Color(0xFFAB31DE),
                                              ],
                                            ),
                                          ] else ...[
                                            Icon(
                                              Icons.person_outline_rounded,
                                              color: Colors.black87,
                                              size: 20.sp,
                                            ),
                                          ],
                                          const Spacer(),
                                          Text(
                                            'Guest',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14.5.sp,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const Spacer(),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 13.sp,
                                            color: Colors.black54,
                                          ),
                                          SizedBox(width: 16.w),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 28.h),

                          // Contact Support & Disclosure Links
                          Center(
                            child: Column(
                              children: [
                                GestureDetector(
                                onTap: () => LaunchUrl.openSupportMail(
                                  context: context,
                                  subject: 'Login Problem - Crazyreward',
                                ),
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${'problem-in-login'.tr()} ',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          color: const Color(0xFF475569),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'contact-us'.tr(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFAB31DE),
                                          decoration: TextDecoration.underline,
                                          decorationColor: const Color(0xFFAB31DE),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Small Terms / Privacy disclosure
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Text.rich(
                                  TextSpan(
                                    text: 'By continuing, you agree to our ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5.sp,
                                      color: const Color(0xFF475569),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Terms',
                                        recognizer: termsRecognizer,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFAB31DE),
                                          decoration: TextDecoration.underline,
                                          decorationColor: const Color(0xFFAB31DE),
                                        ),
                                      ),
                                      const TextSpan(text: ' & '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        recognizer: privacyRecognizer,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFFAB31DE),
                                          decoration: TextDecoration.underline,
                                          decorationColor: const Color(0xFFAB31DE),
                                        ),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand Gaming Title
              Text(
                'Crazyreward',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontFamily: 'Neogen',
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFAB31DE),
                  letterSpacing: 0.2,
                ),
              ),

              SizedBox(height: 6.h),

              // Description
              Text(
                'Play exciting games, complete tasks, compete on the leaderboard, and have fun every day!',
                textAlign: TextAlign.left,
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),

            ],
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          flex: 5,
          child: Image.asset(
            'assets/icons/loginicon.png',
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}
