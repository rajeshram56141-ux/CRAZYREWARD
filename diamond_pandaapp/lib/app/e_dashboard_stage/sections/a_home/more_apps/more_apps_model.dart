class MoreAppsModel {
  final String id;
  final String appName;
  final String appLogo;
  final String subtitle;
  final String redirectionUrl;
  final String buttonType; // 'coin' or 'download'
  final int coins;
  final bool isAd;
  final bool enabled;

  MoreAppsModel({
    required this.id,
    required this.appName,
    required this.appLogo,
    required this.subtitle,
    required this.redirectionUrl,
    this.buttonType = 'download',
    this.coins = 0,
    this.isAd = false,
    this.enabled = true,
  });

  factory MoreAppsModel.fromMap(Map<String, dynamic> map) {
    int parseNum(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    bool parseBool(dynamic val, {bool defaultValue = true}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      if (val is num) return val == 1;
      if (val is String) {
        final s = val.toLowerCase().trim();
        return s == 'true' || s == '1' || s == 'active' || s == 'enabled' || s == 'yes';
      }
      return defaultValue;
    }

    final rawCoins = parseNum(map['coins'] ?? map['coin'] ?? map['rewardCoins'] ?? map['reward']);
    final rawButtonType = (map['buttonType'] ?? map['type'] ?? (rawCoins > 0 ? 'coin' : 'download'))
        .toString()
        .toLowerCase()
        .trim();

    return MoreAppsModel(
      id: (map['id'] ?? map['appId'] ?? map['_id'] ?? '').toString(),
      appName: (map['ourAppName'] ?? map['appName'] ?? map['name'] ?? map['title'] ?? map['app_name'] ?? '').toString(),
      appLogo: (map['ourAppLogo'] ?? map['appLogo'] ?? map['logo'] ?? map['icon'] ?? map['image'] ?? map['app_logo'] ?? '').toString(),
      subtitle: (map['ourAppSubtitle'] ?? map['subtitle'] ?? map['subTitle'] ?? map['desc'] ?? map['description'] ?? map['app_desc'] ?? '').toString(),
      redirectionUrl: (map['ourAppUrl'] ?? map['redirectionUrl'] ?? map['url'] ?? map['link'] ?? map['redirectUrl'] ?? map['appUrl'] ?? map['playstoreUrl'] ?? '').toString(),
      buttonType: (rawButtonType == 'coin' || map['isCoin'] == true) ? 'coin' : 'download',
      coins: rawCoins,
      isAd: parseBool(
        map['isAd'] ??
            map['ad'] ??
            map['isAds'] ??
            map['ads'] ??
            map['isAdvertisement'] ??
            map['advertisement'] ??
            map['ourAppIsAd'],
        defaultValue: false,
      ),
      enabled: parseBool(
        map['enabled'] ??
            map['status'] ??
            map['isActive'] ??
            map['active'] ??
            map['show'] ??
            map['ourAppEnabled'],
        defaultValue: true,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ourAppName': appName,
      'appName': appName,
      'ourAppLogo': appLogo,
      'appLogo': appLogo,
      'ourAppSubtitle': subtitle,
      'subtitle': subtitle,
      'ourAppUrl': redirectionUrl,
      'redirectionUrl': redirectionUrl,
      'buttonType': buttonType,
      'coins': coins,
      'isAd': isAd,
      'enabled': enabled,
    };
  }
}
