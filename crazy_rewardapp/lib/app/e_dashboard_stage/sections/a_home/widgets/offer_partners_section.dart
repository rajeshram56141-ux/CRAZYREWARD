import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../widgets/common/custom_toast.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../offerwall/model/offerwall_data_model.dart';
import '../offerwall/provider/offerwall_manager.dart';
import '../offerwall/provider/offerwall_provider.dart';

class OfferPartnersSection extends HookConsumerWidget {
  const OfferPartnersSection({
    super.key,
    required this.userId,
    required this.email,
    required this.country,
  });

  final String userId;
  final String email;
  final String country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appDataAsync = ref.watch(SplashService.appDataProvider);
    final bool isOfferwallHidden = SplashService.isScreenHidden('offerwall');
    final bool isSurveyHidden = SplashService.isScreenHidden('survey');

    final surveyOffers = useMemoized<List<OfferwallProvider>>(
      () {
        final list = List<OfferwallProvider>.from(
          OfferwallManager.getOffersByCategory(
            category: OfferwallCategory.survey,
          ),
        );
        return list;
      },
      [appDataAsync],
    );

    final taskOffers = useMemoized<List<OfferwallProvider>>(
      () {
        final list = List<OfferwallProvider>.from(
          OfferwallManager.getOffersByCategory(
            category: OfferwallCategory.task,
          ),
        );
        return list;
      },
      [appDataAsync],
    );

    final bool hasEnabledOfferwalls = taskOffers.any((e) => e.enabled);
    final bool hasEnabledSurveys = surveyOffers.any((e) => e.enabled);

    final bool isOfferwallActive = !isOfferwallHidden && hasEnabledOfferwalls;
    final bool isSurveyActive = !isSurveyHidden && hasEnabledSurveys;

    if (!isOfferwallActive && !isSurveyActive) {
      return const SizedBox.shrink();
    }

    final selectedFilterIndex = useState<int>(!isOfferwallActive && isSurveyActive ? 1 : 0); // 0: Offerwalls, 1: Surveys
    final currentPageIndex = useState<int>(0);

    // Keep filter selection synchronized with active states
    useEffect(() {
      if (selectedFilterIndex.value == 1 && !isSurveyActive) {
        selectedFilterIndex.value = 0;
        currentPageIndex.value = 0;
      } else if (selectedFilterIndex.value == 0 && !isOfferwallActive) {
        selectedFilterIndex.value = 1;
        currentPageIndex.value = 0;
      }
      return null;
    }, [isOfferwallActive, isSurveyActive]);
    
    // Unbounded infinite PageController starting at page 5000
    final pageController = usePageController(initialPage: 5000, viewportFraction: 0.88);

    // Filter displayed list based on selected category tab (0: Offerwalls, 1: Surveys)
    // Limits to TOP 5 cards: enabled items first
    final List<_QuickOfferItem> displayedOffers = useMemoized<List<_QuickOfferItem>>(() {
      final List<_QuickOfferItem> items = [];

      if (selectedFilterIndex.value == 0 && isOfferwallActive) {
        for (final offer in taskOffers) {
          if (offer.enabled) {
            items.add(_QuickOfferItem(
              offer: offer,
              categoryLabel: 'OFFERWALL',
            ));
          }
        }
      } else if (selectedFilterIndex.value == 1 && isSurveyActive) {
        for (final offer in surveyOffers) {
          if (offer.enabled) {
            items.add(_QuickOfferItem(
              offer: offer,
              categoryLabel: 'SURVEY',
            ));
          }
        }
      }

      return items.take(5).toList();
    }, [taskOffers, surveyOffers, isOfferwallActive, isSurveyActive, selectedFilterIndex.value]);

    if (displayedOffers.isEmpty) {
      return const SizedBox.shrink();
    }

    // True Unbounded Forward Auto-Scroll Timer (Always slides forward to the right)
    useEffect(() {
      if (displayedOffers.length <= 1) return null;

      final timer = Timer.periodic(const Duration(seconds: 3, milliseconds: 500), (_) {
        if (pageController.hasClients && displayedOffers.isNotEmpty) {
          final double currentPos = pageController.page ?? 5000.0;
          final int nextPage = currentPos.floor() + 1;
          pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeInOutCubic,
          );
        }
      });

      return timer.cancel;
    }, [displayedOffers.length, pageController, selectedFilterIndex.value]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Row: Title on Left + Context-Aware "View More" Button on Top-Right
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left Section Header Title
              Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFE39FFF),
                        Color(0xFFAB31DE),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ).createShader(bounds),
                    child: Icon(
                      Icons.stars_rounded,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offer Partners',
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 16.5.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Container(
                        width: 110.w,
                        height: 2.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1.r),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFAB31DE),
                              Color(0xFFE39FFF),
                              Colors.transparent,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            stops: [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Right Section: Context-Aware "View More" Pill Button
              _PopScaleButton(
                scaleDown: 0.94,
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (selectedFilterIndex.value == 0 && isOfferwallActive) {
                    await AutoRouter.of(context).push(
                      OfferwallScreenRoute(
                        userId: userId,
                        offerwallList: taskOffers,
                        title: 'task-partner',
                        email: email,
                      ),
                    );
                  } else if (selectedFilterIndex.value == 1 && isSurveyActive) {
                    await AutoRouter.of(context).push(
                      OfferwallScreenRoute(
                        userId: userId,
                        offerwallList: surveyOffers,
                        title: 'survey-partner',
                        email: email,
                      ),
                    );
                  } else if (isOfferwallActive) {
                    await AutoRouter.of(context).push(
                      OfferwallScreenRoute(
                        userId: userId,
                        offerwallList: taskOffers,
                        title: 'task-partner',
                        email: email,
                      ),
                    );
                  } else if (isSurveyActive) {
                    await AutoRouter.of(context).push(
                      OfferwallScreenRoute(
                        userId: userId,
                        offerwallList: surveyOffers,
                        title: 'survey-partner',
                        email: email,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.5.h),
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
                        'View More',
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
            ],
          ),
        ),

        SizedBox(height: 14.h),

        // 2. Category Switcher Filter Chips (Offerwalls, Surveys)
        if (isOfferwallActive && isSurveyActive) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Offerwalls',
                  isSelected: selectedFilterIndex.value == 0,
                  onTap: () {
                    selectedFilterIndex.value = 0;
                    currentPageIndex.value = 0;
                  },
                ),
                SizedBox(width: 8.w),
                _buildFilterChip(
                  label: 'Surveys',
                  isSelected: selectedFilterIndex.value == 1,
                  onTap: () {
                    selectedFilterIndex.value = 1;
                    currentPageIndex.value = 0;
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],

        // 3. Truly Unbounded Infinite Forward-Sliding PageView Carousel
        if (displayedOffers.isNotEmpty) ...[
          SizedBox(
            height: 148.h,
            child: PageView.builder(
              controller: pageController,
              onPageChanged: (index) {
                currentPageIndex.value = index % displayedOffers.length;
              },
              itemBuilder: (context, index) {
                final actualIndex = index % displayedOffers.length;
                final item = displayedOffers[actualIndex];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: _buildToroxExactOfferCard(
                    context: context,
                    item: item,
                    index: actualIndex,
                    userId: userId,
                    email: email,
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 10.h),

          // 4. Page Position Indicator Dots (Mapped seamlessly to 0..4)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(displayedOffers.length, (i) {
              final isSelected = currentPageIndex.value == i;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: isSelected ? 18.w : 6.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFAB31DE)
                      : const Color(0xFFAB31DE).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(3.r),
                ),
              );
            }),
          ),
        ] else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Center(
                child: Text(
                  'No offers available right now.',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Filter Chip Widget
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _PopScaleButton(
      scaleDown: 0.95,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFAB31DE)
              : const Color(0xFFAB31DE).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 11.5.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 1-to-1 Replica with loginicon.png Asset & Depth Blur Effect
  Widget _buildToroxExactOfferCard({
    required BuildContext context,
    required _QuickOfferItem item,
    required int index,
    required String userId,
    required String email,
  }) {
    final offer = item.offer;
    final bool isSurvey = item.categoryLabel == 'SURVEY';
    final palette = _themePalettes[index % _themePalettes.length];

    return _PopScaleButton(
      scaleDown: 0.96,
      onTap: () async {
        HapticFeedback.lightImpact();
        if (offer.enabled) {
          await offer.show(
            context: context,
            userId: userId,
            email: email,
          );
        } else {
          CustomToast.showToast(context, msg: 'Locked');
        }
      },
      child: Container(
        height: 148.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26.r),
          border: Border.all(
            color: const Color(0xFFF1F5F9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26.r),
          child: Stack(
            children: [
              // 1. Layer A: Outer Soft Dual-Tone Glow Layer (Unique Theme Color)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 172.w,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.outerGlowColor.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(110.r),
                      bottomLeft: Radius.circular(110.r),
                      topRight: Radius.circular(26.r),
                      bottomRight: Radius.circular(26.r),
                    ),
                  ),
                ),
              ),

              // 2. Layer B: Primary Solid Dome/Arch Container (Unique Theme Color)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 152.w,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.innerDomeColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(125.r),
                      bottomLeft: Radius.circular(105.r),
                      topRight: Radius.circular(26.r),
                      bottomRight: Radius.circular(26.r),
                    ),
                  ),
                ),
              ),

              // 3. Right Side 3D Graphic Artwork (panda 2.png tucked even deeper inside card)
              Positioned(
                right: -8.w,
                bottom: -22.h,
                width: 134.w,
                height: 144.h,
                child: Center(
                  child: Hero(
                    tag: 'partner_graphic_${offer.name}_${item.categoryLabel}',
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Layer 1: Sharp Upper & Middle 3D Graphic (Body, Head & Arms Sharp)
                        ShaderMask(
                          shaderCallback: (rect) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black,
                                Colors.black,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.65, 0.90],
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.dstIn,
                          child: Image.asset(
                            'assets/icons/panda 2.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              isSurvey
                                  ? Icons.assignment_turned_in_rounded
                                  : Icons.auto_awesome_rounded,
                              color: palette.accentArrowColor,
                              size: 56.w,
                            ),
                          ),
                        ),

                        // Layer 2: Subtly Blurred Feet Base of Graphic (Pushed lower)
                        ShaderMask(
                          shaderCallback: (rect) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black,
                                Colors.black,
                              ],
                              stops: [0.60, 0.85, 1.0],
                            ).createShader(rect);
                          },
                          blendMode: BlendMode.dstIn,
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
                            child: Image.asset(
                              'assets/icons/panda 2.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Left Side Content Layout (Square Logo + Title/Subtitle + Circle Arrow Button)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Logo Badge on Top, Arrow Button on Bottom
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Soft Rounded Square Logo Badge Container (Unique Theme Tint)
                        Container(
                          width: 62.w,
                          height: 62.w,
                          padding: EdgeInsets.all(9.w),
                          decoration: BoxDecoration(
                            color: palette.logoBadgeBg,
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: palette.outerGlowColor,
                              width: 1.0,
                            ),
                          ),
                          child: Image.asset(
                            offer.logoImage,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.grid_view_rounded,
                              color: palette.accentArrowColor,
                              size: 26.w,
                            ),
                          ),
                        ),

                        // Bottom-Left Circular Action Arrow Button (Unique Accent Color)
                        Container(
                          width: 38.w,
                          height: 38.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: palette.outerGlowColor,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: palette.accentArrowColor.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              offer.enabled
                                  ? Icons.arrow_forward_rounded
                                  : Icons.lock_rounded,
                              color: palette.accentArrowColor,
                              size: 18.sp,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(width: 14.w),

                    // Middle Column: Title & Subtitle
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 98.w), // Leaves room for right 3D artwork
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            SizedBox(height: 2.h),
                            Text(
                              offer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF0F172A),
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              'Complete offers\nand earn exciting\nrewards.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF64748B),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                                height: 1.25,
                              ),
                            ),
                          ],
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

// Unique Color Palette for Each Card
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
  // 2. Sky Blue Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFE0F2FE),
    innerDomeColor: Color(0xFFBAE6FD),
    logoBadgeBg: Color(0xFFF0F9FF),
    accentArrowColor: Color(0xFF0284C7),
  ),
  // 3. Emerald Mint Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFD1FAE5),
    innerDomeColor: Color(0xFFA7F3D0),
    logoBadgeBg: Color(0xFFECFDF5),
    accentArrowColor: Color(0xFF059669),
  ),
  // 4. Rose Pink Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFFCE7F3),
    innerDomeColor: Color(0xFFFBCFE8),
    logoBadgeBg: Color(0xFFFDF2F8),
    accentArrowColor: Color(0xFFDB2777),
  ),
  // 5. Golden Amber Theme
  _CardThemePalette(
    outerGlowColor: Color(0xFFFEF3C7),
    innerDomeColor: Color(0xFFFDE68A),
    logoBadgeBg: Color(0xFFFFFBEB),
    accentArrowColor: Color(0xFFD97706),
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

// Data Helper Holder
class _QuickOfferItem {
  final OfferwallProvider offer;
  final String categoryLabel;

  _QuickOfferItem({
    required this.offer,
    required this.categoryLabel,
  });
}

// Reusable Pop Scale Button with Tactile Haptic Press
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
