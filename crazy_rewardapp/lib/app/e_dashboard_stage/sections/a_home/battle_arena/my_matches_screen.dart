import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../widgets/common/custom_loading.dart';
import '../../../../../../widgets/common/internet_image.dart';
import 'battle_arena_provider.dart';

class MyMatchesScreen extends StatefulWidget {
  final String userId;

  const MyMatchesScreen({super.key, required this.userId});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> {
  bool _isLoading = true;
  List<dynamic> _completed = [];
  List<dynamic> _cancelled = [];
  int _selectedTab = 0; // 0 for Completed, 1 for Cancelled

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final resp = await BattleArenaService.instance.fetchMyMatches(widget.userId);

      if (resp['success'] == true) {
        _completed = resp['completed'] ?? [];
        _cancelled = resp['cancelled'] ?? [];
      }
    } catch (_) {
      // Error handling
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatMatchTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;

    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour:$minute $period';
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
          onRefresh: _loadData,
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
                // Top Header Bar
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
                    Text(
                      'My Matches',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 18.5.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Quick Stats Overview Dashboard Card
                _buildStatsDashboard(),

                SizedBox(height: 16.h),

                // Segmented Category Tabs (COMPLETED vs CANCELLED)
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
                        label: 'COMPLETED',
                        tabIndex: 0,
                        icon: Icons.check_circle_rounded,
                      ),
                      SizedBox(width: 4.w),
                      _buildTabButton(
                        label: 'CANCELLED',
                        tabIndex: 1,
                        icon: Icons.cancel_rounded,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Content Section (Loading or Tab List)
                if (_isLoading)
                  SizedBox(
                    height: 260.h,
                    child: const Center(child: GlowLightingSpinner(size: 28)),
                  )
                else
                  _selectedTab == 0 ? _buildCompletedList() : _buildCancelledList(),

                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Stats Dashboard Card (Total Battles, Wins, Losses, Win Rate)
  // ------------------------------------------------------------------
  Widget _buildStatsDashboard() {
    final int totalMatches = _completed.length;
    final int totalWins = _completed.where((m) => m['winnerUserId'] == widget.userId).length;
    final int totalLosses = _completed.where((m) => m['winnerUserId'] != widget.userId && m['winnerUserId'] != null).length;
    final double winRate = totalMatches > 0 ? (totalWins / totalMatches) * 100 : 0;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFAB31DE).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem(
                label: 'TOTAL BATTLES',
                value: '$totalMatches',
                valueColor: const Color(0xFFAB31DE),
                icon: Icons.sports_esports_rounded,
              ),
              Container(
                width: 1,
                height: 40.h,
                color: const Color(0xFFF1F5F9),
              ),
              _buildStatItem(
                label: 'VICTORIES',
                value: '$totalWins',
                valueColor: const Color(0xFF10B981),
                icon: Icons.emoji_events_rounded,
              ),
              Container(
                width: 1,
                height: 40.h,
                color: const Color(0xFFF1F5F9),
              ),
              _buildStatItem(
                label: 'DEFEATS',
                value: '$totalLosses',
                valueColor: const Color(0xFFEF4444),
                icon: Icons.close_rounded,
              ),
            ],
          ),
          if (totalMatches > 0) ...[
            SizedBox(height: 12.h),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      color: const Color(0xFF64748B),
                      size: 15.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Battle Win Rate',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: const Color(0xFFF3E8FF),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    '${winRate.toStringAsFixed(1)}% WIN RATE',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFAB31DE),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color valueColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: valueColor, size: 16.sp),
              SizedBox(width: 5.w),
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: valueColor,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: const Color(0xFF64748B),
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Category Tab Button
  // ------------------------------------------------------------------
  Widget _buildTabButton({
    required String label,
    required int tabIndex,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == tabIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != tabIndex) {
            HapticFeedback.lightImpact();
            setState(() => _selectedTab = tabIndex);
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
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 12.5.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Completed Matches List
  // ------------------------------------------------------------------
  Widget _buildCompletedList() {
    if (_completed.isEmpty) {
      return _buildEmptyState(
        title: 'No Completed Battles',
        subtitle: 'Play quiz battles in the arena to view your match log!',
        icon: Icons.sports_esports_outlined,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _completed.length,
      itemBuilder: (context, index) {
        final m = _completed[index];
        final bool isWinner = m['winnerUserId'] == widget.userId;
        final bool isTie = m['winnerUserId'] == null;

        final isPlayer1 = m['player1']?['userId'] == widget.userId;
        final myData = isPlayer1 ? m['player1'] : m['player2'];
        final oppData = isPlayer1 ? m['player2'] : m['player1'];

        final String myName = myData?['userName']?.toString().trim() ?? 'You';
        final String myAvatar = myData?['avatar']?.toString() ?? '';
        final int myScore = (myData?['score'] as num?)?.toInt() ?? 0;

        final String oppFullName = oppData?['userName']?.toString().trim() ?? 'Opponent';
        final String oppAvatar = oppData?['avatar']?.toString() ?? '';
        final int oppScore = (oppData?['score'] as num?)?.toInt() ?? 0;

        final String title = m['title']?.toString() ?? 'Quiz Battle';
        final int entryFee = (m['entryFeeCoins'] as num?)?.toInt() ?? 0;
        final int netPrize = (m['netPrizeAwarded'] as num?)?.toInt() ?? (entryFee * 2);

        final Color statusColor = isTie
            ? const Color(0xFFAB31DE)
            : (isWinner ? const Color(0xFF10B981) : const Color(0xFFEF4444));
        final String statusLabel = isTie ? 'DRAW' : (isWinner ? 'VICTORY' : 'DEFEAT');

        return Container(
          margin: EdgeInsets.only(bottom: 14.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isWinner
                  ? const Color(0xFF10B981).withValues(alpha: 0.35)
                  : (isTie
                      ? const Color(0xFFAB31DE).withValues(alpha: 0.35)
                      : const Color(0xFFF1F5F9)),
              width: isWinner || isTie ? 1.4 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isWinner
                    ? const Color(0xFF10B981).withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar of Card: Title, Time & Result Badge
              Padding(
                padding: EdgeInsets.fromLTRB(14.r, 14.r, 14.r, 10.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title & Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _formatMatchTime(m['updatedAt'] ?? m['createdAt']),
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF64748B),
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge (VICTORY / DEFEAT / DRAW)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTie
                                ? Icons.balance_rounded
                                : (isWinner ? Icons.emoji_events_rounded : Icons.close_rounded),
                            color: statusColor,
                            size: 12.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            statusLabel,
                            style: GoogleFonts.outfit(
                              color: statusColor,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFFF1F5F9), height: 1),

              // VS Participant Head-to-Head Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.r, vertical: 12.r),
                child: Row(
                  children: [
                    // You (Player)
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 17.r,
                            backgroundColor: const Color(0xFFFAF5FF),
                            child: myAvatar.isNotEmpty && myAvatar != 'null'
                                ? ClipOval(
                                    child: AvatarInternetImage(
                                      url: myAvatar,
                                      size: 34.r,
                                    ),
                                  )
                                : Text(
                                    myName.substring(0, myName.isNotEmpty ? 1 : 0).toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFAB31DE),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF1E1B4B),
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$myScore Pts',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFAB31DE),
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // VS Pill Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: const Color(0xFFF3E8FF),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        'VS',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    // Opponent
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  oppFullName,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF1E1B4B),
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$oppScore Pts',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          CircleAvatar(
                            radius: 17.r,
                            backgroundColor: const Color(0xFFFAF5FF),
                            child: oppAvatar.isNotEmpty && oppAvatar != 'null'
                                ? ClipOval(
                                    child: AvatarInternetImage(
                                      url: oppAvatar,
                                      size: 34.r,
                                    ),
                                  )
                                : Text(
                                    oppFullName.substring(0, oppFullName.isNotEmpty ? 1 : 0).toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFAB31DE),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFFF1F5F9), height: 1),

              // Bottom Bar: Entry Fee & Net Prize Won
              Padding(
                padding: EdgeInsets.fromLTRB(14.r, 8.r, 14.r, 10.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Entry Fee: $entryFee Coins',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isWinner && netPrize > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
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
                              '+${_formatCoins(netPrize)} Won',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF10B981),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isTie && entryFee > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'Refunded $entryFee Coins',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFAB31DE),
                            fontSize: 11.sp,
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
    );
  }

  // ------------------------------------------------------------------
  // Cancelled Matches List
  // ------------------------------------------------------------------
  Widget _buildCancelledList() {
    if (_cancelled.isEmpty) {
      return _buildEmptyState(
        title: 'No Cancelled Battles',
        subtitle: 'All your matchmaking attempts were completed successfully!',
        icon: Icons.check_circle_outline_rounded,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _cancelled.length,
      itemBuilder: (context, index) {
        final m = _cancelled[index];
        final String title = m['title']?.toString() ?? 'Quiz Battle';
        final int entryFee = (m['entryFeeCoins'] as num?)?.toInt() ?? 0;
        final String cancelReason = m['cancelReason']?.toString() ?? 'Opponent not found';

        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'CANCELLED',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFEF4444),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                _formatMatchTime(m['updatedAt'] ?? m['createdAt']),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B),
                  fontSize: 11.sp,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cancelReason,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (entryFee > 0)
                    Text(
                      'Refunded: $entryFee Coins',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF10B981),
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFFAB31DE),
            size: 48.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: const Color(0xFF1E1B4B),
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
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
}
