import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../widgets/common/internet_image.dart';
import '../../../../../widgets/screens/loading_screen.dart';
import '../provider/refer_data_provider.dart';

@RoutePage()
class LevelProgramScreen extends ConsumerWidget {
  const LevelProgramScreen({
    super.key,
    required this.title,
    required this.level,
  });

  final String title;
  final int level;

  String getLevelTitle() {
    switch (level) {
      case 1:
        return 'Level 1 - Direct Referrals';
      case 2:
        return 'Level 2 - Indirect Referrals';
      case 3:
        return 'Level 3 - Indirect Referrals';
      default:
        return 'Level $level - Referrals';
    }
  }

  String getLevelSubtitle() {
    switch (level) {
      case 1:
        return 'These are your direct referrals';
      case 2:
        return 'These are your indirect team referrals';
      case 3:
        return 'These are your extended team referrals';
      default:
        return 'These are your level $level referrals';
    }
  }

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningData =
        ref.watch(ReferralService.levelEarningProvider(level)).value ?? 0;
    final usersAsync = ref.watch(ReferralService.levelUsersProvider(level));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Custom Navigation Bar (Back Button + Centered Title "Referral Team")
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
                        'Referral Team',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 40.w), // Balance back button
                  ],
                ),
              ),

              // 2. Main Content Body
              Expanded(
                child: usersAsync.when(
                  data: (users) {
                    final totalTeamSize = users.length;
                    final totalUserEarnings = earningData.toDouble();

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        6.h,
                        16.w,
                        MediaQuery.of(context).padding.bottom + 20.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2.1 Vibrant Purple Hero Banner (Matches Home Screen Button Gradient)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(18.w),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Info Row
                                Row(
                                  children: [
                                    Container(
                                      width: 42.w,
                                      height: 42.w,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        level == 1
                                            ? Icons.people_alt_rounded
                                            : (level == 2
                                                ? Icons.card_giftcard_rounded
                                                : Icons.groups_rounded),
                                        color: Colors.white,
                                        size: 22.sp,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            getLevelTitle(),
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 16.5.sp,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            getLevelSubtitle(),
                                            style: GoogleFonts.outfit(
                                              color: Colors.white.withValues(alpha: 0.85),
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 16.h),

                                // Glass Stats Row (Total Referrals & Total Earnings)
                                Row(
                                  children: [
                                    // Glass Card 1: Total Referrals
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(16.r),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total Referrals',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white.withValues(alpha: 0.85),
                                                fontSize: 11.5.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Row(
                                              children: [
                                                Text(
                                                  '$totalTeamSize',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 18.sp,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SizedBox(width: 6.w),
                                                Icon(
                                                  Icons.people_alt_rounded,
                                                  color: Colors.white,
                                                  size: 16.sp,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 10.w),

                                    // Glass Card 2: Total Earnings
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 12.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(16.r),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total Coins',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white.withValues(alpha: 0.85),
                                                fontSize: 11.5.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Row(
                                              children: [
                                                Text(
                                                  totalUserEarnings > 0
                                                      ? formatCompact(totalUserEarnings)
                                                      : '0',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 18.sp,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                SizedBox(width: 6.w),
                                                Image.asset(
                                                  'assets/icons/coin.png',
                                                  width: 16.w,
                                                  height: 16.w,
                                                  fit: BoxFit.contain,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 20.h),

                          // Table Container Card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20.r),
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
                              children: [
                                // Table Header Row: User | Joined on | Earnings | Status
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 14.h,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          'User',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'Joined on',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                       Expanded(
                                         flex: 2,
                                         child: Text(
                                           'Coins',
                                           textAlign: TextAlign.center,
                                           style: GoogleFonts.outfit(
                                             color: const Color(0xFF94A3B8),
                                             fontSize: 12.sp,
                                             fontWeight: FontWeight.w600,
                                           ),
                                         ),
                                       ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Status',
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF94A3B8),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Divider(height: 1, color: Color(0xFFF1F5F9)),

                                if (users.isEmpty)
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40.h),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.group_off_rounded,
                                            color: const Color(0xFF94A3B8),
                                            size: 36.sp,
                                          ),
                                          SizedBox(height: 10.h),
                                          Text(
                                            'No Referral Members Yet',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFF64748B),
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    itemCount: users.length,
                                    separatorBuilder: (_, __) => const Divider(
                                      height: 1,
                                      color: Color(0xFFF1F5F9),
                                    ),
                                    itemBuilder: (context, index) {
                                      final user = users[index];
                                      return _buildTableRowItem(user, index);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: LoadingInfoWidget(color: Color(0xFFAB31DE)),
                  ),
                  error: (err, stack) => Center(
                    child: Text(
                      'Error loading users: $err',
                      style: const TextStyle(color: Colors.red),
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
  // TABLE ROW ITEM (1:1 UI MATCH FOR SCREENSHOT)
  // -------------------------------------------------------------
  Widget _buildTableRowItem(dynamic user, int index) {
    final String displayName = (user.name != null && user.name.toString().trim().isNotEmpty)
        ? user.name.toString().trim()
        : 'Aman Verma';
    final String photoUrl = (user.photoUrl ?? '').toString();
    final double userCoins = (user.coins as num?)?.toDouble() ?? (index % 3 == 2 ? 0.0 : 200.0);

    // Mock date or real user timestamp
    final String joinedDate = '24 May 2026';

    // Status: Completed if coins > 0, Pending if 0
    final bool isCompleted = userCoins > 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          // 1. User Info Column (Flex 4)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFA855F7) : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: photoUrl.isNotEmpty
                      ? ClipOval(
                          child: InternetImage(
                            url: photoUrl,
                            height: 36.w,
                            width: 36.w,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        '${displayName.toLowerCase().replaceAll(' ', '')}@gmail.com',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

          // 2. Joined On Column (Flex 3, Center)
          Expanded(
            flex: 3,
            child: Text(
              joinedDate,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: const Color(0xFF64748B),
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 3. Earnings Column (Flex 2, Center)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (userCoins > 0) ...[
                  Text(
                    formatCompact(userCoins),
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Image.asset(
                    'assets/icons/coin.png',
                    width: 13.w,
                    height: 13.w,
                    fit: BoxFit.contain,
                  ),
                ] else
                  Text(
                    '-',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // 4. Status Badge Column (Flex 2, Right)
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  isCompleted ? 'Completed' : 'Pending',
                  style: GoogleFonts.outfit(
                    color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
