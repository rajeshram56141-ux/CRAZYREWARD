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
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Solid Clean White Base Background
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // 2. Main Content
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
                        SizedBox(width: 14.w),
                        Container(
                          width: 4.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF26262B),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'More Apps',
                          style: GoogleFonts.kaushanScript(
                            color: const Color(0xFF26262B),
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Main List
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFF26262B),
                      backgroundColor: Colors.white,
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
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 32.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 60.w,
                                        height: 60.w,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF26262B),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.sports_esports_rounded,
                                          color: Colors.white,
                                          size: 28.sp,
                                        ),
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        'No Games Available',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF1E1B4B),
                                          fontSize: 15.5.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        'Check back soon for new gaming apps & bonus offers!',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF64748B),
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
                              return _MoreAppScreenCard(
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
// DARK OBSIDIAN CARD
// -------------------------------------------------------------
class _MoreAppScreenCard extends StatefulWidget {
  const _MoreAppScreenCard({
    required this.app,
    required this.userId,
  });

  final MoreAppsModel app;
  final String userId;

  @override
  State<_MoreAppScreenCard> createState() => _MoreAppScreenCardState();
}

class _MoreAppScreenCardState extends State<_MoreAppScreenCard> {
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
          height: 66.h,
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/Icons1/Rectangle 13.png'),
              fit: BoxFit.fill,
            ),
            borderRadius: BorderRadius.circular(36.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: Circular Logo
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.8,
                  ),
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
                            widget.app.appName.isNotEmpty ? widget.app.appName : 'Recommended Game',
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
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              'AD',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
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
                          : 'Play and earn rewards instantly',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF9E9EA7),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // Right: Action Button
              if (widget.app.coins > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100.r),
                    border: Border.all(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.5),
                      width: 1,
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
                        '+${widget.app.coins}',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFD54F),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    final btnGradient = _getColorfulButtonGradient(widget.app.appName);
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: btnGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: btnGradient.first.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Play',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Icon(
                            Icons.arrow_outward_rounded,
                            color: Colors.white,
                            size: 13.sp,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getColorfulButtonGradient(String name) {
    final List<List<Color>> palettes = [
      // 0: Neon Emerald & Sky Blue
      [const Color(0xFF00E676), const Color(0xFF00B0FF)],
      // 1: Electric Violet & Neon Cyan
      [const Color(0xFF7C4DFF), const Color(0xFF00E5FF)],
      // 2: Sunset Orange & Warm Yellow
      [const Color(0xFFFF6D00), const Color(0xFFFFC400)],
      // 3: Cyber Magenta & Deep Purple
      [const Color(0xFFE040FB), const Color(0xFF7C4DFF)],
      // 4: Vivid Crimson & Coral Rose
      [const Color(0xFFFF1744), const Color(0xFFFF4081)],
      // 5: Radiant Gold & Amber
      [const Color(0xFFFFAB00), const Color(0xFFFF6D00)],
      // 6: Deep Electric Cyan & Emerald
      [const Color(0xFF00E5FF), const Color(0xFF00E676)],
    ];
    final hash = name.hashCode.abs();
    return palettes[hash % palettes.length];
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: Colors.white.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: Colors.white,
          size: 22.sp,
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
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return ShimmerTag(
          baseColor: const Color(0xFFF8FAFC),
          highlightColor: const Color(0xFFF1F5F9),
          child: Container(
            height: 66.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(36.r),
            ),
          ),
        );
      },
    );
  }
}
