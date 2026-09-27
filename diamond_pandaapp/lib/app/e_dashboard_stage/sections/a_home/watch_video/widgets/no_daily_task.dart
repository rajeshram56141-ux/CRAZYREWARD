import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NoDailyTask extends StatelessWidget {
  final String? title;
  final String? message;
  final IconData? icon;
  final Color? accentColor;
  final bool isVideo;

  const NoDailyTask({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.accentColor,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? (isVideo ? const Color(0xFFC084FC) : const Color(0xFFBA4FFF));
    final effectiveIcon = icon ?? (isVideo ? Icons.videocam_off_rounded : Icons.assignment_late_outlined);
    final effectiveTitle = title ?? (isVideo ? 'No Videos Available' : 'no-tasks-available'.tr());
    final effectiveMessage = message ??
        (isVideo
            ? 'New short videos are being added regularly.\nPlease check back in a little while to earn coins!'
            : 'no-tasks-available-message'.tr());

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pure Icon with Gradient (No circle, no glow background)
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  const Color(0xFFF472B6),
                  effectiveAccent,
                  const Color(0xFF818CF8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(
                effectiveIcon,
                size: 52.sp,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 20.h),

            // Title
            Text(
              effectiveTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),

            SizedBox(height: 8.h),

            // Subtitle / Description
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 290.w),
              child: Text(
                effectiveMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.sp,
                  color: const Color(0xFF94A3B8),
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
