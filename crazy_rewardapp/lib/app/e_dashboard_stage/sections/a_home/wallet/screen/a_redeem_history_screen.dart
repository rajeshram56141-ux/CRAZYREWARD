// ignore_for_file: unused_import, deprecated_member_use, depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/legacy.dart';

import '../../../../../../services/launch_url.dart';
import '../../../../../../utils/helper/helper.dart';
import '../../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../../widgets/common/custom_loading.dart';
import '../../../../../../widgets/common/custom_toast.dart';
import '../../../../../../widgets/common/internet_image.dart';
import '../model/redeem_history_model.dart';
import '../provider/redeem_history_provider.dart';

final _historyFilterStateProvider =
    StateProvider<PayoutStatus?>((ref) => null);

@RoutePage()
class RedeemHistoryScreen extends HookConsumerWidget {
  const RedeemHistoryScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      Future.microtask(() {
        ref.invalidate(payoutHistoryProvider(userId));
      });
      return null;
    }, [userId]);

    final selectedStatus = ref.watch(_historyFilterStateProvider);
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
            // 1. Solid White Background (Matching Home & Redeem Screen)
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header with Back Button and Page Title
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, topPadding + 8.h, 16.w, 14.h),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => AutoRouter.of(context).maybePop(),
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
                          SizedBox(width: 14.w),
                          Text(
                            'History',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 18.5.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 4.h),

                    // 2. Horizontally Scrollable Filter Chips (Pure White Luxury Style)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        child: Row(
                          children: [
                            _buildFilterChip(context, ref, 'All', null, selectedStatus),
                            SizedBox(width: 8.w),
                            _buildFilterChip(context, ref, 'Successful', PayoutStatus.successful, selectedStatus),
                            SizedBox(width: 8.w),
                            _buildFilterChip(context, ref, 'Processing', PayoutStatus.inProgress, selectedStatus),
                            SizedBox(width: 8.w),
                            _buildFilterChip(context, ref, 'Pending', PayoutStatus.pending, selectedStatus),
                            SizedBox(width: 8.w),
                            _buildFilterChip(context, ref, 'Failed', PayoutStatus.failed, selectedStatus),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // 3. Transactions Content List
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: ref.watch(payoutHistoryProvider(userId)).when(
                            data: (List<PayoutHistoryModel> payouts) {
                              if (payouts.isEmpty) {
                                return _buildEmptyState(context);
                              }

                              final filteredPayouts = selectedStatus == null
                                  ? payouts
                                  : payouts.where((p) => p.status == selectedStatus).toList();

                              if (filteredPayouts.isEmpty) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 60.h),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 64.w,
                                          height: 64.w,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFAF5FF),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.receipt_long_outlined,
                                            color: const Color(0xFFAB31DE),
                                            size: 32.sp,
                                          ),
                                        ),
                                        SizedBox(height: 14.h),
                                        Text(
                                          'No transactions for ${_getFilterName(selectedStatus)}',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF1E1B4B),
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          'Try switching to another filter category above.',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF64748B),
                                            fontSize: 12.5.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredPayouts.length,
                                itemBuilder: (context, index) {
                                  return _buildHistoryCard(context, filteredPayouts[index]);
                                },
                              );
                            },
                            error: (_, __) => Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 40.h),
                                child: Text(
                                  'error-subtitle'.tr(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFEF4444),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            loading: () => Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 50.h),
                                child: const CircularProgressIndicator(
                                  color: Color(0xFFAB31DE),
                                ),
                              ),
                            ),
                          ),
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Clean Luxury History Card Item (Matching Redeem & Home Screen 1-to-1)
  Widget _buildHistoryCard(BuildContext context, PayoutHistoryModel payout) {
    final hasCode = payout.redeemCode.isNotEmpty &&
        payout.redeemCode.toLowerCase() != 'n/a';

    final dateStr = _formatCustomDate(payout.timestamp);
    final accountStr = _extractAccountDetail(payout);

    final String formattedCoins = payout.coins.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    final (statusLabel, statusBg, statusFg, statusIcon) = _getStatusBadgeStyle(payout.status);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        AutoRouter.of(context).push(
          RedeemHistoryDetailsScreenRoute(history: payout),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: const Color(0xFFAB31DE).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Method Icon + Title & Date + Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Box
                Container(
                  width: 46.w,
                  height: 46.w,
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(15.r),
                    border: Border.all(
                      color: const Color(0xFFF3E8FF),
                      width: 1.2,
                    ),
                  ),
                  child: payout.image.isNotEmpty
                      ? InternetImage(
                          url: payout.image,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          Icons.receipt_long_rounded,
                          color: const Color(0xFFAB31DE),
                          size: 22.sp,
                        ),
                ),
                SizedBox(width: 12.w),

                // Method Title & Timestamp
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payout.title,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 8.w),

                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 11.sp,
                        color: statusFg,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        statusLabel,
                        style: GoogleFonts.outfit(
                          color: statusFg,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Divider Line
            Container(
              height: 1,
              width: double.infinity,
              color: const Color(0xFFF1F5F9),
            ),

            SizedBox(height: 10.h),

            // Row 2: Account/Code info (Left) + Amount & Coins (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Account or Voucher Code Badge
                Expanded(
                  child: hasCode
                      ? GestureDetector(
                          onTap: () {
                            final cleanCode = payout.redeemCode.trim();
                            Clipboard.setData(ClipboardData(text: cleanCode));
                            HapticFeedback.lightImpact();

                            final titleLower = payout.title.toLowerCase();
                            final methodLower = payout.methodName.toLowerCase();
                            final isGooglePlay = titleLower.contains('google') ||
                                titleLower.contains('play') ||
                                methodLower.contains('google') ||
                                methodLower.contains('play');

                            if (isGooglePlay) {
                              CustomToast.showToast(
                                context,
                                msg: 'Code Copied! Opening Google Play...',
                              );
                              LaunchUrl.inWeb(
                                url: 'https://play.google.com/redeem?code=${Uri.encodeComponent(cleanCode)}',
                                context: context,
                              );
                            } else {
                              CustomToast.showToast(
                                context,
                                msg: 'copied-to-clipboard'.tr(),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.confirmation_number_rounded,
                                  color: const Color(0xFFAB31DE),
                                  size: 12.sp,
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    payout.redeemCode,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFAB31DE),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Icon(
                                  Icons.copy_rounded,
                                  color: const Color(0xFFAB31DE),
                                  size: 11.sp,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Text(
                          accountStr.isNotEmpty
                              ? accountStr
                              : '${payout.symbol}${payout.amount} Payout',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),

                SizedBox(width: 10.w),

                // Amount & Coins
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${payout.symbol}${payout.amount}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Image.asset(
                      'assets/icons/coin.png',
                      height: 15.w,
                      width: 15.w,
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      formattedCoins,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFAB31DE),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Failure Reason Box
            if (payout.status == PayoutStatus.failed && payout.failureReason.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: const Color(0xFFFECACA),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: const Color(0xFFEF4444),
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        'Reason: ${payout.failureReason}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFB91C1C),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Modern Luxury Category Filter Chip Widget
  Widget _buildFilterChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    PayoutStatus? status,
    PayoutStatus? selectedStatus,
  ) {
    final isSelected = selectedStatus == status;

    final IconData icon;
    final Color accentColor;
    switch (status) {
      case PayoutStatus.successful:
        icon = Icons.check_circle_rounded;
        accentColor = const Color(0xFF16A34A);
        break;
      case PayoutStatus.inProgress:
        icon = Icons.sync_rounded;
        accentColor = const Color(0xFFD97706);
        break;
      case PayoutStatus.pending:
        icon = Icons.schedule_rounded;
        accentColor = const Color(0xFFD97706);
        break;
      case PayoutStatus.failed:
        icon = Icons.cancel_rounded;
        accentColor = const Color(0xFFDC2626);
        break;
      case null:
        icon = Icons.grid_view_rounded;
        accentColor = const Color(0xFFAB31DE);
        break;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(_historyFilterStateProvider.notifier).state = status;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
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
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.sp,
              color: isSelected ? Colors.white : accentColor,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontSize: 12.5.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern Pure White Empty State Widget
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 60.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF3E8FF),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: const Color(0xFFAB31DE),
                size: 46.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'No History Yet!',
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E1B4B),
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Your completed payouts and voucher redemptions will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 13.sp,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterName(PayoutStatus? status) {
    switch (status) {
      case PayoutStatus.successful:
        return 'Successful';
      case PayoutStatus.pending:
        return 'Pending';
      case PayoutStatus.inProgress:
        return 'Processing';
      case PayoutStatus.failed:
        return 'Failed';
      default:
        return 'All';
    }
  }

  String _formatCustomDate(Timestamp ts) {
    try {
      final date = ts.toDate();
      final DateFormat formatter = DateFormat('d MMM yyyy , h:mm a');
      final formatted = formatter.format(date);
      return formatted;
    } catch (_) {
      return '';
    }
  }

  String _extractAccountDetail(PayoutHistoryModel payout) {
    final details = payout.methodDetails;
    if (details.upiId != null && details.upiId!.trim().isNotEmpty) {
      return details.upiId!.trim();
    }
    if (details.email != null && details.email!.trim().isNotEmpty) {
      return details.email!.trim();
    }
    if (details.name != null && details.name!.trim().isNotEmpty) {
      return details.name!.trim();
    }
    for (final entry in details.customFields.entries) {
      if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }
    return '';
  }

  (String, Color, Color, IconData) _getStatusBadgeStyle(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.successful:
        return ('Success', const Color(0xFFDCFCE7), const Color(0xFF15803D), Icons.check_circle_rounded);
      case PayoutStatus.failed:
        return ('Redeem Failed', const Color(0xFFFEE2E2), const Color(0xFFDC2626), Icons.cancel_rounded);
      case PayoutStatus.inProgress:
        return ('Processing', const Color(0xFFFEF3C7), const Color(0xFFD97706), Icons.sync_rounded);
      case PayoutStatus.pending:
        return ('Pending', const Color(0xFFFEF3C7), const Color(0xFFD97706), Icons.schedule_rounded);
    }
  }
}
