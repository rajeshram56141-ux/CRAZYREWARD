import 'dart:convert';
import 'dart:io';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../services/service_support_api.dart';
import '../../../../../widgets/common/custom_toast.dart';
import '../../../../../widgets/screens/loading_screen.dart';

@RoutePage()
class ContactSupportScreen extends HookWidget {
  const ContactSupportScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  final String userId;
  final String email;

  @override
  Widget build(BuildContext context) {
    final activeTab = useState<int>(0); // 0 = Raise Ticket, 1 = Ticket Status
    final selectedCategory = useState<String>('Coin issue');

    final categories = [
      'Coin issue',
      'Redeem issue',
      'App crash',
      'Other',
    ];

    // Form inputs state
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final subjectCon = useTextEditingController();
    final messageCon = useTextEditingController();
    final selectedScreenshot = useState<File?>(null);

    // Tickets state
    final tickets = useState<List<dynamic>>([]);
    final isLoadingHistory = useState<bool>(false);
    final isSubmitting = useState<bool>(false);

    // Function to load tickets
    final loadTickets = useCallback(() async {
      isLoadingHistory.value = true;
      try {
        final res = await ServiceSupportApi.getSupportRequests(userId);
        tickets.value = res;
      } catch (_) {
        tickets.value = [];
      } finally {
        isLoadingHistory.value = false;
      }
    }, [userId]);

    // Initial fetch on mount
    useEffect(() {
      loadTickets();
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
              // 1. Executive Navigation Bar
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
                        activeTab.value == 1 ? 'Support History' : 'Contact Support',
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
                          loadTickets();
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
                          activeTab.value == 1 ? Icons.edit_note_rounded : Icons.history_rounded,
                          color: const Color(0xFFAB31DE),
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10.h),

              // 3. Tab Views
              Expanded(
                child: activeTab.value == 0
                    ? _buildRaiseTicketForm(
                        context: context,
                        formKey: formKey,
                        email: email,
                        selectedCategory: selectedCategory,
                        categories: categories,
                        subjectCon: subjectCon,
                        messageCon: messageCon,
                        selectedScreenshot: selectedScreenshot,
                        isSubmitting: isSubmitting,
                        userId: userId,
                        loadTickets: loadTickets,
                        onTicketSubmitted: () => activeTab.value = 1,
                      )
                    : _buildTicketStatusView(
                        context: context,
                        tickets: tickets,
                        isLoadingHistory: isLoadingHistory,
                        loadTickets: loadTickets,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // RAISE TICKET FORM
  // -------------------------------------------------------------
  Widget _buildRaiseTicketForm({
    required BuildContext context,
    required GlobalKey<FormState> formKey,
    required String email,
    required ValueNotifier<String> selectedCategory,
    required List<String> categories,
    required TextEditingController subjectCon,
    required TextEditingController messageCon,
    required ValueNotifier<File?> selectedScreenshot,
    required ValueNotifier<bool> isSubmitting,
    required String userId,
    required Future<void> Function() loadTickets,
    required VoidCallback onTicketSubmitted,
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
        child: Container(
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
                      Icons.headset_mic_rounded,
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
                          'Support Ticket Form',
                          style: GoogleFonts.outfit(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E1B4B),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Fill details to reach our support team',
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

              // 2. Issue Category Dropdown
              _buildInputLabel('Issue Category'),
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
                    value: selectedCategory.value,
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
                        selectedCategory.value = val;
                      }
                    },
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(
                          cat,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              SizedBox(height: 14.h),

              // 3. Subject Field
              _buildInputLabel('Subject'),
              TextFormField(
                controller: subjectCon,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter brief subject here',
                  hintStyle: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.subject_rounded,
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
                validator: (v) => v == null || v.trim().isEmpty ? 'Subject cannot be empty' : null,
              ),

              SizedBox(height: 14.h),

              // 4. Message Field
              _buildInputLabel('Detailed Message'),
              TextFormField(
                controller: messageCon,
                maxLines: 4,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Please describe the issue you are facing in detail...',
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
                validator: (v) => v == null || v.trim().isEmpty ? 'Message details cannot be empty' : null,
              ),

              SizedBox(height: 14.h),

              // 5. Screenshot Attachment Field
              _buildInputLabel('Attach Proof / Screenshot (Optional)'),
              selectedScreenshot.value == null
                  ? GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        try {
                          final ImagePicker picker = ImagePicker();
                          final XFile? file = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                            maxWidth: 1024,
                          );
                          if (file != null) {
                            selectedScreenshot.value = File(file.path);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            CustomToast.showToast(context, msg: 'Failed to select image');
                          }
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32.w,
                              height: 32.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF3E8FF),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.add_photo_alternate_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 18.sp,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                'Tap to choose image from gallery',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.file_upload_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 18.sp,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14.r),
                          child: Image.file(
                            selectedScreenshot.value!,
                            width: double.infinity,
                            height: 130.h,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8.h,
                          right: 8.w,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              selectedScreenshot.value = null;
                            },
                            child: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

              SizedBox(height: 22.h),

              // 6. Submit Button
              GestureDetector(
                onTap: isSubmitting.value
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          isSubmitting.value = true;
                          HapticFeedback.lightImpact();
                          try {
                            final finalSubject = '[${selectedCategory.value}] ${subjectCon.text.trim()}';

                            String? screenshotBase64;
                            if (selectedScreenshot.value != null) {
                              try {
                                final bytes = await selectedScreenshot.value!.readAsBytes();
                                screenshotBase64 = 'data:image/png;base64,${base64Encode(bytes)}';
                              } catch (_) {}
                            }

                            final response = await ServiceSupportApi.submitSupportRequest(
                              userId: userId,
                              email: email,
                              subject: finalSubject,
                              message: messageCon.text.trim(),
                              screenshot: screenshotBase64,
                            );

                            if (response['success'] == true) {
                              if (!context.mounted) return;
                              CustomToast.showToast(
                                context,
                                msg: 'Support ticket raised successfully!',
                              );
                              subjectCon.clear();
                              messageCon.clear();
                              selectedScreenshot.value = null;
                              await loadTickets();
                              onTicketSubmitted();
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
                        ? const LoadingInfoWidget(color: Colors.white)
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
                                'SUBMIT TICKET',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14.5.sp,
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
      ),
    );
  }

  // -------------------------------------------------------------
  // TICKET STATUS VIEW
  // -------------------------------------------------------------
  Widget _buildTicketStatusView({
    required BuildContext context,
    required ValueNotifier<List<dynamic>> tickets,
    required ValueNotifier<bool> isLoadingHistory,
    required Future<void> Function() loadTickets,
  }) {
    return RefreshIndicator(
      onRefresh: loadTickets,
      color: const Color(0xFFAB31DE),
      backgroundColor: Colors.white,
      child: isLoadingHistory.value
          ? const Center(
              child: LoadingInfoWidget(color: Color(0xFFAB31DE)),
            )
          : tickets.value.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: 60.h),
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
                              Icons.support_agent_rounded,
                              size: 30.sp,
                              color: const Color(0xFFAB31DE),
                            ),
                          ),
                          SizedBox(height: 14.h),
                          Text(
                            'No Support Tickets Yet',
                            style: GoogleFonts.outfit(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E1B4B),
                            ),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            'Your support requests & responses will appear here.',
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
                  itemCount: tickets.value.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (context, index) {
                    final t = tickets.value[index];
                    final status = (t['status'] ?? 'pending').toString().toLowerCase();
                    final subject = t['subject'] ?? '';
                    final message = t['message'] ?? '';
                    final adminReply = t['adminReply'] ?? '';

                    Color statusBg = const Color(0xFFFEF3C7);
                    Color statusColor = const Color(0xFFD97706);

                    if (status == 'in_progress') {
                      statusBg = const Color(0xFFE0F2FE);
                      statusColor = const Color(0xFF0284C7);
                    } else if (status == 'resolved') {
                      statusBg = const Color(0xFFDCFCE7);
                      statusColor = const Color(0xFF16A34A);
                    } else if (status == 'closed') {
                      statusBg = const Color(0xFFF1F5F9);
                      statusColor = const Color(0xFF64748B);
                    }

                    return Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
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
                              Expanded(
                                child: Text(
                                  subject,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E1B4B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  status.toUpperCase().replaceAll('_', ' '),
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            message,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5.sp,
                              color: const Color(0xFF475569),
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                                        'Support Team Response:',
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
