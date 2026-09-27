import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../widgets/common/internet_image.dart';
import '../../../../../../widgets/common/custom_loading.dart';
import 'battle_arena_provider.dart';

class BattleLeaderboardHistoryScreen extends StatefulWidget {
  const BattleLeaderboardHistoryScreen({super.key, required this.userId});
  final String userId;

  @override
  State<BattleLeaderboardHistoryScreen> createState() => _BattleLeaderboardHistoryScreenState();
}

class _BattleLeaderboardHistoryScreenState extends State<BattleLeaderboardHistoryScreen> {
  int _activeTab = 0; // 0: All, 1: Today, 2: Yesterday
  late Future<List<dynamic>> _historyFuture;
  final Set<int> _expandedIndices = {};

  String get _selectedFilter {
    if (_activeTab == 1) return 'today';
    if (_activeTab == 2) return 'yesterday';
    return 'all';
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = BattleArenaService.instance.fetchLeaderboardHistory(
        userId: widget.userId,
        filter: _selectedFilter,
      );
    });
  }

  String _formatCoins(dynamic coins) {
    final double val = (coins is num) ? coins.toDouble() : 0.0;
    if (val >= 1000) {
      final double kVal = val / 1000.0;
      if (kVal % 1 == 0) {
        return '${kVal.toInt()}k';
      }
      return '${kVal.toStringAsFixed(1)}k';
    }
    return '${val.toInt()}';
  }

  String _formatDate(String? isoStr) {
    if (isoStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute $period';
    } catch (_) {
      return isoStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          color: const Color(0xFFAB31DE),
          backgroundColor: Colors.white,
          edgeOffset: topPadding + 60.h,
          onRefresh: () async {
            _loadHistory();
            await _historyFuture;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16.w,
              topPadding + 8.h,
              16.w,
              bottomPadding + 24.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Header Bar
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).maybePop();
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
                        'Leaderboard History',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1E1B4B),
                          fontSize: 18.5.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Segmented Category Tabs (ALL / TODAY / YESTERDAY)
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: const Color(0xFFF3E8FF),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        label: 'ALL',
                        tabIndex: 0,
                        icon: Icons.history_rounded,
                      ),
                      SizedBox(width: 4.w),
                      _buildTabButton(
                        label: 'TODAY',
                        tabIndex: 1,
                        icon: Icons.today_rounded,
                      ),
                      SizedBox(width: 4.w),
                      _buildTabButton(
                        label: 'YESTERDAY',
                        tabIndex: 2,
                        icon: Icons.event_repeat_rounded,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // History Records Content
                FutureBuilder<List<dynamic>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 300.h,
                        child: const Center(child: GlowLightingSpinner(size: 28)),
                      );
                    }

                    final rawRecords = snapshot.data ?? [];
                    final records = rawRecords.take(30).toList();
                    if (records.isEmpty) {
                      return SizedBox(
                        height: 300.h,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off_rounded, color: const Color(0xFFAB31DE), size: 48.sp),
                              SizedBox(height: 12.h),
                              Text(
                                _activeTab == 1
                                    ? 'No Records for Today'
                                    : (_activeTab == 2
                                        ? 'No Records for Yesterday'
                                        : 'No Past Tournament Records'),
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF1E1B4B),
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Records will appear once tournament cycles complete.',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final item = records[index];
                        final winners = (item['winners'] as List<dynamic>?) ?? [];
                        final String statusStr = (item['status']?.toString() ?? 'APPROVED').toUpperCase();
                        final bool isPending = statusStr == 'PENDING';
                        final declaredAtStr = isPending
                            ? 'Result Preparing...'
                            : _formatDate(item['resultDeclaredAt'] ?? item['createdAt']);
                        final bool showWinnersOnly = item['showWinnersOnly'] == true;

                        final rank1 = winners.firstWhere((w) => w['rank'] == 1, orElse: () => null);
                        final rank2 = winners.firstWhere((w) => w['rank'] == 2, orElse: () => null);
                        final rank3 = winners.firstWhere((w) => w['rank'] == 3, orElse: () => null);
                        final restWinners = winners.where((w) => (w['rank'] ?? 0) > 3).toList();

                        final bool isExpanded = _expandedIndices.contains(index);

                        return Container(
                          margin: EdgeInsets.only(bottom: 14.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18.r),
                            border: Border.all(
                              color: isExpanded
                                  ? const Color(0xFFAB31DE)
                                  : const Color(0xFFF1F5F9),
                              width: isExpanded ? 1.5 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isExpanded
                                    ? const Color(0xFFAB31DE).withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card Header: Status Badge, Date & Rank 1 Profile
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedIndices.remove(index);
                                    } else {
                                      _expandedIndices.add(index);
                                    }
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: EdgeInsets.all(14.r),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       // Top Meta Row: Status Badge and Date
                                       Row(
                                         children: [
                                           Container(
                                             padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.5.h),
                                             decoration: BoxDecoration(
                                               color: isPending
                                                   ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                                                   : const Color(0xFF10B981).withValues(alpha: 0.12),
                                               borderRadius: BorderRadius.circular(8.r),
                                               border: Border.all(
                                                 color: isPending
                                                     ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                                                     : const Color(0xFF10B981).withValues(alpha: 0.35),
                                                 width: 1.0,
                                               ),
                                             ),
                                             child: Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 Icon(
                                                   isPending
                                                       ? Icons.hourglass_top_rounded
                                                       : Icons.check_circle_rounded,
                                                   color: isPending
                                                       ? const Color(0xFFD97706)
                                                       : const Color(0xFF10B981),
                                                   size: 11.sp,
                                                 ),
                                                 SizedBox(width: 4.w),
                                                 Text(
                                                   isPending ? 'PENDING' : 'DECLARED',
                                                   style: GoogleFonts.outfit(
                                                     color: isPending
                                                         ? const Color(0xFFD97706)
                                                         : const Color(0xFF10B981),
                                                     fontSize: 9.5.sp,
                                                     fontWeight: FontWeight.w900,
                                                     letterSpacing: 0.4,
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           ),
                                           SizedBox(width: 8.w),
                                           Expanded(
                                             child: Text(
                                               declaredAtStr,
                                               style: GoogleFonts.outfit(
                                                 color: isPending
                                                     ? const Color(0xFFD97706)
                                                     : const Color(0xFF64748B),
                                                 fontSize: 11.5.sp,
                                                 fontWeight: isPending ? FontWeight.w700 : FontWeight.w600,
                                               ),
                                               maxLines: 1,
                                               overflow: TextOverflow.ellipsis,
                                             ),
                                           ),
                                         ],
                                       ),

                                      SizedBox(height: 12.h),

                                      // Rank 1 Champion Profile Card
                                      Container(
                                        padding: EdgeInsets.all(10.r),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFFFBEB),
                                              Color(0xFFFEF3C7),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(14.r),
                                          border: Border.all(
                                            color: const Color(0xFFFDE68A),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            // Avatar with Gold Ring, Crown & #1 Badge
                                            Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.topCenter,
                                              children: [
                                                // Gold Crown
                                                Positioned(
                                                  top: -9.h,
                                                  child: SizedBox(
                                                    width: 18.w,
                                                    height: 11.h,
                                                    child: const CustomPaint(
                                                      painter: _GoldenCrownPainter(),
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  width: 44.w,
                                                  height: 44.w,
                                                  margin: EdgeInsets.only(top: 4.h),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: const Color(0xFFFFB800),
                                                      width: 2.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFFFFB800).withValues(alpha: 0.35),
                                                        blurRadius: 6,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipOval(
                                                    child: Container(
                                                      color: const Color(0xFFFFFDF0),
                                                      child: (() {
                                                        if (rank1 == null) {
                                                          return Icon(
                                                            Icons.emoji_events_rounded,
                                                            color: const Color(0xFFD97706),
                                                            size: 22.sp,
                                                          );
                                                        }
                                                        final String avatarUrl = rank1['avatar']?.toString() ?? '';
                                                        final String winnerName = rank1['userName']?.toString() ?? 'Winner';
                                                        return avatarUrl.isNotEmpty && avatarUrl != 'null'
                                                            ? AvatarInternetImage(
                                                                url: avatarUrl,
                                                                size: 44.w,
                                                              )
                                                            : Center(
                                                                child: Text(
                                                                  winnerName.isNotEmpty ? winnerName.substring(0, 1).toUpperCase() : 'W',
                                                                  style: GoogleFonts.outfit(
                                                                    color: const Color(0xFFB45309),
                                                                    fontSize: 16.sp,
                                                                    fontWeight: FontWeight.w900,
                                                                  ),
                                                                ),
                                                              );
                                                      })(),
                                                    ),
                                                  ),
                                                ),
                                                // #1 Badge
                                                Positioned(
                                                  bottom: -4.h,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFFFFE500), Color(0xFFFF9900)],
                                                      ),
                                                      borderRadius: BorderRadius.circular(6.r),
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 1.0,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.15),
                                                          blurRadius: 3,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Text(
                                                      '#1',
                                                      style: GoogleFonts.outfit(
                                                        color: const Color(0xFF78350F),
                                                        fontSize: 9.sp,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),

                                            SizedBox(width: 12.w),

                                            // Winner Name & Score
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          rank1 != null
                                                              ? (rank1['userName']?.toString().trim().isNotEmpty == true
                                                                  ? rank1['userName'].toString()
                                                                  : 'Player')
                                                              : (isPending ? 'Calculating Winner...' : 'No Winner Recorded'),
                                                          style: GoogleFonts.outfit(
                                                            color: const Color(0xFF1E1B4B),
                                                            fontSize: 13.5.sp,
                                                            fontWeight: FontWeight.w900,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      SizedBox(width: 4.w),
                                                      Icon(
                                                        Icons.verified_rounded,
                                                        color: const Color(0xFFD97706),
                                                        size: 13.sp,
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  if (rank1 != null)
                                                    Text(
                                                      '${rank1['totalSpeedPoints'] ?? 0} Pts • ${rank1['winsCount'] ?? 0} Wins',
                                                      style: GoogleFonts.outfit(
                                                        color: const Color(0xFF78350F),
                                                        fontSize: 11.sp,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),

                                            SizedBox(width: 6.w),

                                            // Reward Coins Pill Badge
                                            if (rank1 != null && ((rank1['coinsAwarded'] ?? rank1['rewardCoins'] ?? 0) > 0))
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.5.h),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  ),
                                                  borderRadius: BorderRadius.circular(12.r),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFFAB31DE).withValues(alpha: 0.30),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
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
                                                    SizedBox(width: 3.w),
                                                    Text(
                                                      '+${_formatCoins(rank1['coinsAwarded'] ?? rank1['rewardCoins'])}',
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white,
                                                        fontSize: 11.5.sp,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 10.h),

                                      // View All Button
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(vertical: 7.5.h),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAF5FF),
                                          borderRadius: BorderRadius.circular(10.r),
                                          border: Border.all(
                                            color: isExpanded ? const Color(0xFFE9D5FF) : const Color(0xFFF3E8FF),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              isExpanded ? 'Hide Details' : 'View All',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFFAB31DE),
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            SizedBox(width: 4.w),
                                            Icon(
                                              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                              color: const Color(0xFFAB31DE),
                                              size: 16.sp,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Expandable Details Panel
                              if (isExpanded) ...[
                                const Divider(
                                  color: Color(0xFFF1F5F9),
                                  height: 1,
                                  thickness: 1,
                                ),
                                if (isPending)
                                  Container(
                                    margin: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(10.r),
                                      border: Border.all(
                                        color: const Color(0xFFFDE68A),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: const Color(0xFFD97706),
                                          size: 15.sp,
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            'Results are being verified. Reward coins will be credited soon.',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFFB45309),
                                              fontSize: 11.5.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                SizedBox(height: 14.h),

                                // Top 3 Podium Visual Section
                                if (winners.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                                    child: _HistoryPodiumStage(
                                      rank1: rank1,
                                      rank2: rank2,
                                      rank3: rank3,
                                      showWinnersOnly: showWinnersOnly,
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: EdgeInsets.all(16.r),
                                    child: Text(
                                      'No rankers recorded for this cycle.',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF64748B),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                SizedBox(height: 16.h),

                                // Rest Rankers List below Top 3
                                if (restWinners.isNotEmpty) ...[
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                                    child: Text(
                                      'OTHER RANKERS',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFFAB31DE),
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  ...restWinners.map((w) {
                                    final int rank = w['rank'] ?? 0;
                                    final String name = w['userName']?.toString() ?? 'Player';
                                    final int winsCount = w['winsCount'] ?? 0;
                                    final int pts = w['totalSpeedPoints'] ?? 0;
                                    final int coins = w['coinsAwarded'] ?? 0;
                                    final String avatarUrl = w['avatar']?.toString() ?? '';

                                    return Container(
                                      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAF5FF),
                                        borderRadius: BorderRadius.circular(12.r),
                                        border: Border.all(
                                          color: const Color(0xFFF3E8FF),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Rank Badge Pill
                                          Container(
                                            width: 26.r,
                                            height: 26.r,
                                            alignment: Alignment.center,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '#$rank',
                                              style: GoogleFonts.outfit(
                                                color: const Color(0xFFAB31DE),
                                                fontSize: 11.sp,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10.w),

                                          // Avatar Circle
                                          CircleAvatar(
                                            radius: 16.r,
                                            backgroundColor: Colors.white,
                                            child: avatarUrl.isNotEmpty && avatarUrl != 'null'
                                                ? ClipOval(
                                                    child: AvatarInternetImage(
                                                      url: avatarUrl,
                                                      size: 32.r,
                                                    ),
                                                  )
                                                : Text(
                                                    name.substring(0, name.isNotEmpty ? 1 : 0).toUpperCase(),
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(0xFFAB31DE),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                          SizedBox(width: 10.w),

                                          // Name & Stats
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFF1E1B4B),
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 1.h),
                                                Text(
                                                  '$pts Pts • $winsCount Wins',
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(0xFF64748B),
                                                    fontSize: 10.5.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Prize Coins Badge
                                          if (coins > 0)
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.5.h),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(8.r),
                                                border: Border.all(
                                                  color: const Color(0xFFF3E8FF),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Image.asset(
                                                    'assets/icons/coin.png',
                                                    height: 13.w,
                                                    width: 13.w,
                                                    fit: BoxFit.contain,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    '+${_formatCoins(coins)}',
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(0xFFAB31DE),
                                                      fontSize: 11.5.sp,
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                  SizedBox(height: 12.h),
                                ],
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required int tabIndex,
    required IconData icon,
  }) {
    final isSelected = _activeTab == tabIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_activeTab != tabIndex) {
            HapticFeedback.lightImpact();
            setState(() {
              _activeTab = tabIndex;
              _expandedIndices.clear();
            });
            _loadHistory();
          }
        },
        child: Container(
          height: 38.h,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                size: 14.sp,
              ),
              SizedBox(width: 4.w),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontSize: 11.5.sp,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Podium Stage Component for History Screen
// ------------------------------------------------------------------
class _HistoryPodiumStage extends StatelessWidget {
  final dynamic rank1;
  final dynamic rank2;
  final dynamic rank3;
  final bool showWinnersOnly;

  const _HistoryPodiumStage({
    this.rank1,
    this.rank2,
    this.rank3,
    this.showWinnersOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _HistoryPodiumBlock(rank: 2, avatarSize: 48.w, player: rank2, showWinnersOnly: showWinnersOnly, isCenter: false)),
          SizedBox(width: 6.w),
          Expanded(child: _HistoryPodiumBlock(rank: 1, avatarSize: 54.w, player: rank1, showWinnersOnly: showWinnersOnly, isCenter: true)),
          SizedBox(width: 6.w),
          Expanded(child: _HistoryPodiumBlock(rank: 3, avatarSize: 48.w, player: rank3, showWinnersOnly: showWinnersOnly, isCenter: false)),
        ],
      ),
    );
  }
}

class _HistoryPodiumBlock extends StatelessWidget {
  final int rank;
  final double avatarSize;
  final dynamic player;
  final bool showWinnersOnly;
  final bool isCenter;

  const _HistoryPodiumBlock({
    required this.rank,
    required this.avatarSize,
    this.player,
    this.showWinnersOnly = false,
    required this.isCenter,
  });

  String _formatCoins(dynamic coins) {
    final double val = (coins is num) ? coins.toDouble() : 0.0;
    if (val >= 1000) {
      final double kVal = val / 1000.0;
      if (kVal % 1 == 0) {
        return '${kVal.toInt()}k';
      }
      return '${kVal.toStringAsFixed(1)}k';
    }
    return '${val.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final String rawName = player?['userName']?.toString() ?? '-';
    final String name = rawName.trim().isNotEmpty ? rawName.trim().split(' ').first : '-';
    final int winsCount = player?['winsCount'] ?? 0;
    final int totalSpeedPoints = player?['totalSpeedPoints'] ?? 0;
    final int coinsAwarded = player?['coinsAwarded'] ?? 0;
    final bool hasPlayer = player != null;

    final Color ringColor;

    if (rank == 1) {
      ringColor = const Color(0xFFFFB800); // Gold
    } else if (rank == 2) {
      ringColor = const Color(0xFF94A3B8); // Silver
    } else {
      ringColor = const Color(0xFFD97706); // Bronze
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Golden Crown for Rank 1
        if (isCenter)
          Positioned(
            top: -16.h,
            child: SizedBox(
              width: 26.w,
              height: 16.h,
              child: const CustomPaint(
                painter: _GoldenCrownPainter(),
              ),
            ),
          ),

        // Outer 3D Pink/Purple Base Container
        Container(
          margin: EdgeInsets.only(top: isCenter ? 8.h : 18.h),
          padding: EdgeInsets.only(bottom: 5.h),
          decoration: BoxDecoration(
            color: const Color(0xFFC88BE2),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFAB31DE).withValues(alpha: isCenter ? 0.15 : 0.08),
                blurRadius: isCenter ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(4.w, 8.h, 4.w, 8.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: isCenter ? 3.h : 0),

                // Avatar Circle with Ring & Overlapping Hexagon Badge
                Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: ringColor,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ringColor.withValues(alpha: 0.35),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: const Color(0xFFFAF5FF),
                          child: (() {
                            if (!hasPlayer) {
                              return Icon(
                                Icons.person_rounded,
                                color: const Color(0xFFAB31DE),
                                size: rank == 1 ? 22.sp : 18.sp,
                              );
                            }
                            final String avatarUrl = player['avatar']?.toString() ?? '';
                            return avatarUrl.isNotEmpty && avatarUrl != 'null'
                                ? AvatarInternetImage(
                                    url: avatarUrl,
                                    size: avatarSize,
                                  )
                                : Center(
                                    child: Text(
                                      name.substring(0, name.isNotEmpty ? 1 : 0).toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFFAB31DE),
                                        fontSize: rank == 1 ? 15.sp : 13.sp,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                          })(),
                        ),
                      ),
                    ),

                    // Overlapping Vertical Hexagon Badge
                    Positioned(
                      bottom: -9.h,
                      child: _HexagonBadge(
                        rank: rank,
                        fillColor: rank == 1
                            ? const Color(0xFFFFEA00)
                            : (rank == 2 ? const Color(0xFF94A3B8) : const Color(0xFFD97706)),
                        borderColor: rank == 1
                            ? const Color(0xFFFFF59D)
                            : (rank == 2 ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A)),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                // Name
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1B4B),
                    fontSize: isCenter ? 12.sp : 11.sp,
                    fontWeight: isCenter ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),

                SizedBox(height: 2.h),

                // Coins Awarded
                if (coinsAwarded > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/coin.png',
                        width: 11.w,
                        height: 11.w,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: 2.w),
                      Flexible(
                        child: Text(
                          '+${_formatCoins(coinsAwarded)}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF1E1B4B),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                ],
                // Points and Wins Subtitle (Multi-line so it never overflows narrow podium block)
                Text(
                  hasPlayer
                      ? '$totalSpeedPoints Pts\n$winsCount Wins'
                      : '0 Pts\n0 Wins',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// GOLDEN CROWN PAINTER
// -------------------------------------------------------------
class _GoldenCrownPainter extends CustomPainter {
  const _GoldenCrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFE066), Color(0xFFFFB800), Color(0xFFD97706)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.45);
    path.lineTo(size.width * 0.2, size.height);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(size.width, size.height * 0.45);
    path.lineTo(size.width * 0.72, size.height * 0.65);
    path.lineTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.28, size.height * 0.65);
    path.close();

    canvas.drawPath(path, paint);

    final ballPaint = Paint()
      ..color = const Color(0xFFFFE066)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, 0), 2.5, ballPaint);
    canvas.drawCircle(Offset(0, size.height * 0.45), 2.0, ballPaint);
    canvas.drawCircle(Offset(size.width, size.height * 0.45), 2.0, ballPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// HEXAGON BADGE WIDGET & PAINTER
// -------------------------------------------------------------
class _HexagonBadge extends StatelessWidget {
  final int rank;
  final Color fillColor;
  final Color borderColor;

  const _HexagonBadge({
    required this.rank,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18.w,
      height: 20.h,
      child: CustomPaint(
        painter: _HexagonPainter(
          fillColor: fillColor,
          borderColor: borderColor,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: 1.h),
            child: Text(
              '$rank',
              style: GoogleFonts.outfit(
                color: rank == 1 ? const Color(0xFF1B0B3B) : Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HexagonPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;

  const _HexagonPainter({
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.3), 3, false);
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor || oldDelegate.borderColor != borderColor;
}
