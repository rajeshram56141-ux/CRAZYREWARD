import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../services/ad_manager.dart';
import '../../../../../services/cloud_functions.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';

class DailyCheckInPopup extends HookConsumerWidget {
  const DailyCheckInPopup({
    super.key,
    required this.streak,
    required this.streakClaimed,
    required this.userId,
    this.coins = 0,
  });

  final int streak;
  final bool streakClaimed;
  final String userId;
  final int coins;

  static Future<void> show({
    required BuildContext context,
    required int streak,
    required bool streakClaimed,
    required String userId,
    int coins = 0,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Daily Streak',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => DailyCheckInPopup(
        streak: streak,
        streakClaimed: streakClaimed,
        userId: userId,
        coins: coins,
      ),
      transitionBuilder: (_, anim1, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: anim1,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int safeStreak = (streak <= 0) ? 1 : streak;
    final int currentIdx = (safeStreak - 1) % AppConst.maxStreak;
    final isClaiming = useState(false);
    final isClaimedLocal = useState(streakClaimed);

    bool isCompleted(int index) {
      return index < currentIdx || (index == currentIdx && isClaimedLocal.value);
    }

    final int todayCoins = (currentIdx + 1) * SplashService.streakConfig.coins;
    final bool canClaim = !isClaimedLocal.value;

    useEffect(() {
      if (canClaim && SplashService.streakConfig.rewardedAds) {
        AdManager().preloadRewarded();
      }
      return null;
    }, const []);

    Future<void> handleClaimStreak() async {
      if (!canClaim || isClaiming.value) return;

      HapticFeedback.lightImpact();
      isClaiming.value = true;

      try {
        if (SplashService.streakConfig.rewardedAds) {
          bool rewardEarned = false;
          await AdManager().showRewardedAd(
            context: context,
            onReward: () async {
              rewardEarned = true;
            },
            onAdClicked: () async {},
            onAdClosed: (bool earned) async {
              if (earned || rewardEarned) {
                try {
                  await CloudFunctions.streakReward();
                  isClaimedLocal.value = true;
                  ref.invalidate(DashboardService.userDataProvider(userId));
                  if (context.mounted) {
                    isClaiming.value = false;
                    CustomStatusPopup.showSuccess(
                      context: context,
                      tag: 'Daily Streak',
                      title: '+$todayCoins Coins',
                      message:
                          'Congratulations! You have claimed Day ${(currentIdx + 1)} streak reward of $todayCoins coins.',
                      primaryButtonText: 'AWESOME! 🎉',
                      onPrimaryTap: () => Navigator.pop(context),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    isClaiming.value = false;
                    CustomStatusPopup.showFailed(
                      context: context,
                      tag: 'Oops!',
                      title: 'Claim Error',
                      message:
                          'Something went wrong while claiming your streak reward. Please try again.',
                      primaryButtonText: 'CLOSE',
                      onPrimaryTap: () => Navigator.pop(context),
                    );
                  }
                }
              } else {
                isClaiming.value = false;
              }
            },
            onAdFailed: () {
              isClaiming.value = false;
              if (context.mounted) {
                CustomStatusPopup.showFailed(
                  context: context,
                  tag: 'Ad Unavailable',
                  title: 'Claim Failed',
                  message:
                      'Ad is currently unavailable. Please try again in a few moments.',
                  primaryButtonText: 'TRY AGAIN 🔄',
                  onPrimaryTap: () => Navigator.pop(context),
                );
              }
            },
          );
        } else {
          await AdManager().showInterstitialAd(
            onClosed: () async {
              try {
                await CloudFunctions.streakReward();
                isClaimedLocal.value = true;
                ref.invalidate(DashboardService.userDataProvider(userId));
                if (context.mounted) {
                  isClaiming.value = false;
                  CustomStatusPopup.showSuccess(
                    context: context,
                    tag: 'Daily Streak',
                    title: '+$todayCoins Coins',
                    message:
                        'Congratulations! You have claimed Day ${(currentIdx + 1)} streak reward of $todayCoins coins.',
                    primaryButtonText: 'AWESOME! 🎉',
                    onPrimaryTap: () => Navigator.pop(context),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  isClaiming.value = false;
                  CustomStatusPopup.showFailed(
                    context: context,
                    tag: 'Oops!',
                    title: 'Claim Error',
                    message:
                        'Something went wrong while claiming your streak reward. Please try again.',
                    primaryButtonText: 'CLOSE',
                    onPrimaryTap: () => Navigator.pop(context),
                  );
                }
              }
            },
            onAdFailed: () {
              isClaiming.value = false;
              if (context.mounted) {
                CustomStatusPopup.showFailed(
                  context: context,
                  tag: 'Ad Unavailable',
                  title: 'Claim Failed',
                  message:
                      'Ad is currently unavailable. Please try again in a few moments.',
                  primaryButtonText: 'TRY AGAIN 🔄',
                  onPrimaryTap: () => Navigator.pop(context),
                );
              }
            },
          );
        }
      } catch (e) {
        isClaiming.value = false;
        if (context.mounted) {
          CustomStatusPopup.showFailed(
            context: context,
            tag: 'Oops!',
            title: 'Claim Error',
            message:
                'Something went wrong while claiming your streak reward. Please try again.',
            primaryButtonText: 'CLOSE',
            onPrimaryTap: () => Navigator.pop(context),
          );
        }
      }
    }

    final topPadding = MediaQuery.of(context).padding.top;

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
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, topPadding + 8.h, 16.w, 40.h + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Navigation Header
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(14.r),
                            child: Container(
                              width: 40.w,
                              height: 40.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: const Color(0xFF26262B),
                                size: 20.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Daily Check In',
                            style: GoogleFonts.kaushanScript(
                              color: const Color(0xFF26262B),
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20.h),

                      // Executive Streak Hero Card (with assets/Icons1/Rectangle 13.png background)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20.r),
                        decoration: BoxDecoration(
                          image: const DecorationImage(
                            image: AssetImage('assets/Icons1/Rectangle 13.png'),
                            fit: BoxFit.fill,
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Flame Icon Container
                            Container(
                              width: 52.w,
                              height: 52.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/icons/fire (2).png',
                                width: 30.w,
                                height: 30.w,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 26.sp),
                                ),
                              ),
                            ),

                            SizedBox(height: 12.h),

                            // Streak Counter Title
                            Text(
                              '$safeStreak Day Streak!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),

                            SizedBox(height: 4.h),

                            // Subtitle
                            Text(
                              'Check in every day to claim your bonus coin rewards!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE2E8F0),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 22.h),

                      // Section Heading: 7-Day Rewards
                      Row(
                        children: [
                          Container(
                            width: 4.w,
                            height: 18.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFF26262B),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '7-Day Streak Rewards',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF26262B),
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 14.h),

                      // 7-DAY VERTICAL LIST FORMAT
                      Column(
                        children: List.generate(7, (index) {
                          final int dayNum = index + 1;
                          final bool done = isCompleted(index);
                          final bool isToday = index == currentIdx;
                          final int dayCoins = dayNum * SplashService.streakConfig.coins;

                          return _buildVerticalDayRow(
                            context: context,
                            dayNum: dayNum,
                            dayCoins: dayCoins,
                            done: done,
                            isToday: isToday,
                            canClaim: canClaim,
                            isClaiming: isClaiming.value,
                            onClaimTap: handleClaimStreak,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Full-Screen Loading Overlay While Claiming
            if (isClaiming.value)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: Container(
                    width: 56.w,
                    height: 56.w,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF26262B)),
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
  // VERTICAL 7-DAY LIST ITEM ROW
  // ---------------------------------------------------------------------------
  Widget _buildVerticalDayRow({
    required BuildContext context,
    required int dayNum,
    required int dayCoins,
    required bool done,
    required bool isToday,
    required bool canClaim,
    required bool isClaiming,
    required VoidCallback onClaimTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isToday && canClaim
              ? const Color(0xFF26262B)
              : const Color(0xFFE2E8F0),
          width: isToday && canClaim ? 1.4 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Left TV AD Icon
          const _TvAdIconWidget(size: 38),

          SizedBox(width: 14.w),

          // 2. Middle Coin Icon + Reward Coins + Day info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/icons/coin.png',
                      width: 18.w,
                      height: 18.w,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/icons/coin.png',
                        width: 18.w,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      '+$dayCoins Coins',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF26262B),
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  'Day $dayNum Reward',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // 3. Right Action Button (Watch Ad / Locked / Claimed)
          if (done)
            // Completed Status
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFFBBF7D0),
                  width: 1.0,
                ),
              ),
              child: Text(
                'Claimed ✓',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF16A34A),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else if (isToday && canClaim)
            // Active Watch Ad Metallic Silver Button
            GestureDetector(
              onTap: onClaimTap,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFE5E7EB),
                      Color(0xFFB0B5C2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: const Color(0xFF9CA3AF),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isClaiming
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16161A)),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 16.sp,
                            color: const Color(0xFF16161A),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Watch Ad',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF16161A),
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else
            // Locked Status
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13.sp,
                    color: const Color(0xFF94A3B8),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Locked',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
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

// ---------------------------------------------------------------------------
// TV AD ICON WIDGET
// ---------------------------------------------------------------------------
class _TvAdIconWidget extends StatelessWidget {
  const _TvAdIconWidget({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size.w, size.w * 0.95),
      painter: const _TvAdIconPainter(),
    );
  }
}

class _TvAdIconPainter extends CustomPainter {
  const _TvAdIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Paint for TV Outline & Antenna
    final tvPaint = Paint()
      ..color = const Color(0xFFCBD5E1) // Clean slate outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Antennas (V shape on top)
    final antennaPath = Path();
    antennaPath.moveTo(w * 0.40, h * 0.30);
    antennaPath.lineTo(w * 0.28, h * 0.10);
    antennaPath.moveTo(w * 0.60, h * 0.30);
    antennaPath.lineTo(w * 0.72, h * 0.10);

    canvas.drawPath(antennaPath, tvPaint);

    // 2. TV Screen Box (Rounded Rectangle)
    final tvRect = RRect.fromLTRBR(
      w * 0.05,
      h * 0.28,
      w * 0.95,
      h * 0.96,
      Radius.circular(8.r),
    );

    canvas.drawRRect(tvRect, tvPaint);

    // 3. AD Text inside TV Screen
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'AD',
        style: GoogleFonts.poppins(
          color: const Color(0xFF26262B), // Bold executive dark
          fontSize: (size.width * 0.32).sp,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final textOffset = Offset(
      (w - textPainter.width) / 2,
      (h * 0.28 + (h * 0.68 - textPainter.height) / 2),
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
