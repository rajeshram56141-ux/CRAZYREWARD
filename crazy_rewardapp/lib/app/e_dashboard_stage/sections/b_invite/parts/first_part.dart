import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../services/analytics_service.dart';
import '../../../../../utils/constant/constant.dart';
import '../../../../../widgets/common/custom_toast.dart';
import '../../../../../widgets/common/screen_banner_widget.dart';
import '../../../../b_splash_stage/splash_service.dart';
import '../../../provider/dashboard_provider.dart';
import '../model/referral_level_model.dart';
import '../provider/refer_data_provider.dart';

class InviteFirstPart extends HookConsumerWidget {
  const InviteFirstPart({
    super.key,
    required this.userId,
    required this.referred,
    required this.referralCode,
    required this.ref,
  });

  final String userId;
  final bool referred;
  final String referralCode;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String referralLink =
        '${AppConst.appBaseUrl}${SplashService.packageName}&referrer=$referralCode';

    final String content = SplashService.getFormattedShareText(
      referralCode: referralCode,
      referralLink: referralLink,
    );

    // Watch live stats and missions from ReferralService
    final refStatsAsync = ref.watch(ReferralService.referralStatsProvider);
    final refStats = refStatsAsync.value;

    final totalReferred = refStats?.totalReferred ??
        (ref.watch(ReferralService.totalCountProvider).value ?? 0);
    final totalEarning =
        ref.watch(ReferralService.totalEarningProvider).value ?? 0.0;
    final claimedList = refStats?.claimedMissions ??
        (ref.watch(ReferralService.claimedMissionsProvider).value ?? <String>[]);
    final isClaiming = useState<int?>(null);
    final showAllMissions = useState<bool>(false);
    final rawMissions = (refStats != null && refStats.missions.isNotEmpty)
        ? refStats.missions
        : SplashService.referralSettings.missions;
    final List<ReferralMissionModel> effectiveMissions = rawMissions;
    final bool isMissionsEnabled = (refStats?.missionsEnabled ??
        SplashService.referralSettings.missionsEnabled) && effectiveMissions.isNotEmpty;

    final displayedMissions = showAllMissions.value
        ? effectiveMissions
        : effectiveMissions.take(3).toList();

    String formatCompact(num val) {
      if (val >= 1000000) {
        double v = val / 1000000.0;
        return v % 1 == 0 ? '${v.toInt()}M' : '${v.toStringAsFixed(1)}M';
      } else if (val >= 1000) {
        double v = val / 1000.0;
        return v % 1 == 0 ? '${v.toInt()}k' : '${v.toStringAsFixed(1)}k';
      }
      return val.toInt().toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16.h),

        // -------------------------------------------------------------
        // 1. SHARE YOUR REFERRAL LINK & CODE
        // -------------------------------------------------------------
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Panda Hero Illustration
            Image.asset(
              'assets/icons/panda invite.png',
              height: 155.h,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 10.h),

            // Top Hero Title
            Text(
              'Invite & Earn Rewards!',
              textAlign: TextAlign.center,
              style: GoogleFonts.kaushanScript(
                color: const Color(0xFF26262B),
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Invite your friends & earn coins together!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16.h),

            // 1. Referral Link Box
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
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
                  Icon(
                    Icons.link_rounded,
                    color: const Color(0xFF26262B),
                    size: 19.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'LINK: ',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      referralLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF26262B),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: referralLink));
                      CustomToast.showToast(context, msg: 'Referral link copied!');
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
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
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: const Color(0xFF9CA3AF),
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Icons.copy_rounded,
                        color: const Color(0xFF16161A),
                        size: 14.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 10.h),

            // 2. Referral Code Box
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
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
                  Icon(
                    Icons.vpn_key_rounded,
                    color: const Color(0xFF26262B),
                    size: 17.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'CODE: ',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      referralCode.isNotEmpty ? referralCode : '---',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF26262B),
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: referralCode));
                      CustomToast.showToast(context, msg: 'Referral code copied!');
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF26262E),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: const Color(0xFF383842),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            color: Colors.white,
                            size: 12.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Copy',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14.h),

            // 3. Primary Button: Invite Friend (Silver Metallic)
            GestureDetector(
              onTap: () {
                AnalyticsService.logShareReferral(method: 'system_share');
                Share.share(content);
              },
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      color: const Color(0xFF16161A),
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Invite Friends',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF16161A),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // 4. "Invite on Social Media" Section
            Text(
              'Share Via',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),

            SizedBox(height: 10.h),

            // Social Media Action Icons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // WhatsApp
                _buildSocialIconItem(
                  assetPath: 'assets/icons/whatsapp.png',
                  label: 'WhatsApp',
                  onTap: () => _shareToWhatsApp(content),
                ),
                SizedBox(width: 16.w),

                // Telegram
                _buildSocialIconItem(
                  assetPath: 'assets/icons/telegram.png',
                  label: 'Telegram',
                  onTap: () => _shareToTelegram(content),
                ),
                SizedBox(width: 16.w),

                // Instagram
                _buildSocialIconItem(
                  assetPath: 'assets/icons/instagram.png',
                  label: 'Instagram',
                  onTap: () => _shareToInstagram(context, content),
                ),
                SizedBox(width: 16.w),

                // More Social
                _buildSocialIconItem(
                  assetPath: 'assets/icons/social-media.png',
                  label: 'More',
                  onTap: () {
                    AnalyticsService.logShareReferral(method: 'more_social');
                    Share.share(content);
                  },
                ),
              ],
            ),
          ],
        ),

        const ScreenBannerWidget(
          screenKey: 'inviteScreen',
          margin: EdgeInsets.only(top: 14.0, bottom: 6.0),
        ),

        SizedBox(height: 16.h),

        // -------------------------------------------------------------
        // 2. "YOUR STATS" SECTION (2 HORIZONTAL STAT CARDS)
        // -------------------------------------------------------------
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
              'Your Stats',
              style: GoogleFonts.poppins(
                color: const Color(0xFF26262B),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        SizedBox(height: 12.h),

        Row(
          children: [
            // Card 1: Total Referrals
            Expanded(
              child: _buildStatCard(
                value: '$totalReferred',
                label: 'Total Referrals',
              ),
            ),
            SizedBox(width: 10.w),

            // Card 2: Total Coins
            Expanded(
              child: _buildStatCard(
                value: totalEarning > 0 ? formatCompact(totalEarning) : '0',
                label: 'Total Coins',
              ),
            ),
          ],
        ),

        // -------------------------------------------------------------
        // 3. "MILESTONE REWARDS" SECTION
        // -------------------------------------------------------------
        if (isMissionsEnabled) ...[
          SizedBox(height: 24.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    'Milestone Rewards',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26262B),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  showAllMissions.value = !showAllMissions.value;
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(100.r),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    showAllMissions.value ? 'Show Less' : 'View All',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26262B),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16.h),

          // Stepper Milestone List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: displayedMissions.length,
            itemBuilder: (context, index) {
              final mission = displayedMissions[index];
              final int target = mission.target;
              final int reward = mission.reward;
              final String criteriaType = mission.criteriaType;
              final int currentProgress = criteriaType == 'direct'
                  ? totalReferred
                  : (mission.progress > 0 ? mission.progress : 0);

              final bool isClaimed = claimedList.contains(target.toString());
              final bool isUnlocked = currentProgress >= target || isClaimed;
              final bool isEligibleToClaim = isUnlocked && !isClaimed;
              final bool isLast = index == displayedMissions.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Stepper timeline
                  SizedBox(
                    width: 28.w,
                    child: Column(
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUnlocked
                                ? const Color(0xFF26262E)
                                : Colors.white,
                            border: Border.all(
                              color: isUnlocked
                                  ? const Color(0xFF26262E)
                                  : const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: isUnlocked
                              ? Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 13.sp,
                                )
                              : null,
                        ),
                        if (!isLast)
                          Container(
                            width: 2.w,
                            height: 42.h,
                            margin: EdgeInsets.symmetric(vertical: 2.h),
                            color: isUnlocked
                                ? const Color(0xFF26262E)
                                : const Color(0xFFE2E8F0),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(width: 10.w),

                  // Right: Mission Card
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: GestureDetector(
                        onTap: isEligibleToClaim
                            ? () async {
                                if (isClaiming.value != null) return;
                                isClaiming.value = target;
                                HapticFeedback.mediumImpact();
                                final res = await ReferralService.claimMission(target);
                                isClaiming.value = null;
                                if (res['success'] == true) {
                                  ref.invalidate(ReferralService.referralStatsProvider);
                                  ref.invalidate(ReferralService.claimedMissionsProvider);
                                  if (context.mounted) {
                                    CustomToast.showToast(
                                      context,
                                      msg: res['message'] ?? 'Claimed $reward coins!',
                                    );
                                  }
                                } else {
                                  if (context.mounted) {
                                    CustomToast.showToast(
                                      context,
                                      msg: res['message'] ?? 'Failed to claim',
                                    );
                                  }
                                }
                              }
                            : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: isUnlocked
                                  ? const Color(0xFF26262B)
                                  : const Color(0xFFE2E8F0),
                              width: 1.2,
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
                              Container(
                                width: 38.w,
                                height: 38.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: isUnlocked
                                    ? Icon(
                                        Icons.verified_user_rounded,
                                        color: const Color(0xFF16A34A),
                                        size: 20.sp,
                                      )
                                    : Image.asset(
                                        'assets/icons/coin.png',
                                        width: 20.w,
                                        height: 20.w,
                                        fit: BoxFit.contain,
                                      ),
                              ),

                              SizedBox(width: 12.w),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      mission.title.isNotEmpty
                                          ? mission.title
                                          : 'Unlock at $target invite',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF26262B),
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (isEligibleToClaim) ...[
                                      SizedBox(height: 2.h),
                                      Text(
                                        isClaiming.value == target
                                            ? 'Claiming...'
                                            : 'Tap to Claim Reward!',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF16A34A),
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              SizedBox(width: 8.w),

                              // Dark Coin Badge
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF26262E),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: const Color(0xFF383842),
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
                                      '+${formatCompact(reward)}',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (!isUnlocked) ...[
                                      SizedBox(width: 4.w),
                                      Icon(
                                        Icons.lock_rounded,
                                        color: const Color(0xFF94A3B8),
                                        size: 11.sp,
                                      ),
                                    ],
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
              );
            },
          ),

          SizedBox(height: 20.h),
        ] else
          SizedBox(height: 24.h),

        // -------------------------------------------------------------
        // 4. HOW IT WORKS
        // -------------------------------------------------------------
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
                    'How It Works?',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26262B),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 14.h),

              // Step 1: Share Link
              _buildHowItWorksStep(
                step: '01',
                title: 'Share Your Link',
                desc: 'Send your referral link or code to your friends.',
                icon: Icons.send_rounded,
              ),

              SizedBox(height: 10.h),

              // Step 2: Friend Gets Welcome Bonus
              _buildHowItWorksStep(
                step: '02',
                title: 'Friend Gets Welcome Bonus',
                desc: 'Your friend gets instant welcome bonus coins on joining.',
                icon: Icons.card_giftcard_rounded,
              ),

              SizedBox(height: 10.h),

              // Step 3: Commission Perk
              Builder(
                builder: (context) {
                  final String currentRewardMode = refStats?.rewardMode ?? SplashService.referralSettings.rewardMode;
                  final bool isAllMode = currentRewardMode == 'all';
                  final int commPercent = (refStats?.allCommissionPercent ?? SplashService.referralSettings.allCommissionPercent) > 0
                      ? (refStats?.allCommissionPercent ?? SplashService.referralSettings.allCommissionPercent)
                      : 10;

                  return _buildHowItWorksStep(
                    step: '03',
                    title: isAllMode
                        ? 'Get $commPercent% Commission'
                        : 'You Get 3-Tier Perks',
                    desc: isAllMode
                        ? 'Earn $commPercent% lifetime commission every time your referred friends complete tasks & earn coins!'
                        : 'Unlock rewards whenever your 3-level squad plays games, surveys & offerwalls!',
                    icon: Icons.stars_rounded,
                  );
                },
              ),
            ],
          ),
        ),

        SizedBox(height: 20.h),

        // -------------------------------------------------------------
        // 5. ENTER REFERRAL CODE (If not referred)
        // -------------------------------------------------------------
        if (!referred) _buildEnterReferralCodeCard(context, ref),
      ],
    );
  }

  // -------------------------------------------------------------
  // HELPER WIDGETS
  // -------------------------------------------------------------
  Widget _buildStatCard({
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp(String content) async {
    AnalyticsService.logShareReferral(method: 'whatsapp');
    final Uri uri = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(content)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Share.share(content);
      }
    } catch (_) {
      Share.share(content);
    }
  }

  Future<void> _shareToTelegram(String content) async {
    AnalyticsService.logShareReferral(method: 'telegram');
    final Uri uri = Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(content)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Share.share(content);
      }
    } catch (_) {
      Share.share(content);
    }
  }

  Future<void> _shareToInstagram(BuildContext context, String content) async {
    AnalyticsService.logShareReferral(method: 'instagram');
    Clipboard.setData(ClipboardData(text: content));
    CustomToast.showToast(context, msg: 'Link copied! Opening Instagram...');
    final Uri uri = Uri.parse('instagram://');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final Uri webUri = Uri.parse('https://instagram.com');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          Share.share(content);
        }
      }
    } catch (_) {
      Share.share(content);
    }
  }

  Widget _buildSocialIconItem({
    required String assetPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
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
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksStep({
    required String step,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: const Color(0xFF26262E),
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 18.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $step',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF26262B),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF64748B),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterReferralCodeCard(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();
    final isApplying = ValueNotifier<bool>(false);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
                'Have a Referral Code?',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF26262B),
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Enter your friend\'s referral code to get bonus coins',
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44.h,
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: codeController,
                    cursorColor: const Color(0xFF26262B),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26262B),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter code here...',
                      hintStyle: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12.sp,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              GestureDetector(
                onTap: () async {
                  final code = codeController.text.trim();
                  if (code.isEmpty) {
                    CustomToast.showToast(context, msg: 'Please enter a code');
                    return;
                  }
                  isApplying.value = true;
                  try {
                    final res = await ReferralService.applyReferralCode(code);
                    if (res['success'] == true) {
                      ref.invalidate(DashboardService.userDataProvider(userId));
                      ref.invalidate(ReferralService.referralStatsProvider);
                      if (context.mounted) {
                        CustomToast.showToast(
                          context,
                          msg: res['message'] ?? 'Referral code applied successfully!',
                        );
                      }
                    } else {
                      if (context.mounted) {
                        CustomToast.showToast(
                          context,
                          msg: res['message'] ?? 'Failed to apply code',
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      CustomToast.showToast(context, msg: 'Failed to apply code');
                    }
                  }
                  isApplying.value = false;
                },
                child: Container(
                  height: 44.h,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
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
                    borderRadius: BorderRadius.circular(12.r),
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
                  alignment: Alignment.center,
                  child: Text(
                    'Apply',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF16161A),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
