class CrazyRacingSet {
  final bool gameInstallTask;
  final int dailyGemsForInstall;
  final int gameGems;
  final int installGems;
  final bool gameEligible;
  final int gameDailyLimit;
  final int gameClaimsToday;

  CrazyRacingSet({
    required this.gameInstallTask,
    required this.dailyGemsForInstall,
    required this.gameGems,
    required this.installGems,
    required this.gameEligible,
    required this.gameDailyLimit,
    required this.gameClaimsToday,
  });
}

typedef DiamondCatchSet = CrazyRacingSet;
