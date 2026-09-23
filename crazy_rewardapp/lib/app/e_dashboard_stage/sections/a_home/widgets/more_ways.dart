import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../b_splash_stage/splash_service.dart';

class MoreWaysSection extends StatelessWidget {
  const MoreWaysSection({
    super.key,
    required this.userId,
    required this.email,
    required this.country,
    required this.currentIndex,
  });

  final String userId;
  final String email;
  final String country;
  final ValueNotifier<int> currentIndex;

  @override
  Widget build(BuildContext context) {
    const double cardWidth = 148.0;
    final double cardWidthScaled = cardWidth.w;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: "Special For You"
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Container(
                width: 4.w,
                height: 18.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'Special For You',
                style: GoogleFonts.kaushanScript(
                  color: const Color(0xFF26262B),
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12.h),

        // Horizontal Scrollable Row (Cards fit properly without clipping)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              // 1. Refer & Earn
              _SpecialCard(
                width: cardWidthScaled,
                title: 'Refer & Earn',
                subtitle: 'Win upto 500',
                iconPath: 'assets/Icons1/pngtree-d-blue-shield-with-check-mark-in-orange-circle-icon-security-png-image_16822296 1.png',
                iconWidth: 40.w,
                iconHeight: 40.w,
                onTap: () {
                  HapticFeedback.lightImpact();
                  currentIndex.value = 1; // Switches to Refer / Invite Tab
                },
              ),

              SizedBox(width: 10.w),

              // 2. Leaderboard
              _SpecialCard(
                width: cardWidthScaled,
                title: 'Leaderboard',
                subtitle: 'Win upto 500',
                iconPath: 'assets/Icons1/image 39.png',
                iconWidth: 42.w,
                iconHeight: 38.h,
                onTap: () {
                  HapticFeedback.lightImpact();
                  currentIndex.value = 4; // Switches to Leaderboard (Rank) Tab
                },
              ),

              // 4. Promo Code
              if (!SplashService.isScreenHidden('promoCode')) ...[
                SizedBox(width: 10.w),
                _SpecialCard(
                  width: cardWidthScaled,
                  title: 'Promo Code',
                  subtitle: 'Win upto 500',
                  iconPath: 'assets/icons/somthiwnt.png',
                  iconData: Icons.confirmation_number_rounded,
                  iconWidth: 38.w,
                  iconHeight: 38.w,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (!SplashService.isScreenEnabled('promoCode')) {
                      CustomStatusPopup.showComingSoon(
                        context: context,
                        title: 'Promo Code Coming Soon!',
                        message: 'Promo Code feature is currently under active development and will be available very soon.',
                      );
                      return;
                    }
                    AutoRouter.of(context).push(const PromoCodeScreenRoute());
                  },
                ),
              ],

              // 5. Giveaway
              if (!SplashService.isScreenHidden('giveaway')) ...[
                SizedBox(width: 10.w),
                _SpecialCard(
                  width: cardWidthScaled,
                  title: 'Giveaway',
                  subtitle: 'Win upto 500',
                  iconPath: 'assets/icons/trophy-cup.png',
                  iconData: Icons.card_giftcard_rounded,
                  iconWidth: 38.w,
                  iconHeight: 38.w,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (!SplashService.isScreenEnabled('giveaway')) {
                      CustomStatusPopup.showComingSoon(
                        context: context,
                        title: 'Giveaway Coming Soon!',
                        message: 'Giveaway feature is currently under active development and will be available very soon.',
                      );
                      return;
                    }
                    AutoRouter.of(context).push(
                      GiveawayScreenRoute(
                        userId: userId,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SpecialCard extends StatelessWidget {
  const _SpecialCard({
    required this.width,
    required this.title,
    required this.subtitle,
    this.iconPath,
    this.iconData,
    this.iconWidth,
    this.iconHeight,
    required this.onTap,
  });

  final double width;

  final String title;
  final String subtitle;
  final String? iconPath;
  final IconData? iconData;
  final double? iconWidth;
  final double? iconHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: onTap,
      child: Container(
        width: width,
        height: 72.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5BD),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            if (iconPath != null)
              Image.asset(
                iconPath!,
                width: iconWidth ?? 46.w,
                height: iconHeight ?? 46.w,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => iconData != null
                    ? Icon(
                        iconData,
                        color: const Color(0xFFD97706),
                        size: 32.sp,
                      )
                    : const SizedBox.shrink(),
              )
            else if (iconData != null)
              Icon(
                iconData,
                color: const Color(0xFFD97706),
                size: 32.sp,
              ),
            SizedBox(width: 6.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.15,
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subtitle,
                          maxLines: 1,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF1F2937),
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Image.asset(
                          'assets/icons/coin.png',
                          width: 11.w,
                          height: 11.w,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFBBF24),
                            size: 9,
                          ),
                        ),
                      ],
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
}

class _PopScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;

  const _PopScaleButton({
    required this.child,
    required this.onTap,
    this.scaleDown = 0.95,
  });

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
