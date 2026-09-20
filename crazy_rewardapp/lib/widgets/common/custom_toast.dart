import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:styled_text/styled_text.dart';

import '../../app/b_splash_stage/splash_service.dart';
import '../../services/launch_url.dart';
import '../../services/local_storage.dart';

import 'internet_image.dart';

/// Universal Custom Toast Notifier for Dialogs, Modals & Floating Toasts
class CustomToast {
  static Future<void> showRatingDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SafeArea(top: false, child: RatingDialogContent()),
    );
  }

  //! Modern Floating Custom Toast Notification
  static void showToast(BuildContext context, {String msg = 'error-subtitle'}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    final animationController = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 280),
    );

    final slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
          CurvedAnimation(parent: animationController, curve: Curves.easeOutBack),
        );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeOut),
    );

    final cleanText = msg.contains(' ') ? msg : msg.tr();

    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 28.h,
          left: 20.w,
          right: 20.w,
          child: Material(
            color: Colors.transparent,
            child: SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 11.h,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E1B4B),
                          Color(0xFF2E1065),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: const Color(0xFFE39FFF).withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                          offset: const Offset(0, 4),
                          blurRadius: 14,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: const Color(0xFFE39FFF),
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            cleanText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5.sp,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    animationController.forward();

    Future.delayed(const Duration(milliseconds: 2800), () async {
      try {
        if (animationController.status == AnimationStatus.completed) {
          await animationController.reverse();
        }
      } catch (_) {}
      try {
        entry.remove();
      } catch (_) {}
      try {
        animationController.dispose();
      } catch (_) {}
    });
  }

  //! Custom Disclosure Dialog
  //! Custom Disclosure Dialog
  static Future<bool> showDisclosure(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Theme(
          data: Theme.of(context).copyWith(
            textTheme: GoogleFonts.outfitTextTheme(Theme.of(context).textTheme),
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0F31),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Handle Pill
                Container(
                  height: 4.h,
                  width: 36.w,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),

                // Icon Badge with Glowing Security Shield
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1B4B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF9333EA).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.security_rounded,
                      color: const Color(0xFFC084FC),
                      size: 32.sp,
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                // Title with Outfit Font
                Text(
                  'disclosure'.tr().toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFE9D5FF),
                          Color(0xFFC084FC),
                        ],
                      ).createShader(
                        Rect.fromLTWH(0.0, 0.0, 200.0.w, 30.0.h),
                      ),
                  ),
                ),

                SizedBox(height: 10.h),

                // Subtitle
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: StyledText(
                    text: 'disclosure-message'.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13.sp,
                      height: 1.5,
                    ),
                    tags: {
                      'terms': StyledTextActionTag(
                        (text, attrs) async {
                          await LaunchUrl.inWeb(
                            url: SplashService.urlConfig.termsOfService,
                            context: context,
                          );
                        },
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFC084FC),
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFFC084FC),
                        ),
                      ),
                      'privacy': StyledTextActionTag(
                        (text, attrs) async {
                          await LaunchUrl.inWeb(
                            url: SplashService.urlConfig.privacyPolicy,
                            context: context,
                          );
                        },
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFC084FC),
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFFC084FC),
                        ),
                      ),
                    },
                  ),
                ),

                SizedBox(height: 20.h),

                // Action Button with 3D Glossy Slanted Pill Style
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: _AnimatedBounceButton(
                    onTap: () => Navigator.pop(context, true),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Transform(
                            transform: Matrix4.skewX(-0.16),
                            alignment: Alignment.center,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF7E10C8),
                                    Color(0xFF9818D6),
                                    Color(0xFFB022E0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: const Color(0xFFF472B6).withValues(alpha: 0.65),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9333EA).withValues(alpha: 0.5),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: const CustomPaint(
                                painter: _PopupGlossyButtonOverlayPainter(),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'continue'.tr(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  //! Custom Device Limit Reached Dialog (Crazyreward Luxury Theme)
  static Future<void> showDeviceLimitPopup({
    required BuildContext context,
    required String title,
    required String subTitle,
    List<String>? registeredEmails,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: _DeviceLimitPopupDialog(
            title: title,
            subTitle: subTitle,
            registeredEmails: registeredEmails,
          ),
        );
      },
    );
  }


  //! Account Details Sheet (Dark Sage Green System)
  static Future<void> showAccountDetailsSheet({
    required BuildContext context,
    required String name,
    required String email,
    required String userId,
    required String photoUrl,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161C15), // Dark Sage Charcoal
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            border: Border.all(
              color: const Color(0xFF607456).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Handle Bar
              Container(
                height: 4.h,
                width: 48.w,
                margin: EdgeInsets.only(bottom: 18.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF607456).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),

              // User Avatar
              Container(
                padding: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF607456),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF607456).withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AvatarInternetImage(
                  url: photoUrl,
                  size: 76,
                  borderWidth: 0,
                  borderColor: Colors.transparent,
                ),
              ),

              SizedBox(height: 12.h),

              Text(
                name.isEmpty ? 'User' : name,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),

              SizedBox(height: 4.h),

              Text(
                email,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFA6B7A2),
                  fontSize: 12.sp,
                ),
              ),

              SizedBox(height: 18.h),

              // Details Glass Card
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF222B21), // Card Tint
                  borderRadius: BorderRadius.circular(18.r),
                  border: Border.all(
                    color: const Color(0xFF607456).withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    // User ID row with copy button
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161C15),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.badge_rounded,
                            color: const Color(0xFF607456),
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User ID',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFA6B7A2),
                                  fontSize: 10.5.sp,
                                ),
                              ),
                              Text(
                                userId,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: userId));
                            CustomToast.showToast(context, msg: 'copied-to-clipboard');
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF607456).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: const Color(0xFF607456).withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  color: const Color(0xFF607456),
                                  size: 13.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Copy',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF607456),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Account Status',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFA6B7A2),
                            fontSize: 12.sp,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF607456).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            'Active ✓',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF607456),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF7B9570),
                          Color(0xFF607456),
                          Color(0xFF475840),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Done',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  // Account has been deleted popup
  static Future<void> showAccountDeletedPopup(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4.h,
                width: 48.w,
                margin: EdgeInsets.only(bottom: 18.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),

              Icon(
                Icons.check_circle_rounded,
                color: const Color(0xFF15803D),
                size: 54.sp,
              ),

              SizedBox(height: 12.h),

              Text(
                'account-deleted-title'.tr(),
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF0F172A),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 8.h),

              Text(
                'account-deleted-message'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: 20.h),

              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF15803D),
                          Color(0xFF22C55E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF15803D).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'OK',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }

  //! Confirm Logout Popup (Light Green/White Theme)
  static Future<bool> showConfirmLogoutPopup(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D1E).withValues(alpha: 0.92),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    height: 4.h,
                    width: 48.w,
                    margin: EdgeInsets.only(bottom: 22.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),

                  // Glowing Indigo Icon Badge
                  Container(
                    padding: EdgeInsets.all(18.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF818CF8).withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 38.w,
                      height: 38.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 1.5.w,
                            top: 1.5.h,
                            child: Icon(
                              Icons.logout_rounded,
                              color: Colors.black.withValues(alpha: 0.7),
                              size: 38.sp,
                            ),
                          ),
                          Icon(
                            Icons.logout_rounded,
                            color: const Color(0xFF818CF8),
                            size: 38.sp,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 18.h),

                  Text(
                    'Logout',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8.h),

                  Text(
                    'Are you sure you want to sign out of your account?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: 26.h),

                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: _ExitDialogGlossyButton(
                          label: 'Cancel',
                          gradientColors: const [
                            Color(0xFF4B5563),
                            Color(0xFF374151),
                            Color(0xFF1F2937),
                          ],
                          borderColor: const Color(0xFF9CA3AF),
                          shadowColor: const Color(0xFF374151),
                          onTap: () => Navigator.pop(context, false),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      // Logout Button
                      Expanded(
                        child: _ExitDialogGlossyButton(
                          label: 'Yes, Logout',
                          gradientColors: const [
                            Color(0xFFEF4444),
                            Color(0xFFDC2626),
                            Color(0xFF991B1B),
                          ],
                          borderColor: const Color(0xFFF87171),
                          shadowColor: const Color(0xFFDC2626),
                          onTap: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
    return result ?? false;
  }

  //! App Close Popup (Light Green/White Theme)
  static void showAppClosePopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1E).withValues(alpha: 0.92),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  height: 4.h,
                  width: 48.w,
                  margin: EdgeInsets.only(bottom: 22.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),

                // Exit Icon Badge (3D Red Glowing Warning Circle)
                Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF87171).withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 38.w,
                    height: 38.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 1.5.w,
                          top: 1.5.h,
                          child: Icon(
                            Icons.exit_to_app_rounded,
                            color: Colors.black.withValues(alpha: 0.7),
                            size: 38.sp,
                          ),
                        ),
                        Icon(
                          Icons.exit_to_app_rounded,
                          color: const Color(0xFFF87171),
                          size: 38.sp,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 18.h),

                Text(
                  'Exit Application',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8.h),

                Text(
                  'Are you sure you want to exit the app?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: 26.h),

                Row(
                  children: [
                    // Stay Button (Green/Success gloss)
                    Expanded(
                      child: _ExitDialogGlossyButton(
                        label: 'No, Stay',
                        gradientColors: const [
                          Color(0xFF10B981),
                          Color(0xFF059669),
                          Color(0xFF047857),
                        ],
                        borderColor: const Color(0xFF34D399),
                        shadowColor: const Color(0xFF059669),
                        onTap: () {
                          AutoRouter.of(context).maybePop();
                        },
                      ),
                    ),
                    SizedBox(width: 14.w),
                    // Exit Button (Red/Danger gloss)
                    Expanded(
                      child: _ExitDialogGlossyButton(
                        label: 'Yes, Exit',
                        gradientColors: const [
                          Color(0xFFEF4444),
                          Color(0xFFDC2626),
                          Color(0xFF991B1B),
                        ],
                        borderColor: const Color(0xFFF87171),
                        shadowColor: const Color(0xFFDC2626),
                        onTap: () {
                          SystemNavigator.pop();
                        },
                      ),
                    ),
                  ],
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

class RatingDialogContent extends StatefulWidget {
  const RatingDialogContent({super.key});

  @override
  State<RatingDialogContent> createState() => _RatingDialogContentState();
}

class _RatingDialogContentState extends State<RatingDialogContent> with TickerProviderStateMixin {
  int _rating = 0;
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      5,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onStarTapped(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _rating = index + 1;
    });
    for (int i = 0; i <= index; i++) {
      _controllers[i].forward(from: 0.0);
    }
    for (int i = index + 1; i < 5; i++) {
      _controllers[i].reverse();
    }
  }

  String _getRatingFeedbackText(int rating) {
    switch (rating) {
      case 1:
        return 'Needs Improvement 😞';
      case 2:
        return 'Could Be Better 😐';
      case 3:
        return 'Good Experience 😊';
      case 4:
        return 'Great App! 😄';
      case 5:
        return 'Loved It! Top Tier! ❤️🔥';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 28.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF22113A),
            Color(0xFF140A24),
            Color(0xFF0E071A),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF7640FE).withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top Drag Handle Bar
              Container(
                height: 4.5.h,
                width: 48.w,
                margin: EdgeInsets.only(bottom: 22.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF475569).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),

              // 2. Large Bold Main Title ("Enjoying The App?")
              Text(
                'Enjoying The App?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24.sp,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 8.h),

              // 3. Subtitle Description
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Text(
                  'Support us with a quick play store rating. Your feedback means a lot to us.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFCBD5E1),
                    fontSize: 13.sp,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(height: 28.h),

              // 4. 5-Star Row with Ambient Arc Watermark
              Stack(
                alignment: Alignment.center,
                children: [
                  // Ambient Torus Glow Watermark
                  Container(
                    width: 220.w,
                    height: 60.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7640FE).withValues(alpha: 0.18),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),

                  // Stars Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final isSelected = index < _rating;
                      return GestureDetector(
                        onTap: () => _onStarTapped(index),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.35).animate(
                            CurvedAnimation(
                              parent: _controllers[index],
                              curve: Curves.bounceOut,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5.w),
                            child: isSelected
                                ? ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFF7C2), // Top bright shine
                                        Color(0xFFFBBF24), // Vibrant gold
                                        Color(0xFFF59E0B), // Warm amber
                                        Color(0xFFD97706), // Bottom shadow
                                      ],
                                      stops: [0.0, 0.35, 0.70, 1.0],
                                    ).createShader(bounds),
                                    child: Icon(
                                      Icons.star_rounded,
                                      color: Colors.white,
                                      size: 46.sp,
                                    ),
                                  )
                                : Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 46.sp,
                                  ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),

              // 5. Rating Feedback Label
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(top: _rating > 0 ? 16.h : 0),
                height: _rating > 0 ? 28.h : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: _rating > 0 ? 1.0 : 0.0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1438),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getRatingFeedbackText(_rating),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFBBF24),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // 6. 3D Tapered Glossy Action Button
              if (_rating > 0)
                _RatingTaperedActionButton(
                  title: _rating >= 4 ? 'RATE ON PLAY STORE ⭐' : 'SEND FEEDBACK 💬',
                  onTap: () async {
                    Navigator.of(context).pop();
                    LocalStorage.setUserRated();
                    if (_rating >= 4) {
                      await LaunchUrl.inWeb(
                        url: 'https://play.google.com/store/apps/details?id=${SplashService.packageName}',
                        context: context,
                      );
                    } else {
                      await LaunchUrl.openSupportMail(
                        context: context,
                        subject: 'App Feedback - Crazyreward',
                      );
                    }
                  },
                ),

              SizedBox(height: 14.h),

              // 7. Maybe Later Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Text(
                    'Maybe Later',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3D TAPERED GLOSSY ACTION BUTTON FOR RATING MODAL
// ---------------------------------------------------------------------------
class _RatingTaperedActionButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _RatingTaperedActionButton({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedBounceButton(
      onTap: onTap,
      child: CustomPaint(
        painter: const _RatingTaperedPainter(
          taper: 7.0,
          radius: 16.0,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48.h,
          child: Center(
            child: Text(
              title,
              maxLines: 1,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingTaperedPainter extends CustomPainter {
  final double taper;
  final double radius;

  const _RatingTaperedPainter({
    this.taper = 7.0,
    this.radius = 16.0,
  });

  Path getButtonPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final t = taper;
    final r = radius;

    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w - (t * 0.15), r * 0.7);
    path.lineTo(w - t + (t * 0.15), h - r * 0.7);
    path.quadraticBezierTo(w - t, h, w - t - r, h);
    path.lineTo(t + r, h);
    path.quadraticBezierTo(t, h, t - (t * 0.15), h - r * 0.7);
    path.lineTo(t * 0.15, r * 0.7);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = getButtonPath(size);

    // Shadow
    canvas.drawShadow(
      path,
      const Color(0xFF24007A).withValues(alpha: 0.70),
      8.0,
      true,
    );

    // Fill Gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFEADBFF), // Top Milk-Lavender Gloss
          Color(0xFFA565FF), // Mid Rich Violet
          Color(0xFF6B15F6), // Vibrant Electric Violet
          Color(0xFF550BD0), // Deep Bottom Violet Base
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0.0, 0.30, 0.75, 1.0],
      ).createShader(rect);

    canvas.drawPath(path, fillPaint);

    // Top Stroke Highlight
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45, 0.9],
      ).createShader(rect);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedBounceButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _AnimatedBounceButton({
    required this.onTap,
    required this.child,
  });

  @override
  State<_AnimatedBounceButton> createState() => _AnimatedBounceButtonState();
}

class _AnimatedBounceButtonState extends State<_AnimatedBounceButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _DeviceLimitPopupDialog extends StatelessWidget {
  const _DeviceLimitPopupDialog({
    required this.title,
    required this.subTitle,
    this.registeredEmails,
  });

  final String title;
  final String subTitle;
  final List<String>? registeredEmails;

  @override
  Widget build(BuildContext context) {
    final validEmails =
        registeredEmails?.where((e) => e.trim().isNotEmpty).toList() ?? [];

    return PopScope(
      canPop: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E1B4B).withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(22.w, 12.h, 22.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Handle Drag Bar
                Container(
                  width: 44.w,
                  height: 4.5.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
                SizedBox(height: 20.h),

                // Device Illustration with Ambient Purple Glow
                Container(
                  width: 96.w,
                  height: 96.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE39FFF).withValues(alpha: 0.20),
                        const Color(0xFFAB31DE).withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFFE39FFF).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/icons/mobile-phone-with-touch-3d-icon-png-download-6293808 1.png',
                      width: 60.w,
                      height: 60.w,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.phonelink_lock_rounded,
                        size: 46.sp,
                        color: const Color(0xFFAB31DE),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),

                // Security Tag
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7.w,
                        height: 7.w,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'DEVICE SECURITY LIMIT',
                        style: GoogleFonts.outfit(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),

                // Headline
                Text(
                  title.isNotEmpty ? title : 'Device Limit Exceeded',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E1B4B),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 8.h),

                // Subtitle explanation
                Text(
                  validEmails.isNotEmpty
                      ? 'Only 1 Crazyreward account is allowed per device. This device is already linked to the account shown below.'
                      : (subTitle.isNotEmpty
                          ? subTitle
                          : 'Multiple accounts or device limit reached. Please log in using your primary registered account on this device.'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),

                // Registered Account(s) Card (if available)
                if (validEmails.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 15.sp,
                              color: const Color(0xFFAB31DE),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Linked Account on this Device',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        ...validEmails.map(
                          (email) => Container(
                            margin: EdgeInsets.only(bottom: 4.h),
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 7.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.alternate_email_rounded,
                                  size: 14.sp,
                                  color: const Color(0xFF64748B),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E1B4B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 22.h),

                // Primary Luxury Gradient Button: "Understood"
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48.h,
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
                    alignment: Alignment.center,
                    child: Text(
                      'Understood',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 10.h),

                // Contact Support Link
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await LaunchUrl.openSupportMail(
                      context: context,
                      subject: 'Device Limit Assistance - Crazyreward',
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          size: 16.sp,
                          color: const Color(0xFF94A3B8),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Need Help? Contact Support',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
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

class _PopupGlossyButtonOverlayPainter extends CustomPainter {
  const _PopupGlossyButtonOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top sweeping curved glass reflection
    final wavePath = Path();
    wavePath.moveTo(0, 0);
    wavePath.lineTo(w, 0);
    wavePath.lineTo(w, h * 0.36);
    wavePath.cubicTo(
      w * 0.70,
      h * 0.46,
      w * 0.35,
      h * 0.68,
      0,
      h * 0.42,
    );
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.68));

    canvas.drawPath(wavePath, wavePaint);

    // Top-left oval bright specular reflection dot
    final dotRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(18.w, 4.5.h, 16.w, 4.5.h),
      Radius.circular(3.r),
    );
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.90);
    canvas.drawRRect(dotRect, dotPaint);

    // Bottom-right subtle reflection crescent
    final bottomPath = Path();
    bottomPath.moveTo(w * 0.65, h);
    bottomPath.cubicTo(
      w * 0.80,
      h * 0.85,
      w * 0.92,
      h * 0.80,
      w,
      h * 0.68,
    );
    bottomPath.lineTo(w, h);
    bottomPath.close();

    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(w * 0.65, h * 0.68, w * 0.35, h * 0.32));

    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _ExitDialogGlossyButton extends StatefulWidget {
  final String label;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final VoidCallback onTap;

  const _ExitDialogGlossyButton({
    required this.label,
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  State<_ExitDialogGlossyButton> createState() => _ExitDialogGlossyButtonState();
}

class _ExitDialogGlossyButtonState extends State<_ExitDialogGlossyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: SizedBox(
          width: double.infinity,
          height: 44.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Skewed Glossy Glowing Button Base
              Positioned.fill(
                child: Transform(
                  transform: Matrix4.skewX(-0.16),
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: widget.borderColor.withValues(alpha: 0.65),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.shadowColor.withValues(
                            alpha: _isPressed ? 0.20 : 0.45,
                          ),
                          blurRadius: _isPressed ? 5 : 10,
                          offset: Offset(0, _isPressed ? 2 : 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const CustomPaint(
                      painter: _ExitGlossyButtonPainter(),
                    ),
                  ),
                ),
              ),

              // 2. Center Text
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExitGlossyButtonPainter extends CustomPainter {
  const _ExitGlossyButtonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top sweeping specular glass shine wave
    final wavePath = Path();
    wavePath.moveTo(0, 0);
    wavePath.lineTo(w, 0);
    wavePath.lineTo(w, h * 0.38);
    wavePath.cubicTo(
      w * 0.72, h * 0.48,
      w * 0.38, h * 0.68,
      0, h * 0.44,
    );
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.38),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.68));

    canvas.drawPath(wavePath, wavePaint);

    // Oval specular reflection dot / pill
    final dotRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(22.w, 4.5.h, 22.w, 5.h),
      Radius.circular(3.r),
    );
    canvas.drawRRect(
      dotRect,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Bottom-right subtle reflection crescent
    final bottomPath = Path();
    bottomPath.moveTo(w * 0.68, h);
    bottomPath.cubicTo(
      w * 0.82, h * 0.86,
      w * 0.94, h * 0.82,
      w, h * 0.70,
    );
    bottomPath.lineTo(w, h);
    bottomPath.close();

    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(w * 0.68, h * 0.70, w * 0.32, h * 0.30));

    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _ExitGlossyButtonPainter oldDelegate) => false;
}
