import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../services/launch_url.dart';
import '../../../../../../utils/helper/helper.dart';
import '../../../../../../widgets/common/custom_toast.dart';
import '../../../../../../widgets/common/internet_image.dart';
import '../model/redeem_history_model.dart';

@RoutePage()
class RedeemHistoryDetailsScreen extends StatelessWidget {
  const RedeemHistoryDetailsScreen({super.key, required this.history});

  final PayoutHistoryModel history;

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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final (statusLabel, statusBg, statusFg, statusIcon) = _getStatusBadgeStyle(history.status);

    final cleanCode = history.redeemCode.trim();
    final hasCode = cleanCode.isNotEmpty && cleanCode.toLowerCase() != 'n/a';
    final methodLower = history.methodName.trim().toLowerCase();
    final titleLower = history.title.trim().toLowerCase();
    final isGooglePlay = titleLower.contains('google') ||
        titleLower.contains('play') ||
        methodLower.contains('google') ||
        methodLower.contains('play');

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

            // 2. Main Content Stack
            Positioned.fill(
              child: Column(
                children: [
                  // Top Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, topPadding + 8.h, 16.w, 14.h),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
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
                          'Details',
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

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        children: [
                          SizedBox(height: 12.h),

                          // Top Icon Orb Aura (Matching Modern Pure White Executive Style)
                          Container(
                            width: 80.w,
                            height: 80.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFAF5FF),
                              border: Border.all(
                                color: const Color(0xFFF3E8FF),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(10.w),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(8.w),
                                child: InternetImage(
                                  url: history.image,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 14.h),

                          // Method Name Title
                          Text(
                            history.title.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontWeight: FontWeight.w800,
                              fontSize: 19.sp,
                              letterSpacing: 0.3,
                            ),
                          ),

                          SizedBox(height: 18.h),

                          // Details Card Container
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(18.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24.r),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transaction Overview',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF1E1B4B),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5.sp,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Container(
                                  height: 1,
                                  width: double.infinity,
                                  color: const Color(0xFFF1F5F9),
                                ),
                                SizedBox(height: 14.h),

                                _row(context, 'payment-method', history.title),
                                _row(
                                  context,
                                  'date-time',
                                  history.timestamp.formatTimestamp(),
                                ),
                                _row(
                                  context,
                                  'amount',
                                  '${history.symbol}${history.amount}',
                                  color: const Color(0xFF1E1B4B),
                                ),

                                // Status Row
                                Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${'status'.tr()} :',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF64748B),
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              statusIcon,
                                              size: 12.sp,
                                              color: statusFg,
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              statusLabel,
                                              style: GoogleFonts.outfit(
                                                color: statusFg,
                                                fontSize: 11.5.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                _row(context, 'withdraw-id', history.orderId),

                                if (history.methodDetails.email != null ||
                                    history.methodDetails.upiId != null ||
                                    history.methodDetails.name != null) ...[
                                  SizedBox(height: 4.h),
                                  history.methodDetails.toWidgetFromMap(
                                    context,
                                    labelColor: const Color(0xFF64748B),
                                    valueColor: const Color(0xFF1E1B4B),
                                    iconColor: const Color(0xFFAB31DE),
                                  ),
                                ],

                                // Rejection / Failure Reason Box (Matching Executive Red Styling)
                                if (history.status == PayoutStatus.failed && history.failureReason.isNotEmpty) ...[
                                  SizedBox(height: 10.h),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(14.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF5F5),
                                      borderRadius: BorderRadius.circular(16.r),
                                      border: Border.all(
                                        color: const Color(0xFFFECACA),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline_rounded,
                                              color: const Color(0xFFDC2626),
                                              size: 18.sp,
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              'Rejection / Failure Reason',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF991B1B),
                                                fontSize: 13.5.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          history.failureReason,
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFB91C1C),
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w500,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Voucher Code Box (Matching Luxury Voucher Design System 1-to-1)
                                if (hasCode) ...[
                                  SizedBox(height: 10.h),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(14.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF5FF),
                                      borderRadius: BorderRadius.circular(18.r),
                                      border: Border.all(
                                        color: const Color(0xFFAB31DE).withValues(alpha: 0.28),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 26.w,
                                              height: 26.w,
                                              padding: EdgeInsets.all(4.w),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8.r),
                                                border: Border.all(
                                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: history.image.isNotEmpty
                                                  ? InternetImage(url: history.image)
                                                  : Icon(
                                                      Icons.card_giftcard_rounded,
                                                      size: 14.sp,
                                                      color: const Color(0xFFAB31DE),
                                                    ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              isGooglePlay ? 'Google Play Gift Code' : 'Voucher Code',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFF1E1B4B),
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10.h),
                                        Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12.r),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  cleanCode,
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFFAB31DE),
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.0,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: cleanCode));
                                                  HapticFeedback.lightImpact();

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
                                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFAB31DE),
                                                    borderRadius: BorderRadius.circular(8.r),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.copy_rounded,
                                                        color: Colors.white,
                                                        size: 12.sp,
                                                      ),
                                                      SizedBox(width: 4.w),
                                                      Text(
                                                        'COPY',
                                                        style: GoogleFonts.outfit(
                                                          color: Colors.white,
                                                          fontSize: 11.5.sp,
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
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: 20.h),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Button
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, topPadding > 0 ? 20.h : 16.h),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        height: 48.h,
                        alignment: Alignment.center,
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
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'GO BACK',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${label.tr()} :',
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: color ?? const Color(0xFF1E1B4B),
                fontWeight: FontWeight.w700,
                fontSize: 13.5.sp,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// Backward compatibility alias
typedef WithdrawalHistoryDetailsScreen = RedeemHistoryDetailsScreen;
