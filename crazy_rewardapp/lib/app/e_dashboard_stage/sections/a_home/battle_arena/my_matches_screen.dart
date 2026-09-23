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
        backgroundColor: const Color(0xFFF8FAFC),
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
              topPadding + 10.h,
              16.w,
              bottomPadding + 24.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Navigation Bar
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
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: const Color(0xFF26262B),
                          size: 22.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'My Matches',
                        style: GoogleFonts.kaushanScript(
                          color: const Color(0xFF26262B),
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 18.h),

                // 1. Career Stats Section Header
                Row(
                  children: [
                    Container(
                      width: 4.w,
                      height: 18.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Battle Summary',
                      style: GoogleFonts.kaushanScript(
                        color: const Color(0xFF26262B),
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10.h),

                // 2. 4-Grid Career Stats Overview Dashboard
                _build4GridStatsDashboard(),

                SizedBox(height: 22.h),

                // 3. Match History Section Header
                Row(
                  children: [
                    Container(
                      width: 4.w,
                      height: 18.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Match History',
                      style: GoogleFonts.kaushanScript(
                        color: const Color(0xFF26262B),
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10.h),

                // 4. Segmented Category Tabs (COMPLETED vs CANCELLED)
                Container(
                  height: 48.h,
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF222226),
                        Color(0xFF131316),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(
                      color: const Color(0xFF2E2E36),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        label: 'COMPLETED',
                        count: _completed.length,
                        tabIndex: 0,
                        icon: Icons.check_circle_rounded,
                      ),
                      _buildTabButton(
                        label: 'CANCELLED',
                        count: _cancelled.length,
                        tabIndex: 1,
                        icon: Icons.cancel_rounded,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // 5. Content Section (Loading or Tab List)
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
  // 4-Grid Stats Dashboard Cards Layout
  // ------------------------------------------------------------------
  Widget _build4GridStatsDashboard() {
    final int totalMatches = _completed.length;
    final int totalWins = _completed.where((m) => m['winnerUserId'] == widget.userId).length;
    final int totalLosses = _completed.where((m) => m['winnerUserId'] != widget.userId && m['winnerUserId'] != null).length;
    final double winRate = totalMatches > 0 ? (totalWins / totalMatches) * 100 : 0;

    return Row(
      children: [
        // Card 1: Total Battles
        Expanded(
          child: _buildDarkStatCard(
            icon: Icons.sports_esports_rounded,
            iconColor: const Color(0xFF38BDF8),
            value: '$totalMatches',
            label: 'Battles',
          ),
        ),
        SizedBox(width: 8.w),

        // Card 2: Victories
        Expanded(
          child: _buildDarkStatCard(
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFFFBBF24),
            value: '$totalWins',
            label: 'Wins',
          ),
        ),
        SizedBox(width: 8.w),

        // Card 3: Defeats
        Expanded(
          child: _buildDarkStatCard(
            icon: Icons.cancel_rounded,
            iconColor: const Color(0xFFEF4444),
            value: '$totalLosses',
            label: 'Losses',
          ),
        ),
        SizedBox(width: 8.w),

        // Card 4: Win Rate
        Expanded(
          child: _buildDarkStatCard(
            icon: Icons.analytics_rounded,
            iconColor: const Color(0xFF34D399),
            value: '${winRate.toStringAsFixed(0)}%',
            label: 'Win Rate',
          ),
        ),
      ],
    );
  }

  Widget _buildDarkStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF222226),
            Color(0xFF131316),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF2E2E36),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: const Color(0xFF2E2E38),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: const Color(0xFF3E3E4C),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 16.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: const Color(0xFF9E9EA7),
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Category Tab Button with Counter Badge
  // ------------------------------------------------------------------
  Widget _buildTabButton({
    required String label,
    required int count,
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
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFAB31DE), Color(0xFF7928CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF9E9EA7),
                size: 15.sp,
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : const Color(0xFF9E9EA7),
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              if (count > 0) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF2E2E38),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Completed Matches List (Arena Duel Card Layout)
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF222226),
                Color(0xFF131316),
              ],
            ),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: isWinner
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : (isTie
                      ? const Color(0xFFAB31DE).withValues(alpha: 0.5)
                      : const Color(0xFF2E2E36)),
              width: isWinner || isTie ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isWinner
                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Card Header: Title, Timestamp & Result Badge
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Battle Room Title & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.sports_esports_rounded,
                                color: const Color(0xFFAB31DE),
                                size: 16.sp,
                              ),
                              SizedBox(width: 6.w),
                              Flexible(
                                child: Text(
                                  title,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _formatMatchTime(m['updatedAt'] ?? m['createdAt']),
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF9E9EA7),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Result Status Pill Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.5),
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
                            style: GoogleFonts.poppins(
                              color: statusColor,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF2E2E38), height: 1),

              // 2. Arena Head-to-Head Duel Layout
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                child: Row(
                  children: [
                    // Left Fighter: "You"
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B20),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: isWinner ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFF2E2E38),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isWinner ? const Color(0xFF10B981) : const Color(0xFF3E3E4C),
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18.r,
                                backgroundColor: const Color(0xFF2E2E38),
                                child: myAvatar.isNotEmpty && myAvatar != 'null'
                                    ? ClipOval(
                                        child: AvatarInternetImage(
                                          url: myAvatar,
                                          size: 36.r,
                                        ),
                                      )
                                    : Text(
                                        myName.substring(0, myName.isNotEmpty ? 1 : 0).toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$myScore Pts',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF38BDF8),
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
                    ),

                    // Center VS Separator
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E2E38),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: const Color(0xFF3E3E4C),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          'VS',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFBBF24),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    // Right Fighter: Opponent
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B20),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: !isWinner && !isTie ? const Color(0xFF10B981).withValues(alpha: 0.35) : const Color(0xFF2E2E38),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    oppFullName,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$oppScore Pts',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF9E9EA7),
                                      fontSize: 11.5.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: !isWinner && !isTie ? const Color(0xFF10B981) : const Color(0xFF3E3E4C),
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18.r,
                                backgroundColor: const Color(0xFF2E2E38),
                                child: oppAvatar.isNotEmpty && oppAvatar != 'null'
                                    ? ClipOval(
                                        child: AvatarInternetImage(
                                          url: oppAvatar,
                                          size: 36.r,
                                        ),
                                      )
                                    : Text(
                                        oppFullName.substring(0, oppFullName.isNotEmpty ? 1 : 0).toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF2E2E38), height: 1),

              // 3. Card Footer: Entry Fee & Net Prize
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          color: const Color(0xFF9E9EA7),
                          size: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          entryFee == 0 ? 'Free Entry' : 'Entry: $entryFee Coins',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF9E9EA7),
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (isWinner && netPrize > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            width: 1.0,
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
                              '+${_formatCoins(netPrize)} Won',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF34D399),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isTie && entryFee > 0)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAB31DE).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: const Color(0xFFAB31DE).withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          'Refunded $entryFee Coins',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFE39FFF),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E2E38),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '0 Coins',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF9E9EA7),
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
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
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF222226),
                Color(0xFF131316),
              ],
            ),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: const Color(0xFF2E2E36),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
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
                    child: Row(
                      children: [
                        Icon(
                          Icons.sports_esports_rounded,
                          color: const Color(0xFFEF4444),
                          size: 16.sp,
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      'CANCELLED',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFF87171),
                        fontSize: 9.5.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                _formatMatchTime(m['updatedAt'] ?? m['createdAt']),
                style: GoogleFonts.poppins(
                  color: const Color(0xFF9E9EA7),
                  fontSize: 11.sp,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: const Color(0xFF9E9EA7),
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        cancelReason,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF9E9EA7),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (entryFee > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        'Refunded: $entryFee Coins',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF34D399),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
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
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFF64748B),
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
