import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../services/cloud_functions.dart';
import '../../../../../widgets/common/custom_loading.dart';
import '../../../../../widgets/common/custom_status_popup.dart';
import '../../b_invite/widgets/leaderboard_timer.dart';
import 'model/giveaway_model.dart';
import 'provider/giveaway_provider.dart';

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
        backgroundColor: Colors.white,
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

            // Foreground Content Area
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 8.h),

                  // Top Header Bar: Back Button + "Giveaway Details"
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            AutoRouter.of(context).maybePop();
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
                        Expanded(
                          child: Text(
                            'Giveaway Details',
                            style: GoogleFonts.kaushanScript(
                              color: const Color(0xFF26262B),
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
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
                                            color: const Color(0xFFF1F5F9),
                                            alignment: Alignment.center,
                                            child: Icon(
                                              Icons.card_giftcard_rounded,
                                              color: const Color(0xFF26262B),
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
                                            color: isDeclared
                                                ? const Color(0xFFD97706)
                                                : (isLive ? const Color(0xFFDC2626) : const Color(0xFF26262E)),
                                            borderRadius: BorderRadius.circular(6.r),
                                          ),
                                          child: Text(
                                            isDeclared
                                                ? 'RESULTS DECLARED'
                                                : (isLive ? 'LIVE NOW' : 'UPCOMING'),
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 9.5.sp,
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
                                        color: const Color(0xFF26262B),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 6.h),

                                // Linear Progress Bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6.r),
                                  child: Container(
                                    height: 6.h,
                                    width: double.infinity,
                                    color: const Color(0xFFF1F5F9),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress,
                                      child: Container(
                                        color: isDeclared
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF26262B),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: 18.h),

                                // Action Participate / Claim Button (Silver Metallic Gradient Button)
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
                                      child: Container(
                                        width: double.infinity,
                                        height: 48.h,
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
                                          borderRadius: BorderRadius.circular(14.r),
                                          border: Border.all(
                                            color: const Color(0xFF9CA3AF),
                                            width: 1.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.10),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: (isJoining.value || isClaiming.value)
                                            ? const Center(
                                                child: SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF16161A)),
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
                                                    color: const Color(0xFF16161A),
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
                                                      color: const Color(0xFF16161A),
                                                      fontSize: 14.5.sp,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentGiveaway.title,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF26262B),
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                if (currentGiveaway.description.isNotEmpty) ...[
                                  Text(
                                    currentGiveaway.description,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF64748B),
                                      fontSize: 12.sp,
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
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          color: const Color(0xFF26262B),
                                          size: 16.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          isLive ? 'Ends in: ' : 'Starts in: ',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF64748B),
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
                            Row(
                              children: [
                                Container(
                                  width: 4.w,
                                  height: 16.h,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF26262B),
                                    borderRadius: BorderRadius.circular(2.r),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Winners',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF26262B),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
        Row(
          children: [
            Container(
              width: 4.w,
              height: 16.h,
              decoration: BoxDecoration(
                color: const Color(0xFF26262B),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Prizepool',
              style: GoogleFonts.poppins(
                color: const Color(0xFF26262B),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Rank Number / Dark Badge
                  Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF26262E),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#$rank',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10.sp,
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
                        color: const Color(0xFFF1F5F9),
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
                              color: const Color(0xFF26262B),
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            rewardStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF64748B),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else ...[
                          Text(
                            rewardStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF26262B),
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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            child: Text(
              'No winners declared yet.',
              style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12.sp),
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
                statusBg = const Color(0xFFF0FDF4);
                statusText = const Color(0xFF16A34A);
                statusLabel = 'Claimed';
                break;
              case GiveawayWinnerStatus.pending:
                statusBg = const Color(0xFFFEF3C7);
                statusText = const Color(0xFFD97706);
                statusLabel = isSelf ? 'Tap Claim' : 'Pending';
                break;
              case GiveawayWinnerStatus.shipped:
                statusBg = const Color(0xFFF0F9FF);
                statusText = const Color(0xFF0284C7);
                statusLabel = 'Shipped';
                break;
              case GiveawayWinnerStatus.delivered:
                statusBg = const Color(0xFFF0FDF4);
                statusText = const Color(0xFF16A34A);
                statusLabel = 'Delivered';
                break;
              case GiveawayWinnerStatus.cancelled:
                statusBg = const Color(0xFFFEF2F2);
                statusText = const Color(0xFFDC2626);
                statusLabel = 'Cancelled';
                break;
              case GiveawayWinnerStatus.requested:
                statusBg = const Color(0xFFF1F5F9);
                statusText = const Color(0xFF475569);
                statusLabel = 'Requested';
                break;
            }

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isSelf
                      ? const Color(0xFF26262B)
                      : const Color(0xFFE2E8F0),
                  width: isSelf ? 1.4 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    '#$rank',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26262B),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF26262E),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.white,
                      size: 15.sp,
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
                            color: const Color(0xFF26262B),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          w.reward.displayReward,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF64748B),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
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
