import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/ad_manager.dart';
import '../../../../../services/cloud_functions.dart';
import '../../../../../services/launch_url.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../widgets/common/custom_toast.dart';
import '../../../provider/dashboard_provider.dart';
import 'super_offer_step2_list_screen.dart';
import 'super_offer_native_manager.dart';
import 'super_offer_provider.dart';
import 'super_offer_widget.dart';

class SuperOfferStep1Screen extends HookConsumerWidget {
  const SuperOfferStep1Screen({
    super.key,
    required this.userId,
    required this.coins,
    required this.gemsRequired,
    this.packageName,
    this.targetSeconds = 120, // 2 minutes
  });

  final String userId;
  final int coins;
  final int gemsRequired;
  final String? packageName;
  final int targetSeconds;

  static const String _step1StorageKey = 'super_offer_step1_in_progress';

  static Map<String, dynamic>? getSavedStep1(String userId) {
    try {
      final box = GetStorage();
      final data = box.read('${_step1StorageKey}_$userId');
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static void saveStep1(String userId, Map<String, dynamic> data) {
    try {
      final box = GetStorage();
      box.write('${_step1StorageKey}_$userId', data);
    } catch (_) {}
  }

  static void clearStep1(String userId) {
    try {
      final box = GetStorage();
      box.remove('${_step1StorageKey}_$userId');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedStep1 = useMemoized(() => getSavedStep1(userId), [userId]);

    useEffect(() {
      AdManager().preloadRewarded();
      return null;
    }, const []);

    final isTracking = useState(false);
    final clickTime = useState<DateTime?>(null);
    final isAdLoading = useState(false);
    final isInstalled = useState<bool>(savedStep1 != null && savedStep1['isInstalled'] == true);
    final usedSeconds = useState<int>(0);
    final isAdWatched = useState<bool>(savedStep1 != null);
    final isDialogShowing = useRef(false);

    final lifecycleState = useAppLifecycleState();
    final initialStartMs = savedStep1?['startTimeMs'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final startTimeMs = useRef<int>(initialStartMs);

    final tutorialUrl =
        SplashService.superOfferConfig['tutorialUrl']?.toString() ?? '';

    final configPkg = SplashService.superOfferConfig['packageName']?.toString().trim() ?? '';
    final initialPkg = (packageName != null && packageName!.isNotEmpty)
        ? packageName!
        : (savedStep1?['packageName']?.toString() ?? configPkg);
    final activePkg = useState<String>(initialPkg);

    // Check & update app usage duration (ONLY for actual target app usage)
    final updateUsage = useCallback(() async {
      final pkg = activePkg.value.trim();
      if (pkg.isNotEmpty) {
        final hasPerm = await SuperOfferNativeManager.checkUsagePermission();
        if (hasPerm) {
          int startMs = startTimeMs.value;
          if (startMs <= 0) {
            final saved = getSavedStep1(userId);
            startMs = saved?['startTimeMs'] as int? ?? DateTime.now().millisecondsSinceEpoch;
            startTimeMs.value = startMs;
          }
          final sec = await SuperOfferNativeManager.getAppUsageDuration(
            pkg,
            startMs,
          );
          if (sec > usedSeconds.value) {
            usedSeconds.value = sec;
          }
        }
      }
    }, [activePkg.value, userId]);

    // Check real app installation status (only after user starts the task)
    final checkInstallStatus = useCallback(() async {
      if (!isAdWatched.value && savedStep1 == null) return;

      int startMs = startTimeMs.value;
      if (startMs <= 0) {
        final saved = getSavedStep1(userId);
        startMs = saved?['startTimeMs'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        startTimeMs.value = startMs;
      }

      // 1. Check if a brand new app was installed on device after clicking Watch Ad
      final recentPkg = await SuperOfferNativeManager.getRecentlyInstalledPackage(
        startMs - 5000,
      );
      if (recentPkg != null && recentPkg.isNotEmpty) {
        activePkg.value = recentPkg;
        isInstalled.value = true;
        saveStep1(userId, {
          'packageName': recentPkg,
          'isInstalled': true,
          'startTimeMs': startMs,
        });
        return;
      }

      // 2. If a specific package name was strictly configured by Admin in backend:
      if (configPkg.isNotEmpty) {
        final installed = await SuperOfferNativeManager.isAppInstalled(configPkg);
        if (installed) {
          activePkg.value = configPkg;
          isInstalled.value = true;
          saveStep1(userId, {
            'packageName': configPkg,
            'isInstalled': true,
            'startTimeMs': startMs,
          });
          return;
        }
      }
    }, [configPkg, isAdWatched.value, savedStep1, userId]);

    Future<void> showTaskNotCompletedPopup() async {
      if (isDialogShowing.value) return;
      isDialogShowing.value = true;
      
      await Future.delayed(const Duration(milliseconds: 350));
      if (!context.mounted) {
        isDialogShowing.value = false;
        return;
      }

      try {
        await CustomStatusPopup.showFailed(
          context: context,
          tag: 'Oops!',
          title: 'Task Not Completed!',
          message: 'App not installed! Please install the app and open it to complete the task.',
          primaryButtonText: 'TRY AGAIN',
        );
      } catch (_) {
      } finally {
        isDialogShowing.value = false;
      }
    }

    useEffect(() {
      checkInstallStatus();
      if (isInstalled.value) {
        updateUsage();
        final timer = Timer.periodic(const Duration(seconds: 2), (_) {
          updateUsage();
        });
        return timer.cancel;
      }
      return null;
    }, [isInstalled.value]);

    useValueChanged<AppLifecycleState?, void>(lifecycleState, (_, __) async {
      if (lifecycleState == AppLifecycleState.resumed) {
        await checkInstallStatus();
        if (isAdWatched.value && !isInstalled.value) {
          isAdWatched.value = false;
          await showTaskNotCompletedPopup();
        }
      }

      if (isInstalled.value && lifecycleState == AppLifecycleState.resumed) {
        updateUsage();
      }
    });

    final configReward = (SplashService.superOfferConfig['reward'] as num?)?.toInt() ??
        int.tryParse(SplashService.superOfferConfig['reward']?.toString() ?? '');
    final effectiveCoins = (configReward != null && configReward > 0) ? configReward : coins;

    final configSeconds = (SplashService.superOfferConfig['initialUsageSeconds'] as num?)?.toInt() ??
        int.tryParse(SplashService.superOfferConfig['initialUsageSeconds']?.toString() ?? '');
    final effectiveTargetSeconds = (configSeconds != null && configSeconds > 0) ? configSeconds : targetSeconds;

    final durationText = (effectiveTargetSeconds % 60 == 0)
        ? '${effectiveTargetSeconds ~/ 60} minutes'
        : '$effectiveTargetSeconds seconds';

    final isClaiming = useState(false);

    Future<void> handleClaimAndNavigate() async {
      if (isClaiming.value) return;
      if (!isInstalled.value) {
        await showTaskNotCompletedPopup();
        return;
      }
      if (usedSeconds.value < effectiveTargetSeconds) {
        CustomStatusPopup.showFailed(
          context: context,
          tag: 'Oops!',
          title: 'Task Incomplete!',
          message: 'Please open and use the installed app for at least $durationText before claiming.',
          primaryButtonText: 'OK, GOT IT',
        );
        return;
      }

      HapticFeedback.heavyImpact();
      isClaiming.value = true;
      try {
        var pkg = activePkg.value.trim();
        if (pkg.isEmpty) {
          final saved = getSavedStep1(userId);
          if (saved != null && saved['packageName'] != null) {
            pkg = saved['packageName'].toString().trim();
          }
        }
        if (pkg.isEmpty) {
          final recent = await SuperOfferNativeManager.getRecentlyInstalledPackage(
            startTimeMs.value - 60000,
          );
          if (recent != null && recent.isNotEmpty) {
            pkg = recent;
          }
        }
        final resolvedName = pkg.isNotEmpty ? (await SuperOfferNativeManager.getAppName(pkg)) : null;
        final actualName = (resolvedName != null && resolvedName.isNotEmpty)
            ? resolvedName
            : (SplashService.superOfferConfig['appName']?.toString() ?? 'Super Offer App');
        final bool isVerificationEnabled =
            SplashService.superOfferConfig['superOfferVerificationEnabled'] != false;
        final bool isScreenshotEnabled = isVerificationEnabled &&
            (SplashService.superOfferConfig['screenshotVerificationEnabled'] != false);

        if (isVerificationEnabled) {
          SuperOfferStep2ListScreen.saveOffer(userId, {
            'packageName': pkg,
            'appName': actualName,
            'coins': effectiveCoins,
            'installTimeText': 'Installed just now',
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'step1Claimed': true,
            'proofSubmitted': !isScreenshotEnabled,
            'proofStatus': isScreenshotEnabled ? 'not_submitted' : 'approved',
            'isVerificationEnabled': true,
            'configSnapshot': SplashService.superOfferConfig,
          });
          // If screenshot proof is enabled, keep isOfferUnlocked = true until proof submitted
          SuperOfferWidget.setOfferUnlocked(userId, isScreenshotEnabled);
        } else {
          SuperOfferStep2ListScreen.removeOffer(userId, pkg);
          SuperOfferWidget.setOfferUnlocked(userId, false);
        }

        if (!isScreenshotEnabled) {
          SuperOfferWidget.recordClaimTs(userId);
        } else {
          SuperOfferWidget.clearClaimTs(userId);
        }
        await CloudFunctions.claimSuperOffer(
          effectiveCoins,
          0,
          userId: userId,
          packageName: pkg,
          appName: actualName,
        );
        clearStep1(userId);
        if (!isVerificationEnabled) {
          SuperOfferStep2ListScreen.removeOffer(userId, pkg);
        }
        ref.invalidate(DashboardService.userDataProvider(userId));
        ref.invalidate(superOfferVerifierProvider(userId));
        ref.invalidate(pendingOffersProvider(userId));

        if (context.mounted) {
          if (!isVerificationEnabled) {
            CustomToast.showToast(
              context,
              msg: '+$effectiveCoins Coins claimed successfully!',
            );
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SuperOfferStep2ListScreen(
                  userId: userId,
                  coins: effectiveCoins,
                  packageName: pkg,
                  appName: actualName,
                  installTimeText: 'Installed just now',
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          final errText = e.toString().replaceAll('Exception: ', '').trim();
          CustomToast.showToast(
            context,
            msg: errText.isNotEmpty ? errText : 'Failed to claim reward. Please try again.',
          );
        }
      } finally {
        isClaiming.value = false;
      }
    }

    Future<void> handleWatchAd() async {
      if (isAdLoading.value) return;

      final hasPermission = await SuperOfferNativeManager.checkUsagePermission();
      if (!hasPermission) {
        if (!context.mounted) return;
        await CustomStatusPopup.showUsagePermission(
          context: context,
          onAllow: () async {
            await SuperOfferNativeManager.openUsageSettings();
          },
        );
        return;
      }

      activePkg.value = configPkg;
      isInstalled.value = false;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      startTimeMs.value = nowMs;
      usedSeconds.value = 0;
      isAdLoading.value = true;
      isAdWatched.value = true;
      saveStep1(userId, {
        'packageName': configPkg,
        'isInstalled': false,
        'startTimeMs': nowMs,
      });
      try {
        if (!context.mounted) return;
        await AdManager().showRewardedAd(
          context: context,
          onReward: () async {},
          onAdClicked: () async {
            isTracking.value = true;
            clickTime.value = DateTime.now();
          },
          onAdClosed: (bool success) async {
            await checkInstallStatus();
            if (!isInstalled.value) {
              await showTaskNotCompletedPopup();
            }
          },
          onAdFailed: () {
            if (context.mounted) {
              CustomToast.showToast(
                context,
                msg: 'Ad failed to load. Please check internet and try again.',
              );
            }
          },
        );
      } catch (e) {
        if (context.mounted) {
          CustomToast.showToast(
            context,
            msg: 'Failed to load advertisement. Please try again.',
          );
        }
      } finally {
        isAdLoading.value = false;
      }
    }

    final progressRatio = (usedSeconds.value / effectiveTargetSeconds).clamp(0.0, 1.0);
    final isCompleted = usedSeconds.value >= effectiveTargetSeconds;

    Future<bool> handleBackPress() async {
      // Block back navigation completely while Ad is loading or claiming
      if (isAdLoading.value || isClaiming.value) {
        return false;
      }

      if (!isInstalled.value) {
        return true;
      }

      // 1. If usage is completed but reward has not been collected yet
      if (isCompleted) {
        final result = await showModalBottomSheet<bool>(
          context: context,
          isDismissible: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          barrierColor: Colors.black.withValues(alpha: 0.70),
          builder: (ctx) {
            return CustomStatusPopup(
              type: StatusPopupType.success,
              tag: 'Reward Waiting!',
              title: 'Collect Your Reward!',
              message:
                  'You have completed the task! Don\'t forget to collect your +$effectiveCoins Coins before leaving.',
              primaryButtonText: 'COLLECT NOW',
              primaryButtonColor: const Color(0xFF16A34A),
              onPrimaryTap: () {
                Navigator.pop(ctx, false);
                handleClaimAndNavigate();
              },
              secondaryButtonText: 'EXIT ANYWAY',
              onSecondaryTap: () {
                Navigator.pop(ctx, true);
              },
            );
          },
        );

        return result ?? false;
      }

      // 2. If task is still in progress (not completed yet)
      final result = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        barrierColor: Colors.black.withValues(alpha: 0.70),
        builder: (ctx) {
          return CustomStatusPopup(
            type: StatusPopupType.warning,
            tag: 'Wait!',
            title: 'Task Incomplete!',
            message:
                'If you exit now, you will need to restart and complete the task again to earn rewards. Are you sure you want to leave?',
            primaryButtonText: 'CONTINUE',
            primaryButtonColor: const Color(0xFF16A34A),
            onPrimaryTap: () {
              Navigator.pop(ctx, false);
            },
            secondaryButtonText: 'EXIT ANYWAY',
            onSecondaryTap: () {
              Navigator.pop(ctx, true);
            },
          );
        },
      );

      return result ?? false;
    }

    return PopScope(
      canPop: !isInstalled.value && !isAdLoading.value && !isClaiming.value,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isAdLoading.value || isClaiming.value) return;
        final canLeave = await handleBackPress();
        if (canLeave && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                // 1. TOP HEADER BAR
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          if (isAdLoading.value || isClaiming.value) return;
                          HapticFeedback.lightImpact();
                          final canLeave = await handleBackPress();
                          if (canLeave && context.mounted) {
                            Navigator.pop(context);
                          }
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

                      Text(
                        'Super Offer',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const Spacer(),

                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (tutorialUrl.trim().isNotEmpty) {
                            LaunchUrl.inWeb(url: tutorialUrl.trim(), context: context);
                          } else {
                            CustomToast.showToast(
                              context,
                              msg: 'No tutorial video available.',
                            );
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: const Color(0xFFE39FFF).withValues(alpha: 0.8),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.10),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_circle_fill_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 14.sp,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'Tutorial',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFAB31DE),
                                  fontSize: 11.sp,
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

                // 2. MAIN SCROLLABLE CONTENT (MATCHING APP BOUNCING SCROLL)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  child: Column(
                    children: [
                      // ========================================================================= //
                      // 🟢 STEP 2: POST-INSTALL APP USAGE PROGRESS & CLAIM REWARD SCREEN          //
                      // (Shows Install completed card, Live App Usage Progress Bar, Open/Claim)   //
                      // ========================================================================= //
                      if (isInstalled.value) ...[
                        // 🟢 CARD 1: INSTALL APP (MINT GREEN TINTED CARD)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF0FDF4),
                                Color(0xFFDCFCE7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color(0xFF86EFAC),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44.w,
                                height: 44.w,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.download_rounded,
                                  color: const Color(0xFF16A34A),
                                  size: 22.sp,
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Install App',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF065F46),
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      'Download the advertised app',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF047857),
                                        fontSize: 12.5.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: const Color(0xFF15803D),
                                      size: 13.sp,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'Completed',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF15803D),
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 14.h),

                        // 🟣 CARD 2: USE APP & LIVE APP USAGE PROGRESS (LAVENDER PURPLE TINTED CARD)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFAF5FF),
                                Color(0xFFF3E8FF),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22.r),
                            border: Border.all(
                              color: isCompleted
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFD8B4FE),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44.w,
                                    height: 44.w,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFAF5FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sports_esports_rounded,
                                      color: const Color(0xFFAB31DE),
                                      size: 22.sp,
                                    ),
                                  ),
                                  SizedBox(width: 14.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Use App',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF1E1B4B),
                                            fontSize: 16.5.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 1.h),
                                        Text(
                                          'Use the app for at least $durationText',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF64748B),
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCompleted)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: const Color(0xFF15803D),
                                            size: 13.sp,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            'Done',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF15803D),
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              SizedBox(height: 18.h),

                              // APP USAGE PROGRESS HEADER
                              Row(
                                children: [
                                  Icon(
                                    Icons.insights_rounded,
                                    color: const Color(0xFFAB31DE),
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'App Usage Progress',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF1E1B4B),
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 10.h),

                              // LIVE PROGRESS BAR (CLEAN FILL, NO TEXT OVERLAY)
                              Container(
                                height: 14.h,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(7.r),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progressRatio,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF4ADE80),
                                          Color(0xFF16A34A),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(7.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(height: 14.h),

                              // AMBER CALLOUT: ⚡ Play the games or sign up in the app!
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.flash_on_rounded,
                                      color: const Color(0xFFD97706),
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 6.w),
                                    Expanded(
                                      child: Text(
                                        'Play the games or sign up in the app!',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF92400E),
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 8.h),

                              // SUBTEXT: Your progress updates automatically as you use the app
                              Text(
                                'Your progress updates automatically as you use the app',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              SizedBox(height: 14.h),

                              // WARNING CARD (Ban warning & 3 hours retention rule)
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: const Color(0xFFDC2626),
                                          size: 18.sp,
                                        ),
                                        SizedBox(width: 6.w),
                                        Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'Warning: ',
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFFDC2626),
                                                    fontSize: 11.5.sp,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text:
                                                      'Installing any app other than the advertised app will result in a permanent account ban and redeem rejection.',
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFF991B1B),
                                                    fontSize: 11.5.sp,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8.h),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: const Color(0xFFB45309),
                                          size: 15.sp,
                                        ),
                                        SizedBox(width: 6.w),
                                        Expanded(
                                          child: Text(
                                            "Do not delete the installed app for at least 3 hours or your rewards will be deducted.",
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF92400E),
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.w600,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // BOTTOM BUTTONS: CLAIM REWARD (IF COMPLETED) OR (OPEN APP & CHECK USAGE)
                        if (isCompleted)
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.40),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                onTap: isClaiming.value ? null : handleClaimAndNavigate,
                                child: _LuminousShimmerButton(
                                  child: Container(
                                    height: 50.h,
                                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF22C55E),
                                          Color(0xFF16A34A),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(25.r),
                                    ),
                                    child: isClaiming.value
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 16.sp,
                                                height: 16.sp,
                                                child: const CircularProgressIndicator(
                                                  strokeWidth: 2.0,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                'Claiming...',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          )
                                        : (SplashService.superOfferConfig['superOfferVerificationEnabled'] != false)
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'COLLECT',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 16.sp,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                  SizedBox(width: 6.w),
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                    color: Colors.white,
                                                    size: 19.sp,
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'COLLECT',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 16.sp,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Text(
                                                    '+$effectiveCoins',
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(0xFFFEF08A),
                                                      fontSize: 16.sp,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                  SizedBox(width: 5.w),
                                                  Image.asset(
                                                    'assets/icons/coin.png',
                                                    width: 20.w,
                                                    height: 20.w,
                                                  ),
                                                ],
                                              ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              // 1. OPEN APP BUTTON
                              Expanded(
                                flex: 5,
                                child: GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final pkg = activePkg.value.trim();
                                    if (pkg.isNotEmpty) {
                                      int startMs = startTimeMs.value;
                                      if (startMs <= 0) {
                                        startMs = DateTime.now().millisecondsSinceEpoch;
                                        startTimeMs.value = startMs;
                                      }
                                      saveStep1(userId, {
                                        'packageName': pkg,
                                        'isInstalled': true,
                                        'startTimeMs': startMs,
                                      });
                                      final launched = await SuperOfferNativeManager.launchApp(pkg);
                                      if (!launched && context.mounted) {
                                        clearStep1(userId);
                                        isAdWatched.value = false;
                                        isInstalled.value = false;
                                        usedSeconds.value = 0;
                                        startTimeMs.value = 0;
                                      }
                                    } else {
                                      CustomToast.showToast(
                                        context,
                                        msg: 'Opening app...',
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 50.h,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFE39FFF),
                                          Color(0xFFAB31DE),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(25.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Colors.white,
                                          size: 20.sp,
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'OPEN APP',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 14.5.sp,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(width: 10.w),

                              // 2. CHECK USAGE BUTTON
                              Expanded(
                                flex: 5,
                                child: GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final hasPerm = await SuperOfferNativeManager.checkUsagePermission();
                                    if (!hasPerm && context.mounted) {
                                      await CustomStatusPopup.showUsagePermission(
                                        context: context,
                                        onAllow: () async {
                                          await SuperOfferNativeManager.openUsageSettings();
                                        },
                                      );
                                      return;
                                    }
                                    await updateUsage();
                                    if (context.mounted) {
                                      final sec = usedSeconds.value;
                                      if (sec >= effectiveTargetSeconds) {
                                        handleClaimAndNavigate();
                                      } else {
                                        CustomToast.showToast(
                                          context,
                                          msg: 'Usage Updated! Active time: ${sec}s / ${effectiveTargetSeconds}s',
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    height: 50.h,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF5FF),
                                      borderRadius: BorderRadius.circular(25.r),
                                      border: Border.all(
                                        color: const Color(0xFFAB31DE),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.sync_rounded,
                                          color: const Color(0xFFAB31DE),
                                          size: 19.sp,
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'Check Usage',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFAB31DE),
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      // ========================================================================= //
                      // 🟢 STEP 1: FINISH THIS STEP FOR UNLOCK (REQUIREMENTS & STEPS PIPELINE)     //
                      // (Shows Step 1 Watch Ad -> Step 2 Install -> Step 3 Use -> Step 4 Collect) //
                      // ========================================================================= //
                      ] else ...[
                        // BEFORE INSTALL: CONNECTED STEPS & REQUIREMENTS PIPELINE
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(7.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF5FF),
                                      borderRadius: BorderRadius.circular(11.r),
                                      border: Border.all(
                                        color: const Color(0xFFE39FFF).withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.lock_open_rounded,
                                      color: const Color(0xFFAB31DE),
                                      size: 19.sp,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Finish this step for unlock',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF1E1B4B),
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      SizedBox(height: 1.h),
                                      Text(
                                        'Requirements & Steps',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF64748B),
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16.h),
                            _buildConnectedStepCard(
                              stepNumber: 1,
                              title: 'Watch Ad',
                              subtitle: 'Click "WATCH AD" below to watch the sponsored video.',
                              icon: Icons.play_arrow_rounded,
                              iconColor: const Color(0xFFD97706),
                              iconBg: const Color(0xFFFFFBEB),
                              isLast: false,
                            ),
                            _buildConnectedStepCard(
                              stepNumber: 2,
                              title: 'Install App',
                              subtitle: 'Install the advertised app from Google Play Store.',
                              icon: Icons.download_rounded,
                              iconColor: const Color(0xFF16A34A),
                              iconBg: const Color(0xFFF0FDF4),
                              isLast: false,
                            ),
                            _buildConnectedStepCard(
                              stepNumber: 3,
                              title: 'Use App for $durationText',
                              subtitle: 'Open and stay active in the app for at least $durationText.',
                              icon: Icons.timer_rounded,
                              iconColor: const Color(0xFF9333EA),
                              iconBg: const Color(0xFFFAF5FF),
                              isLast: false,
                            ),
                            _buildConnectedStepCard(
                              stepNumber: 4,
                              title: 'Collect Reward',
                              subtitle: 'Return back to collect your rewards!',
                              icon: Icons.stars_rounded,
                              iconColor: const Color(0xFF0284C7),
                              iconBg: const Color(0xFFECFEFF),
                              isLast: true,
                            ),

                            SizedBox(height: 16.h),

                            // IMPORTANT NOTE FOR ALREADY INSTALLED APPS
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD97706).withValues(alpha: 0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32.w,
                                    height: 32.w,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.lightbulb_rounded,
                                      color: const Color(0xFFD97706),
                                      size: 18.sp,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Important Note',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF92400E),
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 3.h),
                                        Text(
                                          'If the advertised app is already installed on your phone, simply close the ad and watch a new ad to get a new app.',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFB45309),
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.w500,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (!isInstalled.value) ...[
                              SizedBox(height: 20.h),

                              // BOTTOM MAIN WATCH AD BUTTON
                              GestureDetector(
                                onTap: isAdLoading.value ? null : handleWatchAd,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      height: 52.h,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFE39FFF),
                                            Color(0xFFAB31DE),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        borderRadius: BorderRadius.circular(26.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: isAdLoading.value
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 18.w,
                                                    height: 18.w,
                                                    child: const CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(width: 10.w),
                                                  Text(
                                                    'LOADING AD...',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 15.sp,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.play_circle_fill_rounded,
                                                    color: Colors.white,
                                                    size: 22.sp,
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Text(
                                                    'WATCH AD',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 16.sp,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),

                                    // CIRCULAR WHITE & BLACK AD BADGE
                                    Positioned(
                                      top: -8.h,
                                      right: 12.w,
                                      child: Container(
                                        width: 24.w,
                                        height: 24.w,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.35),
                                              blurRadius: 5,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'AD',
                                          style: GoogleFonts.fredoka(
                                            color: Colors.black,
                                            fontSize: 9.5.sp,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: MediaQuery.of(context).padding.bottom + 16.h),
                            ],
                          ],
                        ),
                      ],
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

  Widget _buildConnectedStepCard({
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Timeline (Step Badge + connecting line)
          Column(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 21.sp,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.w,
                    margin: EdgeInsets.symmetric(vertical: 4.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          iconColor.withValues(alpha: 0.6),
                          const Color(0xFFCBD5E1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(width: 12.w),

          // Right Step Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.18),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'STEP $stepNumber',
                          style: GoogleFonts.outfit(
                            color: iconColor,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
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

/// Luminous Unified Full-Button Shimmer Sweep (Properly Rounded & Confined)
class _LuminousShimmerButton extends HookWidget {
  const _LuminousShimmerButton({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ctrl = useAnimationController(
      duration: const Duration(milliseconds: 2800),
    );

    useEffect(() {
      ctrl.repeat();
      return null;
    }, [ctrl]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(25.r),
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final double offset = (ctrl.value * 2.8) - 1.4;
              return LinearGradient(
                begin: const Alignment(-1.0, -0.3),
                end: const Alignment(1.0, 0.3),
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.85),
                  Colors.white.withValues(alpha: 0.22),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                transform: _OffsetGradientTransform(offset),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

class _OffsetGradientTransform extends GradientTransform {
  const _OffsetGradientTransform(this.offset);
  final double offset;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * offset, 0.0, 0.0);
  }
}
