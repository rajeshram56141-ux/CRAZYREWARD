import 'package:cloud_firestore/cloud_firestore.dart';

class ReadTskModel {
  final String offerId;
  final String redirectionUrl;
  final int coins;
  final int trackingTime;
  final bool verificationEnabled;
  final String verificationTitle;
  final String verificationDomain;

  ReadTskModel({
    required this.offerId,
    required this.redirectionUrl,
    required this.coins,
    required this.trackingTime,
    this.verificationEnabled = false,
    this.verificationTitle = '',
    this.verificationDomain = '',
  });

  factory ReadTskModel.fromJson(Map<String, dynamic> json) {
    return ReadTskModel(
      offerId: (json['offerId'] ?? '').toString(),
      redirectionUrl: (json['redirectionUrl'] ?? '').toString(),
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      trackingTime: (json['trackingTime'] is num && (json['trackingTime'] as num) > 0)
          ? (json['trackingTime'] as num).toInt()
          : 60,
      verificationEnabled: json['verificationEnabled'] ?? false,
      verificationTitle: (json['verificationTitle'] ?? '').toString(),
      verificationDomain: (json['verificationDomain'] ?? '').toString(),
    );
  }
}

class ReadTskHistoryModel {
  final String offerId;
  final int coins;
  final DateTime timestamp;

  ReadTskHistoryModel({
    required this.offerId,
    required this.coins,
    required this.timestamp,
  });

  factory ReadTskHistoryModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return ReadTskHistoryModel(
      offerId: data['offerId'] ?? 'N/A',
      coins: data['coins'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
