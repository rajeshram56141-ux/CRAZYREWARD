// ignore_for_file: unused_import, deprecated_member_use, depend_on_referenced_packages
import 'dart:async';
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:get_storage/get_storage.dart';
import '../../../../../utils/routes/routes_import.gr.dart';

import '../../../../../services/ad_manager.dart';
import '../../../../../services/analytics_service.dart';
import '../../../../../services/cloud_functions.dart';
import '../../../../../services/launch_url.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../../../utils/helper/helper.dart';
import '../../../../../widgets/common/custom_elevated_button.dart';
import '../../../../../widgets/common/custom_loading.dart';
import '../../../provider/dashboard_provider.dart';
import 'super_offer_provider.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import 'super_offer_native_manager.dart';
import 'super_offer_step1_screen.dart';
import 'super_offer_step2_list_screen.dart';

class SuperOfferWidget extends HookConsumerWidget {
  const SuperOfferWidget({
    super.key,
    required this.gems,
    required this.gemsRequired,
    required this.coins,
    required this.adsRequired,
    required this.installTask,
    this.superOfferVerificationEnabled = true,
    required this.userId,
    required this.dailyGemsForInstall,
    required this.gameGems,
    required this.installGems,
    required this.eligible,
    required this.lastClaimedAt,
    required this.hoursGap,
    this.gapMinutes = 60,
    this.isUnlocked = false,
    this.limitType = 'hours',
  });

  final int gems;
  final int coins;
  final int gemsRequired;
  final bool adsRequired;
  final bool installTask;
  final bool superOfferVerificationEnabled;
  final String userId;
  final int gameGems;
  final int installGems;
  final int dailyGemsForInstall;
  final bool eligible;
  final DateTime? lastClaimedAt;
  final int hoursGap;
  final int gapMinutes;
  final bool isUnlocked;
  final String limitType;

  static const String _unlockedStorageKey = 'super_offer_unlocked';
  static const String _lastClaimStorageKey = 'super_offer_last_claim_ts';

  static bool isOfferUnlocked(String userId) {
    try {
      final box = GetStorage();
      return box.read<bool>('${_unlockedStorageKey}_$userId') ?? false;
    } catch (_) {
      return false;
    }
  }

  static void setOfferUnlocked(String userId, bool unlocked) {
    try {
      final box = GetStorage();
      box.write('${_unlockedStorageKey}_$userId', unlocked);
    } catch (_) {}
  }

  static int? getLastClaimTs(String userId) {
    try {
      final box = GetStorage();
      return box.read<int>('${_lastClaimStorageKey}_$userId');
    } catch (_) {
      return null;
    }
  }

  static void recordClaimTs(String userId) {
    try {
      final box = GetStorage();
      box.write('${_lastClaimStorageKey}_$userId', DateTime.now().millisecondsSinceEpoch);
      final currentClaims = (SplashService.superOfferConfig['claimsToday'] as num?)?.toInt() ?? 0;
      SplashService.superOfferConfig['claimsToday'] = currentClaims + 1;
      setOfferUnlocked(userId, false);
    } catch (_) {}
  }

  static void clearClaimTs(String userId) {
    try {
      final box = GetStorage();
      box.remove('${_lastClaimStorageKey}_$userId');
    } catch (_) {}
  }

  void showResultDialog(
    BuildContext context,
    WidgetRef ref,
    int coins,
    int gemsRequired,
    bool success, {
    bool alreadyClaimed = false,
  }) {
    if (success) {
      CustomStatusPopup.showSuccess(
        context: context,
        title: 'Offer Completed!',
        message: 'You have earned +$coins Coins!',
        primaryButtonText: alreadyClaimed ? 'AWESOME' : 'CLAIM NOW',
        onPrimaryTap: () async {
          if (!alreadyClaimed) {
            recordClaimTs(userId);
            ref.invalidate(DashboardService.userDataProvider(userId));
            ref.invalidate(superOfferVerifierProvider(userId));
            await CloudFunctions.claimSuperOffer(coins, gemsRequired);
            ref.invalidate(DashboardService.userDataProvider(userId));
            ref.invalidate(superOfferVerifierProvider(userId));
          }
        },
      );
    } else {
      CustomStatusPopup.showFailed(
        context: context,
        tag: 'Oops!',
        title: 'Task Not Completed!',
        message: 'Task was not completed! Please install the app and complete the steps to receive your reward.',
        primaryButtonText: 'TRY AGAIN',
      );
    }
  }

  void lessGemsPopup({
    required BuildContext context,
    required int gameGems,
    required int installGems,
  }) {
    CustomStatusPopup.showWarning(
      context: context,
      tag: 'Need More Gems',
      title: 'Not Enough Gems',
      message: 'You need more gems to unlock Super Offer. Play games to get more gems!',
      primaryButtonText: 'PLAY GAME',
      primaryButtonColor: const Color(0xFFAB31DE),
      onPrimaryTap: () {
        AutoRouter.of(context).push(
          DiamondCatchScreenRoute(
            userId: userId,
            gameGems: gameGems,
            installGems: installGems,
            dailyGemsForInstall: dailyGemsForInstall,
            gemsRequired: gemsRequired,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTracking = useState(false);
    final clickTime = useState<DateTime?>(null);
    final lifecycleState = useAppLifecycleState();

    final localClaimTs = getLastClaimTs(userId);
    final DateTime? localClaimDate = localClaimTs != null ? DateTime.fromMillisecondsSinceEpoch(localClaimTs) : null;
    final effectiveMinutes = gapMinutes > 0 ? gapMinutes : (hoursGap * 60);

    final config = SplashService.superOfferConfig;
    final int dailyLimit = (config['dailyLimit'] as num?)?.toInt() ??
        int.tryParse(config['superOfferDailyLimit']?.toString() ?? '') ??
        int.tryParse(config['dailyLimit']?.toString() ?? '') ??
        1;
    final int claimsToday = (config['claimsToday'] as num?)?.toInt() ?? 0;

    final now = DateTime.now();

    final localSaved = SuperOfferStep2ListScreen.getSavedOffers(userId);
    final hasPendingStep2 = localSaved.any(
      (e) => e['step1Claimed'] == true && e['proofSubmitted'] != true,
    );

    // In Method 4, if user has Step 1 claimed and pending screenshot upload,
    // they are currently in progress! Do NOT start cooldown timer or daily limit lock.
    final bool isLocalCooldownActive = !hasPendingStep2 &&
        limitType == 'hours' &&
        localClaimDate != null &&
        now.difference(localClaimDate).inMinutes < effectiveMinutes;

    // Daily limit reached check (applies to BOTH daily and hours modes)
    final bool isDailyLimitReached = !hasPendingStep2 &&
        dailyLimit > 0 &&
        claimsToday >= dailyLimit;
    final bool isJustClaimedLocally = !hasPendingStep2 &&
        isDailyLimitReached &&
        localClaimDate != null &&
        now.difference(localClaimDate).inSeconds < 30;

    final bool isOfferLocked = !hasPendingStep2 && (isDailyLimitReached ||
        isLocalCooldownActive ||
        (!eligible) ||
        isJustClaimedLocally);

    final isTimerExpired = useState<bool>(false);

    useEffect(() {
      isTimerExpired.value = false;
      if (!hasPendingStep2 && eligible && !isDailyLimitReached) {
        clearClaimTs(userId);
      }
      return null;
    }, [lastClaimedAt, eligible, isDailyLimitReached, hasPendingStep2]);

    final bool effectiveEligible = hasPendingStep2
        ? true
        : (isDailyLimitReached
            ? false
            : (isTimerExpired.value
                ? true
                : (isOfferLocked ? false : eligible)));

    final DateTime? effectiveLastClaimedAt = hasPendingStep2
        ? null
        : (lastClaimedAt ?? (isOfferLocked ? (localClaimDate ?? now) : null));

    final remainingTime = useState<Duration>(Duration.zero);

    useEffect(() {
      if (hasPendingStep2 || effectiveEligible || effectiveLastClaimedAt == null || isDailyLimitReached) return null;

      void updateTime() {
        final nextAvailable = effectiveLastClaimedAt.add(Duration(minutes: effectiveMinutes));
        final diff = nextAvailable.difference(DateTime.now());
        if (diff.isNegative || diff.inSeconds <= 0) {
          remainingTime.value = Duration.zero;
          if (!isTimerExpired.value) {
            isTimerExpired.value = true;
            clearClaimTs(userId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.invalidate(superOfferVerifierProvider(userId));
            });
          }
        } else {
          isTimerExpired.value = false;
          remainingTime.value = diff;
        }
      }

      updateTime();
      final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        updateTime();
      });

      return timer.cancel;
    }, [effectiveEligible, effectiveLastClaimedAt, gapMinutes, hoursGap, isDailyLimitReached]);

    String formatDuration(Duration duration) {
      if (limitType == 'daily' || isDailyLimitReached || effectiveLastClaimedAt == null) {
        return 'Tomorrow';
      }
      final effectiveMinutes = gapMinutes > 0 ? gapMinutes : (hoursGap * 60);
      if (effectiveMinutes >= 1440) {
        return 'Tomorrow';
      }
      if (duration.inSeconds <= 0) {
        return '00:00:00';
      }
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }

    useValueChanged<AppLifecycleState?, void>(lifecycleState, (_, __) {
      if (isTracking.value &&
          lifecycleState == AppLifecycleState.resumed &&
          clickTime.value != null) {
        final secondsSpent = DateTime.now()
            .difference(clickTime.value!)
            .inSeconds;

        isTracking.value = false;
        clickTime.value = null;

        Future.microtask(() {
          if (!context.mounted) return;
          showResultDialog(context, ref, coins, gemsRequired, secondsSpent > 90);
        });
      }
    });

    final isButtonLoading = useState<bool>(false);
    final buttonLoadingText = useState<String>('Loading...');

    final currentPkg = config['packageName']?.toString() ?? '';

    // When verification is ON, calculate total combined potential earnings:
    // (Install Coins + Screenshot Coins + Usage Steps Coins)
    final bool isVerificationOn = superOfferVerificationEnabled && (config['superOfferVerificationEnabled'] != false);
    int displayCoins = coins;
    if (isVerificationOn) {
      final int installCoins = coins > 0 ? coins : ((config['reward'] as num?)?.toInt() ?? 768);
      final bool isScreenshotEnabled = config['screenshotVerificationEnabled'] != false;
      final int screenshotCoins = config['screenshotCoins'] != null
          ? (int.tryParse(config['screenshotCoins'].toString()) ?? (installCoins * 0.75).round())
          : (installCoins * 0.75).round();

      final List steps = config['usageSteps'] is List ? (config['usageSteps'] as List) : [];
      int totalUsageCoins = 0;
      for (var s in steps) {
        if (s is Map && s['coins'] != null) {
          totalUsageCoins += (s['coins'] as num).toInt();
        }
      }

      displayCoins = installCoins + (isScreenshotEnabled ? screenshotCoins : 0) + totalUsageCoins;
    }

    final isAlreadyUnlocked = hasPendingStep2 || (!isOfferLocked && isUnlocked);

    final isUnlockedState = useState<bool>(isAlreadyUnlocked);

    useEffect(() {
      if (!isUnlocked && !hasPendingStep2) {
        setOfferUnlocked(userId, false);
      }
      isUnlockedState.value = isAlreadyUnlocked;
      if (isAlreadyUnlocked && !installTask) {
        AdManager().preloadRewarded();
      }
      return null;
    }, [isAlreadyUnlocked, isUnlocked, hasPendingStep2, installTask, isOfferLocked]);

    Future<void> handleTap() async {
      if (isButtonLoading.value) return;

      if (!isUnlockedState.value && gems < gemsRequired) {
        lessGemsPopup(
          context: context,
          gameGems: gameGems,
          installGems: installGems,
        );
        return;
      }

      // FLOW 1: installTask is OFF OR superOfferVerificationEnabled is OFF -> Direct / Watch Ad flow
      if (!installTask || !superOfferVerificationEnabled) {
        // Step 1: If not unlocked yet -> Deduct Gems Instantly & Update State
        if (!isUnlockedState.value) {
          buttonLoadingText.value = 'Unlocking...';
          isButtonLoading.value = true;
          try {
            final success = await CloudFunctions.deductSuperOfferGems(gemsRequired);
            if (success) {
              setOfferUnlocked(userId, true);
              isUnlockedState.value = true;
              ref.invalidate(DashboardService.userDataProvider(userId));
            }
          } catch (_) {
          } finally {
            isButtonLoading.value = false;
          }
          return;
        }

        // Step 2: Already Unlocked!
        // Subcase 1A: installTask is OFF -> Watch Ad to get reward
        if (!installTask) {
          buttonLoadingText.value = 'Loading ad...';
          isButtonLoading.value = true;
          final adCompleter = Completer<void>();
          try {
            await AdManager().showRewardedAd(
              context: context,
              onReward: () async {},
              onAdClicked: () async {},
              onAdClosed: (bool success) async {
                try {
                  if (success) {
                    buttonLoadingText.value = 'Claiming...';
                    // Claim reward on server first BEFORE resetting state or invalidating providers
                    await CloudFunctions.claimSuperOffer(coins, 0, userId: userId);
                    recordClaimTs(userId);
                    setOfferUnlocked(userId, false);
                    isUnlockedState.value = false;
                    ref.invalidate(DashboardService.userDataProvider(userId));
                    ref.invalidate(superOfferVerifierProvider(userId));
                    if (context.mounted) {
                      showResultDialog(context, ref, coins, 0, true, alreadyClaimed: true);
                    }
                  }
                } catch (_) {
                } finally {
                  if (!adCompleter.isCompleted) {
                    adCompleter.complete();
                  }
                }
              },
              onAdFailed: () {
                if (!adCompleter.isCompleted) {
                  adCompleter.complete();
                }
              },
            );
            await adCompleter.future.timeout(
              const Duration(seconds: 45),
              onTimeout: () {},
            );
          } finally {
            isButtonLoading.value = false;
          }
          return;
        }

        // Subcase 1B: installTask is ON -> Complete Now opens Step1 Screen
        if (installTask) {
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

          final initialUsageSeconds = (config['initialUsageSeconds'] as num?)?.toInt() ??
              int.tryParse(config['initialUsageSeconds']?.toString() ?? '') ??
              120;

          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SuperOfferStep1Screen(
                userId: userId,
                coins: coins,
                gemsRequired: 0,
                packageName: currentPkg,
                targetSeconds: initialUsageSeconds,
              ),
            ),
          );

          final stillUnlocked = isOfferUnlocked(userId);
          isUnlockedState.value = stillUnlocked;
          ref.invalidate(DashboardService.userDataProvider(userId));
          ref.invalidate(superOfferVerifierProvider(userId));
          return;
        }
      }

      // FLOW 2: superOfferVerificationEnabled == true (Verification ON)
      // Case 2A: Offer is already unlocked or pending
      if (isUnlockedState.value) {
        isButtonLoading.value = true;
        try {
          final savedList = await SuperOfferStep2ListScreen.syncSavedOffers(userId);

          final pendingOffer = savedList.firstWhere(
            (e) => (e['packageName'] == currentPkg || e['appName'] == config['appName']) && e['step1Claimed'] == true,
            orElse: () => savedList.firstWhere(
              (e) => e['step1Claimed'] == true && e['proofSubmitted'] != true,
              orElse: () => <String, dynamic>{},
            ),
          );

          if (pendingOffer.isNotEmpty && pendingOffer['proofStatus'] == 'pending') {
            setOfferUnlocked(userId, false);
            isUnlockedState.value = false;
            ref.invalidate(superOfferVerifierProvider(userId));
            ref.invalidate(pendingOffersProvider(userId));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF16A34A),
                  content: Text('Screenshot proof is already submitted and under review!'),
                ),
              );
            }
            return;
          }

          final bool isStep1Claimed = pendingOffer.isNotEmpty;

          // If Step 1 is in progress (unlocked but not claimed yet), open Step 1 Screen!
          if (!isStep1Claimed) {
            final initialUsageSeconds = (config['initialUsageSeconds'] as num?)?.toInt() ??
                int.tryParse(config['initialUsageSeconds']?.toString() ?? '') ??
                120;

            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SuperOfferStep1Screen(
                  userId: userId,
                  coins: coins,
                  gemsRequired: 0,
                  packageName: currentPkg,
                  targetSeconds: initialUsageSeconds,
                ),
              ),
            );

            ref.invalidate(DashboardService.userDataProvider(userId));
            ref.invalidate(superOfferVerifierProvider(userId));
            ref.invalidate(pendingOffersProvider(userId));
            isUnlockedState.value = isOfferUnlocked(userId) || isUnlocked;
            return;
          }

          // If Step 1 was already claimed and waiting for proof review or usage steps:
          final activePackageName = pendingOffer['packageName']?.toString() ?? currentPkg;
          final activeAppName = pendingOffer['appName']?.toString() ?? config['appName']?.toString() ?? 'Super Offer App';
          final activeCoins = (pendingOffer['coins'] as num?)?.toInt() ?? coins;

          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SuperOfferStep2ListScreen(
                userId: userId,
                coins: activeCoins,
                packageName: activePackageName,
                appName: activeAppName,
                installTimeText: 'Pending Verification',
              ),
            ),
          );

          ref.invalidate(DashboardService.userDataProvider(userId));
          ref.invalidate(superOfferVerifierProvider(userId));
          ref.invalidate(pendingOffersProvider(userId));
          isUnlockedState.value = isOfferUnlocked(userId) || isUnlocked;
        } finally {
          isButtonLoading.value = false;
        }
        return;
      }

      // Case 2B: Unlocking for the first time
      // STEP A: App Usage Permission Check FIRST!
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

      // STEP B: Deduct Gems Instantly & Change Button to Complete Now
      isButtonLoading.value = true;
      try {
        final success = await CloudFunctions.deductSuperOfferGems(gemsRequired);
        if (success) {
          setOfferUnlocked(userId, true);
          SuperOfferStep1Screen.clearStep1(userId);
          isUnlockedState.value = true;
          ref.invalidate(DashboardService.userDataProvider(userId));

          final appName = config['appName']?.toString() ?? 'Super Offer App';

          if (currentPkg.isNotEmpty) {
            await CloudFunctions.logSuperOfferActivity(
              packageName: currentPkg,
              appName: appName,
              stepNumber: 1,
              stepName: 'Install App & Launch',
              stepType: 'install',
              status: 'started',
              coins: 0,
            );
          }

          // Open SuperOfferStep1Screen so they can do the install/watch ad task
          final initialUsageSeconds = (config['initialUsageSeconds'] as num?)?.toInt() ??
              int.tryParse(config['initialUsageSeconds']?.toString() ?? '') ??
              120;

          if (context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SuperOfferStep1Screen(
                  userId: userId,
                  coins: coins,
                  gemsRequired: 0,
                  packageName: currentPkg,
                  targetSeconds: initialUsageSeconds,
                ),
              ),
            );

            ref.invalidate(DashboardService.userDataProvider(userId));
            ref.invalidate(superOfferVerifierProvider(userId));
            ref.invalidate(pendingOffersProvider(userId));
            isUnlockedState.value = isOfferUnlocked(userId) && isUnlocked;
          }
        }
      } catch (_) {
      } finally {
        isButtonLoading.value = false;
      }
    }

    final double progressVal = gemsRequired > 0 ? (gems / gemsRequired).clamp(0.0, 1.0) : 1.0;

    return Container(
      height: 96.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
            // 1. Subtle background glow
            Positioned(
              left: -10.w,
              top: -10.h,
              child: Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9).withValues(alpha: 0.8),
                ),
              ),
            ),

            // 2. Ultra Large 3D Icon Positioned at Bottom-Left
            Positioned(
              left: -12.w,
              bottom: -14.h,
              child: Image.asset(
                'assets/Icons1/super_offer_3d.png',
                width: 104.w,
                height: 104.w,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/icons/suprerofferdhn.png',
                  width: 96.w,
                  height: 96.w,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 3. Foreground Card Content Row
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(86.w, 10.h, 14.w, 10.h),
                child: Row(
                  children: [
                    // LEFT SECTION: Coins Text + Gem Progress Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SUPER REWARD',
                            maxLines: 1,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF26262B),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/icons/coin.png',
                                height: 16.h,
                                width: 16.h,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: 4.w),
                              Flexible(
                                child: Text(
                                  '+$displayCoins',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF1E1B4B),
                                    fontSize: 16.5.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5.h),
                          // Mini Gem Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: SizedBox(
                              width: 85.w,
                              height: 4.h,
                              child: LinearProgressIndicator(
                                value: progressVal,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF26262B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 8.w),

                    // RIGHT SECTION: Fees Pill (Top) + Unlock Offer Button (Bottom)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Fees Pill
                        Container(
                          height: 26.h,
                          padding: EdgeInsets.symmetric(horizontal: 8.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFF26262E),
                            borderRadius: BorderRadius.circular(100.r),
                            border: Border.all(
                              color: const Color(0xFF383842),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$gemsRequired',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Image.asset(
                                'assets/icons/gems.png',
                                width: 12.w,
                                height: 12.w,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                'Fees',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF9E9EA7),
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 5.h),

                        // 2. Unlock Offer Button or Locked Timer State
                        if (isButtonLoading.value || hasPendingStep2 || (!isOfferLocked && (effectiveEligible || isUnlockedState.value))) ...[
                          GestureDetector(
                            onTap: handleTap,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
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
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: const Color(0xFF9CA3AF),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.10),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isButtonLoading.value
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 12.sp,
                                          height: 12.sp,
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF16161A),
                                          ),
                                        ),
                                        SizedBox(width: 5.w),
                                        Text(
                                          buttonLoadingText.value,
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF16161A),
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          !isUnlockedState.value && !hasPendingStep2
                                              ? Icons.lock_open_rounded
                                              : (hasPendingStep2
                                                  ? Icons.file_upload_outlined
                                                  : (!installTask
                                                      ? Icons.play_circle_filled_rounded
                                                      : Icons.play_arrow_rounded)),
                                          color: const Color(0xFF16161A),
                                          size: 13.sp,
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          !isUnlockedState.value && !hasPendingStep2
                                              ? 'Unlock Offer'
                                              : (hasPendingStep2
                                                  ? 'Upload Screenshot'
                                                  : (!installTask
                                                      ? 'Watch Ad'
                                                      : 'Complete Now')),
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF16161A),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ] else ...[
                          // Timer Locked Pill State
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (limitType == 'daily' || isDailyLimitReached || lastClaimedAt == null) ? Icons.calendar_today_rounded : Icons.timer_outlined,
                                  color: const Color(0xFF64748B),
                                  size: 13.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  formatDuration(remainingTime.value),
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
