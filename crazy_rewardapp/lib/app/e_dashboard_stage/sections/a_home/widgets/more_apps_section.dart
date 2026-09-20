import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../more_apps/more_apps_model.dart';
import '../more_apps/more_apps_provider.dart';

class MoreAppsSection extends HookConsumerWidget {
  const MoreAppsSection({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (SplashService.isScreenHidden('moreApps')) {
      return const SizedBox.shrink();
    }

    final streamApps = ref.watch(moreAppsStreamProvider).value;
    final staticApps = ref.watch(moreAppsProvider);
    final apps = (streamApps != null && streamApps.isNotEmpty)
        ? streamApps
        : staticApps;

    // Rule: Visible only if apps are added, else hidden
    if (apps.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool hasMoreThanThree = apps.length > 3;
    final displayApps = hasMoreThanThree ? apps.take(3).toList() : apps;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // List of More App Cards (Exact matching screenshot design)
          ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayApps.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final app = displayApps[index];
              return _MoreAppHomeCard(
                app: app,
                userId: userId,
              );
            },
          ),

          // Bottom Centered "View All" Button (matching Daily Task View All button)
          if (hasMoreThanThree) ...[
            SizedBox(height: 14.h),
            Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  AutoRouter.of(context).push(
                    MoreAppsScreenRoute(userId: userId),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(100.r),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      // Top-Left Light Highlight Shadow
                      const BoxShadow(
                        color: Colors.white,
                        blurRadius: 8,
                        offset: Offset(-3.5, -3.5),
                      ),
                      // Bottom-Right Warm Amber Gold Shadow
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(3.5, 3.5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 3 Horizontally Overlapping Round Circular App Icons
                      SizedBox(
                        width: 52.w,
                        height: 22.h,
                        child: Stack(
                          children: List.generate(
                            apps.length > 3 ? 3 : apps.length,
                            (index) {
                              final app = apps[index];
                              return Positioned(
                                left: index * 14.w,
                                child: Container(
                                  width: 22.w,
                                  height: 22.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: app.appLogo.isNotEmpty
                                        ? (app.appLogo.startsWith('http')
                                            ? Image.network(
                                                app.appLogo,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _buildFallbackCircleIcon(index),
                                              )
                                            : Image.asset(
                                                app.appLogo,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _buildFallbackCircleIcon(index),
                                              ))
                                        : _buildFallbackCircleIcon(index),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'View All',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFD97706),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const _AnimatedArrowIcon(color: Color(0xFFD97706)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackCircleIcon(int index) {
    final icons = [
      Icons.sports_esports_rounded,
      Icons.extension_rounded,
      Icons.rocket_launch_rounded,
    ];
    final colors = [
      const Color(0xFF7C3AED),
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
    ];
    return Container(
      color: colors[index % colors.length].withValues(alpha: 0.15),
      child: Icon(
        icons[index % icons.length],
        color: colors[index % colors.length],
        size: 12.sp,
      ),
    );
  }
}

class _MoreAppHomeCard extends StatefulWidget {
  const _MoreAppHomeCard({
    required this.app,
    required this.userId,
  });

  final MoreAppsModel app;
  final String userId;

  @override
  State<_MoreAppHomeCard> createState() => _MoreAppHomeCardState();
}

class _MoreAppHomeCardState extends State<_MoreAppHomeCard> {
  bool _isPressed = false;

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.app.redirectionUrl.isNotEmpty) {
      final rawUrl = widget.app.redirectionUrl;
      final finalUrl = rawUrl.replaceAll('{user_id}', widget.userId).replaceAll('{userId}', widget.userId);
      LaunchUrl.inWeb(url: finalUrl, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _handleTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOutBack,
        child: Container(
          height: 68.h,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFF7640FE).withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7640FE).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: Rounded App Icon
              SizedBox(
                width: 44.w,
                height: 44.w,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Image.network(
                    widget.app.appLogo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFEADBFF),
                      child: Icon(
                        Icons.sports_esports_rounded,
                        color: const Color(0xFF7C3AED),
                        size: 24.sp,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              // Center: App Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.app.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        if (widget.app.isAd) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.r),
                              border: Border.all(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'AD',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF7C3AED),
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.app.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF475569),
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              // Right: Visit Button (Vibrant Purple Gradient Pill with White Text & Arrow)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE39FFF),
                      Color(0xFFAB31DE),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(100.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Visit',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Icon(
                      Icons.arrow_outward_rounded,
                      color: Colors.white,
                      size: 12.5.sp,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedArrowIcon extends StatefulWidget {
  final Color color;
  const _AnimatedArrowIcon({this.color = Colors.white});

  @override
  State<_AnimatedArrowIcon> createState() => _AnimatedArrowIconState();
}

class _AnimatedArrowIconState extends State<_AnimatedArrowIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _offsetAnimation = Tween<double>(begin: 0.0, end: 4.w).animate(
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
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.only(left: 4.w),
        child: Icon(
          Icons.arrow_forward_ios_rounded,
          color: widget.color,
          size: 10.5.sp,
        ),
      ),
    );
  }
}
