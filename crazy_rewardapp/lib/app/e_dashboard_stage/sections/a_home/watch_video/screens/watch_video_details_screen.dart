import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../../services/launch_url.dart';
import '../../../../../../utils/helper/helper.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../../widgets/common/internet_image.dart';
import '../../../../../b_splash_stage/splash_service.dart';
import '../../../../provider/dashboard_provider.dart';
import '../../../../../../utils/routes/routes_import.gr.dart';
import '../../daily_task/daily_task_model.dart';
import '../provider/watch_video_provider.dart';

@RoutePage()
class WatchVideoDetailsScreen extends HookWidget {
  const WatchVideoDetailsScreen({
    super.key,
    required this.item,
    required this.email,
    required this.userId,
    required this.countryCode,
    required this.ref,
    this.heroTag,
  });

  final DailyTaskModel item;
  final String userId;
  final String email;
  final String countryCode;
  final WidgetRef ref;
  final String? heroTag;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '30 Sec';
    if (seconds < 60) return '$seconds Sec';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    if (rem == 0) return '$minutes Minutes';
    return '$minutes m $rem s';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isBtnPressed = useState<bool>(false);

    final isTracking = useState(false);
    final clickTime = useState<DateTime?>(null);
    final lifecycleState = useAppLifecycleState();
    final showVerification = useState(false);

    useValueChanged<AppLifecycleState, void>(lifecycleState!, (oldState, _) {
      if (isTracking.value &&
          lifecycleState == AppLifecycleState.resumed &&
          clickTime.value != null) {
        final secondsSpent = DateTime.now()
            .difference(clickTime.value!)
            .inSeconds;

        isTracking.value = false;

        Future.microtask(() {
          if (context.mounted) {
            final isSuccess = secondsSpent >= item.trackingTime;
            if (isSuccess && item.videoVerificationEnabled) {
              showVerification.value = true;
            } else {
              _showResultDialog(
                context,
                isSuccess,
                item.coins,
                countryCode,
              );
            }
          }
        });
      }
    });

    if (showVerification.value) {
      return VideoVerificationScreen(
        item: item,
        userId: userId,
        email: email,
        countryCode: countryCode,
        ref: ref,
        onBack: () {
          showVerification.value = false;
        },
      );
    }

    final durationText = _formatDuration(item.trackingTime);
    final subText = item.subDescription.trim().isNotEmpty
        ? item.subDescription
        : (item.offerDescription.isNotEmpty
            ? item.offerDescription.join(' ')
            : 'Watch video and complete task to earn reward coins');

    final categoryLabel = item.offerCategory.trim().isNotEmpty
        ? item.offerCategory.trim()
        : 'Entertainment';

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
            // 1. Solid Clean White Base Background
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, topPadding + 8.h, 16.w, 100.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Navigation Header
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
                          'Watch Video',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 18.5.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 18.h),

                    // Video Banner / Poster (Matching Reference Image 1-to-1)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.r),
                        child: AspectRatio(
                          aspectRatio: 1.78,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              heroTag != null
                                  ? Hero(
                                      tag: heroTag!,
                                      child: InternetImage(
                                        url: item.bannerPath,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : InternetImage(
                                      url: item.bannerPath,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),

                              // Center Dark Circular Play Button
                              Center(
                                child: Container(
                                  width: 50.w,
                                  height: 50.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.65),
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Category Tag Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EEFF),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        categoryLabel,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // Video Title
                    Text(
                      item.offerName,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),

                    SizedBox(height: 6.h),

                    // Subtitle / Description
                    Text(
                      subText,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // 2-Column Info Card Box (Watch Time & Coin Earnings)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFAF5FF), Color(0xFFFFFFFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFFF1F5F9),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Column 1: Required Watch Time
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 38.w,
                                  height: 38.w,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3E8FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.access_time_filled_rounded,
                                    color: const Color(0xFFAB31DE),
                                    size: 20.sp,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        durationText,
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF1E1B4B),
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 1.h),
                                      Text(
                                        'Required watch time',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 10.5.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            width: 1,
                            height: 32.h,
                            color: const Color(0xFFF1F5F9),
                          ),
                          SizedBox(width: 12.w),

                          // Column 2: Coin Earnings
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 38.w,
                                  height: 38.w,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEF3C7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Image.asset(
                                    'assets/icons/coin.png',
                                    width: 22.w,
                                    height: 22.w,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Text(
                                    '${item.coins} Coins',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF1E1B4B),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // How It Works Card (Step 1, Step 2, Step 3 Timeline)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(18.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(22.r),
                        border: Border.all(
                          color: const Color(0xFFF1F5F9),
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
                          if (item.offerDescription.isNotEmpty) ...[
                            for (int i = 0; i < item.offerDescription.length; i++)
                              _buildAdminStep(
                                stepIndex: i,
                                text: item.offerDescription[i],
                                isLast: i == item.offerDescription.length - 1,
                              ),
                          ] else ...[
                            _buildTimelineStep(
                              stepNum: '1',
                              title: 'Click on "Watch Now"',
                              subtitle: 'Click the button below to start the video',
                              isLast: false,
                            ),
                            _buildTimelineStep(
                              stepNum: '2',
                              title: 'Watch the full video for $durationText',
                              subtitle: 'Watch the video without skipping',
                              isLast: false,
                            ),
                            _buildTimelineStep(
                              stepNum: '3',
                              title: 'Coins will be added automatically',
                              subtitle: 'Once completed, ${item.coins} coins will be added to your wallet automatically',
                              isLast: true,
                            ),
                          ],

                          if (item.offerDisclaimer.isNotEmpty) ...[
                            SizedBox(height: 14.h),
                            Container(
                              height: 1,
                              color: const Color(0xFFF1F5F9),
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: const Color(0xFFEF4444),
                                  size: 16.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'Important Rules & Notes',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFEF4444),
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            for (final disclaimer in item.offerDisclaimer)
                              Padding(
                                padding: EdgeInsets.only(bottom: 6.h),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF64748B),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        disclaimer,
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF64748B),
                                          fontSize: 11.5.sp,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // Pro Tip / Note Banner
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFFF3E8FF),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: const Color(0xFFAB31DE),
                            size: 18.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'Make sure to watch the full video to earn your coins',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF64748B),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
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

            // 3. Fixed Bottom Action Button: "Watch Now"
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  10.h,
                  16.w,
                  MediaQuery.of(context).padding.bottom > 0
                      ? MediaQuery.of(context).padding.bottom + 8.h
                      : 14.h,
                ),
                color: Colors.white,
                child: GestureDetector(
                  onTapDown: (_) {
                    isBtnPressed.value = true;
                    HapticFeedback.lightImpact();
                  },
                  onTapUp: (_) => isBtnPressed.value = false,
                  onTapCancel: () => isBtnPressed.value = false,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    if (item.redirectionUrl.trim().isNotEmpty) {
                      isTracking.value = true;
                      clickTime.value = DateTime.now();

                      final rawUrl = item.redirectionUrl;
                      final finalUrl = rawUrl
                          .replaceAll('{user_id}', userId)
                          .replaceAll('{userId}', userId);

                      LaunchUrl.inWeb(
                        url: finalUrl,
                        context: context,
                      );
                    }
                  },
                  child: AnimatedScale(
                    scale: isBtnPressed.value ? 0.96 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeInOut,
                    child: Container(
                      width: double.infinity,
                      height: 52.h,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE39FFF),
                            Color(0xFFAB31DE),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(26.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 26.sp,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Watch Now',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DYNAMIC ADMIN TIMELINE STEP PARSER & ITEM WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildAdminStep({
    required int stepIndex,
    required String text,
    required bool isLast,
  }) {
    final clean = text.trim();
    String title = clean;
    String? subtitle;

    if (clean.contains(':')) {
      final parts = clean.split(':');
      title = parts[0].trim();
      subtitle = parts.sublist(1).join(':').trim();
    } else if (clean.contains(' - ')) {
      final parts = clean.split(' - ');
      title = parts[0].trim();
      subtitle = parts.sublist(1).join(' - ').trim();
    }

    return _buildTimelineStep(
      stepNum: '${stepIndex + 1}',
      title: title,
      subtitle: (subtitle != null && subtitle.isNotEmpty) ? subtitle : '',
      isLast: isLast,
    );
  }

  Widget _buildTimelineStep({
    required String stepNum,
    required String title,
    required String subtitle,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Circle + Connecting Line
          Column(
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E8FF),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  stepNum,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFAB31DE),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5.w,
                    margin: EdgeInsets.symmetric(vertical: 4.h),
                    color: const Color(0xFFE9D5FF),
                  ),
                ),
            ],
          ),

          SizedBox(width: 12.w),

          // Step Text Details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(
    BuildContext context,
    bool success,
    int coins,
    String countryCode,
  ) {
    if (success) {
      CustomStatusPopup.showSuccess(
        context: context,
        title: 'Task Completed!',
        message: 'You earned +$coins Coins! Rewards will be credited to your account.',
        primaryButtonText: 'GREAT!',
        onPrimaryTap: () async {
          await WatchVideoService.watchVideoPostback(
            userId: userId,
            email: email,
            offerId: item.offerId,
            appName: SplashService.appName.lows(),
          );
          ref.invalidate(DashboardService.userDataProvider(userId));
          ref.invalidate(
            watchVideoProvider((
              userId: userId,
              email: email,
              countryCode: countryCode,
            )),
          );
          if (context.mounted) {
            final hasWatchScreen = context.router.stack.any((r) => r.name == WatchVideoScreenRoute.name);
            if (hasWatchScreen) {
              context.router.popUntil((route) => route.settings.name == WatchVideoScreenRoute.name);
            } else {
              context.router.replace(WatchVideoScreenRoute(
                userId: userId,
                email: email,
                country: countryCode,
              ));
            }
          }
        },
      );
    } else {
      CustomStatusPopup.showFailed(
        context: context,
        title: 'Task Incomplete',
        message: 'You need to watch the video for the full required duration without skipping to earn coins.',
        primaryButtonText: 'TRY AGAIN',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// VIDEO OCR SCREEN VERIFICATION
// ---------------------------------------------------------------------------
class VideoVerificationScreen extends StatefulWidget {
  final DailyTaskModel item;
  final String userId;
  final String email;
  final String countryCode;
  final WidgetRef ref;
  final VoidCallback onBack;

  const VideoVerificationScreen({
    super.key,
    required this.item,
    required this.userId,
    required this.email,
    required this.countryCode,
    required this.ref,
    required this.onBack,
  });

  @override
  State<VideoVerificationScreen> createState() => _VideoVerificationScreenState();
}

class _VideoVerificationScreenState extends State<VideoVerificationScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isChecking = false;
  String? _errorMessage;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to pick image: $e";
      });
    }
  }

  void _verifyLink() async {
    HapticFeedback.lightImpact();
    final link = _controller.text.trim();
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = "Please select/upload a screenshot of the video.";
      });
      return;
    }
    if (link.isEmpty) {
      setState(() {
        _errorMessage = "Please enter or paste the video URL/link.";
      });
      return;
    }

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'screenshot': await MultipartFile.fromFile(
          _selectedImage!.path,
          filename: 'screenshot.jpg',
        ),
        'userId': widget.userId,
        'email': widget.email,
        'offerId': widget.item.offerId,
        'appName': SplashService.appName,
        'videoUrl': link,
        'countryCode': widget.countryCode,
      });

      final response = await dio.post(
        AppConst.watchVideoVerifyOcr,
        data: formData,
        options: Options(
          headers: {
            if (AppConst.apiKey.isNotEmpty) 'x-api-key': AppConst.apiKey,
            if (widget.userId.isNotEmpty) 'x-user-id': widget.userId,
          },
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final resData = response.data;
        if (resData['success'] == true) {
          // Invalidate user wallet and watch video list so completed task is removed
          widget.ref.invalidate(DashboardService.userDataProvider(widget.userId));
          widget.ref.invalidate(
            watchVideoProvider((
              userId: widget.userId,
              email: widget.email,
              countryCode: widget.countryCode,
            )),
          );

          CustomStatusPopup.showSuccess(
            context: context,
            title: 'Task Completed!',
            message: 'Your verification was successful and +${widget.item.coins} coins have been credited!',
            primaryButtonText: 'GREAT!',
            onPrimaryTap: () {
              if (mounted) {
                final hasWatchScreen = context.router.stack.any((r) => r.name == WatchVideoScreenRoute.name);
                if (hasWatchScreen) {
                  context.router.popUntil((route) => route.settings.name == WatchVideoScreenRoute.name);
                } else {
                  context.router.replace(WatchVideoScreenRoute(
                    userId: widget.userId,
                    email: widget.email,
                    country: widget.countryCode,
                  ));
                }
              }
            },
          );
        } else {
          setState(() {
            _isChecking = false;
            _errorMessage = resData['message'] ?? "Verification Failed. Please check image & URL and retry.";
          });
        }
      } else {
        setState(() {
          _isChecking = false;
          _errorMessage = "Server error: ${response.statusCode}. Please try again.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _errorMessage = "Connection error ($e). Make sure your internet is working and retry.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isChecking) {
          widget.onBack();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.white),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (!_isChecking) widget.onBack();
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
                                  'Video Verification',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF1E1B4B),
                                    fontSize: 18.5.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 18.h),

                            // Step 1 Text & Subtitle
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFAB31DE),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        'STEP 1',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Upload Video Screenshot',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF1E1B4B),
                                        fontSize: 13.5.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  'Take a screenshot while watching the video and upload it here',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),

                            // Upload Container
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                height: 160.h,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: const Color(0xFFE9D5FF),
                                    width: 1.5,
                                  ),
                                ),
                                child: _selectedImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(18.r),
                                        child: Image.file(
                                          _selectedImage!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_rounded,
                                            color: const Color(0xFFAB31DE),
                                            size: 36.sp,
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            'Tap to upload video screenshot',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF1E1B4B),
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            SizedBox(height: 18.h),

                            // Step 2 Text & Subtitle
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFAB31DE),
                                        borderRadius: BorderRadius.circular(6.r),
                                      ),
                                      child: Text(
                                        'STEP 2',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Enter Video Link',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF1E1B4B),
                                        fontSize: 13.5.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  'Paste the link or URL of the video you watched',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),

                            // URL Input
                            Container(
                              height: 50.h,
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                              ),
                              child: TextField(
                                controller: _controller,
                                cursorColor: const Color(0xFFAB31DE),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF1E1B4B),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Paste video link/URL',
                                  hintStyle: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 13.5.sp,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),

                            if (_errorMessage != null) ...[
                              SizedBox(height: 10.h),
                              Text(
                                _errorMessage!,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFEF4444),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],

                            SizedBox(height: 20.h),

                            // Verify Button
                            GestureDetector(
                              onTap: _isChecking ? null : _verifyLink,
                              child: Container(
                                width: double.infinity,
                                height: 50.h,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                                  ),
                                  borderRadius: BorderRadius.circular(25.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isChecking
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'Verify & Claim',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
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
