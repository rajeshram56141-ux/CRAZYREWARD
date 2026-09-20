import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../utils/helper/helper.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../provider/dashboard_provider.dart';
import 'read_tsk_model.dart';
import 'read_tsk_provider.dart';

@RoutePage()
class ReadTskVerificationScreen extends HookConsumerWidget {
  const ReadTskVerificationScreen({
    super.key,
    required this.offer,
    required this.userId,
    required this.appName,
  });

  final ReadTskModel offer;
  final String userId;
  final String appName;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '30 sec';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0 && remainingSeconds > 0) {
      return '$minutes min $remainingSeconds sec';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$seconds sec';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTracking = useState(false);
    final clickTime = useState<DateTime?>(null);
    final isTimerCompleted = useState(false);
    final isVerifying = useState(false);
    final isVerifyPressed = useState(false);
    final urlController = useTextEditingController();
    final lifecycleState = useAppLifecycleState();

    useValueChanged<AppLifecycleState?, void>(lifecycleState, (oldState, _) {
      if (lifecycleState == null) return;

      if (isTracking.value &&
          lifecycleState == AppLifecycleState.resumed &&
          clickTime.value != null) {
        final secondsSpent = DateTime.now().difference(clickTime.value!).inSeconds;
        isTracking.value = false;

        Future.microtask(() {
          if (!context.mounted) return;

          if (secondsSpent >= offer.trackingTime) {
            isTimerCompleted.value = true;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('timer-completed-paste-url'.tr()),
                backgroundColor: const Color(0xFF7C3AED),
              ),
            );
          } else {
            CustomStatusPopup.showFailed(
              context: context,
              title: 'Task Incomplete',
              message: 'You returned early. Please read the article for full ${_formatDuration(offer.trackingTime)}.',
            );
          }
        });
      }
    });

    String cleanDomain(String input) {
      String cleaned = input.trim().toLowerCase();
      if (cleaned.startsWith('https://')) {
        cleaned = cleaned.substring(8);
      } else if (cleaned.startsWith('http://')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('www.')) {
        cleaned = cleaned.substring(4);
      }
      final slashIndex = cleaned.indexOf('/');
      if (slashIndex != -1) {
        cleaned = cleaned.substring(0, slashIndex);
      }
      return cleaned.trim();
    }

    bool verifyDomain(String pastedUrl, String targetUrl) {
      try {
        final pastedCleaned = cleanDomain(pastedUrl);
        if (pastedCleaned.isEmpty) return false;

        final targetDomain = cleanDomain(offer.verificationDomain);
        if (targetDomain.isNotEmpty) {
          return pastedCleaned == targetDomain || pastedCleaned.endsWith('.$targetDomain');
        }

        final targetCleaned = cleanDomain(targetUrl);
        if (targetCleaned.isNotEmpty) {
          final isTargetGoogle = targetCleaned == 'google.com' || targetCleaned.endsWith('.google.com');
          if (isTargetGoogle) {
            return pastedCleaned != 'google.com' && !pastedCleaned.endsWith('.google.com');
          }
          return pastedCleaned == targetCleaned || pastedCleaned.endsWith('.$targetCleaned');
        }
        return false;
      } catch (_) {
        return false;
      }
    }

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
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: Stack(
          children: [
            // 1. Main Scrollable Content
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              AutoRouter.of(context).maybePop();
                            },
                            child: Container(
                              width: 40.w,
                              height: 40.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15.r),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 22.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          const Spacer(),
                          // Coins Reward Pill
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons/coin.png',
                                  width: 14.w,
                                  height: 14.w,
                                  fit: BoxFit.contain,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '+${offer.coins.formatCoins()}',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFAB31DE),
                                    fontSize: 12.5.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 12.h),

                            // Top Hero Header: Icon + Title + Subtitle
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 60.w,
                                    height: 60.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFFAF5FF),
                                      border: Border.all(
                                        color: const Color(0xFFE9D5FF),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFAB31DE).withValues(alpha: 0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      'assets/icons/coin.png',
                                      width: 36.w,
                                      height: 36.w,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.monetization_on_rounded,
                                        color: const Color(0xFFAB31DE),
                                        size: 28.sp,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 10.h),
                                  Text(
                                    'How to Complete?',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF1E1B4B),
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Get +${offer.coins.formatCoins()} coins by following these steps:',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF64748B),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 20.h),

                            // 5 Steps List with Stepper Indicators
                            _buildStepItem(
                              stepNumber: 1,
                              title: 'Step 1: Tap Read Now',
                              description:
                                  'After clicking the button, Google or target site will open.',
                              isLast: false,
                            ),

                            _buildStepItem(
                              stepNumber: 2,
                              title: 'Step 2: Find the assigned article',
                              description:
                                  'Find the article with the title: "${offer.verificationTitle.isNotEmpty ? offer.verificationTitle : 'Assigned Article'}"',
                              isLast: false,
                            ),

                            _buildStepItem(
                              stepNumber: 3,
                              title: 'Step 3: Read for full duration',
                              description:
                                  'Open the article, scroll down, and read for ${_formatDuration(offer.trackingTime)}.',
                              isLast: false,
                            ),

                            _buildStepItem(
                              stepNumber: 4,
                              title: 'Step 4: Copy the article URL',
                              description:
                                  'Copy the address bar URL of the article from your browser.',
                              isLast: false,
                            ),

                            // Step 5: Paste and Verify
                            _buildStep5(
                              context: context,
                              ref: ref,
                              offer: offer,
                              userId: userId,
                              appName: appName,
                              urlController: urlController,
                              isVerifying: isVerifying,
                              isVerifyPressed: isVerifyPressed,
                              isTimerCompleted: isTimerCompleted,
                              verifyDomain: verifyDomain,
                            ),

                            SizedBox(height: 80.h),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Fixed Bottom Read Now Button (Transparent Background - No White Card Box Behind It)
            if (MediaQuery.of(context).viewInsets.bottom == 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.transparent,
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      isTracking.value = true;
                      clickTime.value = DateTime.now();
                      LaunchUrl.inWeb(url: offer.redirectionUrl, context: context);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 50.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                        ),
                        borderRadius: BorderRadius.circular(25.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Read Now',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Widget for Steps 1 - 4
  Widget _buildStepItem({
    required int stepNumber,
    required String title,
    required String description,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Indicator
          Column(
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFE39FFF),
                      Color(0xFFAB31DE),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$stepNumber',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.w,
                    color: const Color(0xFFE9D5FF),
                    margin: EdgeInsets.symmetric(vertical: 4.h),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          // Content Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFF3E8FF),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5.sp,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget for Step 5
  Widget _buildStep5({
    required BuildContext context,
    required WidgetRef ref,
    required ReadTskModel offer,
    required String userId,
    required String appName,
    required TextEditingController urlController,
    required ValueNotifier<bool> isVerifying,
    required ValueNotifier<bool> isVerifyPressed,
    required ValueNotifier<bool> isTimerCompleted,
    required bool Function(String, String) verifyDomain,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Indicator
          Column(
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFE39FFF),
                      Color(0xFFAB31DE),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '5',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          // Content Card with Input + Verify
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFF3E8FF),
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 5: Paste and Verify',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Paste the copied URL below and tap Verify.',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  // Input Box
                  Container(
                    height: 44.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFFE9D5FF),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 12.w),
                        Expanded(
                          child: TextField(
                            controller: urlController,
                            cursorColor: const Color(0xFFAB31DE),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'https://example.com/article...',
                              hintStyle: GoogleFonts.outfit(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11.5.sp,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null && data!.text!.trim().isNotEmpty) {
                              urlController.text = data.text!.trim();
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            margin: EdgeInsets.only(right: 6.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'PASTE',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFAB31DE),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Verify Button inside Step 5
                  GestureDetector(
                    onTap: () async {
                      if (isVerifying.value) return;

                      if (!isTimerCompleted.value) {
                        CustomStatusPopup.showFailed(
                          context: context,
                          title: 'Reading Incomplete',
                          message: 'Please tap "Read Now" below and read the article for full ${_formatDuration(offer.trackingTime)} before verifying.',
                        );
                        return;
                      }

                      final pasted = urlController.text.trim();
                      if (pasted.isEmpty) {
                        CustomStatusPopup.showFailed(
                          context: context,
                          title: 'URL Required',
                          message: 'Please paste the article webpage URL to verify.',
                        );
                        return;
                      }

                      final isValid = verifyDomain(pasted, offer.redirectionUrl);
                      if (!isValid) {
                        CustomStatusPopup.showFailed(
                          context: context,
                          title: 'Invalid URL',
                          message: 'The URL you entered does not match the assigned article domain.',
                        );
                        return;
                      }

                      isVerifying.value = true;
                      try {
                        final token = Uri.tryParse(offer.redirectionUrl)?.queryParameters['token'];
                        await ReadTskService.readTskPostback(
                          appName: appName,
                          userId: userId,
                          offerId: offer.offerId,
                          token: token,
                        );

                        ref.invalidate(readTskProvider((userId: userId, appName: appName)));
                        ref.invalidate(readTskHistoryProvider(userId));
                        ref.invalidate(DashboardService.userDataProvider(userId));

                        if (context.mounted) {
                          CustomStatusPopup.showSuccess(
                            context: context,
                            title: '${offer.coins.formatCoins()} Coins Claimed!',
                            message: 'Verification successful! Coins have been credited to your balance.',
                            onPrimaryTap: () {
                              Navigator.pop(context);
                              AutoRouter.of(context).maybePop();
                            },
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          CustomStatusPopup.showFailed(
                            context: context,
                            title: 'Verification Failed',
                            message: 'Unable to verify your task. Please try again.',
                          );
                        }
                      } finally {
                        isVerifying.value = false;
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 44.h,
                      decoration: BoxDecoration(
                        gradient: isTimerCompleted.value
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFE39FFF),
                                  Color(0xFFAB31DE),
                                ],
                              )
                            : null,
                        color: isTimerCompleted.value
                            ? null
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: isTimerCompleted.value
                              ? const Color(0xFFAB31DE)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isVerifying.value
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isTimerCompleted.value
                                      ? Icons.check_circle_rounded
                                      : Icons.lock_outline_rounded,
                                  color: isTimerCompleted.value
                                      ? Colors.white
                                      : const Color(0xFF94A3B8),
                                  size: 16.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  isTimerCompleted.value
                                      ? 'Verify & Claim Coins'
                                      : 'Verify (Read Article First)',
                                  style: GoogleFonts.outfit(
                                    color: isTimerCompleted.value
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w800,
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
        ],
      ),
    );
  }
}

