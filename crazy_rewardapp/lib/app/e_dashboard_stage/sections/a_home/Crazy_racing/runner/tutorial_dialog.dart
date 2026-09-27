import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class RunnerTutorialDialog extends StatelessWidget {
  const RunnerTutorialDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RunnerTutorialDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: Container(
        padding: EdgeInsets.all(22.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(
            color: const Color(0xFFFFD700),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Header
            Text(
              'HOW TO PLAY',
              style: GoogleFonts.fredoka(
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFFD700),
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 16.h),

            // 3 Clean Control Cards
            _buildControlRow(
              icon: Icons.swipe_left_rounded,
              title: 'SWIPE LEFT / RIGHT',
              desc: 'Switch between 3 highway lanes to steer and overtake.',
              color: const Color(0xFF38BDF8),
            ),
            SizedBox(height: 10.h),
            _buildControlRow(
              icon: Icons.warning_amber_rounded,
              title: 'DODGE TRAFFIC & HAZARDS',
              desc: 'Evade oncoming traffic, heavy trucks, roadblocks, and oil spills.',
              color: const Color(0xFFF87171),
            ),
            SizedBox(height: 10.h),
            _buildControlRow(
              icon: Icons.diamond_rounded,
              title: 'EARN GEMS & POWER-UPS',
              desc: 'Earn 1 Gem every 200M. Collect Shield & Magnet power-ups to survive!',
              color: const Color(0xFFFFD700),
            ),

            SizedBox(height: 20.h),

            // Got It Button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: 44.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF86EFAC), Color(0xFF22C55E), Color(0xFF15803D)],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  'GOT IT! LET\'S RACE',
                  style: GoogleFonts.fredoka(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  desc,
                  style: GoogleFonts.fredoka(
                    color: const Color(0xFF94A3B8),
                    fontSize: 10.5.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
