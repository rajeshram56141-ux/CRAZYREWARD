class ReferHistoryModel {
  final double coins;
  final String inviterName;
  final int level;
  final String name;
  final String photoUrl;
  final String userId;

  ReferHistoryModel({
    required this.coins,
    required this.inviterName,
    required this.level,
    required this.name,
    required this.photoUrl,
    required this.userId,
  });

  // 🔹 From Firestore
  factory ReferHistoryModel.fromMap(Map<String, dynamic> map) {
    return ReferHistoryModel(
      coins: map['coins'].toDouble() ?? 0,
      inviterName: map['invitedByName'] ?? '',
      level: (map['level'] ?? 0) as int,
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      userId: map['userId'] ?? '',
    );
  }
}
