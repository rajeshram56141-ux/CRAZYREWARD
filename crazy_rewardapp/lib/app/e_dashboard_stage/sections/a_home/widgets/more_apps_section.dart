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

    if (apps.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayApps = apps.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Section Header: "More Apps"
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
                'More Apps',
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

        // 2. List: 2 Apps + Centered Small View More Button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: [
              for (int i = 0; i < displayApps.length; i++) ...[
                if (i > 0) SizedBox(height: 10.h),
                _MoreAppHomeCard(
                  app: displayApps[i],
                  userId: userId,
                ),
              ],
              if (apps.length > 2 || displayApps.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Center(
                  child: _SmallViewMoreButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      AutoRouter.of(context).push(
                        MoreAppsScreenRoute(userId: userId),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallViewMoreButton extends StatefulWidget {
  const _SmallViewMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SmallViewMoreButton> createState() => _SmallViewMoreButtonState();
}

class _SmallViewMoreButtonState extends State<_SmallViewMoreButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOutBack,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                color: const Color(0xFFC084FC),
                size: 13.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                'View More',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white70,
                size: 13.sp,
              ),
            ],
          ),
        ),
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
          height: 64.h,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFF161618),
            borderRadius: BorderRadius.circular(36.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: Circular Logo with White Ring
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E293B),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.app.appLogo.isNotEmpty
                      ? (widget.app.appLogo.startsWith('http')
                          ? Image.network(
                              widget.app.appLogo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                            )
                          : Image.asset(
                              widget.app.appLogo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                            ))
                      : _buildFallbackLogo(),
                ),
              ),

              SizedBox(width: 12.w),

              // Middle: Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.app.appName.isNotEmpty ? widget.app.appName : 'AyetStudios',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        if (widget.app.isAd) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'AD',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 7.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.app.subtitle.isNotEmpty
                          ? widget.app.subtitle
                          : 'Finish premium offers and earn coins',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // Right: Dark Circular Button with White Arrow
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 16.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Icon(
          Icons.apps_rounded,
          color: Colors.white70,
          size: 22.sp,
        ),
      ),
    );
  }
}
