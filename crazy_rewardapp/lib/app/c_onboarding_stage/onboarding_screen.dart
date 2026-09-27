// ignore_for_file: depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/local_storage.dart';
import '../../utils/helper/helper.dart';
import '../../utils/routes/routes_import.gr.dart';
import 'language_selector.dart';

class _IntroSlideData {
  final String imageAsset;
  final String tag;
  final String title;
  final String description;

  const _IntroSlideData({
    required this.imageAsset,
    required this.tag,
    required this.title,
    required this.description,
  });
}

@RoutePage()
class OnboardingScreen extends HookWidget {
  const OnboardingScreen({super.key});

  static const List<_IntroSlideData> _slides = [
    _IntroSlideData(
      imageAsset: 'assets/icons/crazy_reward_logo.png',
      tag: 'DISCOVER & PLAY',
      title: 'PLAY EXCITING\nGAMES & TASKS',
      description:
          'Explore exciting games, complete fun daily tasks, and enjoy seamless entertainment everyday!',
    ),
    _IntroSlideData(
      imageAsset: 'assets/icons/suprerofferdhn.png',
      tag: 'OFFERS & TASKS',
      title: 'SUPER OFFERS &\nGAME OFFERWALLS',
      description:
          'Complete exciting offerwalls, fun game tasks, and super offers to unlock new achievements!',
    ),
    _IntroSlideData(
      imageAsset: 'assets/icons/invite_friend_boy.png',
      tag: 'INVITE & SHARE',
      title: 'INVITE FRIENDS &\nGET BONUSES',
      description:
          'Share your referral code with your best friends and unlock exciting bonuses for every invite!',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentStep = useState<int>(0); // 0 = Language, 1 = Intro Slides
    final selectedLang = useState<String>(context.locale.languageCode);
    final introPageController = usePageController();
    final currentIntroSlide = useState<int>(0);

    useEffect(() {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFF1F5F9),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      return null;
    }, [currentStep.value]);

    final List<LanguageInfo> listToDisplay = useMemoized(
      () => orderedLanguageList(languageList, context),
      [context.locale.languageCode],
    );

    void onLanguageSelected(String code) {
      selectedLang.value = code;
    }

    void onLanguageContinue() {
      context.setLocale(Locale(selectedLang.value));
      currentStep.value = 1;
    }

    void onFinishIntro() {
      LocalStorage.setOnboardingCompleted();
      AutoRouter.of(context).replace(const AuthenticationScreenRoute());
    }

    void onNextIntroSlide() {
      if (currentIntroSlide.value < _slides.length - 1) {
        introPageController.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
        );
      } else {
        onFinishIntro();
      }
    }

    Widget buildLanguageCard(LanguageInfo lang) {
      final isSelected = selectedLang.value == lang.locale;

      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onLanguageSelected(lang.locale);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isSelected ? const Color(0xFF9333EA) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF9333EA).withValues(alpha: 0.14)
                    : const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Country Flag Circular Avatar
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFAF5FF) : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFD8B4FE) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: CountryPickerUtils.getDefaultFlagImage(
                    CountryPickerUtils.getCountryByIsoCode(
                      lang.countryCode,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14.w),

              // Language Name & Country
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${lang.languageName.tr()} (${lang.languageName.caps()})',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B2E),
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        fontSize: 14.5.sp,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      lang.countryName,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection Radio Indicator
              Container(
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFE39FFF), Color(0xFF9333EA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF9333EA).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 15.sp,
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    // Step 0: Language Selection View
    Widget buildLanguageView() {
      return SafeArea(
        child: Column(
          children: [
            // 1. Top Header Bar
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 4.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Language',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.kaushanScript(
                      color: const Color(0xFF1E1B2E),
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Choose your preferred language for the app',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14.h),

            // 2. Expanded Language Selection Cards List
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: listToDisplay.length,
                physics: const BouncingScrollPhysics(),
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  return buildLanguageCard(listToDisplay[index]);
                },
              ),
            ),

            // 3. Bottom Action Button Container
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 20.h),
              child: _EngagingShimmerActionButton(
                label: 'continue'.tr(),
                onTap: onLanguageContinue,
              ),
            ),
          ],
        ),
      );
    }

    // Step 1: Intro Walkthrough Slides View
    Widget buildIntroView() {
      final isLastSlide = currentIntroSlide.value == _slides.length - 1;

      return SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip Button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onFinishIntro();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SKIP',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF7C3AED),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11.sp,
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sliding Page Content
            Expanded(
              child: PageView.builder(
                controller: introPageController,
                itemCount: _slides.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  currentIntroSlide.value = index;
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Clean Floating Hero Illustration
                        _IntroHeroGraphicWidget(imageAsset: slide.imageAsset),

                        SizedBox(height: 18.h),

                        // Tag Pill Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: const Color(0xFFD8B4FE),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF9333EA).withValues(alpha: 0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            slide.tag,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF7C3AED),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),

                        SizedBox(height: 10.h),

                        // Headline Title (Matching Hot Offers KaushanScript Style)
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.kaushanScript(
                            fontSize: 25.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E1B2E),
                            letterSpacing: 0.5,
                            height: 1.25,
                          ),
                        ),

                        SizedBox(height: 8.h),

                        // Description Subtitle
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // Page Indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_slides.length, (i) {
                            final isCurrent = currentIntroSlide.value == i;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              width: isCurrent ? 28.w : 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFF9333EA)
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4.r),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF9333EA).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                            );
                          }),
                        ),

                        SizedBox(height: 16.h),

                        // Unique Engaging Action Button (Continue / Get Started)
                        _EngagingShimmerActionButton(
                          label: isLastSlide ? 'GET STARTED' : 'continue'.tr(),
                          onTap: onNextIntroSlide,
                        ),

                        SizedBox(height: 24.h),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: currentStep.value == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && currentStep.value == 1) {
          currentStep.value = 0;
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFF1F5F9),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: currentStep.value == 0
                ? Container(
                    key: const ValueKey('language_step'),
                    child: buildLanguageView(),
                  )
                : Container(
                    key: const ValueKey('intro_step'),
                    child: buildIntroView(),
                  ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// UNIQUE ENGAGING SHIMMER ACTION BUTTON
// -------------------------------------------------------------
class _EngagingShimmerActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _EngagingShimmerActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_EngagingShimmerActionButton> createState() => _EngagingShimmerActionButtonState();
}

class _EngagingShimmerActionButtonState extends State<_EngagingShimmerActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

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
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: Container(
          width: double.infinity,
          height: 56.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              // Vibrant Ambient Color Aura
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(
                  alpha: _isPressed ? 0.30 : 0.45,
                ),
                blurRadius: _isPressed ? 12 : 22,
                offset: Offset(0, _isPressed ? 3 : 8),
              ),
              // Bottom 3D Depth Shadow
              BoxShadow(
                color: const Color(0xFF4C1D95).withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.r),
            child: Stack(
              children: [
                // 1. Rich Electric Gradient Base
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF8B5CF6), // Bright Violet
                          Color(0xFF6D28D9), // Electric Purple
                          Color(0xFF4C1D95), // Deep Royal Indigo
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(28.r),
                      border: Border.all(
                        color: const Color(0xFFC4B5FD).withValues(alpha: 0.6),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),

                // 2. Animated Shimmer Light Beam Sweep
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      final val = _shimmerController.value;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(val * 4.0 - 2.0, -1.0),
                            end: Alignment(val * 4.0 - 0.8, 1.0),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.0),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 3. Top Glass Gloss Highlight Line
                Positioned(
                  top: 1.5,
                  left: 16.w,
                  right: 16.w,
                  height: 1.2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.75),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Foreground Content: Centered Bold Text with 3D Shadow
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        widget.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
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

// -------------------------------------------------------------
// HERO GRAPHIC WIDGET
// -------------------------------------------------------------
class _IntroHeroGraphicWidget extends StatefulWidget {
  final String imageAsset;
  const _IntroHeroGraphicWidget({required this.imageAsset});

  @override
  State<_IntroHeroGraphicWidget> createState() => _IntroHeroGraphicWidgetState();
}

class _IntroHeroGraphicWidgetState extends State<_IntroHeroGraphicWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.16),
                  blurRadius: 36,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Image.asset(
              widget.imageAsset,
              width: 235.w,
              height: 235.w,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}


