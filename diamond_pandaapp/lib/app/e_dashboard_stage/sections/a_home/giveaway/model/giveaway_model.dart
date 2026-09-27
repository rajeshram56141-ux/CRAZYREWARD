import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum GiveawayStatus { upcoming, ongoing, declared }

enum GiveawayWinnerStatus {
  pending,
  claimed,
  requested,
  shipped,
  delivered,
  cancelled;

  static GiveawayWinnerStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'claimed':
        return GiveawayWinnerStatus.claimed;
      case 'pending':
      case 'claimable':
      case 'unclaimed':
        return GiveawayWinnerStatus.pending;
      case 'shipped':
        return GiveawayWinnerStatus.shipped;
      case 'delivered':
        return GiveawayWinnerStatus.delivered;
      case 'cancelled':
        return GiveawayWinnerStatus.cancelled;
      case 'requested':
      default:
        return GiveawayWinnerStatus.requested;
    }
  }
}

class GiveawayWinnerModel {
  final String userId;
  final String name;
  final String photoUrl;
  final GiveawayWinnerStatus status;
  final GiveawayRewardModel reward;

  GiveawayWinnerModel({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.status,
    required this.reward,
  });

  factory GiveawayWinnerModel.fromMap(Map<String, dynamic> map) {
    return GiveawayWinnerModel(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      status: GiveawayWinnerStatus.fromString(map['status']),
      reward: GiveawayRewardModel(
        productName: map['reward']?['productName'] ?? '',
        productImage: map['reward']?['productImage'] ?? '',
        productRank: map['reward']?['productRank'] is int
            ? map['reward']['productRank']
            : (int.tryParse(map['reward']?['productRank']?.toString() ?? '1') ?? 1),
        coins: map['reward']?['coins'] is int
            ? map['reward']['coins']
            : (int.tryParse(map['reward']?['coins']?.toString() ?? '0') ?? 0),
      ),
    );
  }
}

class GiveawayModel {
  final String id;
  final String title;
  final String bannerUrl;
  final String description;

  final int totalSlots;
  final int joinedCount;
  final int prizeCoins;

  final Timestamp startsAt;
  final Timestamp declaresAt;
  final String statusStr;

  final List<GiveawayRewardModel> rewards;

  /// UI helper (later stream se set hoga)
  final bool joined;

  GiveawayModel({
    required this.id,
    required this.title,
    required this.bannerUrl,
    required this.description,
    required this.totalSlots,
    required this.joinedCount,
    this.prizeCoins = 0,
    required this.startsAt,
    required this.declaresAt,
    this.statusStr = 'active',
    required this.rewards,
    this.joined = false,
  });

  factory GiveawayModel.fromJson(Map<String, dynamic> data, {bool joined = false}) {
    final rewardsList = (data['rewards'] as List<dynamic>? ?? [])
        .map(
          (reward) {
            final rMap = reward is Map<String, dynamic> ? reward : <String, dynamic>{};
            final rCoins = rMap['coins'] is int
                ? rMap['coins'] as int
                : (int.tryParse(rMap['coins']?.toString() ?? '0') ?? 0);
            final rName = rMap['productName']?.toString() ?? '';
            final rRank = rMap['productRank'] is int
                ? rMap['productRank'] as int
                : (int.tryParse(rMap['productRank']?.toString() ?? '1') ?? 1);

            return GiveawayRewardModel(
              productName: rName,
              productImage: rMap['productImage']?.toString() ?? '',
              productRank: rRank,
              coins: rCoins,
            );
          },
        )
        .toList();

    rewardsList.sort((a, b) => a.productRank.compareTo(b.productRank));

    final startsMs = data['startsAt'] is int
        ? data['startsAt']
        : (data['startsAt'] != null
            ? (DateTime.tryParse(data['startsAt'].toString())?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch)
            : (DateTime.tryParse(data['createdAt']?.toString() ?? '')?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch));

    final int declaresMs;
    if (data['declaresAt'] != null) {
      declaresMs = data['declaresAt'] is int
          ? data['declaresAt']
          : (DateTime.tryParse(data['declaresAt'].toString())?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch);
    } else if (data['endDate'] != null) {
      declaresMs = data['endDate'] is int
          ? data['endDate']
          : (DateTime.tryParse(data['endDate'].toString())?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch);
    } else {
      declaresMs = DateTime.now().millisecondsSinceEpoch;
    }

    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final joinedList = (data['joinedUsers'] as List<dynamic>? ?? data['participants'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    final bool isUserJoined = (data['joined'] == true) || (currentUid.isNotEmpty && joinedList.contains(currentUid));

    final pCoins = data['prizeCoins'] is int
        ? data['prizeCoins'] as int
        : (int.tryParse(data['prizeCoins']?.toString() ?? '0') ?? 0);

    return GiveawayModel(
      id: data['giveawayId']?.toString() ?? data['id']?.toString() ?? data['_id']?.toString() ?? '',
      title: data['title'] ?? '',
      bannerUrl: (data['bannerUrl'] != null && data['bannerUrl'].toString().isNotEmpty)
          ? data['bannerUrl'].toString()
          : (data['image']?.toString() ?? ''),
      description: data['description'] ?? '',
      totalSlots: data['totalSlots'] is int ? data['totalSlots'] : (int.tryParse(data['totalSlots']?.toString() ?? '0') ?? 0),
      joinedCount: data['joinedCount'] is int ? data['joinedCount'] : joinedList.length,
      prizeCoins: pCoins,
      startsAt: Timestamp.fromMillisecondsSinceEpoch(startsMs),
      declaresAt: Timestamp.fromMillisecondsSinceEpoch(declaresMs),
      statusStr: data['status']?.toString() ?? 'active',
      rewards: rewardsList,
      joined: joined || isUserJoined,
    );
  }

  // 🔹 Convert Firestore Doc → Model
  factory GiveawayModel.fromDoc(DocumentSnapshot doc, {bool joined = false}) {
    final data = doc.data() as Map<String, dynamic>;

    final rewardsList = (data['rewards'] as List<dynamic>? ?? [])
        .map(
          (reward) {
            final rMap = reward is Map<String, dynamic> ? reward : <String, dynamic>{};
            return GiveawayRewardModel(
              productName: rMap['productName'] ?? '',
              productImage: rMap['productImage'] ?? '',
              productRank: rMap['productRank'] is int ? rMap['productRank'] : (int.tryParse(rMap['productRank']?.toString() ?? '1') ?? 1),
              coins: rMap['coins'] is int ? rMap['coins'] : (int.tryParse(rMap['coins']?.toString() ?? '0') ?? 0),
            );
          },
        )
        .toList();

    // 🔥 Sort by productRank (ascending)
    rewardsList.sort((a, b) => a.productRank.compareTo(b.productRank));

    return GiveawayModel(
      id: doc.id,
      title: data['title'] ?? '',
      bannerUrl: data['bannerUrl'] ?? '',
      description: data['description'] ?? '',
      totalSlots: data['totalSlots'] ?? 0,
      joinedCount: data['joinedCount'] ?? 0,
      prizeCoins: data['prizeCoins'] ?? 0,
      startsAt: data['startsAt'] as Timestamp,
      declaresAt: data['declaresAt'] as Timestamp,
      statusStr: data['status']?.toString() ?? 'active',
      rewards: rewardsList, // ✅ sorted
      joined: joined,
    );
  }

  // 🔹 Timestamp → DateTime
  DateTime get startsAtDate => startsAt.toDate();
  DateTime get declaresAtDate => declaresAt.toDate();

  // 🔹 Calculate Status Using Server Time & Status String
  GiveawayStatus getStatus(DateTime serverTime) {
    final s = statusStr.toLowerCase();
    if (s == 'declared' || s == 'completed' || s == 'result') {
      return GiveawayStatus.declared;
    }
    if (serverTime.isBefore(startsAtDate)) {
      return GiveawayStatus.upcoming;
    } else if (serverTime.isAfter(declaresAtDate) || serverTime.isAtSameMomentAs(declaresAtDate)) {
      return GiveawayStatus.declared;
    } else {
      return GiveawayStatus.ongoing;
    }
  }

  // 🔹 Slots Left
  int get slotsLeft => totalSlots - joinedCount;

  // 🔹 Is Full
  bool get isFull => joinedCount >= totalSlots;
}

class GiveawayRewardModel {
  final String productName;
  final String productImage;
  final int productRank;
  final int coins;

  GiveawayRewardModel({
    required this.productName,
    required this.productImage,
    required this.productRank,
    this.coins = 0,
  });

  String get displayReward {
    if (coins > 0) return '$coins Coins';
    if (productName.isNotEmpty) {
      if (RegExp(r'^\d+$').hasMatch(productName)) {
        return '$productName Coins';
      }
      return productName;
    }
    return 'Reward';
  }
}
