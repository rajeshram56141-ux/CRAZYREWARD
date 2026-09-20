import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../widgets/common/shimmer_tag.dart';

const Color _shimmerBase = Color(0xFFF1F5F9);
const Color _shimmerHighlight = Color(0xFFE2E8F0);
const Color _shimmerAccentViolet = Color(0xFFAB31DE);

class HomeScreenShimmer extends StatelessWidget {
  const HomeScreenShimmer({super.key});

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double borderRadius = 12.0,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return ShimmerTag(
      type: ShimmerType.pulse,
      baseColor: baseColor ?? _shimmerBase,
      highlightColor: highlightColor ?? _shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor ?? _shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }

  Widget _buildSectionHeaderShimmer({
    required double titleWidth,
    required double subtitleWidth,
    bool showFilterPills = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSkeletonBox(width: titleWidth, height: 18.h, borderRadius: 6.r),
                SizedBox(height: 5.h),
                _buildSkeletonBox(width: subtitleWidth, height: 10.h, borderRadius: 4.r),
              ],
            ),
            if (showFilterPills)
              Row(
                children: [
                  _buildSkeletonBox(width: 65.w, height: 26.h, borderRadius: 13.r),
                  SizedBox(width: 6.w),
                  _buildSkeletonBox(width: 65.w, height: 26.h, borderRadius: 13.r),
                ],
              ),
          ],
        ),
        SizedBox(height: 8.h),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 36.w,
            height: 2.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_shimmerAccentViolet, Colors.transparent],
              ),
              borderRadius: BorderRadius.circular(1.r),
            ),
          ),
        ),
      ],
    );
  }

  // 1. Top Fixed User Profile Header Skeleton
  Widget _buildTopHeaderSkeleton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Avatar + "Hi," + User Name
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSkeletonBox(width: 44.w, height: 44.w, borderRadius: 22.r),
                  SizedBox(width: 10.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSkeletonBox(width: 24.w, height: 12.h, borderRadius: 4.r),
                      SizedBox(height: 4.h),
                      _buildSkeletonBox(width: 95.w, height: 16.h, borderRadius: 6.r),
                    ],
                  ),
                ],
              ),

              // Right: Balance Coin Pill
              _buildSkeletonBox(width: 110.w, height: 36.h, borderRadius: 18.r),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Balance Card Skeleton (Matching BalanceCard design 1-to-1)
  Widget _buildBalanceCardSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        height: 146.h,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSkeletonBox(width: 95.w, height: 13.h, borderRadius: 6.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 60.w, height: 22.h, borderRadius: 6.r),
                  SizedBox(height: 14.h),
                  _buildSkeletonBox(width: 75.w, height: 13.h, borderRadius: 6.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 50.w, height: 22.h, borderRadius: 6.r),
                ],
              ),
            ),
            _buildSkeletonBox(width: 110.w, height: 110.w, borderRadius: 20.r),
          ],
        ),
      ),
    );
  }

  // 3. Home Banner Slider Skeleton (140.h with 3 dots)
  Widget _buildBannerSliderSkeleton() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            height: 140.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            ),
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSkeletonBox(width: 90.w, height: 16.h, borderRadius: 6.r),
                      SizedBox(height: 8.h),
                      _buildSkeletonBox(width: 140.w, height: 20.h, borderRadius: 6.r),
                      SizedBox(height: 12.h),
                      _buildSkeletonBox(width: 80.w, height: 28.h, borderRadius: 14.r),
                    ],
                  ),
                ),
                _buildSkeletonBox(width: 90.w, height: 90.w, borderRadius: 16.r),
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSkeletonBox(width: 22.w, height: 5.h, borderRadius: 3.r, baseColor: _shimmerAccentViolet),
            SizedBox(width: 6.w),
            _buildSkeletonBox(width: 6.w, height: 5.h, borderRadius: 3.r),
            SizedBox(width: 6.w),
            _buildSkeletonBox(width: 6.w, height: 5.h, borderRadius: 3.r),
          ],
        ),
      ],
    );
  }

  // 4. Quick Shortcut Cards Grid Skeleton (Horizontal Scrolling List of 6 items: Offerwall, Daily Task, Daily Streak, Survey, Promocode, Giveaway)
  Widget _buildQuickShortcutsSkeleton() {
    return SizedBox(
      height: 74.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: 6,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          return Container(
            width: 68.w,
            height: 74.h,
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSkeletonBox(width: 32.w, height: 32.w, borderRadius: 16.r),
                SizedBox(height: 6.h),
                _buildSkeletonBox(width: 48.w, height: 10.h, borderRadius: 4.r),
              ],
            ),
          );
        },
      ),
    );
  }

  // 5. Play Games Hero Banner Skeleton ("Daily Challenge" Hero Card)
  Widget _buildPlayGamesHeroSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        height: 126.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSkeletonBox(width: 75.w, height: 12.h, borderRadius: 4.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 130.w, height: 20.h, borderRadius: 6.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 155.w, height: 10.h, borderRadius: 5.r),
                ],
              ),
            ),
            _buildSkeletonBox(width: 85.w, height: 85.w, borderRadius: 20.r),
          ],
        ),
      ),
    );
  }

  // 6. Slanted Pair Card Skeleton (Crazyreward & Super Offer side-by-side pair)
  Widget _buildSlantedCardsPairSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          // Left Card: Crazyreward
          Expanded(
            child: Container(
              height: 148.h,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _buildSkeletonBox(width: 64.w, height: 64.w, borderRadius: 16.r),
                  ),
                  const Spacer(),
                  _buildSkeletonBox(width: 85.w, height: 14.h, borderRadius: 6.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 60.w, height: 18.h, borderRadius: 9.r),
                ],
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Right Card: Super Offer
          Expanded(
            child: Container(
              height: 148.h,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _buildSkeletonBox(width: 64.w, height: 64.w, borderRadius: 16.r),
                  ),
                  const Spacer(),
                  _buildSkeletonBox(width: 85.w, height: 14.h, borderRadius: 6.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 60.w, height: 18.h, borderRadius: 9.r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7. Offer Partners 2-Column Grid Skeleton
  Widget _buildPartnersSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          _buildSectionHeaderShimmer(titleWidth: 140.w, subtitleWidth: 180.w, showFilterPills: true),
          SizedBox(height: 14.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 2.1,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                ),
                child: Row(
                  children: [
                    _buildSkeletonBox(width: 36.w, height: 36.w, borderRadius: 10.r),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSkeletonBox(width: 55.w, height: 11.h, borderRadius: 5.r),
                          SizedBox(height: 4.h),
                          _buildSkeletonBox(width: 40.w, height: 8.h, borderRadius: 4.r),
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

  // 8. More Ways Section Skeleton (Invite Friends, Play Games, Read Articles, Watch Videos)
  Widget _buildMoreWaysSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          _buildSectionHeaderShimmer(titleWidth: 120.w, subtitleWidth: 190.w),
          SizedBox(height: 14.h),
          ...List.generate(4, (index) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Container(
              width: double.infinity,
              height: 76.h,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              ),
              child: Row(
                children: [
                  _buildSkeletonBox(width: 44.w, height: 44.w, borderRadius: 14.r),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSkeletonBox(width: 110.w, height: 14.h, borderRadius: 6.r),
                        SizedBox(height: 5.h),
                        _buildSkeletonBox(width: 140.w, height: 10.h, borderRadius: 4.r),
                      ],
                    ),
                  ),
                  _buildSkeletonBox(width: 24.w, height: 24.w, borderRadius: 12.r),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  // 9. More Apps Section Skeleton
  Widget _buildMoreAppsSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          _buildSectionHeaderShimmer(titleWidth: 110.w, subtitleWidth: 160.w),
          SizedBox(height: 14.h),
          ...List.generate(3, (index) => Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Container(
              width: double.infinity,
              height: 76.h,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              ),
              child: Row(
                children: [
                  _buildSkeletonBox(width: 48.w, height: 48.w, borderRadius: 14.r),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSkeletonBox(width: 100.w, height: 14.h, borderRadius: 6.r),
                        SizedBox(height: 5.h),
                        _buildSkeletonBox(width: 130.w, height: 10.h, borderRadius: 4.r),
                      ],
                    ),
                  ),
                  _buildSkeletonBox(width: 64.w, height: 30.h, borderRadius: 15.r),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  // 10. Follow Us Card Skeleton
  Widget _buildFollowUsSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        width: double.infinity,
        height: 124.h,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSkeletonBox(width: 80.w, height: 12.h, borderRadius: 4.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 140.w, height: 18.h, borderRadius: 6.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 110.w, height: 10.h, borderRadius: 4.r),
                ],
              ),
            ),
            _buildSkeletonBox(width: 70.w, height: 70.w, borderRadius: 18.r),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // 1. Solid White Background
        Positioned.fill(
          child: Container(
            color: Colors.white,
          ),
        ),

        // 2. Fixed Top User Header (Pinned at Top)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            color: Colors.white,
            child: _buildTopHeaderSkeleton(context),
          ),
        ),

        // 3. Scrollable Feed Skeletons matching exact Home layout sequence 1-to-1
        Positioned.fill(
          top: 64.h + topPadding,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                SizedBox(height: 10.h),

                // 1. Balance Card
                _buildBalanceCardSkeleton(),

                SizedBox(height: 14.h),

                // 2. Banner Slider
                _buildBannerSliderSkeleton(),

                SizedBox(height: 14.h),

                // 3. Daily Tasks Carousel
                const HomeDailyTaskShimmer(),

                SizedBox(height: 14.h),

                // 4. Slanted Cards Pair (Crazyreward & Super Offer)
                _buildSlantedCardsPairSkeleton(),

                SizedBox(height: 14.h),

                // 5. Daily Challenge Hero Banner
                _buildPlayGamesHeroSkeleton(),

                SizedBox(height: 8.h),

                // 6. Quick Shortcuts Horizontal Grid (Offerwall, Daily Task, Daily Streak, Survey, Promocode, Giveaway)
                _buildQuickShortcutsSkeleton(),

                SizedBox(height: 24.h),

                // 7. Offer Partners Section
                _buildPartnersSkeleton(),

                SizedBox(height: 24.h),

                // 8. More Ways Section
                _buildMoreWaysSkeleton(),

                SizedBox(height: 24.h),

                // 9. More Apps Section
                _buildMoreAppsSkeleton(),

                SizedBox(height: 24.h),

                // 10. Follow Us Card
                _buildFollowUsSkeleton(),

                SizedBox(height: 100.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Task Section Shimmer (100% 1-to-1 Matching loaded HomeDailyTaskSection)
// ---------------------------------------------------------------------------
class HomeDailyTaskShimmer extends StatelessWidget {
  const HomeDailyTaskShimmer({super.key});

  Widget _buildSkeletonBox({
    required double width,
    required double height,
    double borderRadius = 12.0,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return ShimmerTag(
      type: ShimmerType.pulse,
      baseColor: baseColor ?? _shimmerBase,
      highlightColor: highlightColor ?? _shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor ?? _shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row (Title on Left, "View All" Button on Right)
          Row(
            children: [
              _buildSkeletonBox(width: 110.w, height: 20.h, borderRadius: 6.r),
              const Spacer(),
              _buildSkeletonBox(width: 75.w, height: 28.h, borderRadius: 10.r),
            ],
          ),
          SizedBox(height: 14.h),

          // 2. Wide Horizontal Banner Card (122.h height matching exact 1-to-1 card layout)
          Container(
            height: 122.h,
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left Content: Category Tag, Title, Subtitle & Reward Pill
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSkeletonBox(width: 60.w, height: 12.h, borderRadius: 4.r),
                      SizedBox(height: 8.h),
                      _buildSkeletonBox(width: 120.w, height: 18.h, borderRadius: 6.r),
                      SizedBox(height: 6.h),
                      _buildSkeletonBox(width: 90.w, height: 10.h, borderRadius: 4.r),
                      SizedBox(height: 10.h),
                      _buildSkeletonBox(width: 65.w, height: 22.h, borderRadius: 11.r),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                // Right Content: App Thumbnail / Artwork Box
                _buildSkeletonBox(width: 86.w, height: 86.w, borderRadius: 18.r),
              ],
            ),
          ),
          SizedBox(height: 14.h),

          // 3. Bottom Indicator Dots (5 Dots)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSkeletonBox(width: 18.w, height: 6.h, borderRadius: 3.r, baseColor: _shimmerAccentViolet),
              SizedBox(width: 5.w),
              _buildSkeletonBox(width: 6.w, height: 6.h, borderRadius: 3.r),
              SizedBox(width: 5.w),
              _buildSkeletonBox(width: 6.w, height: 6.h, borderRadius: 3.r),
              SizedBox(width: 5.w),
              _buildSkeletonBox(width: 6.w, height: 6.h, borderRadius: 3.r),
              SizedBox(width: 5.w),
              _buildSkeletonBox(width: 6.w, height: 6.h, borderRadius: 3.r),
            ],
          ),
        ],
      ),
    );
  }
}
