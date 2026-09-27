import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../b_splash_stage/splash_service.dart';
import '../../../../widgets/common/custom_status_popup.dart';
import '../../../utils/routes/routes_import.gr.dart';

class DashboardNavbar extends StatelessWidget {
  const DashboardNavbar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.isLoading,
  });

  final ValueNotifier<int> currentIndex;
  final List<String> items;
  final bool isLoading;

  int _getSlotIndex(int tabIndex) {
    switch (tabIndex) {
      case 2:
        return 0; // Slot 0
      case 4:
        return 1; // Slot 1
      case 0:
        return 2; // Slot 2
      case 1:
        return 3; // Slot 3
      case 3:
        return 4; // Slot 4
      default:
        return 2;
    }
  }

  _NavItemData _getNavItemData(int slotIndex) {
    switch (slotIndex) {
      case 0:
        return const _NavItemData(
          icon: Icons.play_circle_fill_rounded,
          tabIndex: 2,
        );
      case 1:
        return const _NavItemData(
          icon: Icons.emoji_events_rounded,
          tabIndex: 4,
        );
      case 2:
        return const _NavItemData(
          icon: Icons.sports_esports_rounded,
          tabIndex: 0,
        );
      case 3:
        return const _NavItemData(
          icon: Icons.group_add_rounded,
          tabIndex: 1,
        );
      case 4:
        return const _NavItemData(
          icon: Icons.account_circle_rounded,
          tabIndex: 3,
        );
      default:
        return const _NavItemData(
          icon: Icons.home_rounded,
          tabIndex: 0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.shrink();
    }

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double navBarHeight = 52.h + bottomPadding;
    final double totalHeight = navBarHeight + 16.h;

    return ValueListenableBuilder<int>(
      valueListenable: currentIndex,
      builder: (context, selectedIndex, _) {
        final activeSlotIndex = _getSlotIndex(selectedIndex);
        final activeItem = _getNavItemData(activeSlotIndex);

        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final double slotWidth = width / 5.0;

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: activeSlotIndex.toDouble(),
                end: activeSlotIndex.toDouble(),
              ),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              builder: (context, animatedSlot, _) {
                final double cx = (animatedSlot + 0.5) * slotWidth;

                return SizedBox(
                  width: width,
                  height: totalHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 1. Dark Obsidian Scooped Curved Navigation Bar with Dynamic Sliding Notch
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: navBarHeight,
                        child: CustomPaint(
                          painter: _NotchedNavPainter(cx: cx),
                          child: ClipPath(
                            clipper: _NotchedNavClipper(cx: cx),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white,
                                    Color(0xFFF3E8FF),
                                    Color(0xFFEADBFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 2. Base Side Navigation Slots (Row of 5 items)
                      Positioned(
                        bottom: bottomPadding + 4.h,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: List.generate(5, (slotIndex) {
                            final item = _getNavItemData(slotIndex);
                            final isCurrentActive = slotIndex == activeSlotIndex;

                            return Expanded(
                              child: _NavScaleTap(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  if (slotIndex == 0) {
                                    if (!SplashService.isScreenEnabled('watchVideo')) {
                                      CustomStatusPopup.showComingSoon(context: context);
                                      return;
                                    }
                                    AutoRouter.of(context).push(
                                      WatchVideoScreenRoute(
                                        userId: '',
                                        email: '',
                                        country: 'IN',
                                      ),
                                    );
                                    return;
                                  }
                                  currentIndex.value = item.tabIndex;
                                },
                                child: Container(
                                  height: 36.h,
                                  alignment: Alignment.center,
                                  child: Opacity(
                                    opacity: isCurrentActive ? 0.0 : 1.0,
                                    child: Icon(
                                      item.icon,
                                      size: 21.sp,
                                      color: const Color(0xFF6B657D),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // 3. Sliding Elevated 3D Button with Sunken Dish & Top Purple Crescent
                      Positioned(
                        bottom: navBarHeight - 23.h,
                        left: cx - 23.w,
                        child: _ElevatedCenterButton(
                          icon: activeItem.icon,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (activeSlotIndex == 0) {
                              if (!SplashService.isScreenEnabled('watchVideo')) {
                                CustomStatusPopup.showComingSoon(context: context);
                                return;
                              }
                              AutoRouter.of(context).push(
                                WatchVideoScreenRoute(
                                  userId: '',
                                  email: '',
                                  country: 'IN',
                                ),
                              );
                              return;
                            }
                            currentIndex.value = activeItem.tabIndex;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// Elevated 3D Sliding Button with Realistic Sunken Shadow & Top Purple Crescent
class _ElevatedCenterButton extends StatelessWidget {
  const _ElevatedCenterButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NavScaleTap(
      onTap: onTap,
      child: SizedBox(
        width: 46.w,
        height: 46.w,
        child: CustomPaint(
          painter: const _Realistic3DHomeButtonPainter(),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 20.5.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Realistic3DHomeButtonPainter extends CustomPainter {
  const _Realistic3DHomeButtonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.77;

    // 1. Outer Sunken Dish with Custom Purple ambient gradient
    final outerRect = Rect.fromCircle(center: center, radius: outerRadius);
    final outerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE39FFF),
          Color(0xFFAB31DE),
        ],
      ).createShader(outerRect);

    canvas.drawCircle(center, outerRadius, outerPaint);

    // 2. Outer Dish Inner Rim Shadow (Sunken Depth)
    final outerShadowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          const Color(0xFFAB31DE).withValues(alpha: 0.20),
        ],
        stops: const [0.60, 1.0],
      ).createShader(outerRect);
    canvas.drawCircle(center, outerRadius, outerShadowPaint);

    // 3. Inner Dome Button Drop Shadow into Dish
    final innerPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(center.dx, center.dy + 1.4), radius: innerRadius));
    canvas.drawShadow(
      innerPath,
      const Color(0xFFAB31DE).withValues(alpha: 0.25),
      4.0,
      true,
    );

    // 4. Inner Convex Dome Button
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    final innerPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.45),
        radius: 0.85,
        colors: const [
          Color(0xFFE39FFF),
          Color(0xFFAB31DE),
        ],
        stops: const [0.0, 0.80],
      ).createShader(innerRect);

    canvas.drawCircle(center, innerRadius, innerPaint);

    // 5. Subtle top rim bevel highlight on inner dome
    final innerBevelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(innerRect);

    canvas.drawCircle(center, innerRadius, innerBevelPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Smooth Scooped U-Notch Geometry for any position cx
Path _buildNotchedPath(Size size, double cx) {
  final double w = size.width;
  final double h = size.height;

  final double cornerRadius = 16.0;
  final double notchWidth = 32.0; // Half width of scoop
  final double notchDepth = 18.0; // Depth of dip
  final double transitionWidth = 12.0; // Smooth curve transition

  final double notchStart = cx - notchWidth - transitionWidth;
  final double notchEnd = cx + notchWidth + transitionWidth;

  final path = Path();

  // Top-left rounded corner
  path.moveTo(0, cornerRadius);
  path.quadraticBezierTo(0, 0, cornerRadius, 0);

  // Left top flat edge
  if (notchStart > cornerRadius) {
    path.lineTo(notchStart, 0);
  }

  // Smooth entry curve into scooped dip
  path.cubicTo(
    cx - notchWidth,
    0,
    cx - notchWidth + 4.5,
    notchDepth * 0.40,
    cx - notchWidth * 0.65,
    notchDepth * 0.86,
  );

  // Bottom rounded cradle of the scoop
  path.cubicTo(
    cx - notchWidth * 0.32,
    notchDepth,
    cx + notchWidth * 0.32,
    notchDepth,
    cx + notchWidth * 0.65,
    notchDepth * 0.86,
  );

  // Smooth exit curve out of scooped dip
  path.cubicTo(
    cx + notchWidth - 4.5,
    notchDepth * 0.40,
    cx + notchWidth,
    0,
    cx + notchWidth + transitionWidth,
    0,
  );

  // Right top flat edge
  if (notchEnd < w - cornerRadius) {
    path.lineTo(w - cornerRadius, 0);
  }
  path.quadraticBezierTo(w, 0, w, cornerRadius);

  // Right vertical, bottom, and left vertical edges
  path.lineTo(w, h);
  path.lineTo(0, h);
  path.close();

  return path;
}

class _NotchedNavClipper extends CustomClipper<Path> {
  const _NotchedNavClipper({required this.cx});
  final double cx;

  @override
  Path getClip(Size size) => _buildNotchedPath(size, cx);

  @override
  bool shouldReclip(covariant _NotchedNavClipper oldClipper) =>
      oldClipper.cx != cx;
}

class _NotchedNavPainter extends CustomPainter {
  const _NotchedNavPainter({required this.cx});
  final double cx;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildNotchedPath(size, cx);

    // 1. Soft top ambient glow around the dynamic notch at cx
    final glowGradient = RadialGradient(
      center: Alignment((cx / size.width) * 2 - 1, -1.0),
      radius: 0.35,
      colors: [
        const Color(0xFF8B5CF6).withValues(alpha: 0.18),
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final glowPaint = Paint()
      ..shader = glowGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, glowPaint);

    // 2. Subtle top rim light stroke
    final strokeGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFAB31DE).withValues(alpha: 0.20),
        const Color(0xFFAB31DE).withValues(alpha: 0.10),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..shader = strokeGradient
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _NotchedNavPainter oldDelegate) =>
      oldDelegate.cx != cx;
}

class _NavItemData {
  final IconData icon;
  final int tabIndex;

  const _NavItemData({
    required this.icon,
    required this.tabIndex,
  });
}

// Micro bounce tap animation wrapper
class _NavScaleTap extends StatefulWidget {
  const _NavScaleTap({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_NavScaleTap> createState() => _NavScaleTapState();
}

class _NavScaleTapState extends State<_NavScaleTap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
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
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
