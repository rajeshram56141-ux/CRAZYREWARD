import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/theme/theme.dart';

import '../common/custom_loading.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/icons/bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: LoadingInfoWidget(color: AppTheme.primaryColor),
      ),
    );
  }
}

class LoadingInfoWidget extends StatelessWidget {
  const LoadingInfoWidget({
    super.key,
    this.color = AppTheme.primaryColor,
    this.style,
  });

  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10,
        children: [
          GlowLightingSpinner(
            size: 28,
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.6),
              color,
            ],
          ),
          Text(
            'loading'.tr(),
            style: style ?? GoogleFonts.orbitron(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12.sp,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
