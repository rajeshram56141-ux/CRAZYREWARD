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
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Solid Executive White Background
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // Main Content
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
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            AutoRouter.of(context).maybePop();
                          },
                          borderRadius: BorderRadius.circular(14.r),
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
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'Giveaways',
                            style: GoogleFonts.kaushanScript(
                              color: const Color(0xFF26262B),
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Right: "How To?" Button
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
                              vertical: 7.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.help_outline_rounded,
                                  color: const Color(0xFF26262B),
                                  size: 14.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'How To?',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF26262B),
                                    fontSize: 11.5.sp,
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

                  SizedBox(height: 14.h),

                  // Full-Width Category Filter Tabs Row
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Container(
                      height: 46.h,
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
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
                          SizedBox(width: 6.w),
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
                              color: const Color(0xFF94A3B8),
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
      color: const Color(0xFF26262B),
      backgroundColor: Colors.white,
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
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDeclaredTab
                                  ? Icons.emoji_events_outlined
                                  : Icons.card_giftcard_outlined,
                              color: const Color(0xFF26262B),
                              size: 38.sp,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              emptyMsg,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF26262B),
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
                                color: const Color(0xFF64748B),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                        color: const Color(0xFFF1F5F9),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.card_giftcard_rounded,
                          color: const Color(0xFF26262B),
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
                        color: isDeclared
                            ? const Color(0xFFD97706)
                            : (isLive ? const Color(0xFFDC2626) : const Color(0xFF26262E)),
                        borderRadius: BorderRadius.circular(6.r),
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
                              fontSize: 9.sp,
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
                          borderRadius: BorderRadius.circular(6.r),
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
                                fontSize: 8.5.sp,
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
                        color: const Color(0xFF26262B),
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
                            color: const Color(0xFF26262B),
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
                        color: const Color(0xFFF1F5F9),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            color: isDeclared
                                ? const Color(0xFFD97706)
                                : const Color(0xFF26262B),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // Silver Metallic Action Button
                    Container(
                      width: double.infinity,
                      height: 32.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFFE5E7EB),
                            Color(0xFFB0B5C2),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: const Color(0xFF9CA3AF),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isDeclared
                            ? 'View Winners'
                            : (joined ? 'View Status' : 'Enter Giveaway'),
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF16161A),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
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
// FILTER CHIP
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
        height: 38.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF26262E) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
