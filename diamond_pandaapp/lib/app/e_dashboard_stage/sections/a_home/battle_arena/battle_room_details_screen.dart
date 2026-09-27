import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../provider/dashboard_provider.dart';
import '../super_offer/super_offer_native_manager.dart';
import 'battle_arena_provider.dart';
import 'matching_partner_screen.dart';
import '../../../../../../widgets/common/custom_loading.dart';
import '../../../../../../services/ad_manager.dart';
import '../../../../../../services/local_storage.dart';
import '../../../../../../widgets/common/custom_toast.dart';
import '../../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../../services/cloud_functions.dart';
import '../../../../d_authentication_stage/users_data_model.dart';

class BattleRoomDetailsScreen extends ConsumerStatefulWidget {
  final String userId;
  final Map<String, dynamic> match;

  const BattleRoomDetailsScreen({
    super.key,
    required this.userId,
    required this.match,
  });

  @override
  ConsumerState<BattleRoomDetailsScreen> createState() => _BattleRoomDetailsScreenState();
}

class _BattleRoomDetailsScreenState extends ConsumerState<BattleRoomDetailsScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  late Map<String, dynamic> _matchData;
  int _activeTab = 0; // 0: Prize Pool, 1: Terms
  BuildContext? _installSheetContext;

  // Install Task & Usage Tracking State
  String? _installedPackageName;
  String? _installedAppName;
  int _taskStartTimeMs = 0;
  int _usedSeconds = 0;
  bool _isAdClicked = false;
  bool _isInstallAdWatched = false;
  bool _isTaskVerifying = false;
  bool _isFailedDialogShowing = false;
  bool _isActionDebounced = false;
  Timer? _usagePollingTimer;

  static const String _battleInstallTaskStorageKey = 'battle_install_task_progress';

  static Map<String, dynamic>? getSavedBattleInstallTask(String userId) {
    try {
      final box = GetStorage();
      final data = box.read('${_battleInstallTaskStorageKey}_$userId');
      if (data != null && data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static void saveBattleInstallTask(String userId, Map<String, dynamic> data) {
    try {
      final box = GetStorage();
      box.write('${_battleInstallTaskStorageKey}_$userId', data);
    } catch (_) {}
  }

  static void clearSavedBattleInstallTask(String userId) {
    try {
      final box = GetStorage();
      box.remove('${_battleInstallTaskStorageKey}_$userId');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _matchData = Map<String, dynamic>.from(widget.match);
    WidgetsBinding.instance.addObserver(this);
    _restoreSavedInstallTask();
    _fetchFreshRoomData();
    final adType = (_matchData['adType'] ?? 'rewarded').toString().toLowerCase();
    if (adType == 'interstitial') {
      AdManager().preloadInterstitial();
    } else {
      AdManager().preloadRewarded();
    }
  }

  Future<void> _fetchFreshRoomData() async {
    try {
      final String safeRoomId = (_matchData['roomId'] ??
              _matchData['_id'] ??
              widget.match['roomId'] ??
              widget.match['_id'] ??
              '')
          .toString()
          .trim();
      if (safeRoomId.isEmpty) return;

      final res = await BattleArenaService.instance.fetchRoomDetails(
        userId: widget.userId,
        roomId: safeRoomId,
      );

      if (res != null && res['success'] == true && res['room'] != null && mounted) {
        final r = res['room'] is Map ? Map<String, dynamic>.from(res['room']) : null;
        if (r != null) {
          final String roomId = r['roomId']?.toString() ?? r['_id']?.toString() ?? safeRoomId;
          final String title = r['title']?.toString() ?? '1v1 Battle Clash';
          final String gameTitle = r['assignedGameTitle']?.toString() ??
              r['category']?.toString() ??
              'General Quiz Clash';
          final String subtitle = (r['subtitle'] != null && r['subtitle'].toString().trim().isNotEmpty)
              ? r['subtitle'].toString().trim()
              : (r['description'] != null && r['description'].toString().trim().isNotEmpty)
                  ? r['description'].toString().trim()
                  : gameTitle;
          final int prize = (r['netPrizePoolCoins'] as num?)?.toInt() ??
              (r['prize'] as num?)?.toInt() ??
              0;
          final int entryFee = (r['entryFeeCoins'] as num?)?.toInt() ??
              (r['entryFee'] as num?)?.toInt() ??
              0;
          final String entryType =
              r['entryType']?.toString() ?? (entryFee == 0 ? 'Free' : 'Paid');
          final int capacity = (r['capacity'] as num?)?.toInt() ?? 2;
          final int qCount = (r['questionCount'] as num?)?.toInt() ?? 7;
          final int timePerQ = (r['timePerQuestionSec'] as num?)?.toInt() ?? 15;
          final String catTag = r['category']?.toString() ?? 'quiz';
          final String badge = entryType.toLowerCase() == 'free' ? 'FREE' : 'COIN';
          final int countdownSec = (r['countdownSec'] as num?)?.toInt() ?? 0;

          setState(() {
            _matchData = {
              'roomId': roomId,
              'title': title,
              'subtitle': subtitle,
              'assignedGameTitle': gameTitle,
              'description': subtitle,
              'prize': prize > 0 ? '$prize Coins' : 'Rank Points',
              'fee': entryType.toLowerCase() == 'free' || entryFee == 0
                  ? 'FREE'
                  : '$entryFee Coins',
              'entryFeeCoins': entryFee,
              'entryFee': entryFee,
              'entryType': entryType,
              'netPrizePoolCoins': prize,
              'category': catTag,
              'badge': badge,
              'adType': r['adType']?.toString() ?? 'None',
              'skipAdMatches': (r['skipAdMatches'] as num?)?.toInt() ??
                  (int.tryParse(r['skipAdMatches']?.toString() ?? '0') ?? 0),
              'capacity': capacity,
              'questionCount': qCount,
              'timePerQuestionSec': timePerQ,
              'rankRewards': r['rankRewards'] ?? [],
              'matchingTimeoutSec':
                  (r['matchingTimeoutSec'] as num?)?.toInt() ?? 35,
              'countdownSec': countdownSec,
              'raw': r,
            };
          });
        }
      }
    } catch (_) {}
  }

  void _restoreSavedInstallTask() {
    final saved = getSavedBattleInstallTask(widget.userId);
    if (saved != null) {
      final String? pkg = saved['packageName']?.toString();
      final String? name = saved['appName']?.toString();
      final int startMs = saved['startTimeMs'] as int? ?? 0;
      if (pkg != null && pkg.isNotEmpty && startMs > 0) {
        _installedPackageName = pkg;
        _installedAppName = name;
        _taskStartTimeMs = startMs;
        if (_installedAppName == null || _installedAppName!.isEmpty) {
          _fetchAndSetAppName(pkg);
        }
        _startUsagePolling();
      }
    }
  }

  Future<void> _fetchAndSetAppName(String pkg) async {
    try {
      final name = await SuperOfferNativeManager.getAppName(pkg);
      if (name != null && name.isNotEmpty && mounted) {
        setState(() {
          _installedAppName = name;
        });
        final saved = getSavedBattleInstallTask(widget.userId);
        if (saved != null) {
          saved['appName'] = name;
          saveBattleInstallTask(widget.userId, saved);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _usagePollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _showTaskNotCompletedPopup({
    String? tag = 'Oops!',
    String title = 'Task Not Completed!',
    String message = 'App not installed! Please install the app and open it to complete the task.',
    String primaryButtonText = 'TRY AGAIN',
    VoidCallback? onPrimaryTap,
  }) async {
    if (_isFailedDialogShowing) return;
    _isFailedDialogShowing = true;

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) {
      _isFailedDialogShowing = false;
      return;
    }

    try {
      await CustomStatusPopup.showFailed(
        context: context,
        tag: tag,
        title: title,
        message: message,
        primaryButtonText: primaryButtonText,
        onPrimaryTap: onPrimaryTap,
      );
    } catch (_) {
    } finally {
      _isFailedDialogShowing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_installedPackageName != null && _installedPackageName!.isNotEmpty) {
        _updateUsageDuration();
      } else if (_taskStartTimeMs > 0) {
        _checkInstallStatus().then((_) {
          if (_installedPackageName == null && mounted) {
            if (_isInstallAdWatched || _isAdClicked) {
              _isInstallAdWatched = false;
              _isAdClicked = false;
              _showTaskNotCompletedPopup();
            }
          }
        });
      }
    }
  }

  Future<void> _checkInstallStatus() async {
    if (_taskStartTimeMs <= 0) {
      final saved = getSavedBattleInstallTask(widget.userId);
      _taskStartTimeMs = saved?['startTimeMs'] as int? ?? 0;
    }
    if (_taskStartTimeMs <= 0) return;

    final recentPkg = await SuperOfferNativeManager.getRecentlyInstalledPackage(
      _taskStartTimeMs - 5000,
    );

    if (recentPkg != null && recentPkg.isNotEmpty) {
      _installedPackageName = recentPkg;
      _isInstallAdWatched = false;
      _isAdClicked = false;
      _taskStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      _fetchAndSetAppName(recentPkg);
      saveBattleInstallTask(widget.userId, {
        'packageName': recentPkg,
        'appName': _installedAppName,
        'startTimeMs': _taskStartTimeMs,
        'savedAt': _taskStartTimeMs,
        'isInstalled': true,
      });
      _startUsagePolling();
      if (mounted) setState(() {});
    }
  }

  void _startUsagePolling() {
    _usagePollingTimer?.cancel();
    _updateUsageDuration();
    _usagePollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateUsageDuration();
    });
  }

  Future<void> _updateUsageDuration() async {
    if (!mounted) return;
    if (_installedPackageName == null || _installedPackageName!.isEmpty || _taskStartTimeMs <= 0) return;

    final isStillInstalled = await SuperOfferNativeManager.isAppInstalled(_installedPackageName!);
    if (!isStillInstalled && mounted) {
      clearSavedBattleInstallTask(widget.userId);
      _usagePollingTimer?.cancel();
      _installedPackageName = null;
      _installedAppName = null;
      _taskStartTimeMs = 0;
      _usedSeconds = 0;
      _isInstallAdWatched = false;
      _isAdClicked = false;
      setState(() {});
      _showTaskNotCompletedPopup(
        tag: 'Uninstalled!',
        title: 'App Uninstalled',
        message: 'You have uninstalled the task app before completing usage. Task has been reset.',
        primaryButtonText: 'TRY AGAIN',
      );
      return;
    }

    final hasPerm = await SuperOfferNativeManager.checkUsagePermission();
    if (hasPerm) {
      final sec = await SuperOfferNativeManager.getAppUsageDuration(
        _installedPackageName!,
        _taskStartTimeMs,
      );

      if (sec > _usedSeconds && mounted) {
        setState(() {
          _usedSeconds = sec;
        });
      }

      final config = BattleArenaService.instance.configData;
      final int targetSeconds = (config != null && config['installTaskUsageSeconds'] != null)
          ? (config['installTaskUsageSeconds'] as num).toInt()
          : 300;

      if (_usedSeconds >= targetSeconds && !_isTaskVerifying) {
        _completeInstallTaskSuccess();
      }
    }
  }

  Future<void> _completeInstallTaskSuccess() async {
    _isTaskVerifying = true;
    _usagePollingTimer?.cancel();
    try {
      final res = await CloudFunctions.completeBattleInstallTask();
      if (res['response'] == 'success' || res['success'] == true) {
        ref.invalidate(DashboardService.userDataProvider(widget.userId));
        LocalStorage.setFreeBattleAdPass(true);
        clearSavedBattleInstallTask(widget.userId);
        _installedPackageName = null;
        _taskStartTimeMs = 0;
        _usedSeconds = 0;
        _isInstallAdWatched = false;
        _isAdClicked = false;
        if (mounted) {
          setState(() {});
          CustomToast.showToast(context, msg: '🎉 Install Task Completed! Free Battle Unlocked!');
          CustomStatusPopup.showSuccess(
            context: context,
            tag: 'Congratulations',
            title: 'Task Completed!',
            message: 'App usage verified! Free Battle is now unlocked.',
            primaryButtonText: 'JOIN NOW',
          );
        }
      } else {
        if (mounted) {
          _showTaskNotCompletedPopup(
            tag: 'Oops!',
            title: 'Verification Failed',
            message: res['message']?.toString() ?? 'Failed to complete install task. Please try again.',
            primaryButtonText: 'TRY AGAIN',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _showTaskNotCompletedPopup(
          tag: 'Oops!',
          title: 'Verification Failed',
          message: 'Failed to verify task. Please try opening the app again.',
          primaryButtonText: 'OK',
        );
      }
    } finally {
      _isTaskVerifying = false;
    }
  }

  String _formatCoins(dynamic coins) {
    final double val = (coins is num) ? coins.toDouble() : 0.0;
    if (val >= 1000) {
      final double kVal = val / 1000.0;
      if (kVal % 1 == 0) {
        return '${kVal.toInt()}k';
      }
      return '${kVal.toStringAsFixed(1)}k';
    }
    return '${val.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final matchData = _matchData;
    final rawData = matchData['raw'] is Map ? (matchData['raw'] as Map) : matchData;
    final int entryFee = (rawData['entryFeeCoins'] is num)
        ? (rawData['entryFeeCoins'] as num).toInt()
        : ((matchData['entryFeeCoins'] is num)
            ? (matchData['entryFeeCoins'] as num).toInt()
            : ((matchData['entryFee'] is num)
                ? (matchData['entryFee'] as num).toInt()
                : (int.tryParse(rawData['entryFeeCoins']?.toString() ??
                        rawData['entryFee']?.toString() ??
                        matchData['entryFeeCoins']?.toString() ??
                        matchData['entryFee']?.toString() ??
                        matchData['fee']?.toString().replaceAll(RegExp(r'[^\d]'), '') ??
                        '0') ??
                    0)));

    final commissionPercent = BattleArenaService.instance.configData?['platformCommissionFee'] is num
        ? (BattleArenaService.instance.configData?['platformCommissionFee'] as num).toInt()
        : 10;
    final capacity = matchData['capacity'] is num
        ? (matchData['capacity'] as num).toInt()
        : (int.tryParse(matchData['capacity']?.toString() ?? '2') ?? 2);

    final rawNetPrize = (rawData['netPrizePoolCoins'] is num)
        ? (rawData['netPrizePoolCoins'] as num).toInt()
        : ((matchData['netPrizePoolCoins'] is num)
            ? (matchData['netPrizePoolCoins'] as num).toInt()
            : ((matchData['prizeCoins'] is num)
                ? (matchData['prizeCoins'] as num).toInt()
                : 0));
    final netPrize = entryFee > 0 ? (entryFee * capacity * (100 - commissionPercent) / 100).toInt() : rawNetPrize;
    final bool isFreeRoom = entryFee == 0;

    final List<dynamic> termsRaw = isFreeRoom
        ? (BattleArenaService.instance.configData?['freeTerms'] ?? BattleArenaService.instance.configData?['terms'] ?? [])
        : (BattleArenaService.instance.configData?['paidTerms'] ?? BattleArenaService.instance.configData?['terms'] ?? []);

    final List<Map<String, String>> terms = termsRaw.map((t) {
      return {
        'title': t['title']?.toString() ?? '',
        'description': t['description']?.toString() ?? '',
      };
    }).toList();

    final List<Map<String, String>> displayTerms = terms.isNotEmpty
        ? terms
        : (isFreeRoom
            ? const [
                {
                  'title': '1. Acceptance of Terms',
                  'description': 'By accessing or using this Quiz Application ("App"), you agree to be bound by these Terms and Conditions.',
                },
                {
                  'title': '2. Fair Play & Anti-Cheat',
                  'description': 'Minimizing the app or switching to other apps during a battle will forfeit the current question.',
                },
              ]
            : const [
                {
                  'title': '1. Acceptance of Terms',
                  'description': 'By accessing or using this Quiz Application ("App"), you agree to be bound by these Terms and Conditions.',
                },
                {
                  'title': '2. Fair Play & Anti-Cheat',
                  'description': 'Minimizing the app or switching to other apps during a battle will forfeit the current question.',
                },
                {
                  'title': '3. Winner Coin Distribution',
                  'description': 'Platform fee cut % is deducted automatically, and net coins are credited to the winner instantly.',
                }
              ]);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Navigation Header Bar
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, topPadding > 0 ? 6.h : 14.h, 16.w, 14.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
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
                      'Battle Details',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 18.5.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Panels
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return RefreshIndicator(
                      color: const Color(0xFFAB31DE),
                      onRefresh: _fetchFreshRoomData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Room Title Highlight Card
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(16.r),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      matchData['title']?.toString() ?? 'Battle Clash',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18.sp,
                                        color: const Color(0xFF1E1B4B),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      (matchData['subtitle'] != null && matchData['subtitle'].toString().trim().isNotEmpty)
                                          ? matchData['subtitle'].toString().trim()
                                          : (rawData['subtitle'] != null && rawData['subtitle'].toString().trim().isNotEmpty)
                                              ? rawData['subtitle'].toString().trim()
                                              : (rawData['description'] != null && rawData['description'].toString().trim().isNotEmpty)
                                                  ? rawData['description'].toString().trim()
                                                  : 'Review rules, entry requirements & rewards below',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF64748B),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 16.h),

                              // Category Tab Switcher (PRIZE POOL vs TERMS)
                              Container(
                                padding: EdgeInsets.all(4.r),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: const Color(0xFFF3E8FF),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildTabButton(
                                      label: 'PRIZE POOL',
                                      tabIndex: 0,
                                      icon: Icons.emoji_events_rounded,
                                    ),
                                    SizedBox(width: 4.w),
                                    _buildTabButton(
                                      label: 'TERMS',
                                      tabIndex: 1,
                                      icon: Icons.article_rounded,
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 16.h),

                              // Active Tab Content
                              _activeTab == 0
                                  ? _buildPrizePoolPanel(entryFee, netPrize, capacity)
                                  : _buildTermsPanel(displayTerms),

                              SizedBox(height: 20.h),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Action Button
              _buildBottomButton(context, (matchData['roomId'] ?? matchData['_id'] ?? '').toString(), matchData['title']?.toString() ?? '', matchData),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Tab Switcher Button
  // ------------------------------------------------------------------
  Widget _buildTabButton({
    required String label,
    required int tabIndex,
    required IconData icon,
  }) {
    final isSelected = _activeTab == tabIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_activeTab != tabIndex) {
            HapticFeedback.lightImpact();
            setState(() => _activeTab = tabIndex);
          }
        },
        child: Container(
          height: 38.h,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 12.5.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Prize Pool Panel
  // ------------------------------------------------------------------
  Widget _buildPrizePoolPanel(int entryFee, int netPrize, int capacity) {
    final rawData = _matchData['raw'] is Map ? (_matchData['raw'] as Map) : _matchData;
    final String entryType = rawData['entryType']?.toString() ?? _matchData['entryType']?.toString() ?? 'Paid';
    final bool isFree = entryType.toLowerCase() == 'free' || entryFee == 0;
    final durationSec = _matchData['timePerQuestionSec'] ?? _matchData['timePerQuestion'] ?? 20;

    final List<dynamic> rankRewards = rawData['rankRewards'] is List
        ? rawData['rankRewards']
        : (_matchData['rankRewards'] is List ? _matchData['rankRewards'] : []);
    final int rawPrize = (rawData['netPrizePoolCoins'] is num)
        ? (rawData['netPrizePoolCoins'] as num).toInt()
        : ((_matchData['netPrizePoolCoins'] is num)
            ? (_matchData['netPrizePoolCoins'] as num).toInt()
            : ((_matchData['prizeCoins'] is num)
                ? (_matchData['prizeCoins'] as num).toInt()
                : 0));
    final int effectiveNetPrize = netPrize > 0 ? netPrize : rawPrize;
    final bool hasPrizePool = effectiveNetPrize > 0 || rankRewards.isNotEmpty;

    if (isFree) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 20.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/icons/battle.png',
                  height: 72.h,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.emoji_events_rounded,
                    color: const Color(0xFFAB31DE),
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'FREE BATTLE CLASH',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  effectiveNetPrize > 0
                      ? 'Win ${_formatCoins(effectiveNetPrize)} Coins on match victory + climb the Leaderboard to win huge prizes!'
                      : 'Compete against opponents, improve your speed index, and rank up on the Leaderboard to win real rewards!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFFF3E8FF),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, color: const Color(0xFFAB31DE), size: 15.sp),
                          SizedBox(width: 6.w),
                          Text(
                            '${durationSec}s duration',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(height: 14.h, width: 1, color: const Color(0xFFE9D5FF)),
                      Row(
                        children: [
                          Icon(Icons.group_outlined, color: const Color(0xFFAB31DE), size: 15.sp),
                          SizedBox(width: 6.w),
                          Text(
                            '$capacity players room',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
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
          if (hasPrizePool) ...[
            SizedBox(height: 18.h),
            _buildRankRewardsSection(),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3-Column Glass Overview: Entry Fee, Time, Prize Pool
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Entry Fee
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENTRY FEE',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/coin.png',
                          height: 20.sp,
                          width: 20.sp,
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          entryFee > 0 ? _formatCoins(entryFee) : 'FREE',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                height: 40.h,
                width: 1,
                color: const Color(0xFFF1F5F9),
              ),

              // Central Time Clash
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Column(
                  children: [
                    Text(
                      'TIME CLASH',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: const Color(0xFFF3E8FF),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: const Color(0xFFAB31DE), size: 15.sp),
                          SizedBox(width: 3.w),
                          Text(
                            '${durationSec}s',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                height: 40.h,
                width: 1,
                color: const Color(0xFFF1F5F9),
              ),

              // Prize Pool
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PRIZE POOL',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/coin.png',
                          height: 20.sp,
                          width: 20.sp,
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          _formatCoins(netPrize),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
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

        SizedBox(height: 14.h),

        // Grid showing Players and Winner
        Row(
          children: [
            Expanded(child: _buildSpecItem(Icons.people_alt_rounded, '$capacity Players')),
            SizedBox(width: 10.w),
            Expanded(child: _buildSpecItem(Icons.emoji_events_rounded, '1 Winner')),
          ],
        ),

        SizedBox(height: 18.h),

        // Rank Wise Distribution
        _buildRankRewardsSection(),
      ],
    );
  }

  Widget _buildSpecItem(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFAB31DE), size: 16.sp),
          SizedBox(width: 8.w),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankRewardsSection() {
    final rawData = _matchData['raw'] is Map ? (_matchData['raw'] as Map) : _matchData;
    final List<dynamic> rankRewards = rawData['rankRewards'] is List ? rawData['rankRewards'] : [];

    final int entryFee = (rawData['entryFeeCoins'] is num)
        ? (rawData['entryFeeCoins'] as num).toInt()
        : ((_matchData['entryFeeCoins'] is num)
            ? (_matchData['entryFeeCoins'] as num).toInt()
            : 0);
    final int rawPrize = (rawData['netPrizePoolCoins'] is num)
        ? (rawData['netPrizePoolCoins'] as num).toInt()
        : ((_matchData['netPrizePoolCoins'] is num)
            ? (_matchData['netPrizePoolCoins'] as num).toInt()
            : ((_matchData['prizeCoins'] is num)
                ? (_matchData['prizeCoins'] as num).toInt()
                : 0));
    final int capacity = _matchData['capacity'] is num
        ? (_matchData['capacity'] as num).toInt()
        : (int.tryParse(_matchData['capacity']?.toString() ?? '2') ?? 2);
    final commissionPercent = BattleArenaService.instance.configData?['platformCommissionFee'] is num
        ? (BattleArenaService.instance.configData?['platformCommissionFee'] as num).toInt()
        : 10;
    final int netPrize = entryFee > 0
        ? (entryFee * capacity * (100 - commissionPercent) / 100).toInt()
        : rawPrize;

    final displayRewards = rankRewards.isNotEmpty
        ? rankRewards
        : (netPrize > 0
            ? [
                {'rank': 1, 'coins': netPrize}
              ]
            : []);

    if (displayRewards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RANK DISTRIBUTION',
          style: GoogleFonts.outfit(
            fontSize: 11.sp,
            color: const Color(0xFFAB31DE),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        SizedBox(height: 10.h),
        ...displayRewards.map((reward) {
          final int rank = reward['rank'] is num ? (reward['rank'] as num).toInt() : 1;
          final int coins = reward['coins'] is num ? (reward['coins'] as num).toInt() : 0;

          final Color medalColor = rank == 1
              ? const Color(0xFFFFD700)
              : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));

          return Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      rank == 1
                          ? Icons.emoji_events_rounded
                          : (rank == 2 ? Icons.military_tech_rounded : Icons.workspace_premium_rounded),
                      color: medalColor,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Rank $rank',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xFFF3E8FF),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/coin.png',
                        height: 13.w,
                        width: 13.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '+${_formatCoins(coins)}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Terms Panel
  // ------------------------------------------------------------------
  Widget _buildTermsPanel(List<Map<String, String>> terms) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...terms.map((t) {
          final titleStr = t['title'] ?? '';
          final descStr = t['description'] ?? '';
          return Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: const Color(0xFFF1F5F9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleStr,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  descStr,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 12.sp,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Bottom Action Button (Exact 3D Tapered Style)
  // ------------------------------------------------------------------
  Widget _buildBottomButton(BuildContext context, String roomId, String roomTitle, Map<String, dynamic> matchDetails) {
    final rawData = matchDetails['raw'] is Map ? (matchDetails['raw'] as Map) : matchDetails;
    final String safeRoomId = roomId.trim().isNotEmpty
        ? roomId.trim()
        : ((rawData['roomId'] ?? rawData['_id'] ?? matchDetails['roomId'] ?? matchDetails['_id'] ?? widget.match['roomId'] ?? widget.match['_id'] ?? '').toString().trim());

    final int entryFee = (rawData['entryFeeCoins'] is num)
        ? (rawData['entryFeeCoins'] as num).toInt()
        : ((matchDetails['entryFeeCoins'] is num)
            ? (matchDetails['entryFeeCoins'] as num).toInt()
            : ((matchDetails['entryFee'] is num)
                ? (matchDetails['entryFee'] as num).toInt()
                : (int.tryParse(rawData['entryFeeCoins']?.toString() ??
                        rawData['entryFee']?.toString() ??
                        matchDetails['entryFeeCoins']?.toString() ??
                        matchDetails['entryFee']?.toString() ??
                        matchDetails['fee']?.toString().replaceAll(RegExp(r'[^\d]'), '') ??
                        '0') ??
                    0)));

    final String entryType = rawData['entryType']?.toString() ?? (entryFee == 0 ? 'Free' : 'Paid');
    final bool isFreeRoom = entryType.toLowerCase() == 'free' || entryFee == 0;
    final String adType = (rawData['adType']?.toString() ?? matchDetails['adType']?.toString() ?? widget.match['adType']?.toString() ?? 'None').trim();
    final bool hasAd = adType.toLowerCase() != 'none' && adType.isNotEmpty;
    final int skipAdMatches = (rawData['skipAdMatches'] is num)
        ? (rawData['skipAdMatches'] as num).toInt()
        : ((matchDetails['skipAdMatches'] is num)
            ? (matchDetails['skipAdMatches'] as num).toInt()
            : ((widget.match['skipAdMatches'] is num)
                ? (widget.match['skipAdMatches'] as num).toInt()
                : (int.tryParse(rawData['skipAdMatches']?.toString() ??
                        matchDetails['skipAdMatches']?.toString() ??
                        widget.match['skipAdMatches']?.toString() ??
                        '0') ??
                    0)));
    final int remainingSkips = LocalStorage.getRoomAdSkipMatches(widget.userId, safeRoomId);
    final bool isAdSkipped = hasAd && remainingSkips > 0;
    final bool requiresAdWatch = hasAd && !isAdSkipped;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
      child: _PopScaleButton(
        onTap: () async {
          if (_isActionDebounced) return;
          _isActionDebounced = true;
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _isActionDebounced = false;
          });

          final cachedProfile = ref.read(DashboardService.userDataProvider(widget.userId)).value;
          final bool isInstallTaskTarget = isFreeRoom &&
              requiresAdWatch &&
              cachedProfile != null &&
              cachedProfile.battleInstallTaskCompletedToday == false &&
              cachedProfile.battleInstallTaskNumber > 0 &&
              cachedProfile.freeBattlesJoinedToday == cachedProfile.battleInstallTaskNumber;

          if (isInstallTaskTarget) {
            final config = BattleArenaService.instance.configData;
            final int targetSec = (config != null && config['installTaskUsageSeconds'] != null)
                ? (config['installTaskUsageSeconds'] as num).toInt()
                : 300;

            // If task is in progress (app installed, waiting for usage time), tap launches app directly
            if (_installedPackageName != null &&
                _installedPackageName!.isNotEmpty &&
                _usedSeconds < targetSec) {
              SuperOfferNativeManager.launchApp(_installedPackageName!);
              return;
            }

            if (context.mounted) {
              _showInstallTaskSheet(
                context,
                cachedProfile.battleInstallTaskCompletedToday,
                cachedProfile.battleInstallTaskNumber,
              );
            }
            ref.invalidate(DashboardService.userDataProvider(widget.userId));
            return;
          }

          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(
                child: GlowLightingSpinner(size: 32),
              ),
            );
          }

          UserDataModel? userProfile;
          try {
            ref.invalidate(DashboardService.userDataProvider(widget.userId));
            userProfile = await ref.read(DashboardService.userDataProvider(widget.userId).future);
          } catch (_) {}

          if (!isInstallTaskTarget && context.mounted) {
            Navigator.of(context).pop();
          }

          if (userProfile == null) {
            if (context.mounted) {
              CustomToast.showToast(context, msg: 'Failed to load user profile. Please try again.');
            }
            return;
          }

          if (isFreeRoom && userProfile.battleDailyLimit != -1 && userProfile.freeBattlesJoinedToday >= userProfile.battleDailyLimit) {
            if (context.mounted) {
              _showLimitExceededBottomSheet(context);
            }
            return;
          }

          final double userCoins = userProfile.coins;

          if (!isFreeRoom && entryFee > 0 && userCoins < entryFee) {
            if (context.mounted) {
              _showInsufficientCoinsPopup(context, entryFee, userCoins);
            }
            return;
          }

          Future<void> proceedToJoin({
            String adVerifiedToken = '',
            bool wasAdSkippedForThisMatch = false,
          }) async {
            if (!context.mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(
                child: GlowLightingSpinner(size: 32),
              ),
            );

            final res = await BattleArenaService.instance.joinRoom(
              userId: widget.userId,
              roomId: safeRoomId,
              adVerifiedToken: adVerifiedToken,
            );

            if (context.mounted) {
              Navigator.of(context).pop();
            }

            if (res['success'] == true) {
              ref.invalidate(DashboardService.userDataProvider(widget.userId));
              final String matchId = res['matchId']?.toString() ?? 'match_${DateTime.now().millisecondsSinceEpoch}';
              if (context.mounted) {
                final resultMsg = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MatchingPartnerScreen(
                      userId: widget.userId,
                      roomId: safeRoomId,
                      isAdSkipped: wasAdSkippedForThisMatch,
                      matchId: matchId,
                      roomTitle: roomTitle,
                      entryFee: isFreeRoom ? 0 : entryFee,
                      matchingTimeoutSec: res['matchingTimeoutSec'] is num
                          ? (res['matchingTimeoutSec'] as num).toInt()
                          : (matchDetails['matchingTimeoutSec'] is num ? (matchDetails['matchingTimeoutSec'] as num).toInt() : 35),
                    ),
                  ),
                );

                ref.invalidate(DashboardService.userDataProvider(widget.userId));
                _fetchFreshRoomData();
                if (mounted) {
                  setState(() {});
                }

                if (resultMsg != null && resultMsg is String && context.mounted) {
                  Future.delayed(const Duration(milliseconds: 350), () {
                    if (context.mounted) {
                      showBattleRefundPopup(context, resultMsg, shouldPopParent: true);
                    }
                  });
                }
              }
            } else {
              if (context.mounted) {
                final bool isBonusRestriction = res['isBonusCoinRestriction'] == true ||
                    (res['message']?.toString().toLowerCase().contains('bonus coin') == true);
                if (isBonusRestriction) {
                  final double bonusAmount = (res['bonusCoins'] as num?)?.toDouble() ?? (userProfile?.bonusCoins ?? 0.0);
                  final double earnedAmount = (res['earnedCoins'] as num?)?.toDouble() ?? 0.0;
                  final int allowedPercent = (res['allowedBonusPercent'] as num?)?.toInt() ?? 0;
                  final int minEarnedReq = (res['minEarnedCoinsRequired'] as num?)?.toInt() ?? entryFee;
                  final String? customMsg = res['message']?.toString();
                  _showBonusCoinsRestrictionBottomSheet(
                    context,
                    bonusCoins: bonusAmount,
                    entryFee: entryFee,
                    allowedBonusPercent: allowedPercent,
                    earnedCoins: earnedAmount,
                    minEarnedRequired: minEarnedReq,
                    customMessage: customMsg,
                  );
                } else {
                  final String errMsg = res['message']?.toString() ?? 'Unable to join battle room';
                  if (errMsg.toLowerCase().contains('limit')) {
                    _showLimitExceededBottomSheet(context);
                  } else {
                    CustomToast.showToast(context, msg: errMsg);
                    CustomStatusPopup.showFailed(
                      context: context,
                      tag: 'Failed',
                      title: 'Unable to Join Room',
                      message: errMsg,
                      primaryButtonText: 'OK',
                    );
                  }
                }
              }
            }
          }

          final bool hasAdPass = isFreeRoom && LocalStorage.hasFreeBattleAdPass();

          if (requiresAdWatch && !hasAdPass) {
            if (isFreeRoom &&
                userProfile.battleInstallTaskCompletedToday == false &&
                userProfile.battleInstallTaskNumber > 0 &&
                userProfile.freeBattlesJoinedToday == userProfile.battleInstallTaskNumber) {

              final config = BattleArenaService.instance.configData;
              final int targetSec = (config != null && config['installTaskUsageSeconds'] != null)
                  ? (config['installTaskUsageSeconds'] as num).toInt()
                  : 30;

              // If task is in progress (app installed, waiting for usage time), tap launches app directly
              if (_installedPackageName != null &&
                  _installedPackageName!.isNotEmpty &&
                  _usedSeconds < targetSec) {
                SuperOfferNativeManager.launchApp(_installedPackageName!);
                return;
              }
              
              if (context.mounted) {
                _showInstallTaskSheet(context, userProfile.battleInstallTaskCompletedToday, userProfile.battleInstallTaskNumber);
              }
              return;
            }

            bool spinnerDismissed = false;
            void dismissSpinner() {
              if (!spinnerDismissed && context.mounted) {
                Navigator.of(context).pop();
                spinnerDismissed = true;
              }
            }

            if (context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(
                  child: GlowLightingSpinner(size: 32),
                ),
              );
            }

            bool adRewardEarned = false;

            if (context.mounted) {
              if (adType.toLowerCase() == 'interstitial') {
                await AdManager().showInterstitialAd(
                  onAdShown: () {
                    dismissSpinner();
                  },
                  onAdFailed: () {
                    dismissSpinner();
                  },
                  onClosed: () async {
                    dismissSpinner();
                    if (skipAdMatches > 0) {
                      LocalStorage.setRoomAdSkipMatches(widget.userId, safeRoomId, skipAdMatches);
                    }
                    if (isFreeRoom) {
                      LocalStorage.setFreeBattleAdPass(true);
                    }
                    if (context.mounted) {
                      await proceedToJoin(adVerifiedToken: 'WATCHED_AD', wasAdSkippedForThisMatch: false);
                    }
                  },
                );
              } else {
                await AdManager().showRewardedAd(
                  context: context,
                  onReward: () async {
                    adRewardEarned = true;
                  },
                  onAdClicked: () async {
                    dismissSpinner();
                  },
                  onAdShown: () {
                    dismissSpinner();
                  },
                  onAdFailed: () {
                    dismissSpinner();
                    if (context.mounted) {
                      CustomToast.showToast(context, msg: 'Ad failed to load. Please try again.');
                      CustomStatusPopup.showFailed(
                        context: context,
                        tag: 'Error',
                        title: 'Ad Failed',
                        message: 'Failed to load video advertisement. Please check your internet connection and try again.',
                        primaryButtonText: 'OK',
                      );
                    }
                  },
                  onAdClosed: (hasEarnedReward) async {
                    dismissSpinner();
                    if ((hasEarnedReward || adRewardEarned) && context.mounted) {
                      if (skipAdMatches > 0) {
                        LocalStorage.setRoomAdSkipMatches(widget.userId, safeRoomId, skipAdMatches);
                      }
                      if (isFreeRoom) {
                        LocalStorage.setFreeBattleAdPass(true);
                      }
                      await proceedToJoin(adVerifiedToken: 'WATCHED_AD', wasAdSkippedForThisMatch: false);
                    } else if (context.mounted) {
                      CustomToast.showToast(context, msg: 'You must watch the full ad to join this battle room.');
                      CustomStatusPopup.showFailed(
                        context: context,
                        tag: 'Ad Incomplete',
                        title: 'Reward Not Earned!',
                        message: 'You must watch the full rewarded ad to join this battle room.',
                        primaryButtonText: 'WATCH AGAIN',
                      );
                    }
                  },
                );
              }
            }
          } else {
            await proceedToJoin(
              adVerifiedToken: (hasAd || hasAdPass) ? 'WATCHED_AD' : '',
              wasAdSkippedForThisMatch: isAdSkipped,
            );
          }
        },
        child: Builder(
          builder: (context) {
            final userProfile = ref.watch(DashboardService.userDataProvider(widget.userId)).value;
            final config = BattleArenaService.instance.configData;
            final int targetSeconds = (config != null && config['installTaskUsageSeconds'] != null)
                ? (config['installTaskUsageSeconds'] as num).toInt()
                : 30;

            final bool isTaskCompleted = userProfile?.battleInstallTaskCompletedToday == true;
            final bool isTaskInProgress = _installedPackageName != null &&
                _installedPackageName!.isNotEmpty &&
                _usedSeconds < targetSeconds &&
                !isTaskCompleted;

            if (isTaskInProgress) {
              final double progressRatio = (_usedSeconds / targetSeconds).clamp(0.0, 1.0);
              final String appDisplayName = (_installedAppName != null && _installedAppName!.isNotEmpty)
                  ? _installedAppName!
                  : 'App Usage Progress';
              return Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFE9D5FF),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: App Icon + App Name & Subtitle + Live Timer Pill
                    Row(
                      children: [
                        Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFAF5FF),
                            border: Border.all(color: const Color(0xFFE9D5FF), width: 1),
                          ),
                          child: Icon(
                            Icons.hourglass_top_rounded,
                            color: const Color(0xFFAB31DE),
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                appDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1E1B4B),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Use app for $targetSeconds sec to unlock',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: const Color(0xFFE9D5FF), width: 1),
                          ),
                          child: Text(
                            '${_usedSeconds}s / ${targetSeconds}s',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFAB31DE),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10.h),

                    // Progress Bar
                    Container(
                      height: 7.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progressRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // Uninstall Warning Banner
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 1.h),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: const Color(0xFFD97706),
                              size: 14.sp,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              'Warning: Open, Signup & explore (if app) OR play 2-3 levels (if game). Do not uninstall for 24 hrs, otherwise reward cancelled & account banned.',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFB45309),
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // Bottom OPEN APP Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (_installedPackageName != null) {
                          SuperOfferNativeManager.launchApp(_installedPackageName!);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 9.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.26),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.launch_rounded, color: Colors.white, size: 14.sp),
                            SizedBox(width: 6.w),
                            Text(
                              'OPEN',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
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

            final int freshSkips = LocalStorage.getRoomAdSkipMatches(widget.userId, safeRoomId);
            final bool freshIsAdSkipped = hasAd && freshSkips > 0;
            final bool freshRequiresAdWatch = hasAd && !freshIsAdSkipped;
            final bool hasAdPass = isFreeRoom && LocalStorage.hasFreeBattleAdPass();
            final bool showAdBadgeOnPaid = !isFreeRoom && freshRequiresAdWatch;
            final bool showWatchAdForFree = isFreeRoom && freshRequiresAdWatch && !hasAdPass;

            final buttonWidget = Container(
              width: double.infinity,
              height: 48.h,
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
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.32),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showWatchAdForFree) ...[
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                    ] else if (isFreeRoom && hasAdPass) ...[
                      Icon(
                        Icons.bolt_rounded,
                        color: const Color(0xFFFFEA00),
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                    ],
                    Text(
                      showWatchAdForFree
                          ? 'WATCH AD TO JOIN'
                          : (isFreeRoom ? 'JOIN FREE BATTLE' : 'JOIN BATTLE NOW'),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (showAdBadgeOnPaid) {
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  buttonWidget,
                  // Top-Right Circular White/Black "AD" Badge
                  Positioned(
                    top: -5.h,
                    right: 12.w,
                    child: Container(
                      width: 22.w,
                      height: 22.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'AD',
                        style: GoogleFonts.outfit(
                          color: Colors.black,
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return buttonWidget;
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Modal Bottom Sheets (Install Task, Limit Exceeded, Insufficient Coins)
  // ------------------------------------------------------------------
  Widget _buildStep(String index, String text) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22.w,
            height: 22.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              index,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E1B4B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInstallTaskSheet(BuildContext context, bool completedToday, int totalTasks) {
    final config = BattleArenaService.instance.configData;
    final int targetSeconds = (config != null && config['installTaskUsageSeconds'] != null)
        ? (config['installTaskUsageSeconds'] as num).toInt()
        : 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool isAdLoading = false;
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                  border: Border.all(
                    color: const Color(0xFFF1F5F9),
                    width: 1.2,
                  ),
                ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Icon(
                    Icons.download_for_offline_rounded,
                    color: const Color(0xFFAB31DE),
                    size: 42.sp,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Unlock Free Battles: Install Task Required',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E1B4B),
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildStep("1", "Tap button below to watch the sponsored ad."),
                  _buildStep("2", "Install the app from the sponsored ad."),
                  _buildStep("3", "Open the installed app for $targetSeconds seconds."),
                  _buildStep("4", "Return to app — free battle will be unlocked automatically!"),
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 1.h),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: const Color(0xFFD97706),
                            size: 15.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF92400E),
                                fontSize: 11.sp,
                                height: 1.35,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Important Warning:\n',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                                const TextSpan(
                                  text: '• If App: Open, Signup & explore features.\n• If Game: Play at least 2-3 levels.\n⚠️ Do not uninstall this app for 24 hours, otherwise reward will be cancelled & your account may be banned.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(sheetContext);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w800,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isAdLoading
                              ? null
                              : () async {
                                  setStateSheet(() => isAdLoading = true);

                                  final bool hasPerm = await SuperOfferNativeManager.checkUsagePermission();
                                  if (!hasPerm) {
                                    if (mounted) setStateSheet(() => isAdLoading = false);
                                    if (context.mounted) {
                                      await CustomStatusPopup.showUsagePermission(
                                        context: context,
                                        onAllow: () async {
                                          await SuperOfferNativeManager.openUsageSettings();
                                        },
                                      );
                                    }
                                    return;
                                  }

                                  _installSheetContext = sheetContext;
                                  _taskStartTimeMs = DateTime.now().millisecondsSinceEpoch;
                                  _usedSeconds = 0;
                                  _isAdClicked = false;
                                  saveBattleInstallTask(widget.userId, {
                                    'startTimeMs': _taskStartTimeMs,
                                    'savedAt': _taskStartTimeMs,
                                    'isInstalled': false,
                                  });

                                  if (!context.mounted) return;
                                  await AdManager().showRewardedAd(
                                    context: context,
                                    onReward: () async {},
                                    onAdClicked: () async {
                                      _isAdClicked = true;
                                    },
                                    onAdClosed: (_) async {
                                      if (_installSheetContext != null && _installSheetContext!.mounted) {
                                        Navigator.pop(_installSheetContext!);
                                        _installSheetContext = null;
                                      }
                                      _isInstallAdWatched = true;
                                      await _checkInstallStatus();
                                      if (_installedPackageName == null && mounted) {
                                        await _showTaskNotCompletedPopup();
                                      }
                                    },
                                    onAdFailed: () {
                                      if (mounted) {
                                        setStateSheet(() => isAdLoading = false);
                                        if (_installSheetContext != null && _installSheetContext!.mounted) {
                                          Navigator.pop(_installSheetContext!);
                                          _installSheetContext = null;
                                        }
                                        _showTaskNotCompletedPopup(
                                          tag: 'Error',
                                          title: 'Ad Failed',
                                          message: 'Failed to load sponsored ad. Please check your internet connection and try again.',
                                          primaryButtonText: 'OK',
                                        );
                                      }
                                    },
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 13.h),
                            backgroundColor: const Color(0xFFAB31DE),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: isAdLoading
                              ? SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'START TASK NOW',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.sp,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  }

  void _showLimitExceededBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 18.h),

                // Glowing Icon Badge
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFAF5FF),
                    border: Border.all(
                      color: const Color(0xFFE9D5FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 46.w,
                      height: 46.w,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                        ),
                      ),
                      child: Icon(
                        Icons.hourglass_bottom_rounded,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),

                // Title
                Text(
                  'Daily Free Limit Reached!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E1B4B),
                  ),
                ),
                SizedBox(height: 8.h),

                // Description
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: Text(
                    'You have completed all your free battles for today. Please check back tomorrow!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Info Highlight Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: const Color(0xFFF3E8FF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.tips_and_updates_rounded,
                          color: const Color(0xFFAB31DE),
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Want to keep playing?',
                              style: GoogleFonts.outfit(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E1B4B),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Join Coin Battle Rooms with entry coins to win bigger rewards and top the leaderboard!',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(sheetContext);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Text(
                          'CLOSE',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(sheetContext);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'EXPLORE ROOMS',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.sp,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBonusCoinsRestrictionBottomSheet(
    BuildContext context, {
    required double bonusCoins,
    required int entryFee,
    int allowedBonusPercent = 0,
    double earnedCoins = 0.0,
    int? minEarnedRequired,
    String? customMessage,
  }) {
    final int maxBonusDiscount = (entryFee * (allowedBonusPercent / 100)).floor();
    final int usableBonus = (bonusCoins.toInt()).clamp(0, maxBonusDiscount);
    final int finalPayableEarned = minEarnedRequired ?? (entryFee - usableBonus);
    final int missingEarned = (finalPayableEarned - earnedCoins.toInt()).clamp(0, entryFee);

    final String messageText = allowedBonusPercent > 0
        ? 'You have ${bonusCoins.toInt()} Bonus Coins. You can use $usableBonus Bonus Coins ($allowedBonusPercent%) for this room. You still need $missingEarned more Earned Coins to enter!'
        : 'You have ${bonusCoins.toInt()} Bonus Coins. Bonus coins cannot be used to join Coin Battle rooms (0% allowed). You still need $missingEarned more Earned Coins to enter!';

    CustomStatusPopup.show(
      context: context,
      type: StatusPopupType.warning,
      tag: 'Bonus Coins',
      title: 'Bonus Coins Detected!',
      message: messageText,
      customBody: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Room Entry Fee',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5.sp,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$entryFee Coins',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5.sp,
                    color: allowedBonusPercent > 0 ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                    decoration: allowedBonusPercent > 0 ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/icons/coin.png',
                      width: 14.w,
                      height: 14.w,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      allowedBonusPercent > 0
                          ? 'Bonus Coins Used ($allowedBonusPercent%)'
                          : 'Bonus Coins Used (0%)',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5.sp,
                        color: allowedBonusPercent > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  allowedBonusPercent > 0 ? '-$usableBonus Coins' : '0 Coins',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5.sp,
                    color: allowedBonusPercent > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (missingEarned > 0) ...[
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15.sp, color: const Color(0xFFEF4444)),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'You need $missingEarned more Earned Coins to join this room.',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5.sp,
                          color: const Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      primaryButtonText: 'COLLECT COINS',
      primaryButtonColor: const Color(0xFFAB31DE),
      primaryButtonGradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
      ),
      onPrimaryTap: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      secondaryButtonText: 'CLOSE',
    );
  }

  void _showInsufficientCoinsPopup(BuildContext context, int fee, double currentCoins) {
    showDialog(
      context: context,
      builder: (_) => CustomStatusPopup(
        type: StatusPopupType.warning,
        title: 'Insufficient Coins',
        message: 'You need $fee Coins to join this room. Current Balance: ${currentCoins.toInt()} Coins.',
      ),
    );
  }
}

class _PopScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PopScaleButton({required this.child, required this.onTap});

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.child,
        ),
      ),
    );
  }
}
