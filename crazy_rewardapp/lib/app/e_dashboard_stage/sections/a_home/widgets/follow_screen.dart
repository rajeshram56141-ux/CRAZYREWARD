import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/cloud_functions.dart';
import '../../../../../services/launch_url.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';

@RoutePage()
class FollowScreen extends HookConsumerWidget {
  const FollowScreen({super.key, this.userId = ''});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();

    // Auto-refresh config when screen opens
    useEffect(() {
      Future.microtask(() {
        ref.invalidate(SplashService.appDataProvider);
        if (userId.isNotEmpty) {
          ref.invalidate(DashboardService.userDataProvider(userId));
        }
      });
      return null;
    }, const []);

    final userDataAsync = ref.watch(DashboardService.userDataProvider(userId));
    final socialFollowed = userDataAsync.asData?.value.socialFollowed ?? [];
    ref.watch(SplashService.appDataProvider);
    final followCoins = SplashService.followCoins > 0 ? SplashService.followCoins : 50;

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
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),

              // Fixed Top Header: Back Button + Screen Title + Coins Pill
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE9D5FF),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: const Color(0xFF1E1B4B),
                          size: 18.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Follow Us',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Scrollable Body Content
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFAB31DE),
                  backgroundColor: const Color(0xFFFAF5FF),
                  onRefresh: () async {
                    ref.invalidate(SplashService.appDataProvider);
                    if (userId.isNotEmpty) {
                      ref.invalidate(DashboardService.userDataProvider(userId));
                    }
                  },
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      4.h,
                      16.w,
                      MediaQuery.of(context).padding.bottom + 30.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Executive Community Hero Card
                        _buildCommunityHeroCard(followCoins),

                        SizedBox(height: 22.h),

                        // Section Title Row
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: const Color(0xFFE9D5FF),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.hub_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 16.sp,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Official Channels',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 16.5.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12.h),

                        // Social Channels List
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: SocialMedia.values.length,
                          separatorBuilder: (_, __) => SizedBox(height: 12.h),
                          itemBuilder: (context, index) {
                            final String tag = SocialMedia.values[index].name;
                            final String link = SocialMedia.values[index].link;
                            final String title = SocialMedia.values[index].title;

                            final isFollowed = socialFollowed.contains(tag);

                            return _SocialPlatformCard(
                              tag: tag,
                              title: title,
                              link: link,
                              isFollowed: isFollowed,
                              rewardCoins: followCoins,
                              userId: userId,
                            );
                          },
                        ),

                        SizedBox(height: 20.h),
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
  // COMMUNITY HERO CARD (EXECUTIVE LIGHT DESIGN)
  // -------------------------------------------------------------
  Widget _buildCommunityHeroCard(int coins) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFE9D5FF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.stars_rounded,
              color: Colors.white,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join Official Community',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  coins > 0
                      ? 'Follow official channels & get +$coins Coins for each channel!'
                      : 'Follow our official channels for regular updates and announcements.',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 12.sp,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// SOCIAL PLATFORM CARD WITH 10-SEC VALIDATION & EXECUTIVE DESIGN
// -------------------------------------------------------------
class _SocialPlatformCard extends HookConsumerWidget {
  const _SocialPlatformCard({
    required this.tag,
    required this.title,
    required this.link,
    required this.isFollowed,
    required this.rewardCoins,
    required this.userId,
  });

  final String tag;
  final String title;
  final String link;
  final bool isFollowed;
  final int rewardCoins;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPressed = useState(false);
    final isVerifying = useState(false);
    final clickTimestamp = useRef<DateTime?>(null);

    String getButtonLabel() {
      switch (tag) {
        case 'youtube':
          return 'Subscribe';
        case 'whatsapp':
        case 'telegram':
          return 'Join';
        case 'instagram':
        default:
          return 'Follow';
      }
    }

    String getPlatformSubtitle() {
      switch (tag) {
        case 'whatsapp':
          return 'Official WhatsApp Channel';
        case 'youtube':
          return 'Official YouTube Channel';
        case 'telegram':
          return 'Official Telegram Group';
        case 'instagram':
          return 'Official Instagram Page';
        default:
          return 'Official Social Channel';
      }
    }

    Color getPlatformBadgeBg() {
      switch (tag) {
        case 'whatsapp':
          return const Color(0xFFDCFCE7);
        case 'youtube':
          return const Color(0xFFFEE2E2);
        case 'telegram':
          return const Color(0xFFE0F2FE);
        case 'instagram':
          return const Color(0xFFFCE7F3);
        default:
          return const Color(0xFFF3E8FF);
      }
    }

    Color getPlatformIconColor() {
      switch (tag) {
        case 'whatsapp':
          return const Color(0xFF16A34A);
        case 'youtube':
          return const Color(0xFFDC2626);
        case 'telegram':
          return const Color(0xFF0284C7);
        case 'instagram':
          return const Color(0xFFDB2777);
        default:
          return const Color(0xFFAB31DE);
      }
    }

    String getFormattedLink(String platformTag, String rawLink) {
      String trimmed = rawLink.trim();
      if (trimmed.isEmpty) {
        switch (platformTag) {
          case 'whatsapp':
            return 'https://whatsapp.com';
          case 'youtube':
            return 'https://youtube.com';
          case 'telegram':
            return 'https://t.me';
          case 'instagram':
            return 'https://instagram.com';
          default:
            return 'https://google.com';
        }
      }
      if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
        return 'https://$trimmed';
      }
      return trimmed;
    }

    Future<void> handleFollowTap() async {
      HapticFeedback.lightImpact();

      final targetUrl = getFormattedLink(tag, link);

      if (isFollowed) {
        await LaunchUrl.inWeb(url: targetUrl, context: context);
        return;
      }

      if (isVerifying.value) return;

      isVerifying.value = true;
      clickTimestamp.value = DateTime.now();

      // Launch URL externally without blocking or prematurely resetting verification state
      LaunchUrl.inWeb(url: targetUrl, context: context);
    }

    useOnAppLifecycleStateChange((previous, current) {
      if (current == AppLifecycleState.resumed && isVerifying.value && !isFollowed) {
        final startTime = clickTimestamp.value;
        if (startTime != null) {
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          if (elapsed < 10) {
            isVerifying.value = false;
            if (context.mounted) {
              CustomStatusPopup.showFailed(
                context: context,
                title: 'Follow Incomplete',
                message: 'Please follow the channel to claim your coins!',
              );
            }
          } else {
            CloudFunctions.followReward(tag).then((_) {
              ref.invalidate(DashboardService.userDataProvider(userId));
              CloudFunctions.triggerBalanceRefresh();
              if (context.mounted) {
                CustomStatusPopup.showSuccess(
                  context: context,
                  title: 'Coins Added!',
                  message: '+$rewardCoins Coins added successfully!',
                );
              }
            }).catchError((_) {});
            isVerifying.value = false;
          }
        }
      }
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => isPressed.value = true,
      onTapUp: (_) {
        isPressed.value = false;
        handleFollowTap();
      },
      onTapCancel: () => isPressed.value = false,
      child: AnimatedScale(
        scale: isPressed.value ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: isFollowed ? Colors.white : const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isFollowed ? const Color(0xFFE2E8F0) : const Color(0xFFE9D5FF),
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
          child: Row(
            children: [
              // Platform Brand Logo Container
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: getPlatformBadgeBg(),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: getPlatformIconColor().withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(9.w),
                child: Image.asset(
                  'assets/icons/$tag.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/icons/$tag-follow.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.share_rounded,
                      color: getPlatformIconColor(),
                      size: 22.sp,
                    ),
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              // Title + Subtitle + Reward Status Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      getPlatformSubtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    SizedBox(height: 5.h),

                    // Badge Pill (Coin Reward if not followed, or Followed indicator if followed)
                    if (!isFollowed && rewardCoins > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: const Color(0xFFFDE68A),
                            width: 1,
                          ),
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
                              '+$rewardCoins Coins',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFD97706),
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(width: 10.w),

              // Action Button (Gradient Join/Subscribe or Soft Outline Open)
              if (isVerifying.value)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
                      SizedBox(
                        width: 12.w,
                        height: 12.w,
                        child: const CircularProgressIndicator(
                          color: Color(0xFFAB31DE),
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Verifying...',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else if (!isFollowed)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        getButtonLabel(),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: Colors.white,
                        size: 13.sp,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
                        'Open',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.open_in_new_rounded,
                        color: const Color(0xFFAB31DE),
                        size: 12.sp,
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
