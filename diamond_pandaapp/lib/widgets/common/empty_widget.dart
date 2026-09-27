import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NoDataWidget extends StatelessWidget {
  const NoDataWidget({
    super.key,
    required this.msg,
    this.icon = Icons.inbox_rounded,
  });

  final String msg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyStateWidget(
              icon: icon,
              size: 42.w,
            ),
            SizedBox(height: 18.h),
            Text(
              msg.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFFCBD5E1),
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.icon,
    this.size = 70,
  });

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final boxDimension = size * 1.8;

    return Container(
      width: boxDimension,
      height: boxDimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF2E1A47),
            Color(0xFF130D24),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFBA4FFF).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: boxDimension * 0.72,
          height: boxDimension * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E1535),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFEADBFF),
                  Color(0xFFC084FC),
                  Color(0xFF38BDF8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(
                icon,
                size: size,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
