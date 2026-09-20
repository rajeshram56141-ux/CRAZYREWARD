import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_storage/get_storage.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../services/cloud_functions.dart';
import '../../../../../services/ad_manager.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import 'super_offer_native_manager.dart';
import 'super_offer_widget.dart';
import 'super_offer_provider.dart';

class SuperOfferStep2ListScreen extends HookConsumerWidget {
  final String userId;
  final int coins;
  final String appName;
  final String? appIconUrl;
  final String installTimeText;
  final String? packageName;

  const SuperOfferStep2ListScreen({
    super.key,
    required this.userId,
    required this.coins,
    this.appName = 'Newly Installed App',
    this.appIconUrl,
    this.installTimeText = 'Installed recently',
    this.packageName,
  });

  static const String _storageKey = 'super_offer_saved_list';

  static List<Map<String, dynamic>> getSavedOffers(String userId) {
    try {
      final box = GetStorage();
      final raw = box.read<List>('${_storageKey}_$userId');
      if (raw == null) return [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  static void saveOffer(String userId, Map<String, dynamic> offer) {
    try {
      final box = GetStorage();
      final list = getSavedOffers(userId);
      
      final existingIndex = list.indexWhere((e) => e['packageName'] == offer['packageName']);
      bool oldProofSubmitted = false;
      String oldProofStatus = 'not_submitted';
      bool oldStep1Claimed = false;
      dynamic oldConfigSnapshot;
      if (existingIndex != -1) {
        oldProofSubmitted = list[existingIndex]['proofSubmitted'] == true;
        oldProofStatus = list[existingIndex]['proofStatus']?.toString() ?? 'not_submitted';
        oldStep1Claimed = list[existingIndex]['step1Claimed'] == true;
        oldConfigSnapshot = list[existingIndex]['configSnapshot'];
        list.removeAt(existingIndex);
      }
      
      final newOffer = Map<String, dynamic>.from(offer);
      if (!newOffer.containsKey('proofSubmitted')) {
        newOffer['proofSubmitted'] = oldProofSubmitted;
      }
      if (!newOffer.containsKey('proofStatus')) {
        newOffer['proofStatus'] = oldProofStatus;
      }
      if (!newOffer.containsKey('step1Claimed')) {
        newOffer['step1Claimed'] = oldStep1Claimed;
      }
      if (!newOffer.containsKey('configSnapshot') && oldConfigSnapshot != null) {
        newOffer['configSnapshot'] = oldConfigSnapshot;
      }
      if (newOffer['configSnapshot'] == null) {
        newOffer['configSnapshot'] = SplashService.superOfferConfig;
      }
      
      list.insert(0, newOffer);
      box.write('${_storageKey}_$userId', list);
    } catch (_) {
      // Storage error ignored
    }
  }

  static void removeOffer(String userId, String? packageName) {
    if (packageName == null || packageName.isEmpty) return;
    try {
      final box = GetStorage();
      final list = getSavedOffers(userId);
      list.removeWhere((e) => e['packageName'] == packageName);
      box.write('${_storageKey}_$userId', list);

      // Clear all step-specific progress keys to avoid dirty state on re-unlock
      box.remove('so_completed_usage_${userId}_$packageName');
      box.remove('so_skipped_usage_${userId}_$packageName');
      for (int i = 1; i <= 10; i++) {
        box.remove('so_step_cooldown_${userId}_${packageName}_$i');
        box.remove('so_step_start_${userId}_${packageName}_$i');
        box.remove('so_step_used_${userId}_${packageName}_$i');
      }
    } catch (_) {
      // Storage error ignored
    }
  }

  static List<int> getCompletedUsageSteps(String userId, String packageName) {
    if (userId.isEmpty || packageName.isEmpty) return [];
    try {
      final box = GetStorage();
      final list = box.read('so_completed_usage_${userId}_$packageName');
      if (list is List) {
        return list.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
      }
    } catch (_) {}
    return [];
  }

  static void markUsageStepCompleted(String userId, String packageName, int stepNumber) {
    if (userId.isEmpty || packageName.isEmpty) return;
    try {
      final box = GetStorage();
      final list = getCompletedUsageSteps(userId, packageName);
      if (!list.contains(stepNumber)) {
        list.add(stepNumber);
        box.write('so_completed_usage_${userId}_$packageName', list);
      }
    } catch (_) {}
  }

  static List<int> getSkippedUsageSteps(String userId, String packageName) {
    if (userId.isEmpty || packageName.isEmpty) return [];
    try {
      final box = GetStorage();
      final list = box.read('so_skipped_usage_${userId}_$packageName');
      if (list is List) {
        return list.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
      }
    } catch (_) {}
    return [];
  }

  static void markUsageStepSkipped(String userId, String packageName, int stepNumber) {
    if (userId.isEmpty || packageName.isEmpty) return;
    try {
      final box = GetStorage();
      final list = getSkippedUsageSteps(userId, packageName);
      if (!list.contains(stepNumber)) {
        list.add(stepNumber);
        box.write('so_skipped_usage_${userId}_$packageName', list);
      }
    } catch (_) {}
  }

  static int getStepCooldownExpiry(String userId, String packageName, int stepNumber) {
    if (userId.isEmpty || packageName.isEmpty) return 0;
    try {
      final box = GetStorage();
      return (box.read('so_step_cooldown_${userId}_${packageName}_$stepNumber') as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static void setStepCooldownExpiry(String userId, String packageName, int stepNumber, int expiryMs) {
    if (userId.isEmpty || packageName.isEmpty) return;
    try {
      final box = GetStorage();
      box.write('so_step_cooldown_${userId}_${packageName}_$stepNumber', expiryMs);
    } catch (_) {}
  }

  static int getStepStartTime(String userId, String packageName, int stepNumber) {
    if (userId.isEmpty || packageName.isEmpty) return 0;
    try {
      final box = GetStorage();
      return (box.read('so_step_start_${userId}_${packageName}_$stepNumber') as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static void setStepStartTime(String userId, String packageName, int stepNumber, int timeMs) {
    if (userId.isEmpty || packageName.isEmpty) return;
    try {
      final box = GetStorage();
      box.write('so_step_start_${userId}_${packageName}_$stepNumber', timeMs);
    } catch (_) {}
  }

  static int getStepUsedSeconds(String userId, String packageName, int stepNumber) {
    if (userId.isEmpty || packageName.isEmpty) return 0;
    try {
      final box = GetStorage();
      return (box.read('so_step_used_${userId}_${packageName}_$stepNumber') as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static void setStepUsedSeconds(String userId, String packageName, int stepNumber, int seconds) {
    if (userId.isEmpty || packageName.isEmpty) return;
    try {
      final box = GetStorage();
      box.write('so_step_used_${userId}_${packageName}_$stepNumber', seconds);
    } catch (_) {}
  }

  static String formatInstallTime(dynamic rawTime, {int? savedAtMs}) {
    DateTime? dt;
    if (rawTime is DateTime) {
      dt = rawTime;
    } else if (rawTime is int && rawTime > 0) {
      dt = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else if (rawTime is String && rawTime.isNotEmpty) {
      if (rawTime.startsWith('Installed ') && !rawTime.contains('recently')) {
        return rawTime;
      }
      dt = DateTime.tryParse(rawTime);
    }

    if (dt == null && savedAtMs != null && savedAtMs > 0) {
      dt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
    }

    if (dt == null) return 'Installed recently';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60 && diff.inSeconds >= 0) {
      return 'Installed just now';
    } else if (diff.inMinutes < 60 && diff.inMinutes >= 1) {
      return 'Installed ${diff.inMinutes} ${diff.inMinutes == 1 ? "min" : "mins"} ago';
    } else if (diff.inHours < 24 && diff.inHours >= 1) {
      return 'Installed ${diff.inHours} ${diff.inHours == 1 ? "hr" : "hrs"} ago';
    } else if (diff.inDays == 1) {
      return 'Installed Yesterday';
    } else if (diff.inDays < 7) {
      return 'Installed ${diff.inDays} days ago';
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = monthNames[dt.month - 1];
      final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return 'Installed $day $month, $hour12:$min $ampm';
    }
  }

  static Future<List<Map<String, dynamic>>> syncSavedOffers(String userId) async {
    final localList = getSavedOffers(userId);
    if (userId.isEmpty) return localList;
    try {
      final dbOffers = await CloudFunctions.getUserPendingOffersDetails(userId: userId);
      if (dbOffers.isNotEmpty) {
        dbOffers.sort((a, b) {
          final timeA = (a['savedAt'] as num?)?.toInt() ?? (DateTime.tryParse(a['installedAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0);
          final timeB = (b['savedAt'] as num?)?.toInt() ?? (DateTime.tryParse(b['installedAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? 0);
          return timeB.compareTo(timeA);
        });
        final box = GetStorage();
        box.write('${_storageKey}_$userId', dbOffers);
        return dbOffers;
      } else {
        // If DB returned empty, check if local offers still have pending usage steps
        final remainingLocal = localList.where((e) {
          final pkg = e['packageName']?.toString() ?? '';
          if (pkg.isEmpty) return false;
          final completed = getCompletedUsageSteps(userId, pkg);
          final skipped = getSkippedUsageSteps(userId, pkg);
          final snapshot = e['configSnapshot'];
          final rawSteps = (snapshot is Map && snapshot['usageSteps'] is List)
              ? (snapshot['usageSteps'] as List)
              : SplashService.superOfferConfig['usageSteps'];
          final totalSteps = (rawSteps is List && rawSteps.isNotEmpty) ? rawSteps.length : 3;
          final doneCount = completed.length + skipped.length;
          return doneCount < totalSteps;
        }).toList();

        if (remainingLocal.isNotEmpty) {
          final box = GetStorage();
          box.write('${_storageKey}_$userId', remainingLocal);
          return remainingLocal;
        }

        final activePackages = await CloudFunctions.getUserPendingOffers(userId: userId);
        final set = activePackages.toSet();
        final filtered = localList.where((e) {
          final pkg = e['packageName'];
          return set.contains(pkg);
        }).toList();
        final box = GetStorage();
        box.write('${_storageKey}_$userId', filtered);
        return filtered;
      }
    } catch (_) {}
    return localList;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialSaved = getSavedOffers(userId);
    final currentInitialPkg = (packageName?.trim().isNotEmpty == true)
        ? packageName!.trim()
        : (initialSaved.isNotEmpty ? (initialSaved.first['packageName']?.toString() ?? '') : '');

    final initialOffer = initialSaved.firstWhere(
      (e) => e['packageName'] == currentInitialPkg || (appName.isNotEmpty && e['appName'] == appName),
      orElse: () => initialSaved.isNotEmpty ? initialSaved.first : <String, dynamic>{},
    );

    // CRITICAL: Always use the frozen configSnapshot of this engaged offer so admin changes only affect new tasks!
    final dynamic offerSnapshot = initialOffer['configSnapshot'];
    final Map<String, dynamic> superOfferConfig = (offerSnapshot is Map && offerSnapshot.isNotEmpty)
        ? Map<String, dynamic>.from(offerSnapshot)
        : SplashService.superOfferConfig;

    final int activeMethod = (superOfferConfig['activeMethod'] as num?)?.toInt() ??
        (SplashService.superOfferConfig['activeMethod'] as num?)?.toInt() ??
        ((superOfferConfig['screenshotVerificationEnabled'] == false || SplashService.superOfferConfig['screenshotVerificationEnabled'] == false) ? 3 : 4);

    final bool isScreenshotEnabled = (activeMethod != 3) &&
        (superOfferConfig['screenshotVerificationEnabled'] != false) &&
        (SplashService.superOfferConfig['screenshotVerificationEnabled'] != false) &&
        (superOfferConfig['superOfferVerificationEnabled'] != false);
    final int configReward = (superOfferConfig['reward'] as num?)?.toInt() ??
        (int.tryParse(superOfferConfig['reward']?.toString() ?? '') ?? 0);
    final int splashReward = (SplashService.superOfferConfig['reward'] as num?)?.toInt() ??
        (int.tryParse(SplashService.superOfferConfig['reward']?.toString() ?? '') ?? 0);
    final int baseReward = configReward > 0 ? configReward : (splashReward > 0 ? splashReward : 5000);
    final int installCoins = (coins >= 100) ? coins : baseReward;
    final int screenshotCoins = superOfferConfig['screenshotCoins'] != null
        ? (int.tryParse(superOfferConfig['screenshotCoins'].toString()) ?? (installCoins * 0.75).round())
        : (installCoins * 0.75).round();

    final dynamic rawUsageSteps = superOfferConfig['usageSteps'];
    final List<Map<String, dynamic>> usageStepsList = [];
    if (rawUsageSteps is List && rawUsageSteps.isNotEmpty) {
      for (final st in rawUsageSteps) {
        if (st is Map) {
          final int cooldownSec = int.tryParse(st['cooldownSeconds']?.toString() ?? '') ??
              int.tryParse(st['hoursGap']?.toString() ?? '0') ??
              0;

          final int usageSeconds = int.tryParse(st['usageSeconds']?.toString() ?? '') ??
              ((int.tryParse(st['minutes']?.toString() ?? '5') ?? 5) * 60);

          usageStepsList.add({
            'stepNumber': st['stepNumber'] ?? (usageStepsList.length + 1),
            'name': st['stepName'] ?? st['name'] ?? 'Use App',
            'minutes': int.tryParse(st['minutes']?.toString() ?? '5') ?? (usageSeconds ~/ 60),
            'usageSeconds': usageSeconds,
            'coins': int.tryParse(st['coins']?.toString() ?? '0') ?? 0,
            'cooldownSeconds': cooldownSec,
            'hoursGap': cooldownSec,
          });
        }
      }
    }

    if (usageStepsList.isEmpty) {
      usageStepsList.addAll([
        {'stepNumber': 1, 'name': 'Use App', 'usageSeconds': 300, 'minutes': 5, 'coins': (installCoins * 0.875).round(), 'cooldownSeconds': 0, 'hoursGap': 0},
        {'stepNumber': 2, 'name': 'Use App', 'usageSeconds': 300, 'minutes': 5, 'coins': (installCoins * 0.875).round(), 'cooldownSeconds': 86400, 'hoursGap': 86400},
        {'stepNumber': 3, 'name': 'Use App', 'usageSeconds': 300, 'minutes': 5, 'coins': (installCoins * 1.5).round(), 'cooldownSeconds': 86400, 'hoursGap': 86400},
      ]);
    }

    int totalUsageCoins = 0;
    for (final st in usageStepsList) {
      totalUsageCoins += (st['coins'] as int? ?? 0);
    }

    final int totalPotentialEarnings = installCoins + (isScreenshotEnabled ? screenshotCoins : 0) + totalUsageCoins;

    final bool initialIsSubmitted = !isScreenshotEnabled ||
        initialOffer['proofSubmitted'] == true ||
        initialOffer['proofStatus'] == 'pending' ||
        initialOffer['proofStatus'] == 'approved';

    final String initialProofStatus = !isScreenshotEnabled
        ? 'approved'
        : (initialOffer['proofStatus']?.toString() ??
            (initialOffer['proofSubmitted'] == true ? 'pending' : 'none'));

    final savedOffers = useState<List<Map<String, dynamic>>>(initialSaved);
    final selectedImage = useState<File?>(null);
    final isUploading = useState<bool>(false);
    final isSubmitted = useState<bool>(initialIsSubmitted);
    final resolvedAppName = useState<String>(initialOffer['appName']?.toString() ?? appName);
    final initialInstallTimeStr = formatInstallTime(
      initialOffer['installTimeText'] ?? initialOffer['installedAt'] ?? initialOffer['savedAt'],
      savedAtMs: initialOffer['savedAt'] as int?,
    );
    final resolvedInstallTime = useState<String>(initialInstallTimeStr);

    // Track active package
    final activePkg = useState<String>(currentInitialPkg);

    final proofStatus = useState<String>(initialProofStatus);
    final proofReason = useState<String>(initialOffer['rejectionReason']?.toString() ?? '');

    final completedSteps = useState<List<int>>(getCompletedUsageSteps(userId, currentInitialPkg));
    final skippedSteps = useState<List<int>>(getSkippedUsageSteps(userId, currentInitialPkg));

    final Map<int, int> initialUsed = {};
    for (final st in usageStepsList) {
      final sNum = st['stepNumber'] ?? 0;
      initialUsed[sNum] = getStepUsedSeconds(userId, currentInitialPkg, sNum);
    }
    final stepUsedSeconds = useState<Map<int, int>>(initialUsed);

    final Map<int, int> initialCooldowns = {};
    for (int i = 0; i < usageStepsList.length; i++) {
      final stNum = usageStepsList[i]['stepNumber'] ?? (i + 1);
      final cooldownSec = (usageStepsList[i]['cooldownSeconds'] as int?) ?? (usageStepsList[i]['hoursGap'] as int? ?? 0);
      int expiry = getStepCooldownExpiry(userId, currentInitialPkg, stNum);
      if (i == 0 && expiry == 0 && cooldownSec > 0 && (!isScreenshotEnabled || initialProofStatus == 'approved') && !completedSteps.value.contains(stNum) && !skippedSteps.value.contains(stNum)) {
        expiry = DateTime.now().millisecondsSinceEpoch + (cooldownSec * 1000);
        setStepCooldownExpiry(userId, currentInitialPkg, stNum, expiry);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if (expiry > now) {
        initialCooldowns[stNum] = ((expiry - now) / 1000).ceil();
      }
    }
    final cooldownRemainingMap = useState<Map<int, int>>(initialCooldowns);
    final isClaimingUsage = useState<bool>(false);
    final isNextOfferLoading = useState<bool>(false);
    final lastLaunchTime = useRef<int?>(null);

    final lifecycleState = useAppLifecycleState();

    // Check & update app usage duration
    final updateAppUsage = useCallback(() async {
      final pkg = activePkg.value.trim();
      final bool isProofApproved = !isScreenshotEnabled || (proofStatus.value == 'approved');
      if (pkg.isEmpty || userId.isEmpty || !isProofApproved) return;

      final hasPerm = await SuperOfferNativeManager.checkUsagePermission();
      if (!hasPerm) return;

      final activeIdx = usageStepsList.indexWhere((s) {
        final sNum = s['stepNumber'] ?? 0;
        return !completedSteps.value.contains(sNum) && !skippedSteps.value.contains(sNum);
      });

      if (activeIdx != -1) {
        final activeStepNum = usageStepsList[activeIdx]['stepNumber'] ?? (activeIdx + 1);
        final targetSec = (usageStepsList[activeIdx]['usageSeconds'] as int?) ??
            ((usageStepsList[activeIdx]['minutes'] as int? ?? 5) * 60);

        int stepStartMs = getStepStartTime(userId, pkg, activeStepNum);
        if (stepStartMs <= 0) {
          stepStartMs = DateTime.now().millisecondsSinceEpoch;
          setStepStartTime(userId, pkg, activeStepNum, stepStartMs);
        }

        final durationSec = await SuperOfferNativeManager.getAppUsageDuration(pkg, stepStartMs);
        final curMap = Map<int, int>.from(stepUsedSeconds.value);
        final currentUsed = durationSec.clamp(0, targetSec);

        if (currentUsed != (curMap[activeStepNum] ?? 0)) {
          curMap[activeStepNum] = currentUsed;
          stepUsedSeconds.value = curMap;
          setStepUsedSeconds(userId, pkg, activeStepNum, currentUsed);
        }
      }
    }, [activePkg.value, userId, proofStatus.value, completedSteps.value, skippedSteps.value, usageStepsList, isScreenshotEnabled]);

    final checkProofStatus = useCallback(() async {
      if (!isScreenshotEnabled) {
        proofStatus.value = 'approved';
        return;
      }
      final pkg = activePkg.value.trim();
      if (pkg.isEmpty || userId.isEmpty) return;
      try {
        final res = await CloudFunctions.getSuperOfferProofStatus(packageName: pkg);
        if (res['success'] == true && res['status'] != null) {
          final s = res['status'].toString();
          proofStatus.value = s;
          final isSub = (s == 'approved' || s == 'pending');
          isSubmitted.value = isSub;

          // Update saved offer in storage & memory for this specific package
          final curList = List<Map<String, dynamic>>.from(savedOffers.value);
          final itemIdx = curList.indexWhere((e) => e['packageName'] == pkg);
          if (itemIdx != -1) {
            final updated = Map<String, dynamic>.from(curList[itemIdx]);
            updated['proofStatus'] = s;
            updated['proofSubmitted'] = isSub;
            if (s == 'rejected') {
              updated['rejectionReason'] = res['proof']?['rejectionReason']?.toString() ?? '';
              proofReason.value = updated['rejectionReason'];
            }
            curList[itemIdx] = updated;
            savedOffers.value = curList;
            saveOffer(userId, updated);
          }

          if (s == 'approved') {
            final firstCooldown = usageStepsList.isNotEmpty ? (usageStepsList[0]['cooldownSeconds'] as int? ?? (usageStepsList[0]['hoursGap'] as int? ?? 0)) : 0;
            if (firstCooldown > 0 && !completedSteps.value.contains(1) && !skippedSteps.value.contains(1)) {
              final existingExp = getStepCooldownExpiry(userId, pkg, 1);
              if (existingExp == 0) {
                final revAtStr = res['proof']?['reviewedAt']?.toString() ?? res['proof']?['updatedAt']?.toString();
                final revAtMs = revAtStr != null ? (DateTime.tryParse(revAtStr)?.millisecondsSinceEpoch ?? 0) : 0;
                final baseTimeMs = revAtMs > 0 ? revAtMs : DateTime.now().millisecondsSinceEpoch;
                setStepCooldownExpiry(userId, pkg, 1, baseTimeMs + (firstCooldown * 1000));
              }
            }
            ref.invalidate(DashboardService.userDataProvider(userId));
          } else if (s == 'rejected') {
            isSubmitted.value = false;
            proofReason.value = res['proof']?['rejectionReason']?.toString() ?? '';
          } else if (s == 'none') {
            isSubmitted.value = false;
            proofStatus.value = 'none';
          }
        }
      } catch (_) {}
    }, [activePkg.value, userId, usageStepsList, isScreenshotEnabled]);

    // Resumed lifecycle listener: instantly query usage when returning to Crazyreward!
    useValueChanged<AppLifecycleState?, void>(lifecycleState, (_, __) async {
      if (lifecycleState == AppLifecycleState.resumed) {
        await updateAppUsage();
      }
    });

    // Preload next offer interstitial ad in background
    useEffect(() {
      AdManager().preloadInterstitial();
      return null;
    }, const []);

    // 1. Dedicated 1-second smooth countdown ticker for all cooldowns
    useEffect(() {
      void updateCooldowns() {
        final pkg = activePkg.value.trim();
        if (pkg.isEmpty) return;

        final Map<int, int> newCooldowns = {};
        final now = DateTime.now().millisecondsSinceEpoch;
        for (int i = 0; i < usageStepsList.length; i++) {
          final stNum = usageStepsList[i]['stepNumber'] ?? (i + 1);
          final int expiry = getStepCooldownExpiry(userId, pkg, stNum);
          if (expiry > now) {
            newCooldowns[stNum] = ((expiry - now) / 1000).ceil();
          }
        }
        cooldownRemainingMap.value = newCooldowns;
      }

      // Run immediately on activePkg switch with zero delay
      updateCooldowns();

      final timer = Timer.periodic(const Duration(seconds: 1), (_) => updateCooldowns());
      return () => timer.cancel();
    }, [activePkg.value, userId, usageStepsList]);

    // 2. Separate background poller for native app usage
    useEffect(() {
      updateAppUsage();
      final usageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        updateAppUsage();
        if (isScreenshotEnabled && proofStatus.value == 'pending') {
          checkProofStatus();
        }
      });
      return () => usageTimer.cancel();
    }, [activePkg.value, userId, proofStatus.value, completedSteps.value, skippedSteps.value, updateAppUsage, checkProofStatus, isScreenshotEnabled]);

    void refreshList() {
      savedOffers.value = getSavedOffers(userId);
    }

    useEffect(() {
      syncSavedOffers(userId).then((synced) {
        final initialPkg = (packageName?.trim().isNotEmpty == true)
            ? packageName!.trim()
            : (activePkg.value.trim().isNotEmpty
                ? activePkg.value.trim()
                : (synced.isNotEmpty ? synced.first['packageName']?.toString() ?? '' : ''));

        final sortedList = List<Map<String, dynamic>>.from(synced);
        if (initialPkg.isNotEmpty) {
          final targetIdx = sortedList.indexWhere((e) => e['packageName'] == initialPkg);
          if (targetIdx > 0) {
            final item = sortedList.removeAt(targetIdx);
            sortedList.insert(0, item);
          }
        }

        savedOffers.value = sortedList;
        if (activePkg.value.isEmpty && initialPkg.isNotEmpty) {
          activePkg.value = initialPkg;
        }

        final currentPkg = activePkg.value.isNotEmpty ? activePkg.value : initialPkg;
        final currentOffer = sortedList.firstWhere(
          (e) => e['packageName'] == currentPkg,
          orElse: () => sortedList.isNotEmpty ? sortedList.first : <String, dynamic>{},
        );
        if (currentOffer.isNotEmpty) {
          resolvedAppName.value = currentOffer['appName']?.toString() ?? appName;
          final rawTime = currentOffer['installTimeText'] ?? currentOffer['installedAt'] ?? currentOffer['savedAt'];
          resolvedInstallTime.value = formatInstallTime(rawTime, savedAtMs: currentOffer['savedAt'] as int?);

          isSubmitted.value = !isScreenshotEnabled ||
              currentOffer['proofSubmitted'] == true ||
              currentOffer['proofStatus'] == 'pending' ||
              currentOffer['proofStatus'] == 'approved';
          proofStatus.value = !isScreenshotEnabled
              ? 'approved'
              : (currentOffer['proofStatus']?.toString() ?? 'none');
          proofReason.value = currentOffer['rejectionReason']?.toString() ?? '';

          if ((!isScreenshotEnabled || proofStatus.value == 'approved') && usageStepsList.isNotEmpty) {
            final firstCooldown = (usageStepsList[0]['cooldownSeconds'] as int?) ?? (usageStepsList[0]['hoursGap'] as int? ?? 0);
            if (firstCooldown > 0 && !completedSteps.value.contains(1) && !skippedSteps.value.contains(1)) {
              final existingExp = getStepCooldownExpiry(userId, currentPkg, 1);
              if (existingExp == 0) {
                final revAtStr = currentOffer['proofReviewedAt']?.toString() ?? currentOffer['savedAt']?.toString();
                final revAtMs = revAtStr != null ? (DateTime.tryParse(revAtStr)?.millisecondsSinceEpoch ?? 0) : 0;
                final baseTimeMs = revAtMs > 0 ? revAtMs : DateTime.now().millisecondsSinceEpoch;
                setStepCooldownExpiry(userId, currentPkg, 1, baseTimeMs + (firstCooldown * 1000));
              }
            }
          }
        }
        if (isScreenshotEnabled) {
          checkProofStatus();
        }
      });
      return null;
    }, [userId]);

    useEffect(() {
      final initialPkg = packageName?.trim() ?? '';
      if (initialPkg.isNotEmpty) {
        // Save to local storage for pending tasks list
        saveOffer(userId, {
          'packageName': initialPkg,
          'appName': resolvedAppName.value,
          'coins': installCoins,
          'installTimeText': resolvedInstallTime.value,
          'savedAt': DateTime.now().millisecondsSinceEpoch,
        });
        refreshList();

        // Fetch actual installed app name from device
        SuperOfferNativeManager.getAppName(initialPkg).then((name) {
          if (name != null && name.isNotEmpty) {
            resolvedAppName.value = name;
            saveOffer(userId, {
              'packageName': initialPkg,
              'appName': name,
              'coins': installCoins,
              'installTimeText': resolvedInstallTime.value,
              'savedAt': DateTime.now().millisecondsSinceEpoch,
            });
            refreshList();
          }
        });

        // Fetch actual install timestamp from device
        SuperOfferNativeManager.getInstallTime(initialPkg).then((timeMs) {
          if (timeMs > 0) {
            final timeStr = formatInstallTime(timeMs);
            resolvedInstallTime.value = timeStr;
            saveOffer(userId, {
              'packageName': initialPkg,
              'appName': resolvedAppName.value,
              'coins': installCoins,
              'installTimeText': timeStr,
              'savedAt': timeMs,
            });
            refreshList();
          }
        });
      } else if (savedOffers.value.isNotEmpty) {
        final first = savedOffers.value.first;
        activePkg.value = first['packageName']?.toString() ?? '';
        resolvedAppName.value = first['appName']?.toString() ?? appName;
        final rawTime = first['installTimeText'] ?? first['installedAt'] ?? first['savedAt'];
        resolvedInstallTime.value = formatInstallTime(rawTime, savedAtMs: first['savedAt'] as int?);
      }
      return null;
    }, [packageName]);

    useEffect(() {
      for (final offer in savedOffers.value) {
        final p = offer['packageName']?.toString() ?? '';
        if (p.isNotEmpty) {
          SuperOfferNativeManager.getInstallTime(p).then((timeMs) {
            if (timeMs > 0) {
              final formatted = formatInstallTime(timeMs);
              offer['installTimeText'] = formatted;
              if (activePkg.value == p) {
                resolvedInstallTime.value = formatted;
              }
            }
          });
          SuperOfferNativeManager.getAppName(p).then((name) {
            if (name != null && name.isNotEmpty) {
              offer['appName'] = name;
              if (activePkg.value == p) {
                resolvedAppName.value = name;
              }
            }
          });
        }
      }
      return null;
    }, [savedOffers.value.length]);

    Future<void> pickImage() async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1080,
          maxHeight: 1920,
          imageQuality: 65,
        );

        if (pickedFile != null) {
          selectedImage.value = File(pickedFile.path);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to select image from gallery.')),
          );
        }
      }
    }

    Future<void> submitProof() async {
      if (selectedImage.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a screenshot proof first.')),
        );
        return;
      }
      isUploading.value = true;
      try {
        final imageBytes = await selectedImage.value!.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

        final success = await CloudFunctions.submitSuperOfferScreenshot(
          userId: userId,
          packageName: activePkg.value,
          appName: resolvedAppName.value,
          imageUrl: base64Image,
          coins: screenshotCoins,
        );

        await checkProofStatus();

        if (success || proofStatus.value == 'pending') {
          isSubmitted.value = true;
          proofStatus.value = 'pending';
          saveOffer(userId, {
            'packageName': activePkg.value,
            'appName': resolvedAppName.value,
            'coins': installCoins,
            'installTimeText': resolvedInstallTime.value,
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'step1Claimed': true,
            'proofSubmitted': true,
            'proofStatus': 'pending',
          });
          // Screenshot proof submitted: record claim timestamp and set isOfferUnlocked to false!
          SuperOfferWidget.recordClaimTs(userId);
          SuperOfferWidget.setOfferUnlocked(userId, false);
          refreshList();
          ref.invalidate(DashboardService.userDataProvider(userId));
          ref.invalidate(superOfferVerifierProvider(userId));
          ref.invalidate(pendingOffersProvider(userId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF16A34A),
                content: Text('Screenshot proof submitted successfully! Under review.'),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to submit proof. Please try again.')),
            );
          }
        }
      } catch (e) {
        await checkProofStatus();
        if (proofStatus.value == 'pending') {
          isSubmitted.value = true;
          saveOffer(userId, {
            'packageName': activePkg.value,
            'appName': resolvedAppName.value,
            'coins': installCoins,
            'installTimeText': resolvedInstallTime.value,
            'savedAt': DateTime.now().millisecondsSinceEpoch,
            'step1Claimed': true,
            'proofSubmitted': true,
            'proofStatus': 'pending',
          });
          // Screenshot proof submitted: record claim timestamp and set isOfferUnlocked to false!
          SuperOfferWidget.recordClaimTs(userId);
          SuperOfferWidget.setOfferUnlocked(userId, false);
          refreshList();
          ref.invalidate(DashboardService.userDataProvider(userId));
          ref.invalidate(superOfferVerifierProvider(userId));
          ref.invalidate(pendingOffersProvider(userId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF16A34A),
                content: Text('Screenshot proof submitted successfully! Under review.'),
              ),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to submit proof. Please try again.')),
          );
        }
      } finally {
        isUploading.value = false;
      }
    }

    void showRemoveDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
            side: BorderSide(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          backgroundColor: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(22.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFCA5A5),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: const Color(0xFFEF4444),
                    size: 26.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Remove Offer?',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Are you sure you want to remove "${resolvedAppName.value}" from your offers list?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 22.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 44.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF64748B),
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          
                          // Show progress indicator
                          BuildContext? loadingCtx;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (c) {
                              loadingCtx = c;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFAB31DE),
                                ),
                              );
                            },
                          );

                          try {
                            await CloudFunctions.logSuperOfferActivity(
                              packageName: activePkg.value,
                              appName: resolvedAppName.value,
                              stepType: 'removed',
                              status: 'removed',
                            );
                            removeOffer(userId, activePkg.value);
                            ref.invalidate(DashboardService.userDataProvider(userId));
                            ref.invalidate(superOfferVerifierProvider(userId));
                            ref.invalidate(pendingOffersProvider(userId));
                          } catch (_) {}

                          if (loadingCtx != null && loadingCtx!.mounted) {
                            Navigator.pop(loadingCtx!);
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFFEF4444),
                                content: Text('Offer removed from list.'),
                              ),
                            );
                          }
                        },
                        child: Container(
                          height: 44.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFF87171),
                                Color(0xFFEF4444),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            'REMOVE',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
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

    final hasPendingOffer = (packageName != null && packageName!.isNotEmpty) || savedOffers.value.isNotEmpty;

    final tutorialUrl = SplashService.superOfferConfig['tutorialUrl']?.toString() ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          ref.invalidate(pendingOffersProvider(userId));
          ref.invalidate(superOfferVerifierProvider(userId));
          ref.invalidate(DashboardService.userDataProvider(userId));
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                // 1. TOP APP BAR
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.invalidate(pendingOffersProvider(userId));
                          ref.invalidate(superOfferVerifierProvider(userId));
                          ref.invalidate(DashboardService.userDataProvider(userId));
                          Navigator.pop(context);
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
                        'Super Offers',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 18.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      if (tutorialUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            LaunchUrl.inApp(url: tutorialUrl, context: context);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: const Color(0xFFEF4444),
                                  size: 16.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'Watch Tutorial',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // 2. MAIN CONTENT
              if (!hasPendingOffer)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 76.w,
                            height: 76.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE39FFF).withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.checklist_rounded,
                              color: const Color(0xFFAB31DE),
                              size: 38.sp,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'No Pending Offers',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'You do not have any pending offers right now. Complete super offers to see your active tasks here!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF64748B),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MULTIPLE INSTALLED APPS SELECTOR (IF MORE THAN 1 SAVED)
                        if (savedOffers.value.length > 1) ...[
                          SizedBox(
                            height: 38.h,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: savedOffers.value.length,
                              separatorBuilder: (_, __) => SizedBox(width: 8.w),
                              itemBuilder: (context, idx) {
                                final item = savedOffers.value[idx];
                                final isSelected = item['packageName'] == activePkg.value;
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    final pkg = item['packageName']?.toString() ?? '';
                                    activePkg.value = pkg;
                                    resolvedAppName.value = item['appName']?.toString() ?? 'Offer App';
                                    final rawTime = item['installTimeText'] ?? item['installedAt'] ?? item['savedAt'];
                                    resolvedInstallTime.value = formatInstallTime(rawTime, savedAtMs: item['savedAt'] as int?);

                                    final rawStatus = item['proofStatus']?.toString();
                                    final pStatus = (rawStatus != null && rawStatus.isNotEmpty && rawStatus != 'not_submitted' && rawStatus != 'none')
                                        ? rawStatus
                                        : (item['proofSubmitted'] == true ? 'pending' : 'none');

                                    final isSub = !isScreenshotEnabled ||
                                        item['proofSubmitted'] == true ||
                                        pStatus == 'pending' ||
                                        pStatus == 'approved';

                                    isSubmitted.value = isSub;
                                    proofStatus.value = !isScreenshotEnabled ? 'approved' : pStatus;
                                    proofReason.value = item['rejectionReason']?.toString() ?? '';
                                    final cSteps = getCompletedUsageSteps(userId, pkg);
                                    final sSteps = getSkippedUsageSteps(userId, pkg);
                                    completedSteps.value = cSteps;
                                    skippedSteps.value = sSteps;

                                    // Check if first step cooldown needs initialization for this package
                                    if ((!isScreenshotEnabled || pStatus == 'approved') && usageStepsList.isNotEmpty) {
                                      final firstCooldown = (usageStepsList[0]['cooldownSeconds'] as int?) ?? (usageStepsList[0]['hoursGap'] as int? ?? 0);
                                      if (firstCooldown > 0 && !cSteps.contains(1) && !sSteps.contains(1)) {
                                        final existingExp = getStepCooldownExpiry(userId, pkg, 1);
                                        if (existingExp == 0) {
                                          final revAtStr = item['proofReviewedAt']?.toString() ?? item['savedAt']?.toString();
                                          final revAtMs = revAtStr != null ? (DateTime.tryParse(revAtStr)?.millisecondsSinceEpoch ?? 0) : 0;
                                          final baseTimeMs = revAtMs > 0 ? revAtMs : DateTime.now().millisecondsSinceEpoch;
                                          setStepCooldownExpiry(userId, pkg, 1, baseTimeMs + (firstCooldown * 1000));
                                        }
                                      }
                                    }

                                    // Instantly update cooldowns and used seconds synchronously for the selected package!
                                    final Map<int, int> newCooldowns = {};
                                    final Map<int, int> newUsed = {};
                                    final nowMs = DateTime.now().millisecondsSinceEpoch;
                                    for (int i = 0; i < usageStepsList.length; i++) {
                                      final stNum = usageStepsList[i]['stepNumber'] ?? (i + 1);
                                      newUsed[stNum] = getStepUsedSeconds(userId, pkg, stNum);
                                      final int expiry = getStepCooldownExpiry(userId, pkg, stNum);
                                      if (expiry > nowMs) {
                                        newCooldowns[stNum] = ((expiry - nowMs) / 1000).ceil();
                                      }
                                    }
                                    cooldownRemainingMap.value = newCooldowns;
                                    stepUsedSeconds.value = newUsed;

                                    if (isScreenshotEnabled) {
                                      checkProofStatus();
                                    }
                                    updateAppUsage();

                                    if (pkg.isNotEmpty) {
                                      SuperOfferNativeManager.getInstallTime(pkg).then((timeMs) {
                                        if (timeMs > 0 && activePkg.value == pkg) {
                                          final formatted = formatInstallTime(timeMs);
                                          resolvedInstallTime.value = formatted;
                                          item['installTimeText'] = formatted;
                                        }
                                      });
                                      SuperOfferNativeManager.getAppName(pkg).then((name) {
                                        if (name != null && name.isNotEmpty && activePkg.value == pkg) {
                                          resolvedAppName.value = name;
                                          item['appName'] = name;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      gradient: isSelected
                                          ? const LinearGradient(
                                              colors: [
                                                Color(0xFFE39FFF),
                                                Color(0xFFAB31DE),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            )
                                          : null,
                                      color: isSelected ? null : Colors.white,
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: isSelected ? Colors.transparent : const Color(0xFFF1F5F9),
                                        width: 1.2,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFAB31DE).withValues(alpha: 0.2),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [
                                              BoxShadow(
                                                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        item['appName']?.toString() ?? 'Offer ${idx + 1}',
                                        style: GoogleFonts.outfit(
                                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 12.h),
                        ],

                        // TOP APP HEADER CARD (WHITE THEME)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color(0xFFF1F5F9),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48.w,
                                height: 48.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: const Color(0xFFF3E8FF),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.card_giftcard_rounded,
                                    color: const Color(0xFFAB31DE),
                                    size: 24.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      resolvedAppName.value,
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF1E1B4B),
                                        fontSize: 16.5.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          color: const Color(0xFFAB31DE),
                                          size: 13.sp,
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          resolvedInstallTime.value,
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF64748B),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
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

                        // REWARDS SECTION HEADER
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events_rounded,
                              color: const Color(0xFFAB31DE),
                              size: 18.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'REWARDS',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12.h),

                        // CARD 1: INSTALL APP (WHITE THEME - APPROVED)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: const Color(0xFF86EFAC),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42.w,
                                height: 42.w,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF15803D),
                                    size: 24,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Install App',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF1E1B4B),
                                        fontSize: 15.5.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Install app and use it for a couple of minutes.',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF64748B),
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/icons/coin.png',
                                        width: 13.w,
                                        height: 13.w,
                                        fit: BoxFit.contain,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        '$installCoins Coins',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFAB31DE),
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: const Color(0xFFA7F3D0),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      'Done',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF15803D),
                                        fontSize: 10.5.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (isScreenshotEnabled) ...[
                          SizedBox(height: 12.h),

                          // CARD 2: SCREENSHOT (GREEN THEME IF APPROVED, PURPLE ACCENT IF NOT)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: proofStatus.value == 'approved'
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: proofStatus.value == 'approved'
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFF3E8FF),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: proofStatus.value == 'approved'
                                      ? const Color(0xFF10B981).withValues(alpha: 0.04)
                                      : const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 42.w,
                                      height: 42.w,
                                      decoration: BoxDecoration(
                                        color: proofStatus.value == 'approved'
                                            ? const Color(0xFFDCFCE7)
                                            : const Color(0xFFFAF5FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          proofStatus.value == 'approved'
                                              ? Icons.check_circle_rounded
                                              : Icons.camera_alt_rounded,
                                          color: proofStatus.value == 'approved'
                                              ? const Color(0xFF15803D)
                                              : const Color(0xFFAB31DE),
                                          size: proofStatus.value == 'approved' ? 24 : 22,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Upload Screenshot',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF1E1B4B),
                                              fontSize: 15.5.sp,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            'Sign up in the app & take a screenshot and upload it.',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF64748B),
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.asset(
                                              'assets/icons/coin.png',
                                              width: 13.w,
                                              height: 13.w,
                                              fit: BoxFit.contain,
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              '$screenshotCoins Coins',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFFAB31DE),
                                                fontSize: 13.5.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (proofStatus.value == 'pending') ...[
                                          SizedBox(height: 4.h),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(6.r),
                                              border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                                            ),
                                            child: Text(
                                              'Pending',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFFB45309),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ] else if (proofStatus.value == 'approved') ...[
                                          SizedBox(height: 4.h),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(6.r),
                                              border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                                            ),
                                            child: Text(
                                              'Done',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF15803D),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ] else if (proofStatus.value == 'rejected') ...[
                                          SizedBox(height: 4.h),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(6.r),
                                              border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
                                            ),
                                            child: Text(
                                              'Rejected',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFFB91C1C),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),

                                if (proofStatus.value != 'approved') ...[
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14.h),
                                    child: const Divider(color: Color(0xFFF1F5F9), height: 1),
                                  ),
                                  if (proofStatus.value == 'pending') ...[
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(14.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(14.r),
                                        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.access_time_rounded, color: const Color(0xFFB45309), size: 18.sp),
                                              SizedBox(width: 8.w),
                                              Text(
                                                'Pending Review',
                                                style: GoogleFonts.outfit(
                                                  color: const Color(0xFFB45309),
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 6.h),
                                          Text(
                                            'Your Screenshot is under admin review, coins will be awarded after approval.',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF78350F),
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    if (proofStatus.value == 'rejected') ...[
                                      Container(
                                        width: double.infinity,
                                        margin: EdgeInsets.only(bottom: 14.h),
                                        padding: EdgeInsets.all(12.w),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(12.r),
                                          border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.cancel_rounded, color: const Color(0xFFB91C1C), size: 16.sp),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  'Proof Rejected',
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFFB91C1C),
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (proofReason.value.isNotEmpty) ...[
                                              SizedBox(height: 4.h),
                                              Text(
                                                'Reason: ${proofReason.value}',
                                                style: GoogleFonts.outfit(
                                                  color: const Color(0xFF991B1B),
                                                  fontSize: 11.5.sp,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                            SizedBox(height: 4.h),
                                            Text(
                                              'Please upload a valid screenshot proof below to submit again.',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF7F1D1D),
                                                fontSize: 11.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    Text(
                                      '1: Sign up in the app or Register in the app.\n2: Or if it is a game, play the game until level 3.\n3: Take a screenshot of the installed app\'s profile section or level section and upload it.',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF64748B),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        height: 1.45,
                                      ),
                                    ),
                                    SizedBox(height: 14.h),
                                    // UPLOAD BOX
                                    GestureDetector(
                                      onTap: pickImage,
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(16.r),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: selectedImage.value != null
                                            ? Column(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(10.r),
                                                    child: Image.file(
                                                      selectedImage.value!,
                                                      height: 80.h,
                                                      width: double.infinity,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                  SizedBox(height: 6.h),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        Icons.change_circle_outlined,
                                                        color: const Color(0xFFAB31DE),
                                                        size: 16.sp,
                                                      ),
                                                      SizedBox(width: 6.w),
                                                      Text(
                                                        'Tap to change screenshot',
                                                        style: GoogleFonts.outfit(
                                                          color: const Color(0xFFAB31DE),
                                                          fontSize: 12.sp,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                children: [
                                                  Container(
                                                    width: 36.w,
                                                    height: 36.w,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFAF5FF),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: const Color(0xFFF3E8FF),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.add_photo_alternate_rounded,
                                                        color: const Color(0xFFAB31DE),
                                                        size: 20.sp,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 6.h),
                                                  Text(
                                                    'Select Screenshot',
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(0xFF1E1B4B),
                                                      fontSize: 13.5.sp,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    'Upload proof that you installed & completed task',
                                                    textAlign: TextAlign.center,
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(0xFF64748B),
                                                      fontSize: 11.sp,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                    SizedBox(height: 14.h),
                                    // WARNING BANNER
                                    Container(
                                      padding: EdgeInsets.all(10.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(10.r),
                                        border: Border.all(
                                          color: const Color(0xFFFEE2E2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: const Color(0xFFEF4444),
                                            size: 16.sp,
                                          ),
                                          SizedBox(width: 6.w),
                                          Expanded(
                                            child: Text(
                                              'Note: Admins verify all submissions manually. Submitting fake, edited, or incorrect screenshots will lead to permanent account suspension!',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF991B1B),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 14.h),
                                    // SUBMIT PROOF BUTTON
                                    GestureDetector(
                                      onTap: isUploading.value ? null : submitProof,
                                      child: Container(
                                        height: 44.h,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFE39FFF),
                                              Color(0xFFAB31DE),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(14.r),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: isUploading.value
                                              ? SizedBox(
                                                  width: 20.w,
                                                  height: 20.w,
                                                  child: const CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.file_upload_outlined,
                                                      color: Colors.white,
                                                      size: 18.sp,
                                                    ),
                                                    SizedBox(width: 6.w),
                                                    Text(
                                                      proofStatus.value == 'rejected' ? 'Re-upload Screenshot Proof' : 'Submit Proof',
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white,
                                                        fontSize: 14.sp,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 12.h),

                        // DYNAMIC APP USAGE MULTI-STEP CARDS
                        ...usageStepsList.asMap().entries.map((entry) {
                          final int idx = entry.key;
                          final step = entry.value;
                          final stepNumber = step['stepNumber'] ?? (idx + 1);
                          final int targetSec = (step['usageSeconds'] as int?) ??
                              ((step['minutes'] as int? ?? 5) * 60);
                          final int stepMins = (step['minutes'] as int?) ?? (targetSec ~/ 60);
                          final usedSec = stepUsedSeconds.value[stepNumber] ?? getStepUsedSeconds(userId, activePkg.value, stepNumber);
                          final isCompleted = completedSteps.value.contains(stepNumber);
                          final isSkipped = skippedSteps.value.contains(stepNumber);
                          final isDone = isCompleted || isSkipped;

                          int cooldownRem = cooldownRemainingMap.value[stepNumber] ?? 0;
                          if (cooldownRem <= 0 && !isDone) {
                            final exp = getStepCooldownExpiry(userId, activePkg.value, stepNumber);
                            final n = DateTime.now().millisecondsSinceEpoch;
                            if (exp > n) {
                              cooldownRem = ((exp - n) / 1000).ceil();
                            }
                          }
                          final isCooldown = cooldownRem > 0 && !isDone;

                          // Check if all prior usage steps are completed or skipped
                          bool priorStepsDone = true;
                          for (int i = 0; i < idx; i++) {
                            final pNum = usageStepsList[i]['stepNumber'] ?? (i + 1);
                            if (!completedSteps.value.contains(pNum) && !skippedSteps.value.contains(pNum)) {
                              priorStepsDone = false;
                              break;
                            }
                          }

                          final bool isProofApproved = !isScreenshotEnabled || (proofStatus.value == 'approved');
                          final bool isActive = isProofApproved && priorStepsDone && !isDone && !isCooldown;

                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _buildUsageStepCard(
                              context: context,
                              step: step,
                              stepIndex: idx,
                              isCompleted: isCompleted,
                              isSkipped: isSkipped,
                              isActive: isActive,
                              isCooldown: isCooldown,
                              cooldownRemainingSec: cooldownRem,
                              usedSeconds: usedSec,
                              targetSeconds: targetSec,
                              isClaiming: isClaimingUsage.value,
                              onOpenApp: () async {
                                final pkg = activePkg.value.trim();
                                if (pkg.isNotEmpty) {
                                  lastLaunchTime.value = DateTime.now().millisecondsSinceEpoch;
                                  int stepStartMs = getStepStartTime(userId, pkg, stepNumber);
                                  if (stepStartMs <= 0) {
                                    stepStartMs = DateTime.now().millisecondsSinceEpoch;
                                    setStepStartTime(userId, pkg, stepNumber, stepStartMs);
                                  }
                                  final bool launched = await SuperOfferNativeManager.launchApp(pkg);
                                  if (!launched) {
                                    if (context.mounted) {
                                      await CustomStatusPopup.show(
                                        context: context,
                                        type: StatusPopupType.failed,
                                        title: 'App Uninstalled',
                                        message: 'Oops! It looks like you have uninstalled this app. Since the app is deleted, you cannot continue this task, and the remaining rewards will be missed.',
                                        primaryButtonText: 'OK',
                                        onPrimaryTap: () async {
                                          HapticFeedback.mediumImpact();
                                          Navigator.pop(context); // Close the popup
                                          
                                          // Show a progress indicator
                                          BuildContext? dialogContext;
                                          if (context.mounted) {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (ctx) {
                                                dialogContext = ctx;
                                                return const Center(
                                                  child: CircularProgressIndicator(
                                                    color: Color(0xFFAB31DE),
                                                  ),
                                                );
                                              },
                                            );
                                          }

                                          try {
                                            // 1. Mark status as 'uninstalled' on the backend
                                            await CloudFunctions.logSuperOfferActivity(
                                              packageName: pkg,
                                              appName: resolvedAppName.value,
                                              stepType: 'uninstalled',
                                              status: 'uninstalled',
                                            );
                                            
                                            // 2. Remove the offer from local storage
                                            removeOffer(userId, pkg);

                                            // 3. Invalidate providers to force main screen to reload
                                            ref.invalidate(DashboardService.userDataProvider(userId));
                                            ref.invalidate(superOfferVerifierProvider(userId));
                                            ref.invalidate(pendingOffersProvider(userId));
                                          } catch (_) {}
                                          
                                          // Close progress indicator and pop Task Progress screen safely
                                          if (dialogContext != null && dialogContext!.mounted) {
                                            Navigator.pop(dialogContext!); // Close loading dialog
                                          }
                                          if (context.mounted) {
                                            Navigator.pop(context); // Pop Task Progress Screen
                                          }
                                        },
                                      );
                                    }
                                  }
                                }
                              },
                              onSkip: () async {
                                final stCoins = step['coins'] as int? ?? 0;
                                await CustomStatusPopup.show(
                                  context: context,
                                  type: StatusPopupType.warning,
                                  title: 'Skip This Step?',
                                  message: 'If you skip this step, you will miss the reward of 🪙 $stCoins Coins. Are you sure you want to skip and move directly to the next step?',
                                  primaryButtonText: 'CANCEL',
                                  primaryButtonColor: const Color(0xFF64748B),
                                  onPrimaryTap: () {
                                    Navigator.pop(context);
                                  },
                                  secondaryButtonText: 'SKIP',
                                  onSecondaryTap: () async {
                                    Navigator.pop(context);
                                    if (isClaimingUsage.value) return;
                                    isClaimingUsage.value = true;
                                    try {
                                      final pkg = activePkg.value.trim();
                                      final stName = step['name']?.toString() ?? 'Use App';
                                      final int effectiveStepNum = isScreenshotEnabled ? (stepNumber + 2) : (stepNumber + 1);

                                      await CloudFunctions.claimSuperOfferUsageStep(
                                        packageName: pkg,
                                        appName: resolvedAppName.value,
                                        stepNumber: effectiveStepNum,
                                        stepName: stName,
                                        coins: 0,
                                        usageMinutes: 0,
                                        userId: userId,
                                        status: 'skipped',
                                      );

                                      markUsageStepSkipped(userId, pkg, stepNumber);
                                      skippedSteps.value = getSkippedUsageSteps(userId, pkg);

                                      // Cooldown for next step
                                      if (idx + 1 < usageStepsList.length) {
                                        final nextStep = usageStepsList[idx + 1];
                                        final nextStNum = nextStep['stepNumber'] ?? (idx + 2);
                                        setStepStartTime(userId, pkg, nextStNum, DateTime.now().millisecondsSinceEpoch);
                                        final nextCooldownSec = nextStep['cooldownSeconds'] as int? ?? (nextStep['hoursGap'] as int? ?? 0);
                                        if (nextCooldownSec > 0) {
                                          final expiryMs = DateTime.now().millisecondsSinceEpoch + (nextCooldownSec * 1000);
                                          setStepCooldownExpiry(userId, pkg, nextStNum, expiryMs);
                                          final newCooldowns = Map<int, int>.from(cooldownRemainingMap.value);
                                          newCooldowns[nextStNum] = nextCooldownSec;
                                          cooldownRemainingMap.value = newCooldowns;
                                        }
                                      }

                                      ref.invalidate(DashboardService.userDataProvider(userId));
                                      ref.invalidate(pendingOffersProvider(userId));

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            backgroundColor: Color(0xFFE11D48),
                                            content: Text('Step skipped (0 Coins reward). Next step unlocked.'),
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                    } finally {
                                      isClaimingUsage.value = false;
                                    }
                                  },
                                );
                              },
                              onClaim: () async {
                                if (isClaimingUsage.value) return;
                                isClaimingUsage.value = true;
                                try {
                                  final pkg = activePkg.value.trim();
                                  final stCoins = step['coins'] as int? ?? 0;
                                  final stName = step['name']?.toString() ?? 'Use App';
                                  final int effectiveStepNum = isScreenshotEnabled ? (stepNumber + 2) : (stepNumber + 1);

                                  final success = await CloudFunctions.claimSuperOfferUsageStep(
                                    packageName: pkg,
                                    appName: resolvedAppName.value,
                                    stepNumber: effectiveStepNum,
                                    stepName: stName,
                                    coins: stCoins,
                                    usageMinutes: stepMins,
                                    userId: userId,
                                  );

                                  if (success) {
                                    markUsageStepCompleted(userId, pkg, stepNumber);
                                    completedSteps.value = getCompletedUsageSteps(userId, pkg);

                                    // Cooldown for next step
                                    if (idx + 1 < usageStepsList.length) {
                                      final nextStep = usageStepsList[idx + 1];
                                      final nextStNum = nextStep['stepNumber'] ?? (idx + 2);
                                      setStepStartTime(userId, pkg, nextStNum, DateTime.now().millisecondsSinceEpoch);
                                      final nextCooldownSec = nextStep['cooldownSeconds'] as int? ?? (nextStep['hoursGap'] as int? ?? 0);
                                      if (nextCooldownSec > 0) {
                                        final expiryMs = DateTime.now().millisecondsSinceEpoch + (nextCooldownSec * 1000);
                                        setStepCooldownExpiry(userId, pkg, nextStNum, expiryMs);
                                        final newCooldowns = Map<int, int>.from(cooldownRemainingMap.value);
                                        newCooldowns[nextStNum] = nextCooldownSec;
                                        cooldownRemainingMap.value = newCooldowns;
                                      }
                                    } else {
                                      SuperOfferWidget.setOfferUnlocked(userId, false);
                                    }

                                    ref.invalidate(DashboardService.userDataProvider(userId));
                                    ref.invalidate(pendingOffersProvider(userId));

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: const Color(0xFF16A34A),
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                              SizedBox(width: 8.w),
                                              Expanded(
                                                child: Text(
                                                  'Awesome! +$stCoins Coins added to your wallet! 🎉',
                                                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFFEF4444),
                                        content: Text('Failed to claim coins: $e'),
                                      ),
                                    );
                                  }
                                } finally {
                                  isClaimingUsage.value = false;
                                }
                              },
                            ),
                          );
                        }),

                        SizedBox(height: 20.h),

                        // TOTAL POTENTIAL EARNINGS CARD (WHITE THEME)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Total Reward',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/icons/coin.png',
                                    width: 18.w,
                                    height: 18.w,
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    '$totalPotentialEarnings Coins',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 20.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),

                        if ((!isScreenshotEnabled || proofStatus.value == 'approved') &&
                            (usageStepsList.isEmpty || usageStepsList.every((s) {
                              final sNum = s['stepNumber'] ?? 1;
                              return completedSteps.value.contains(sNum) || skippedSteps.value.contains(sNum);
                            }))) ...[
                          // NEXT OFFER BUTTON (VIBRANT PREMIUM GREEN GRADIENT)
                          GestureDetector(
                            onTap: () async {
                              if (isNextOfferLoading.value) return;
                              HapticFeedback.mediumImpact();
                              isNextOfferLoading.value = true;
                              try {
                                final pkg = activePkg.value.trim();
                                await AdManager().showInterstitialAd(
                                  onClosed: () async {
                                    if (pkg.isNotEmpty) {
                                      removeOffer(userId, pkg);
                                    }
                                    SuperOfferWidget.setOfferUnlocked(userId, false);
                                    ref.invalidate(DashboardService.userDataProvider(userId));
                                    ref.invalidate(superOfferVerifierProvider(userId));
                                    ref.invalidate(pendingOffersProvider(userId));
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                );
                              } catch (_) {
                                final pkg = activePkg.value.trim();
                                if (pkg.isNotEmpty) {
                                  removeOffer(userId, pkg);
                                }
                                SuperOfferWidget.setOfferUnlocked(userId, false);
                                ref.invalidate(DashboardService.userDataProvider(userId));
                                ref.invalidate(superOfferVerifierProvider(userId));
                                ref.invalidate(pendingOffersProvider(userId));
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              } finally {
                                if (context.mounted) {
                                  isNextOfferLoading.value = false;
                                }
                              }
                            },
                            child: Container(
                              height: 48.h,
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
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isNextOfferLoading.value
                                    ? SizedBox(
                                        width: 18.w,
                                        height: 18.w,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Next Offer',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          SizedBox(width: 6.w),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 16.sp,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // REMOVE OFFER BUTTON (WHITE WITH RED BORDER)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              showRemoveDialog(context);
                            },
                            child: Container(
                              height: 48.h,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: const Color(0xFFFEE2E2),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Remove Offer',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFE11D48),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 24.h),
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

  Widget _buildUsageStepCard({
    required BuildContext context,
    required Map<String, dynamic> step,
    required int stepIndex,
    required bool isCompleted,
    required bool isSkipped,
    required bool isActive,
    required bool isCooldown,
    required int cooldownRemainingSec,
    required int usedSeconds,
    required int targetSeconds,
    required bool isClaiming,
    required VoidCallback onOpenApp,
    required VoidCallback onSkip,
    required VoidCallback onClaim,
  }) {
    final stepCoins = step['coins'] as int? ?? 0;

    final String usageTargetText = targetSeconds >= 60 && targetSeconds % 60 == 0
        ? '${targetSeconds ~/ 60} mins'
        : (targetSeconds >= 60 ? '${(targetSeconds / 60).toStringAsFixed(1)} mins' : '${targetSeconds}s');

    final String usageTargetLongText = targetSeconds >= 60 && targetSeconds % 60 == 0
        ? '${targetSeconds ~/ 60} minutes'
        : (targetSeconds >= 60 ? '${(targetSeconds / 60).toStringAsFixed(1)} minutes' : '$targetSeconds seconds');

    final bool canClaim = usedSeconds >= targetSeconds;
    final String baseTitle = 'Use App';

    if (isSkipped) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFFEE2E2), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.skip_next_rounded, color: Color(0xFFB91C1C), size: 24),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baseTitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Usage Skipped',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFB91C1C),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: const Color(0xFFFECACA), width: 0.8),
              ),
              child: Text(
                'SKIPPED (0 🪙)',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFB91C1C),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isCompleted) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 24),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baseTitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Use app for $usageTargetLongText',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/coin.png',
                      width: 13.w,
                      height: 13.w,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '$stepCoins Coins',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFAB31DE),
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF15803D),
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (isCooldown) {
      String formatRemaining(int sec) {
        if (sec < 60) return '$sec sec';
        if (sec < 3600) return '${(sec / 60).ceil()} mins';
        return '${(sec / 3600).toStringAsFixed(1)} hrs';
      }

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFFEF3C7), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309), size: 20),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    baseTitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Unlocks in ${formatRemaining(cooldownRemainingSec)}',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFB45309),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/coin.png',
                  width: 13.w,
                  height: 13.w,
                  fit: BoxFit.contain,
                ),
                SizedBox(width: 4.w),
                Text(
                  '$stepCoins Coins',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFAB31DE),
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (!isActive) {
      return _buildLockedCard(baseTitle, 'Use app for $usageTargetText', stepCoins);
    }

    // ACTIVE STEP
    final double progress = targetSeconds > 0 ? (usedSeconds / targetSeconds).clamp(0.0, 1.0) : 0.0;

    String formatTime(int sec) {
      final m = (sec ~/ 60).toString().padLeft(2, '0');
      final s = (sec % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    // Dynamic Step Themes (Rainbow palette)
    final List<_StepTheme> stepThemes = [
      _StepTheme(
        primaryColor: const Color(0xFFAB31DE), // Violet
        lightBgColor: const Color(0xFFFAF5FF),
        buttonGradient: const [Color(0xFFE39FFF), Color(0xFFAB31DE)],
        badgeBorder: const Color(0xFFE39FFF),
      ),
      _StepTheme(
        primaryColor: const Color(0xFF2563EB), // Blue
        lightBgColor: const Color(0xFFEFF6FF),
        buttonGradient: const [Color(0xFF60A5FA), Color(0xFF2563EB)],
        badgeBorder: const Color(0xFF93C5FD),
      ),
      _StepTheme(
        primaryColor: const Color(0xFFEA580C), // Orange
        lightBgColor: const Color(0xFFFFF7ED),
        buttonGradient: const [Color(0xFFFDBA74), Color(0xFFEA580C)],
        badgeBorder: const Color(0xFFFFD9B3),
      ),
      _StepTheme(
        primaryColor: const Color(0xFFDB2777), // Pink
        lightBgColor: const Color(0xFFFFF1F2),
        buttonGradient: const [Color(0xFFF472B6), Color(0xFFDB2777)],
        badgeBorder: const Color(0xFFFBCFE8),
      ),
      _StepTheme(
        primaryColor: const Color(0xFF0F766E), // Teal
        lightBgColor: const Color(0xFFF0FDFA),
        buttonGradient: const [Color(0xFF2DD4BF), Color(0xFF0F766E)],
        badgeBorder: const Color(0xFF99F6E4),
      ),
    ];

    // Select the theme for this step (or Green if canClaim)
    final currentTheme = canClaim
        ? _StepTheme(
            primaryColor: const Color(0xFF10B981), // Green
            lightBgColor: const Color(0xFFDCFCE7),
            buttonGradient: const [Color(0xFF34D399), Color(0xFF10B981)],
            badgeBorder: const Color(0xFFA7F3D0),
          )
        : stepThemes[stepIndex % stepThemes.length];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: currentTheme.lightBgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: currentTheme.primaryColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: currentTheme.primaryColor.withValues(alpha: 0.12),
            blurRadius: 16,
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
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: currentTheme.lightBgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.timer_outlined,
                    color: currentTheme.primaryColor,
                    size: 22,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baseTitle,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Use app for $usageTargetLongText',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/coin.png',
                        width: 13.w,
                        height: 13.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '$stepCoins Coins',
                        style: GoogleFonts.outfit(
                          color: currentTheme.primaryColor,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: currentTheme.lightBgColor,
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: currentTheme.badgeBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      canClaim ? 'READY' : 'ACTIVE',
                      style: GoogleFonts.outfit(
                        color: currentTheme.primaryColor,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // PROGRESS BAR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Usage Progress',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B),
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formatTime(usedSeconds),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Container(
            height: 8.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * progress,
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: currentTheme.primaryColor,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 16.h),

          // BUTTONS
          if (!canClaim) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: onOpenApp,
                    child: Container(
                      height: 44.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: currentTheme.buttonGradient,
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: currentTheme.primaryColor.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.launch_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 6.w),
                          Text(
                            'OPEN APP',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFEE2E2), width: 1.2),
                      backgroundColor: const Color(0xFFFEF2F2),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                        SizedBox(width: 4.w),
                        Text(
                          'SKIP',
                          style: GoogleFonts.outfit(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: isClaiming ? null : onClaim,
              child: Container(
                width: double.infinity,
                height: 46.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: currentTheme.buttonGradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: currentTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: isClaiming
                    ? SizedBox(
                        height: 20.w,
                        width: 20.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                          SizedBox(width: 8.w),
                          Text(
                            'COLLECT $stepCoins COINS',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLockedCard(String title, String subtitle, int coins) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.lock_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Locked',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/icons/coin.png',
                  width: 13.w,
                  height: 13.w,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '$coins Coins',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _StepTheme {
  final Color primaryColor;
  final Color lightBgColor;
  final List<Color> buttonGradient;
  final Color badgeBorder;

  _StepTheme({
    required this.primaryColor,
    required this.lightBgColor,
    required this.buttonGradient,
    required this.badgeBorder,
  });
}

