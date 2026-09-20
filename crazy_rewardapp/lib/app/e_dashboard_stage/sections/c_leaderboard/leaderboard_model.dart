class LeaderboardModel {
  final String userId;
  final String name;
  final String photoUrl;
  final double totalCoins;
  final int totalReferrals;

  LeaderboardModel({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.totalCoins,
    required this.totalReferrals,
  });

  factory LeaderboardModel.fromMap(Map<String, dynamic> map) {
    final String userId =
        (map['userId'] ?? map['uid'] ?? map['_id'] ?? '').toString().trim();
    final double coins = (map['coins'] as num?)?.toDouble() ?? 0.0;
    final double totalCoins = (map['totalCoins'] as num?)?.toDouble() ?? 0.0;
    final int totalReferrals = (map['totalReferrals'] as num?)?.toInt() ??
        (map['referralCount'] as num?)?.toInt() ??
        0;
    final String rawName =
        (map['displayName'] ?? map['name'] ?? '').toString().trim();

    return LeaderboardModel(
      userId: userId,
      name: rawName.isEmpty ? 'Crazyreward User' : rawName,
      photoUrl: (map['photoUrl'] ?? '').toString(),
      totalCoins: totalCoins > 0 ? totalCoins : coins,
      totalReferrals: totalReferrals,
    );
  }
}
