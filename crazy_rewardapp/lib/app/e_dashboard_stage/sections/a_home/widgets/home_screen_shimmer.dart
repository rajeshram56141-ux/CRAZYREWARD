import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../widgets/common/shimmer_tag.dart';

const Color _shimmerBase = Color(0xFFCBD5E1);
const Color _shimmerHighlight = Color(0xFFF1F5F9);
const Color _shimmerDarkBase = Color(0xFF222228);
const Color _shimmerDarkHighlight = Color(0xFF33333E);

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
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
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
          _buildSkeletonBox(
            width: titleWidth,
            height: 18.h,
            borderRadius: 4.r,
            baseColor: const Color(0xFF94A3B8),
            highlightColor: const Color(0xFFE2E8F0),
          ),
        ],
      ),
    );
  }

  // 1. Top Silver Curved Header & Balance Skeleton (Matching _HomeTopHeaderCard exactly)
  Widget _buildTopHeaderSkeleton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/icons/rectangle_285.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 26.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Profile Capsule Pill + Hi User (Left) & Bell Notification (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Capsule Pill + Greeting Column
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // User Profile Capsule Pill
                      Container(
                        height: 38.h,
                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B2E),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSkeletonBox(
                              width: 28.w,
                              height: 28.w,
                              borderRadius: 14.r,
                              baseColor: const Color(0xFF383848),
                              highlightColor: const Color(0xFF555566),
                            ),
                            SizedBox(width: 8.w),
                            Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 14.w,
                                    height: 2.2.h,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Container(
                                    width: 14.w,
                                    height: 2.2.h,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Container(
                                    width: 14.w,
                                    height: 2.2.h,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 10.w),

                      // Greeting & Name Shimmer
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSkeletonBox(
                            width: 24.w,
                            height: 11.h,
                            borderRadius: 3.r,
                            baseColor: const Color(0xFF334155),
                            highlightColor: const Color(0xFF64748B),
                          ),
                          SizedBox(height: 4.h),
                          _buildSkeletonBox(
                            width: 75.w,
                            height: 14.h,
                            borderRadius: 4.r,
                            baseColor: const Color(0xFF1E293B),
                            highlightColor: const Color(0xFF475569),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Right: Polygon Bell Button
                  SizedBox(
                    width: 44.w,
                    height: 44.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/icons/polygon_2.png',
                          width: 44.w,
                          height: 44.w,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B2E),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.notifications_rounded,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 20.sp,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 18.h),

              // Middle: Available Balance with Diamond Dividers
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Row(
                  children: [
                    // Left Divider Line with Diamond
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1.2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Transform.rotate(
                            angle: 0.785398,
                            child: Container(
                              width: 5.5.w,
                              height: 5.5.w,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: _buildSkeletonBox(
                        width: 105.w,
                        height: 13.h,
                        borderRadius: 4.r,
                        baseColor: Colors.white.withValues(alpha: 0.35),
                        highlightColor: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),

                    // Right Divider Line with Diamond
                    Expanded(
                      child: Row(
                        children: [
                          Transform.rotate(
                            angle: 0.785398,
                            child: Container(
                              width: 5.5.w,
                              height: 5.5.w,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Container(
                              height: 1.2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.85),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
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

              SizedBox(height: 10.h),

              // Bottom: 3D Dollar Coin + Large Balance Shimmer + Conversion Rate Shimmer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 3D Dollar Coin
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFDF00),
                          Color(0xFFFFA500),
                          Color(0xFFFF8C00),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFF7C2),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '\$',
                        style: TextStyle(
                          color: const Color(0xFFFFF9E6),
                          fontSize: 25.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 10.w),

                  // Large Balance Shimmer
                  _buildSkeletonBox(
                    width: 110.w,
                    height: 36.h,
                    borderRadius: 8.r,
                    baseColor: Colors.white.withValues(alpha: 0.45),
                    highlightColor: Colors.white.withValues(alpha: 0.95),
                  ),
                ],
              ),

              SizedBox(height: 6.h),

              // Conversion Rate Shimmer
              _buildSkeletonBox(
                width: 55.w,
                height: 11.h,
                borderRadius: 4.r,
                baseColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                highlightColor: const Color(0xFF10B981).withValues(alpha: 0.75),
              ),

              SizedBox(height: 18.h),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Home Banner Slider Skeleton (140.h with 3 dots)
  Widget _buildBannerSliderSkeleton() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            height: 140.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B4B),
              borderRadius: BorderRadius.circular(26.r),
              border: Border.all(
                color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSkeletonBox(
                        width: 90.w,
                        height: 14.h,
                        borderRadius: 4.r,
                        baseColor: const Color(0xFF4C1D95),
                        highlightColor: const Color(0xFF7C3AED),
                      ),
                      SizedBox(height: 8.h),
                      _buildSkeletonBox(
                        width: 130.w,
                        height: 18.h,
                        borderRadius: 6.r,
                        baseColor: const Color(0xFF5B21B6),
                        highlightColor: const Color(0xFF8B5CF6),
                      ),
                      SizedBox(height: 12.h),
                      _buildSkeletonBox(
                        width: 80.w,
                        height: 26.h,
                        borderRadius: 13.r,
                        baseColor: const Color(0xFF7C3AED),
                        highlightColor: const Color(0xFFA855F7),
                      ),
                    ],
                  ),
                ),
                _buildSkeletonBox(
                  width: 88.w,
                  height: 88.w,
                  borderRadius: 18.r,
                  baseColor: const Color(0xFF3B0764),
                  highlightColor: const Color(0xFF6B21A8),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSkeletonBox(
              width: 20.w,
              height: 6.h,
              borderRadius: 3.r,
              baseColor: const Color(0xFFC084FC),
              highlightColor: Colors.white,
            ),
            SizedBox(width: 4.w),
            _buildSkeletonBox(
              width: 6.w,
              height: 6.h,
              borderRadius: 3.r,
              baseColor: const Color(0xFF334155),
            ),
            SizedBox(width: 4.w),
            _buildSkeletonBox(
              width: 6.w,
              height: 6.h,
              borderRadius: 3.r,
              baseColor: const Color(0xFF334155),
            ),
          ],
        ),
        SizedBox(height: 16.h),
      ],
    );
  }

  // 3. Regular Offers 2x2 Grid Skeleton
  Widget _buildRegularOffersSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderShimmer(titleWidth: 130.w),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Column(
            children: [
              // Row 1: Play Games & Super Offers
              Row(
                children: [
                  Expanded(child: _buildRegularCardItem()),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildRegularCardItem()),
                ],
              ),
              SizedBox(height: 12.h),
              // Row 2: Battle Quiz & Offerwalls
              Row(
                children: [
                  Expanded(child: _buildRegularCardItem()),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildRegularCardItem()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegularCardItem() {
    return Container(
      height: 142.h,
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFF282832), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSkeletonBox(
            width: 75.w,
            height: 13.h,
            borderRadius: 4.r,
            baseColor: _shimmerDarkHighlight,
          ),
          SizedBox(height: 4.h),
          _buildSkeletonBox(
            width: 50.w,
            height: 9.h,
            borderRadius: 3.r,
            baseColor: _shimmerDarkBase,
          ),
          const Spacer(),
          _buildSkeletonBox(
            width: 60.w,
            height: 50.h,
            borderRadius: 12.r,
            baseColor: _shimmerDarkBase,
            highlightColor: _shimmerDarkHighlight,
          ),
        ],
      ),
    );
  }

  // 4. Daily Challenge Hero Banner Skeleton ("_PlayGamesHeroBanner")
  Widget _buildDailyChallengeHeroSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Container(
        width: double.infinity,
        height: 96.h,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7CC),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: const Color(0xFFFEF08A).withValues(alpha: 0.80),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEAB308).withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        child: Row(
          children: [
            // Left Circle / Icon
            Container(
              width: 80.w,
              height: 70.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.72),
              ),
              child: Center(
                child: _buildSkeletonBox(
                  width: 50.w,
                  height: 50.w,
                  borderRadius: 25.r,
                  baseColor: const Color(0xFFFDE047),
                  highlightColor: const Color(0xFFFEF08A),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Right Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSkeletonBox(
                    width: 110.w,
                    height: 15.h,
                    borderRadius: 4.r,
                    baseColor: const Color(0xFFCA8A04),
                    highlightColor: const Color(0xFFEAB308),
                  ),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(
                    width: double.infinity,
                    height: 10.h,
                    borderRadius: 3.r,
                    baseColor: const Color(0xFFD97706).withValues(alpha: 0.4),
                    highlightColor: const Color(0xFFFACC15).withValues(alpha: 0.7),
                  ),
                  SizedBox(height: 4.h),
                  _buildSkeletonBox(
                    width: 100.w,
                    height: 10.h,
                    borderRadius: 3.r,
                    baseColor: const Color(0xFFD97706).withValues(alpha: 0.3),
                    highlightColor: const Color(0xFFFACC15).withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Surveys Section Skeleton
  Widget _buildSurveysSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderShimmer(titleWidth: 75.w),
        SizedBox(height: 12.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFFFF2A8),
                          width: 2.5.w,
                        ),
                      ),
                      child: Center(
                        child: _buildSkeletonBox(
                          width: 32.w,
                          height: 32.w,
                          borderRadius: 16.r,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    _buildSkeletonBox(
                      width: 52.w,
                      height: 10.h,
                      borderRadius: 3.r,
                    ),
                  ],
                ),
                SizedBox(width: 14.w),
              ],
              // 5th View More Circle
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFF2A8),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                        size: 18.sp,
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(
                    width: 52.w,
                    height: 10.h,
                    borderRadius: 3.r,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 6. All Offers 2x2 Grid Skeleton
  Widget _buildAllOffersSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderShimmer(titleWidth: 90.w),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Column(
            children: [
              // Row 1: Watch & Earn & Play & Earn
              Row(
                children: [
                  Expanded(child: _buildAllOffersCardItem()),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildAllOffersCardItem()),
                ],
              ),
              SizedBox(height: 12.h),
              // Row 2: Daily Check-In & Read & Earn
              Row(
                children: [
                  Expanded(child: _buildAllOffersCardItem()),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildAllOffersCardItem()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllOffersCardItem() {
    return Container(
      height: 132.h,
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF2C2C36), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(10.w),
      child: Stack(
        children: [
          // Top Left Pill Shimmer
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSkeletonBox(
                  width: 52.w,
                  height: 16.h,
                  borderRadius: 8.r,
                  baseColor: _shimmerDarkHighlight,
                ),
                SizedBox(height: 3.h),
                _buildSkeletonBox(
                  width: 65.w,
                  height: 8.h,
                  borderRadius: 2.r,
                  baseColor: _shimmerDarkBase,
                ),
              ],
            ),
          ),
          // Bottom Label Shimmer
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildSkeletonBox(
              width: 80.w,
              height: 14.h,
              borderRadius: 4.r,
              baseColor: _shimmerDarkHighlight,
            ),
          ),
        ],
      ),
    );
  }

  // 7. Native Ad Card Skeleton
  Widget _buildNativeAdSkeleton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Container(
        width: double.infinity,
        height: 110.h,
        margin: EdgeInsets.only(top: 10.h, bottom: 20.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildSkeletonBox(
              width: 80.w,
              height: 80.w,
              borderRadius: 12.r,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSkeletonBox(width: 60.w, height: 10.h, borderRadius: 3.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 120.w, height: 14.h, borderRadius: 4.r),
                  SizedBox(height: 6.h),
                  _buildSkeletonBox(width: 140.w, height: 10.h, borderRadius: 3.r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 8. Special For You / More Ways Section Skeleton
  Widget _buildSpecialForYouSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderShimmer(titleWidth: 140.w),
        SizedBox(height: 12.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                Container(
                  width: 148.w,
                  height: 72.h,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5BD),
                    borderRadius: BorderRadius.circular(18.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildSkeletonBox(
                        width: 40.w,
                        height: 40.w,
                        borderRadius: 20.r,
                        baseColor: const Color(0xFFFDE047),
                        highlightColor: const Color(0xFFFEF08A),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSkeletonBox(
                              width: 70.w,
                              height: 13.h,
                              borderRadius: 3.r,
                              baseColor: const Color(0xFFCA8A04),
                              highlightColor: const Color(0xFFEAB308),
                            ),
                            SizedBox(height: 4.h),
                            _buildSkeletonBox(
                              width: 55.w,
                              height: 9.h,
                              borderRadius: 2.r,
                              baseColor: const Color(0xFFD97706).withValues(alpha: 0.5),
                              highlightColor: const Color(0xFFFACC15).withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 9. Bonus Offers Section Skeleton (Rate Us + Stay Updated)
  Widget _buildBonusOffersSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderShimmer(titleWidth: 120.w),
        SizedBox(height: 12.h),
        ...List.generate(2, (index) => Padding(
          padding: EdgeInsets.fromLTRB(6.w, 0, 6.w, 12.h),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18.w, 16.h, 12.w, 16.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF222226),
                  Color(0xFF131316),
                ],
              ),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: const Color(0xFF2E2E36),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSkeletonBox(
                        width: 120.w,
                        height: 15.h,
                        borderRadius: 4.r,
                        baseColor: _shimmerDarkHighlight,
                      ),
                      SizedBox(height: 5.h),
                      _buildSkeletonBox(
                        width: 150.w,
                        height: 10.h,
                        borderRadius: 3.r,
                        baseColor: _shimmerDarkBase,
                      ),
                      SizedBox(height: 12.h),
                      _buildSkeletonBox(
                        width: 90.w,
                        height: 26.h,
                        borderRadius: 13.r,
                        baseColor: const Color(0xFFE2E4E8),
                        highlightColor: Colors.white,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                _buildSkeletonBox(
                  width: 75.w,
                  height: 75.w,
                  borderRadius: 18.r,
                  baseColor: _shimmerDarkBase,
                  highlightColor: _shimmerDarkHighlight,
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  // 10. More Apps Section Skeleton
  Widget _buildMoreAppsSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderShimmer(titleWidth: 100.w),
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Column(
            children: [
              ...List.generate(2, (index) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
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
                      _buildSkeletonBox(
                        width: 46.w,
                        height: 46.w,
                        borderRadius: 23.r,
                        baseColor: const Color(0xFF1E293B),
                        highlightColor: const Color(0xFF334155),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSkeletonBox(
                              width: 90.w,
                              height: 13.h,
                              borderRadius: 4.r,
                              baseColor: _shimmerDarkHighlight,
                            ),
                            SizedBox(height: 4.h),
                            _buildSkeletonBox(
                              width: 140.w,
                              height: 9.h,
                              borderRadius: 3.r,
                              baseColor: _shimmerDarkBase,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      _buildSkeletonBox(
                        width: 36.w,
                        height: 36.w,
                        borderRadius: 18.r,
                        baseColor: Colors.white.withValues(alpha: 0.10),
                      ),
                    ],
                  ),
                ),
              )),
              SizedBox(height: 6.h),
              Center(
                child: _buildSkeletonBox(
                  width: 110.w,
                  height: 30.h,
                  borderRadius: 15.r,
                  baseColor: const Color(0xFF161618),
                  highlightColor: const Color(0xFF2E2E38),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Soft Premium Neutral Light-Grey Background (matching Auth & Home screens)
        Positioned.fill(
          child: Container(
            color: const Color(0xFFF1F5F9),
          ),
        ),

        // 2. Foreground Scrollable Feed matching Home Layout 1-to-1
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // 1. Silver Curved Header & Balance Card
                _buildTopHeaderSkeleton(context),

                // 2. Hot Offers / Daily Tasks Section
                Transform.translate(
                  offset: Offset(0, -10.h),
                  child: const HomeDailyTaskShimmer(),
                ),

                // 3. Home Banner Slider
                _buildBannerSliderSkeleton(),

                SizedBox(height: 14.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: Column(
                    children: [
                      // 4. Regular Offers (2x2 Grid)
                      _buildRegularOffersSkeleton(),

                      SizedBox(height: 20.h),

                      // 5. Daily Challenge Hero Banner
                      _buildDailyChallengeHeroSkeleton(),

                      SizedBox(height: 18.h),

                      // 6. Surveys Section
                      _buildSurveysSkeleton(),

                      SizedBox(height: 20.h),

                      // 7. All Offers (2x2 Grid)
                      _buildAllOffersSkeleton(),

                      SizedBox(height: 14.h),

                      // 8. Native Ad Card
                      _buildNativeAdSkeleton(),

                      SizedBox(height: 10.h),

                      // 9. Special For You / More Ways Section
                      _buildSpecialForYouSkeleton(),

                      SizedBox(height: 24.h),

                      // 10. Bonus Offers Section (Rate Us + Stay Updated)
                      _buildBonusOffersSkeleton(),

                      SizedBox(height: 24.h),

                      // 11. More Apps Section
                      _buildMoreAppsSkeleton(),

                      SizedBox(height: 100.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Task Section Shimmer (100% 1-to-1 Matching HomeDailyTaskSection)
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
      padding: EdgeInsets.only(top: 0.h, bottom: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Centered Header Shimmer
          Center(
            child: _buildSkeletonBox(
              width: 140.w,
              height: 26.h,
              borderRadius: 6.r,
              baseColor: const Color(0xFF1E1B4B).withValues(alpha: 0.25),
              highlightColor: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 6.h),

          // 2 Cards Side-by-Side in Row matching HomeDailyTaskSection
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Expanded(child: _buildCardSkeleton()),
                SizedBox(width: 12.w),
                Expanded(child: _buildCardSkeleton()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSkeleton() {
    return Container(
      height: 206.h,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFF282832), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSkeletonBox(
            width: double.infinity,
            height: 88.h,
            borderRadius: 15.r,
            baseColor: const Color(0xFF222228),
            highlightColor: const Color(0xFF2E2E38),
          ),
          SizedBox(height: 5.h),
          _buildSkeletonBox(
            width: 105.w,
            height: 13.h,
            borderRadius: 4.r,
            baseColor: const Color(0xFF2E2E38),
          ),
          SizedBox(height: 3.h),
          _buildSkeletonBox(
            width: 75.w,
            height: 10.h,
            borderRadius: 3.r,
            baseColor: const Color(0xFF222228),
          ),
          SizedBox(height: 5.h),
          _buildSkeletonBox(
            width: 110.w,
            height: 15.h,
            borderRadius: 8.r,
            baseColor: const Color(0xFF2E2E38),
          ),
          SizedBox(height: 5.h),
          _buildSkeletonBox(
            width: double.infinity,
            height: 26.h,
            borderRadius: 13.r,
            baseColor: const Color(0xFFE2E4E8),
            highlightColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
