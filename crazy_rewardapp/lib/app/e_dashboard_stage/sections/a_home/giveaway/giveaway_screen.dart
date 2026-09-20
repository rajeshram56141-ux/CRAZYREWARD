import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../widgets/common/custom_loading.dart';
import '../../../../b_splash_stage/splash_service.dart';
import 'model/giveaway_model.dart';
import 'provider/giveaway_provider.dart';

// Tapered 3D Button Custom Painter
class _TaperedButtonPainter extends CustomPainter {
  final double radius;
  final bool isAmber;

  const _TaperedButtonPainter({
    this.radius = 12.0,
    this.isAmber = false,
  });

  Path getButtonPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius;

    final path = Path();
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w - 2, r * 0.7);
    path.lineTo(w - 5, h - r * 0.7);
    path.quadraticBezierTo(w - 6, h, w - 6 - r, h);
    path.lineTo(6 + r, h);
    path.quadraticBezierTo(6, h, 5, h - r * 0.7);
    path.lineTo(2, r * 0.7);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = getButtonPath(size);

    // Drop shadow
    canvas.drawShadow(
      path,
      (isAmber ? const Color(0xFFB45309) : const Color(0xFF24007A)).withValues(alpha: 0.65),
      6.0,
      true,
    );

    // Fill glossy gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = (isAmber
          ? const LinearGradient(
              colors: [
                Color(0xFFFEF3C7),
                Color(0xFFFBBF24),
                Color(0xFFD97706),
                Color(0xFFB45309),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.30, 0.75, 1.0],
            )
          : const LinearGradient(
              colors: [
                Color(0xFFEADBFF),
                Color(0xFFA565FF),
                Color(0xFF6B15F6),
                Color(0xFF550BD0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.30, 0.75, 1.0],
            )).createShader(rect);

    canvas.drawPath(path, fillPaint);

    // Top rim highlight stroke
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.60),
          Colors.white.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45, 0.9],
      ).createShader(rect);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

@RoutePage()
class GiveawayScreen extends HookConsumerWidget {
  const GiveawayScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      Future.microtask(() {
        ref.invalidate(GiveawayProviders.giveawaysProvider);
      });
      return null;
    }, const []);

    final selectedIndex = useState<int>(0);
    final pageController = usePageController(initialPage: 0);
    final giveawaysAsync = ref.watch(GiveawayProviders.giveawaysProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF090314),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 8.h),

                  // Top Header Bar: Back Button + "Giveaways" + How To Use
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
                        Expanded(
                          child: Text(
                            'Giveaways',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        // Right: "How To Use?" Button (Matching Play Games)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            LaunchUrl.inWeb(
                              url: SplashService.getTutorialUrl(
                                'giveaway',
                                SplashService.urlConfig.giveawayTutorial,
                              ),
                              context: context,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF181528),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.help_outline_rounded,
                                  color: const Color(0xFFDDD6FE),
                                  size: 15.sp,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  'How To?',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFDDD6FE),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 12.h),

                  // Full-Width Category Filter Tabs Row
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FilterChip(
                            label: 'Live Giveaway',
                            isSelected: selectedIndex.value == 0,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              selectedIndex.value = 0;
                              pageController.animateToPage(
                                0,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: _FilterChip(
                            label: 'Completed',
                            isSelected: selectedIndex.value == 1,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              selectedIndex.value = 1;
                              pageController.animateToPage(
                                1,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 14.h),

                  // Main Giveaway Grid Pages
                  Expanded(
                    child: giveawaysAsync.when(
                      loading: () => const Center(
                        child: GlowLightingSpinner(size: 28),
                      ),
                      error: (_, __) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              color: const Color(0xFFA78BFA),
                              size: 42.sp,
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'error-subtitle'.tr(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF94A3B8),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      data: (_) {
                        final ongoingAndUpcoming = [
                          ...ref.watch(GiveawayProviders.filteredGiveawaysProvider(GiveawayStatus.upcoming)),
                          ...ref.watch(GiveawayProviders.filteredGiveawaysProvider(GiveawayStatus.ongoing)),
                        ];

                        final declared = ref.watch(GiveawayProviders.filteredGiveawaysProvider(GiveawayStatus.declared));

                        return PageView(
                          controller: pageController,
                          onPageChanged: (index) {
                            selectedIndex.value = index;
                          },
                          children: [
                            _buildGiveawayGrid(
                              context: context,
                              ref: ref,
                              list: ongoingAndUpcoming,
                              emptyMsg: 'No live giveaways at this moment',
                              isDeclaredTab: false,
                            ),
                            _buildGiveawayGrid(
                              context: context,
                              ref: ref,
                              list: declared,
                              emptyMsg: 'No completed giveaways yet',
                              isDeclaredTab: true,
                            ),
                          ],
                        );
                      },
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

  Widget _buildGiveawayGrid({
    required BuildContext context,
    required WidgetRef ref,
    required List<GiveawayModel> list,
    required String emptyMsg,
    required bool isDeclaredTab,
  }) {
    return RefreshIndicator(
      color: const Color(0xFFA78BFA),
      backgroundColor: const Color(0xFF1E1B2C),
      onRefresh: () async {
        HapticFeedback.lightImpact();
        ref.invalidate(GiveawayProviders.giveawaysProvider);
        try {
          await ref.read(GiveawayProviders.giveawaysProvider.future);
        } catch (_) {}
      },
      child: list.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32.w),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 28.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDeclaredTab
                                  ? Icons.emoji_events_outlined
                                  : Icons.card_giftcard_outlined,
                              color: const Color(0xFFA78BFA),
                              size: 38.sp,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              emptyMsg,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              isDeclaredTab
                                  ? 'Past giveaway winners will appear here once announced.'
                                  : 'Check back soon for new giveaways and grand reward events!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11.5.sp,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : GridView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 20.h),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 0.68,
              ),
              itemCount: list.length,
              itemBuilder: (_, index) {
                final giveaway = list[index];
                return _GiveawayCard(
                  userId: userId,
                  giveaway: giveaway,
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------
// Modern Giveaway Card Component
// ---------------------------------------------------------
class _GiveawayCard extends HookConsumerWidget {
  const _GiveawayCard({
    required this.giveaway,
    required this.userId,
  });

  final GiveawayModel giveaway;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPressed = useState(false);
    final joined = ref.watch(
      GiveawayProviders.joinedProvider((userId, giveaway.id)),
    );

    final serverTime = ref.watch(GiveawayProviders.tickingServerTimeProvider).value;
    if (serverTime == null) return const SizedBox.shrink();

    final status = giveaway.getStatus(serverTime);
    final progress = giveaway.totalSlots > 0
        ? (giveaway.joinedCount / giveaway.totalSlots).clamp(0.0, 1.0)
        : 0.0;

    final isLive = status == GiveawayStatus.ongoing;
    final isDeclared = status == GiveawayStatus.declared;

    return GestureDetector(
      onTapDown: (_) {
        isPressed.value = true;
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        isPressed.value = false;
        AutoRouter.of(context).push(
          GiveawayDetailScreenRoute(
            giveaway: giveaway,
            userId: userId,
          ),
        );
      },
      onTapCancel: () => isPressed.value = false,
      child: AnimatedScale(
        scale: isPressed.value ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF180E2E), // Exact solid dark container (no outline)
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Banner Image with Status Badge
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.55,
                    child: Image.network(
                      giveaway.bannerUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2E1952), Color(0xFF140B28)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          color: const Color(0xFFA78BFA),
                          size: 28.sp,
                        ),
                      ),
                    ),
                  ),

                  // Top Status Pill
                  Positioned(
                    top: 6.h,
                    left: 6.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDeclared
                              ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                              : (isLive
                                  ? [const Color(0xFFE11D48), const Color(0xFFBE123C)]
                                  : [const Color(0xFF7C3AED), const Color(0xFF6D28D9)]),
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLive) ...[
                            Container(
                              width: 5.w,
                              height: 5.w,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                          ],
                          Text(
                            isDeclared
                                ? 'RESULTS'
                                : (isLive ? 'LIVE' : 'UPCOMING'),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Joined Badge (Top-Right)
                  if (joined)
                    Positioned(
                      top: 6.h,
                      right: 6.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              'JOINED',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Card Body Content
              Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      giveaway.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(height: 6.h),

                    // Slots Info Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              color: const Color(0xFF94A3B8),
                              size: 11.sp,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Slots:',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF94A3B8),
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${giveaway.joinedCount} / ${giveaway.totalSlots}',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFC4B5FD),
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 5.h),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: Container(
                        height: 4.h,
                        width: double.infinity,
                        color: Colors.white.withValues(alpha: 0.08),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDeclared
                                    ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
                                    : [const Color(0xFF8B5CF6), const Color(0xFFC084FC)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // 3D Tapered Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 32.h,
                      child: CustomPaint(
                        painter: _TaperedButtonPainter(
                          radius: 10,
                          isAmber: isDeclared,
                        ),
                        child: Center(
                          child: Text(
                            isDeclared
                                ? 'View Winners'
                                : (joined ? 'View Status' : 'Enter Giveaway'),
                            style: GoogleFonts.poppins(
                              color: isDeclared ? const Color(0xFF78350F) : Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// FILTER CHIP (MATCHING DAILY TASK SCREEN)
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        height: 42.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEADBFF), // Top Milk-Lavender Gloss
                    Color(0xFFA565FF), // Mid Rich Violet
                    Color(0xFF6B15F6), // Vibrant Electric Violet
                    Color(0xFF550BD0), // Deep Bottom Violet Base
                  ],
                  stops: [0.0, 0.30, 0.75, 1.0],
                )
              : null,
          color: isSelected ? null : const Color(0xFF1E1B2C),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6B15F6).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13.5.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

