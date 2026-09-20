import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:play_install_referrer/play_install_referrer.dart';

class ReferCodeService {
  static final Random _random = Random();

  static const String _possibleChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  static Future<String> generateReferralCode() async {
    while (true) {
      final String referralCode = List.generate(
        6,
        (index) => _possibleChars[_random.nextInt(_possibleChars.length)],
      ).join();

      final QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('referralCode', isEqualTo: referralCode)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return referralCode;
      }
    }
  }

  static Future<String> extractReferralCode() async {
    final ReferrerDetails referrerDetails =
        await PlayInstallReferrer.installReferrer;

    final String referralCode = referrerDetails.installReferrer ?? '';
    return referralCode.length == 6 ? referralCode : '';
  }
}
