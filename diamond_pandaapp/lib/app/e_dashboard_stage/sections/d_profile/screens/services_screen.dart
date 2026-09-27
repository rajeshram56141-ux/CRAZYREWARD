// ignore_for_file: depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../services/analytics_service.dart';
import '../../../../../services/service_support_api.dart';
import '../../../../../widgets/common/custom_loading.dart';
import '../../../../../widgets/common/custom_toast.dart';

@RoutePage()
class ServicesScreen extends HookWidget {
  const ServicesScreen({super.key, required this.userId, required this.email});

  final String userId;
  final String email;

  @override
  Widget build(BuildContext context) {
    final activeTab = useState<int>(0); // 0 = Request Service, 1 = Request Status
    final selectedType = useState<String>('app_promotion');

    // Form inputs state
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final emailCon = useTextEditingController(text: email);
    final titleCon = useTextEditingController();
    final descCon = useTextEditingController();
    final linkCon = useTextEditingController();
    final phoneCon = useTextEditingController();
    final budgetCon = useTextEditingController();
    final campaignType = useState<String>('install');
    final selectedCountry = useState<Country>(
      CountryPickerUtils.getCountryByIsoCode('IN'),
    );

    // History state
    final requests = useState<List<dynamic>>([]);
    final isLoadingHistory = useState<bool>(false);
    final isSubmitting = useState<bool>(false);

    // Function to load history
    final loadHistory = useCallback(() async {
      isLoadingHistory.value = true;
      try {
        final data = await ServiceSupportApi.getPromotionRequests(userId);
        requests.value = data;
      } finally {
        isLoadingHistory.value = false;
      }
    }, [userId]);

    // Initial load
    useEffect(() {
      loadHistory();
      return null;
    }, const []);

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
        body: SafeArea(
          child: Column(
            children: [
              // 1. Executive Top Bar (Leaderboard standard Back Button + Centered Title)
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
                        activeTab.value == 1 ? 'Request History' : 'Service Requests',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // Right Side: History Toggle Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (activeTab.value == 0) {
                          activeTab.value = 1;
                          loadHistory();
                        } else {
                          activeTab.value = 0;
                        }
                      },
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activeTab.value == 1 ? const Color(0xFFF3E8FF) : Colors.white,
                          borderRadius: BorderRadius.circular(15.r),
                          border: Border.all(
                            color: activeTab.value == 1 ? const Color(0xFFAB31DE) : const Color(0xFFF1F5F9),
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
                          activeTab.value == 1 ? Icons.add_task_rounded : Icons.history_rounded,
                          color: const Color(0xFFAB31DE),
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10.h),

              // 3. Tab Content Views
              Expanded(
                child: activeTab.value == 0
                    ? _buildRequestForm(
                        context: context,
                        formKey: formKey,
                        email: email,
                        emailCon: emailCon,
                        phoneCon: phoneCon,
                        budgetCon: budgetCon,
                        campaignType: campaignType,
                        selectedCountry: selectedCountry,
                        selectedType: selectedType,
                        titleCon: titleCon,
                        descCon: descCon,
                        linkCon: linkCon,
                        isSubmitting: isSubmitting,
                        userId: userId,
                        loadHistory: loadHistory,
                        onSubmitted: () => activeTab.value = 1,
                      )
                    : _buildHistoryView(
                        context: context,
                        requests: requests,
                        isLoadingHistory: isLoadingHistory,
                        loadHistory: loadHistory,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // REQUEST SERVICE FORM
  // -------------------------------------------------------------
  Widget _buildRequestForm({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required String email,
    required TextEditingController emailCon,
    required TextEditingController phoneCon,
    required TextEditingController budgetCon,
    required ValueNotifier<String> campaignType,
    required ValueNotifier<Country> selectedCountry,
    required ValueNotifier<String> selectedType,
    required TextEditingController titleCon,
    required TextEditingController descCon,
    required TextEditingController linkCon,
    required ValueNotifier<bool> isSubmitting,
    required String userId,
    required Future<void> Function() loadHistory,
    required VoidCallback onSubmitted,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16.w,
        4.h,
        16.w,
        MediaQuery.of(context).padding.bottom + 20.h,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Service Type Cards
            Text(
              'Choose Service Type',
              style: GoogleFonts.outfit(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E1B4B),
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: _TypeCard(
                    icon: Icons.shop_two_rounded,
                    label: 'App Promo',
                    isSelected: selectedType.value == 'app_promotion',
                    onTap: () => selectedType.value = 'app_promotion',
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _TypeCard(
                    icon: Icons.video_collection_rounded,
                    label: 'Video Promo',
                    isSelected: selectedType.value == 'video_promotion',
                    onTap: () => selectedType.value = 'video_promotion',
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _TypeCard(
                    icon: Icons.developer_mode_rounded,
                    label: 'App Dev',
                    isSelected: selectedType.value == 'app_development',
                    onTap: () => selectedType.value = 'app_development',
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // 2. Executive Form Container
            Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: const Color(0xFFE9D5FF),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Header
                  Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3E8FF),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.miscellaneous_services_rounded,
                          color: const Color(0xFFAB31DE),
                          size: 22.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Details',
                              style: GoogleFonts.outfit(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E1B4B),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Fill requirements for promotion or development',
                              style: GoogleFonts.outfit(
                                fontSize: 12.sp,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 18.h),

                  // Mobile Number Field
                  _buildInputLabel('Mobile Number'),
                  TextFormField(
                    controller: phoneCon,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter mobile number',
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Theme(
                              data: Theme.of(context).copyWith(
                                dialogTheme: const DialogThemeData(
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              child: CountryPickerDialog(
                                titlePadding: const EdgeInsets.all(12),
                                searchCursorColor: const Color(0xFFAB31DE),
                                searchInputDecoration: InputDecoration(
                                  hintText: 'Search country...',
                                  hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                                isSearchable: true,
                                onValuePicked: (Country country) {
                                  selectedCountry.value = country;
                                },
                                itemBuilder: (Country country) => Row(
                                  children: [
                                    CountryPickerUtils.getDefaultFlagImage(country),
                                    SizedBox(width: 8.w),
                                    Text(
                                      '+${country.phoneCode}',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF1E1B4B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Flexible(
                                      child: Text(
                                        country.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(color: const Color(0xFF64748B)),
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
                            SizedBox(width: 12.w),
                            CountryPickerUtils.getDefaultFlagImage(selectedCountry.value),
                            SizedBox(width: 6.w),
                            Text(
                              '+${selectedCountry.value.phoneCode}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontWeight: FontWeight.w700,
                                fontSize: 13.sp,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: Color(0xFFAB31DE),
                            ),
                            SizedBox(width: 6.w),
                          ],
                        ),
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(
                          color: Color(0xFFAB31DE),
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Mobile number cannot be empty';
                      if (v.trim().length < 8) return 'Please enter a valid mobile number';
                      return null;
                    },
                  ),

                  SizedBox(height: 14.h),

                  // Budget Field
                  _buildInputLabel('Budget'),
                  TextFormField(
                    controller: budgetCon,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter budget amount',
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.currency_rupee_rounded,
                        color: const Color(0xFFAB31DE),
                        size: 18.sp,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(
                          color: Color(0xFFAB31DE),
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Budget cannot be empty';
                      if (double.tryParse(v.trim()) == null) return 'Please enter a valid amount';
                      return null;
                    },
                  ),

                  if (selectedType.value == 'app_promotion') ...[
                    SizedBox(height: 14.h),
                    _buildInputLabel('Campaign Type / Action Required'),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: campaignType.value,
                          isExpanded: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Color(0xFFAB31DE),
                          ),
                          dropdownColor: Colors.white,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                          onChanged: (String? val) {
                            if (val != null) {
                              campaignType.value = val;
                            }
                          },
                          items: const [
                            DropdownMenuItem<String>(
                              value: 'install',
                              child: Text('Install'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'register',
                              child: Text('Register'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 14.h),

                  // Title Field
                  _buildInputLabel(
                    selectedType.value == 'app_promotion'
                        ? 'App Name / Title'
                        : selectedType.value == 'video_promotion'
                            ? 'Video Title / Channel'
                            : 'Project Title',
                  ),
                  TextFormField(
                    controller: titleCon,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter title here',
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.title_rounded,
                        color: const Color(0xFFAB31DE),
                        size: 18.sp,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(
                          color: Color(0xFFAB31DE),
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title cannot be empty' : null,
                  ),

                  SizedBox(height: 14.h),

                  // Link Field
                  _buildInputLabel(
                    selectedType.value == 'app_development'
                        ? 'Link / URL (Optional)'
                        : 'Link / URL',
                  ),
                  TextFormField(
                    controller: linkCon,
                    keyboardType: TextInputType.url,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.link_rounded,
                        color: const Color(0xFFAB31DE),
                        size: 18.sp,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(
                          color: Color(0xFFAB31DE),
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (selectedType.value != 'app_development') {
                        if (v == null || v.trim().isEmpty) return 'Link / URL cannot be empty';
                        final uri = Uri.tryParse(v.trim());
                        final isUrl = uri != null &&
                            (uri.scheme == 'http' || uri.scheme == 'https') &&
                            uri.host.isNotEmpty &&
                            uri.host.contains('.');
                        if (!isUrl) return 'Please enter a valid URL (e.g., https://...)';
                      } else if (v != null && v.trim().isNotEmpty) {
                        final uri = Uri.tryParse(v.trim());
                        final isUrl = uri != null &&
                            (uri.scheme == 'http' || uri.scheme == 'https') &&
                            uri.host.isNotEmpty &&
                            uri.host.contains('.');
                        if (!isUrl) return 'Please enter a valid URL (e.g., https://...)';
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 14.h),

                  // Description Field
                  _buildInputLabel('Requirements / Description'),
                  TextFormField(
                    controller: descCon,
                    maxLines: 4,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Describe your project requirements, target audience, budget, or other instructions here...',
                      hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w400,
                      ),
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: EdgeInsets.all(14.w),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(
                          color: Color(0xFFAB31DE),
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Description cannot be empty' : null,
                  ),

                  SizedBox(height: 22.h),

                  // Submit Button
                  GestureDetector(
                    onTap: isSubmitting.value
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              isSubmitting.value = true;
                              HapticFeedback.lightImpact();
                              try {
                                final String fullPhoneNumber =
                                    '+${selectedCountry.value.phoneCode}${phoneCon.text.trim()}';

                                final response = await ServiceSupportApi.submitPromotionRequest(
                                  userId: userId,
                                  email: email,
                                  promotionType: selectedType.value,
                                  title: titleCon.text.trim(),
                                  description: descCon.text.trim(),
                                  link: linkCon.text.trim(),
                                  phoneNumber: fullPhoneNumber,
                                  budget: budgetCon.text.trim(),
                                  campaignType: selectedType.value == 'app_promotion'
                                      ? campaignType.value
                                      : '',
                                );

                                if (response['success'] == true) {
                                  AnalyticsService.logCustomEvent(
                                    'submit_service_request',
                                    parameters: {
                                      'userId': userId,
                                      'service_type': selectedType.value,
                                      'budget': budgetCon.text.trim(),
                                    },
                                  );
                                  if (!context.mounted) return;
                                  CustomToast.showToast(
                                    context,
                                    msg: 'Request submitted successfully!',
                                  );
                                  titleCon.clear();
                                  descCon.clear();
                                  linkCon.clear();
                                  phoneCon.clear();
                                  budgetCon.clear();
                                  await loadHistory();
                                  onSubmitted();
                                } else {
                                  if (!context.mounted) return;
                                  CustomToast.showToast(
                                    context,
                                    msg: response['message'] ?? 'Submission failed',
                                  );
                                }
                              } finally {
                                isSubmitting.value = false;
                              }
                            }
                          },
                    child: Container(
                      height: 48.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isSubmitting.value
                            ? const GlowLightingSpinner(size: 22)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'SUBMIT REQUEST',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
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
      ),
    );
  }

  // -------------------------------------------------------------
  // HISTORY VIEW
  // -------------------------------------------------------------
  Widget _buildHistoryView({
    required BuildContext context,
    required ValueNotifier<List<dynamic>> requests,
    required ValueNotifier<bool> isLoadingHistory,
    required Future<void> Function() loadHistory,
  }) {
    return RefreshIndicator(
      onRefresh: loadHistory,
      color: const Color(0xFFAB31DE),
      backgroundColor: Colors.white,
      child: isLoadingHistory.value
          ? const Center(
              child: GlowLightingSpinner(size: 28),
            )
          : requests.value.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 80.h),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 68.w,
                            height: 68.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF5FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              Icons.history_toggle_off_rounded,
                              size: 30.sp,
                              color: const Color(0xFFAB31DE),
                            ),
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            'No Promotion Requests Yet',
                            style: GoogleFonts.outfit(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1B4B),
                            ),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            'Your requested services will appear here.',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5.sp,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    4.h,
                    16.w,
                    MediaQuery.of(context).padding.bottom + 20.h,
                  ),
                  itemCount: requests.value.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    final req = requests.value[index];
                    final status = (req['status'] ?? 'pending').toString().toLowerCase();
                    final type = req['promotionType'] ?? '';
                    final title = req['title'] ?? '';
                    final adminReply = req['adminReply'] ?? '';

                    Color statusBg = const Color(0xFFFEF3C7);
                    Color statusText = const Color(0xFFD97706);

                    if (status == 'active') {
                      statusBg = const Color(0xFFE0F2FE);
                      statusText = const Color(0xFF0284C7);
                    } else if (status == 'completed') {
                      statusBg = const Color(0xFFDCFCE7);
                      statusText = const Color(0xFF16A34A);
                    } else if (status == 'rejected') {
                      statusBg = const Color(0xFFFFE4E6);
                      statusText = const Color(0xFFE11D48);
                    }

                    String displayType = 'App Dev';
                    if (type == 'app_promotion') {
                      displayType = 'App Promo';
                    }
                    if (type == 'video_promotion') {
                      displayType = 'Video Promo';
                    }

                    return Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: const Color(0xFFE9D5FF),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  displayType,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFAB31DE),
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    color: statusText,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1B4B),
                            ),
                          ),
                          if (req['description'] != null && req['description'].toString().isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              req['description'].toString(),
                              style: GoogleFonts.outfit(
                                fontSize: 12.5.sp,
                                color: const Color(0xFF64748B),
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (adminReply.toString().isNotEmpty) ...[
                            SizedBox(height: 12.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: const Color(0xFFE9D5FF),
                                  width: 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_user_rounded,
                                        color: const Color(0xFFAB31DE),
                                        size: 15.sp,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        'Admin Response:',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFAB31DE),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    adminReply,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5.sp,
                                      color: const Color(0xFF1E1B4B),
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E1B4B),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// SERVICE TYPE SELECTOR CARD
// -------------------------------------------------------------
class _TypeCard extends HookWidget {
  const _TypeCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? const Color(0xFFAB31DE) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Accent Bar when selected
            Container(
              height: 3.5.h,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                      )
                    : null,
                color: isSelected ? null : Colors.transparent,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(6.w, 10.h, 6.w, 12.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
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
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(height: 7.h),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5.sp,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? const Color(0xFF1E1B4B) : const Color(0xFF64748B),
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
