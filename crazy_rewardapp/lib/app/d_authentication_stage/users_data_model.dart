// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

class UserDataModel {
  UserDataModel({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.userId,
    required this.coins,
    required this.referralCode,
    required this.firstLogin,
    required this.lastLogin,
    required this.socialFollowed,
    required this.country,
    required this.deviceId,
    required this.streak,
    required this.streakClaimed,
    required this.source,
    required this.isGuest,
    required this.mobileNo,
    required this.blocked,
    required this.referred,
    required this.gems,
    required this.account_deleted,
    required this.battleInstallTaskNumber,
    required this.battleInstallTaskCompletedToday,
    required this.freeBattlesJoinedToday,
    required this.battleDailyLimit,
    this.bonusCoins = 0.0,
  });

  final String referralCode;
  final double coins;
  final double bonusCoins;
  final String email;
  final String userId;
  final String name;
  final String photoUrl;
  final Timestamp firstLogin;
  final Timestamp lastLogin;
  final List<String> socialFollowed;
  final String country;
  final String deviceId;
  final int streak;
  final bool streakClaimed;
  final String source;
  final bool isGuest;
  final String mobileNo;
  final bool blocked;
  final bool referred;
  final int gems;
  final bool account_deleted;
  final int battleInstallTaskNumber;
  final bool battleInstallTaskCompletedToday;
  final int freeBattlesJoinedToday;
  final int battleDailyLimit;

  factory UserDataModel.fromJson(Map<String, dynamic> data) {
    return UserDataModel(
      blocked: data['isBlocked'] ?? data['blocked'] ?? false,
      isGuest: data['isGuest'] ?? false,
      coins: (data['coins'] as num?)?.toDouble() ?? 0.0,
      email: data['email'] ?? '',
      userId: data['userId'] ?? '',
      name: data['displayName'] ?? data['name'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      firstLogin: Timestamp.now(),
      lastLogin: Timestamp.now(),
      socialFollowed: List<String>.from(data['socialFollowed'] ?? []),
      country: data['countryCode'] ?? data['country'] ?? 'IN',
      deviceId: data['deviceId'] ?? '',
      streak: (data['streak'] as num?)?.toInt() ?? 1,
      streakClaimed: data['streakClaimed'] ?? false,
      source: data['source'] ?? '',
      referralCode: data['referralCode'] ?? '',
      mobileNo: data['mobileNo'] ?? '',
      referred: data['referred'] ?? false,
      gems: (data['gems'] as num?)?.toInt() ?? 0,
      account_deleted: data['account_deleted'] ?? false,
      battleInstallTaskNumber: (data['battleInstallTaskNumber'] as num?)?.toInt() ?? 0,
      battleInstallTaskCompletedToday: data['battleInstallTaskCompletedToday'] ?? false,
      freeBattlesJoinedToday: (data['freeBattlesJoinedToday'] as num?)?.toInt() ?? 0,
      battleDailyLimit: (data['battleDailyLimit'] as num?)?.toInt() ?? 0,
      bonusCoins: (data['bonusCoins'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory UserDataModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;

    return UserDataModel(
      blocked: data['blocked'],
      isGuest: data['isGuest'],
      coins: data['coins'].toDouble(),
      bonusCoins: (data['bonusCoins'] as num?)?.toDouble() ?? 0.0,
      email: data['email'],
      userId: data['userId'],
      name: data['name'],
      photoUrl: data['photoUrl'],
      firstLogin: data['firstLogin'],
      lastLogin: data['lastLogin'],
      socialFollowed: List<String>.from(data['socialFollowed']),
      country: data['country'],
      deviceId: data['deviceId'],
      streak: data['streak'],
      streakClaimed: data['streakClaimed'],
      source: data['source'],
      referralCode: data['referralCode'],
      mobileNo: data['mobileNo'],
      referred: data['referred'] ?? false,
      gems: data['gems'] ?? 0,
      account_deleted: data['account_deleted'] ?? false,
      battleInstallTaskNumber: data['battleInstallTaskNumber'] ?? 0,
      battleInstallTaskCompletedToday: data['battleInstallTaskCompletedToday'] ?? false,
      freeBattlesJoinedToday: data['freeBattlesJoinedToday'] ?? 0,
      battleDailyLimit: data['battleDailyLimit'] ?? 0,
    );
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'blocked': blocked,
      'mobileNo': mobileNo,
      'isGuest': isGuest,
      'referralCode': referralCode,
      'coins': coins,
      'email': email,
      'userId': userId,
      'name': name,
      'photoUrl': photoUrl,
      'firstLogin': firstLogin.millisecondsSinceEpoch,
      'lastLogin': lastLogin.millisecondsSinceEpoch,
      'socialFollowed': socialFollowed,
      'country': country,
      'deviceId': deviceId,
      'streak': streak,
      'streakClaimed': streakClaimed,
      'source': source,
      'referred': referred,
      'gems': gems,
      'account_deleted': account_deleted,
      'battleInstallTaskNumber': battleInstallTaskNumber,
      'battleInstallTaskCompletedToday': battleInstallTaskCompletedToday,
      'freeBattlesJoinedToday': freeBattlesJoinedToday,
      'battleDailyLimit': battleDailyLimit,
    };
  }

  UserDataModel copyWith({
    String? referralCode,
    double? coins,
    double? bonusCoins,
    String? email,
    String? userId,
    String? name,
    String? photoUrl,
    Timestamp? firstLogin,
    Timestamp? lastLogin,
    List<String>? socialFollowed,
    String? country,
    String? deviceId,
    int? streak,
    bool? streakClaimed,
    String? source,
    bool? isGuest,
    String? mobileNo,
    bool? blocked,
    bool? referred,
    int? gems,
    bool? account_deleted,
    int? battleInstallTaskNumber,
    bool? battleInstallTaskCompletedToday,
    int? freeBattlesJoinedToday,
    int? battleDailyLimit,
  }) {
    return UserDataModel(
      referralCode: referralCode ?? this.referralCode,
      coins: coins ?? this.coins,
      bonusCoins: bonusCoins ?? this.bonusCoins,
      email: email ?? this.email,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      firstLogin: firstLogin ?? this.firstLogin,
      lastLogin: lastLogin ?? this.lastLogin,
      socialFollowed: socialFollowed ?? this.socialFollowed,
      country: country ?? this.country,
      deviceId: deviceId ?? this.deviceId,
      streak: streak ?? this.streak,
      streakClaimed: streakClaimed ?? this.streakClaimed,
      source: source ?? this.source,
      isGuest: isGuest ?? this.isGuest,
      mobileNo: mobileNo ?? this.mobileNo,
      blocked: blocked ?? this.blocked,
      referred: referred ?? this.referred,
      gems: gems ?? this.gems,
      account_deleted: account_deleted ?? this.account_deleted,
      battleInstallTaskNumber: battleInstallTaskNumber ?? this.battleInstallTaskNumber,
      battleInstallTaskCompletedToday: battleInstallTaskCompletedToday ?? this.battleInstallTaskCompletedToday,
      freeBattlesJoinedToday: freeBattlesJoinedToday ?? this.freeBattlesJoinedToday,
      battleDailyLimit: battleDailyLimit ?? this.battleDailyLimit,
    );
  }
}

