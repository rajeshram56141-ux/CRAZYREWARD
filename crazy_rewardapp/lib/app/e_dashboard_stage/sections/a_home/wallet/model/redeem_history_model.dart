import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../../utils/helper/helper.dart';
import '../../../../../../utils/theme/theme.dart';
import 'redeem_details_model.dart';

enum PayoutStatus { pending, successful, failed, inProgress }

class PayoutHistoryModel {
  final int amount;
  final int coins;
  final String orderId;
  final PayoutStatus status;
  final String symbol;
  final String image;
  final Timestamp timestamp;
  final String methodName;
  final PaymentDetails methodDetails;
  final String redeemCode;
  final String title;
  final String failureReason;

  PayoutHistoryModel({
    required this.amount,
    required this.image,
    required this.coins,
    required this.orderId,
    required this.status,
    required this.symbol,
    required this.timestamp,
    required this.methodName,
    required this.methodDetails,
    required this.redeemCode,
    required this.title,
    this.failureReason = '',
  });

  factory PayoutHistoryModel.fromSnapshot(DocumentSnapshot snapshot, [Map<String, String>? catalogTitles]) {
    final data = snapshot.data() as Map<String, dynamic>;

    final String method = data['methodName'];

    if (!data.containsKey(method)) {
      throw Exception("PayoutHistoryModel: Missing method details for $method");
    }

    final Map<String, dynamic> detailsJson = data[method];

    final PaymentDetails methodDetails = PaymentDetails.fromSnapshot(
      detailsJson,
    );

    String resolvedTitle = '';
    final String rawTitle = (data['displayTitle'] ?? data['title'] ?? data['methodTitle'] ?? '').toString().trim();

    if (rawTitle.isNotEmpty && rawTitle.toLowerCase() != 'null') {
      resolvedTitle = rawTitle;
    } else if (catalogTitles != null && catalogTitles.containsKey(method)) {
      resolvedTitle = catalogTitles[method]!;
    } else {
      final methodLower = method.toLowerCase();
      if (methodLower == 'google_play' || methodLower == 'googleplay' || methodLower == 'pr') {
        resolvedTitle = 'Google Play';
      } else if (methodLower == 'amazon' || methodLower == 'ar') {
        resolvedTitle = 'Amazon';
      } else if (methodLower == 'flipkart' || methodLower == 'fp') {
        resolvedTitle = 'Flipkart';
      } else if (methodLower == 'upi') {
        resolvedTitle = 'UPI';
      } else if (methodLower == 'paytm') {
        resolvedTitle = 'Paytm';
      } else {
        resolvedTitle = method.replaceAll('_', ' ').caps();
      }
    }

    if (resolvedTitle.endsWith(' Gift Card')) {
      resolvedTitle = resolvedTitle.replaceAll(' Gift Card', '').trim();
    } else if (resolvedTitle.endsWith(' Gift Voucher')) {
      resolvedTitle = resolvedTitle.replaceAll(' Gift Voucher', '').trim();
    }

    final rawReason = (data['failureReason'] ?? data['rejectReason'] ?? data['message'] ?? '').toString().trim();

    return PayoutHistoryModel(
      redeemCode: data['redeemCode'] ?? 'N/A',
      image: data['image'],
      amount: data['amount'],
      coins: data['coins'],
      methodName: data['methodName'],
      orderId: data['orderId'],
      status: _parseStatus(data['status']),
      symbol: data['symbol'].toString().parseSymbol(),
      timestamp: data['timestamp'],
      methodDetails: methodDetails,
      title: resolvedTitle,
      failureReason: rawReason,
    );
  }

  factory PayoutHistoryModel.fromJson(Map<String, dynamic> json, [Map<String, String>? catalogTitles]) {
    final String method = json['methodName'] ?? 'Redeem';

    final Map<String, dynamic> detailsJson = Map<String, dynamic>.from(json['methodDetails'] ?? json[method] ?? {});

    final PaymentDetails methodDetails = PaymentDetails.fromSnapshot(
      detailsJson,
    );

    String resolvedTitle = '';
    final String rawTitle = (json['displayTitle'] ?? json['title'] ?? json['methodTitle'] ?? '').toString().trim();

    if (rawTitle.isNotEmpty && rawTitle.toLowerCase() != 'null') {
      resolvedTitle = rawTitle;
    } else if (catalogTitles != null && catalogTitles.containsKey(method)) {
      resolvedTitle = catalogTitles[method]!;
    } else {
      final methodLower = method.toLowerCase();
      if (methodLower == 'google_play' || methodLower == 'googleplay' || methodLower == 'pr') {
        resolvedTitle = 'Google Play';
      } else if (methodLower == 'amazon' || methodLower == 'ar') {
        resolvedTitle = 'Amazon';
      } else if (methodLower == 'flipkart' || methodLower == 'fp') {
        resolvedTitle = 'Flipkart';
      } else if (methodLower == 'upi') {
        resolvedTitle = 'UPI';
      } else if (methodLower == 'paytm') {
        resolvedTitle = 'Paytm';
      } else {
        resolvedTitle = method.replaceAll('_', ' ').caps();
      }
    }

    if (resolvedTitle.endsWith(' Gift Card')) {
      resolvedTitle = resolvedTitle.replaceAll(' Gift Card', '').trim();
    } else if (resolvedTitle.endsWith(' Gift Voucher')) {
      resolvedTitle = resolvedTitle.replaceAll(' Gift Voucher', '').trim();
    }

    final tsString = json['timestamp'] ?? json['createdAt'];
    final Timestamp ts = tsString != null
        ? Timestamp.fromDate(DateTime.parse(tsString.toString()))
        : Timestamp.now();

    final rawReason = (json['failureReason'] ?? json['rejectReason'] ?? json['message'] ?? '').toString().trim();

    return PayoutHistoryModel(
      redeemCode: json['redeemCode'] ?? 'N/A',
      image: json['image'] ?? '',
      amount: (json['amount'] ?? 0).toInt(),
      coins: (json['coins'] ?? 0).toInt(),
      methodName: method,
      orderId: json['orderId'] ?? '',
      status: _parseStatus(json['status'] ?? 'pending'),
      symbol: (json['symbol'] ?? '₹').toString().parseSymbol(),
      timestamp: ts,
      methodDetails: methodDetails,
      title: resolvedTitle,
      failureReason: rawReason,
    );
  }

  static PayoutStatus _parseStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'success':
        return PayoutStatus.successful;
      case 'failed':
        return PayoutStatus.failed;
      case 'inprogress':
      case 'in_progress':
      case 'processing':
        return PayoutStatus.inProgress;
      default:
        return PayoutStatus.pending;
    }
  }

  static Color getColor(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.failed:
        return AppTheme.errorColor;
      case PayoutStatus.successful:
        return AppTheme.successColor;
      default:
        return AppTheme.processingColor;
    }
  }
}

// Backward compatibility & semantic aliases
typedef RedeemHistoryModel = PayoutHistoryModel;
typedef WithdrawalHistoryModel = PayoutHistoryModel;
