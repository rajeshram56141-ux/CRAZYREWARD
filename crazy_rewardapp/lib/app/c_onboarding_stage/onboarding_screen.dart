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
      imageAsset: 'assets/icons/panda1.png',
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
      imageAsset: 'assets/icons/panda invite.png',
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
    final isButtonPressed = useState<bool>(false);
    final introPageController = usePageController();
    final currentIntroSlide = useState<int>(0);

    useEffect(() {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
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
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFAF5FF) : Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isSelected ? const Color(0xFFAB31DE) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFFAB31DE).withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
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
                  color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFE9D5FF) : const Color(0xFFE2E8F0),
                    width: 1,
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
                        color: isSelected ? const Color(0xFFAB31DE) : const Color(0xFF1E1B4B),
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        fontSize: 14.5.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      lang.countryName,
                      style: GoogleFonts.outfit(
                        color: isSelected
                            ? const Color(0xFFAB31DE).withValues(alpha: 0.8)
                            : const Color(0xFF64748B),
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
                          colors: [Color(0xFFBA54EC), Color(0xFFAB31DE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.transparent : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
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

    // Signature Daily Task Claim-Style Button
    Widget buildClaimStyleButton({
      required String label,
      required VoidCallback onTap,
      IconData icon = Icons.arrow_forward_rounded,
    }) {
      return GestureDetector(
        onTapDown: (_) {
          isButtonPressed.value = true;
          HapticFeedback.lightImpact();
        },
        onTapUp: (_) {
          isButtonPressed.value = false;
          onTap();
        },
        onTapCancel: () {
          isButtonPressed.value = false;
        },
        child: AnimatedScale(
          scale: isButtonPressed.value ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
          child: Container(
            width: double.infinity,
            height: 52.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE39FFF),
                  Color(0xFFAB31DE),
                ],
              ),
              borderRadius: BorderRadius.circular(26.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAB31DE).withValues(
                    alpha: isButtonPressed.value ? 0.25 : 0.45,
                  ),
                  blurRadius: isButtonPressed.value ? 8 : 16,
                  offset: Offset(0, isButtonPressed.value ? 2 : 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ],
            ),
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
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select Language',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4.h),
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

            SizedBox(height: 12.h),

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
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 52.h),
              child: buildClaimStyleButton(
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
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFFE9D5FF),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SKIP',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFAB31DE),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11.sp,
                            color: const Color(0xFFAB31DE),
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

                        SizedBox(height: 32.h),

                        // Tag Pill Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: const Color(0xFFE9D5FF),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            slide.tag,
                            style: GoogleFonts.pressStart2p(
                              color: const Color(0xFFAB31DE),
                              fontSize: 9.sp,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        SizedBox(height: 14.h),

                        // Headline Title
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 25.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E1B4B),
                            height: 1.2,
                          ),
                        ),

                        SizedBox(height: 10.h),

                        // Description Subtitle
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),

                        SizedBox(height: 18.h),

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
                                    ? const Color(0xFFAB31DE)
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4.r),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFAB31DE).withValues(alpha: 0.4),
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

                        // Action Button (Continue / Get Started)
                        buildClaimStyleButton(
                          label: isLastSlide ? 'GET STARTED' : 'continue'.tr(),
                          icon: isLastSlide
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          onTap: onNextIntroSlide,
                        ),

                        SizedBox(height: 36.h),
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
          systemNavigationBarColor: Color(0xFFF8FAFC),
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: currentStep.value == 0
                ? Container(
                    key: const ValueKey('language_step'),
                    color: const Color(0xFFF8FAFC),
                    child: buildLanguageView(),
                  )
                : Container(
                    key: const ValueKey('intro_step'),
                    color: const Color(0xFFF8FAFC),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/icons/Splash (2).png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                        buildIntroView(),
                      ],
                    ),
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

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
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
          child: Image.asset(
            widget.imageAsset,
            width: 180.w,
            height: 180.w,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }
}
