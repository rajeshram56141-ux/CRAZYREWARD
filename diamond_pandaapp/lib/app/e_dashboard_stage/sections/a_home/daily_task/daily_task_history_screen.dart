import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../../widgets/common/custom_loading.dart';
import '../../../../../../widgets/common/internet_image.dart';
import 'daily_task_model.dart';
import 'daily_task_provider.dart';

@RoutePage()
class DailyTaskHistoryScreen extends HookConsumerWidget {
  const DailyTaskHistoryScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.country,
  });

  final String userId;
  final String email;
  final String country;

  bool _isTaskFullyCompleted(DailyTaskModel task) {
    if (task.dailyReset) {
      return false;
    }
    if (task.events.isNotEmpty) {
      if (task.dailyRewardEnabled) {
        return task.events.every((e) => e.completed || e.status == 'completed');
      }
      return task.events.every((e) => e.completed);
    }
    return false;
  }

  void _navigateToTaskDetails(
    BuildContext context,
    DailyTaskModel task,
  ) {
    AutoRouter.of(context).push(
      DailyTaskDetailsScreenRoute(
        item: task,
        cardColor: task.color,
        userId: userId,
        email: email,
        country: country,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = useState<int>(0); // 0: Active/In Progress, 1: Completed

    final historyProvider = dailyTaskHistoryProvider((
      userId: userId,
      email: email,
      countryCode: country,
      offerType: DailyTaskType.dailyTask,
    ));

    useEffect(() {
      Future.microtask(() {
        ref.invalidate(historyProvider);
      });
      return null;
    }, [userId]);

    final historyAsync = ref.watch(historyProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Solid Clean White Background
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: RefreshIndicator(
                color: const Color(0xFFAB31DE),
                backgroundColor: Colors.white,
                edgeOffset: topPadding + 60.h,
                onRefresh: () async {
                  ref.invalidate(historyProvider);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    // Executive Top Header Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          16.w,
                          topPadding + 8.h,
                          16.w,
                          14.h,
                        ),
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

                            Text(
                              'Daily Task History',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 18.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Content Body based on AsyncValue
                    historyAsync.when(
                      loading: () => const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: GlowLightingSpinner(size: 40),
                        ),
                      ),
                      error: (err, _) => SliverFillRemaining(
                        hasScrollBody: false,
                        child: _HistoryErrorWidget(
                          error: err.toString(),
                          onRetry: () => ref.invalidate(historyProvider),
                        ),
                      ),
                      data: (tasks) {
                        DateTime getTaskCompletionTime(DailyTaskModel task) {
                          if (task.events.isNotEmpty) {
                            for (final e in task.events) {
                              if (e.completedAt != null) return e.completedAt!;
                            }
                          }
                          return task.timestamp;
                        }

                        final completedTasks =
                            tasks.where((t) => _isTaskFullyCompleted(t)).toList();
                        completedTasks.sort((a, b) {
                          final aTime = getTaskCompletionTime(a);
                          final bTime = getTaskCompletionTime(b);
                          return bTime.compareTo(aTime);
                        });

                        final activeTasks =
                            tasks.where((t) => !_isTaskFullyCompleted(t)).toList();
                        activeTasks.sort((a, b) {
                          final aTime = getTaskCompletionTime(a);
                          final bTime = getTaskCompletionTime(b);
                          return bTime.compareTo(aTime);
                        });

                        final totalCoinsEarned = tasks.fold<int>(0, (sum, task) {
                          if (task.hasEvents && task.events.isNotEmpty) {
                            return sum +
                                task.events
                                    .where((e) =>
                                        e.completed || e.status == 'completed')
                                    .fold<int>(0, (s, e) => s + e.coins);
                          }
                          return sum + task.coins;
                        });

                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 40.h),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // Executive Overview Stats Banner
                              _OverviewStatsCard(
                                activeCount: activeTasks.length,
                                completedCount: completedTasks.length,
                                totalCoinsEarned: totalCoinsEarned,
                              ),

                              SizedBox(height: 18.h),

                              // Executive Tab Switcher Pill Bar (Active vs Completed)
                              Container(
                                height: 48.h,
                                padding: EdgeInsets.all(4.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(24.r),
                                  border: Border.all(
                                    color: const Color(0xFFE39FFF).withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          selectedTab.value = 0;
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          decoration: BoxDecoration(
                                            gradient: selectedTab.value == 0
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFFE39FFF),
                                                      Color(0xFFAB31DE),
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  )
                                                : null,
                                            color: selectedTab.value == 0
                                                ? null
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(20.r),
                                            boxShadow: selectedTab.value == 0
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.timelapse_rounded,
                                                color: selectedTab.value == 0
                                                    ? Colors.white
                                                    : const Color(0xFF64748B),
                                                size: 16.sp,
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                'Active • ${activeTasks.length}',
                                                style: GoogleFonts.outfit(
                                                  color: selectedTab.value == 0
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                  fontSize: 13.sp,
                                                  fontWeight: selectedTab.value == 0
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          selectedTab.value = 1;
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          decoration: BoxDecoration(
                                            gradient: selectedTab.value == 1
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFFE39FFF),
                                                      Color(0xFFAB31DE),
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  )
                                                : null,
                                            color: selectedTab.value == 1
                                                ? null
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(20.r),
                                            boxShadow: selectedTab.value == 1
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.task_alt_rounded,
                                                color: selectedTab.value == 1
                                                    ? Colors.white
                                                    : const Color(0xFF64748B),
                                                size: 16.sp,
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                'Completed • ${completedTasks.length}',
                                                style: GoogleFonts.outfit(
                                                  color: selectedTab.value == 1
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                  fontSize: 13.sp,
                                                  fontWeight: selectedTab.value == 1
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
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

                              SizedBox(height: 16.h),

                              // Tab 0: Active Tasks List
                              if (selectedTab.value == 0) ...[
                                if (activeTasks.isEmpty)
                                  _EmptyActiveHistoryWidget(
                                    onBrowse: () =>
                                        AutoRouter.of(context).maybePop(),
                                  )
                                else
                                  ...activeTasks.map((task) => Padding(
                                        padding: EdgeInsets.only(bottom: 12.h),
                                        child: _ActiveTaskCard(
                                          task: task,
                                          onTap: () => _navigateToTaskDetails(
                                            context,
                                            task,
                                          ),
                                        ),
                                      )),
                              ],

                              // Tab 1: Completed Tasks List
                              if (selectedTab.value == 1) ...[
                                if (completedTasks.isEmpty)
                                  _EmptyTaskHistoryWidget(
                                    onBrowse: () =>
                                        AutoRouter.of(context).maybePop(),
                                  )
                                else
                                  ...completedTasks.map((task) => Padding(
                                        padding: EdgeInsets.only(bottom: 12.h),
                                        child: _CompletedTaskCard(task: task),
                                      )),
                              ],
                            ]),
                          ),
                        );
                      },
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

// ---------------------------------------------------------------------------
// HELPER TO FORMAT TIMESTAMP
// ---------------------------------------------------------------------------
String _formatTimestamp(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final month = months[local.month - 1];
  final year = local.year;
  int hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  final hourStr = hour.toString().padLeft(2, '0');

  return '$day $month $year, $hourStr:$minute $period';
}

DateTime _getTaskLatestCompletionDate(DailyTaskModel task) {
  DateTime? latest;
  for (final e in task.events) {
    if ((e.completed || e.status == 'completed') && e.completedAt != null) {
      if (latest == null || e.completedAt!.isAfter(latest)) {
        latest = e.completedAt;
      }
    }
  }
  return latest ?? task.timestamp;
}

// ---------------------------------------------------------------------------
// EXECUTIVE OVERVIEW STATS CARD
// ---------------------------------------------------------------------------
class _OverviewStatsCard extends StatelessWidget {
  const _OverviewStatsCard({
    required this.activeCount,
    required this.completedCount,
    required this.totalCoinsEarned,
  });

  final int activeCount;
  final int completedCount;
  final int totalCoinsEarned;

  String _formatCompact(num val) {
    if (val >= 1000000) {
      double v = val / 1000000.0;
      return v % 1 == 0 ? '${v.toInt()}M' : '${v.toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      double v = val / 1000.0;
      return v % 1 == 0 ? '${v.toInt()}k' : '${v.toStringAsFixed(1)}k';
    }
    return val.toInt().toString();
  }

  Widget _buildTopStatCard({
    required String label,
    required String value,
    required Widget icon,
    required Color iconBg,
    required Color iconBorder,
    required Color labelColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: iconBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: iconBorder,
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: labelColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTopStatCard(
              label: 'Active Tasks',
              value: '$activeCount Active',
              iconBg: const Color(0xFFFAF5FF),
              iconBorder: const Color(0xFFF3E8FF),
              labelColor: const Color(0xFFAB31DE),
              icon: Icon(
                Icons.timelapse_rounded,
                color: const Color(0xFFAB31DE),
                size: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildTopStatCard(
              label: 'Completed',
              value: '$completedCount Done',
              iconBg: const Color(0xFFECFDF5),
              iconBorder: const Color(0xFFD1FAE5),
              labelColor: const Color(0xFF059669),
              icon: Icon(
                Icons.task_alt_rounded,
                color: const Color(0xFF059669),
                size: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildTopStatCard(
              label: 'Coins Earned',
              value: '+${_formatCompact(totalCoinsEarned)}',
              iconBg: const Color(0xFFFFFBEB),
              iconBorder: const Color(0xFFFEF3C7),
              labelColor: const Color(0xFFD97706),
              icon: Image.asset(
                'assets/icons/coin.png',
                width: 18.w,
                height: 18.w,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/icons/coin.png',
                  width: 18.w,
                  height: 18.w,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ACTIVE / IN-PROGRESS TASK CARD ITEM
// ---------------------------------------------------------------------------
class _ActiveTaskCard extends StatelessWidget {
  const _ActiveTaskCard({
    required this.task,
    required this.onTap,
  });

  final DailyTaskModel task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completedEvents = task.events
        .where((e) => e.completed || e.status == 'completed')
        .toList();
    final earnedCoins = completedEvents.isNotEmpty
        ? completedEvents.fold<int>(0, (sum, e) => sum + e.coins)
        : 0;

    final totalSteps = task.events.length;
    final doneSteps = completedEvents.length;

    final allEventsCompletedToday = task.events.isNotEmpty &&
        task.events.every((e) => e.completed || e.status == 'completed');

    final isEligibleNextDay = (task.dailyRewardEnabled && !task.events.any((e) => e.status == 'active')) ||
        (task.dailyReset && allEventsCompletedToday);

    final badgeText = isEligibleNextDay ? 'Eligible Next Day' : 'In Progress';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
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
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFFAB31DE).withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Left: Task Icon + Coins Pill
            Column(
              mainAxisSize: MainAxisSize.min,
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14.r),
                    child: task.imagePath.trim().isNotEmpty
                        ? InternetImage(
                            url: task.imagePath,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : _FallbackTaskIcon(name: task.offerName),
                  ),
                ),
                SizedBox(height: 5.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFFE39FFF).withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/coin.png',
                        width: 11.w,
                        height: 11.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        '+$earnedCoins coins',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(width: 12.w),

            // 2. Middle: Title + Day/Step progress + Date Timestamp
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.offerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  if (totalSteps > 0)
                    Text(
                      task.dailyRewardEnabled
                          ? 'Day $doneSteps/$totalSteps'
                          : 'Step $doneSteps/$totalSteps',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFAB31DE),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  SizedBox(height: 3.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: isEligibleNextDay ? const Color(0xFFECFDF5) : const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: isEligibleNextDay ? const Color(0xFFD1FAE5) : const Color(0xFFF3E8FF),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.outfit(
                        color: isEligibleNextDay ? const Color(0xFF059669) : const Color(0xFFAB31DE),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 8.w),

            // 3. Right: Circular Purple Gradient Forward Arrow Button
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE39FFF),
                    Color(0xFFAB31DE),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// COMPLETED TASK CARD ITEM
// ---------------------------------------------------------------------------
class _CompletedTaskCard extends StatelessWidget {
  const _CompletedTaskCard({required this.task});

  final DailyTaskModel task;

  @override
  Widget build(BuildContext context) {
    final completedEvents = task.events
        .where((e) => e.completed || e.status == 'completed')
        .toList();
    final earnedCoins = completedEvents.isNotEmpty
        ? completedEvents.fold<int>(0, (sum, e) => sum + e.coins)
        : 0;

    final isRejected = earnedCoins == 0;

    final subText = isRejected
        ? 'Verification Rejected (0 Coins)'
        : (task.subDescription.isNotEmpty
            ? task.subDescription
            : (task.offerDescription.isNotEmpty
                ? task.offerDescription.first
                : (task.offerCategory.isNotEmpty
                    ? task.offerCategory
                    : 'Daily Task Completed')));

    final dateStr = _formatTimestamp(_getTaskLatestCompletionDate(task));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isRejected
                ? const Color(0xFFEF4444).withValues(alpha: 0.04)
                : const Color(0xFF059669).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Left: Task Icon + Coin Pill
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: task.imagePath.trim().isNotEmpty
                      ? InternetImage(
                          url: task.imagePath,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : _FallbackTaskIcon(name: task.offerName),
                ),
              ),

              SizedBox(height: 5.h),

              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                decoration: BoxDecoration(
                  color: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/coin.png',
                      width: 11.w,
                      height: 11.w,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      '$earnedCoins coins',
                      style: GoogleFonts.outfit(
                        color: isRejected ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(width: 12.w),

          // 2. Middle: Title + Sub Description + Date Timestamp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.offerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: isRejected ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                    fontSize: 11.5.sp,
                    fontWeight: isRejected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (dateStr.isNotEmpty) ...[
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 11.sp,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          SizedBox(width: 8.w),

          // 3. Right: "Done" vs "Rejected" Status Chip
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRejected ? Icons.cancel_rounded : Icons.verified_rounded,
                  color: isRejected ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  size: 14.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  isRejected ? 'Rejected' : 'Done',
                  style: GoogleFonts.outfit(
                    color: isRejected ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Fallback letter icon if image missing
class _FallbackTaskIcon extends StatelessWidget {
  const _FallbackTaskIcon({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'T';
    return Container(
      color: const Color(0xFFFAF5FF),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.outfit(
          color: const Color(0xFFAB31DE),
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EMPTY ACTIVE HISTORY WIDGET
// ---------------------------------------------------------------------------
class _EmptyActiveHistoryWidget extends StatelessWidget {
  const _EmptyActiveHistoryWidget({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 30.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFAF5FF),
                border: Border.all(
                  color: const Color(0xFFE39FFF).withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.timelapse_rounded,
                  color: const Color(0xFFAB31DE),
                  size: 38.sp,
                ),
              ),
            ),

            SizedBox(height: 16.h),

            Text(
              'No Active Tasks',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E1B4B),
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),

            SizedBox(height: 6.h),

            Text(
              'You have no daily tasks in progress or eligible for next day. Start a daily task to track active milestones here!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),

            SizedBox(height: 20.h),

            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onBrowse();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 11.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE39FFF),
                      Color(0xFFAB31DE),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'Explore Daily Tasks',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EMPTY COMPLETED HISTORY WIDGET
// ---------------------------------------------------------------------------
class _EmptyTaskHistoryWidget extends StatelessWidget {
  const _EmptyTaskHistoryWidget({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 30.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFECFDF5),
                border: Border.all(
                  color: const Color(0xFFA7F3D0),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF059669),
                  size: 38.sp,
                ),
              ),
            ),

            SizedBox(height: 16.h),

            Text(
              'No Completed Tasks Yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E1B4B),
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),

            SizedBox(height: 6.h),

            Text(
              'You haven\'t fully completed any daily tasks yet. Complete all milestones of an offer to see it here!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),

            SizedBox(height: 20.h),

            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onBrowse();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 11.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE39FFF),
                      Color(0xFFAB31DE),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'Browse Daily Tasks',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ERROR STATE WIDGET
// ---------------------------------------------------------------------------
class _HistoryErrorWidget extends StatelessWidget {
  const _HistoryErrorWidget({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: const Color(0xFFEF4444),
              size: 44.sp,
            ),
            SizedBox(height: 16.h),
            Text(
              'Failed to Load History',
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E1B4B),
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAB31DE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
