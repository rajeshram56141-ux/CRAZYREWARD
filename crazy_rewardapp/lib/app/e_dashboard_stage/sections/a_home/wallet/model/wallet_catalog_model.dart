import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../../utils/helper/helper.dart';

class WalletDenomination {
  final int amount;
  final int coins;
  final String id;
  final String? subtitle;
  final bool isOutOfStock;

  WalletDenomination({
    required this.amount,
    required this.coins,
    required this.id,
    this.subtitle,
    this.isOutOfStock = false,
  });

  WalletDenomination copyWith({
    int? amount,
    int? coins,
    String? id,
    String? subtitle,
    bool? isOutOfStock,
  }) {
    return WalletDenomination(
      amount: amount ?? this.amount,
      coins: coins ?? this.coins,
      id: id ?? this.id,
      subtitle: subtitle ?? this.subtitle,
      isOutOfStock: isOutOfStock ?? this.isOutOfStock,
    );
  }

  factory WalletDenomination.fromMap(Map<String, dynamic> map, String id) {
    return WalletDenomination(
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      coins: (map['coins'] as num?)?.toInt() ?? 0,
      id: id,
      subtitle: map['subtitle']?.toString(),
      isOutOfStock: map['isOutOfStock'] == true,
    );
  }

  factory WalletDenomination.fromJson(Map<String, dynamic> json) {
    return WalletDenomination(
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      id: json['id']?.toString() ?? json['denomId']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      isOutOfStock: json['isOutOfStock'] == true,
    );
  }
}


class WalletMethod {
  final String id;
  final String title;
  final String symbol;
  final String image;
  final List<String> validators;
  final List<WalletDenomination> denominations;
  final bool autoPayment;
  final Map<String, String> hints;

  WalletMethod({
    required this.id,
    required this.title,
    required this.symbol,
    required this.image,
    required this.denominations,
    required this.validators,
    this.autoPayment = false,
    required this.hints,
  });

  factory WalletMethod.fromSnapshot(
    DocumentSnapshot doc,
    List<WalletDenomination> denominations,
  ) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return WalletMethod(
      symbol: (data['symbol'] ?? '₹').toString().parseSymbol(),
      id: doc.id,
      image: data['image']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Redeem',
      validators: List<String>.from(data['validators'] ?? []),
      denominations: denominations,
      autoPayment: data['autoPayment'] == true,
      hints: Map<String, String>.from(data['hints'] ?? {}),
    );
  }

  factory WalletMethod.fromJson(Map<String, dynamic> json) {
    final denomsList = (json['denominations'] as List? ?? [])
        .whereType<Map>()
        .map((d) => WalletDenomination.fromJson(Map<String, dynamic>.from(d)))
        .toList();
    return WalletMethod(
      id: json['id']?.toString() ?? json['methodId']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Redeem',
      symbol: (json['symbol'] ?? '₹').toString().parseSymbol(),
      image: json['image']?.toString() ?? '',
      validators: (json['validators'] as List? ?? []).map((e) => e.toString()).toList(),
      denominations: denomsList,
      autoPayment: json['autoPayment'] == true,
      hints: Map<String, String>.from(json['hints'] ?? {}),
    );
  }
}

class HideDenominationConfig {
  final bool enabled;
  final double thresholdPercent;
  final int hideCount;
  final String hideMode; // 'hide' | 'out_of_stock'
  final String redeemCondition; // 'always' | 'exact_redeems' | 'max_redeems' | 'min_redeems'
  final int targetRedeemCount;

  const HideDenominationConfig({
    this.enabled = false,
    this.thresholdPercent = 99.0,
    this.hideCount = 1,
    this.hideMode = 'hide',
    this.redeemCondition = 'always',
    this.targetRedeemCount = 0,
  });

  bool get isHideCard => hideMode != 'out_of_stock';

  factory HideDenominationConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HideDenominationConfig();
    return HideDenominationConfig(
      enabled: json['enabled'] == true,
      thresholdPercent: (json['thresholdPercent'] as num?)?.toDouble() ?? 99.0,
      hideCount: (json['hideCount'] as num?)?.toInt() ?? 1,
      hideMode: json['hideMode']?.toString() ?? 'hide',
      redeemCondition: json['redeemCondition']?.toString() ?? 'always',
      targetRedeemCount: (json['targetRedeemCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'thresholdPercent': thresholdPercent,
    'hideCount': hideCount,
    'hideMode': hideMode,
    'redeemCondition': redeemCondition,
    'targetRedeemCount': targetRedeemCount,
  };

  /// Evaluates whether the denomination at [index] (0-based in sorted ascending order)
  /// should be targeted for a user with [userCoins] and [userRedeemCount].
  bool shouldHide({
    required int index,
    required int denominationCoins,
    required double userCoins,
    required int userRedeemCount,
  }) {
    if (!enabled) return false;

    // Check redeem condition
    bool conditionMatches = false;
    if (redeemCondition == 'always') {
      conditionMatches = true;
    } else if (redeemCondition == 'exact_redeems') {
      conditionMatches = (userRedeemCount == targetRedeemCount);
    } else if (redeemCondition == 'max_redeems') {
      conditionMatches = (userRedeemCount <= targetRedeemCount);
    } else if (redeemCondition == 'min_redeems') {
      conditionMatches = (userRedeemCount >= targetRedeemCount);
    }
    if (!conditionMatches) return false;

    // Check if this card rank is within hideCount lowest cards
    if (index >= hideCount) return false;

    // Check coin threshold
    final double threshold = denominationCoins * (thresholdPercent / 100.0);
    return userCoins >= threshold;
  }

  /// Filters a list of denominations based on coin threshold & redeem count.
  /// If hideMode is 'hide', hides them. If hideMode is 'out_of_stock', marks isOutOfStock = true.
  List<WalletDenomination> filterDenominations({
    required List<WalletDenomination> originalList,
    required double userCoins,
    required int userRedeemCount,
  }) {
    if (!enabled || originalList.isEmpty) return originalList;

    // Sort entries by coins ascending to determine rank
    final sortedWithIndices = originalList.asMap().entries.toList()
      ..sort((a, b) => a.value.coins.compareTo(b.value.coins));

    final targetIndices = <int>{};
    for (int rank = 0; rank < sortedWithIndices.length; rank++) {
      final entry = sortedWithIndices[rank];
      if (shouldHide(
        index: rank,
        denominationCoins: entry.value.coins,
        userCoins: userCoins,
        userRedeemCount: userRedeemCount,
      )) {
        targetIndices.add(entry.key);
      }
    }

    if (targetIndices.isEmpty) return originalList;

    // If hideMode is 'hide' (Toggle ON), remove cards completely
    if (isHideCard) {
      return [
        for (int i = 0; i < originalList.length; i++)
          if (!targetIndices.contains(i)) originalList[i]
      ];
    }

    // If hideMode is 'out_of_stock' (Toggle OFF), keep cards visible but mark as out of stock
    return [
      for (int i = 0; i < originalList.length; i++)
        if (targetIndices.contains(i))
          originalList[i].copyWith(isOutOfStock: true)
        else
          originalList[i]
    ];
  }
}
