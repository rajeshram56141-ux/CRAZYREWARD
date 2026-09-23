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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          offset: const Offset(0, 4),
                          blurRadius: 16,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          offset: const Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: const Color(0xFF26262B),
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            cleanText,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF26262B),
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
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
  static Future<bool> showDisclosure(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),

              // Icon Badge
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.security_rounded,
                    color: const Color(0xFF26262B),
                    size: 30.sp,
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // Title
              Text(
                'disclosure'.tr().toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF26262B),
                ),
              ),

              SizedBox(height: 10.h),

              // Subtitle
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: StyledText(
                  text: 'disclosure-message'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
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
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF26262B),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFF26262B),
                      ),
                    ),
                    'privacy': StyledTextActionTag(
                      (text, attrs) async {
                        await LaunchUrl.inWeb(
                          url: SplashService.urlConfig.privacyPolicy,
                          context: context,
                        );
                      },
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF26262B),
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFF26262B),
                      ),
                    ),
                  },
                ),
              ),

              SizedBox(height: 20.h),

              // Action Button (Silver Metallic Executive Gradient)
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: _AnimatedBounceButton(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.white,
                          Color(0xFFE5E7EB),
                          Color(0xFFB0B5C2),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: const Color(0xFF9CA3AF),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: const Color(0xFF16161A),
                          size: 19.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'continue'.tr(),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF16161A),
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  //! Custom Device Limit Reached Dialog
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

  //! Account Details Sheet
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
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),

                // User Avatar
                Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 2,
                    ),
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
                    color: const Color(0xFF26262B),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 4.h),

                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 12.5.sp,
                  ),
                ),

                SizedBox(height: 18.h),

                // Details Card
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.badge_rounded,
                              color: const Color(0xFF26262B),
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
                                    color: const Color(0xFF64748B),
                                    fontSize: 10.5.sp,
                                  ),
                                ),
                                Text(
                                  userId,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF26262B),
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.copy_rounded,
                                    color: const Color(0xFF26262B),
                                    size: 13.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Copy',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF26262B),
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
                      Divider(color: const Color(0xFFE2E8F0), height: 20.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Account Status',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF64748B),
                              fontSize: 12.sp,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: const Color(0xFF86EFAC),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Active ✓',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF16A34A),
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

                // Close Button (Silver Metallic Gradient)
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFFE5E7EB),
                            Color(0xFFB0B5C2),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFF9CA3AF),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Done',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF16161A),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
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

                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFDCFCE7),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: const Color(0xFF16A34A),
                    size: 44.sp,
                  ),
                ),

                SizedBox(height: 14.h),

                Text(
                  'account-deleted-title'.tr(),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 8.h),

                Text(
                  'account-deleted-message'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                SizedBox(height: 20.h),

                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFFE5E7EB),
                            Color(0xFFB0B5C2),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFF9CA3AF),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'OK',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF16161A),
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

  //! Confirm Logout Popup
  static Future<bool> showConfirmLogoutPopup(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
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
                  margin: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),

                // Danger Logout Icon Badge
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFEE2E2),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: const Color(0xFFDC2626),
                    size: 34.sp,
                  ),
                ),

                SizedBox(height: 16.h),

                Text(
                  'Logout',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                SizedBox(height: 8.h),

                Text(
                  'Are you sure you want to sign out of your account?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                SizedBox(height: 24.h),

                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, false);
                        },
                        child: Container(
                          height: 46.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF64748B),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Logout Button (Red Danger)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, true);
                        },
                        child: Container(
                          height: 46.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            'Yes, Logout',
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
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  //! App Close Popup
  static void showAppClosePopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),

              // Exit Icon Badge
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  Icons.exit_to_app_rounded,
                  color: const Color(0xFF26262B),
                  size: 34.sp,
                ),
              ),

              SizedBox(height: 16.h),

              Text(
                'Exit Application',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF26262B),
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),

              SizedBox(height: 8.h),

              Text(
                'Are you sure you want to exit the app?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF64748B),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),

              SizedBox(height: 24.h),

              Row(
                children: [
                  // Stay Button (White outline)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AutoRouter.of(context).maybePop();
                      },
                      child: Container(
                        height: 46.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          'No, Stay',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // Exit Button (Executive Silver Gradient)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        SystemNavigator.pop();
                      },
                      child: Container(
                        height: 46.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.white,
                              Color(0xFFE5E7EB),
                              Color(0xFFB0B5C2),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: const Color(0xFF9CA3AF),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          'Yes, Exit',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF16161A),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Drag Handle Bar
          Container(
            height: 4.5.h,
            width: 48.w,
            margin: EdgeInsets.only(bottom: 20.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),

          // 2. Large Bold Main Title
          Text(
            'Enjoying The App?',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontWeight: FontWeight.w700,
              fontSize: 22.sp,
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
                color: const Color(0xFF64748B),
                fontSize: 13.sp,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // 4. 5-Star Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final isSelected = index < _rating;
              return GestureDetector(
                onTap: () => _onStarTapped(index),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.30).animate(
                    CurvedAnimation(
                      parent: _controllers[index],
                      curve: Curves.bounceOut,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5.w),
                    child: Icon(
                      Icons.star_rounded,
                      color: isSelected
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFE2E8F0),
                      size: 46.sp,
                    ),
                  ),
                ),
              );
            }),
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
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 1,
                  ),
                ),
                child: Text(
                  _getRatingFeedbackText(_rating),
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFD97706),
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // 6. Action Button (Silver Metallic Executive Gradient)
          if (_rating > 0)
            _AnimatedBounceButton(
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
              child: Container(
                width: double.infinity,
                height: 48.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFE5E7EB),
                      Color(0xFFB0B5C2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFF9CA3AF),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _rating >= 4 ? 'RATE ON PLAY STORE ⭐' : 'SEND FEEDBACK 💬',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF16161A),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
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
    );
  }
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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

                // Device Illustration
                Container(
                  width: 88.w,
                  height: 88.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF8FAFC),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/icons/mobile-phone-with-touch-3d-icon-png-download-6293808 1.png',
                      width: 56.w,
                      height: 56.w,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.phonelink_lock_rounded,
                        size: 40.sp,
                        color: const Color(0xFF26262B),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

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
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
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
                  style: GoogleFonts.poppins(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF26262B),
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
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
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
                              color: const Color(0xFF26262B),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Linked Account on this Device',
                              style: GoogleFonts.poppins(
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
                                color: const Color(0xFFE2E8F0),
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
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF26262B),
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

                // Primary Silver Metallic Gradient Button: "Understood"
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
                        colors: [
                          Colors.white,
                          Color(0xFFE5E7EB),
                          Color(0xFFB0B5C2),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: const Color(0xFF9CA3AF),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Understood',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF16161A),
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
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
                          color: const Color(0xFF64748B),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Need Help? Contact Support',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
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
