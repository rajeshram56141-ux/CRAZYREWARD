import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../../widgets/ads/topon_native_ad_card.dart';
import '../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../../widgets/common/shimmer_tag.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import '../daily_task/daily_task_model.dart';
import 'provider/watch_video_provider.dart';
import 'widgets/no_daily_task.dart';
import 'widgets/watch_video_full_video_widget.dart';

@RoutePage()
class WatchVideoScreen extends HookConsumerWidget {
  const WatchVideoScreen({
    super.key,
    required this.email,
    required this.userId,
    required this.country,
  });

  final String userId;
  final String email;
  final String country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPadding = MediaQuery.of(context).padding.top;

    final provider = watchVideoProvider((
      countryCode: country,
      email: email,
      userId: userId,
    ));

    useEffect(() {
      Future.microtask(() {
        if (userId.trim().isNotEmpty) {
          ref.invalidate(provider);
        }
      });
      return () {
        if (userId.trim().isNotEmpty) {
          ref.invalidate(DashboardService.userDataProvider(userId));
        }
      };
    }, const []);

    final watchVideoAsync = ref.watch(provider);
    final selectedCategory = useState<String>('All');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Solid Clean White Base Background
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // 2. Main Scrollable Body
            Positioned.fill(
              child: watchVideoAsync.when(
                data: (List<DailyTaskModel> offers) {
                  if (offers.isEmpty) {
                    return RefreshIndicator(
                      color: const Color(0xFFAB31DE),
                      backgroundColor: Colors.white,
                      edgeOffset: topPadding + 60.h,
                      onRefresh: () async {
                        ref.invalidate(provider);
                        await ref.read(provider.future).catchError((_) => <DailyTaskModel>[]);
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildHeader(context, topPadding),
                            const ScreenBannerWidget(
                              screenKey: 'watchVideoScreen',
                              margin: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                            ),
                            SizedBox(height: 40.h),
                            const NoDailyTask(isVideo: true),
                          ],
                        ),
                      ),
                    );
                  }

                  // Extract unique categories
                  final rawCategories = offers
                      .map((e) => e.offerCategory.trim())
                      .where((c) => c.isNotEmpty)
                      .toSet()
                      .toList();
                  final categories = ['All', ...rawCategories];

                  final filteredOffers = selectedCategory.value == 'All'
                      ? offers
                      : offers
                          .where((offer) =>
                              offer.offerCategory.trim().toLowerCase() ==
                              selectedCategory.value.trim().toLowerCase())
                          .toList();

                  return RefreshIndicator(
                    color: const Color(0xFFAB31DE),
                    backgroundColor: Colors.white,
                    edgeOffset: topPadding + 60.h,
                    onRefresh: () async {
                      ref.invalidate(provider);
                      await ref.read(provider.future).catchError((_) => <DailyTaskModel>[]);
                    },
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          controller: scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Container(
                              color: Colors.transparent,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. Top Header Bar
                                  _buildHeader(context, topPadding),

                                  // Screen Banner (Admin Configurable 700x200 with AD badge)
                                  const ScreenBannerWidget(
                                    screenKey: 'watchVideoScreen',
                                    margin: EdgeInsets.only(left: 16, right: 16, bottom: 12),
                                  ),

                                  SizedBox(height: 6.h),

                                  // 2. Sub-Category Filter Chips Row
                                  if (categories.length > 1)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 16.h),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                                        physics: const BouncingScrollPhysics(),
                                        child: Row(
                                          children: [
                                            for (int i = 0; i < categories.length; i++) ...[
                                              if (i > 0) SizedBox(width: 8.w),
                                              _FilterChip(
                                                label: categories[i],
                                                isSelected: selectedCategory.value == categories[i],
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  selectedCategory.value = categories[i];
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),

                                  // 3. Video Feed Cards List
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                                    child: filteredOffers.isEmpty
                                        ? Padding(
                                            padding: EdgeInsets.symmetric(vertical: 40.h),
                                            child: const NoDailyTask(isVideo: true),
                                          )
                                        : ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            padding: EdgeInsets.only(bottom: 32.h),
                                            itemCount: filteredOffers.length,
                                            separatorBuilder: (_, __) => SizedBox(height: 12.h),
                                            itemBuilder: (context, index) {
                                              final item = filteredOffers[index];
                                              final card = WatchVideoFullVideoWidget(
                                                item: item,
                                                email: email,
                                                userId: userId,
                                                countryCode: country,
                                                ref: ref,
                                                isVerticalList: true,
                                                enableHero: true,
                                              );

                                              if (index == 1) {
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    card,
                                                    ToponNativeAdCard(
                                                      isEnabled: AdKeys.isWatchVideoNativeEnabled,
                                                      margin: EdgeInsets.only(top: 12.h),
                                                    ),
                                                  ],
                                                );
                                              }

                                              return card;
                                            },
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                error: (_, __) => const NoDailyTask(isVideo: true),
                loading: () => const _WatchVideoListShimmer(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double topPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.w,
        topPadding + 8.h,
        16.w,
        14.h,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Back Button + Title
          Row(
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
              SizedBox(width: 12.w),
              Text(
                'Watch Video',
                style: GoogleFonts.kaushanScript(
                  color: const Color(0xFF26262B),
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          // Right: "How To?" Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              LaunchUrl.inWeb(
                url: SplashService.getTutorialUrl(
                  'watchEarn',
                  SplashService.urlConfig.watchEarnTutorial,
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
                    size: 15.sp,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'How To?',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26262B),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SUB-CATEGORY FILTER CHIP (MATCHING HOME SCREEN DESIGN SYSTEM)
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
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF26262B) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF26262B)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12.5.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SHIMMER SKELETON FOR WATCH VIDEO FEED
// ---------------------------------------------------------------------------
class _WatchVideoListShimmer extends StatelessWidget {
  const _WatchVideoListShimmer();

  static const Color _shimmerBase = Color(0xFFF8FAFC);
  static const Color _shimmerHighlight = Color(0xFFF1F5F9);

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double borderRadius = 12.0,
  }) {
    return ShimmerTag(
      type: ShimmerType.pulse,
      baseColor: _shimmerBase,
      highlightColor: _shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, topPadding + 8.h, 16.w, 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Bar Shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildSkeletonBox(width: 40.w, height: 40.w, borderRadius: 15.r),
                  SizedBox(width: 12.w),
                  _buildSkeletonBox(width: 130.w, height: 22.h, borderRadius: 6.r),
                ],
              ),
              _buildSkeletonBox(width: 80.w, height: 36.h, borderRadius: 14.r),
            ],
          ),

          SizedBox(height: 16.h),

          // 2. Filter Chips Shimmer
          Row(
            children: [
              _buildSkeletonBox(width: 50.w, height: 36.h, borderRadius: 12.r),
              SizedBox(width: 8.w),
              _buildSkeletonBox(width: 75.w, height: 36.h, borderRadius: 12.r),
              SizedBox(width: 8.w),
              _buildSkeletonBox(width: 80.w, height: 36.h, borderRadius: 12.r),
            ],
          ),

          SizedBox(height: 18.h),

          // 3. List Shimmer
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: 4,
            separatorBuilder: (_, __) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22.r),
                  border: Border.all(
                    color: const Color(0xFFF1F5F9),
                    width: 1.2,
                  ),
                ),
                padding: EdgeInsets.all(10.r),
                child: Row(
                  children: [
                    _buildSkeletonBox(width: 116.w, height: 78.h, borderRadius: 16.r),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSkeletonBox(width: 120.w, height: 16.h, borderRadius: 6.r),
                          SizedBox(height: 6.h),
                          _buildSkeletonBox(width: 150.w, height: 12.h, borderRadius: 4.r),
                          SizedBox(height: 12.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSkeletonBox(width: 50.w, height: 22.h, borderRadius: 12.r),
                              _buildSkeletonBox(width: 65.w, height: 26.h, borderRadius: 14.r),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
