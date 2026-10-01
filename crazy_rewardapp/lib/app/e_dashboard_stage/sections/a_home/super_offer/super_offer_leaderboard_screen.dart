import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'super_offer_leaderboard_model.dart';
import 'super_offer_leaderboard_provider.dart';

class SuperOfferLeaderboardScreen extends HookConsumerWidget {
  const SuperOfferLeaderboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = useState<String>('');
    final selectedTab = useState<int>(0); // 0: All Contest, 1: Leaderboard, 2: History
    final leaderboardAsync = ref.watch(superOfferLeaderboardProvider(selectedMonth.value));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mega Prize 🏆',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFD97706)),
            onPressed: () => ref.refresh(superOfferLeaderboardProvider(selectedMonth.value)),
          ),
        ],
      ),
      body: leaderboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD97706)),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load leaderboard',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(superOfferLeaderboardProvider(selectedMonth.value)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
        data: (data) {
          final contest = data.contest;
          final List<SuperOfferLeaderboardUser> topUsers = data.leaderboard;

          final userStats = data.userStats;
          final podiumUsers = topUsers.take(3).toList();
          final remainingUsers = topUsers.length > 3 ? topUsers.sublist(3) : <SuperOfferLeaderboardUser>[];

          return Stack(
            children: [
              RefreshIndicator(
                color: const Color(0xFFD97706),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  return ref.refresh(superOfferLeaderboardProvider(selectedMonth.value));
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Top 3-Option Navigation Selector Card (All Contest | Leaderboard | History)
                    SliverToBoxAdapter(
                      child: _buildTopTabNavigation(selectedTab),
                    ),

                    // TAB 0: ALL CONTEST
                    if (selectedTab.value == 0) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: _buildTimerHeader(data.timeRemainingSeconds, contest),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: const [
                              Icon(Icons.military_tech_rounded, color: Color(0xFFD97706), size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Bumper Prize Tiers 🏆',
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),
                      SliverToBoxAdapter(
                        child: _buildBumperPrizesInlineList(contest.prizes),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverToBoxAdapter(
                        child: _buildContestRulesCard(),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 90)),
                    ]
                    // TAB 1: LEADERBOARD
                    else if (selectedTab.value == 1) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: _buildTimerHeader(data.timeRemainingSeconds, contest),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildMegaPrizeCardWithPopup(context, contest.prizes),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                          child: _buildTop3Podium(podiumUsers, contest.prizes),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Rankings List',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '${topUsers.length} Players',
                                    style: const TextStyle(
                                      color: Color(0xFFD97706),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (remainingUsers.isEmpty && podiumUsers.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                    child: Text(
                                      'No unlocks recorded yet for this active contest.\nUnlock your first Super Offer to claim Rank 1! ⚡',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                                    ),
                                  ),
                                )
                              else if (remainingUsers.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Text(
                                      'Top winners locked! Unlock offers to join the list! ⚡',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: remainingUsers.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final user = remainingUsers[index];
                                    return _buildRankRowItem(user, contest.prizes);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 90)),
                    ]
                    // TAB 2: HISTORY
                    else if (selectedTab.value == 2) ...[
                      SliverToBoxAdapter(
                        child: _buildHistoryTab(ref),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 90)),
                    ],
                  ],
                ),
              ),

              // Sticky User Rank Bottom Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildUserStickyRankBar(userStats),
              ),
            ],
          );
        },
      ),
    );
  }

  // 1. Top Tab Selector Bar (All Contest | Leaderboard | History)
  Widget _buildTopTabNavigation(ValueNotifier<int> selectedTab) {
    final tabs = [
      {'title': 'All Contest', 'icon': Icons.emoji_events_rounded},
      {'title': 'Leaderboard', 'icon': Icons.leaderboard_rounded},
      {'title': 'History', 'icon': Icons.history_rounded},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = selectedTab.value == index;
          final tab = tabs[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => selectedTab.value = index,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFD97706), Color(0xFFB45309)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD97706).withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        tab['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 2. All Contest Tab - Bumper Prizes Inline Cards List
  Widget _buildBumperPrizesInlineList(List<SuperOfferPrize> prizes) {
    if (prizes.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: prizes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final prize = prizes[index];
        final rankLabel = _formatRankLabel(prize.rankRange);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.6), width: 1.5),
                ),
                child: ClipOval(
                  child: prize.imageUrl.isNotEmpty
                      ? Image.network(
                          prize.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.amberAccent,
                            size: 28,
                          ),
                        )
                      : const Icon(
                          Icons.card_giftcard_rounded,
                          color: Colors.amberAccent,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rankLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prize.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (prize.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        prize.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (prize.coinBonus > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on_rounded, color: Colors.amberAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '+${prize.coinBonus}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
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

  // 3. All Contest Tab - Rules Card
  Widget _buildContestRulesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.menu_book_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'Contest Rules & Details 📋',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRuleItem('1', 'Unlock maximum Super Offers to earn higher leaderboard rank.'),
          const SizedBox(height: 8),
          _buildRuleItem('2', 'Leaderboard updates live based on your total completed Super Offer unlocks.'),
          const SizedBox(height: 8),
          _buildRuleItem('3', 'Top rankers win Bumper Mega Physical Prizes at contest completion.'),
          const SizedBox(height: 8),
          _buildRuleItem('4', 'Rank 4 to 12 players receive guaranteed 5,000 Coin Rewards in wallet.'),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFD97706),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  // 4. History Tab - Winner Past Contests View
  Widget _buildHistoryTab(WidgetRef ref) {
    final historyAsync = ref.watch(superOfferWinnerHistoryProvider);

    return historyAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFD97706)),
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.history_toggle_off_rounded, color: Colors.grey, size: 48),
              const SizedBox(height: 8),
              Text(
                'Unable to load contest history',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
      data: (historyList) {
        if (historyList.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: const [
                Icon(Icons.emoji_events_outlined, color: Color(0xFFCBD5E1), size: 54),
                SizedBox(height: 12),
                Text(
                  'No Past Contest History Yet',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Past contest winners will be archived and shown here once the current contest finishes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.3),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: historyList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final item = historyList[index];
            final contestTitle = item['title'] ?? item['contestTitle'] ?? item['monthKey'] ?? item['month'] ?? 'Past Contest';
            final winners = item['winners'] as List<dynamic>? ?? [];

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
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
                          '🏆 $contestTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF334155), height: 20),
                  if (winners.isEmpty)
                    const Text(
                      'Winners declared for this contest.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    )
                  else
                    Column(
                      children: winners.map((w) {
                        final rank = w['rank'] ?? 1;
                        final name = w['userName'] ?? w['name'] ?? 'Winner';
                        final prizeName = w['prizeTitle'] ?? w['prize'] ?? 'Mega Prize';
                        final unlocks = w['unlockCount'] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: rank == 1
                                      ? const Color(0xFFD97706)
                                      : (rank == 2 ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#$rank',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    Text(
                                      '$prizeName • $unlocks Unlocks',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Timer & Contest Banner (Dark Sleek Card)
  Widget _buildTimerHeader(int timeRemainingSeconds, SuperOfferContest contest) {
    if (!contest.isActive) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: const [
            Icon(Icons.pause_circle_filled_rounded, color: Colors.amberAccent, size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Super Offer Mega Contest is currently paused by admin.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ],
        ),
      );
    }

    if (contest.isWinnerDeclared) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD97706), Color(0xFFB45309)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🏆 Contest Winner Declared!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contest.declaredAt.isNotEmpty
                        ? 'Declared on: ${contest.declaredAt}'
                        : 'Coin rewards have been credited to winner wallets!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final days = timeRemainingSeconds ~/ (24 * 3600);
    final hours = (timeRemainingSeconds % (24 * 3600)) ~/ 3600;
    final minutes = (timeRemainingSeconds % 3600) ~/ 60;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amberAccent.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined, color: Colors.amberAccent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contest.title.isNotEmpty ? contest.title : 'Super Offer Mega Contest 🏆',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timeRemainingSeconds > 0
                      ? (days > 0
                          ? 'Contest Ends In: ${days}d ${hours}h ${minutes}m'
                          : 'Contest Ends In: ${hours}h ${minutes}m')
                      : 'Contest Completed - Awaiting Admin Declaration',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMegaPrizeCardWithPopup(BuildContext context, List<SuperOfferPrize> prizes) {
    return InkWell(
      onTap: () => _showPrizePopupSheet(context, prizes),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amberAccent.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.amberAccent.withOpacity(0.4), width: 1),
              ),
              child: FloatingPulseIcon(
                child: Image.asset(
                  'assets/Icons1/output-onlinegiftools.gif',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Mega Prize 🏆',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap arrow to view prize breakdown & rewards',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.amberAccent,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrizePopupSheet(BuildContext context, List<SuperOfferPrize> prizes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/Icons1/output-onlinegiftools.gif',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Mega Contest Prizes 🏆',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(color: Colors.white.withOpacity(0.12), height: 20),
              if (prizes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      'No prize details updated yet.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: prizes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final prize = prizes[index];
                      final rankLabel = _formatRankLabel(prize.rankRange);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.amberAccent.withOpacity(0.5), width: 1.5),
                              ),
                              child: ClipOval(
                                child: prize.imageUrl.isNotEmpty
                                    ? Image.network(
                                        prize.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(
                                          Icons.card_giftcard_rounded,
                                          color: Colors.amberAccent,
                                          size: 26,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.card_giftcard_rounded,
                                        color: Colors.amberAccent,
                                        size: 26,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      rankLabel.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    prize.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (prize.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      prize.subtitle,
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (prize.coinBonus > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.monetization_on_rounded, color: Colors.amberAccent, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${prize.coinBonus}',
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatRankLabel(String rankRange) {
    final clean = rankRange.trim();
    if (clean == '1') return '1st Rank';
    if (clean == '2') return '2nd Rank';
    if (clean == '3') return '3rd Rank';
    if (clean.isNotEmpty && !clean.toLowerCase().contains('rank')) {
      return 'Rank $clean';
    }
    return clean.isEmpty ? 'Prize' : clean;
  }

  SuperOfferPrize? _getPrizeForRank(List<SuperOfferPrize> prizes, String targetRank) {
    final targetNum = int.tryParse(targetRank);
    if (targetNum == null) return null;
    for (final p in prizes) {
      if (p.minRank <= targetNum && targetNum <= p.maxRank) {
        return p;
      }
      final r = p.rankRange.trim();
      if (r == targetRank) {
        return p;
      }
      if (r.contains('-')) {
        final parts = r.split('-');
        if (parts.length == 2) {
          final start = int.tryParse(parts[0].trim());
          final end = int.tryParse(parts[1].trim());
          if (start != null && end != null && targetNum >= start && targetNum <= end) {
            return p;
          }
        }
      }
    }
    if (prizes.isEmpty && targetNum >= 4 && targetNum <= 10) {
      return SuperOfferPrize(
        minRank: 4,
        maxRank: 10,
        rankRange: '4-10',
        title: '500 Coins',
        subtitle: 'Coin Reward',
        imageUrl: 'https://zodplay.in/image-tool/uploads/2026/10/super-offer-coin-20261001-080429-6da1485c.png',
        coinBonus: 500,
      );
    }
    return null;
  }

  // Top 3 Metallic 3D Podium
  Widget _buildTop3Podium(List<SuperOfferLeaderboardUser> podiumUsers, List<SuperOfferPrize> prizes) {
    final rank1 = podiumUsers.isNotEmpty ? podiumUsers[0] : null;
    final rank2 = podiumUsers.length > 1 ? podiumUsers[1] : null;
    final rank3 = podiumUsers.length > 2 ? podiumUsers[2] : null;

    final prize1 = _getPrizeForRank(prizes, '1');
    final prize2 = _getPrizeForRank(prizes, '2');
    final prize3 = _getPrizeForRank(prizes, '3');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSinglePodiumColumn(
          rank: 2,
          user: rank2,
          prize: prize2,
          blockWidth: 88,
          blockHeight: 90,
          blockColors: const [Color(0xFF828896), Color(0xFF535966), Color(0xFF374151)],
          badgeColor: const Color(0xFF64748B),
          nameColor: const Color(0xFF1E293B),
        ),
        const SizedBox(width: 6),
        _buildSinglePodiumColumn(
          rank: 1,
          user: rank1,
          prize: prize1,
          blockWidth: 104,
          blockHeight: 125,
          blockColors: const [Color(0xFF9CA3AF), Color(0xFF6B7280), Color(0xFF4B5563)],
          badgeColor: const Color(0xFFEAB308),
          nameColor: const Color(0xFFEF4444),
        ),
        const SizedBox(width: 6),
        _buildSinglePodiumColumn(
          rank: 3,
          user: rank3,
          prize: prize3,
          blockWidth: 88,
          blockHeight: 70,
          blockColors: const [Color(0xFF717785), Color(0xFF4B515D), Color(0xFF333A48)],
          badgeColor: const Color(0xFFD97706),
          nameColor: const Color(0xFF1E293B),
        ),
      ],
    );
  }

  Widget _buildSinglePodiumColumn({
    required int rank,
    required SuperOfferLeaderboardUser? user,
    required SuperOfferPrize? prize,
    required double blockWidth,
    required double blockHeight,
    required List<Color> blockColors,
    required Color badgeColor,
    required Color nameColor,
  }) {
    final displayName = user != null ? user.userName : 'Empty';
    final scoreVal = user != null ? user.unlockCount : 0;
    final prizeImageUrl = prize != null ? prize.imageUrl : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: rank == 1 ? 64 : 56,
              height: rank == 1 ? 64 : 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: badgeColor,
                  width: rank == 1 ? 2.8 : 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withOpacity(0.35),
                    blurRadius: 10,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
              child: ClipOval(
                child: user != null && user.avatar.isNotEmpty
                    ? Image.network(
                        user.avatar,
                        width: rank == 1 ? 64 : 56,
                        height: rank == 1 ? 64 : 56,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          color: const Color(0xFF1E293B),
                          child: Icon(
                            Icons.person_rounded,
                            color: badgeColor,
                            size: rank == 1 ? 36 : 30,
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1E293B),
                        child: Icon(
                          Icons.person_rounded,
                          color: badgeColor,
                          size: rank == 1 ? 36 : 30,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: blockWidth + 8,
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: user != null ? nameColor : Colors.grey.shade400,
              fontSize: rank == 1 ? 13.5 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.flash_on_rounded,
              color: Color(0xFFD97706),
              size: 13,
            ),
            const SizedBox(width: 2),
            Text(
              '$scoreVal',
              style: TextStyle(
                color: user != null ? const Color(0xFFD97706) : Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: blockWidth,
          height: blockHeight,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
            gradient: LinearGradient(
              colors: blockColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 4,
                left: 8,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: const Color(0xFF475569),
                    fontSize: rank == 1 ? 34 : 28,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    height: 0.85,
                    letterSpacing: -1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: SizedBox(
                  width: blockWidth * 0.85,
                  height: blockHeight * 0.75,
                  child: prizeImageUrl.isNotEmpty
                      ? Image.network(
                          prizeImageUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          errorBuilder: (c, e, s) => Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.amberAccent,
                            size: rank == 1 ? 40 : 32,
                          ),
                        )
                      : Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.amberAccent,
                          size: rank == 1 ? 44 : 34,
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Rankings Row Item (#4 to #100)
  Widget _buildRankRowItem(SuperOfferLeaderboardUser user, List<SuperOfferPrize> prizes) {
    final prize = _getPrizeForRank(prizes, '${user.rank}');
    final double leftPadding = user.rank >= 100 ? 54 : (user.rank >= 10 ? 44 : 36);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(leftPadding, 10, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.55), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amberAccent.withOpacity(0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: user.avatar.isNotEmpty
                        ? Image.network(
                            user.avatar,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: const Color(0xFF334155),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.amberAccent,
                                size: 28,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF334155),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.amberAccent,
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.flash_on_rounded,
                            color: Color(0xFFD97706),
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${user.unlockCount} Offers Unlocked',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (prize != null && (prize.imageUrl.isNotEmpty || prize.coinBonus > 0)) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amberAccent.withOpacity(0.6), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amberAccent.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: prize.imageUrl.isNotEmpty
                                ? Image.network(
                                    prize.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.monetization_on_rounded,
                                      color: Colors.amberAccent,
                                      size: 18,
                                    ),
                                  )
                                : const Icon(
                                    Icons.monetization_on_rounded,
                                    color: Colors.amberAccent,
                                    size: 18,
                                  ),
                          ),
                        ),
                        if (prize.coinBonus > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '+${prize.coinBonus}',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            bottom: -4,
            top: -12,
            child: Container(
              alignment: Alignment.bottomLeft,
              child: Text(
                '${user.rank}',
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w900,
                  fontSize: user.rank >= 100 ? 32 : (user.rank >= 10 ? 44 : 54),
                  height: 0.85,
                  letterSpacing: -2,
                  fontStyle: FontStyle.italic,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 3,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sticky Bottom Bar showing User's Rank
  Widget _buildUserStickyRankBar(SuperOfferUserRankStats userStats) {
    final rankText = userStats.rank > 0 ? '#${userStats.rank}' : 'Unranked';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.amberAccent.withOpacity(0.3), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 26),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'YOUR RANK',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    rankText,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
            ),
            child: Text(
              'Unlocked: ${userStats.unlockCount} Offers ⚡',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingPulseIcon extends StatefulWidget {
  final Widget child;
  const FloatingPulseIcon({Key? key, required this.child}) : super(key: key);

  @override
  State<FloatingPulseIcon> createState() => _FloatingPulseIconState();
}

class _FloatingPulseIconState extends State<FloatingPulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translation;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _translation = Tween<double>(begin: 0, end: -6.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translation.value),
          child: Transform.scale(
            scale: _scale.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
