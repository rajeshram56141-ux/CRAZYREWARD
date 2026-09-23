import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../common/custom_loading.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.black,
            image: DecorationImage(
              image: AssetImage('assets/icons/Splash (2).png'),
              fit: BoxFit.cover,
            ),
          ),
          child: const LoadingInfoWidget(),
        ),
      ),
    );
  }
}

class LoadingInfoWidget extends StatelessWidget {
  const LoadingInfoWidget({
    super.key,
    this.color,
    this.textColor,
    this.style,
  });

  final Color? color;
  final Color? textColor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final effectiveSpinnerColor = color ?? const Color(0xFFC084FC);
    final effectiveTextColor = textColor ?? Colors.black;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GlowLightingSpinner(
            size: 32,
            colors: [
              effectiveSpinnerColor.withValues(alpha: 0.15),
              effectiveSpinnerColor.withValues(alpha: 0.6),
              effectiveSpinnerColor,
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            'loading'.tr().toUpperCase(),
            style: style ??
                GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: effectiveTextColor,
                  fontSize: 11.5.sp,
                  letterSpacing: 2.0,
                ),
          ),
        ],
      ),
    );
  }
}
