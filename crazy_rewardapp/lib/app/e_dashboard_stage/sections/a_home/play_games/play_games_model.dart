class PlayGamesModel {
  final String imagePath;
  final String offerName;
  final int trackingTime;
  final int coins;
  final String redirectionUrl;
  final String offerId;
  final String category;
  final int maxPlaysPerUser;
  final bool dailyEnabled;
  final int maxPlaysPerDay;

  PlayGamesModel({
    required this.imagePath,
    required this.offerName,
    required this.trackingTime,
    required this.coins,
    required this.redirectionUrl,
    required this.offerId,
    required this.category,
    this.maxPlaysPerUser = -1,
    this.dailyEnabled = false,
    this.maxPlaysPerDay = 1,
  });

  factory PlayGamesModel.fromJson(Map<String, dynamic> json) {
    return PlayGamesModel(
      imagePath: json['imagePath']?.toString() ?? '',
      offerName: json['offerName']?.toString() ?? '',
      trackingTime: (json['trackingTime'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      redirectionUrl: json['redirectionUrl']?.toString() ?? '',
      offerId: json['offerId']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      maxPlaysPerUser: (json['maxPlaysPerUser'] as num?)?.toInt() ?? -1,
      dailyEnabled: json['dailyEnabled'] as bool? ?? false,
      maxPlaysPerDay: (json['maxPlaysPerDay'] as num?)?.toInt() ?? 1,
    );
  }
}
