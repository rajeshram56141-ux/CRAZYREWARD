import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'parts/first_part.dart';
import 'parts/second_part.dart';
import 'provider/refer_data_provider.dart';
import '../../../b_splash_stage/splash_service.dart';

class InviteBody extends HookConsumerWidget {
  const InviteBody({
    super.key,
    required this.referralNavIndex,
    required this.userId,
    required this.referralCode,
    required this.referred,
  });

  final ValueNotifier<int> referralNavIndex;
  final String userId;
  final bool referred;
  final String referralCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController(initialPage: referralNavIndex.value);
    useListenable(referralNavIndex);

    // Sync PageController with referralNavIndex value changes & on initial/re-entry build
    useEffect(() {
      void syncPage() {
        if (pageController.hasClients) {
          final currentPage = pageController.page?.round() ?? -1;
          if (currentPage != referralNavIndex.value) {
            pageController.jumpToPage(referralNavIndex.value);
          }
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => syncPage());

      void listener() {
        if (pageController.hasClients) {
          final currentPage = pageController.page?.round() ?? -1;
          if (currentPage != referralNavIndex.value) {
            pageController.animateToPage(
              referralNavIndex.value,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
            );
          }
        }
      }

      referralNavIndex.addListener(listener);
      return () => referralNavIndex.removeListener(listener);
    }, [pageController, referralNavIndex]);

    Widget buildDailyTaskStyleTab({
      required String label,
      required int tabIndex,
      required IconData icon,
    }) {
      final isSelected = referralNavIndex.value == tabIndex;

      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            referralNavIndex.value = tabIndex;
            if (pageController.hasClients) {
              pageController.animateToPage(
                tabIndex,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            height: 40.h,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontSize: 13.5.sp,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Solid Executive White Background
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // Main Content
            SafeArea(
              bottom: false,
              child: Builder(
                builder: (context) {
                  final refStats = ref.watch(ReferralService.referralStatsProvider).value;
                  final bool isAllMode = (refStats?.rewardMode ?? SplashService.referralSettings.rewardMode) == 'all';

                  return Column(
                    children: [
                      SizedBox(height: 8.h),

                      // Segmented Executive White Tab Selector (Shown ONLY when Task Wise mode is active)
                      if (!isAllMode) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Container(
                            height: 48.h,
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                buildDailyTaskStyleTab(
                                  label: 'Referral',
                                  tabIndex: 0,
                                  icon: Icons.people_alt_rounded,
                                ),
                                SizedBox(width: 6.w),
                                buildDailyTaskStyleTab(
                                  label: 'Level',
                                  tabIndex: 1,
                                  icon: Icons.military_tech_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],

                      // Swipable PageView for pages (or single view in ALL mode)
                      Expanded(
                        child: isAllMode
                            ? SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.symmetric(horizontal: 14.w),
                                child: Column(
                                  children: [
                                    InviteFirstPart(
                                      userId: userId,
                                      referred: referred,
                                      referralCode: referralCode,
                                      ref: ref,
                                    ),
                                    SizedBox(height: 100.h),
                                  ],
                                ),
                              )
                            : PageView(
                                controller: pageController,
                                onPageChanged: (index) {
                                  referralNavIndex.value = index;
                                },
                                children: [
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                                    child: Column(
                                      children: [
                                        InviteFirstPart(
                                          userId: userId,
                                          referred: referred,
                                          referralCode: referralCode,
                                          ref: ref,
                                        ),
                                        SizedBox(height: 100.h),
                                      ],
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                                    child: Column(
                                      children: [
                                        InviteSecondPart(userId: userId, ref: ref),
                                        SizedBox(height: 100.h),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
