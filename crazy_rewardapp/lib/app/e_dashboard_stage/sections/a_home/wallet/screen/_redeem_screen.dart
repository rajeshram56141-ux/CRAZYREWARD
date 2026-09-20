// ignore_for_file: unused_import, depend_on_referenced_packages
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../utils/helper/helper.dart';
import '../../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../../widgets/common/custom_loading.dart';
import '../../../../../../widgets/common/custom_toast.dart';
import '../../../../../../widgets/common/internet_image.dart';
import '../../../../../../widgets/screens/loading_screen.dart';
import '../../../../provider/dashboard_provider.dart';
import '../../widgets/balance_card.dart';
import '../model/wallet_catalog_model.dart';
import '../model/redeem_history_model.dart';
import '../provider/handle_redeem_request.dart';
import '../provider/wallet_catalog_provider.dart';
import '../provider/redeem_history_provider.dart';
import '../../../../../../utils/theme/theme.dart';
import '../../../../../b_splash_stage/splash_service.dart';
import '../../../../../../widgets/common/screen_banner_widget.dart';

@RoutePage()
class RedeemScreen extends HookConsumerWidget {
  const RedeemScreen({
    super.key,
    required this.userId,
    required this.country,
    required this.isGuest,
  });

  final String userId;
  final String country;
  final bool isGuest;

  // Helper method to format coin balance exactly like mockup (e.g. 12,426.00)
  String _formatBalance(double coins) {
    final String basic = coins.toStringAsFixed(2);
    final List<String> parts = basic.split('.');
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return parts.join('.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableCoins =
        ref.watch(DashboardService.userCoinsProvider(userId)).value ?? 0;
    final userAsync = ref.watch(DashboardService.userDataProvider(userId));
    final String rawName = userAsync.value?.name ?? '';
    final String userName = rawName.trim().isNotEmpty ? rawName.trim() : 'User';

    final hideConfig = ref.watch(hideDenominationConfigProvider);
    final payoutHistoryAsync = ref.watch(payoutHistoryProvider(userId));
    final int userRedeemCount = (payoutHistoryAsync.value ?? [])
        .where((p) => p.status != PayoutStatus.failed)
        .length;

    final topPadding = MediaQuery.of(context).padding.top;

    useEffect(() {
      Future.microtask(() {
        ref.invalidate(DashboardService.userDataProvider(userId));
        ref.invalidate(walletCatalogProvider(country));
        ref.invalidate(payoutHistoryProvider(userId));
      });
      return null;
    }, []);

    final catalogAsync = ref.watch(walletCatalogProvider(country));

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
            // 1. Solid White Background (Matching Home Screen)
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
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  ref.invalidate(DashboardService.userDataProvider(userId));
                  ref.invalidate(walletCatalogProvider(country));
                  ref.invalidate(payoutHistoryProvider(userId));
                  await ref.read(walletCatalogProvider(country).future);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Column(
                  children: [
                    // Header Bar (Back button + Title + History Pill)
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, topPadding + 8.h, 16.w, 14.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
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
                              SizedBox(width: 12.w),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Hi 👋',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 1.h),
                                  Text(
                                    userName,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF1E1B4B),
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (SplashService.showCoinConversionRate && SplashService.coinConversionRate > 0)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.5.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF059669).withValues(alpha: 0.08),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '≈ ₹${(availableCoins / SplashService.coinConversionRate).toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF059669),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 6.h),

                    // 3. Premium Modern Executive Wallet Balance Card (Matching Home Screen BalanceCard style 1-to-1)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                            BoxShadow(
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24.r),
                          child: Stack(
                            children: [
                              // Right Soft Purple Dome Backdrop Patti
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                width: 130.w,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFFAF5FF).withValues(alpha: 0.0),
                                        const Color(0xFFFAF5FF).withValues(alpha: 0.6),
                                        const Color(0xFFF3E8FF),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.0, 0.25, 1.0],
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(60.r),
                                      bottomLeft: Radius.circular(60.r),
                                      topRight: Radius.circular(24.r),
                                      bottomRight: Radius.circular(24.r),
                                    ),
                                  ),
                                ),
                              ),

                              // Right Mascot Image Artwork
                              Positioned(
                                right: 6.w,
                                top: 6.h,
                                bottom: 6.h,
                                width: 115.w,
                                child: Center(
                                  child: Image.asset(
                                    'assets/icons/panda 4.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                              // Content
                              Padding(
                                padding: EdgeInsets.all(18.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Available Balance Tag
                                    Row(
                                      children: [
                                        Container(
                                          width: 8.w,
                                          height: 8.w,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFFAB31DE),
                                          ),
                                        ),
                                        SizedBox(width: 7.w),
                                        Text(
                                          'Available Balance',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF64748B),
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 8.h),

                                    // Coin Balance Display
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'assets/icons/coin.png',
                                          height: 30.w,
                                          width: 30.w,
                                          fit: BoxFit.contain,
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            _formatBalance(availableCoins.toDouble()),
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF1E1B4B),
                                              fontSize: 26.sp,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 10.h),

                                    // History Pill Button (Left aligned below coin balance, away from Panda artwork)
                                    GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        AutoRouter.of(context).push(
                                          RedeemHistoryScreenRoute(
                                            userId: userId,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFE39FFF),
                                              Color(0xFFAB31DE),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(12.r),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFAB31DE).withValues(alpha: 0.22),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.history_rounded,
                                              color: Colors.white,
                                              size: 13.sp,
                                            ),
                                            SizedBox(width: 5.w),
                                            Text(
                                              'History',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 11.5.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(width: 3.w),
                                            Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              color: Colors.white,
                                              size: 9.sp,
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
                      ),
                    ),

                    SizedBox(height: 22.h),

                    if (SplashService.showCoinConversionRate && SplashService.coinConversionRate > 0)
                      Padding(
                        padding: EdgeInsets.only(bottom: 12.h, left: 16.w, right: 16.w),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: const Color(0xFFE9D5FF), width: 1),
                          ),
                          child: Center(
                            child: Text(
                              '₹ 1.00 = ${SplashService.coinConversionRate} Coins',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7E22CE),
                              ),
                            ),
                          ),
                        ),
                      ),

                    SizedBox(height: 10.h),

                    // Screen Banner (Admin Configurable 700x200 with AD badge)
                    const ScreenBannerWidget(
                      screenKey: 'redeemScreen',
                      margin: EdgeInsets.only(bottom: 14, left: 16, right: 16),
                    ),

                    // 4. Dynamic Redeem Sections (All Methods & Denominations displayed directly)
                    catalogAsync.when(
                      data: (List<WalletMethod> methods) {
                        if (methods.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40.h),
                              child: Text(
                                'No redeem methods available',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }

                        // Check if after hiding denominations, there are any visible methods
                        final List<({WalletMethod method, List<WalletDenomination> visibleDenoms})> visibleMethodsList = [];
                        for (final method in methods) {
                          final visibleDenoms = hideConfig.filterDenominations(
                            originalList: method.denominations,
                            userCoins: availableCoins.toDouble(),
                            userRedeemCount: userRedeemCount,
                          );
                          if (visibleDenoms.isNotEmpty) {
                            visibleMethodsList.add((method: method, visibleDenoms: visibleDenoms));
                          }
                        }

                        if (visibleMethodsList.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40.h),
                              child: Text(
                                'No redeem methods available',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: visibleMethodsList.map((entry) {
                            final method = entry.method;
                            final visibleDenoms = entry.visibleDenoms;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 22.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Section Header: "Redeem As [Method Title]"
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            ShaderMask(
                                              shaderCallback: (bounds) => const LinearGradient(
                                                colors: [
                                                  Color(0xFFE39FFF),
                                                  Color(0xFFAB31DE),
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ).createShader(bounds),
                                              child: Icon(
                                                Icons.confirmation_number_rounded,
                                                color: Colors.white,
                                                size: 22.sp,
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            RichText(
                                              text: TextSpan(
                                                text: 'Redeem As ',
                                                style: GoogleFonts.outfit(
                                                  color: const Color(0xFF1E1B4B),
                                                  fontSize: 16.5.sp,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -0.2,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: method.title,
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(0xFFAB31DE),
                                                      fontSize: 16.5.sp,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6.h),
                                        Container(
                                          width: 36.w,
                                          height: 2.h,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFAB31DE),
                                                Colors.transparent,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(1.r),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 14.h),

                                  // Denominations List for this method
                                  SizedBox(
                                    height: 124.h,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                                      itemCount: visibleDenoms.length,
                                      separatorBuilder: (context, index) => SizedBox(width: 12.w),
                                      itemBuilder: (context, dIndex) {
                                        final denomination = visibleDenoms[dIndex];
                                        return _buildInlineDenominationCard(
                                          context: context,
                                          method: method,
                                          denomination: denomination,
                                          availableCoins: availableCoins,
                                          userId: userId,
                                          isGuest: isGuest,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                      error: (_, __) => Center(
                        child: Text(
                          'error-subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.redAccent,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: GlowLightingSpinner(size: 32),
                        ),
                      ),
                    ),

                    SizedBox(height: 40.h),
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

  // Denomination Voucher Card UI matching Home Screen Card System
  Widget _buildInlineDenominationCard({
    required BuildContext context,
    required WalletMethod method,
    required WalletDenomination denomination,
    required double availableCoins,
    required String userId,
    required bool isGuest,
  }) {
    final String amountText = '${method.symbol}${denomination.amount}';
    final String formattedCoins = denomination.coins
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    final bool isLocked = availableCoins < denomination.coins;

    return Builder(
      builder: (cardCtx) {
        return GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            if (denomination.isOutOfStock) {
              CustomToast.showToast(
                cardCtx,
                msg: 'This denomination is currently Out of Stock',
              );
              return;
            }
            final box = cardCtx.findRenderObject() as RenderBox?;
            final rect = box != null && box.hasSize
                ? box.localToGlobal(Offset.zero) & box.size
                : null;
            await RedeemRequest.handle(
              context: cardCtx,
              availableCoins: availableCoins,
              paymentMethod: method,
              userId: userId,
              denomination: denomination,
              isGuest: isGuest,
              originRect: rect,
            );
          },
          child: Container(
            width: 142.w,
            height: 124.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: denomination.isOutOfStock
                    ? const Color(0xFFFCA5A5)
                    : (isLocked ? const Color(0xFFF1F5F9) : const Color(0xFFE39FFF).withValues(alpha: 0.5)),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: denomination.isOutOfStock
                      ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                      : (isLocked
                          ? const Color(0xFF0F172A).withValues(alpha: 0.03)
                          : const Color(0xFFAB31DE).withValues(alpha: 0.12)),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Row: Method Icon + Amount Text
                    Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                          ),
                          child: InternetImage(
                            url: method.image,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            amountText,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 17.5.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (denomination.subtitle != null && denomination.subtitle!.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          denomination.subtitle!,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    // Divider
                    Container(
                      height: 1.0,
                      width: double.infinity,
                      color: const Color(0xFFF1F5F9),
                    ),

                    // Bottom Row: If Out of Stock -> Show "OUT OF STOCK" replacing coin and arrow!
                    if (denomination.isOutOfStock) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 4.5.h),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.block_rounded,
                              size: 11.sp,
                              color: const Color(0xFFDC2626),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'OUT OF STOCK',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFDC2626),
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Bottom Row: Coin Pill + Action Arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Coin Pill
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: const Color(0xFFE39FFF).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons/coin.png',
                                  height: 11.h,
                                  width: 11.h,
                                ),
                                SizedBox(width: 3.5.w),
                                Flexible(
                                  child: Text(
                                    formattedCoins,
                                    style: GoogleFonts.outfit(
                                      color: isLocked
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFFAB31DE),
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Action arrow circle
                          Container(
                            width: 22.w,
                            height: 22.w,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isLocked
                                    ? [const Color(0xFFCBD5E1), const Color(0xFF94A3B8)]
                                    : [const Color(0xFFE39FFF), const Color(0xFFAB31DE)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isLocked
                                      ? Colors.transparent
                                      : const Color(0xFFAB31DE).withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }




}

// Backward compatibility alias
typedef WalletScreen = RedeemScreen;

// ---------------------------------------------------------------------------
// FULLSCREEN DENOMINATIONS SCREEN WITH HOME SCREEN DESIGN SYSTEM
// ---------------------------------------------------------------------------
class RedeemDenominationsScreen extends ConsumerWidget {
  final WalletMethod method;
  final double availableCoins;
  final String userId;
  final bool isGuest;

  const RedeemDenominationsScreen({
    super.key,
    required this.method,
    required this.availableCoins,
    required this.userId,
    required this.isGuest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideConfig = ref.watch(hideDenominationConfigProvider);
    final payoutHistoryAsync = ref.watch(payoutHistoryProvider(userId));
    final int userRedeemCount = (payoutHistoryAsync.value ?? [])
        .where((p) => p.status != PayoutStatus.failed)
        .length;

    final visibleDenominations = hideConfig.filterDenominations(
      originalList: method.denominations,
      userCoins: availableCoins,
      userRedeemCount: userRedeemCount,
    );

    final String formattedBalance = availableCoins.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Solid White Background
          Positioned.fill(
            child: Container(
              color: Colors.white,
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. App Bar Row
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
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

                      // Current Coins Balance Pill
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: const Color(0xFFE39FFF).withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/icons/coin.png',
                              width: 15.w,
                              height: 15.w,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              formattedBalance,
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

                // 2. Main content area (Scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 20.h),

                        // Method Big Icon Box
                        Container(
                          width: 82.w,
                          height: 82.w,
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
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14.r),
                            child: InternetImage(
                              url: method.image,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        SizedBox(height: 14.h),

                        // Title Text
                        Text(
                          'Redeem ${method.title}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),

                        SizedBox(height: 24.h),

                        // Denominations Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14.w,
                            mainAxisSpacing: 14.w,
                            childAspectRatio: 0.80,
                          ),
                          itemCount: visibleDenominations.length,
                          itemBuilder: (context, index) {
                            final denomination = visibleDenominations[index];
                            return _buildPremiumDenominationCard(
                              context: context,
                              denomination: denomination,
                            );
                          },
                        ),

                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Denominations Card UI for Fullscreen Screen
  Widget _buildPremiumDenominationCard({
    required BuildContext context,
    required WalletDenomination denomination,
  }) {
    final String amountText = '${method.symbol}${denomination.amount}';
    final String formattedCoins = denomination.coins
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    final bool isLocked = availableCoins < denomination.coins;

    return Builder(
      builder: (cardCtx) {
        return GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            if (denomination.isOutOfStock) {
              CustomToast.showToast(
                cardCtx,
                msg: 'This denomination is currently Out of Stock',
              );
              return;
            }
            final box = cardCtx.findRenderObject() as RenderBox?;
            final rect = box != null && box.hasSize
                ? box.localToGlobal(Offset.zero) & box.size
                : null;
            await RedeemRequest.handle(
              context: cardCtx,
              availableCoins: availableCoins,
              paymentMethod: method,
              userId: userId,
              denomination: denomination,
              isGuest: isGuest,
              originRect: rect,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: denomination.isOutOfStock
                    ? const Color(0xFFFCA5A5)
                    : (isLocked ? const Color(0xFFF1F5F9) : const Color(0xFFE39FFF).withValues(alpha: 0.5)),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: denomination.isOutOfStock
                      ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                      : (isLocked
                          ? const Color(0xFF0F172A).withValues(alpha: 0.03)
                          : const Color(0xFFAB31DE).withValues(alpha: 0.12)),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Reward Voucher Amount
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFAF5FF),
                            ),
                          ),
                          Text(
                            amountText,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      if (denomination.subtitle != null && denomination.subtitle!.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          denomination.subtitle!,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                if (denomination.isOutOfStock) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block_rounded,
                          size: 13.sp,
                          color: const Color(0xFFDC2626),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          'OUT OF STOCK',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFDC2626),
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Coins Price Label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/coin.png',
                        height: 14.h,
                        width: 14.h,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        formattedCoins,
                        style: GoogleFonts.outfit(
                          color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFFAB31DE),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10.h),

                  // Redeem Button
                  _DenominationRedeemButton(
                    onTap: () async {
                      final box = cardCtx.findRenderObject() as RenderBox?;
                      final rect = box != null && box.hasSize
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      await RedeemRequest.handle(
                        context: cardCtx,
                        availableCoins: availableCoins,
                        paymentMethod: method,
                        userId: userId,
                        denomination: denomination,
                        isGuest: isGuest,
                        originRect: rect,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// Backward compatibility alias
typedef WalletDenominationsScreen = RedeemDenominationsScreen;

// Interactive 3D Purple Redeem Button
class _DenominationRedeemButton extends StatefulWidget {
  final VoidCallback onTap;

  const _DenominationRedeemButton({
    required this.onTap,
  });

  @override
  State<_DenominationRedeemButton> createState() =>
      _DenominationRedeemButtonState();
}

class _DenominationRedeemButtonState extends State<_DenominationRedeemButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          height: 34.h,
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
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFAB31DE).withValues(
                  alpha: _isPressed ? 0.20 : 0.40,
                ),
                blurRadius: _isPressed ? 4 : 8,
                offset: Offset(0, _isPressed ? 1 : 3),
              ),
            ],
          ),
          child: Text(
            'REDEEM',
            style: GoogleFonts.outfit(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}
