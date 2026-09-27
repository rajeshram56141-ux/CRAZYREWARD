import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../widgets/common/custom_toast.dart';
import '../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../b_splash_stage/splash_service.dart';
import 'model/offerwall_data_model.dart';
import 'provider/offerwall_manager.dart';
import 'provider/offerwall_provider.dart';

class OfferwallTheme {
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final String bgAsset;
  final double bgAssetSize;

  const OfferwallTheme({
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.bgAsset,
    this.bgAssetSize = 100,
  });
}

OfferwallTheme getOfferwallTheme(String name) {
  final cleanName = name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
  switch (cleanName) {
    case 'tapjoy':
      return const OfferwallTheme(
        primaryColor: Color(0xFFE22119),
        backgroundColor: Color(0xFFFDECE9),
        borderColor: Color(0xFFF88E6D),
        bgAsset: 'assets/icons/tapjoy-logo.png',
        bgAssetSize: 120,
      );
    case 'sushiads':
      return const OfferwallTheme(
        primaryColor: Color(0xFFFF3B30),
        backgroundColor: Color(0xFFFFF3E0),
        borderColor: Color(0xFFFF8A65),
        bgAsset: 'assets/icons/sushiads-logo.png',
        bgAssetSize: 130,
      );
    case 'notik':
    case 'notikme':
      return const OfferwallTheme(
        primaryColor: Color(0xFF009688),
        backgroundColor: Color(0xFFE0F2F1),
        borderColor: Color(0xFF4DB6AC),
        bgAsset: 'assets/icons/notik-logo.png',
        bgAssetSize: 120,
      );
    case 'cpidroid':
      return const OfferwallTheme(
        primaryColor: Color(0xFF689F38),
        backgroundColor: Color(0xFFF1F8E9),
        borderColor: Color(0xFF9CCC65),
        bgAsset: 'assets/icons/cpidroid-logo.png',
        bgAssetSize: 130,
      );
    case 'taskwall':
      return const OfferwallTheme(
        primaryColor: Color(0xFF007AFF),
        backgroundColor: Color(0xFFE1F5FE),
        borderColor: Color(0xFF64B5F6),
        bgAsset: 'assets/icons/taskwall-logo.png',
        bgAssetSize: 120,
      );
    case 'adjoe':
      return const OfferwallTheme(
        primaryColor: Color(0xFF5856D6),
        backgroundColor: Color(0xFFEDE7F6),
        borderColor: Color(0xFF9575CD),
        bgAsset: 'assets/icons/adjoe-logo.png',
        bgAssetSize: 160,
      );
    case 'pubscale':
      return const OfferwallTheme(
        primaryColor: Color(0xFF008080),
        backgroundColor: Color(0xFFE0F2F1),
        borderColor: Color(0xFF4DB6AC),
        bgAsset: 'assets/icons/pubscale-logo.png',
        bgAssetSize: 130,
      );
    case 'timewall':
      return const OfferwallTheme(
        primaryColor: Color(0xFF1565C0),
        backgroundColor: Color(0xFFE3F2FD),
        borderColor: Color(0xFF64B5F6),
        bgAsset: 'assets/icons/timewall-logo.png',
        bgAssetSize: 130,
      );
    case 'wannads':
      return const OfferwallTheme(
        primaryColor: Color(0xFFEF6C00),
        backgroundColor: Color(0xFFFFF3E0),
        borderColor: Color(0xFFFFB74D),
        bgAsset: 'assets/icons/wannads-logo.png',
        bgAssetSize: 130,
      );
    case 'bitlabs':
      return const OfferwallTheme(
        primaryColor: Color(0xFF0277BD),
        backgroundColor: Color(0xFFE1F5FE),
        borderColor: Color(0xFF4FC3F7),
        bgAsset: 'assets/icons/bitlabs-logo.png',
        bgAssetSize: 130,
      );
    case 'cpxresearch':
      return const OfferwallTheme(
        primaryColor: Color(0xFF0288D1),
        backgroundColor: Color(0xFFE1F5FE),
        borderColor: Color(0xFF4FC3F7),
        bgAsset: 'assets/icons/cpxresearch-logo.png',
        bgAssetSize: 130,
      );
    case 'lootably':
      return const OfferwallTheme(
        primaryColor: Color(0xFFC62828),
        backgroundColor: Color(0xFFFFEBEE),
        borderColor: Color(0xFFE57373),
        bgAsset: 'assets/icons/lootably-logo.png',
        bgAssetSize: 130,
      );
    case 'growdeck':
      return const OfferwallTheme(
        primaryColor: Color(0xFF37474F),
        backgroundColor: Color(0xFFECEFF1),
        borderColor: Color(0xFF90A4AE),
        bgAsset: 'assets/icons/growdeck-logo.png',
        bgAssetSize: 130,
      );
    case 'playtimeads':
      return const OfferwallTheme(
        primaryColor: Color(0xFF6A1B9A),
        backgroundColor: Color(0xFFF3E5F5),
        borderColor: Color(0xFFBA68C8),
        bgAsset: 'assets/icons/playtimeads-logo.png',
        bgAssetSize: 130,
      );
    case 'theoremreach':
      return const OfferwallTheme(
        primaryColor: Color(0xFF3F51B5),
        backgroundColor: Color(0xFFE8EAF6),
        borderColor: Color(0xFFC5CAE9),
        bgAsset: 'assets/icons/theoremreach-logo.png',
        bgAssetSize: 130,
      );
    default:
      return const OfferwallTheme(
        primaryColor: Color(0xFF38BDF8),
        backgroundColor: Color(0xFFFFF2EC),
        borderColor: Color(0xFF38BDF8),
        bgAsset: 'assets/icons/suprerofferdhn.png',
        bgAssetSize: 120,
      );
  }
}

String getOfferwallSubtitle(String name) {
  final clean = name.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '');
  switch (clean) {
    case 'cpxresearch':
      return 'Answer surveys & earn instant rewards';
    case 'timewall':
      return 'Complete quick tasks & collect coins';
    case 'bitlabs':
      return 'Share your opinion & earn big coins';
    case 'pubscale':
      return 'Play new games and complete offers';
    case 'notik':
    case 'notikme':
      return 'Install apps & get instant rewards';
    case 'taskwall':
      return 'Complete easy tasks & earn daily coins';
    case 'sushiads':
      return 'Explore top games & earn rewards';
    case 'cpidroid':
      return 'Download apps & claim coin bonuses';
    case 'theoremreach':
      return 'High paying surveys with daily bonus';
    case 'wannads':
      return 'Browse exclusive apps & survey offers';
    case 'lootably':
      return 'Watch videos, surveys & exciting offers';
    case 'growdeck':
      return 'Complete quick quizzes & earn coins';
    case 'playtimeads':
    case 'playtime':
      return 'Play games every minute & earn coins';
    case 'tapjoy':
      return 'Unlock rewards with top game offers';
    default:
      return 'Complete offers & collect instant coins';
  }
}

@RoutePage()
class OfferwallScreen extends HookConsumerWidget {
  const OfferwallScreen({
    super.key,
    required this.userId,
    required this.offerwallList,
    required this.title,
    required this.email,
  });

  final String userId;
  final List<OfferwallProvider> offerwallList;
  final String title;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final topPadding = MediaQuery.of(context).padding.top;

    useEffect(() {
      Future.microtask(() {
        ref.invalidate(SplashService.appDataProvider);
      });
      return null;
    }, const []);

    ref.watch(SplashService.appDataProvider);

    final currentList = title.toLowerCase().contains('task')
        ? OfferwallManager.getOffersByCategory(category: OfferwallCategory.task)
        : OfferwallManager.getOffersByCategory(category: OfferwallCategory.survey);

    final isTaskScreen = title.toLowerCase().contains('task');
    final screenTitle = title.tr() == title
        ? (isTaskScreen ? 'Task Partners' : 'Survey Partners')
        : title.tr();

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
            // 1. Solid Clean White Background
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Main Feed
            Positioned.fill(
              child: Column(
                children: [
                  // Executive Top Header Bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      topPadding + 8.h,
                      16.w,
                      14.h,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Executive Back Arrow + Screen Title
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
                                  borderRadius: BorderRadius.circular(15.r),
                                  border: Border.all(
                                    color: const Color(0xFFF1F5F9),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: const Color(0xFFAB31DE),
                                  size: 22.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),

                            Text(
                              screenTitle,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 18.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),

                        // Right: Executive "How To?" Pill Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            LaunchUrl.inWeb(
                              url: isTaskScreen
                                  ? SplashService.getTutorialUrl('offerwall', SplashService.urlConfig.taskTutorial)
                                  : SplashService.getTutorialUrl('survey', SplashService.urlConfig.surveyTutorial),
                              context: context,
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: const Color(0xFFE39FFF).withValues(alpha: 0.6),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.help_outline_rounded,
                                  color: const Color(0xFFAB31DE),
                                  size: 14.sp,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  'How To?',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFAB31DE),
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
                  ),

                  // Screen Banner (Admin Configurable 700x200 with AD badge)
                  const ScreenBannerWidget(
                    screenKey: 'offerwallScreen',
                    margin: EdgeInsets.only(left: 14, right: 14, bottom: 8),
                  ),

                  // 2 Cards Per Row Grid
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(SplashService.appDataProvider);
                        try {
                          await ref.read(SplashService.appDataProvider.future);
                        } catch (_) {}
                      },
                      color: const Color(0xFFAB31DE),
                      backgroundColor: Colors.white,
                      child: GridView.builder(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 40.h),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12.h,
                          crossAxisSpacing: 10.w,
                          childAspectRatio: 1.42,
                        ),
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final OfferwallProvider offerwall = currentList[index];
                          return OfferwallExecutiveCard(
                            offerwall: offerwall,
                            userId: userId,
                            email: email,
                            index: index,
                            isSurvey: !isTaskScreen,
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

// -----------------------------------------------------------------------------
// EXECUTIVE 2-CARD WIDE HORIZONTAL OFFERWALL CARD
// -----------------------------------------------------------------------------
class OfferwallExecutiveCard extends HookWidget {
  const OfferwallExecutiveCard({
    super.key,
    required this.offerwall,
    required this.userId,
    required this.email,
    required this.index,
    required this.isSurvey,
  });

  final OfferwallProvider offerwall;
  final String userId;
  final String email;
  final int index;
  final bool isSurvey;

  @override
  Widget build(BuildContext context) {
    final isPressed = useState(false);
    final theme = getOfferwallTheme(offerwall.name);
    final palette = _themePalettes[index % _themePalettes.length];
    final subtitle = getOfferwallSubtitle(offerwall.name);
    final isLocked = !offerwall.enabled;

    String displayName = offerwall.name;
    if (displayName.toLowerCase() == 'sushiads') {
      displayName = 'Sushi Ads';
    } else if (displayName.toLowerCase() == 'notik') {
      displayName = 'Notikme';
    } else if (displayName.toLowerCase() == 'cpidroid') {
      displayName = 'Cpi Droid';
    } else if (displayName.toLowerCase() == 'taskwall') {
      displayName = 'Task Wall';
    } else if (displayName.toLowerCase() == 'theoremreach') {
      displayName = 'Theorem Reach';
    } else if (displayName.toLowerCase() == 'cpxresearch') {
      displayName = 'CPX Research';
    } else if (displayName.toLowerCase() == 'timewall') {
      displayName = 'Timewall';
    } else if (displayName.toLowerCase() == 'bitlabs') {
      displayName = 'BitLabs';
    } else if (displayName.toLowerCase() == 'pubscale') {
      displayName = 'PubScale';
    }

    return GestureDetector(
      onTapDown: (_) {
        if (offerwall.enabled) {
          isPressed.value = true;
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) async {
        if (offerwall.enabled) {
          isPressed.value = false;
          HapticFeedback.lightImpact();
          await offerwall.show(
            context: context,
            userId: userId,
            email: email,
          );
        } else {
          HapticFeedback.vibrate();
          CustomToast.showToast(context, msg: 'offerwall-locked'.tr());
        }
      },
      onTapCancel: () {
        isPressed.value = false;
      },
      child: AnimatedScale(
        scale: isPressed.value ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: palette.accentArrowColor.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: Stack(
              children: [
                // 1. Right Pastel Outer Glow Layer
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 78.w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.outerGlowColor.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(70.r),
                        bottomLeft: Radius.circular(70.r),
                        topRight: Radius.circular(18.r),
                        bottomRight: Radius.circular(18.r),
                      ),
                    ),
                  ),
                ),

                // 2. Right Pastel Inner Arch Dome Layer
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 66.w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.innerDomeColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(80.r),
                        bottomLeft: Radius.circular(70.r),
                        topRight: Radius.circular(18.r),
                        bottomRight: Radius.circular(18.r),
                      ),
                    ),
                  ),
                ),

                // 3. Right Side Offerwall Specific Brand Logo Image (Replaces Panda Icon!)
                Positioned(
                  right: 4.w,
                  top: 0,
                  bottom: 0,
                  width: 58.w,
                  child: Center(
                    child: (offerwall.config?.iconUrl.isNotEmpty ?? false)
                        ? Image.network(
                            offerwall.config!.iconUrl,
                            height: 48.h,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Image.asset(
                              offerwall.logoImage,
                              height: 48.h,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Image.asset(
                                theme.bgAsset,
                                height: 48.h,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.local_offer_rounded,
                                  color: palette.accentArrowColor,
                                  size: 32.sp,
                                ),
                              ),
                            ),
                          )
                        : Image.asset(
                            offerwall.logoImage,
                            height: 48.h,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Image.asset(
                              theme.bgAsset,
                              height: 48.h,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.local_offer_rounded,
                                color: palette.accentArrowColor,
                                size: 32.sp,
                              ),
                            ),
                          ),
                  ),
                ),

                // 4. Foreground Content Layout (Un-truncated Name & Subtitle + Arrow CTA)
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 10.h, 8.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Small Logo Container + Title & Subtitle Column
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Small Logo Container
                          Container(
                            width: 32.w,
                            height: 32.w,
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: palette.logoBadgeBg,
                              borderRadius: BorderRadius.circular(9.r),
                              border: Border.all(
                                color: palette.outerGlowColor,
                                width: 0.8,
                              ),
                            ),
                            child: (offerwall.config?.iconUrl.isNotEmpty ?? false)
                                ? Image.network(
                                    offerwall.config!.iconUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      offerwall.logoImage,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                        theme.bgAsset,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.grid_view_rounded,
                                          color: palette.accentArrowColor,
                                          size: 16.w,
                                        ),
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    offerwall.logoImage,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      theme.bgAsset,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.grid_view_rounded,
                                        color: palette.accentArrowColor,
                                        size: 16.w,
                                      ),
                                    ),
                                  ),
                          ),

                          SizedBox(width: 6.w),

                          // Full Un-truncated Title & Subtitle Column
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: 36.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF1E1B4B),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF64748B),
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w400,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Bottom Row: Arrow Circle Button
                      Container(
                        width: 24.w,
                        height: 24.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: offerwall.enabled
                                ? palette.outerGlowColor
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: palette.accentArrowColor.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            offerwall.enabled
                                ? Icons.arrow_forward_rounded
                                : Icons.lock_rounded,
                            color: offerwall.enabled ? palette.accentArrowColor : const Color(0xFF94A3B8),
                            size: 13.sp,
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
      ),
    );
  }
}

// Unique Pastel Color Palette for Each Card
class _CardThemePalette {
  final Color outerGlowColor;
  final Color innerDomeColor;
  final Color logoBadgeBg;
  final Color accentArrowColor;

  const _CardThemePalette({
    required this.outerGlowColor,
    required this.innerDomeColor,
    required this.logoBadgeBg,
    required this.accentArrowColor,
  });
}

final List<_CardThemePalette> _themePalettes = const [
  // 1. Purple Lavender Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFF3E8FF),
    innerDomeColor: Color(0xFFF0E5FF),
    logoBadgeBg: Color(0xFFF8F5FF),
    accentArrowColor: Color(0xFF9333EA),
  ),
  // 2. Soft Sky Blue Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFE0F2FE),
    innerDomeColor: Color(0xFFBAE6FD),
    logoBadgeBg: Color(0xFFF0F9FF),
    accentArrowColor: Color(0xFF0284C7),
  ),
  // 3. Golden Amber Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFFEF3C7),
    innerDomeColor: Color(0xFFFDE68A),
    logoBadgeBg: Color(0xFFFFFBEB),
    accentArrowColor: Color(0xFFD97706),
  ),
  // 4. Rose Pink Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFFCE7F3),
    innerDomeColor: Color(0xFFFBCFE8),
    logoBadgeBg: Color(0xFFFDF2F8),
    accentArrowColor: Color(0xFFDB2777),
  ),
  // 5. Mint Emerald Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFD1FAE5),
    innerDomeColor: Color(0xFFA7F3D0),
    logoBadgeBg: Color(0xFFECFDF5),
    accentArrowColor: Color(0xFF059669),
  ),
  // 6. Indigo Violet Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFE0E7FF),
    innerDomeColor: Color(0xFFC7D2FE),
    logoBadgeBg: Color(0xFFEEF2FF),
    accentArrowColor: Color(0xFF4F46E5),
  ),
  // 7. Peach Coral Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFFFEDD5),
    innerDomeColor: Color(0xFFFED7AA),
    logoBadgeBg: Color(0xFFFFF7ED),
    accentArrowColor: Color(0xFFEA580C),
  ),
];
