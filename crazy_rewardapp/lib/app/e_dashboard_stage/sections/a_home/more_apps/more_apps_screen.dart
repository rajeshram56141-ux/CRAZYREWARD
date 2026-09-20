import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../widgets/common/shimmer_tag.dart';
import '../../../../b_splash_stage/splash_service.dart';
import 'more_apps_model.dart';
import 'more_apps_provider.dart';

@RoutePage()
class MoreAppsScreen extends HookConsumerWidget {
  const MoreAppsScreen({super.key, this.userId = ''});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final appsAsync = ref.watch(moreAppsStreamProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Full Background Image (Matching Home Screen)
            Positioned.fill(
              child: Image.asset(
                'assets/icons/bgg.png',
                fit: BoxFit.cover,
              ),
            ),

            // 2. Deep Ambient Frosted Glass Blur Overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
            ),

            // 3. Main Content
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8.h),

                  // Header: Back Button + Title
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            AutoRouter.of(context).maybePop();
                          },
                          child: Image.asset(
                            'assets/icons/backk.png',
                            width: 42.w,
                            height: 42.w,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Text(
                          'More Apps',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Main List
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFFC084FC),
                      backgroundColor: const Color(0xFF180E2E),
                      onRefresh: () async {
                        ref.invalidate(SplashService.appDataProvider);
                        ref.invalidate(moreAppsStreamProvider);
                        await ref.read(moreAppsStreamProvider.future).catchError((_) => <MoreAppsModel>[]);
                      },
                      child: Builder(
                        builder: (context) {
                          final streamApps = appsAsync.value;
                          final staticApps = ref.watch(moreAppsProvider);
                          final apps = (streamApps != null && streamApps.isNotEmpty)
                              ? streamApps
                              : staticApps;

                          if (apps.isEmpty && appsAsync.isLoading) {
                            return const _MoreAppsShimmer();
                          }

                          if (apps.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32.w),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 54.w,
                                        height: 54.w,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6B15F6).withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.apps_rounded,
                                          color: const Color(0xFFC084FC),
                                          size: 26.sp,
                                        ),
                                      ),
                                      SizedBox(height: 14.h),
                                      Text(
                                        'No Apps Available',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        'Check back soon for new recommended apps and games!',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            controller: scrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              4.h,
                              16.w,
                              MediaQuery.of(context).padding.bottom + 24.h,
                            ),
                            itemCount: apps.length,
                            separatorBuilder: (_, __) => SizedBox(height: 12.h),
                            itemBuilder: (context, index) {
                              final app = apps[index];
                              return _MoreAppCard(
                                app: app,
                                userId: userId,
                              );
                            },
                          );
                        },
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
}

// -------------------------------------------------------------
// PREMIUM FROSTED GRADIENT CARD
// -------------------------------------------------------------
class _MoreAppCard extends StatefulWidget {
  const _MoreAppCard({
    required this.app,
    required this.userId,
  });

  final MoreAppsModel app;
  final String userId;

  @override
  State<_MoreAppCard> createState() => _MoreAppCardState();
}

class _MoreAppCardState extends State<_MoreAppCard> {
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
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          height: 70.h,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            color: Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            gradient: const LinearGradient(
              colors: [
                Color(0x148B5CF6),
                Color(0x2E6D28D9),
                Color(0x66581C87),
                Color(0xB34C1D95),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.35, 0.70, 1.0],
            ),
          ),
          child: Row(
            children: [
              // Left: Rounded App Logo
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13.r),
                  child: Image.network(
                    widget.app.appLogo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF382366),
                      child: Icon(
                        Icons.sports_esports_rounded,
                        color: const Color(0xFFC084FC),
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
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4.r),
                              border: Border.all(
                                color: const Color(0xFFC084FC).withValues(alpha: 0.7),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'AD',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE9D5FF),
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
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              // Right: Visit Button (White Pill with Purple Text & Arrow)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.5.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.app.coins > 0 ? '+${widget.app.coins}' : 'Visit',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6B15F6),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Icon(
                      widget.app.coins > 0 ? Icons.stars_rounded : Icons.arrow_outward_rounded,
                      color: const Color(0xFF6B15F6),
                      size: 13.sp,
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

// -------------------------------------------------------------
// SHIMMER LOADING PLACEHOLDER
// -------------------------------------------------------------
class _MoreAppsShimmer extends StatelessWidget {
  const _MoreAppsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      itemCount: 5,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return ShimmerTag(
          baseColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.14),
          child: Container(
            height: 70.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
            ),
          ),
        );
      },
    );
  }
}
