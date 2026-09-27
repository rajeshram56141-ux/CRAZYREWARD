enum OfferwallCategory { survey, task }

enum SurveyName { bitlabs, cpxResearch, timewall, wannads, cpidroid, tapjoy, theoremReach }

enum TaskName {
  tapjoy,
  sushiAds,
  notik,
  cpidroid,
  taskwall,
  adjoe,
  wannads,
  bitlabs,
  pubscale,
  lootably,
  timewall,
  cpxResearch,
  playtimeAds,
  growDeck,
}

class OffersDataModel {
  final bool enabled;
  final int rank;
  final String sdkHash;
  final String token;
  final String url;
  final String appId;
  final String secretKey;
  final String appKey;
  final String providerName;
  final String iconUrl;
  final String category;

  OffersDataModel({
    required this.enabled,
    required this.rank,
    this.appId = '',
    this.sdkHash = '',
    this.token = '',
    this.url = '',
    this.appKey = '',
    this.secretKey = '',
    this.providerName = '',
    this.iconUrl = '',
    this.category = '',
  });

  factory OffersDataModel.fromMap(Map<String, dynamic> map) {
    return OffersDataModel(
      enabled: map['enabled'] ?? false,
      rank: map['rank'] ?? 0,
      appId: map['appId'] ?? '',
      sdkHash: map['sdkHash'] ?? '',
      token: map['token'] ?? '',
      url: map['url'] ?? '',
      appKey: map['appKey'] ?? '',
      secretKey: map['secretKey'] ?? '',
      providerName: map['providerName'] ?? '',
      iconUrl: map['iconUrl'] ?? '',
      category: map['category'] ?? '',
    );
  }
}