import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../offerwall/model/offerwall_data_model.dart';
import '../offerwall/provider/offerwall_manager.dart';
import '../offerwall/provider/offerwall_provider.dart';
import 'package:lottie/lottie.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import 'surveys_section.dart';
import 'daily_checkin_sheet.dart';

class TopRecommendedTaskWidget extends StatelessWidget {
  const TopRecommendedTaskWidget({
    super.key,
    required this.userId,
    required this.email,
    required this.country,
    this.streak = 0,
    this.streakClaimed = false,
    this.coins = 0,
    this.dailyChallengeWidget,
    this.quickShortcutGridWidget,
  });

  final String userId;
  final String email;
  final String country;
  final int streak;
  final bool streakClaimed;
  final double coins;
  final Widget? dailyChallengeWidget;
  final Widget? quickShortcutGridWidget;

  @override
  Widget build(BuildContext context) {
    final bool hideDiamondCatch = SplashService.isScreenHidden('diamondCatch');
    final bool hidePlayGames = SplashService.isScreenHidden('playGames');
    final bool hideSuperOffer = SplashService.isScreenHidden('superOffer');
    final bool hideBattleArena = SplashService.isScreenHidden('battleArena');
    final bool hideWatchAndEarn = SplashService.isScreenHidden('watchAndEarn');
    final bool hideOfferwall = SplashService.isScreenHidden('offerwall');

    if (hideDiamondCatch && hidePlayGames && hideSuperOffer && hideBattleArena && hideWatchAndEarn && hideOfferwall) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // ================= 1. REGULAR OFFERS (2x2 GRID) =================
        if (!hidePlayGames || !hideDiamondCatch || !hideSuperOffer || !hideBattleArena || !hideOfferwall) ...[
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
                  'Regular Offers',
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

          // Regular Offers 2x2 Grid
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                // Top Row: Play Games & Super Offers
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildRegularPlayGamesCard(context),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildRegularSuperOffersCard(context),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                // Bottom Row: Battle Quiz & Offerwalls
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildRegularBattleQuizCard(context),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildRegularOfferwallsCard(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
        ],

        // ================= 2. DAILY CHALLENGE & SURVEYS =================
        if (dailyChallengeWidget != null) ...[
          dailyChallengeWidget!,
          SizedBox(height: 18.h),
          SurveysSection(
            userId: userId,
            email: email,
            country: country,
          ),
          SizedBox(height: 20.h),
        ],

        // ================= 3. ALL OFFERS (2x2 GRID) =================
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
                'All Offers',
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

        // All Offers 2x2 Grid
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: [
              // Top Row: Watch & Earn (Left) & Play & Earn (Right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildWatchAndEarnCard(context),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildPlayAndEarnCard(context),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Bottom Row: Daily Check-In (Left) & Read & Earn (Right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildDailyCheckInCard(context),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildReadAndEarnCard(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),

        // 4. PlayTime Banner Card (Positioned directly below All Offers)
        _PlayTimeBannerWidget(userId: userId, email: email),
        SizedBox(height: 24.h),
      ],
    );
  }

  // ================= 1. REGULAR OFFERS (2x2 GRID CARDS) =================

  /// Card 1 (Top-Left): Play Games (Connected to Play Games / Diamond Catch)
  Widget _buildRegularPlayGamesCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('diamondCatch')) {
          _showUpcomingPopup(
            context,
            title: 'Diamond Catch Coming Soon!',
            message: 'Diamond Catch feature is currently under active development and will be available very soon.',
          );
          return;
        }
        final config = SplashService.superOfferConfig;
        AutoRouter.of(context).push(
          DiamondCatchScreenRoute(
            userId: userId,
            installGems: (config['installGems'] as num?)?.toInt() ?? 2,
            gameGems: (config['gameGems'] as num?)?.toInt() ?? 1,
            dailyGemsForInstall: (config['dailyGemsForInstall'] as num?)?.toInt() ?? 10,
            gemsRequired: (config['gemsRequired'] as num?)?.toInt() ?? 0,
          ),
        );
      },
      child: Container(
        height: 142.h,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Icons1/Group 78 (1).png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            // Top Details (Title & Subtitle) - Centered
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 14.h, left: 6.w, right: 6.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Play Games',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '& Win Coins',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFD1D5DB),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom 3D Controller Image (Properly scaled & nestled in circular glow)
            Positioned(
              bottom: 8.h,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/Icons1/pngtree-controller-3d-illustration-png-image_11477416 1 (1).png',
                  width: 72.w,
                  height: 54.h,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 2 (Top-Right): Super Offers (Connected to Super Offer)
  Widget _buildRegularSuperOffersCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('superOffer')) {
          _showUpcomingPopup(
            context,
            title: 'Super Offer Coming Soon!',
            message: 'Super Offer feature is currently under active development and will be available very soon.',
          );
          return;
        }
        AutoRouter.of(context).push(
          SuperOfferScreenRoute(userId: userId),
        );
      },
      child: Container(
        height: 142.h,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Icons1/Group 78 (1).png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 14.h, left: 6.w, right: 6.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Super Offers',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get upto 500',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFD1D5DB),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Image.asset(
                          'assets/icons/coin.png',
                          width: 11.w,
                          height: 11.w,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFBBF24),
                            size: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Bottom 3D Super Offer Treasure Box Icon
            Positioned(
              bottom: 2.h,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/Icons1/super_offer_3d.png',
                  width: 92.w,
                  height: 72.h,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 3 (Bottom-Left): Battle Quiz (Connected to Battle Arena)
  Widget _buildRegularBattleQuizCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('battleArena')) {
          _showUpcomingPopup(
            context,
            title: 'Battle Arena Coming Soon!',
            message: 'Battle Arena feature is currently under active development and will be available very soon.',
          );
          return;
        }
        AutoRouter.of(context).push(
          BattleArenaSplashScreenRoute(userId: userId, email: email),
        );
      },
      child: Container(
        height: 142.h,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Icons1/Group 78 (1).png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 14.h, left: 6.w, right: 6.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Battle Quiz',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Complete & Win',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFD1D5DB),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom 3D Battle Icon Image
            Positioned(
              bottom: 8.h,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/Icons1/battle-3d-icon-png-download-11623292 3.png',
                  width: 72.w,
                  height: 54.h,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 4 (Bottom-Right): Offerwalls (Connected to Offerwalls)
  Widget _buildRegularOfferwallsCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('offerwall')) {
          _showUpcomingPopup(
            context,
            title: 'Offerwalls Coming Soon!',
            message: 'Offerwalls feature is currently under active development and will be available very soon.',
          );
          return;
        }
        final taskOffers = OfferwallManager.getOffersByCategory(category: OfferwallCategory.task);
        AutoRouter.of(context).push(
          OfferwallScreenRoute(
            userId: userId,
            offerwallList: taskOffers,
            title: 'task-partner',
            email: email,
          ),
        );
      },
      child: Container(
        height: 142.h,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Icons1/Group 78 (1).png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 14.h, left: 6.w, right: 6.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Offerwalls',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Complete Tasks',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFD1D5DB),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom 3D Shield/Task Icon Image
            Positioned(
              bottom: 8.h,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/Icons1/pngtree-d-blue-shield-with-check-mark-in-orange-circle-icon-security-png-image_16822296 1.png',
                  width: 72.w,
                  height: 54.h,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 2. ALL OFFERS (2x2 GRID CARDS) =================

  /// Card 1 (Top-Left): Watch & Earn (Connected to Watch Video)
  Widget _buildWatchAndEarnCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('watchAndEarn')) {
          _showUpcomingPopup(
            context,
            title: 'Watch & Earn Coming Soon!',
            message: 'Watch & Earn feature is currently under active development and will be available very soon.',
          );
          return;
        }
        AutoRouter.of(context).push(
          WatchVideoScreenRoute(
            email: email,
            userId: userId,
            country: country,
          ),
        );
      },
      child: Container(
        height: 132.h,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Icons1/Frame 24 (3).png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            // Top-Left Coin Pill & Subtitle
            Positioned(
              top: 10.h,
              left: 11.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.5.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/coin.png',
                          width: 12.w,
                          height: 12.w,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFBBF24),
                            size: 12,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          '156',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Get Coins Upto',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Pill Label
            Positioned(
              left: 0,
              right: 0,
              bottom: 10.h,
              child: Center(
                child: Text(
                  'Watch & Earn',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 2 (Top-Right): Play & Earn (Connected to PlayGamesScreenRoute)
  Widget _buildPlayAndEarnCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('playGames')) {
          _showUpcomingPopup(
            context,
            title: 'Play Games Coming Soon!',
            message: 'Play Games feature is currently under active development and will be available very soon.',
          );
          return;
        }
        AutoRouter.of(context).push(
          PlayGamesScreenRoute(
            userId: userId,
          ),
        );
      },
      child: Container(
        height: 132.h,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          image: const DecorationImage(
            image: AssetImage('assets/Icons1/Frame 10.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            // 1. Background Glossy Controller Depth (196.w * 178.h behind controller)
            Positioned(
              right: -52.w,
              bottom: -58.h,
              child: Opacity(
                opacity: 0.45,
                child: Image.asset(
                  'assets/Icons1/play_earn_controller_purple_blur.png',
                  width: 196.w,
                  height: 178.h,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // 2. Purple & Cyan Ambient Glow Aura (Behind Controller in Right Corner)
            Positioned(
              right: 0.w,
              bottom: -8.h,
              child: Container(
                width: 82.w,
                height: 82.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC084FC).withValues(alpha: 0.65),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                    BoxShadow(
                      color: const Color(0xFF818CF8).withValues(alpha: 0.45),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),

            // 3. Main 3D Game Controller (140.w * 126.h - Half Hidden on Right Bottom Corner)
            Positioned(
              right: -20.w,
              bottom: -28.h,
              child: Image.asset(
                'assets/Icons1/play_earn_controller_purple.png',
                width: 140.w,
                height: 126.h,
                fit: BoxFit.contain,
              ),
            ),

            // 4. Frosted Glass Bottom Pill Layer (Tucks controller behind pill & text)
            Positioned(
              left: 9.w,
              right: 9.w,
              bottom: 6.h,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 28.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 0.8.w,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Play & Earn',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Top-Left Coin Pill & Subtitle (Always in front)
            Positioned(
              top: 10.h,
              left: 11.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.5.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/coin.png',
                          width: 12.w,
                          height: 12.w,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFBBF24),
                            size: 12,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          '156',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Get Coins Upto',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
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

  /// Card 3 (Bottom-Left): Daily Check-In (Connected to DailyCheckInPopup)
  Widget _buildDailyCheckInCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('dailyStreak') && !SplashService.isScreenEnabled('streak')) {
          _showUpcomingPopup(
            context,
            title: 'Daily Streak Coming Soon!',
            message: 'Daily Streak feature is currently under active development and will be available very soon.',
          );
          return;
        }
        DailyCheckInPopup.show(
          context: context,
          streak: streak,
          streakClaimed: streakClaimed,
          userId: userId,
          coins: coins.toInt(),
        );
      },
      child: Container(
        height: 132.h,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Icons1/Frame 24 (4).png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            // Top-Left Coin Pill & Subtitle
            Positioned(
              top: 10.h,
              left: 11.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.5.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/coin.png',
                          width: 12.w,
                          height: 12.w,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFBBF24),
                            size: 12,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          '156',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Get Coins Upto',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
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

  /// Card 4 (Bottom-Right): Read & Earn (Connected to ReadTskScreenRoute)
  Widget _buildReadAndEarnCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('readTask')) {
          _showUpcomingPopup(
            context,
            title: 'Read & Earn Coming Soon!',
            message: 'Read & Earn feature is currently under active development and will be available very soon.',
          );
          return;
        }
        AutoRouter.of(context).push(
          ReadTskScreenRoute(
            userId: userId,
          ),
        );
      },
      child: Container(
        height: 132.h,
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/Icons1/Frame 25.png'),
            fit: BoxFit.fill,
          ),
        ),
        child: Stack(
          children: [
            // Top-Left Coin Pill & Subtitle
            Positioned(
              top: 10.h,
              left: 11.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.5.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/coin.png',
                          width: 12.w,
                          height: 12.w,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.monetization_on,
                            color: Color(0xFFFBBF24),
                            size: 12,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          '156',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Get Coins Upto',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Pill Label
            Positioned(
              left: 0,
              right: 0,
              bottom: 10.h,
              child: Center(
                child: Text(
                  'Read & Earn',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        offset: const Offset(0, 1),
                        blurRadius: 3,
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

  Widget _buildBattleArenaCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.96,
      onTap: () {
        if (!SplashService.isScreenEnabled('battleArena')) {
          _showUpcomingPopup(
            context,
            title: 'Battle Arena Coming Soon!',
            message: 'Battle Arena feature is currently under active development and will be available very soon.',
          );
          return;
        }
        AutoRouter.of(context).push(
          BattleArenaSplashScreenRoute(
            userId: userId,
            email: email,
          ),
        );
      },
      child: Container(
        height: 130.h,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFAB31DE).withValues(alpha: 0.22),
              const Color(0xFFE39FFF).withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              // Bottom Gradient Fade Overlay on Card
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 52.h,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),

              // Glassmorphism aura behind Panda icon
              Positioned(
                left: 0.w,
                bottom: -20.h,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: 165.w,
                      height: 165.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.38),
                            Colors.white.withValues(alpha: 0.06),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Tilted & Enlarged Panda Icon shifted rightward (with Bottom Fade)
              Positioned(
                left: -10.w,
                bottom: -32.h,
                child: Transform.rotate(
                  angle: 0.22,
                  child: SizedBox(
                    width: 185.w,
                    height: 185.w,
                    child: Hero(
                      tag: 'battle_ninja_lottie',
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            colors: [
                              Colors.black,
                              Colors.black,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.55, 0.95],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          'assets/icons/battle.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/icons/battle game.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.sports_esports_rounded,
                              color: const Color(0xFFC084FC),
                              size: 54.w,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Right Section: Title & Subtitle details (Positioned next to Panda icon)
              Positioned(
                left: 148.w,
                top: 18.h,
                right: 12.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Battle Panda',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Enter the arena & win epic battles',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Play Now Button - Flush to Right edge like Crazyreward card
              Positioned(
                right: 0,
                bottom: 12.h,
                child: _PopScaleButton(
                  onTap: () {
                    if (!SplashService.isScreenEnabled('battleArena')) {
                      _showUpcomingPopup(
                        context,
                        title: 'Battle Arena Coming Soon!',
                        message: 'Battle Arena feature is currently under active development and will be available very soon.',
                      );
                      return;
                    }
                    AutoRouter.of(context).push(
                      BattleArenaSplashScreenRoute(
                        userId: userId,
                        email: email,
                      ),
                    );
                  },
                  child: Container(
                    width: 124.w,
                    padding: EdgeInsets.only(right: 14.w, left: 20.w, top: 7.h, bottom: 7.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(-2, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Play Now',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF89009E),
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: const Color(0xFFAB31DE),
                          size: 13.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Upcoming Badge
              if (!SplashService.isScreenEnabled('battleArena'))
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'UPCOMING',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 7.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayGamesSlantedCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('playGames')) {
          _showUpcomingPopup(
            context,
            title: 'Play Games Coming Soon!',
            message: 'Play Games feature is currently under active development and will be available very soon.',
          );
          return;
        }
        AutoRouter.of(context).push(
          PlayGamesScreenRoute(userId: userId),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 148.h,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  const Color(0xFF10B981).withValues(alpha: 0.15),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(22.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 52.h),

                    // Title
                    Text(
                      'Play Games',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2.h),

                    // Subtitle
                    Text(
                      'Play & earn coins',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.15,
                      ),
                    ),
                    const Spacer(),

                    // Centered Circular Action Button with Pop Effect
                    Center(
                      child: _PopScaleButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (!SplashService.isScreenEnabled('playGames')) {
                            _showUpcomingPopup(
                              context,
                              title: 'Play Games Coming Soon!',
                              message: 'Play Games feature is currently under active development and will be available very soon.',
                            );
                            return;
                          }
                          AutoRouter.of(context).push(
                            PlayGamesScreenRoute(userId: userId),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-2.5, -2.5),
                              ),
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.18),
                                blurRadius: 6,
                                offset: const Offset(2.5, 2.5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Play',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF89009E),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 12.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ),

          // Floating Graphic (Play Games Joystick) centered half-inside, half-outside
          Positioned(
            top: -52.h,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 148.w,
                height: 148.w,
                child: Hero(
                  tag: 'play_games_slanted_banner_hero',
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                        ],
                        stops: [0.0, 0.32, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Lottie.asset(
                      'assets/icons/weplay.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/icons/playtimegame.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.sports_esports_rounded,
                          color: const Color(0xFFC084FC),
                          size: 42.w,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchVideoSlantedCard(BuildContext context) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!SplashService.isScreenEnabled('watchAndEarn')) {
          _showUpcomingPopup(
            context,
            title: 'Watch & Earn Coming Soon!',
            message: 'Watch & Earn feature is currently under active development and will be available very soon.',
          );
          return;
        }
        AutoRouter.of(context).push(
          WatchVideoScreenRoute(
            email: email,
            userId: userId,
            country: country,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 148.h,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  const Color(0xFFF59E0B).withValues(alpha: 0.15),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(22.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 52.h),

                    // Title
                    Text(
                      'Watch Video',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2.h),

                    // Subtitle
                    Text(
                      'Watch & earn coins',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 8.5.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.15,
                      ),
                    ),
                    const Spacer(),

                    // Centered Circular Action Button with Pop Effect
                    Center(
                      child: _PopScaleButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (!SplashService.isScreenEnabled('watchAndEarn')) {
                            _showUpcomingPopup(
                              context,
                              title: 'Watch & Earn Coming Soon!',
                              message: 'Watch & Earn feature is currently under active development and will be available very soon.',
                            );
                            return;
                          }
                          AutoRouter.of(context).push(
                            WatchVideoScreenRoute(
                              email: email,
                              userId: userId,
                              country: country,
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              const BoxShadow(
                                color: Colors.white,
                                blurRadius: 6,
                                offset: Offset(-2.5, -2.5),
                              ),
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.18),
                                blurRadius: 6,
                                offset: const Offset(2.5, 2.5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Watch',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF89009E),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 12.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ),

          // Floating Graphic (Video Player) centered half-inside, half-outside
          Positioned(
            top: -36.h,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 108.w,
                height: 108.w,
                child: Hero(
                  tag: 'watch_video_banner_slanted_hero',
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                        ],
                        stops: [0.0, 0.32, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Lottie.asset(
                      'assets/icons/Audio And Video Animation.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/icons/watch video.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.play_circle_filled_rounded,
                          color: const Color(0xFFC084FC),
                          size: 48.w,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpcomingPopup(
    BuildContext context, {
    required String title,
    String? message,
  }) {
    CustomStatusPopup.showComingSoon(
      context: context,
      title: title,
      message: message ?? '$title feature is currently under active development and will be available very soon.',
    );
  }
}

class _ShimmeringTitle extends StatefulWidget {
  final String text;
  final double fontSize;
  final List<Color> colors;

  const _ShimmeringTitle({
    required this.text,
    required this.fontSize,
    required this.colors,
  });

  @override
  State<_ShimmeringTitle> createState() => _ShimmeringTitleState();
}

class _ShimmeringTitleState extends State<_ShimmeringTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
        final double value = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment(value * 3.6 - 1.8, 0),
              end: Alignment(value * 3.6 - 0.6, 0),
              colors: widget.colors,
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: widget.fontSize.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerCardWrapper extends StatefulWidget {
  final Widget child;
  const _ShimmerCardWrapper({required this.child});

  @override
  State<_ShimmerCardWrapper> createState() => _ShimmerCardWrapperState();
}

class _ShimmerCardWrapperState extends State<_ShimmerCardWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
        return widget.child;
      },
    );
  }
}


class _GlossyActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final IconData icon;

  const _GlossyActionButton({
    required this.label,
    required this.onTap,
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
    required this.icon,
  });

  @override
  State<_GlossyActionButton> createState() => _GlossyActionButtonState();
}

class _GlossyActionButtonState extends State<_GlossyActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: SizedBox(
          width: double.infinity,
          height: 36.h,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Skewed Glossy Glowing Button Base
              Positioned.fill(
                child: Transform(
                  transform: Matrix4.skewX(-0.16),
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: widget.borderColor,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.shadowColor.withValues(
                            alpha: _isPressed ? 0.25 : 0.55,
                          ),
                          blurRadius: _isPressed ? 6 : 12,
                          spreadRadius: _isPressed ? 0 : 1,
                          offset: Offset(0, _isPressed ? 2 : 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: const CustomPaint(
                      painter: _GlossyButtonOverlayPainter(),
                    ),
                  ),
                ),
              ),

              // 2. Center Content (Icon + Text)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 13.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    widget.label,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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

class _GlossyButtonOverlayPainter extends CustomPainter {
  const _GlossyButtonOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Top sweeping curved glass reflection
    final wavePath = Path();
    wavePath.moveTo(0, 0);
    wavePath.lineTo(w, 0);
    wavePath.lineTo(w, h * 0.36);
    wavePath.cubicTo(
      w * 0.70, h * 0.46,
      w * 0.35, h * 0.68,
      0, h * 0.42,
    );
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.68));

    canvas.drawPath(wavePath, wavePaint);

    // 2. Top-left oval bright specular reflection dot / pill
    final dotRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(20.w, 4.5.h, 18.w, 5.h),
      Radius.circular(3.r),
    );
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90);
    canvas.drawRRect(dotRect, dotPaint);

    // 3. Bottom-right subtle reflection crescent
    final bottomPath = Path();
    bottomPath.moveTo(w * 0.65, h);
    bottomPath.cubicTo(
      w * 0.80, h * 0.85,
      w * 0.92, h * 0.80,
      w, h * 0.68,
    );
    bottomPath.lineTo(w, h);
    bottomPath.close();

    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(w * 0.65, h * 0.68, w * 0.35, h * 0.32));

    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _GlossyButtonOverlayPainter oldDelegate) => false;
}







class _PopScaleButton extends StatefulWidget {
  const _PopScaleButton({
    required this.onTap,
    required this.child,
    this.scaleDown = 0.92,
  });

  final VoidCallback onTap;
  final Widget child;
  final double scaleDown;

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOutBack,
        child: widget.child,
      ),
    );
  }
}

class _PlayTimeBannerWidget extends HookWidget {
  const _PlayTimeBannerWidget({
    required this.userId,
    required this.email,
  });

  final String userId;
  final String email;

  @override
  Widget build(BuildContext context) {
    if (SplashService.isScreenHidden('playTime') || SplashService.isScreenHidden('playtime')) {
      return const SizedBox.shrink();
    }
    final config = SplashService.playtimeConfig;
    final String targetName = (config['offerwallName'] ??
            config['taskName'] ??
            config['provider'] ??
            'playtimeAds')
        .toString()
        .trim();

    final OfferwallProvider? targetProvider = useMemoized(() {
      if (targetName.isEmpty) return null;

      final allOffers = [
        ...OfferwallManager.getOffersByCategory(category: OfferwallCategory.task),
        ...OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey),
      ];
      for (final provider in allOffers) {
        final cleanP = provider.name
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('-', '')
            .replaceAll('_', '');
        final cleanT = targetName
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('-', '')
            .replaceAll('_', '');
        if (cleanP == cleanT) {
          return provider;
        }
      }

      final fallbackProvider = OfferwallManager.getProviderByName(targetName);
      if (fallbackProvider != null) {
        final modelConfig = OffersDataModel.fromMap(config);
        fallbackProvider.attachConfig(modelConfig);
        fallbackProvider.enabled = modelConfig.enabled;
        return fallbackProvider;
      }

      return null;
    }, [targetName, config]);

    final String title = (config['title'] ?? 'PlayTime').toString();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: _PopScaleButton(
        scaleDown: 0.96,
        onTap: () async {
          HapticFeedback.lightImpact();
          if (targetProvider != null) {
            if (config.isNotEmpty) {
              final modelConfig = OffersDataModel.fromMap(config);
              targetProvider.attachConfig(modelConfig);
              targetProvider.enabled = modelConfig.enabled;
            }
            await targetProvider.init(userId: userId);
            if (!context.mounted) return;
            await targetProvider.show(
              context: context,
              userId: userId,
              email: email,
            );
          } else {
            final playtimeProvider =
                OfferwallManager.getProviderByName('Playtime Ads') ??
                    PlaytimeAdsTaskProvider();
            if (config.isNotEmpty) {
              final modelConfig = OffersDataModel.fromMap(config);
              playtimeProvider.attachConfig(modelConfig);
            }
            await playtimeProvider.init(userId: userId);
            if (!context.mounted) return;
            await playtimeProvider.show(
              context: context,
              userId: userId,
              email: email,
            );
          }
        },
        child: Container(
          width: double.infinity,
          height: 96.h,
          clipBehavior: Clip.antiAlias,
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
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 1. Soft white translucent circular backdrop on left
              Positioned(
                left: -15.w,
                top: -12.h,
                bottom: -12.h,
                width: 120.w,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // 2. Foreground Content: Left Icon + Center Text & Tag + Right Action Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Row(
                  children: [
                    // 3D PlayTime Game Icon
                    SizedBox(
                      width: 84.w,
                      height: 76.h,
                      child: Center(
                        child: Image.asset(
                          'assets/icons/gamesplaytime.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/icons/playtimegame.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),

                    // Title & Subtitle Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16.5.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              // Coin / Minute Tag matching Dark Theme
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.w,
                                  vertical: 1.5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E2E38),
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(
                                    color: const Color(0xFF3E3E4C),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/icons/coin.png',
                                      width: 9.w,
                                      height: 9.w,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.monetization_on,
                                        color: Color(0xFFFBBF24),
                                        size: 9,
                                      ),
                                    ),
                                    SizedBox(width: 2.5.w),
                                    Text(
                                      'Per Min',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFBBF24),
                                        fontSize: 7.8.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            'Play games & earn coins per minute',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF9E9EA7),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // Right Silver Metallic Action Circle Button
                    Container(
                      width: 28.h,
                      height: 28.h,
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
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: const Color(0xFF16161A),
                          size: 14.sp,
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

class _LeftToRightShimmerSheen extends HookWidget {
  const _LeftToRightShimmerSheen({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ctrl = useAnimationController(
      duration: const Duration(milliseconds: 2400),
    );

    useEffect(() {
      ctrl.repeat();
      return null;
    }, [ctrl]);

    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final value = ctrl.value;
        return ShaderMask(
          blendMode: BlendMode.srcOver,
          shaderCallback: (bounds) {
            final double startX = (value * 2.5 - 0.75) * bounds.width;
            final double endX = startX + bounds.width * 0.45;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.05),
                Colors.transparent,
              ],
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
            ).createShader(Rect.fromLTRB(startX, 0, endX, bounds.height));
          },
          child: child,
        );
      },
      child: child,
    );
  }
}





