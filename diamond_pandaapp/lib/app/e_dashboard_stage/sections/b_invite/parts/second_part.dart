import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../b_splash_stage/splash_service.dart';
import '../../../../../utils/routes/routes_import.gr.dart';
import '../model/referral_level_model.dart';
import '../provider/refer_data_provider.dart';

class InviteSecondPart extends HookConsumerWidget {
  const InviteSecondPart({super.key, required this.userId, WidgetRef? ref});

  final String userId;

  IconData _getTaskIcon(String key) {
    switch (key) {
      case 'dailyTask':
        return Icons.task_alt_rounded;
      case 'hotOffer':
        return Icons.local_fire_department_rounded;
      case 'offerwall':
        return Icons.view_carousel_rounded;
      case 'survey':
        return Icons.poll_rounded;
      case 'playGames':
        return Icons.sports_esports_rounded;
      case 'readEarn':
        return Icons.menu_book_rounded;
      case 'watchEarn':
        return Icons.play_circle_fill_rounded;
      case 'playWin':
        return Icons.videogame_asset_rounded;
      case 'promoCode':
        return Icons.confirmation_number_rounded;
      case 'referral':
        return Icons.people_alt_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = useState<int>(1); // Level 1, 2, 3 selection

    final levelData = activeTab.value == 1
        ? SplashService.referralSettings.firstLevel
        : (activeTab.value == 2
            ? SplashService.referralSettings.secondLevel
            : SplashService.referralSettings.thirdLevel);

    final taskList = levelData.values.entries.toList();

    final l1Percent = ReferralSettings.getCommissionPercent(1);
    final l2Percent = ReferralSettings.getCommissionPercent(2);
    final l3Percent = ReferralSettings.getCommissionPercent(3);
    final totalMaxPercent = (l1Percent + l2Percent + l3Percent) > 0
        ? (l1Percent + l2Percent + l3Percent)
        : (l1Percent > 0 ? l1Percent : 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 6.h),

        // -------------------------------------------------------------
        // 1. HERO COMMISSION SHOWCASE (3-TIER PASSIVE REWARDS)
        // -------------------------------------------------------------
        _buildHeroCommissionBanner(
          maxPercent: totalMaxPercent,
          l1: l1Percent,
          l2: l2Percent,
          l3: l3Percent,
        ),

        SizedBox(height: 24.h),

        // -------------------------------------------------------------
        // 2. YOUR REFERRAL TEAM TIERS (LEVEL A, B, C CARDS)
        // -------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hub_rounded,
                  color: const Color(0xFFAB31DE),
                  size: 19.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Your Referral Team',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 16.5.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Text(
              '3 Levels Network',
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        SizedBox(height: 12.h),

        // Level 1 (Direct Referrals)
        const _ModernLevelTierCard(
          level: 1,
          title: 'Level 1',
          subtitle: 'Direct referrals',
          iconData: Icons.people_alt_rounded,
          iconBgColor: Color(0xFFF3E8FF),
          themeColor: Color(0xFFAB31DE),
        ),

        // Level 2 (Indirect Referrals)
        const _ModernLevelTierCard(
          level: 2,
          title: 'Level 2',
          subtitle: 'Indirect referrals',
          iconData: Icons.card_giftcard_rounded,
          iconBgColor: Color(0xFFDCFCE7),
          themeColor: Color(0xFF16A34A),
        ),

        // Level 3 (Indirect Referrals)
        const _ModernLevelTierCard(
          level: 3,
          title: 'Level 3',
          subtitle: 'Indirect referrals',
          iconData: Icons.groups_rounded,
          iconBgColor: Color(0xFFFCE7F3),
          themeColor: Color(0xFFE11D48),
        ),

        SizedBox(height: 24.h),

        // -------------------------------------------------------------
        // 3. TASK COMMISSION RATES BREAKDOWN
        // -------------------------------------------------------------

        // Level Selector Tabs (Level A, Level B, Level C)
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: const Color(0xFFE9D5FF),
              width: 1,
            ),
          ),
          child: Row(
            children: List.generate(3, (index) {
              final levelNum = index + 1;
              final isSelected = activeTab.value == levelNum;
              final percent = levelNum == 1
                  ? (l1Percent > 0 ? l1Percent : 10)
                  : (levelNum == 2
                      ? (l2Percent > 0 ? l2Percent : 5)
                      : (l3Percent > 0 ? l3Percent : 3));
              final String levelName = 'Level $levelNum ($percent%)';

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    activeTab.value = levelNum;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(vertical: 9.h),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      levelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        SizedBox(height: 14.h),

        // Grid of Task Commissions
        if (taskList.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: Center(
              child: Text(
                'No commission tasks found',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B),
                  fontSize: 12.sp,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: taskList.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.35,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
            ),
            itemBuilder: (context, index) {
              final task = taskList[index];
              final String taskKey = task.key;
              final double commission = task.value.toDouble();
              final icon = _getTaskIcon(taskKey);

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: const Color(0xFFE9D5FF),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: const Color(0xFFE9D5FF),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        color: const Color(0xFFAB31DE),
                        size: 18.sp,
                      ),
                    ),
                    SizedBox(width: 9.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            taskKey.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              '+$commission% Extra',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFAB31DE),
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
  // HERO COMMISSION SHOWCASE BANNER
  // -------------------------------------------------------------
  Widget _buildHeroCommissionBanner({
    required int maxPercent,
    required int l1,
    required int l2,
    required int l3,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: const Color(0xFFE9D5FF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '3-TIER SQUAD PERKS',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFAB31DE),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Build Your Squad',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'Unlock rewards whenever your friends & team play!',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          // Illustration / Icon
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFE9D5FF),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/icons/panda invite.png',
              width: 52.w,
              height: 52.w,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/icons/coin.png',
                  width: 36.w,
                  height: 36.w,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MODERN LEVEL TIER CARD (STATE-OF-THE-ART GLASSMORPHIC DESIGN)
// -----------------------------------------------------------------------------
class _ModernLevelTierCard extends ConsumerWidget {
  final int level;
  final String title;
  final String subtitle;
  final IconData iconData;
  final Color iconBgColor;
  final Color themeColor;

  const _ModernLevelTierCard({
    required this.level,
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.iconBgColor,
    required this.themeColor,
  });

  String _formatCompact(num val) {
    if (val >= 1000000) {
      double v = val / 1000000.0;
      return v % 1 == 0 ? '${v.toInt()}M' : '${v.toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      double v = val / 1000.0;
      return v % 1 == 0 ? '${v.toInt()}k' : '${v.toStringAsFixed(1)}k';
    }
    return val.toInt().toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(ReferralService.levelCountProvider(level));
    final earningAsync = ref.watch(ReferralService.levelEarningProvider(level));

    final count = countAsync.value ?? 0;
    final earning = earningAsync.value ?? 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          AutoRouter.of(context).push(
            LevelProgramScreenRoute(
              title: '$title – $subtitle',
              level: level,
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFFE9D5FF),
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
          child: Row(
            children: [
              // 1. Icon + Title + Subtitle (Left Section)
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  iconData,
                  color: themeColor,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: themeColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Vertical Divider 1
              Container(
                width: 1.w,
                height: 28.h,
                color: const Color(0xFFE2E8F0),
              ),

              // 2. People Stat (Middle Section)
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'People',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _formatCompact(count),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              // Vertical Divider 2
              Container(
                width: 1.w,
                height: 28.h,
                color: const Color(0xFFE2E8F0),
              ),

              // 3. Coins Earned Stat (Right Section)
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Coins',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          earning > 0 ? _formatCompact(earning) : '0',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Image.asset(
                          'assets/icons/coin.png',
                          width: 15.w,
                          height: 15.w,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: 4.w),

              // 4. Navigation Arrow Icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF94A3B8),
                size: 13.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
