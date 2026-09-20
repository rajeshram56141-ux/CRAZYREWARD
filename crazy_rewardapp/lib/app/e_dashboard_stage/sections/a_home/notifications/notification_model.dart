import 'dart:convert';

class NotificationModel {
  final String? id;
  final String title;
  final String body;
  final String type; // 'payment', 'personal', 'support', 'service'
  final Map<String, dynamic> data;
  final DateTime time;
  final bool isRead;

  NotificationModel({
    this.id,
    required this.title,
    required this.body,
    this.type = 'personal',
    required this.data,
    required this.time,
    this.isRead = false,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    Map<String, dynamic>? data,
    DateTime? time,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
    );
  }

  static bool isAllowedType(String? type, {String? title, String? body}) {
    final t = (type ?? '').trim().toLowerCase();
    // Exclude broad broadcasts
    if (t == 'broadcast' || t == 'promotional' || t == 'all' || t == 'global') {
      return false;
    }
    // Strictly allowed in-app categories
    if (t == 'payment' || t == 'personal' || t == 'support' || t == 'service') {
      return true;
    }
    final text = '${title ?? ''} ${body ?? ''}'.toLowerCase();
    if (text.contains('payout') ||
        text.contains('payment') ||
        text.contains('redeem') ||
        text.contains('refund') ||
        text.contains('wallet') ||
        text.contains('support') ||
        text.contains('ticket') ||
        text.contains('verification')) {
      return true;
    }
    return false;
  }

  static String resolveType({String? type, String? title, String? body}) {
    final t = (type ?? '').trim().toLowerCase();
    if (t == 'payment' || t == 'personal' || t == 'support' || t == 'service') {
      return t;
    }
    final text = '${title ?? ''} ${body ?? ''}'.toLowerCase();
    if (text.contains('payout') ||
        text.contains('payment') ||
        text.contains('redeem') ||
        text.contains('refund') ||
        text.contains('wallet')) {
      return 'payment';
    }
    if (text.contains('support') ||
        text.contains('ticket') ||
        text.contains('contact')) {
      return 'support';
    }
    if (text.contains('promotion') ||
        text.contains('service request') ||
        text.contains('task proof') ||
        text.contains('verification')) {
      return 'service';
    }
    return 'personal';
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'title': title,
    'body': body,
    'type': type,
    'data': data,
    'time': time.toIso8601String(),
    'isRead': isRead,
  };

  factory NotificationModel.fromJson(dynamic rawJson) {
    if (rawJson == null || rawJson is! Map) {
      return NotificationModel(
        title: 'Notification',
        body: rawJson?.toString() ?? '',
        type: 'personal',
        data: const {},
        time: DateTime.now(),
      );
    }
    final Map json = rawJson;
    Map<String, dynamic> rawData = <String, dynamic>{};
    try {
      if (json['data'] != null) {
        if (json['data'] is Map) {
          rawData = Map<String, dynamic>.from(json['data'] as Map);
        } else if (json['data'] is String) {
          try {
            final decoded = jsonDecode(json['data'] as String);
            if (decoded is Map) {
              rawData = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    final rawType = (json['type'] ?? rawData['type'] ?? '').toString();
    final titleStr = (json['title'] ?? '').toString();
    final bodyStr = (json['body'] ?? '').toString();

    DateTime parsedTime = DateTime.now();
    try {
      if (json['time'] != null) {
        final t = json['time'];
        if (t is int) {
          parsedTime = DateTime.fromMillisecondsSinceEpoch(t);
        } else if (t is String && t.isNotEmpty) {
          final intVal = int.tryParse(t);
          if (intVal != null && intVal > 1000000000) {
            parsedTime = DateTime.fromMillisecondsSinceEpoch(intVal);
          } else {
            parsedTime = DateTime.tryParse(t) ?? DateTime.now();
          }
        }
      }
    } catch (_) {}

    return NotificationModel(
      id: json['id']?.toString() ?? json['_id']?.toString(),
      title: titleStr,
      body: bodyStr,
      type: resolveType(type: rawType, title: titleStr, body: bodyStr),
      data: rawData,
      time: parsedTime,
      isRead: json['isRead'] == true,
    );
  }
}

