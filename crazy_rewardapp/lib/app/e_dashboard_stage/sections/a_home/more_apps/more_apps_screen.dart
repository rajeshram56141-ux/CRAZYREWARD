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
        systemNavigationBarColor: Color(0xFF070312),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF090414),
        body: Stack(
          children: [
            // 1. Deep Cyberpunk Gaming Obsidian Multi-Stop Gradient Base
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF090414), // Deep Cyber Void
                      Color(0xFF140827), // Midnight Purple
                      Color(0xFF1E0B3B), // Royal Gaming Violet
                      Color(0xFF0D031A), // Dark Cyber Base
                    ],
                    stops: [0.0, 0.35, 0.70, 1.0],
                  ),
                ),
              ),
            ),

            // 2. Top-Right Electric Neon Violet / Indigo Laser Glow
            Positioned(
              top: -80.h,
              right: -60.w,
              child: Container(
                width: 320.w,
                height: 320.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.40),
                      const Color(0xFF6366F1).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 3. Center-Left Hot Cyber Pink / Neon Magenta Pulsing Glow
            Positioned(
              top: 220.h,
              left: -90.w,
              child: Container(
                width: 290.w,
                height: 290.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF007A).withValues(alpha: 0.26),
                      const Color(0xFF7928CA).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 4. Bottom-Right Cyber Cyan / Electric Sky Glow
            Positioned(
              bottom: -60.h,
              right: -50.w,
              child: Container(
                width: 270.w,
                height: 270.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00F0FF).withValues(alpha: 0.22),
                      const Color(0xFF0070F3).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // 5. Main Content
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8.h),

                  // Header: Gaming Back Button + Kaushan Title (Simple & Clean)
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
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F0FF).withValues(alpha: 0.20),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Container(
                          width: 4.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F0FF),
                            borderRadius: BorderRadius.circular(2.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F0FF).withValues(alpha: 0.7),
                                blurRadius: 6,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'More Apps',
                          style: GoogleFonts.kaushanScript(
                            color: Colors.white,
                            fontSize: 24.sp,
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
                      color: const Color(0xFF00F0FF),
                      backgroundColor: const Color(0xFF140827),
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
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(24.r),
                                    border: Border.all(
                                      color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.40),
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
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF00F0FF),
                                              Color(0xFF7000FF),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
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
                                          color: Colors.white,
                                          fontSize: 15.5.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Text(
                                        'Check back soon for new gaming apps & bonus offers!',
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
// CYBERPUNK GAMING GLOW OBSIDIAN PILL CARD
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B0E33),
                Color(0xFF140A28),
                Color(0xFF0F061F),
              ],
            ),
            borderRadius: BorderRadius.circular(36.r),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left: Circular Logo with Cyber Neon Ring
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF261642),
                  border: Border.all(
                    color: const Color(0xFF00F0FF),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.40),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
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

              // Middle: Title & Subtitle (Home Screen Typography)
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
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF007A),
                                  Color(0xFF7928CA),
                                ],
                              ),
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
                        color: const Color(0xFF94A3B8),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // Right: Action Button (Cyber Gold Gradient for Coins / Cyan for Visit)
              if (widget.app.coins > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFF8C00),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(100.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8C00).withValues(alpha: 0.40),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${widget.app.coins}',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF1E1000),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        Icons.stars_rounded,
                        color: const Color(0xFF1E1000),
                        size: 13.sp,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00F0FF),
                        Color(0xFF8B5CF6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(100.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F0FF).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: const Color(0xFF261642),
      child: Center(
        child: Icon(
          Icons.sports_esports_rounded,
          color: const Color(0xFF00F0FF),
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
          baseColor: const Color(0xFF1B0E33),
          highlightColor: const Color(0xFF2C1B58),
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
