import 'package:cloud_firestore/cloud_firestore.dart';

enum CoinHistoryType { task, withdrawal }

class CoinHistoryModel {
  final String title;
  final double coins;
  final Timestamp timestamp;
  final CoinHistoryType type;
  final String? status; // 'success', 'failed', 'refund', 'refunded', 'pending', 'inprogress', 'processing'

  CoinHistoryModel({
    required this.title,
    required this.coins,
    required this.timestamp,
    required this.type,
    this.status,
  });
}
