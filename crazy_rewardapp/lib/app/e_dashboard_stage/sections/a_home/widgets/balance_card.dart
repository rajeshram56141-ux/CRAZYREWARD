import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../utils/helper/helper.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../utils/theme/theme.dart';
import '../../../../b_splash_stage/splash_service.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.coins,
    this.gems = 0,
    required this.userId,
    required this.country,
    required this.isGuest,
  });

  final double coins;
  final int gems;
  final String userId;
  final String country;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final String yourBalanceText = 'your-balance'.tr();
    final String titleText = yourBalanceText == 'your-balance' ? 'Your Balance' : yourBalanceText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0xCCFFFFFF),
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.20, 0.45],
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            // 1. RIGHT SIDE SOFT DOME GRADIENT PATTI (With Top Fade Blend)
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

            // 2. RIGHT SIDE BIG PANDA MASCOT ARTWORK
            Positioned(
              right: 4.w,
              top: 6.h,
              bottom: 6.h,
              width: 115.w,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => AutoRouter.of(context).push(
                  RedeemScreenRoute(userId: userId, country: country, isGuest: isGuest),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/panda 4.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // 3. LEFT SIDE VERTICAL COIN & GEM BALANCES COLUMN
            Padding(
              padding: EdgeInsets.only(left: 14.w, top: 12.h, bottom: 12.h, right: 116.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- TOP: COINS BALANCE ROW ---
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => AutoRouter.of(context).push(
                      RedeemScreenRoute(userId: userId, country: country, isGuest: isGuest),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44.w,
                          height: 44.w,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 38.w,
                                height: 38.w,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFAF5FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/icons/coin.png',
                                    width: 24.w,
                                    height: 24.w,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _CircularArcPainter(
                                    color: const Color(0xFFAB31DE),
                                    strokeWidth: 3.w,
                                    startAngle: -1.2,
                                    sweepAngle: 2.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                titleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w400,
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(height: 1.h),
                              RouletteBalanceText(
                                coins: coins,
                                formatAsK: false,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFAB31DE),
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  height: 1.1,
                                ),
                              ),
                              if (SplashService.showCoinConversionRate && SplashService.coinConversionRate > 0) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  '≈ ₹${(coins / SplashService.coinConversionRate).toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF059669),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: const Color(0xFFAB31DE),
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Divider(
                      color: const Color(0xFFF1F5F9),
                      thickness: 1.2,
                      height: 1.2,
                    ),
                  ),

                  // --- BOTTOM: GEMS BALANCE ROW ---
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => AutoRouter.of(context).push(
                      SuperOfferScreenRoute(userId: userId),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44.w,
                          height: 44.w,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 38.w,
                                height: 38.w,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF0F9FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/icons/gems.png',
                                    width: 22.w,
                                    height: 22.w,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _CircularArcPainter(
                                    color: const Color(0xFF0284C7),
                                    strokeWidth: 3.w,
                                    startAngle: -1.2,
                                    sweepAngle: 2.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Gems',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w400,
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                '$gems',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF0284C7),
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: const Color(0xFF0284C7),
                          size: 18.sp,
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

class _CircularArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double startAngle;
  final double sweepAngle;

  _CircularArcPainter({
    required this.color,
    required this.strokeWidth,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant _CircularArcPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.sweepAngle != sweepAngle;
  }
}

class RouletteBalanceText extends StatefulWidget {
  const RouletteBalanceText({
    super.key,
    required this.coins,
    required this.style,
    this.formatAsK = true,
  });

  final double coins;
  final TextStyle style;
  final bool formatAsK;

  @override
  State<RouletteBalanceText> createState() => _RouletteBalanceTextState();
}

class _RouletteBalanceTextState extends State<RouletteBalanceText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _valueAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  double _oldCoins = 0.0;
  double _currentDisplayCoins = 0.0;

  @override
  void initState() {
    super.initState();
    _oldCoins = widget.coins;
    _currentDisplayCoins = widget.coins;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _valueAnimation = Tween<double>(begin: _oldCoins, end: widget.coins).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuint),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.18)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.18, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
    ]).animate(_controller);

    _colorAnimation = ColorTween(
      begin: widget.style.color ?? AppTheme.primaryColor,
      end: const Color(0xFFE5A93B), // Premium gold/roulette color
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    _controller.addListener(() {
      setState(() {
        _currentDisplayCoins = _valueAnimation.value;
      });
    });
  }

  @override
  void didUpdateWidget(covariant RouletteBalanceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coins != oldWidget.coins) {
      _oldCoins = oldWidget.coins;
      
      if (widget.coins > _oldCoins) {
        // Run roulette animation ONLY when balance increases
        _valueAnimation = Tween<double>(
          begin: _oldCoins,
          end: widget.coins,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutQuint),
        );

        _controller.forward(from: 0.0);
      } else {
        // For decreases or initial load, update immediately without animation
        setState(() {
          _currentDisplayCoins = widget.coins;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        Color? textColor = widget.style.color ?? AppTheme.primaryColor;
        if (_controller.isAnimating) {
          if (_controller.value > 0.7) {
            final double t = (_controller.value - 0.7) / 0.3; // 0.0 to 1.0
            textColor = Color.lerp(
              const Color(0xFFE5A93B),
              widget.style.color ?? AppTheme.primaryColor,
              t,
            );
          } else {
            textColor = _colorAnimation.value;
          }
        }

        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.centerLeft,
          child: Text(
            widget.formatAsK
                ? _currentDisplayCoins.formatK()
                : _currentDisplayCoins.formatBalance(),
            style: widget.style.copyWith(
              color: textColor,
              shadows: _controller.isAnimating
                  ? [
                      Shadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                        blurRadius: 12,
                        offset: const Offset(0, 0),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}
