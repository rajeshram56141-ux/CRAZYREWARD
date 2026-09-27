// ignore_for_file: depend_on_referenced_packages
import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../services/launch_url.dart';
import '../../../../../utils/helper/helper.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../widgets/common/custom_loading.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import 'read_tsk_model.dart';
import 'read_tsk_provider.dart';

@RoutePage()
class ReadTskScreen extends HookConsumerWidget {
  const ReadTskScreen({super.key, required this.userId});

  final String userId;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '30 sec';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0 && remainingSeconds > 0) {
      return '$minutes min $remainingSeconds sec';
    } else if (minutes > 0) {
      return '$minutes min';
    } else {
      return '$seconds sec';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appName = SplashService.appName.lows();
    final params = (userId: userId, appName: appName);
    final isTracking = useState(false);
    final clickTime = useState<DateTime?>(null);
    final isBtnPressed = useState<bool>(false);
    final lifecycleState = useAppLifecycleState();

    useEffect(() {
      Future.microtask(() {
        if (userId.trim().isNotEmpty) {
          ref.invalidate(readTskProvider(params));
          ref.invalidate(readTskHistoryProvider(userId));
        }
      });
      return () {
        if (userId.trim().isNotEmpty) {
          ref.invalidate(DashboardService.userDataProvider(userId));
        }
      };
    }, [userId]);

    final offerAsync = ref.watch(readTskProvider(params));

    useValueChanged<AppLifecycleState?, void>(lifecycleState, (oldState, _) {
      if (lifecycleState == null) return;
      final offer = offerAsync.value;
      if (offer == null) return;

      if (isTracking.value &&
          lifecycleState == AppLifecycleState.resumed &&
          clickTime.value != null) {
        final secondsSpent = DateTime.now().difference(clickTime.value!).inSeconds;
        isTracking.value = false;

        Future.microtask(() {
          if (context.mounted) {
            final isSuccess = secondsSpent >= offer.trackingTime;
            if (isSuccess) {
              _handleSuccessClaim(
                context: context,
                ref: ref,
                params: params,
                offer: offer,
              );
            } else {
              CustomStatusPopup.showFailed(
                context: context,
                title: 'Task Incomplete',
                message: 'You left before the required time. Please read the article for full duration to earn rewards.',
              );
            }
          }
        });
      }
    });

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
          child: RefreshIndicator(
            color: const Color(0xFFAB31DE),
            backgroundColor: Colors.white,
            onRefresh: () async {
              if (userId.trim().isNotEmpty) {
                ref.invalidate(readTskProvider(params));
                ref.invalidate(readTskHistoryProvider(userId));
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Header Bar: Back Button + Title + How To Use
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
                            Expanded(
                              child: Text(
                                'Read & Earn',
                                style: GoogleFonts.outfit(
                                  fontSize: 19.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E1B4B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            // Right: "How To?" Button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                LaunchUrl.inWeb(
                                  url: SplashService.getTutorialUrl(
                                    'readTask',
                                    SplashService.urlConfig.readEarnTutorial,
                                  ),
                                  context: context,
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 7.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF5FF),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: const Color(0xFFE9D5FF),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.help_outline_rounded,
                                      color: const Color(0xFFAB31DE),
                                      size: 15.sp,
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

                        SizedBox(height: 18.h),

                        // Screen Banner (Admin Configurable 700x200 with AD badge)
                        const ScreenBannerWidget(
                          screenKey: 'readEarnScreen',
                          margin: EdgeInsets.only(bottom: 14),
                        ),

                        // Active Task Card Section
                        offerAsync.when(
                          data: (offer) {
                            if (offer == null) {
                              return _buildNoTaskAvailable();
                            }
                            return _buildHeroOfferCard(
                              context: context,
                              offer: offer,
                              isBtnPressed: isBtnPressed,
                              onReadTap: () {
                                HapticFeedback.lightImpact();
                                if (offer.verificationEnabled) {
                                  AutoRouter.of(context).push(
                                    ReadTskVerificationScreenRoute(
                                      offer: offer,
                                      userId: userId,
                                      appName: appName,
                                    ),
                                  );
                                } else {
                                  isTracking.value = true;
                                  clickTime.value = DateTime.now();
                                  LaunchUrl.inWeb(
                                    url: offer.redirectionUrl,
                                    context: context,
                                  );
                                }
                              },
                            );
                          },
                          loading: () => Container(
                            height: 200.h,
                            alignment: Alignment.center,
                            child: const GlowLightingSpinner(size: 28),
                          ),
                          error: (_, __) => _buildNoTaskAvailable(),
                        ),

                        SizedBox(height: 24.h),

                        // Task History Section Header
                        Row(
                          children: [
                            Container(
                              width: 3.5.w,
                              height: 14.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFFAB31DE),
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Reading History',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12.h),

                        // Task History List Section
                        ref.watch(readTskHistoryProvider(userId)).when(
                          data: (history) => history.isEmpty
                              ? _buildEmptyHistoryState()
                              : _buildHistoryList(context, history),
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: GlowLightingSpinner(size: 28),
                            ),
                          ),
                          error: (_, __) => _buildEmptyHistoryState(),
                        ),

                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoTaskAvailable() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: const Color(0xFFAB31DE),
            size: 36.sp,
          ),
          SizedBox(height: 10.h),
          Text(
            'No Reading Tasks Available Right Now',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 14.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Check back in a little while for new articles to read & earn.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroOfferCard({
    required BuildContext context,
    required ReadTskModel offer,
    required ValueNotifier<bool> isBtnPressed,
    required VoidCallback onReadTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: const Color(0xFFF3E8FF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Article Icon Box + Title + Duration + Coin Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFE9D5FF),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/icons/reaadnowo.png',
                  width: 38.w,
                  height: 38.w,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.auto_stories_rounded,
                    color: const Color(0xFFAB31DE),
                    size: 28.sp,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Read Article',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        // Timer Pill
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                color: const Color(0xFFAB31DE),
                                size: 13.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                _formatDuration(offer.trackingTime),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFAB31DE),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Coin Reward Pill
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: const Color(0xFFE9D5FF),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/icons/coin.png',
                                width: 14.w,
                                height: 14.w,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '+${offer.coins.formatCoins()}',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFAB31DE),
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Divider Line
          Container(
            height: 1,
            color: const Color(0xFFF3E8FF),
          ),

          SizedBox(height: 14.h),

          // 3-Step Guide Section
          Text(
            'How To Complete:',
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          _buildStepRow(1, 'Tap "Read Now" below to open the assigned article.'),
          SizedBox(height: 6.h),
          _buildStepRow(2, 'Read the article for at least ${_formatDuration(offer.trackingTime)}.'),
          SizedBox(height: 6.h),
          _buildStepRow(3, 'Return to the app to claim your coins instantly.'),

          SizedBox(height: 18.h),

          // Vibrant Purple Gradient "Read Now" Action Button
          GestureDetector(
            onTap: onReadTap,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Read Now',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
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

  Widget _buildStepRow(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18.w,
          height: 18.w,
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE9D5FF),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: GoogleFonts.outfit(
              color: const Color(0xFFAB31DE),
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: const Color(0xFF475569),
              fontSize: 12.sp,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistoryState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            color: const Color(0xFF94A3B8),
            size: 28.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            'No Reading History Yet',
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Complete your first read task to see your earning record here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<ReadTskHistoryModel> history,
  ) {
    String formatTimeAgo(DateTime date) {
      final localDate = date.isUtc ? date.toLocal() : date;
      final now = DateTime.now();
      final difference = now.difference(localDate);

      if (difference.inSeconds < 10) {
        return 'Just now';
      } else if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
      } else if (difference.inHours < 24) {
        final hrs = difference.inHours;
        return '$hrs ${hrs == 1 ? 'hr' : 'hrs'} ago';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return '$days ${days == 1 ? 'day' : 'days'} ago';
      } else {
        return DateFormat('dd MMM yyyy').format(localDate);
      }
    }

    return ListView.separated(
      itemCount: history.length,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final item = history[index];
        final timeStr = formatTimeAgo(item.timestamp);
        final maskedId = item.offerId.length > 8
            ? '${item.offerId.substring(0, 4)}...${item.offerId.substring(item.offerId.length - 4)}'
            : item.offerId;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFFF3E8FF),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: Image.asset(
                  'assets/icons/reaadnowo.png',
                  width: 38.w,
                  height: 38.w,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: const Color(0xFFAB31DE),
                      size: 20.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Read Completed',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '$maskedId • $timeStr',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/coin.png',
                      width: 13.w,
                      height: 13.w,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '+${item.coins.formatCoins()}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF16A34A),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleSuccessClaim({
    required BuildContext context,
    required WidgetRef ref,
    required ReadTskParams params,
    required ReadTskModel offer,
  }) async {
    try {
      final token = Uri.tryParse(offer.redirectionUrl)?.queryParameters['token'];
      await ReadTskService.readTskPostback(
        appName: params.appName,
        userId: params.userId,
        offerId: offer.offerId,
        token: token,
      );

      ref.invalidate(readTskProvider(params));
      ref.invalidate(readTskHistoryProvider(params.userId));
      ref.invalidate(DashboardService.userDataProvider(params.userId));

      if (context.mounted) {
        CustomStatusPopup.showSuccess(
          context: context,
          title: '${offer.coins.formatCoins()} Coins Earned!',
          message: "You've successfully completed the reading task! Coins have been credited to your balance.",
        );
      }
    } catch (_) {
      if (context.mounted) {
        CustomStatusPopup.showFailed(
          context: context,
          title: 'Claim Failed',
          message: 'Unable to process your reward. Please try again.',
        );
      }
    }
  }
}
