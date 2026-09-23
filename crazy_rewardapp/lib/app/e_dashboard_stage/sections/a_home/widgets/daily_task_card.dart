import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/helper/helper.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../widgets/common/custom_loading.dart';
import '../../../../../widgets/common/internet_image.dart';
import '../../../../../widgets/common/shimmer_tag.dart';
import '../daily_task/daily_task_model.dart';

class HomeDailyTaskSection extends HookConsumerWidget {
  const HomeDailyTaskSection({
    super.key,
    required this.offers,
    required this.userId,
    required this.email,
    required this.country,
  });

  final List<DailyTaskModel> offers;
  final String userId;
  final String email;
  final String country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadingId = useState<String?>(null);
    final featuredOffer = offers.isNotEmpty ? offers.first : null;

    if (featuredOffer == null) {
      return const SizedBox();
    }

    return Padding(
      padding: EdgeInsets.only(top: 0.h, bottom: 0.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Header (Centered "Hot Offers" in cursive script style)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                AutoRouter.of(context).push(
                  DailyTaskScreenRoute(
                    userId: userId,
                    email: email,
                    country: country,
                  ),
                );
              },
              child: Center(
                child: Text(
                  'Hot Offers',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.kaushanScript(
                    color: const Color(0xFF26262B),
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // 2. Exactly Two Side-by-Side Cards (Left: Featured Offer, Right: Hot Offers Entrance)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                // Left Card: Featured Daily Task Offer (Tap opens Task Details)
                Expanded(
                  child: _HotOffersModernCard(
                    item: featuredOffer,
                    isLoading: loadingId.value == featuredOffer.offerId,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await AutoRouter.of(context).push(
                        DailyTaskDetailsScreenRoute(
                          item: featuredOffer,
                          cardColor: featuredOffer.color,
                          userId: userId,
                          email: email,
                          country: country,
                          heroTag: 'task_card_home_${featuredOffer.offerId}_0',
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                // Right Card: Hot Offers Main Entrance Card (Tap opens DailyTaskScreenRoute)
                Expanded(
                  child: _HotOffersEntranceCard(
                    coins: offers.isNotEmpty
                        ? offers.map((e) => e.coins).fold<int>(0, (max, c) => c > max ? c : max)
                        : featuredOffer.coins,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      AutoRouter.of(context).push(
                        DailyTaskScreenRoute(
                          userId: userId,
                          email: email,
                          country: country,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HotOffersCoinBadge extends StatelessWidget {
  const _HotOffersCoinBadge({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFF26262E),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: const Color(0xFF383842),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
              ),
            ),
            padding: EdgeInsets.all(1.w),
            child: Image.asset(
              'assets/icons/coin.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.monetization_on,
                color: Color(0xFFFBBF24),
                size: 10,
              ),
            ),
          ),
          SizedBox(width: 3.5.w),
          Text(
            '$coins',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotOffersEntranceCard extends StatelessWidget {
  const _HotOffersEntranceCard({
    required this.onTap,
    this.coins = 156,
  });

  final VoidCallback onTap;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 152.h,
        padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 6.h),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/Icons1/Rectangle 13.png'),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Top Artwork/Thumbnail Box (Using Frame 3 (1).png)
            Container(
              height: 52.h,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: const Color(0xFF202028),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9.r),
                child: Image.asset(
                  'assets/Icons1/Frame 3 (1).png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),

            SizedBox(height: 3.h),

            // 2. Title
            Text(
              'Hot Offers',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),

            SizedBox(height: 1.h),

            // 3. Subtitle / Short description
            SizedBox(
              height: 14.h,
              child: Text(
                'Play coin master and build your village',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF9E9EA7),
                  fontSize: 7.5.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
            ),

            SizedBox(height: 2.h),

            // 4. Get Coins Upto Row (Dynamic Coin Badge)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Get Coins Upto',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4.w),
                _HotOffersCoinBadge(coins: coins),
              ],
            ),

            const Spacer(),

            // 5. Bottom Silver Metallic Action Button (Pushed to bottom)
            Container(
              width: 22.h,
              height: 22.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Color(0xFFE5E7EB),
                    Color(0xFFB0B5C2),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: const Color(0xFF16161A),
                  size: 12.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotOffersModernCard extends StatelessWidget {
  const _HotOffersModernCard({
    required this.item,
    required this.onTap,
    this.isLoading = false,
  });

  final DailyTaskModel item;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.bannerPath.isNotEmpty ? item.bannerPath : item.imagePath;
    final subtitle = item.subDescription.isNotEmpty
        ? item.subDescription
        : (item.offerDescription.isNotEmpty
            ? item.offerDescription.first
            : 'Play coin master and build your village');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 152.h,
        padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 6.h),
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/Icons1/Rectangle 13.png'),
            fit: BoxFit.fill,
          ),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Top Artwork/Thumbnail Box
            Container(
              height: 52.h,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.r),
                color: const Color(0xFF202028),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9.r),
                child: imageUrl.isNotEmpty
                    ? InternetImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Image.asset(
                        'assets/Icons1/Frame 3 (1).png',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
              ),
            ),

            SizedBox(height: 3.h),

            // 2. Title
            Text(
              item.offerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),

            SizedBox(height: 1.h),

            // 3. Subtitle / Short description
            SizedBox(
              height: 14.h,
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF9E9EA7),
                  fontSize: 7.5.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
            ),

            SizedBox(height: 2.h),

            // 4. Get Coins Upto Row (Dynamic Coin Badge)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Get Coins Upto',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4.w),
                _HotOffersCoinBadge(coins: item.coins),
              ],
            ),

            const Spacer(),

            // 5. Bottom Silver Metallic Action Button (Claim) (Pushed to bottom)
            Container(
              height: 22.h,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Color(0xFFE5E7EB),
                    Color(0xFFB0B5C2),
                  ],
                ),
                borderRadius: BorderRadius.circular(11.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16161A)),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.card_giftcard_rounded,
                            color: const Color(0xFF16161A),
                            size: 10.sp,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'Claim',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF16161A),
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyTaskHorizontalCard extends StatelessWidget {
  const DailyTaskHorizontalCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isLoading = false,
    this.heroTag,
  });

  final DailyTaskModel item;
  final VoidCallback onTap;
  final bool isLoading;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final isHighPaying = item.coins >= 300;
    final tagGradient = isHighPaying
        ? const LinearGradient(
            colors: [Color(0xFFFFF1C5), Color(0xFFFFD54F)], // Light Gold
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFF81C784)], // Soft Mint/Green
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );
    final tagText = isHighPaying ? 'High Reward' : 'New Offer';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 135.h,
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Custom Painted Ticket background
            LayoutBuilder(
              builder: (context, constraints) {
                final clipX = constraints.maxWidth - 82.w;
                final ticketRadius = 10.r;
                final rrectRadius = 16.r;
                return SizedBox(
                  width: constraints.maxWidth,
                  height: 120.h,
                  child: Stack(
                    children: [
                      // 1. Ticket background and shadow
                      CustomPaint(
                        size: Size(constraints.maxWidth, 120.h),
                        painter: TicketPainter(
                          clipX: clipX,
                          radius: ticketRadius,
                        ),
                      ),
                      // 2. Subtle Rotating Sunburst Rays (Clipped to ticket shape)
                      Positioned.fill(
                        child: ClipPath(
                          clipper: TicketClipper(
                            clipX: clipX,
                            radius: ticketRadius,
                            rrectRadius: rrectRadius,
                          ),
                          child: RotatingSunburst(
                            rayColor: const Color(0xFFD3A32D).withValues(alpha: 0.1), // Subtle gold rays
                          ),
                        ),
                      ),
                      // 3. Foreground content
                      SizedBox(
                        width: constraints.maxWidth,
                        height: 120.h,
                        child: Row(
                          children: [
                            // Left Section: Main Ticket Body
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 14.w,
                                  right: 12.w,
                                  top: 12.h,
                                  bottom: 12.h,
                                ),
                                child: Row(
                                  children: [
                                    // Logo
                                    Container(
                                      width: 52.w,
                                      height: 52.w,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14.r),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14.r),
                                        child: InternetImage(
                                          url: item.imagePath,
                                          width: 52.w,
                                          height: 52.w,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    // Text details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item.offerName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: const Color(0xFF1E1C24),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13.sp,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          SizedBox(height: 3.h),
                                          Text(
                                            item.cleanSubtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: const Color(0xFF6B6675),
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (item.trackingTime > 0) ...[
                                            SizedBox(height: 4.h),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time_filled_rounded,
                                                  size: 10.sp,
                                                  color: const Color(0xFFFF5252),
                                                ),
                                                SizedBox(width: 3.w),
                                                Text(
                                                  '${item.trackingTime} mins',
                                                  style: TextStyle(
                                                    color: const Color(0xFFFF5252),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 9.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Right Section: Ticket Stub (Coin reward pill)
                            Container(
                              width: 92.w,
                              alignment: Alignment.center,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 5.w),
                                child: Container(
                                  width: 82.w,
                                  height: 35.h,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFF9C487), // Lighter gold/brown
                                        Color(0xFFD68A2E), // Base Leaderboard brown
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(16.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD68A2E).withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isLoading
                                      ? const Center(
                                          child: GlowLightingSpinner(size: 14),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/icons/coin.png',
                                              height: 15.sp,
                                              width: 15.sp,
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              item.coins.formatCoins(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 12.sp,
                                              ),
                                            ),
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
                );
              },
            ),
            // Floating Status Badge on top left
            Positioned(
              top: 2.h,
              left: 12.w,
              child: FlippingTag(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    gradient: tagGradient,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: (isHighPaying
                                ? const Color(0xFFFF8F00)
                                : const Color(0xFF81C784))
                            .withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isHighPaying
                            ? Icons.local_fire_department_rounded
                            : Icons.star_rounded,
                        color: isHighPaying
                            ? const Color(0xFF7B5B00)
                            : const Color(0xFF2E7D32),
                        size: 9.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        tagText,
                        style: TextStyle(
                          color: isHighPaying
                              ? const Color(0xFF7B5B00)
                              : const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w900,
                          fontSize: 8.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyTaskGridCard extends StatelessWidget {
  const DailyTaskGridCard({
    super.key,
    required this.item,
    required this.onTap,
    this.isLoading = false,
    this.heroTag,
  });

  final DailyTaskModel item;
  final VoidCallback onTap;
  final bool isLoading;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final isHighPaying = item.coins >= 300;
    final tagGradient = isHighPaying
        ? const LinearGradient(
            colors: [Color(0xFFFFF1C5), Color(0xFFFFD54F)], // Light Gold
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFECEC), Color(0xFFFF8A8A)], // Soft Pink/Coral
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFFDFD), // Cream White
              Color(0xFFFFF3F0), // Soft Peach
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF7A59).withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Stack(
            children: [
              // Ambient glow spots peaking from behind in grid style
              Positioned(
                right: -25.w,
                bottom: -25.h,
                child: Container(
                  width: 70.w,
                  height: 70.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF8A65).withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -25.w,
                top: -25.h,
                child: Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFD54F).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              
              // Card contents layout
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Logo & Status Tag
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Logo inside soft-shadow card (no border)
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: InternetImage(
                            url: item.imagePath,
                            width: 40.w,
                            height: 40.w,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      
                      // Status Tag (New / High)
                      FlippingTag(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            gradient: tagGradient,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isHighPaying ? Icons.local_fire_department_rounded : Icons.star_rounded,
                                color: isHighPaying ? const Color(0xFF7B5B00) : const Color(0xFFC62828),
                                size: 9.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                isHighPaying ? 'High' : 'New',
                                style: TextStyle(
                                  color: isHighPaying ? const Color(0xFF7B5B00) : const Color(0xFFC62828),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Middle Section: Task texts
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.offerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF1E1C24), // High-contrast charcoal text
                          fontWeight: FontWeight.w900,
                          fontSize: 12.sp,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        item.cleanSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF6B6675), // Readable grey-brown text
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  // Bottom Section: Centered Premium Coin button (No Install category tag)
                  ShimmerTag(
                    type: ShimmerType.shining,
                    blendMode: BlendMode.srcATop,
                    baseColor: Colors.transparent,
                    highlightColor: Colors.white.withValues(alpha: 0.45),
                    child: Container(
                      width: double.infinity,
                      height: 33.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFC107), // Glossy Amber Gold
                            Color(0xFFFF8F00),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8F00).withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isLoading
                          ? const Center(
                              child: GlowLightingSpinner(size: 14),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/icons/coin.png',
                                  height: 15.sp,
                                  width: 15.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  item.coins.formatCoins(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class TicketPainter extends CustomPainter {
  final double clipX;
  final double radius;

  TicketPainter({
    required this.clipX,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrectRadius = 16.r;

    final paint = Paint()
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    paint.shader = const LinearGradient(
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFFFFDF5),
        Color(0xFFFFF9E6),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);

    final borderPaint = Paint()
      ..color = const Color(0xFFD3A32D).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path()
      ..moveTo(0, rrectRadius)
      // Top-left rounded corner
      ..quadraticBezierTo(0, 0, rrectRadius, 0)
      // Top line to cutout
      ..lineTo(clipX - radius, 0)
      // Top cutout (concave semi-circle going inwards)
      ..arcToPoint(
        Offset(clipX + radius, 0),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      // Top line to top-right corner
      ..lineTo(size.width - rrectRadius, 0)
      // Top-right corner
      ..quadraticBezierTo(size.width, 0, size.width, rrectRadius)
      // Right line to bottom-right corner
      ..lineTo(size.width, size.height - rrectRadius)
      // Bottom-right corner
      ..quadraticBezierTo(size.width, size.height, size.width - rrectRadius, size.height)
      // Bottom line to bottom cutout
      ..lineTo(clipX + radius, size.height)
      // Bottom cutout (concave semi-circle going inwards)
      ..arcToPoint(
        Offset(clipX - radius, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      // Bottom line to bottom-left corner
      ..lineTo(rrectRadius, size.height)
      // Bottom-left corner
      ..quadraticBezierTo(0, size.height, 0, size.height - rrectRadius)
      ..close();

    // Draw shadow
    canvas.drawShadow(
      path,
      const Color(0xFFD68A2E).withValues(alpha: 0.12),
      4.0,
      true,
    );

    // Draw ticket background
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Draw dashed vertical divider
    final dashPaint = Paint()
      ..color = const Color(0xFFD3A32D).withValues(alpha: 0.25) // Soft Watch gold divider
      ..strokeWidth = 1.2.w
      ..style = PaintingStyle.stroke;

    double startY = radius + 6.h;
    final endY = size.height - radius - 6.h;
    final dashHeight = 4.h;
    final dashSpace = 4.h;

    while (startY < endY) {
      canvas.drawLine(
        Offset(clipX, startY),
        Offset(clipX, startY + dashHeight),
        dashPaint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant TicketPainter oldDelegate) {
    return oldDelegate.clipX != clipX || oldDelegate.radius != radius;
  }
}

class FlippingTag extends StatefulWidget {
  final Widget child;
  const FlippingTag({super.key, required this.child});

  @override
  State<FlippingTag> createState() => _FlippingTagState();
}

class _FlippingTagState extends State<FlippingTag> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4 seconds total cycle
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Spin a full 360 degrees (2 * pi) in the last 0.8 seconds (20% of 4-sec duration)
        final double value = _controller.value;
        double angle = 0.0;
        if (value > 0.8) {
          final double t = (value - 0.8) / 0.2; // normalize to 0.0 -> 1.0
          final double curveT = Curves.easeInOutCubic.transform(t);
          angle = curveT * 2 * math.pi;
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002) // 3D Perspective
            ..rotateY(angle),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  final double clipX;
  final double radius;
  final double rrectRadius;

  TicketClipper({
    required this.clipX,
    required this.radius,
    required this.rrectRadius,
  });

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, rrectRadius)
      ..quadraticBezierTo(0, 0, rrectRadius, 0)
      ..lineTo(clipX - radius, 0)
      ..arcToPoint(
        Offset(clipX + radius, 0),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(size.width - rrectRadius, 0)
      ..quadraticBezierTo(size.width, 0, size.width, rrectRadius)
      ..lineTo(size.width, size.height - rrectRadius)
      ..quadraticBezierTo(size.width, size.height, size.width - rrectRadius, size.height)
      ..lineTo(clipX + radius, size.height)
      ..arcToPoint(
        Offset(clipX - radius, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(rrectRadius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - rrectRadius)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketClipper oldClipper) {
    return oldClipper.clipX != clipX || oldClipper.radius != radius || oldClipper.rrectRadius != rrectRadius;
  }
}

class SunburstPainter extends CustomPainter {
  final double rotationAngle;
  final Color rayColor;

  SunburstPainter({
    required this.rotationAngle,
    required this.rayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.sqrt(size.width * size.width + size.height * size.height);
    
    final paint = Paint()
      ..color = rayColor
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    const int numRays = 16;
    final double angleStep = 2 * math.pi / numRays;
    final double halfRayWidth = angleStep / 4; // ray occupies 50% of its step sector

    for (int i = 0; i < numRays; i++) {
      final double rayAngle = i * angleStep;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(radius * math.cos(rayAngle - halfRayWidth), radius * math.sin(rayAngle - halfRayWidth))
        ..lineTo(radius * math.cos(rayAngle + halfRayWidth), radius * math.sin(rayAngle + halfRayWidth))
        ..close();
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SunburstPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle || oldDelegate.rayColor != rayColor;
  }
}

class RotatingSunburst extends StatefulWidget {
  final Color rayColor;
  const RotatingSunburst({
    super.key,
    required this.rayColor,
  });

  @override
  State<RotatingSunburst> createState() => _RotatingSunburstState();
}

class _RotatingSunburstState extends State<RotatingSunburst> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // slow, premium rotation
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: SunburstPainter(
            rotationAngle: _controller.value * 2 * math.pi,
            rayColor: widget.rayColor,
          ),
        );
      },
    );
  }
}
