import 'dart:ui';
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
import '../../../../../widgets/common/custom_loading.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import '../../b_invite/widgets/leaderboard_timer.dart';
import 'model/giveaway_model.dart';
import 'provider/giveaway_provider.dart';

// Tapered 3D Button Custom Painter
class _TaperedButtonPainter extends CustomPainter {
  final double radius;
  final bool isAmber;
  final bool isGreen;

  const _TaperedButtonPainter({
    this.radius = 14.0,
    this.isAmber = false,
    this.isGreen = false,
  });

  Path getButtonPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius;

    final path = Path();
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w - 2, r * 0.7);
    path.lineTo(w - 6, h - r * 0.7);
    path.quadraticBezierTo(w - 7, h, w - 7 - r, h);
    path.lineTo(7 + r, h);
    path.quadraticBezierTo(7, h, 6, h - r * 0.7);
    path.lineTo(2, r * 0.7);
    path.quadraticBezierTo(0, 0, r, 0);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = getButtonPath(size);

    // Drop shadow
    final shadowColor = isAmber
        ? const Color(0xFFB45309)
        : (isGreen ? const Color(0xFF065F46) : const Color(0xFF24007A));
    canvas.drawShadow(path, shadowColor.withValues(alpha: 0.65), 8.0, true);

    // Fill glossy gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = (isAmber
          ? const LinearGradient(
              colors: [
                Color(0xFFFEF3C7),
                Color(0xFFFBBF24),
                Color(0xFFD97706),
                Color(0xFFB45309),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.30, 0.75, 1.0],
            )
          : (isGreen
              ? const LinearGradient(
                  colors: [
                    Color(0xFFD1FAE5),
                    Color(0xFF34D399),
                    Color(0xFF059669),
                    Color(0xFF065F46),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.30, 0.75, 1.0],
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFFEADBFF),
                    Color(0xFFA565FF),
                    Color(0xFF6B15F6),
                    Color(0xFF550BD0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.30, 0.75, 1.0],
                ))).createShader(rect);

    canvas.drawPath(path, fillPaint);

    // Top rim highlight stroke
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.2),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45, 0.9],
      ).createShader(rect);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

@RoutePage()
class GiveawayDetailScreen extends HookConsumerWidget {
  const GiveawayDetailScreen({
    super.key,
    required this.giveaway,
    required this.userId,
  });

  final GiveawayModel giveaway;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      Future.microtask(() {
        ref.invalidate(GiveawayProviders.giveawaysProvider);
        ref.invalidate(GiveawayProviders.joinedProvider((userId, giveaway.id)));
        ref.invalidate(GiveawayProviders.winnersProvider(giveaway.id));
      });
      return null;
    }, const []);

    final isJoining = useState<bool>(false);
    final isClaiming = useState<bool>(false);
    final isButtonPressed = useState<bool>(false);

    final giveawaysAsync = ref.watch(GiveawayProviders.giveawaysProvider);
    final currentGiveaway = giveawaysAsync.whenOrNull(
          data: (list) {
            final matches = list.where((g) => g.id == giveaway.id);
            return matches.isNotEmpty ? matches.first : giveaway;
          },
        ) ??
        giveaway;

    final serverTime = ref.watch(GiveawayProviders.tickingServerTimeProvider).value;

    final joined = ref.watch(
      GiveawayProviders.joinedProvider((userId, currentGiveaway.id)),
    );

    final winnersAsync = ref.watch(GiveawayProviders.winnersProvider(currentGiveaway.id));
    final currentWinner = winnersAsync.value?.where((w) => w.userId == userId).firstOrNull;

    if (serverTime == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0416),
        body: Center(child: GlowLightingSpinner(size: 28)),
      );
    }

    final status = currentGiveaway.getStatus(serverTime);
    final progress = currentGiveaway.totalSlots > 0
        ? (currentGiveaway.joinedCount / currentGiveaway.totalSlots).clamp(0.0, 1.0)
        : 0.0;

    final isLive = status == GiveawayStatus.ongoing;
    final isDeclared = status == GiveawayStatus.declared;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF090314),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Full Background Image (Matching Home Screen)
            Positioned.fill(
              child: Image.asset(
                'assets/icons/bgg.png',
                fit: BoxFit.cover,
              ),
            ),

            // 2. Deep Ambient Frosted Glass Blur Overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
            ),

            // 3. Foreground Content Area
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 8.h),

                  // Top Header Bar: Back Button + "Giveaway Details" + How To Use
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            AutoRouter.of(context).maybePop();
                          },
                          child: Image.asset(
                            'assets/icons/backk.png',
                            width: 42.w,
                            height: 42.w,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Text(
                            'Giveaway Details',
                            style: GoogleFonts.poppins(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Hero Card (Banner + Progress + Action Button)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFF180E2E), // Exact solid dark container (no outline)
                              borderRadius: BorderRadius.circular(22.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Banner Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: Stack(
                                    children: [
                                      AspectRatio(
                                        aspectRatio: 1.75,
                                        child: Image.network(
                                          currentGiveaway.bannerUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFF2E1952),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.card_giftcard_rounded,
                                              color: const Color(0xFFA78BFA),
                                              size: 36.sp,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8.h,
                                        left: 8.w,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isDeclared
                                                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                                  : (isLive
                                                      ? [const Color(0xFFE11D48), const Color(0xFFBE123C)]
                                                      : [const Color(0xFF7C3AED), const Color(0xFF6D28D9)]),
                                            ),
                                            borderRadius: BorderRadius.circular(8.r),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            isDeclared
                                                ? 'RESULTS DECLARED'
                                                : (isLive ? 'LIVE NOW' : 'UPCOMING'),
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 14.h),

                                // Progress Bar & Slots Info
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.people_alt_rounded,
                                          color: const Color(0xFF94A3B8),
                                          size: 13.sp,
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          'Joined Slots:',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${currentGiveaway.joinedCount} / ${currentGiveaway.totalSlots}',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFC4B5FD),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 6.h),

                                // Sleek Gradient Linear Progress Bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6.r),
                                  child: Container(
                                    height: 6.h,
                                    width: double.infinity,
                                    color: Colors.white.withValues(alpha: 0.08),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isDeclared
                                                ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
                                                : [const Color(0xFF8B5CF6), const Color(0xFFC084FC)],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: 18.h),

                                // 3D Action Participate / Claim Button
                                () {
                                  final bool canClaimCoins = isDeclared &&
                                      currentWinner != null &&
                                      currentWinner.status == GiveawayWinnerStatus.pending &&
                                      currentWinner.reward.coins > 0;
                                  final bool isRewardClaimed = isDeclared &&
                                      currentWinner != null &&
                                      currentWinner.status == GiveawayWinnerStatus.claimed;
                                  final bool isRewardRequested = isDeclared &&
                                      currentWinner != null &&
                                      currentWinner.status == GiveawayWinnerStatus.requested;
                                  final bool isRewardShipped = isDeclared &&
                                      currentWinner != null &&
                                      currentWinner.status == GiveawayWinnerStatus.shipped;
                                  final bool isRewardDelivered = isDeclared &&
                                      currentWinner != null &&
                                      currentWinner.status == GiveawayWinnerStatus.delivered;

                                  final bool canInteract = (isLive && !joined && !isJoining.value) ||
                                      (canClaimCoins && !isClaiming.value);

                                  return GestureDetector(
                                    onTapDown: (_) {
                                      if (canInteract) {
                                        isButtonPressed.value = true;
                                        HapticFeedback.lightImpact();
                                      }
                                    },
                                    onTapUp: (_) {
                                      isButtonPressed.value = false;
                                    },
                                    onTapCancel: () => isButtonPressed.value = false,
                                    onTap: canInteract
                                        ? () async {
                                            if (canClaimCoins) {
                                              isClaiming.value = true;
                                              try {
                                                final String msg = await CloudFunctions.requestClaimGiveawayReward(
                                                  currentGiveaway.id,
                                                );
                                                ref.invalidate(GiveawayProviders.winnersProvider(currentGiveaway.id));
                                                ref.invalidate(GiveawayProviders.giveawaysProvider);
                                                CloudFunctions.triggerBalanceRefresh();
                                                if (!context.mounted) return;

                                                CustomStatusPopup.showSuccess(
                                                  context: context,
                                                  title: 'Reward Claimed! 🎉',
                                                  message: msg.isNotEmpty
                                                      ? msg
                                                      : '+${currentWinner.reward.coins} Coins added to your wallet!',
                                                );
                                              } catch (e) {
                                                if (context.mounted) {
                                                  CustomStatusPopup.showFailed(
                                                    context: context,
                                                    title: 'Claim Failed',
                                                    message: 'Unable to claim reward. Please try again later.',
                                                  );
                                                }
                                              } finally {
                                                isClaiming.value = false;
                                              }
                                            } else if (isLive && !joined) {
                                              isJoining.value = true;
                                              try {
                                                final String res = await CloudFunctions.joinGiveaway(
                                                  currentGiveaway.id,
                                                );
                                                ref.invalidate(GiveawayProviders.giveawaysProvider);
                                                ref.invalidate(GiveawayProviders.joinedProvider((userId, currentGiveaway.id)));
                                                if (!context.mounted) return;

                                                CustomStatusPopup.showSuccess(
                                                  context: context,
                                                  title: 'Giveaway Entered!',
                                                  message: res.isNotEmpty ? res : 'You have successfully joined this giveaway!',
                                                );
                                              } catch (e) {
                                                if (context.mounted) {
                                                  CustomStatusPopup.showFailed(
                                                    context: context,
                                                    title: 'Entry Failed',
                                                    message: 'Unable to join giveaway. Please check your eligibility and try again.',
                                                  );
                                                }
                                              } finally {
                                                isJoining.value = false;
                                              }
                                            }
                                          }
                                        : null,
                                    child: AnimatedScale(
                                      scale: isButtonPressed.value ? 0.96 : 1.0,
                                      duration: const Duration(milliseconds: 100),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 48.h,
                                        child: CustomPaint(
                                          painter: _TaperedButtonPainter(
                                            radius: 14,
                                            isAmber: isDeclared && !canClaimCoins && !isRewardClaimed && !isRewardDelivered,
                                            isGreen: (joined && !isDeclared) || canClaimCoins || isRewardClaimed || isRewardDelivered,
                                          ),
                                          child: (isJoining.value || isClaiming.value)
                                              ? const Center(
                                                  child: SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      canClaimCoins
                                                          ? Icons.stars_rounded
                                                          : (isRewardClaimed || isRewardDelivered
                                                              ? Icons.check_circle_rounded
                                                              : (isRewardRequested
                                                                  ? Icons.hourglass_top_rounded
                                                                  : (isRewardShipped
                                                                      ? Icons.local_shipping_rounded
                                                                      : (isDeclared
                                                                          ? Icons.emoji_events_rounded
                                                                          : (joined ? Icons.check_circle_rounded : Icons.card_giftcard_rounded))))),
                                                      color: (isDeclared && !canClaimCoins && !isRewardClaimed && !isRewardDelivered)
                                                          ? const Color(0xFF78350F)
                                                          : Colors.white,
                                                      size: 18.sp,
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Text(
                                                      canClaimCoins
                                                          ? 'Claim ${currentWinner.reward.coins} Coins'
                                                          : (isRewardClaimed
                                                              ? 'Reward Claimed'
                                                              : (isRewardRequested
                                                                  ? 'Reward Requested'
                                                                  : (isRewardShipped
                                                                      ? 'Reward Shipped'
                                                                      : (isRewardDelivered
                                                                          ? 'Reward Delivered'
                                                                          : (isDeclared
                                                                              ? 'Results Declared'
                                                                              : (joined ? 'Already Joined' : (isLive ? 'Join Giveaway' : 'Starts Soon'))))))),
                                                      style: GoogleFonts.poppins(
                                                        color: (isDeclared && !canClaimCoins && !isRewardClaimed && !isRewardDelivered)
                                                            ? const Color(0xFF78350F)
                                                            : Colors.white,
                                                        fontSize: 15.sp,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  );
                                }(),
                              ],
                            ),
                          ),

                          SizedBox(height: 20.h),

                          // Giveaway Info Card
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFF180E2E), // Exact solid dark container (no outline)
                              borderRadius: BorderRadius.circular(20.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentGiveaway.title,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                if (currentGiveaway.description.isNotEmpty) ...[
                                  Text(
                                    currentGiveaway.description,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFCBD5E1),
                                      fontSize: 11.5.sp,
                                      height: 1.4,
                                    ),
                                  ),
                                  SizedBox(height: 14.h),
                                ],

                                // Timer / Countdown Row
                                if (!isDeclared) ...[
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          color: const Color(0xFFA78BFA),
                                          size: 16.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          isLive ? 'Ends in: ' : 'Starts in: ',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        LeaderboardTimer(
                                          leaderboardTimeLeft: isLive
                                              ? currentGiveaway.declaresAt.millisecondsSinceEpoch
                                              : currentGiveaway.startsAt.millisecondsSinceEpoch,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          SizedBox(height: 20.h),

                          // -------------------------------------------------------------
                          // PRIZEPOOL / REWARDS SECTION (DYNAMIC FROM DATABASE)
                          // -------------------------------------------------------------
                          _buildPrizepoolSection(currentGiveaway),

                          if (isDeclared) ...[
                            SizedBox(height: 20.h),
                            Text(
                              'Winners',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            _buildWinnersSection(ref, currentGiveaway.id),
                          ],

                          SizedBox(height: 32.h),
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
    );
  }

  // -------------------------------------------------------------
  // DYNAMIC PRIZEPOOL / REWARDS GRID WITH NAME & ICON
  // -------------------------------------------------------------
  Widget _buildPrizepoolSection(GiveawayModel giveaway) {
    final rewards = giveaway.rewards;
    final List<Map<String, dynamic>> items = [];

    if (rewards.isNotEmpty) {
      for (final r in rewards) {
        items.add({
          'rank': r.productRank,
          'name': r.productName,
          'reward': r.displayReward,
          'image': r.productImage,
          'coins': r.coins,
        });
      }
    } else {
      final pCoins = giveaway.prizeCoins > 0 ? giveaway.prizeCoins : 100;
      items.add({
        'rank': 1,
        'name': 'Grand Prize',
        'reward': '$pCoins Coins',
        'image': '',
        'coins': pCoins,
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prizepool',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: items.length == 1 ? 1 : 2,
            crossAxisSpacing: 10.w,
            mainAxisSpacing: 10.h,
            childAspectRatio: items.length == 1 ? 4.2 : 2.8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final rank = item['rank'];
            final name = item['name'] as String? ?? '';
            final rewardStr = item['reward'] as String;
            final imageUrl = item['image'] as String? ?? '';
            final isTop = rank == 1;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF180E2E), // Solid dark container
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rank Number / Badge
                  Container(
                    width: 22.w,
                    height: 22.w,
                    decoration: BoxDecoration(
                      color: isTop ? const Color(0xFFF59E0B) : const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$rank',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),

                  // Product Icon / Image
                  if (imageUrl.isNotEmpty && imageUrl.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.r),
                      child: Image.network(
                        imageUrl,
                        width: 26.w,
                        height: 26.w,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/coin.png',
                          width: 20.w,
                          height: 20.w,
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 26.w,
                      height: 26.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E1952),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/icons/coin.png',
                        width: 18.w,
                        height: 18.w,
                        fit: BoxFit.contain,
                      ),
                    ),

                  SizedBox(width: 8.w),

                  // Name & Coins details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (name.isNotEmpty && !RegExp(r'^\d+$').hasMatch(name)) ...[
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            rewardStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFC4B5FD),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else ...[
                          Text(
                            rewardStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // WINNERS LIST SECTION
  // -------------------------------------------------------------
  Widget _buildWinnersSection(WidgetRef ref, String giveawayId) {
    final winnersAsync = ref.watch(GiveawayProviders.winnersProvider(giveawayId));

    return winnersAsync.when(
      loading: () => const Center(child: GlowLightingSpinner(size: 22)),
      error: (_, __) => Text(
        'Unable to load winners',
        style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12.sp),
      ),
      data: (winners) {
        if (winners.isEmpty) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: const Color(0xFF180E2E),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text(
              'No winners declared yet.',
              style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 12.sp),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: winners.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (context, index) {
            final w = winners[index];
            final rank = w.reward.productRank;
            final isSelf = w.userId == userId;

            Color statusBg;
            Color statusText;
            String statusLabel;

            switch (w.status) {
              case GiveawayWinnerStatus.claimed:
                statusBg = const Color(0xFF065F46).withValues(alpha: 0.35);
                statusText = const Color(0xFF34D399);
                statusLabel = 'Claimed';
                break;
              case GiveawayWinnerStatus.pending:
                statusBg = const Color(0xFFB45309).withValues(alpha: 0.35);
                statusText = const Color(0xFFFBBF24);
                statusLabel = isSelf ? 'Tap Claim' : 'Pending';
                break;
              case GiveawayWinnerStatus.shipped:
                statusBg = const Color(0xFF0E7490).withValues(alpha: 0.35);
                statusText = const Color(0xFF38BDF8);
                statusLabel = 'Shipped';
                break;
              case GiveawayWinnerStatus.delivered:
                statusBg = const Color(0xFF065F46).withValues(alpha: 0.35);
                statusText = const Color(0xFF34D399);
                statusLabel = 'Delivered';
                break;
              case GiveawayWinnerStatus.cancelled:
                statusBg = const Color(0xFF991B1B).withValues(alpha: 0.35);
                statusText = const Color(0xFFF87171);
                statusLabel = 'Cancelled';
                break;
              case GiveawayWinnerStatus.requested:
              default:
                statusBg = const Color(0xFF3730A3).withValues(alpha: 0.35);
                statusText = const Color(0xFFA5B4FC);
                statusLabel = 'Requested';
                break;
            }

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isSelf
                    ? const Color(0xFF281845)
                    : const Color(0xFF180E2E),
                borderRadius: BorderRadius.circular(16.r),
                border: isSelf
                    ? Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Text(
                    '#$rank',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFBBF24),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: isSelf ? const Color(0xFF9333EA) : const Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSelf
                              ? '${w.name.isNotEmpty ? w.name : 'You'} (You)'
                              : (w.name.isNotEmpty
                                  ? w.name
                                  : (w.userId.length > 6
                                      ? '${w.userId.substring(0, 3)}***${w.userId.substring(w.userId.length - 3)}'
                                      : w.userId)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: isSelf ? const Color(0xFFDDD6FE) : Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          w.reward.displayReward,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFC4B5FD),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      statusLabel,
                      style: GoogleFonts.poppins(
                        color: statusText,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
