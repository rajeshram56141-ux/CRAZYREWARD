// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../../services/analytics_service.dart';
import '../../../../../services/cloud_functions.dart';
import '../../../../../services/launch_url.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';

@RoutePage()
class PromoCodeScreen extends HookConsumerWidget {
  const PromoCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promoCodeCon = useTextEditingController();
    final isLoading = useState<bool>(false);
    final errorMessage = useState<String?>(null);
    final refreshTrigger = useState<int>(0);

    useEffect(() {
      return () {
        ref.invalidate(DashboardService.userDataProvider);
      };
    }, const []);

    // 🚀 Fetch ONLY Real Dynamic Recent Redemptions from Server (No Fake Fallback)
    final recentRedemptionsAsync = useFuture(
      useMemoized(() async {
        try {
          final uri = Uri.parse('${AppConst.serverBaseUrl}/api/promo-code/recent');
          final res = await http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (AppConst.apiKey.isNotEmpty) 'x-api-key': AppConst.apiKey,
            },
          ).timeout(const Duration(seconds: 8));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            if (data['success'] == true && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            }
          }
        } catch (_) {}
        return <Map<String, dynamic>>[];
      }, [refreshTrigger.value]),
    );

    Future<void> submitPromoCode() async {
      if (isLoading.value) return;
      final codeText = promoCodeCon.text.trim();
      if (codeText.isEmpty) {
        errorMessage.value = 'Please enter your special code.';
        CustomStatusPopup.showFailed(
          context: context,
          title: 'Code Required',
          message: 'Please enter a valid special code to redeem.',
        );
        return;
      }

      FocusScope.of(context).unfocus();
      isLoading.value = true;
      errorMessage.value = null;

      try {
        final String msg = await CloudFunctions.promoCodeReward(
          codeText.toUpperCase(),
        );
        if (context.mounted) {
          final lowerMsg = msg.toLowerCase();
          if (lowerMsg.contains('invalid') ||
              lowerMsg.contains('incorrect') ||
              lowerMsg.contains('error') ||
              lowerMsg.contains('failed') ||
              lowerMsg.contains('expired') ||
              lowerMsg.contains('already')) {
            errorMessage.value = msg;
            CustomStatusPopup.showFailed(
              context: context,
              title: 'Redemption Failed',
              message: msg,
            );
          } else {
            AnalyticsService.logPromoCodeRedeemed(code: codeText.toUpperCase());
            promoCodeCon.clear();
            refreshTrigger.value++; // Refresh the real recent redemptions list!
            CustomStatusPopup.showSuccess(
              context: context,
              title: 'Coins Claimed!',
              message: msg.isNotEmpty ? msg : 'Promo code redeemed successfully! Coins credited.',
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
          final errTxt = (cleanMsg.isNotEmpty && !cleanMsg.contains('Instance of'))
              ? cleanMsg
              : 'The promo code you entered is invalid or expired.';
          errorMessage.value = errTxt;
          CustomStatusPopup.showFailed(
            context: context,
            title: 'Redemption Failed',
            message: errTxt,
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    final redemptionsList = recentRedemptionsAsync.data ?? <Map<String, dynamic>>[];
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Solid Clean White Base Background
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  topPadding + 8.h,
                  16.w,
                  isKeyboardOpen ? 40.h : 130.h + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            AutoRouter.of(context).maybePop();
                          },
                          borderRadius: BorderRadius.circular(14.r),
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
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
                        SizedBox(width: 12.w),
                        Text(
                          'Promo Code',
                          style: GoogleFonts.kaushanScript(
                            color: const Color(0xFF26262B),
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    // Screen Banner (Admin Configurable 700x200 with AD badge)
                    const ScreenBannerWidget(
                      screenKey: 'promoCodeScreen',
                      margin: EdgeInsets.only(bottom: 14),
                    ),

                    // Executive Promo Code Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
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
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1.0,
                                  ),
                                ),
                                child: Icon(
                                  Icons.confirmation_num_rounded,
                                  color: const Color(0xFF26262B),
                                  size: 22.sp,
                                ),
                              ),
                              SizedBox(width: 14.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Redeem Special Code',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF26262B),
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Enter code & claim instant reward coins',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF64748B),
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 18.h),

                          // Code Input Box with Integrated Paste Button
                          Container(
                            height: 48.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 14.w),
                                Expanded(
                                  child: TextFormField(
                                    controller: promoCodeCon,
                                    textCapitalization: TextCapitalization.characters,
                                    cursorColor: const Color(0xFF26262B),
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF26262B),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                    onChanged: (_) {
                                      if (errorMessage.value != null) {
                                        errorMessage.value = null;
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Enter your code',
                                      hintStyle: GoogleFonts.poppins(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (promoCodeCon.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: const Color(0xFF94A3B8),
                                      size: 18.sp,
                                    ),
                                    onPressed: () {
                                      promoCodeCon.clear();
                                      errorMessage.value = null;
                                    },
                                  ),
                                // Paste Button
                                GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                                      promoCodeCon.text = data.text!.trim();
                                      errorMessage.value = null;
                                    }
                                  },
                                  child: Container(
                                    width: 48.w,
                                    height: 48.h,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(14.r),
                                        bottomRight: Radius.circular(14.r),
                                      ),
                                      border: const Border(
                                        left: BorderSide(
                                          color: Color(0xFFE2E8F0),
                                          width: 1.2,
                                        ),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.content_paste_rounded,
                                      color: const Color(0xFF26262B),
                                      size: 18.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (errorMessage.value != null) ...[
                            SizedBox(height: 8.h),
                            Text(
                              errorMessage.value!,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFEF4444),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          SizedBox(height: 16.h),

                          // Apply Code Button (Silver Metallic Gradient Button)
                          GestureDetector(
                            onTap: submitPromoCode,
                            child: Container(
                              width: double.infinity,
                              height: 48.h,
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
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: const Color(0xFF9CA3AF),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isLoading.value
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16161A)),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: const Color(0xFF16161A),
                                            size: 18.sp,
                                          ),
                                          SizedBox(width: 8.w),
                                          Text(
                                            'Apply Code',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF16161A),
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w800,
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

                    SizedBox(height: 24.h),

                    // Section Heading: Recent Redemption
                    Row(
                      children: [
                        Container(
                          width: 4.w,
                          height: 16.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF26262B),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Recent Redemptions',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF26262B),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    // Recent Redemptions List
                    if (recentRedemptionsAsync.connectionState == ConnectionState.waiting) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF26262B)),
                          ),
                        ),
                      ),
                    ] else if (redemptionsList.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'No redemptions yet. Be the first to redeem a special code!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: redemptionsList.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final item = redemptionsList[index];
                          final codeText = item['code']?.toString() ?? 'CODE*****1234';
                          final coinsVal = item['coins']?.toString() ?? '500';

                          String dateFormatted = item['date']?.toString() ?? '';
                          if (dateFormatted.isEmpty) {
                            final tsStr = item['timestamp']?.toString();
                            if (tsStr != null && tsStr.isNotEmpty) {
                              final dt = DateTime.tryParse(tsStr);
                              if (dt != null) {
                                dateFormatted = 'Redeemed on ${DateFormat('dd MMM yyyy').format(dt)}';
                              }
                            }
                          }
                          if (dateFormatted.isEmpty) {
                            dateFormatted = 'Redeemed on ${DateFormat('dd MMM yyyy').format(DateTime.now())}';
                          }

                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
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
                              children: [
                                // Voucher / Gift Badge Icon
                                Container(
                                  width: 38.w,
                                  height: 38.w,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10.r),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Image.asset(
                                    'assets/icons/suprerofferdhn.png',
                                    width: 22.w,
                                    height: 22.w,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.card_giftcard_rounded,
                                      color: const Color(0xFF26262B),
                                      size: 20.sp,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        codeText,
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF26262B),
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        dateFormatted,
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF64748B),
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Reward Coin Chip (Dark Pill)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF26262E),
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(
                                      color: const Color(0xFF383842),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
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
                                        coinsVal.startsWith('+') ? coinsVal : '+$coinsVal',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Pinned Bottom Telegram Community Banner
            if (!isKeyboardOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    10.h,
                    16.w,
                    bottomInset > 0 ? bottomInset + 6.h : 14.h,
                  ),
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    child: Row(
                      children: [
                        // Telegram Icon Box
                        Container(
                          width: 40.w,
                          height: 40.w,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          child: Image.asset(
                            'assets/icons/telegram.png',
                            width: 24.w,
                            height: 24.w,
                            fit: BoxFit.contain,
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Join Telegram Channel',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF26262B),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Get daily promo codes & updates',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(width: 8.w),

                        // Join Button (Silver Metallic)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final link = SplashService.urlConfig.telegramLink.isNotEmpty
                                ? SplashService.urlConfig.telegramLink
                                : 'https://t.me/crazyreward';
                            LaunchUrl.inWeb(
                              url: link,
                              context: context,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: const Color(0xFF9CA3AF),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'Join Now',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF16161A),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
    );
  }
}
