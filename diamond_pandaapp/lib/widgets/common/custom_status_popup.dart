import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/b_splash_stage/model.dart';
import '../../app/b_splash_stage/splash_service.dart';
import '../../services/launch_url.dart';
import 'internet_image.dart';

/// Supported Status Popup Types
enum StatusPopupType {
  success,
  failed,
  inProgress,
  warning,
  info,
  permission,
}

/// Universal Status Popup Dialog (Matching Luxury Center-Notched UI with Multi-Type Support)
class CustomStatusPopup extends StatelessWidget {
  const CustomStatusPopup({
    super.key,
    this.type = StatusPopupType.success,
    this.isSuccess,
    this.tag,
    this.title,
    this.message,
    this.customBody,
    this.centerIcon,
    this.orbSize,
    this.primaryButtonText,
    this.primaryButtonColor,
    this.primaryButtonGradient,
    this.onPrimaryTap,
    this.secondaryButtonText,
    this.onSecondaryTap,
    this.onClose,
  });

  final StatusPopupType type;
  final bool? isSuccess;
  final String? tag;
  final String? title;
  final String? message;
  final Widget? customBody;
  final Widget? centerIcon;
  final double? orbSize;
  final String? primaryButtonText;
  final Color? primaryButtonColor;
  final Gradient? primaryButtonGradient;
  final VoidCallback? onPrimaryTap;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onClose;

  StatusPopupType get resolvedType {
    if (isSuccess != null) {
      return isSuccess! ? StatusPopupType.success : StatusPopupType.failed;
    }
    return type;
  }

  /// 1. Static Helper: Universal show
  static Future<T?> show<T>({
    required BuildContext context,
    StatusPopupType type = StatusPopupType.success,
    bool? isSuccess,
    String? tag,
    String? title,
    String? message,
    Widget? customBody,
    Widget? centerIcon,
    double? orbSize,
    String? primaryButtonText,
    Color? primaryButtonColor,
    Gradient? primaryButtonGradient,
    VoidCallback? onPrimaryTap,
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
    VoidCallback? onClose,
    bool isDismissible = true,
  }) {
    if (!context.mounted) return Future.value(null);

    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.70),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: AnimatedPadding(
            padding: MediaQuery.of(ctx).viewInsets,
            duration: const Duration(milliseconds: 100),
            child: CustomStatusPopup(
              type: type,
              isSuccess: isSuccess,
              tag: tag,
              title: title,
              message: message,
              customBody: customBody,
              centerIcon: centerIcon,
              orbSize: orbSize,
              primaryButtonText: primaryButtonText,
              primaryButtonColor: primaryButtonColor,
              primaryButtonGradient: primaryButtonGradient,
              onPrimaryTap: onPrimaryTap,
              secondaryButtonText: secondaryButtonText,
              onSecondaryTap: onSecondaryTap,
              onClose: onClose,
            ),
          ),
        );
      },
    );
  }

  /// 2. Static Shortcut: Success Dialog
  static Future<T?> showSuccess<T>({
    required BuildContext context,
    String? tag = 'Congratulations',
    String title = 'Success!',
    String? message,
    Widget? customBody,
    String primaryButtonText = 'DONE',
    VoidCallback? onPrimaryTap,
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
    VoidCallback? onClose,
    bool isDismissible = true,
  }) {
    return show<T>(
      context: context,
      type: StatusPopupType.success,
      tag: tag,
      title: title,
      message: message,
      customBody: customBody,
      primaryButtonText: primaryButtonText,
      onPrimaryTap: onPrimaryTap,
      secondaryButtonText: secondaryButtonText,
      onSecondaryTap: onSecondaryTap,
      onClose: onClose,
      isDismissible: isDismissible,
    );
  }

  /// 3. Static Shortcut: Failed / Incomplete Dialog
  static Future<T?> showFailed<T>({
    required BuildContext context,
    String? tag = 'Oops!',
    String title = 'Failed!',
    String? message,
    Widget? customBody,
    String primaryButtonText = 'TRY LATER',
    VoidCallback? onPrimaryTap,
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
    VoidCallback? onClose,
    bool isDismissible = true,
  }) {
    return show<T>(
      context: context,
      type: StatusPopupType.failed,
      tag: tag,
      title: title,
      message: message,
      customBody: customBody,
      primaryButtonText: primaryButtonText,
      onPrimaryTap: onPrimaryTap,
      secondaryButtonText: secondaryButtonText,
      onSecondaryTap: onSecondaryTap,
      onClose: onClose,
      isDismissible: isDismissible,
    );
  }

  /// 4. Static Shortcut: In Progress / Processing / Pending Dialog
  static Future<T?> showInProgress<T>({
    required BuildContext context,
    String? tag = 'Please Wait',
    String title = 'Processing...',
    String? message = 'Your request is in progress. Please check back shortly.',
    Widget? customBody,
    String primaryButtonText = 'GOT IT',
    VoidCallback? onPrimaryTap,
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
    VoidCallback? onClose,
    bool isDismissible = true,
  }) {
    return show<T>(
      context: context,
      type: StatusPopupType.inProgress,
      tag: tag,
      title: title,
      message: message,
      customBody: customBody,
      primaryButtonText: primaryButtonText,
      onPrimaryTap: onPrimaryTap,
      secondaryButtonText: secondaryButtonText,
      onSecondaryTap: onSecondaryTap,
      onClose: onClose,
      isDismissible: isDismissible,
    );
  }

  /// 5. Static Shortcut: Coming Soon / Under Development Dialog
  static Future<T?> showComingSoon<T>({
    required BuildContext context,
    String? tag = 'Stay Tuned',
    String title = 'Coming Soon!',
    String? message = 'This feature is currently under active development and will be available very soon.',
    Widget? customBody,
    String primaryButtonText = 'GOT IT',
    VoidCallback? onPrimaryTap,
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
    VoidCallback? onClose,
    bool isDismissible = true,
  }) {
    return show<T>(
      context: context,
      type: StatusPopupType.info,
      tag: tag,
      title: title,
      message: message,
      customBody: customBody,
      centerIcon: const Icon(
        Icons.rocket_launch_rounded,
        color: Colors.white,
        size: 34,
      ),
      primaryButtonText: primaryButtonText,
      onPrimaryTap: onPrimaryTap,
      secondaryButtonText: secondaryButtonText,
      onSecondaryTap: onSecondaryTap,
      onClose: onClose,
      isDismissible: isDismissible,
    );
  }

  /// 5. Static Shortcut: Warning / Notice Dialog
  static Future<T?> showWarning<T>({
    required BuildContext context,
    String? tag = 'Attention',
    String title = 'Notice!',
    String? message,
    Widget? customBody,
    String primaryButtonText = 'OK, GOT IT',
    Color? primaryButtonColor,
    VoidCallback? onPrimaryTap,
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
    VoidCallback? onClose,
    bool isDismissible = true,
  }) {
    return show<T>(
      context: context,
      type: StatusPopupType.warning,
      tag: tag,
      title: title,
      message: message,
      customBody: customBody,
      primaryButtonText: primaryButtonText,
      primaryButtonColor: primaryButtonColor,
      onPrimaryTap: onPrimaryTap,
      secondaryButtonText: secondaryButtonText,
      onSecondaryTap: onSecondaryTap,
      onClose: onClose,
      isDismissible: isDismissible,
    );
  }

  /// 6. Static Shortcut: Info Dialog
  static Future<T?> showInfo<T>({
    required BuildContext context,
    String? tag = 'Information',
    String title = 'Did you know?',
    String? message,
    Widget? customBody,
    String primaryButtonText = 'UNDERSTOOD',
    VoidCallback? onPrimaryTap,
    String? secondaryButtonText,
    VoidCallback? onSecondaryTap,
    VoidCallback? onClose,
    bool isDismissible = true,
  }) {
    return show<T>(
      context: context,
      type: StatusPopupType.info,
      tag: tag,
      title: title,
      message: message,
      customBody: customBody,
      primaryButtonText: primaryButtonText,
      onPrimaryTap: onPrimaryTap,
      secondaryButtonText: secondaryButtonText,
      onSecondaryTap: onSecondaryTap,
      onClose: onClose,
      isDismissible: isDismissible,
    );
  }

  /// 7. Static Shortcut: App Usage Access Permission Dialog (Matching Signature Luxury Center-Notched Card UI with DBCCFF/FFFFFF Colors)
  static Future<bool> showUsagePermission({
    required BuildContext context,
    required VoidCallback onAllow,
    VoidCallback? onDeny,
  }) async {
    if (!context.mounted) return false;

    bool allowed = false;
    await show<void>(
      context: context,
      type: StatusPopupType.permission,
      tag: 'Permission Needed',
      title: 'Allow App usage',
      message:
          'To verify your progress and reward eligibility, please allow usage access permission',
      orbSize: 76.w,
      centerIcon: Center(
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.bolt_rounded,
            color: const Color(0xFFFDE047),
            size: 26.sp,
          ),
        ),
      ),
      primaryButtonText: 'ALLOW',
      onPrimaryTap: () {
        allowed = true;
        onAllow();
      },
      secondaryButtonText: 'Deny',
      onSecondaryTap: () {
        if (onDeny != null) onDeny();
      },
      onClose: onDeny,
      isDismissible: true,
    );

    return allowed;
  }

  /// 8. Static Shortcut: Confirm Logout Dialog (Matching User Reference Mockup 1-to-1)
  static Future<bool> showConfirmLogout({
    required BuildContext context,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) async {
    if (!context.mounted) return false;

    bool confirmed = false;
    await show<void>(
      context: context,
      type: StatusPopupType.warning,
      tag: null,
      title: 'Logout',
      message: 'Are you sure you want to logout from our account',
      orbSize: 76.w,
      centerIcon: Icon(
        Icons.logout_rounded,
        color: const Color(0xFFFF4757),
        size: 32.sp,
      ),
      primaryButtonText: 'Logout',
      onPrimaryTap: () {
        confirmed = true;
        if (onConfirm != null) onConfirm();
      },
      secondaryButtonText: 'Cancel',
      onSecondaryTap: () {
        confirmed = false;
        if (onCancel != null) onCancel();
      },
      onClose: () {
        confirmed = false;
        if (onCancel != null) onCancel();
      },
      isDismissible: true,
    );

    return confirmed;
  }

  /// 9. Static Shortcut: Confirm Delete Account Dialog (Matching User Reference Mockup 1-to-1)
  static Future<bool> showConfirmDeleteAccount({
    required BuildContext context,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) async {
    if (!context.mounted) return false;

    bool confirmed = false;
    await show<void>(
      context: context,
      type: StatusPopupType.warning,
      tag: null,
      title: 'Delete Account?',
      message:
          'Are you sure you want to permanently delete your account? All progress & balance will be lost.',
      orbSize: 76.w,
      centerIcon: Icon(
        Icons.delete_forever_rounded,
        color: const Color(0xFFFF4757),
        size: 34.sp,
      ),
      primaryButtonText: 'Delete',
      onPrimaryTap: () {
        confirmed = true;
        if (onConfirm != null) onConfirm();
      },
      secondaryButtonText: 'Cancel',
      onSecondaryTap: () {
        confirmed = false;
        if (onCancel != null) onCancel();
      },
      onClose: () {
        confirmed = false;
        if (onCancel != null) onCancel();
      },
      isDismissible: true,
    );

    return confirmed;
  }

  /// 10. Static Shortcut: Exit App Dialog (Matching Signature Luxury Center-Notched Card UI with DBCCFF/FFFFFF Colors)
  static Future<bool> showAppExit({
    required BuildContext context,
    VoidCallback? onExit,
    VoidCallback? onStay,
  }) async {
    if (!context.mounted) return false;

    bool willExit = false;
    await show<void>(
      context: context,
      type: StatusPopupType.permission,
      tag: 'Leaving So Soon?',
      title: 'Exit App?',
      message: 'Are you sure you want to close and exit the application?',
      orbSize: 76.w,
      centerIcon: Center(
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.power_settings_new_rounded,
            color: const Color(0xFFFDE047),
            size: 26.sp,
          ),
        ),
      ),
      primaryButtonText: 'EXIT NOW',
      onPrimaryTap: () {
        willExit = true;
        if (onExit != null) {
          onExit();
        } else {
          SystemNavigator.pop();
        }
      },
      secondaryButtonText: 'Cancel',
      onSecondaryTap: () {
        willExit = false;
        if (onStay != null) onStay();
      },
      onClose: () {
        willExit = false;
        if (onStay != null) onStay();
      },
      isDismissible: true,
    );

    return willExit;
  }

  /// 11. Static Shortcut: Disclaimer & Policy Disclosure Dialog (Matching Signature Luxury Center-Notched Card UI with DBCCFF/FFFFFF Colors)
  static Future<bool> showDisclosure(BuildContext context) async {
    if (!context.mounted) return false;

    bool accepted = false;
    await show<void>(
      context: context,
      type: StatusPopupType.permission,
      tag: null,
      title: 'Terms & Conditions',
      orbSize: 76.w,
      centerIcon: Center(
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFAB31DE).withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.description_rounded,
            color: const Color(0xFFAB31DE),
            size: 24.sp,
          ),
        ),
      ),
      customBody: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'By continuing, you acknowledge that rewards, tasks, and games are strictly intended for entertainment and follow all applicable guidelines.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF475569),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => LaunchUrl.inWeb(
                    url: SplashService.urlConfig.privacyPolicy,
                    context: context,
                  ),
                  child: Text(
                    'Privacy Policy',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFAB31DE),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFFAB31DE),
                    ),
                  ),
                ),
                Container(
                  width: 1.2,
                  height: 14.h,
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.4),
                ),
                GestureDetector(
                  onTap: () => LaunchUrl.inWeb(
                    url: SplashService.urlConfig.termsOfService,
                    context: context,
                  ),
                  child: Text(
                    'Terms of Service',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFAB31DE),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFFAB31DE),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      primaryButtonText: 'CONTINUE',
      onPrimaryTap: () {
        accepted = true;
      },
      secondaryButtonText: 'Decline',
      onSecondaryTap: () {
        accepted = false;
      },
      onClose: () {
        accepted = false;
      },
      isDismissible: true,
    );

    return accepted;
  }

  static Future<bool> showGuestDisclosure(BuildContext context) async {
    if (!context.mounted) return false;

    bool accepted = false;
    await show<void>(
      context: context,
      type: StatusPopupType.permission,
      tag: null,
      title: 'Guest Account Notice',
      orbSize: 76.w,
      centerIcon: Center(
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFAB31DE).withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.explore_rounded,
            color: const Color(0xFFAB31DE),
            size: 24.sp,
          ),
        ),
      ),
      customBody: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'A Guest account is only for exploration. Since it is a temporary account, your progress, coins, and rewards are not securely saved and can be lost if you clear app cache, uninstall the app, or change devices.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF475569),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'To securely save your actual data and rewards, we highly recommend signing in with Google.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFFAB31DE),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
      ),
      primaryButtonText: 'CONTINUE GUEST',
      onPrimaryTap: () {
        accepted = true;
      },
      secondaryButtonText: 'CANCEL',
      onSecondaryTap: () {
        accepted = false;
      },
      onClose: () {
        accepted = false;
      },
      isDismissible: true,
    );

    return accepted;
  }

  /// 12. Static Shortcut: Welcome Popup Dialog (Matching Signature Exit/Logout Luxury Center-Notched UI)
  static Future<void> showWelcomePopup({
    required BuildContext context,
    required WelcomePopupConfig welcomePopup,
    required String userId,
  }) {
    if (!context.mounted) return Future.value(null);

    return show<void>(
      context: context,
      type: StatusPopupType.permission,
      tag: 'WELCOME NOTICE',
      title: welcomePopup.title,
      message: welcomePopup.message,
      customBody: welcomePopup.imageUrl.isNotEmpty
          ? Container(
              height: 160.h,
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 14.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFDBCCFF).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  InternetImage(
                    url: welcomePopup.imageUrl,
                    height: 160.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFF0F172A).withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
      orbSize: 76.w,
      centerIcon: Center(
        child: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.card_giftcard_rounded,
            color: const Color(0xFFFDE047),
            size: 24.sp,
          ),
        ),
      ),
      primaryButtonText: welcomePopup.buttonName.isNotEmpty
          ? welcomePopup.buttonName
          : 'CONTINUE',
      onPrimaryTap: () {
        Navigator.of(context, rootNavigator: true).pop();
        if (welcomePopup.buttonClickUrl.isNotEmpty) {
          String finalUrl = welcomePopup.buttonClickUrl;
          if (finalUrl.contains('{UserId}')) {
            finalUrl = finalUrl.replaceAll('{UserId}', userId);
          }
          if (finalUrl.contains('{userId}')) {
            finalUrl = finalUrl.replaceAll('{userId}', userId);
          }
          LaunchUrl.inWeb(url: finalUrl, context: context);
        }
      },
      secondaryButtonText: null, // Removed Close button as requested
      onSecondaryTap: null,
      isDismissible: true,
    );
  }

  /// 12. Static Shortcut: Finish To Unlock / Instructions Dialog with Steps & Actions
  static Future<T?> showFinishToUnlock<T>({
    required BuildContext context,
    String? tag = 'Super Mission',
    String title = 'Finish To Unlock',
    String? description,
    List<String>? steps,
    String primaryButtonText = 'WATCH AD',
    IconData primaryButtonIcon = Icons.play_circle_fill_rounded,
    VoidCallback? onHowTo,
    Future<void> Function(BuildContext dialogContext)? onWatchAd,
    VoidCallback? onClose,
    bool isDismissible = false,
  }) {
    if (!context.mounted) return Future.value(null);

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.80),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (dialogContext, anim1, anim2) {
        bool isAdLoading = false;
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  EdgeInsets.symmetric(horizontal: 22.w, vertical: 24.h),
              child: CustomStatusPopup(
                type: StatusPopupType.success,
                tag: tag,
                title: title,
                orbSize: 76.w,
                centerIcon: Center(
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.lock_open_rounded,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ),
                ),
                customBody: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (description != null && description.isNotEmpty) ...[
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5.sp,
                          color: const Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 14.h),
                    ],
                    if (steps != null) ...[
                      for (int i = 0; i < steps.length; i++)
                        _buildStepCard('${i + 1}', steps[i]),
                    ],
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        // 1. HOW TO ? BUTTON
                        if (onHowTo != null) ...[
                          Expanded(
                            flex: 2,
                            child: _PopScaleButton(
                              onTap: onHowTo,
                              child: Container(
                                height: 48.h,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF140F2D),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.50),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7C3AED)
                                          .withValues(alpha: 0.20),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.help_outline_rounded,
                                      color: const Color(0xFFDDD6FE),
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      'HOW TO ?',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFDDD6FE),
                                        fontSize: 12.5.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                        ],
                        // 2. WATCH AD BUTTON
                        Expanded(
                          flex: 3,
                          child: _PopScaleButton(
                            onTap: isAdLoading || onWatchAd == null
                                ? () {}
                                : () async {
                                    setStateSheet(() {
                                      isAdLoading = true;
                                    });
                                    try {
                                      await onWatchAd(dialogContext);
                                    } finally {
                                      if (dialogContext.mounted) {
                                        setStateSheet(() {
                                          isAdLoading = false;
                                        });
                                      }
                                    }
                                  },
                            child: Container(
                              width: double.infinity,
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFAB31DE),
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Center(
                                child: isAdLoading
                                    ? SizedBox(
                                        height: 18.w,
                                        width: 18.w,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8.w),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                primaryButtonIcon,
                                                color: Colors.white,
                                                size: 18.sp,
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                primaryButtonText,
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                primaryButtonText: '',
                onClose: onClose,
              ),
            );
          },
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );

        return ScaleTransition(
          alignment: Alignment.center,
          scale: Tween<double>(begin: 0.2, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: anim,
              curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  static Widget _buildStepCard(String index, String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF140F2D),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFBA4FFF).withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFA855F7), Color(0xFF7E10C8)],
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              index,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: const Color(0xFFE2E8F0),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final curType = resolvedType;

    // Palette per status type matching user reference image 1-to-1
    final Color iconBgLight;
    final Color iconBgInner;
    final Color iconColor;
    final IconData iconData;
    Color primaryBtnColor;
    final String defaultTag;
    final String defaultTitle;
    final String defaultButtonText;

    switch (curType) {
      case StatusPopupType.success:
        iconBgLight = const Color(0xFFF0FDF4); // Softest green
        iconBgInner = const Color(0xFFDCFCE7); // Light green ring
        iconColor = const Color(0xFF22C55E); // Green checkmark
        iconData = Icons.check_rounded;
        primaryBtnColor = const Color(0xFF22C55E);
        defaultTag = '';
        defaultTitle = 'Success!';
        defaultButtonText = 'Continue';
        break;

      case StatusPopupType.failed:
        iconBgLight = const Color(0xFFFEF2F2); // Softest red
        iconBgInner = const Color(0xFFFEE2E2); // Light red ring
        iconColor = const Color(0xFFEF4444); // Red cross
        iconData = Icons.close_rounded;
        primaryBtnColor = const Color(0xFFEF4444);
        defaultTag = '';
        defaultTitle = 'Error!';
        defaultButtonText = 'Try Again';
        break;

      case StatusPopupType.inProgress:
        iconBgLight = const Color(0xFFFFFBEB); // Softest amber
        iconBgInner = const Color(0xFFFEF3C7); // Light amber ring
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.hourglass_top_rounded;
        primaryBtnColor = const Color(0xFFF59E0B);
        defaultTag = '';
        defaultTitle = 'Processing...';
        defaultButtonText = 'Got It';
        break;

      case StatusPopupType.warning:
        iconBgLight = const Color(0xFFFEF2F2); // Soft pink/red
        iconBgInner = const Color(0xFFFEE2E2);
        iconColor = const Color(0xFFEF4444); // Red warning !
        iconData = Icons.priority_high_rounded;
        primaryBtnColor = const Color(0xFFEF4444);
        defaultTag = '';
        defaultTitle = 'Confirm Action?';
        defaultButtonText = 'Confirm';
        break;

      case StatusPopupType.info:
      case StatusPopupType.permission:
        iconBgLight = const Color(0xFFFAF5FF); // Soft lavender
        iconBgInner = const Color(0xFFF3E8FF);
        iconColor = const Color(0xFFAB31DE);
        iconData = Icons.info_outline_rounded;
        primaryBtnColor = const Color(0xFFAB31DE);
        defaultTag = '';
        defaultTitle = 'Notice';
        defaultButtonText = 'Understand';
        break;
    }

    if (primaryButtonColor != null) {
      primaryBtnColor = primaryButtonColor!;
    }

    final effectiveTag = tag ?? defaultTag;
    final effectiveTitle = title ?? defaultTitle;
    final effectiveButtonText = primaryButtonText ?? defaultButtonText;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: Stack(
          children: [
            // Top Right Close (X) Button
            Positioned(
              top: 14.h,
              right: 14.w,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final navigator = Navigator.of(context);
                  final modalRoute = ModalRoute.of(context);
                  if (onClose != null) {
                    onClose!();
                  }
                  if (navigator.mounted && modalRoute != null && modalRoute.isCurrent && navigator.canPop()) {
                    navigator.pop();
                  }
                },
                child: Container(
                  width: 32.w,
                  height: 32.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20.sp,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 20.h + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Center Glowing Icon Orb Aura (Matching mockup 1-to-1)
                  centerIcon ??
                      Container(
                        width: orbSize ?? 80.w,
                        height: orbSize ?? 80.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconBgLight,
                        ),
                        padding: EdgeInsets.all(8.w),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconBgInner,
                          ),
                          child: Icon(
                            iconData,
                            color: iconColor,
                            size: 38.sp,
                          ),
                        ),
                      ),

                  SizedBox(height: 16.h),

                  // 2. Tag / Subtitle (if present)
                  if (effectiveTag.isNotEmpty) ...[
                    Text(
                      effectiveTag,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 4.h),
                  ],

                  // 3. Main Title Text
                  Text(
                    effectiveTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),

                  // 4. Description Message (if present)
                  if (message != null && message!.isNotEmpty) ...[
                    SizedBox(height: 6.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  // 5. Custom Body Widget (if present)
                  if (customBody != null) ...[
                    SizedBox(height: 12.h),
                    customBody!,
                  ],

                  SizedBox(height: 20.h),

                  // 6. Action Buttons Row (Dual Side-by-Side vs Single Full Width)
                  if (secondaryButtonText != null && secondaryButtonText!.isNotEmpty) ...[
                    Row(
                      children: [
                        // Secondary / Cancel Button (White with subtle border)
                        Expanded(
                          child: _PopScaleButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final navigator = Navigator.of(context);
                              final modalRoute = ModalRoute.of(context);
                              if (onSecondaryTap != null) {
                                onSecondaryTap!();
                              }
                              if (navigator.mounted && modalRoute != null && modalRoute.isCurrent && navigator.canPop()) {
                                navigator.pop();
                              }
                            },
                            child: Container(
                              height: 46.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              ),
                              child: Text(
                                secondaryButtonText!,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 12.w),

                        // Primary / Confirm Button (Solid Vibrant Color)
                        Expanded(
                          child: _PopScaleButton(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final navigator = Navigator.of(context);
                              final modalRoute = ModalRoute.of(context);
                              if (onPrimaryTap != null) {
                                onPrimaryTap!();
                              }
                              if (navigator.mounted && modalRoute != null && modalRoute.isCurrent && navigator.canPop()) {
                                navigator.pop();
                              }
                            },
                            child: Container(
                              height: 46.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primaryButtonGradient == null ? primaryBtnColor : null,
                                gradient: primaryButtonGradient,
                                borderRadius: BorderRadius.circular(14.r),
                                boxShadow: primaryButtonGradient != null
                                    ? [
                                        BoxShadow(
                                          color: (primaryButtonColor ?? const Color(0xFFAB31DE)).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                effectiveButtonText,
                                style: GoogleFonts.outfit(
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
                  ] else if (effectiveButtonText.isNotEmpty) ...[
                    // Single Full Width Action Button
                    _PopScaleButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final navigator = Navigator.of(context);
                        final modalRoute = ModalRoute.of(context);
                        if (onPrimaryTap != null) {
                          onPrimaryTap!();
                        }
                        if (navigator.mounted && modalRoute != null && modalRoute.isCurrent && navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 46.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryButtonGradient == null ? primaryBtnColor : null,
                          gradient: primaryButtonGradient,
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: primaryButtonGradient != null
                              ? [
                                  BoxShadow(
                                    color: (primaryButtonColor ?? const Color(0xFFAB31DE)).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          effectiveButtonText,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopScaleButton extends StatefulWidget {
  const _PopScaleButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
