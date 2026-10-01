class SuperOfferPrize {
  final int minRank;
  final int maxRank;
  final String rankRange;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int coinBonus;

  SuperOfferPrize({
    required this.minRank,
    required this.maxRank,
    required this.rankRange,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.coinBonus,
  });

  factory SuperOfferPrize.fromJson(Map<String, dynamic> json) {
    final minR = int.tryParse(json['minRank']?.toString() ?? '1') ?? 1;
    final maxR = int.tryParse(json['maxRank']?.toString() ?? '1') ?? 1;
    var rangeStr = json['rankRange']?.toString() ?? '';
    if (rangeStr.isEmpty) {
      rangeStr = minR == maxR ? 'Rank $minR' : 'Rank $minR - $maxR';
    }
    return SuperOfferPrize(
      minRank: minR,
      maxRank: maxR,
      rankRange: rangeStr,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      coinBonus: int.tryParse(json['coinBonus']?.toString() ?? '0') ?? 0,
    );
  }
}

class SuperOfferContest {
  final String title;
  final String subtitle;
  final String bannerUrl;
  final String status;
  final bool isActive;
  final String startTime;
  final String endTime;
  final bool isWinnerDeclared;
  final String declaredAt;
  final List<SuperOfferPrize> prizes;

  SuperOfferContest({
    required this.title,
    required this.subtitle,
    required this.bannerUrl,
    required this.status,
    required this.isActive,
    required this.startTime,
    required this.endTime,
    required this.isWinnerDeclared,
    required this.declaredAt,
    required this.prizes,
  });

  factory SuperOfferContest.fromJson(Map<String, dynamic> json) {
    var prizesList = <SuperOfferPrize>[];
    if (json['prizes'] is List) {
      prizesList = (json['prizes'] as List)
          .map((p) => SuperOfferPrize.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    }
    return SuperOfferContest(
      title: json['title']?.toString() ?? 'Super Offer Bumper League',
      subtitle: json['subtitle']?.toString() ?? '',
      bannerUrl: json['bannerUrl']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      isActive: json['isActive'] != false,
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      isWinnerDeclared: json['isWinnerDeclared'] == true,
      declaredAt: json['declaredAt']?.toString() ?? '',
      prizes: prizesList,
    );
  }
}

class SuperOfferUserRankStats {
  final int rank;
  final int unlockCount;
  final bool isInTop3;
  final bool isInTop10;

  SuperOfferUserRankStats({
    required this.rank,
    required this.unlockCount,
    required this.isInTop3,
    required this.isInTop10,
  });

  factory SuperOfferUserRankStats.fromJson(Map<String, dynamic> json) {
    return SuperOfferUserRankStats(
      rank: int.tryParse(json['rank']?.toString() ?? '0') ?? 0,
      unlockCount: int.tryParse(json['unlockCount']?.toString() ?? '0') ?? 0,
      isInTop3: json['isInTop3'] == true,
      isInTop10: json['isInTop10'] == true,
    );
  }
}

class SuperOfferLeaderboardUser {
  final int rank;
  final String userId;
  final String userName;
  final String avatar;
  final int unlockCount;

  SuperOfferLeaderboardUser({
    required this.rank,
    required this.userId,
    required this.userName,
    required this.avatar,
    required this.unlockCount,
  });

  factory SuperOfferLeaderboardUser.fromJson(Map<String, dynamic> json) {
    return SuperOfferLeaderboardUser(
      rank: int.tryParse(json['rank']?.toString() ?? '0') ?? 0,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'User',
      avatar: json['avatar']?.toString() ?? '',
      unlockCount: int.tryParse(json['unlockCount']?.toString() ?? '0') ?? 0,
    );
  }
}

class SuperOfferLeaderboardResponse {
  final bool success;
  final String monthKey;
  final SuperOfferContest contest;
  final int timeRemainingSeconds;
  final SuperOfferUserRankStats userStats;
  final List<SuperOfferLeaderboardUser> leaderboard;

  SuperOfferLeaderboardResponse({
    required this.success,
    required this.monthKey,
    required this.contest,
    required this.timeRemainingSeconds,
    required this.userStats,
    required this.leaderboard,
  });

  factory SuperOfferLeaderboardResponse.fromJson(Map<String, dynamic> json) {
    var usersList = <SuperOfferLeaderboardUser>[];
    if (json['leaderboard'] is List) {
      usersList = (json['leaderboard'] as List)
          .map((u) => SuperOfferLeaderboardUser.fromJson(Map<String, dynamic>.from(u as Map)))
          .toList();
    }
    return SuperOfferLeaderboardResponse(
      success: json['success'] == true,
      monthKey: json['monthKey']?.toString() ?? '',
      contest: json['contest'] is Map
          ? SuperOfferContest.fromJson(Map<String, dynamic>.from(json['contest'] as Map))
          : SuperOfferContest(
              title: 'Super Offer Bumper League',
              subtitle: '',
              bannerUrl: '',
              status: 'active',
              isActive: true,
              startTime: '',
              endTime: '',
              isWinnerDeclared: false,
              declaredAt: '',
              prizes: [],
            ),
      timeRemainingSeconds: int.tryParse(json['timeRemainingSeconds']?.toString() ?? '0') ?? 0,
      userStats: json['userStats'] is Map
          ? SuperOfferUserRankStats.fromJson(Map<String, dynamic>.from(json['userStats'] as Map))
          : SuperOfferUserRankStats(rank: 0, unlockCount: 0, isInTop3: false, isInTop10: false),
      leaderboard: usersList,
    );
  }
}
