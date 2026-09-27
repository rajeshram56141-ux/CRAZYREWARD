class SuperOfferModel {
  final int streak;
  final int gems;
  final int dailyGems;
  final int completedSuperOffers;

  SuperOfferModel({
    required this.streak,
    required this.gems,
    required this.dailyGems,
    required this.completedSuperOffers,
  });
}

class SuperOfferSet {
  final int coins;
  final int gemsRequired;
  final bool adsRequired;
  final bool installTask;
  final bool superOfferVerificationEnabled;
  final int dailyGemsForInstall;
  final int installGems;
  final bool eligible;
  final DateTime? lastClaimedAt;
  final int hoursGap;
  final int gapMinutes;
  final bool isUnlocked;
  final int completedSuperOffers;
  final String limitType;

  SuperOfferSet({
    required this.coins,
    required this.gemsRequired,
    required this.adsRequired,
    required this.installTask,
    this.superOfferVerificationEnabled = true,
    required this.dailyGemsForInstall,
    required this.installGems,
    required this.eligible,
    this.lastClaimedAt,
    this.hoursGap = 8,
    this.gapMinutes = 60,
    this.isUnlocked = false,
    this.completedSuperOffers = 0,
    this.limitType = 'hours',
  });
}
