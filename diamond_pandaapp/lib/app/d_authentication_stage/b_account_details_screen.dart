// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../services/analytics_service.dart';
import '../../services/refer_code_service.dart';
import '../../services/security_service.dart';
import '../../utils/constant/constant.dart';
import '../../utils/helper/helper.dart';
import '../../utils/routes/routes_import.gr.dart';
import '../../widgets/common/custom_loading.dart';
import '../../widgets/common/custom_toast.dart';
import '../../widgets/common/custom_status_popup.dart';
import '../../widgets/common/custom_textformfield.dart';
import '../../widgets/common/internet_image.dart';
import '../b_splash_stage/splash_service.dart';

// ------------------ Main Screen Widget ------------------
@RoutePage()
class AccountDetailsScreen extends HookConsumerWidget {
  const AccountDetailsScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.userPhotoUrl,
    required this.fetchedReferralCode,
  });

  final String userId;
  final String userName;
  final String userEmail;
  final String userPhotoUrl;
  final String fetchedReferralCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCon = useTextEditingController(text: userName);
    final mobileNoCon = useTextEditingController();
    final referralCodeCon = useTextEditingController(text: fetchedReferralCode);
    final accKey = useMemoized(() => GlobalKey<FormState>());
    final isSubmitting = useState<bool>(false);
    final isButtonPressed = useState<bool>(false);
    final selectedGender = useState<String>('');

    // Default Country (India)
    final selectedCountry = useState<Country>(
      CountryPickerUtils.getCountryByIsoCode('IN'),
    );

    // Strip out non-digits if OS autofill attempts to insert email/text into mobile field
    useEffect(() {
      void listener() {
        final text = mobileNoCon.text;
        final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
        if (text != digitsOnly) {
          mobileNoCon.value = TextEditingValue(
            text: digitsOnly,
            selection: TextSelection.collapsed(offset: digitsOnly.length),
          );
        }
      }

      mobileNoCon.addListener(listener);
      return () => mobileNoCon.removeListener(listener);
    }, [mobileNoCon]);

    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final screenSize = mediaQuery.size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            CustomStatusPopup.showAppExit(context: context);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: true,
          body: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: Stack(
              children: [
                // 1. App Wallpaper Background (Fixed Fullscreen)
                Positioned(
                  left: 0,
                  top: 0,
                  width: screenSize.width,
                  height: screenSize.height,
                  child: Image.asset(
                    'assets/icons/Splash (2).png',
                    fit: BoxFit.cover,
                  ),
                ),



                // 3. Main Form Content (Scrolls cleanly without moving background)
                Positioned.fill(
                  child: SafeArea(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Form(
                        key: accKey,
                        child: Column(
                          children: [
                            // 1. Top Header Banner Container (Avatar and Email Chip)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                topPadding > 0 ? 12.h : 24.h,
                                16.w,
                                12.h,
                              ),
                              child: Column(
                                children: [
                                  // User Avatar Circle with Glowing Purple Ring
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFAB31DE),
                                          width: 2.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFAB31DE).withValues(alpha: 0.40),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: AvatarInternetImage(
                                        url: userPhotoUrl,
                                        size: 82,
                                        borderWidth: 0,
                                        borderColor: Colors.transparent,
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: 12.h),

                                  // User Email Chip Pill
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF).withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: const Color(0xFFAB31DE).withValues(alpha: 0.20),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFAB31DE).withValues(alpha: 0.04),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.email_rounded,
                                          color: const Color(0xFFAB31DE),
                                          size: 14.sp,
                                        ),
                                        SizedBox(width: 6.w),
                                        Flexible(
                                          child: Text(
                                            userEmail,
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF5C1B78),
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. Profile Details Form Card Container
                            Container(
                              margin: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.95),
                                    const Color(0xFFFAF5FF).withValues(alpha: 0.95),
                                    const Color(0xFFF3E8FF).withValues(alpha: 0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.18),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Section Title
                                  Text(
                                    'account-details'.tr(),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFAB31DE),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  Container(
                                    margin: EdgeInsets.symmetric(vertical: 8.h),
                                    width: 48.w,
                                    height: 3.5.h,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFAB31DE), Color(0xFF5C1B78)],
                                      ),
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'PLEASE COMPLETE YOUR PROFILE TO CONTINUE',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  SizedBox(height: 24.h),

                                  // Full Name Field
                                  CustomTextFormField(
                                    controller: nameCon,
                                    hintText: 'name',
                                    bgColor: Colors.white,
                                    textColor: Colors.black87,
                                    focusedBorderColor: const Color(0xFFAB31DE),
                                    borderColor: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                                    autofillHints: const [AutofillHints.name],
                                    prefixIcon: Icon(
                                      Icons.person_rounded,
                                      color: const Color(0xFFAB31DE),
                                      size: 20.sp,
                                    ),
                                    validator: nameValidator,
                                  ),
                                  SizedBox(height: 14.h),

                                  // Mobile Number Field with Country Code Picker
                                  CustomTextFormField(
                                    textInputType: TextInputType.phone,
                                    controller: mobileNoCon,
                                    hintText: 'mobile-no',
                                    bgColor: Colors.white,
                                    textColor: Colors.black87,
                                    focusedBorderColor: const Color(0xFFAB31DE),
                                    borderColor: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    autofillHints: const [],
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    validator: (val) =>
                                        mobileValidator(val, selectedCountry.value.phoneCode),
                                    prefixIcon: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                                      child: InkWell(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Theme(
                                              data: Theme.of(context).copyWith(
                                                dialogTheme: const DialogThemeData(
                                                  backgroundColor: Color(0xFF140F24),
                                                ),
                                              ),
                                              child: CountryPickerDialog(
                                                titlePadding: EdgeInsets.all(16.w),
                                                searchCursorColor: const Color(0xFFAB31DE),
                                                searchInputDecoration: InputDecoration(
                                                  hintText: 'Search country...',
                                                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                                                  prefixIcon: const Icon(Icons.search, color: Color(0xFFAB31DE)),
                                                  filled: true,
                                                  fillColor: const Color(0xFF1E1B2C),
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12.r),
                                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                                  ),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12.r),
                                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                                  ),
                                                  focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12.r),
                                                    borderSide: const BorderSide(color: Color(0xFFAB31DE)),
                                                  ),
                                                ),
                                                isSearchable: true,
                                                title: Text(
                                                  'Select your country',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 17.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                onValuePicked: (Country country) {
                                                  selectedCountry.value = country;
                                                },
                                                itemBuilder: (country) => Row(
                                                  children: [
                                                    CountryPickerUtils.getDefaultFlagImage(country),
                                                    SizedBox(width: 8.w),
                                                    Text(
                                                      '+${country.phoneCode}',
                                                      style: GoogleFonts.poppins(color: const Color(0xFFAB31DE)),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Flexible(
                                                      child: Text(
                                                        country.name,
                                                        style: GoogleFonts.poppins(color: Colors.white),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CountryPickerUtils.getDefaultFlagImage(selectedCountry.value),
                                            SizedBox(width: 4.w),
                                            Text(
                                              '+${selectedCountry.value.phoneCode}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.black87,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Icon(Icons.arrow_drop_down, color: const Color(0xFFAB31DE), size: 20.sp),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 14.h),

                                  // Gender Selection Row
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
                                      child: Text(
                                        'Gender',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF475569),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Male Card
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => selectedGender.value = 'Male',
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            height: 48.h,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              gradient: selectedGender.value == 'Male'
                                                  ? LinearGradient(
                                                      begin: Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                      colors: [
                                                        const Color(0xFFAB31DE).withValues(alpha: 0.85),
                                                        const Color(0xFFAB31DE).withValues(alpha: 0.25),
                                                        Colors.transparent,
                                                      ],
                                                    )
                                                  : null,
                                              borderRadius: BorderRadius.circular(14.r),
                                              border: Border.all(
                                                color: selectedGender.value == 'Male'
                                                    ? const Color(0xFFAB31DE)
                                                    : const Color(0xFFAB31DE).withValues(alpha: 0.15),
                                                width: selectedGender.value == 'Male' ? 1.5 : 1.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: selectedGender.value == 'Male'
                                                      ? const Color(0xFFAB31DE).withValues(alpha: 0.25)
                                                      : Colors.black.withValues(alpha: 0.02),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.male_rounded,
                                                  color: selectedGender.value == 'Male'
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                  size: 20.sp,
                                                ),
                                                SizedBox(width: 8.w),
                                                Text(
                                                  'Male',
                                                  style: GoogleFonts.poppins(
                                                    color: selectedGender.value == 'Male'
                                                        ? Colors.white
                                                        : const Color(0xFF64748B),
                                                    fontSize: 14.sp,
                                                    fontWeight: selectedGender.value == 'Male'
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      // Female Card
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => selectedGender.value = 'Female',
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            height: 48.h,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              gradient: selectedGender.value == 'Female'
                                                  ? LinearGradient(
                                                      begin: Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                      colors: [
                                                        const Color(0xFFAB31DE).withValues(alpha: 0.85),
                                                        const Color(0xFFAB31DE).withValues(alpha: 0.25),
                                                        Colors.transparent,
                                                      ],
                                                    )
                                                  : null,
                                              borderRadius: BorderRadius.circular(14.r),
                                              border: Border.all(
                                                color: selectedGender.value == 'Female'
                                                    ? const Color(0xFFAB31DE)
                                                    : const Color(0xFFAB31DE).withValues(alpha: 0.15),
                                                width: selectedGender.value == 'Female' ? 1.5 : 1.0,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: selectedGender.value == 'Female'
                                                      ? const Color(0xFFAB31DE).withValues(alpha: 0.25)
                                                      : Colors.black.withValues(alpha: 0.02),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.female_rounded,
                                                  color: selectedGender.value == 'Female'
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                  size: 20.sp,
                                                ),
                                                SizedBox(width: 8.w),
                                                Text(
                                                  'Female',
                                                  style: GoogleFonts.poppins(
                                                    color: selectedGender.value == 'Female'
                                                        ? Colors.white
                                                        : const Color(0xFF64748B),
                                                    fontSize: 14.sp,
                                                    fontWeight: selectedGender.value == 'Female'
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 14.h),

                                  // Optional Referral Code Field
                                  CustomTextFormField(
                                    controller: referralCodeCon,
                                    hintText: '${'referral-code'.tr()} (Optional)',
                                    translate: false,
                                    bgColor: Colors.white,
                                    textColor: Colors.black87,
                                    focusedBorderColor: const Color(0xFFAB31DE),
                                    borderColor: const Color(0xFFAB31DE).withValues(alpha: 0.15),
                                    prefixIcon: Icon(
                                      Icons.card_giftcard_rounded,
                                      color: const Color(0xFFAB31DE),
                                      size: 20.sp,
                                    ),
                                  ),
                                  SizedBox(height: 28.h),

                                  // Submit Button
                                  GestureDetector(
                                    onTapDown: (_) {
                                      isButtonPressed.value = true;
                                      HapticFeedback.lightImpact();
                                    },
                                    onTapUp: (_) async {
                                      isButtonPressed.value = false;
                                      if (isSubmitting.value) return;

                                      // 1. Check Name length
                                      final String cleanName = nameCon.text.trim();
                                      if (cleanName.isEmpty) {
                                        CustomToast.showToast(context, msg: 'empty-name'.tr());
                                        return;
                                      }
                                      if (cleanName.length < 4) {
                                        CustomToast.showToast(context, msg: 'Name must be at least 4 characters long');
                                        return;
                                      }

                                      // 2. Check Mobile Number
                                      final String cleanMobile = mobileNoCon.text.trim();
                                      if (cleanMobile.isEmpty) {
                                        CustomToast.showToast(context, msg: 'empty-mobile-no'.tr());
                                        return;
                                      }
                                      final String code = selectedCountry.value.phoneCode;
                                      if (code == '91') {
                                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleanMobile)) {
                                          CustomToast.showToast(context, msg: 'invalid-mobile-no'.tr());
                                          return;
                                        }
                                      } else {
                                        if (!RegExp(r'^\d{7,12}$').hasMatch(cleanMobile)) {
                                          CustomToast.showToast(context, msg: 'invalid-mobile-no'.tr());
                                          return;
                                        }
                                      }

                                      // 3. Validate form state
                                      if (!accKey.currentState!.validate()) return;

                                      // 4. Check if Gender is selected
                                      if (selectedGender.value.isEmpty) {
                                        CustomToast.showToast(context, msg: 'Please select your gender');
                                        return;
                                      }

                                      isSubmitting.value = true;
                                      final String fullMobileNo =
                                          '+${selectedCountry.value.phoneCode}${mobileNoCon.text.trim()}';

                                      bool success = false;
                                      try {
                                        final String referralCode =
                                            await ReferCodeService.generateReferralCode();

                                        final user = FirebaseAuth.instance.currentUser;
                                        final token = await user?.getIdToken() ?? '';

                                        final detailsInput = {
                                          'name': nameCon.text.trim(),
                                          'email': userEmail,
                                          'photoUrl': userPhotoUrl,
                                          'mobileNo': fullMobileNo,
                                          'gender': selectedGender.value,
                                          'country': selectedCountry.value.isoCode,
                                          'referralCode': referralCode,
                                          'inputReferralCode': referralCodeCon.text.trim(),
                                          'deviceId': SplashService.deviceId,
                                          'gaid': SplashService.gaid,
                                        };

                                        final res = await SecurityService.post(
                                          AppConst.saveUserDetailsApi,
                                          userId: user?.uid ?? '',
                                          deviceId: SplashService.deviceId,
                                          token: token,
                                          body: detailsInput,
                                        ).timeout(const Duration(seconds: 8));

                                        Map<String, dynamic>? resData;
                                        try {
                                          final decoded = jsonDecode(res.body);
                                          if (decoded is Map<String, dynamic>) {
                                            resData = decoded;
                                          }
                                        } catch (_) {}

                                        if (res.statusCode == 200 && (resData == null || resData['success'] != false)) {
                                          success = true;
                                          AnalyticsService.logSignup(userId);
                                          ref.invalidate(SplashService.authProvider);
                                        } else {
                                          final String errorMsg = resData?['message']?.toString() ?? 'Failed to save account details';
                                          if (context.mounted) {
                                            CustomToast.showToast(context, msg: errorMsg);
                                          }
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          CustomToast.showToast(context, msg: 'Failed to save account details');
                                        }
                                      } finally {
                                        isSubmitting.value = false;
                                        if (success && context.mounted) {
                                          AutoRouter.of(context).replace(DashboardScreenRoute(userId: userId));
                                        }
                                      }
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
                                        height: 50.h,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFFAB31DE),
                                              Color(0xFF5C1B78),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(14.r),
                                          border: Border.all(
                                            color: const Color(0xFFAB31DE).withValues(alpha: 0.20),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFAB31DE).withValues(
                                                alpha: isButtonPressed.value ? 0.15 : 0.30,
                                              ),
                                              blurRadius: isButtonPressed.value ? 8 : 18,
                                              offset: Offset(0, isButtonPressed.value ? 2 : 5),
                                            ),
                                          ],
                                        ),
                                        child: isSubmitting.value
                                            ? const Center(
                                                child: GlowLightingSpinner(
                                                  size: 20,
                                                  colors: [
                                                    Color(0xFFAB31DE),
                                                    Color(0xFF7C3AED),
                                                    Color(0xFF8B5CF6),
                                                    Color(0xFF5C1B78),
                                                  ],
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'continue'.tr().toUpperCase(),
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontSize: 15.sp,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8.w),
                                                  Icon(
                                                    Icons.arrow_forward_ios_rounded,
                                                    color: Colors.white,
                                                    size: 16.sp,
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
