import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/helper/helper.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../widgets/common/custom_loading.dart';
import '../../../../../widgets/common/internet_image.dart';
import '../../../../../widgets/common/shimmer_tag.dart';
import '../daily_task/daily_task_model.dart';
import '../../../../b_splash_stage/splash_service.dart';

class HomeDailyTaskSection extends HookConsumerWidget {
  const HomeDailyTaskSection({
    super.key,
    required this.offers,
    required this.userId,
    required this.email,
    required this.country,
  });

  final List<DailyTaskModel> offers;
  final String userId;
  final String email;
  final String country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingId = useState<String?>(null);
    final isPaused = useState<bool>(false);
    final previewTasks = offers.take(5).toList(); // Max 5 cards

    if (previewTasks.isEmpty) {
      return const SizedBox();
    }

    const initialPage = 1000;
    final pageController = usePageController(
      viewportFraction: 0.88,
      initialPage: initialPage,
      keys: const ['hot_offers_carousel_v7'],
    );

    final pageValue = useState<double>(initialPage.toDouble());
    final activeIndex = useState<int>(initialPage % previewTasks.length);

    useEffect(() {
      void listener() {
        if (pageController.hasClients) {
          pageValue.value = pageController.page ?? initialPage.toDouble();
          final pageIndex = (pageController.page!.round()) % previewTasks.length;
          if (activeIndex.value != pageIndex) {
            activeIndex.value = pageIndex;
          }
        }
      }
      pageController.addListener(listener);
      return () => pageController.removeListener(listener);
    }, [pageController, previewTasks.length]);

    // Auto-scroll loop
    useEffect(() {
      final timer = Timer.periodic(const Duration(milliseconds: 4500), (timer) {
        if (!isPaused.value && pageController.hasClients) {
          final nextPage = (pageController.page?.round() ?? initialPage) + 1;
          pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
          );
        }
      });
      return timer.cancel;
    }, [previewTasks, isPaused.value]);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row (Purple Flame Icon + "Hot Offers" on Left, "View All" on Right)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  SplashService.dailyTaskTitle.isNotEmpty ? SplashService.dailyTaskTitle : 'Daily Task',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 16.5.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AutoRouter.of(context).push(
                      DailyTaskScreenRoute(
                        userId: userId,
                        email: email,
                        country: country,
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.5.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFE39FFF),
                          Color(0xFFAB31DE),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 10.5.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),

          // 2. 3D Wide Banner Carousel
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                isPaused.value = true;
              } else if (notification is ScrollEndNotification) {
                Future.delayed(const Duration(milliseconds: 3000), () {
                  isPaused.value = false;
                });
              }
              return false;
            },
            child: SizedBox(
              height: 122.h,
              child: PageView.builder(
                controller: pageController,
                clipBehavior: Clip.none,
                itemCount: 10000,
                itemBuilder: (context, index) {
                  final item = previewTasks[index % previewTasks.length];
                  final heroTag = 'task_card_home_${item.offerId}_$index';

                  final diff = index - pageValue.value;
                  final distance = diff.abs();
                  final double scale = (1.0 - (distance * 0.08)).clamp(0.92, 1.0);

                  return Transform.scale(
                    scale: scale,
                    child: _HomeDailyTaskItemCard(
                      item: item,
                      isLoading: loadingId.value == item.offerId,
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        isPaused.value = true;
                        await AutoRouter.of(context).push(
                          DailyTaskDetailsScreenRoute(
                            item: item,
                            cardColor: item.color,
                            userId: userId,
                            email: email,
                            country: country,
                            heroTag: heroTag,
                          ),
                        );
                        isPaused.value = false;
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // 3. Bottom Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(previewTasks.length, (index) {
              final isSelected = index == activeIndex.value;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                height: 6.h,
                width: 6.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFF7640FE)
                      : const Color(0xFF262A34),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _GlowLightingSpinner extends StatefulWidget {
  final double size;
  final List<Color> colors;

  const _GlowLightingSpinner({
    this.size = 15.0,
    required this.colors,
  });

  @override
  State<_GlowLightingSpinner> createState() => _GlowLightingSpinnerState();
}

class _GlowLightingSpinnerState extends State<_GlowLightingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
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
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size.w,
            height: widget.size.w,
            child: CustomPaint(
              painter: _GlowSpinnerPainter(colors: widget.colors),
            ),
          ),
        );
      },
    );
  }
}

class _GlowSpinnerPainter extends CustomPainter {
  final List<Color> colors;

  _GlowSpinnerPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4.0) / 2;
    const startAngle = 0.0;
    const sweepAngle = 4.4;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = colors.last.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, trackPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      colors: [
        colors.last.withValues(alpha: 0.0),
        colors.length > 1 ? colors[1].withValues(alpha: 0.4) : colors.last.withValues(alpha: 0.4),
        colors.length > 2 ? colors[2] : colors.last,
        colors.last,
      ],
      stops: const [0.0, 0.35, 0.75, 1.0],
    );

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = 2.6
      ..shader = gradient.createShader(rect);

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

    final headAngle = startAngle + sweepAngle;
    final headPoint = Offset(
      center.dx + radius * math.cos(headAngle),
      center.dy + radius * math.sin(headAngle),
    );

    final outerGlowPaint = Paint()
      ..color = colors.last.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(headPoint, 4.2, outerGlowPaint);

    final innerGlowPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(headPoint, 2.6, innerGlowPaint);

    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(headPoint, 1.8, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TicketPatternPainter extends CustomPainter {
  const _TicketPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF22C55E).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Origin exactly at the right boundary of the green side (touching the center split)
    final origin = Offset(size.width, size.height * 0.05);

    // Primary waves fanning out from the right divider edge all the way to the left side
    for (int i = 0; i < 15; i++) {
      final path = Path();
      path.moveTo(origin.dx, origin.dy);

      final controlX = size.width * (0.1 + i * 0.06);
      final controlY = size.height * (0.95 - i * 0.05);
      final endX = size.width * (0.0 - i * 0.03);
      final endY = size.height * (0.2 + i * 0.06);

      path.quadraticBezierTo(controlX, controlY, endX, endY);
      canvas.drawPath(path, paint);
    }

    // Secondary waves flowing from left edge (0) and ending exactly on the right divider edge (size.width)
    for (int i = 0; i < 8; i++) {
      final path = Path();
      path.moveTo(0, size.height * (0.3 + i * 0.08));

      final controlX1 = size.width * 0.3;
      final controlY1 = size.height * (0.1 - i * 0.03);
      final controlX2 = size.width * 0.7;
      final controlY2 = size.height * (0.95 - i * 0.04);
      final endX = size.width; // Touches the center split exactly
      final endY = size.height * (0.25 + i * 0.06);

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, endX, endY);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HotSpecialOfferCard extends StatelessWidget {
  const _HotSpecialOfferCard({
    required this.item,
    required this.onTap,
    this.isLoading = false,
    this.heroTag,
  });

  final DailyTaskModel item;
  final VoidCallback onTap;
  final bool isLoading;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imagePath.isNotEmpty ? item.imagePath : item.bannerPath;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B4B),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: const Color(0xFF9333EA).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9333EA).withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Row(
            children: [
              // Left Section (Purple Gradient)
              Expanded(
                flex: 12,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF7E10C8),
                        Color(0xFF3B0764),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: const _TicketPatternPainter(),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Category Tag Row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: const Color(0xFFF472B6),
                                  size: 13.sp,
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  item.offerCategory.isNotEmpty
                                      ? item.offerCategory.toUpperCase()
                                      : 'TASK',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFF472B6),
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            // Title
                            Text(
                              item.offerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            // Subtext
                            Text(
                              item.cleanSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 8.5.sp,
                                height: 1.15,
                              ),
                            ),
                            // Button
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF472B6), Color(0xFFDB2777)],
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFDB2777).withValues(alpha: 0.35),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Start',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Image.asset(
                                          'assets/icons/coin.png',
                                          height: 14.sp,
                                          width: 14.sp,
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          item.coins.formatCoins(),
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w800,
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
              ),
              // Right Section
              Expanded(
                flex: 8,
                child: Container(
                  color: const Color(0xFF1E1B4B),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 55.w,
                        height: 55.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF9333EA).withValues(alpha: 0.25),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: InternetImage(
                          url: imageUrl,
                          fit: BoxFit.cover,
                          width: 50.w,
                          height: 50.w,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmeringHotOfferText extends StatefulWidget {
  const _ShimmeringHotOfferText();

  @override
  State<_ShimmeringHotOfferText> createState() => _ShimmeringHotOfferTextState();
}

class _ShimmeringHotOfferTextState extends State<_ShimmeringHotOfferText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
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
        final double value = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment(value * 3.6 - 1.8, 0),
              end: Alignment(value * 3.6 - 0.6, 0),
              colors: const [
                Color(0xFF9333EA),
                Color(0xFFC084FC),
                Color(0xFFF472B6),
                Color(0xFFC084FC),
                Color(0xFF9333EA),
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            'Special Offers',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}

class DailyTaskHorizontalCard extends StatelessWidget {
  const DailyTaskHorizontalCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isLoading = false,
    this.heroTag,
  });

  final DailyTaskModel item;
  final VoidCallback onTap;
  final bool isLoading;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final isHighPaying = item.coins >= 300;
    final tagGradient = isHighPaying
        ? const LinearGradient(
            colors: [Color(0xFFFFF1C5), Color(0xFFFFD54F)], // Light Gold
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFF81C784)], // Soft Mint/Green
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
    final tagText = isHighPaying ? 'High Reward' : 'New Offer';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 135.h,
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Custom Painted Ticket background
            LayoutBuilder(
              builder: (context, constraints) {
                final clipX = constraints.maxWidth - 82.w;
                final ticketRadius = 10.r;
                final rrectRadius = 16.r;
                return SizedBox(
                  width: constraints.maxWidth,
                  height: 120.h,
                  child: Stack(
                    children: [
                      // 1. Ticket background and shadow
                      CustomPaint(
                        size: Size(constraints.maxWidth, 120.h),
                        painter: TicketPainter(
                          clipX: clipX,
                          radius: ticketRadius,
                        ),
                      ),
                      // 2. Subtle Rotating Sunburst Rays (Clipped to ticket shape)
                      Positioned.fill(
                        child: ClipPath(
                          clipper: TicketClipper(
                            clipX: clipX,
                            radius: ticketRadius,
                            rrectRadius: rrectRadius,
                          ),
                          child: RotatingSunburst(
                            rayColor: const Color(0xFFD3A32D).withValues(alpha: 0.1), // Subtle gold rays
                          ),
                        ),
                      ),
                      // 3. Foreground content
                      SizedBox(
                        width: constraints.maxWidth,
                        height: 120.h,
                        child: Row(
                          children: [
                            // Left Section: Main Ticket Body
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 14.w,
                                  right: 12.w,
                                  top: 12.h,
                                  bottom: 12.h,
                                ),
                                child: Row(
                                  children: [
                                    // Logo
                                    Container(
                                      width: 52.w,
                                      height: 52.w,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14.r),
                                        child: InternetImage(
                                          url: item.imagePath,
                                          width: 52.w,
                                          height: 52.w,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    // Text details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item.offerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: const Color(0xFF1E1C24),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13.sp,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            item.cleanSubtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: const Color(0xFF6B6675),
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (item.trackingTime > 0) ...[
                                            SizedBox(height: 4.h),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time_filled_rounded,
                                                  size: 10.sp,
                                                  color: const Color(0xFFFF5252),
                                                ),
                                                SizedBox(width: 3.w),
                                                Text(
                                                  '${item.trackingTime} mins',
                                                  style: TextStyle(
                                                    color: const Color(0xFFFF5252),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 9.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Right Section: Ticket Stub (Coin reward pill)
                            Container(
                              width: 92.w,
                              alignment: Alignment.center,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 5.w),
                                child: Container(
                                  width: 82.w,
                                  height: 35.h,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF9C487), // Lighter gold/brown
                                        Color(0xFFD68A2E), // Base Leaderboard brown
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(16.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD68A2E).withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isLoading
                                      ? const Center(
                                          child: GlowLightingSpinner(size: 14),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/icons/coin.png',
                                              height: 15.sp,
                                              width: 15.sp,
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              item.coins.formatCoins(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12.sp,
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
                    ],
                  ),
                );
              },
            ),
            // Floating Status Badge on top left
            Positioned(
              top: 2.h,
              left: 12.w,
              child: FlippingTag(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    gradient: tagGradient,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: (isHighPaying
                                ? const Color(0xFFFF8F00)
                                : const Color(0xFF81C784))
                            .withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHighPaying
                            ? Icons.local_fire_department_rounded
                            : Icons.star_rounded,
                        color: isHighPaying
                            ? const Color(0xFF7B5B00)
                            : const Color(0xFF2E7D32),
                        size: 9.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        tagText,
                        style: TextStyle(
                          color: isHighPaying
                              ? const Color(0xFF7B5B00)
                              : const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w900,
                          fontSize: 8.sp,
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

class DailyTaskGridCard extends StatelessWidget {
  const DailyTaskGridCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isLoading = false,
    this.heroTag,
  });

  final DailyTaskModel item;
  final VoidCallback onTap;
  final bool isLoading;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final isHighPaying = item.coins >= 300;
    final tagGradient = isHighPaying
        ? const LinearGradient(
            colors: [Color(0xFFFFF1C5), Color(0xFFFFD54F)], // Light Gold
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFECEC), Color(0xFFFF8A8A)], // Soft Pink/Coral
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFDFD), // Cream White
              Color(0xFFFFF3F0), // Soft Peach
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7A59).withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Stack(
            children: [
              // Ambient glow spots peaking from behind in grid style
              Positioned(
                right: -25.w,
                bottom: -25.h,
                child: Container(
                  width: 70.w,
                  height: 70.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF8A65).withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -25.w,
                top: -25.h,
                child: Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFD54F).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Card contents layout
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Logo & Status Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Logo inside soft-shadow card (no border)
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: InternetImage(
                            url: item.imagePath,
                            width: 40.w,
                            height: 40.w,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      
                      // Status Tag (New / High)
                      FlippingTag(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            gradient: tagGradient,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isHighPaying ? Icons.local_fire_department_rounded : Icons.star_rounded,
                                color: isHighPaying ? const Color(0xFF7B5B00) : const Color(0xFFC62828),
                                size: 9.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                isHighPaying ? 'High' : 'New',
                                style: TextStyle(
                                  color: isHighPaying ? const Color(0xFF7B5B00) : const Color(0xFFC62828),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Middle Section: Task texts
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.offerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1E1C24), // High-contrast charcoal text
                          fontWeight: FontWeight.w900,
                          fontSize: 12.sp,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        item.cleanSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF6B6675), // Readable grey-brown text
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  // Bottom Section: Centered Premium Coin button (No Install category tag)
                  ShimmerTag(
                    type: ShimmerType.shining,
                    blendMode: BlendMode.srcATop,
                    baseColor: Colors.transparent,
                    highlightColor: Colors.white.withValues(alpha: 0.45),
                    child: Container(
                      width: double.infinity,
                      height: 33.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFC107), // Glossy Amber Gold
                            Color(0xFFFF8F00),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8F00).withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isLoading
                          ? const Center(
                              child: GlowLightingSpinner(size: 14),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/icons/coin.png',
                                  height: 15.sp,
                                  width: 15.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  item.coins.formatCoins(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
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
}


class TicketPainter extends CustomPainter {
  final double clipX;
  final double radius;

  TicketPainter({
    required this.clipX,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrectRadius = 16.r;

    final paint = Paint()
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = const LinearGradient(
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFFFFDF5),
        Color(0xFFFFF9E6),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);

    final borderPaint = Paint()
      ..color = const Color(0xFFD3A32D).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path()
      ..moveTo(0, rrectRadius)
      // Top-left rounded corner
      ..quadraticBezierTo(0, 0, rrectRadius, 0)
      // Top line to cutout
      ..lineTo(clipX - radius, 0)
      // Top cutout (concave semi-circle going inwards)
      ..arcToPoint(
        Offset(clipX + radius, 0),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      // Top line to top-right corner
      ..lineTo(size.width - rrectRadius, 0)
      // Top-right corner
      ..quadraticBezierTo(size.width, 0, size.width, rrectRadius)
      // Right line to bottom-right corner
      ..lineTo(size.width, size.height - rrectRadius)
      // Bottom-right corner
      ..quadraticBezierTo(size.width, size.height, size.width - rrectRadius, size.height)
      // Bottom line to bottom cutout
      ..lineTo(clipX + radius, size.height)
      // Bottom cutout (concave semi-circle going inwards)
      ..arcToPoint(
        Offset(clipX - radius, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      // Bottom line to bottom-left corner
      ..lineTo(rrectRadius, size.height)
      // Bottom-left corner
      ..quadraticBezierTo(0, size.height, 0, size.height - rrectRadius)
      ..close();

    // Draw shadow
    canvas.drawShadow(
      path,
      const Color(0xFFD68A2E).withValues(alpha: 0.12),
      4.0,
      true,
    );

    // Draw ticket background
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Draw dashed vertical divider
    final dashPaint = Paint()
      ..color = const Color(0xFFD3A32D).withValues(alpha: 0.25) // Soft Watch gold divider
      ..strokeWidth = 1.2.w
      ..style = PaintingStyle.stroke;

    double startY = radius + 6.h;
    final endY = size.height - radius - 6.h;
    final dashHeight = 4.h;
    final dashSpace = 4.h;

    while (startY < endY) {
      canvas.drawLine(
        Offset(clipX, startY),
        Offset(clipX, startY + dashHeight),
        dashPaint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant TicketPainter oldDelegate) {
    return oldDelegate.clipX != clipX || oldDelegate.radius != radius;
  }
}

class FlippingTag extends StatefulWidget {
  final Widget child;
  const FlippingTag({super.key, required this.child});

  @override
  State<FlippingTag> createState() => _FlippingTagState();
}

class _FlippingTagState extends State<FlippingTag> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4 seconds total cycle
    )..repeat();
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
        // Spin a full 360 degrees (2 * pi) in the last 0.8 seconds (20% of 4-sec duration)
        final double value = _controller.value;
        double angle = 0.0;
        if (value > 0.8) {
          final double t = (value - 0.8) / 0.2; // normalize to 0.0 -> 1.0
          final double curveT = Curves.easeInOutCubic.transform(t);
          angle = curveT * 2 * math.pi;
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002) // 3D Perspective
            ..rotateY(angle),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  final double clipX;
  final double radius;
  final double rrectRadius;

  TicketClipper({
    required this.clipX,
    required this.radius,
    required this.rrectRadius,
  });

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, rrectRadius)
      ..quadraticBezierTo(0, 0, rrectRadius, 0)
      ..lineTo(clipX - radius, 0)
      ..arcToPoint(
        Offset(clipX + radius, 0),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(size.width - rrectRadius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, rrectRadius)
      ..lineTo(size.width, size.height - rrectRadius)
      ..quadraticBezierTo(size.width, size.height, size.width - rrectRadius, size.height)
      ..lineTo(clipX + radius, size.height)
      ..arcToPoint(
        Offset(clipX - radius, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(rrectRadius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - rrectRadius)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketClipper oldClipper) {
    return oldClipper.clipX != clipX || oldClipper.radius != radius || oldClipper.rrectRadius != rrectRadius;
  }
}

class SunburstPainter extends CustomPainter {
  final double rotationAngle;
  final Color rayColor;

  SunburstPainter({
    required this.rotationAngle,
    required this.rayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.sqrt(size.width * size.width + size.height * size.height);
    
    final paint = Paint()
      ..color = rayColor
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    const int numRays = 16;
    final double angleStep = 2 * math.pi / numRays;
    final double halfRayWidth = angleStep / 4; // ray occupies 50% of its step sector

    for (int i = 0; i < numRays; i++) {
      final double rayAngle = i * angleStep;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(radius * math.cos(rayAngle - halfRayWidth), radius * math.sin(rayAngle - halfRayWidth))
        ..lineTo(radius * math.cos(rayAngle + halfRayWidth), radius * math.sin(rayAngle + halfRayWidth))
        ..close();
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SunburstPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle || oldDelegate.rayColor != rayColor;
  }
}

class RotatingSunburst extends StatefulWidget {
  final Color rayColor;
  const RotatingSunburst({
    super.key,
    required this.rayColor,
  });

  @override
  State<RotatingSunburst> createState() => _RotatingSunburstState();
}

class _RotatingSunburstState extends State<RotatingSunburst> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // slow, premium rotation
    )..repeat();
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
        return CustomPaint(
          size: Size.infinite,
          painter: SunburstPainter(
            rotationAngle: _controller.value * 2 * math.pi,
            rayColor: widget.rayColor,
          ),
        );
      },
    );
  }
}

class ArcadeCardClipper extends CustomClipper<Path> {
  const ArcadeCardClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final double r = 16.0; // corner radius
    final double arcR = 10.0; // bottom center arc height
    final double arcW = 38.0; // bottom center arc width

    // Start top-left
    path.moveTo(0, r);
    // Left corner rounds to y=10
    path.quadraticBezierTo(0, 10, 10, 10);
    // Smooth notch curving up to y=0
    path.cubicTo(16, 10, 18, 0, 26, 0);
    // Top tab line
    path.lineTo(size.width - 26, 0);
    // Smooth notch curving down to y=10
    path.cubicTo(size.width - 18, 0, size.width - 16, 10, size.width - 10, 10);
    // Right corner rounds down to y=r
    path.quadraticBezierTo(size.width, 10, size.width, r);

    // Right edge
    path.lineTo(size.width, size.height - r);
    path.quadraticBezierTo(size.width, size.height, size.width - r, size.height);

    // Bottom edge with a flat-topped smooth arch cut-out in the middle
    final double centerX = size.width / 2;
    path.lineTo(centerX + arcW / 2, size.height);
    
    // Smooth cubic bezier arch cutout
    path.cubicTo(
      centerX + arcW / 3,
      size.height - arcR,
      centerX - arcW / 3,
      size.height - arcR,
      centerX - arcW / 2,
      size.height,
    );

    path.lineTo(r, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - r);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class ArcadeCardBorderPainter extends CustomPainter {
  const ArcadeCardBorderPainter({required this.borderColor});
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final double r = 16.0;
    final double arcR = 10.0;
    final double arcW = 38.0;

    path.moveTo(0, r);
    // Left corner rounds to y=10
    path.quadraticBezierTo(0, 10, 10, 10);
    // Smooth notch curving up to y=0
    path.cubicTo(16, 10, 18, 0, 26, 0);
    // Top tab line
    path.lineTo(size.width - 26, 0);
    // Smooth notch curving down to y=10
    path.cubicTo(size.width - 18, 0, size.width - 16, 10, size.width - 10, 10);
    // Right corner rounds down to y=r
    path.quadraticBezierTo(size.width, 10, size.width, r);

    // Right edge
    path.lineTo(size.width, size.height - r);
    path.quadraticBezierTo(size.width, size.height, size.width - r, size.height);

    // Bottom edge with a flat-topped smooth arch cut-out in the middle
    final double centerX = size.width / 2;
    path.lineTo(centerX + arcW / 2, size.height);
    path.cubicTo(
      centerX + arcW / 3,
      size.height - arcR,
      centerX - arcW / 3,
      size.height - arcR,
      centerX - arcW / 2,
      size.height,
    );

    path.lineTo(r, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - r);
    path.close();

    // Draw glowing border paint that fades from top to bottom
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          borderColor,
          borderColor.withValues(alpha: 0.6),
          borderColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.70],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TaperedCardPainter extends CustomPainter {
  const _TaperedCardPainter({
    this.taper = 14.0,
    this.radius = 38.0,
  });

  final double taper;
  final double radius;

  Path getCardPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final r = radius;
    final t = taper;

    // Top-left start
    path.moveTo(r, 0);
    // Top edge with subtle convex arch
    path.quadraticBezierTo(w / 2, -1.5, w - r, 0);
    // Top-right rounded corner
    path.quadraticBezierTo(w, 0, w, r);
    // Right side gently tapering down to (w - t, h - r)
    path.cubicTo(
      w - (t * 0.15), h * 0.40,
      w - (t * 0.75), h * 0.78,
      w - t, h - r,
    );
    // Bottom-right rounded corner (deep curve)
    path.quadraticBezierTo(w - t, h, w - t - r, h);
    // Bottom edge with smooth convex bowl curve matching screenshot
    path.quadraticBezierTo(w / 2, h + 6.0, t + r, h);
    // Bottom-left rounded corner (deep curve)
    path.quadraticBezierTo(t, h, t, h - r);
    // Left side gently tapering up to (0, r)
    path.cubicTo(
      t * 0.75, h * 0.78,
      t * 0.15, h * 0.40,
      0, r,
    );
    // Top-left rounded corner
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = getCardPath(size);

    // Draw shadow first
    canvas.drawShadow(
      path,
      const Color(0xFF7640FE).withValues(alpha: 0.08),
      6.0,
      true,
    );

    // Draw solid white background
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    canvas.drawPath(path, paint);

    // Draw subtle purple border stroke
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF7640FE).withValues(alpha: 0.15);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeDailyTaskItemCard extends StatelessWidget {
  const _HomeDailyTaskItemCard({
    required this.item,
    required this.onTap,
    this.isLoading = false,
  });

  final DailyTaskModel item;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imagePath.trim().isNotEmpty
        ? item.imagePath.trim()
        : (item.bannerPath.trim().isNotEmpty ? item.bannerPath.trim() : '');

    return _PopScaleButton(
      onTap: onTap,
      scaleDown: 0.95,
      child: Container(
        height: 120.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: Colors.white,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: Stack(
            children: [
              // 1. Solid Pure White Base
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                ),
              ),

              // 2. Right-Side Background Art Layer
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 140.w,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(22.r),
                    bottomRight: Radius.circular(22.r),
                  ),
                  child: Image.asset(
                    'assets/icons/daily task blur.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // 3. Glassmorphism Light Glass Backdrop Layer (Lighter Blur)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.72),
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0.15),
                          ],
                          stops: const [0.0, 0.50, 1.0],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.90),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Main Content Row (Logo + Text Info)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Row(
                  children: [
                    // Left Column: Crisp Square Logo Thumbnail with Soft Elevation
                    Container(
                      width: 72.w,
                      height: 72.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.r),
                        child: imageUrl.isNotEmpty
                            ? InternetImage(
                                url: imageUrl,
                                fit: BoxFit.cover,
                                width: 72.w,
                                height: 72.w,
                              )
                            : Container(
                                color: const Color(0xFFAB31DE),
                                child: Icon(
                                  Icons.sports_esports_rounded,
                                  color: Colors.white,
                                  size: 36.sp,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(width: 12.w),

                    // Middle Column: Title, Subtitle & Category Tag (Below Subtitle)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 60.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Title
                            Text(
                              item.offerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF0F172A),
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),

                            SizedBox(height: 2.h),

                            // Subtitle
                            Text(
                              item.cleanSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF64748B),
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w400,
                                height: 1.15,
                              ),
                            ),

                            SizedBox(height: 6.h),

                            // Category Badge Tag (Low Opacity Flat Color, No Gradient, No Outline)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    color: const Color(0xFFAB31DE),
                                    size: 9.5.sp,
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    item.offerCategory.isNotEmpty
                                        ? item.offerCategory.toUpperCase()
                                        : 'HOT',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFAB31DE),
                                      fontSize: 7.5.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Coin Action Button (Shifted slightly left)
              Positioned(
                right: 30.w,
                bottom: 12.h,
                child: _PopScaleButton(
                  onTap: onTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(11.r),
                      border: Border.all(
                        color: const Color(0xFFE39FFF).withValues(alpha: 0.70),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFAB31DE)),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/icons/coin.png',
                                width: 14.w,
                                height: 14.w,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '+${item.coins}',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFAB31DE),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.arrow_downward_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 12.sp,
                              ),
                            ],
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
}



class _PopScaleButton extends StatefulWidget {
  const _PopScaleButton({
    required this.onTap,
    required this.child,
    this.scaleDown = 0.92,
  });

  final VoidCallback onTap;
  final Widget child;
  final double scaleDown;

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOutBack,
        child: widget.child,
      ),
    );
  }
}

