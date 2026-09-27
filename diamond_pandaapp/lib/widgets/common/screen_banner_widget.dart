import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../app/b_splash_stage/splash_service.dart';
import '../../services/launch_url.dart';
import '../../utils/constant/constant.dart';
import 'internet_image.dart';

class ScreenBannerWidget extends StatelessWidget {
  const ScreenBannerWidget({
    super.key,
    required this.screenKey,
    this.margin,
    this.borderRadius,
  });

  final String screenKey;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final banner = SplashService.getScreenBanner(screenKey);
    if (banner == null || banner.imageUrl.isEmpty || !banner.enabled) {
      return const SizedBox.shrink();
    }

    final double radius = borderRadius ?? 14.r;

    return Padding(
      padding: margin ?? EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          // Attribute click accurately: if this screen is using global allScreens fallback, record as allScreens
          final specificBanner = SplashService.screenBanners[screenKey];
          final isUsingGlobal = (specificBanner == null ||
                  !specificBanner.enabled ||
                  specificBanner.imageUrl.isEmpty) &&
              (SplashService.screenBanners['allScreens']?.enabled == true &&
                  SplashService.screenBanners['allScreens']?.imageUrl.isNotEmpty == true);
          final effectiveTrackingKey = isUsingGlobal ? 'allScreens' : screenKey;

          // Record click in background (non-blocking)
          _recordBannerClick(effectiveTrackingKey, banner.clickUrl);

          if (banner.clickUrl.isNotEmpty) {
            LaunchUrl.inWeb(url: banner.clickUrl, context: context);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: AspectRatio(
              // User specified ratio: 700 width x 200 height px (3.5:1)
              aspectRatio: 700 / 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Banner Image (Cached Network Image)
                  InternetImage(
                    url: banner.imageUrl,
                    fit: BoxFit.cover,
                  ),

                  // 2. Circular "AD" Badge in Top Right Corner (Shown only for external/web ads, NOT for In-App Screens)
                  if (!banner.clickUrl.trim().startsWith('app://'))
                    Positioned(
                      top: 6.h,
                      right: 6.w,
                      child: Container(
                        width: 22.w,
                        height: 22.w,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'AD',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 8.5.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              height: 1.0,
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
      ),
    );
  }

  static void _recordBannerClick(String screenKey, String clickUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? '';
      await http.post(
        Uri.parse(AppConst.trackBannerClickApi),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': AppConst.apiKey,
          'user-id': userId,
        },
        body: jsonEncode({
          'screenKey': screenKey,
          'clickUrl': clickUrl,
          'userId': userId,
        }),
      );
    } catch (_) {}
  }
}
