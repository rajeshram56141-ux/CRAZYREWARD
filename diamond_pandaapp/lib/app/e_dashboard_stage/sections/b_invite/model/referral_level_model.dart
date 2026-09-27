import '../../../../b_splash_stage/splash_service.dart';

class ReferralMissionModel {
  final String id;
  final int target;
  final int reward;
  final bool enabled;
  final String title;
  final String criteriaType;
  final int criteriaCount;
  final int progress;

  const ReferralMissionModel({
    required this.id,
    required this.target,
    required this.reward,
    this.enabled = true,
    this.title = '',
    this.criteriaType = 'direct',
    this.criteriaCount = 1,
    this.progress = 0,
  });

  factory ReferralMissionModel.fromMap(Map<String, dynamic> map) {
    return ReferralMissionModel(
      id: map['id']?.toString() ?? '',
      target: (map['target'] as num?)?.toInt() ?? 0,
      reward: (map['reward'] as num?)?.toInt() ?? 0,
      enabled: map['enabled'] != false,
      title: map['title']?.toString() ?? '',
      criteriaType: (map['criteriaType'] ?? 'direct').toString(),
      criteriaCount: (map['criteriaCount'] as num?)?.toInt() ?? 1,
      progress: (map['progress'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target': target,
      'reward': reward,
      'enabled': enabled,
      'title': title,
      'criteriaType': criteriaType,
      'criteriaCount': criteriaCount,
      'progress': progress,
    };
  }
}

class ReferralLevel {
  final Map<String, int> values;

  const ReferralLevel(this.values);

  factory ReferralLevel.fromMap(Map<String, dynamic> map) {
    final result = <String, int>{};

    map.forEach((key, value) {
      if (value is num) {
        result[key] = value.toInt();
      }
    });

    return ReferralLevel(result);
  }
}

class ReferralSettings {
  final String rewardMode; // 'all' or 'taskWise'
  final int allCommissionPercent;
  final int referrerBonusCoins;
  final String referrerBonusCondition;
  final ReferralLevel firstLevel;
  final ReferralLevel secondLevel;
  final ReferralLevel thirdLevel;
  final bool referredRewardEnabled;
  final int referredRewardCoins;
  final bool missionsEnabled;
  final String missionsSubtitle;
  final List<ReferralMissionModel> missions;

  const ReferralSettings({
    this.rewardMode = 'all',
    this.allCommissionPercent = 10,
    this.referrerBonusCoins = 0,
    this.referrerBonusCondition = 'none',
    required this.firstLevel,
    required this.secondLevel,
    required this.thirdLevel,
    this.referredRewardEnabled = false,
    this.referredRewardCoins = 0,
    this.missionsEnabled = false,
    this.missionsSubtitle = '',
    this.missions = const [],
  });

  ReferralSettings copyWith({
    String? rewardMode,
    int? allCommissionPercent,
    int? referrerBonusCoins,
    String? referrerBonusCondition,
    ReferralLevel? firstLevel,
    ReferralLevel? secondLevel,
    ReferralLevel? thirdLevel,
    bool? referredRewardEnabled,
    int? referredRewardCoins,
    bool? missionsEnabled,
    String? missionsSubtitle,
    List<ReferralMissionModel>? missions,
  }) {
    return ReferralSettings(
      rewardMode: rewardMode ?? this.rewardMode,
      allCommissionPercent: allCommissionPercent ?? this.allCommissionPercent,
      referrerBonusCoins: referrerBonusCoins ?? this.referrerBonusCoins,
      referrerBonusCondition: referrerBonusCondition ?? this.referrerBonusCondition,
      firstLevel: firstLevel ?? this.firstLevel,
      secondLevel: secondLevel ?? this.secondLevel,
      thirdLevel: thirdLevel ?? this.thirdLevel,
      referredRewardEnabled: referredRewardEnabled ?? this.referredRewardEnabled,
      referredRewardCoins: referredRewardCoins ?? this.referredRewardCoins,
      missionsEnabled: missionsEnabled ?? this.missionsEnabled,
      missionsSubtitle: missionsSubtitle ?? this.missionsSubtitle,
      missions: missions ?? this.missions,
    );
  }

  factory ReferralSettings.fromFirestore(Map<String, dynamic> data) {
    final rawMissions = data['missions'];
    List<ReferralMissionModel> parsedMissions = [];
    if (rawMissions is List) {
      parsedMissions = rawMissions
          .where((m) => m is Map<String, dynamic> || m is Map)
          .map((m) => ReferralMissionModel.fromMap(
              Map<String, dynamic>.from(m as Map)))
          .where((m) => m.enabled && m.target > 0)
          .toList()
        ..sort((a, b) => a.target.compareTo(b.target));
    }

    return ReferralSettings(
      rewardMode: (data['rewardMode'] ?? 'all').toString(),
      allCommissionPercent: (data['allCommissionPercent'] as num?)?.toInt() ?? 10,
      referrerBonusCoins: (data['referrerBonusCoins'] as num?)?.toInt() ?? 0,
      referrerBonusCondition: (data['referrerBonusCondition'] ?? 'none').toString(),
      firstLevel: ReferralLevel.fromMap(
        Map<String, dynamic>.from(data['firstLevel'] ?? const {}),
      ),
      secondLevel: ReferralLevel.fromMap(
        Map<String, dynamic>.from(data['secondLevel'] ?? const {}),
      ),
      thirdLevel: ReferralLevel.fromMap(
        Map<String, dynamic>.from(data['thirdLevel'] ?? const {}),
      ),
      referredRewardEnabled: data['referredRewardEnabled'] == true,
      referredRewardCoins: (data['referredRewardCoins'] as num?)?.toInt() ?? 0,
      missionsEnabled: data['missionsEnabled'] == true,
      missionsSubtitle: (data['missionsSubtitle'] ?? data['missionsDescription'] ?? '').toString(),
      missions: parsedMissions,
    );
  }

  factory ReferralSettings.empty() {
    return const ReferralSettings(
      rewardMode: 'all',
      allCommissionPercent: 10,
      referrerBonusCoins: 0,
      referrerBonusCondition: 'none',
      firstLevel: ReferralLevel({}),
      secondLevel: ReferralLevel({}),
      thirdLevel: ReferralLevel({}),
      referredRewardEnabled: false,
      referredRewardCoins: 0,
      missionsEnabled: false,
      missionsSubtitle: '',
      missions: [],
    );
  }

  static int getCommissionPercent(int level) {
    final settings = SplashService.referralSettings;

    switch (level) {
      case 1:
        return settings.firstLevel.values.values.fold(0, (a, b) => a + b);

      case 2:
        return settings.secondLevel.values.values.fold(0, (a, b) => a + b);

      case 3:
        return settings.thirdLevel.values.values.fold(0, (a, b) => a + b);

      default:
        return 0;
    }
  }
}
