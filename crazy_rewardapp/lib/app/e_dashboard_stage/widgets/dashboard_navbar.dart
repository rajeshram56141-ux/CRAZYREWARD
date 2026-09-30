import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../utils/routes/routes_import.gr.dart';

class DashboardNavbar extends StatelessWidget {
  const DashboardNavbar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.isLoading,
    this.userId = '',
    this.country = 'IN',
    this.isGuest = false,
  });

  final ValueNotifier<int> currentIndex;
  final List<String> items;
  final bool isLoading;
  final String userId;
  final String country;
  final bool isGuest;

  int _getSlotIndex(int tabIndex) {
    switch (tabIndex) {
      case 4:
        return 0; // Slot 0: Leaderboard (Far Left Corner)
      case 1:
        return 1; // Slot 1: Invite & Earn (Left Side)
      case 0:
        return 2; // Slot 2: Home (Center)
      case 3:
        return 4; // Slot 4: Profile (Far Right Corner)
      case 2:
        return 0; // Watch Video fallback to slot 0
      default:
        return 2;
    }
  }

  _NavItemData _getNavItemData(int slotIndex) {
    switch (slotIndex) {
      case 0:
        return const _NavItemData(
          icon: Icons.emoji_events_rounded,
          label: 'Rank',
          tabIndex: 4,
        );
      case 1:
        return const _NavItemData(
          icon: Icons.group_add_rounded,
          label: 'Invite',
          tabIndex: 1,
        );
      case 2:
        return const _NavItemData(
          icon: Icons.home_rounded,
          label: 'Home',
          tabIndex: 0,
        );
      case 3:
        return const _NavItemData(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Wallet',
          tabIndex: -1,
        );
      case 4:
        return const _NavItemData(
          icon: Icons.account_circle_rounded,
          label: 'Profile',
          tabIndex: 3,
        );
      default:
        return const _NavItemData(
          icon: Icons.home_rounded,
          label: 'Home',
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
    final double navBarHeight = 56.h;
    final double totalHeight = navBarHeight + 24.h + (bottomPadding > 0 ? bottomPadding - 4.h : 0);

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

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding > 0 ? bottomPadding : 10.h,
                    left: 12.w,
                    right: 12.w,
                  ),
                  child: SizedBox(
                    width: width - 24.w,
                    height: totalHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        // 1. Floating Dark Obsidian Scooped Curved Navigation Bar
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: navBarHeight,
                          child: CustomPaint(
                            painter: _NotchedNavPainter(cx: cx - 12.w),
                            child: ClipPath(
                              clipper: _NotchedNavClipper(cx: cx - 12.w),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF26262F),
                                      Color(0xFF18181F),
                                      Color(0xFF111116),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 2. Base Navigation Slots (Row of 5 items)
                        Positioned(
                          bottom: 10.h,
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
                                    if (slotIndex == 3) {
                                      AutoRouter.of(context).push(
                                        RedeemScreenRoute(
                                          userId: userId,
                                          country: country,
                                          isGuest: isGuest,
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
                                        size: 22.sp,
                                        color: Colors.white.withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        // 3. Sliding Elevated Yellow-Orange Circular Button with Label
                        Positioned(
                          bottom: navBarHeight - 26.h,
                          left: (cx - 12.w) - 27.w,
                          child: _ElevatedCenterButton(
                            icon: activeItem.icon,
                            label: activeItem.label,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (activeSlotIndex == 3) {
                                AutoRouter.of(context).push(
                                  RedeemScreenRoute(
                                    userId: userId,
                                    country: country,
                                    isGuest: isGuest,
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

// Elevated Yellow/Orange Glowing Button matching reference screenshot 1-to-1
class _ElevatedCenterButton extends StatelessWidget {
  const _ElevatedCenterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NavScaleTap(
      onTap: onTap,
      child: Container(
        width: 54.w,
        height: 54.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFD000),
              Color(0xFFFF9D00),
              Color(0xFFFF7A00),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9D00).withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 21.sp,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Smooth Scooped U-Notch Geometry matching reference screenshot
Path _buildNotchedPath(Size size, double cx) {
  final double w = size.width;
  final double h = size.height;

  final double cornerRadius = 28.0; // Rounded pill ends
  final double notchWidth = 33.0; // Half width of scoop
  final double notchDepth = 22.0; // Depth of dip
  final double transitionWidth = 14.0; // Smooth curve transition

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
    cx - notchWidth + 5.0,
    notchDepth * 0.42,
    cx - notchWidth * 0.65,
    notchDepth * 0.88,
  );

  // Bottom rounded cradle of the scoop
  path.cubicTo(
    cx - notchWidth * 0.32,
    notchDepth,
    cx + notchWidth * 0.32,
    notchDepth,
    cx + notchWidth * 0.65,
    notchDepth * 0.88,
  );

  // Smooth exit curve out of scooped dip
  path.cubicTo(
    cx + notchWidth - 5.0,
    notchDepth * 0.42,
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

  // Bottom right corner & bottom left corner
  path.lineTo(w, h - cornerRadius);
  path.quadraticBezierTo(w, h, w - cornerRadius, h);
  path.lineTo(cornerRadius, h);
  path.quadraticBezierTo(0, h, 0, h - cornerRadius);
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

    // 1. Soft top ambient glow around the dynamic notch
    final glowGradient = RadialGradient(
      center: Alignment((cx / size.width) * 2 - 1, -1.0),
      radius: 0.35,
      colors: [
        const Color(0xFFFF9D00).withValues(alpha: 0.20),
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final glowPaint = Paint()
      ..shader = glowGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, glowPaint);

    // 2. Subtle top rim light stroke
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
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
  final String label;
  final int tabIndex;

  const _NavItemData({
    required this.icon,
    required this.label,
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
