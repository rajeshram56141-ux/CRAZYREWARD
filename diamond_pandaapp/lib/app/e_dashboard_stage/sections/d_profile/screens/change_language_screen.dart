// ignore_for_file: depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../utils/helper/helper.dart';
import '../../../../c_onboarding_stage/language_selector.dart';

@RoutePage()
class ChangeLanguageScreen extends HookWidget {
  const ChangeLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selLan = useState<String>(context.locale.toString());

    final List<LanguageInfo> result = useMemoized(
      () => orderedLanguageList(languageList, context),
      [context.locale.languageCode],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Header Bar (Leaderboard style Back Button + Centered Title)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                child: Row(
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
                    Expanded(
                      child: Text(
                        'Select Language',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 40.w), // Balance back button
                  ],
                ),
              ),

              // 2. Subtitle Header Text
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Text(
                  'Choose your preferred language for the app',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // 3. Language Cards List
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    4.h,
                    16.w,
                    MediaQuery.of(context).padding.bottom + 24.h,
                  ),
                  itemCount: result.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    final languageInfo = result[index];
                    final isSelected = languageInfo.locale == selLan.value;

                    return _LanguageCard(
                      languageInfo: languageInfo,
                      isSelected: isSelected,
                      onSelect: () {
                        HapticFeedback.lightImpact();
                        selLan.value = languageInfo.locale;
                        context.setLocale(Locale(languageInfo.locale));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.languageInfo,
    required this.isSelected,
    required this.onSelect,
  });

  final LanguageInfo languageInfo;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
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
                    languageInfo.countryCode,
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
                    '${languageInfo.languageName.tr()} (${languageInfo.languageName.caps()})',
                    style: GoogleFonts.outfit(
                      color: isSelected ? const Color(0xFFAB31DE) : const Color(0xFF1E1B4B),
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                      fontSize: 14.5.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    languageInfo.countryName,
                    style: GoogleFonts.outfit(
                      color: isSelected ? const Color(0xFFAB31DE).withValues(alpha: 0.8) : const Color(0xFF64748B),
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
}
