class DailyChallengeTaskItem {
  final String taskId;
  final String title;
  final String description;
  final String taskType;
  final int targetCount;
  final int currentCount;
  final int actualCount;
  final double progressPercent;
  final bool isCompleted;
  final String icon;

  DailyChallengeTaskItem({
    required this.taskId,
    required this.title,
    required this.description,
    required this.taskType,
    required this.targetCount,
    required this.currentCount,
    required this.actualCount,
    required this.progressPercent,
    required this.isCompleted,
    required this.icon,
  });

  factory DailyChallengeTaskItem.fromJson(Map<String, dynamic> json) {
    final rawIcon = json['icon']?.toString() ?? '';
    final type = (json['taskType']?.toString() ?? '').toLowerCase();
    String resolvedIcon = rawIcon;
    if (resolvedIcon.isEmpty || resolvedIcon == 'assets/icons/game.png' || resolvedIcon == 'assets/icons/plygames.png') {
      switch (type) {
        case 'play_games':
          resolvedIcon = 'assets/icons/playtimegame.png';
          break;
        case 'super_offer':
          resolvedIcon = 'assets/icons/suprerofferdhn.png';
          break;
        case 'read_and_earn':
          resolvedIcon = 'assets/icons/reaadnowo.png';
          break;
        case 'battle_arena':
          resolvedIcon = 'assets/icons/battle.png';
          break;
        case 'daily_task':
          resolvedIcon = 'assets/icons/daily task blur.png';
          break;
        case 'watch_earn':
        case 'watch_video':
          resolvedIcon = 'assets/icons/watch video.png';
          break;
        case 'offerwall':
          resolvedIcon = 'assets/icons/pubscale-logo.png';
          break;
        case 'survey':
          resolvedIcon = 'assets/icons/bitlabs-logo.png';
          break;
        case 'daily_checkin':
          resolvedIcon = 'assets/icons/battle time.png';
          break;
        case 'diamond_catch':
          resolvedIcon = 'assets/icons/diamondcatchpnda.png';
          break;
        case 'giveaway':
          resolvedIcon = 'assets/icons/super coin.png';
          break;
        default:
          resolvedIcon = 'assets/icons/playtimegame.png';
          break;
      }
    }

    return DailyChallengeTaskItem(
      taskId: json['taskId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      taskType: json['taskType']?.toString() ?? '',
      targetCount: (json['targetCount'] as num?)?.toInt() ?? 1,
      currentCount: (json['currentCount'] as num?)?.toInt() ?? 0,
      actualCount: (json['actualCount'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      isCompleted: json['isCompleted'] == true,
      icon: resolvedIcon,
    );
  }
}

class DailyChallengeData {
  final bool isActive;
  final int rewardCoins;
  final String dateStr;
  final String nextResetTime;
  final int secondsRemaining;
  final int totalTasksCount;
  final int completedTasksCount;
  final double overallProgressPercent;
  final bool isAllCompleted;
  final bool claimedReward;
  final bool canClaim;
  final List<DailyChallengeTaskItem> tasks;

  DailyChallengeData({
    required this.isActive,
    required this.rewardCoins,
    required this.dateStr,
    required this.nextResetTime,
    required this.secondsRemaining,
    required this.totalTasksCount,
    required this.completedTasksCount,
    required this.overallProgressPercent,
    required this.isAllCompleted,
    required this.claimedReward,
    required this.canClaim,
    required this.tasks,
  });

  factory DailyChallengeData.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? [];
    return DailyChallengeData(
      isActive: json['isActive'] == true,
      rewardCoins: (json['rewardCoins'] as num?)?.toInt() ?? 500,
      dateStr: json['dateStr']?.toString() ?? '',
      nextResetTime: json['nextResetTime']?.toString() ?? '',
      secondsRemaining: (json['secondsRemaining'] as num?)?.toInt() ?? 0,
      totalTasksCount: (json['totalTasksCount'] as num?)?.toInt() ?? 0,
      completedTasksCount: (json['completedTasksCount'] as num?)?.toInt() ?? 0,
      overallProgressPercent: (json['overallProgressPercent'] as num?)?.toDouble() ?? 0.0,
      isAllCompleted: json['isAllCompleted'] == true,
      claimedReward: json['claimedReward'] == true,
      canClaim: json['canClaim'] == true,
      tasks: rawTasks.map((t) => DailyChallengeTaskItem.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}
