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
      'firstLogin': firstLogin,
      'lastLogin': lastLogin,
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
}
