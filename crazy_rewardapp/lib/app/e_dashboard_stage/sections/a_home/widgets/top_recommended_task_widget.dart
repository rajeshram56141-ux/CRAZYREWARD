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

class TopRecommendedTaskWidget extends StatelessWidget {
  const TopRecommendedTaskWidget({
    super.key,
    required this.userId,
    required this.email,
    required this.country,
    this.dailyChallengeWidget,
    this.quickShortcutGridWidget,
  });

  final String userId;
  final String email;
  final String country;
  final Widget? dailyChallengeWidget;
  final Widget? quickShortcutGridWidget;

  @override
  Widget build(BuildContext context) {
    final bool hidePlayGames = SplashService.isScreenHidden('playGames');
    final bool hideSuperOffer = SplashService.isScreenHidden('superOffer');
    final bool hideBattleArena = SplashService.isScreenHidden('battleArena');
    final bool hideWatchAndEarn = SplashService.isScreenHidden('watchAndEarn');

    if (hidePlayGames && hideSuperOffer && hideBattleArena && hideWatchAndEarn) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 1. Top Slanted Pair: Crazyreward (Left) & Super Offer (Right - Super Mission)
        if (!hidePlayGames && !hideSuperOffer)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _LeftToRightShimmerSheen(
              child: Row(
                children: [
                  Expanded(
                    child: _buildCrazyrewardCard(context),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildMegaOfferCard(context),
                  ),
                ],
              ),
            ),
          )
        else if (!hidePlayGames)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _buildCrazyrewardCard(context),
          )
        else if (!hideSuperOffer)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _buildMegaOfferCard(context),
          ),

        // 2. Daily Challenge & Quick Shortcut Grid (Positioned JUST below Super Mission)
        if (dailyChallengeWidget != null) ...[
          SizedBox(height: 14.h),
          dailyChallengeWidget!,
        ],
        if (quickShortcutGridWidget != null) ...[
          SizedBox(height: 8.h),
          quickShortcutGridWidget!,
        ],

        // 3. Battle Arena Card
        if (!hideBattleArena) ...[
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: _buildBattleArenaCard(context),
          ),
        ],

        // 3. Admin PlayTime Banner Card (Positioned directly below Battle Arena)
        if (SplashService.playtimeConfig['enabled'] == true) ...[
          SizedBox(height: 16.h),
          _PlayTimeBannerWidget(userId: userId, email: email),
        ],

        // 4. New Slanted Pair below PlayTime: Play Games (Left) & Watch Video (Right)
        if (!hidePlayGames || !hideWatchAndEarn) ...[
          SizedBox(height: 44.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                if (!hidePlayGames)
                  Expanded(
                    child: _buildPlayGamesSlantedCard(context),
                  ),
                if (!hidePlayGames && !hideWatchAndEarn)
                  SizedBox(width: 12.w),
                if (!hideWatchAndEarn)
                  Expanded(
                    child: _buildWatchVideoSlantedCard(context),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMegaOfferCard(BuildContext context) {
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
        height: 148.h,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFEC4899).withValues(alpha: 0.22),
              const Color(0xFFF472B6).withValues(alpha: 0.08),
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
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            // Bottom Gradient Fade Overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 55.h,
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

            // Top Details (Title & Subtitle)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Offer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/coin.png',
                        width: 13.w,
                        height: 13.w,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.monetization_on_rounded,
                          color: const Color(0xFFF59E0B),
                          size: 13.sp,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'Upto 100K+',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF64748B),
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Glassmorphism aura behind icon
            Positioned(
              left: -20.w,
              bottom: -18.h,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 140.w,
                    height: 140.w,
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

            // Left-Bottom Icon inside Card
            Positioned(
              left: -40.w,
              bottom: -36.h,
              child: SizedBox(
                width: 190.w,
                height: 190.w,
                child: Hero(
                  tag: 'mega_offer_banner',
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
                      'assets/icons/super coin.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.star_rounded,
                        color: const Color(0xFFF472B6),
                        size: 42.w,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right-Bottom Start Button (flush to right edge, white patti fading to left)
            Positioned(
              right: 0,
              bottom: 12.h,
              child: _PopScaleButton(
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
                  width: 112.w,
                  padding: EdgeInsets.only(right: 14.w, left: 20.w, top: 7.h, bottom: 7.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16.r),
                      bottomLeft: Radius.circular(16.r),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.55),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
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
                        'Start',
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
          ],
        ),
      ),
    );
  }

  Widget _buildCrazyrewardCard(BuildContext context) {
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
        height: 148.h,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0EA5E9).withValues(alpha: 0.22),
              const Color(0xFF38BDF8).withValues(alpha: 0.08),
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
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            // Bottom Gradient Fade Overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 55.h,
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

            // Top Details (Title & Subtitle)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diamond Catch',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/gems.png',
                        width: 13.w,
                        height: 13.w,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.diamond_rounded,
                          color: const Color(0xFF38BDF8),
                          size: 13.sp,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'Upto 100K+',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF64748B),
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Glassmorphism aura behind icon
            Positioned(
              left: -15.w,
              bottom: -12.h,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    width: 130.w,
                    height: 130.w,
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

            // Left-Bottom Icon inside Card
            Positioned(
              left: -18.w,
              bottom: -16.h,
              child: SizedBox(
                width: 140.w,
                height: 140.w,
                child: Hero(
                  tag: 'crazyreward_banner',
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
                      'assets/icons/panda1.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.extension_rounded,
                        color: const Color(0xFF38BDF8),
                        size: 42.w,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right-Bottom Play Button (flush to right edge, white patti extra faded to left)
            Positioned(
              right: 0,
              bottom: 12.h,
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
                  width: 118.w,
                  padding: EdgeInsets.only(right: 14.w, left: 24.w, top: 7.h, bottom: 7.h),
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
                        'Play',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF0284C7),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: const Color(0xFF0284C7),
                        size: 13.sp,
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
    final config = SplashService.playtimeConfig;
    final bool isEnabled = config['enabled'] == true;
    final String targetName = (config['offerwallName'] ?? config['taskName'] ?? config['provider'] ?? 'playtimeAds').toString().trim();

    if (!isEnabled) {
      return const SizedBox.shrink();
    }

    final OfferwallProvider? targetProvider = useMemoized(() {
      if (targetName.isEmpty) return null;

      final allOffers = [
        ...OfferwallManager.getOffersByCategory(category: OfferwallCategory.task),
        ...OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey),
      ];
      for (final provider in allOffers) {
        final cleanP = provider.name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
        final cleanT = targetName.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
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
            await targetProvider.init(userId: userId);
            if (!context.mounted) return;
            await targetProvider.show(
              context: context,
              userId: userId,
              email: email,
            );
          } else {
            AutoRouter.of(context).push(
              SuperOfferScreenRoute(userId: userId),
            );
          }
        },
        child: Container(
          height: 130.h,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withValues(alpha: 0.22),
                const Color(0xFF6EE7B7).withValues(alpha: 0.08),
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

                // Glassmorphism aura behind PlayTime icon
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

                // Tilted & Enlarged PlayTime Icon shifted rightward (with Bottom Fade)
                Positioned(
                  left: -10.w,
                  bottom: -32.h,
                  child: Transform.rotate(
                    angle: 0.22,
                    child: SizedBox(
                      width: 185.w,
                      height: 185.w,
                      child: Hero(
                        tag: 'playtime_banner_graphic',
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
                            'assets/icons/playtimegame.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Image.asset(
                              'assets/icons/playtimegame.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.sports_esports_rounded,
                                color: const Color(0xFF10B981),
                                size: 54.w,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Right Section: Title & Subtitle details (Positioned next to icon)
                Positioned(
                  left: 148.w,
                  top: 18.h,
                  right: 12.w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        title,
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
                        'Play games & get coins per min',
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

                // Play Now Button - Flush to Right edge
                Positioned(
                  right: 0,
                  bottom: 12.h,
                  child: _PopScaleButton(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      if (targetProvider != null) {
                        await targetProvider.init(userId: userId);
                        if (!context.mounted) return;
                        await targetProvider.show(
                          context: context,
                          userId: userId,
                          email: email,
                        );
                      } else {
                        AutoRouter.of(context).push(
                          SuperOfferScreenRoute(userId: userId),
                        );
                      }
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
                              color: const Color(0xFF059669),
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: const Color(0xFF10B981),
                            size: 13.sp,
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





