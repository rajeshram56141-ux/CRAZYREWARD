import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetScreen({
    super.key,
    this.onRetry,
  });

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
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Top Executive System Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: const Color(0xFFE9D5FF),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'NETWORK DISCONNECTED',
                          style: GoogleFonts.outfit(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFAB31DE),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // 2. Wifi Hero Artwork
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icons/wifi.png',
                      width: 230.w,
                      height: 230.w,
                      fit: BoxFit.contain,
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // 3. Headline & Subtitle
                  Text(
                    'No Internet Connection',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 25.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    'We couldn’t connect to the internet. Please check your Wi-Fi or mobile network connection and try again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 28.h),

                  // 4. Info Card: Connection Offline Status
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: const Color(0xFFE9D5FF),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3E8FF),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.wifi_off_rounded,
                            color: const Color(0xFFAB31DE),
                            size: 20.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connection Offline',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF1E1B4B),
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Please ensure mobile data or Wi-Fi is active',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 28.h),

                  // 5. Action Button (Retry or Open Settings)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onRetry != null) {
                        onRetry!();
                      } else {
                        AppSettings.openAppSettings(type: AppSettingsType.wireless);
                      }
                    },
                    child: Container(
                      height: 50.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              onRetry != null ? Icons.refresh_rounded : Icons.wifi_find_rounded,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              onRetry != null ? 'Retry Connection' : 'Open Settings',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (onRetry != null) ...[
                    SizedBox(height: 12.h),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        AppSettings.openAppSettings(type: AppSettingsType.wireless);
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                      ),
                      child: Text(
                        'Open Network Settings',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 4.h),

                  // Close App Option
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      SystemNavigator.pop();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    ),
                    child: Text(
                      'Close Application',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
