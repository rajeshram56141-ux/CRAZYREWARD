import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

extension ExtString on String {
  bool get isValidName => RegExp(r'^[A-Za-z ]{3,}$').hasMatch(this);

  bool get isValidUPI => RegExp(r'^[\w.-]+@+[\w.]+$').hasMatch(this);

  bool get isValidEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  bool get isValidMobileNo => RegExp(r'^\+\d{8,15}$').hasMatch(this);

  String caps() {
    final List<String> words = split('_');
    final List<String> capitalizedWords = words.map((word) {
      if (word.isNotEmpty) {
        if (word.contains(RegExp(r'[A-Z]'))) {
          return word
              .replaceAllMapped(
                RegExp(r'([a-z])([A-Z])'),
                (match) => '${match.group(1)} ${match.group(2)}',
              )
              .split(' ')
              .map(
                (part) =>
                    part[0].toUpperCase() + part.substring(1).toLowerCase(),
              )
              .join(' ');
        } else {
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }
      } else {
        return '';
      }
    }).toList();
    return capitalizedWords.join(' ');
  }

  String lows() => replaceAll(' ', '').toLowerCase();

  String img() =>
      replaceAll(' ', '').replaceAll('-', '').replaceAll('_', '').toLowerCase();

  String parseSymbol() {
    if (!contains(r'\u')) {
      return this;
    }
    return RegExp(r'\\u[0-9A-Fa-f]{4}')
        .allMatches(this)
        .map((match) {
          final unicode = match.group(0)?.substring(2);
          return unicode != null
              ? String.fromCharCode(int.parse(unicode, radix: 16))
              : '';
        })
        .join('');
  }
}

extension ExtInt on int {
  String formatCoins() {
    int value = this;

    final int absValue = value.abs();
    String output;

    if (absValue > 999 && absValue < 99999) {
      final double kValue = absValue / 1000;
      output = kValue == kValue.roundToDouble()
          ? '${kValue.round()}K'
          : '${kValue.toStringAsFixed(1)}K';
    } else if (absValue > 99999 && absValue < 999999) {
      output = '${(absValue / 1000).round()}K';
    } else if (absValue > 999999 && absValue < 999999999) {
      final double mValue = absValue / 1000000;
      output = mValue == mValue.roundToDouble()
          ? '${mValue.round()}M'
          : '${mValue.toStringAsFixed(1)}M';
    } else if (absValue > 999999999) {
      output = '${(absValue / 1000000000).toStringAsFixed(1)}B';
    } else {
      output = absValue.toString();
    }

    return value < 0 ? '-$output' : output;
  }

  String addComma() {
    final String numberString = toString();
    String output = '';

    int count = 0;
    for (int i = numberString.length - 1; i >= 0; i--) {
      output = numberString[i] + output;
      count++;

      if (count == 3 && i > 0) {
        output = ',$output';
        count = 0;
      }
    }

    return output;
  }
}

extension ExtDouble on double {
  String formatBalance({int fractionDigits = 2}) {
    final double curValDouble = toDouble();
    final int curValInt = int.parse(curValDouble.toStringAsFixed(0));

    final String finalCurVal = curValInt == curValDouble
        ? curValInt.toString()
        : curValDouble.toStringAsFixed(fractionDigits);

    return finalCurVal;
  }

  String formatK() {
    final double val = this;
    if (val >= 1000000) {
      final double mVal = val / 1000000.0;
      return mVal % 1 == 0 ? '${mVal.toInt()}M' : '${mVal.toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      final double kVal = val / 1000.0;
      return kVal % 1 == 0 ? '${kVal.toInt()}K' : '${kVal.toStringAsFixed(1)}K';
    }
    final int intVal = val.toInt();
    return intVal == val ? intVal.toString() : val.toStringAsFixed(1);
  }
}

extension ExtTimeStamp on Timestamp {
  String formatTimestamp() {
    final DateTime timestampAsDateTime = toDate().toLocal();
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(timestampAsDateTime);

    if (diff.isNegative || diff.inSeconds < 10) {
      return 'Few sec ago';
    }

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} sec ago';
    }

    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    }

    if (diff.inHours < 24) {
      final hrs = diff.inHours;
      return '$hrs ${hrs == 1 ? 'hr' : 'hrs'} ago';
    }

    if (diff.inDays < 7) {
      final days = diff.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }

    return DateFormat('dd MMM yyyy').format(timestampAsDateTime);
  }

  String get toMaintenanceTime {
    final DateTime dt = toDate();
    final DateTime now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(dt.year, dt.month, dt.day);

    if (targetDay.isBefore(today)) {
      return '00:00:00 IST';
    }

    // ----- Time formatting -----
    int hour = dt.hour;
    final int minute = dt.minute;

    final String period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final String hh = hour.toString().padLeft(2, '0');
    final String mm = minute.toString().padLeft(2, '0');

    final String time = '$hh:$mm $period IST';

    // ✅ Same day
    if (targetDay == today) {
      return time;
    }

    // ✅ Future day → show date + time
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final String date = '${dt.day} ${months[dt.month - 1]}';

    return '$date, $time';
  }
}

extension ExtDateTime on DateTime {
  String formatDateTime() {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(this);
    String time = '';

    if (diff.inSeconds <= 0 ||
        diff.inSeconds > 0 && diff.inMinutes == 0 ||
        diff.inMinutes > 0 && diff.inHours == 0 ||
        diff.inHours > 0 && diff.inDays == 0) {
      if (diff.isNegative || (diff.inSeconds >= 0 && diff.inSeconds < 60)) {
        time = 'just-now'.tr();
      }
      if (diff.inMinutes >= 1 && diff.inMinutes < 60) {
        time = 'minutes-ago'.tr(args: [diff.inMinutes.toString()]);
      }
      if (diff.inHours >= 1 && diff.inHours < 24) {
        time = 'hours-ago'.tr(args: [diff.inHours.toString()]);
      }
    } else if (diff.inDays > 0 && diff.inDays < 7) {
      time = '${diff.inDays} day(s) ago';
      time = 'day-ago'.tr(args: [diff.inDays.toString()]);
    } else {
      time = 'week-ago'.tr(args: [((diff.inDays / 7).floor()).toString()]);
    }
    return time;
  }
}

String? nameValidator(String? value) {
  final cleanValue = value?.trim() ?? '';
  if (cleanValue.isEmpty) {
    return 'empty-name'.tr();
  }
  if (cleanValue.length < 4) {
    return 'Name must be at least 4 characters long';
  }
  if (!cleanValue.isValidName) {
    return 'invalid-name'.tr();
  }
  return null;
}

String? emailValidator(String? email) {
  if (email == null || email.isEmpty) {
    return 'empty-email'.tr();
  }
  if (!email.isValidEmail) {
    return 'invalid-email'.tr();
  }
  return null;
}

String? upiValidator(String? upi) {
  if (upi == null || upi.isEmpty) {
    return 'empty-upi'.tr();
  }
  if (!upi.isValidUPI) {
    return 'invalid-upi'.tr();
  }
  return null;
}

String? mobileValidator(String? mobileNo, String phoneCode) {
  if (mobileNo == null || mobileNo.isEmpty) {
    return 'empty-mobile-no'.tr();
  }

  final fullNumber = '+$phoneCode${mobileNo.trim()}';

  if (!fullNumber.isValidMobileNo) {
    return 'invalid-mobile-no'.tr();
  }
  return null;
}

String? promoCodeValidator(String? promoCode) {
  if (promoCode == null || promoCode.isEmpty) {
    return 'empty-promo-code'.tr();
  }

  return null;
}

String? referralCodeValidator(String? referralCode) {
  if (referralCode == null || referralCode.isEmpty) {
    return null;
  }

  if (referralCode.length != 6) {
    return 'invalid-referral-code'.tr();
  }

  if (referralCode.contains(' ')) {
    return 'invalid-referral-code'.tr();
  }

  final regex = RegExp(r'^[a-zA-Z0-9]+$');
  if (!regex.hasMatch(referralCode)) {
    return 'invalid-referral-code'.tr();
  }

  return null;
}
