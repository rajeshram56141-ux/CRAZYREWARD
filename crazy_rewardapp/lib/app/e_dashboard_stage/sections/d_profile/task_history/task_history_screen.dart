// ignore_for_file: depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/helper/helper.dart';
import '../../../../../widgets/screens/loading_screen.dart';
import 'task_history_model.dart';
import 'task_history_provider.dart';

// Filter options for Coin History
enum _CoinFilterType { all, earned, spent }

@RoutePage()
class TaskHistoryScreen extends HookConsumerWidget {
  const TaskHistoryScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      Future.microtask(() {
        ref.invalidate(rewardHistoryProvider(userId));
      });
      return null;
    }, [userId]);

    final selectedFilter = useState<_CoinFilterType>(_CoinFilterType.all);

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
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Custom Navigation Bar (Leaderboard style back button + Centered Title)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: const Color(0xFF26262B),
                          size: 20.sp,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Coin History',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF26262B),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 40.w), // Balance back button
                  ],
                ),
              ),

              // Filter Chips Row
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All Activity',
                      icon: Icons.grid_view_rounded,
                      type: _CoinFilterType.all,
                      selected: selectedFilter.value,
                      onTap: () => selectedFilter.value = _CoinFilterType.all,
                    ),
                    SizedBox(width: 8.w),
                    _buildFilterChip(
                      label: 'Earned (+)',
                      icon: Icons.add_circle_outline_rounded,
                      type: _CoinFilterType.earned,
                      selected: selectedFilter.value,
                      onTap: () => selectedFilter.value = _CoinFilterType.earned,
                    ),
                    SizedBox(width: 8.w),
                    _buildFilterChip(
                      label: 'Spent (-)',
                      icon: Icons.remove_circle_outline_rounded,
                      type: _CoinFilterType.spent,
                      selected: selectedFilter.value,
                      onTap: () => selectedFilter.value = _CoinFilterType.spent,
                    ),
                  ],
                ),
              ),

              // 2. Main Scrollable Body
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFF26262B),
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    ref.invalidate(rewardHistoryProvider(userId));
                    await ref.read(rewardHistoryProvider(userId).future).catchError((_) => <CoinHistoryModel>[]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      6.h,
                      16.w,
                      MediaQuery.of(context).padding.bottom + 20.h,
                    ),
                    child: ref.watch(rewardHistoryProvider(userId)).when(
                          data: (List<CoinHistoryModel> historyList) {
                            // Filter items according to the selected chip
                            final filteredList = historyList.where((item) {
                              final isTask = item.type == CoinHistoryType.task;
                              final cleanStatus = (item.status ?? '').trim().toLowerCase();
                              final isFailedOrRefund = cleanStatus == 'failed' ||
                                  cleanStatus == 'refund' ||
                                  cleanStatus == 'refunded' ||
                                  cleanStatus == 'rejected';

                              // Exclude any failed or refund withdrawal records completely
                              if (!isTask && isFailedOrRefund) {
                                return false;
                              }

                              switch (selectedFilter.value) {
                                case _CoinFilterType.all:
                                  return true;
                                case _CoinFilterType.earned:
                                  return isTask;
                                case _CoinFilterType.spent:
                                  return !isTask;
                              }
                            }).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // List View / Filtered Empty State
                                if (historyList.isEmpty)
                                  _buildEmptyState(
                                    title: 'No Coin History Found',
                                    subtitle: 'Your coin earnings and spending history will appear here.',
                                  )
                                else if (filteredList.isEmpty)
                                  _buildEmptyState(
                                    title: 'No Transactions Found',
                                    subtitle: 'No records matching the selected filter.',
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.only(bottom: 20.h),
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredList.length,
                                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                                    itemBuilder: (context, index) {
                                      return _CoinHistoryCard(history: filteredList[index]);
                                    },
                                  ),
                              ],
                            );
                          },
                          error: (e, _) => Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 60.h),
                              child: Text(
                                'error-subtitle'.tr(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFEF4444),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          loading: () => const Center(
                            child: LoadingInfoWidget(color: Color(0xFF26262B)),
                          ),
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required _CoinFilterType type,
    required _CoinFilterType selected,
    required VoidCallback onTap,
  }) {
    final isSelected = type == selected;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 36.h,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFF26262B),
                      Color(0xFF16161A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? const Color(0xFF2E2E36) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF16161A).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13.sp,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              SizedBox(width: 5.w),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 11.5.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState({required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68.w,
              height: 68.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: const Color(0xFF26262B),
                size: 30.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF26262B),
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// COIN HISTORY ITEM CARD (LUXURY CARD DESIGN)
// -------------------------------------------------------------
class _CoinHistoryCard extends StatelessWidget {
  const _CoinHistoryCard({required this.history});

  final CoinHistoryModel history;

  @override
  Widget build(BuildContext context) {
    final isTask = history.type == CoinHistoryType.task;
    final cleanStatus = (history.status ?? '').trim().toLowerCase();

    final String amountPrefix = isTask ? '+' : '-';
    final String? statusLabel = isTask
        ? null
        : (cleanStatus == 'success' || cleanStatus == 'successful'
            ? 'Successful'
            : 'Pending');

    final Color iconBgColor = isTask
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFFE4E6);

    final Color iconColor = isTask
        ? const Color(0xFF16A34A)
        : const Color(0xFFE11D48);

    final Color amountColor = isTask ? const Color(0xFF16A34A) : const Color(0xFFE11D48);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Icon Badge
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isTask
                ? Image.asset(
                    'assets/icons/coin.png',
                    width: 22.w,
                    height: 22.w,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    Icons.account_balance_wallet_rounded,
                    color: iconColor,
                    size: 20.sp,
                  ),
          ),
          SizedBox(width: 12.w),

          // 2. Title & Date Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  history.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: const Color(0xFF94A3B8),
                      size: 12.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      history.timestamp.formatTimestamp(),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (statusLabel != null) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: statusLabel == 'Successful'
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.poppins(
                            color: statusLabel == 'Successful'
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // 3. Amount Display
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$amountPrefix${history.coins.formatBalance()}',
                style: GoogleFonts.poppins(
                  color: amountColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 4.w),
              Image.asset(
                'assets/icons/coin.png',
                width: 15.w,
                height: 15.w,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
