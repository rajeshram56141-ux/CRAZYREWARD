import 'dart:convert';
import 'package:auto_route/auto_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../services/analytics_service.dart';
import '../../services/local_storage.dart';
import '../../services/refer_code_service.dart';
import '../../services/security_service.dart';
import '../../services/restart_app.dart';
import '../../utils/constant/constant.dart';
import '../../utils/routes/routes_import.gr.dart';
import '../../widgets/common/custom_toast.dart';
import '../../widgets/common/custom_status_popup.dart';
import '../../widgets/screens/account_blocked_screen.dart';
import '../../widgets/screens/account_deleted_screen.dart';
import '../b_splash_stage/splash_service.dart';

class AuthenticationService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final CollectionReference<Map<String, dynamic>> _collection =
      FirebaseFirestore.instance.collection('users');

  static Future<void> signInWithGoogle(BuildContext context) async {
    final accepted = await CustomStatusPopup.showDisclosure(context);
    if (!accepted) return;

    try {
      await _googleSignIn.initialize();
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.authenticate();
      } catch (_) {
        account = null;
      }

      if (account == null) {
        // User cancelled or error
        return;
      }

      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
        return;
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;

      if (user == null) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
        return;
      }

      bool isExistingUser = false;
      try {
        final token = await user.getIdToken();
        final bodyInput = {
          'email': user.email ?? '',
          'name': user.displayName ?? '',
          'photoUrl': user.photoURL ?? '',
          'deviceId': SplashService.deviceId,
          'gaid': SplashService.gaid,
          'isGuest': false,
        };
        final response = await SecurityService.post(
          AppConst.userSyncApi,
          userId: user.uid,
          deviceId: SplashService.deviceId,
          token: token,
          body: bodyInput,
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          var resData = jsonDecode(response.body);

          final bool exists = resData['exists'] == true || resData['user'] != null;
          final userData = resData['user'];
          final String email = (userData?['email'] ?? resData['email'])?.toString().trim() ?? '';
          final String uId = (userData?['userId'] ?? resData['userId'])?.toString().trim() ?? '';
          final bool isGuest = userData?['isGuest'] == true || resData['isGuest'] == true;
          final bool hasValidUser = isGuest || (email.isNotEmpty && email != 'null') || uId.isNotEmpty;
          isExistingUser = exists && hasValidUser;
        } else if (response.statusCode == 400 || response.statusCode == 403) {
          final resData = jsonDecode(response.body);
          if (resData['isDeleted'] == true) {
            await _googleSignIn.signOut();
            await _auth.signOut();
            await SecurityService.clearSecureKeys();
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountDeletedScreen()),
            );
            return;
          } else if (resData['isBlocked'] == true || resData['blocked'] == true) {
            await _googleSignIn.signOut();
            await _auth.signOut();
            await SecurityService.clearSecureKeys();
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountBlockedScreen()),
            );
            return;
          } else if (resData['deviceLimitExceeded'] == true) {
            await _googleSignIn.signOut();
            await _auth.signOut();
            await SecurityService.clearSecureKeys();
            if (!context.mounted) return;
            final List emails = resData['emails'] ?? [];
            CustomToast.showDeviceLimitPopup(
              context: context,
              title: 'device-limit-exceeded'.tr(),
              subTitle: 'device-limit-exceeded-message'.tr(
                args: [
                  AppConst.maxAccountPerDevice.toString(),
                  emails.map((e) => '• $e').join('\n'),
                ],
              ),
              registeredEmails: emails.map((e) => e.toString()).toList(),
            );
            return;
          } else if (response.statusCode == 403) {
            if (!context.mounted) return;
            AutoRouter.of(context).replace(const SplashScreenRoute());
            return;
          }
        }
      } catch (e) {
         // debugPrint('MongoDB User Sync Error: $e');
        isExistingUser = false;
      }

      if (!isExistingUser) {
        try {
          final String fetchedReferralCode = await ReferCodeService.extractReferralCode();
          final String newReferralCode = await ReferCodeService.generateReferralCode();
          final token = await user.getIdToken() ?? '';

          final detailsInput = {
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'mobileNo': '',
            'gender': 'Male',
            'country': 'IN',
            'referralCode': newReferralCode,
            'inputReferralCode': fetchedReferralCode,
            'deviceId': SplashService.deviceId,
            'gaid': SplashService.gaid,
          };

          await SecurityService.post(
            AppConst.saveUserDetailsApi,
            userId: user.uid,
            deviceId: SplashService.deviceId,
            token: token,
            body: detailsInput,
          ).timeout(const Duration(seconds: 8));
        } catch (_) {}

        AnalyticsService.logSignup(user.uid);
        LocalStorage.setOnboardingCompleted();

        if (context.mounted) {
          AutoRouter.of(
            context,
          ).replace(DashboardScreenRoute(userId: user.uid));
        }
      } else {
        AnalyticsService.logSignup(user.uid);
        LocalStorage.setOnboardingCompleted();

        if (context.mounted) {
          AutoRouter.of(
            context,
          ).replace(DashboardScreenRoute(userId: user.uid));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' ||
          e.code == 'invalid-credential') {
        if (!context.mounted) return;
        CustomToast.showToast(context, msg: 'invalid-credential');
      } else {
        if (!context.mounted) return;
        CustomToast.showToast(context);
      }
    } catch (e) {
       // debugPrint(e.toString());
      if (!context.mounted) return;
      CustomToast.showToast(context);
    }
  }

  static Future<void> signInAnonymously(BuildContext context) async {
    final accepted = await CustomStatusPopup.showGuestDisclosure(context);
    if (!accepted) return;

    try {
      final UserCredential userCredential = await _auth.signInAnonymously();

      final User? user = userCredential.user;

      if (user == null) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
        return;
      }

      try {
        final token = await user.getIdToken() ?? '';
        final referralCode = await ReferCodeService.generateReferralCode();

        final guestInput = {
          'name': 'Guest User',
          'email': '',
          'photoUrl': '',
          'mobileNo': '',
          'isGuest': true,
          'referralCode': referralCode,
          'deviceId': SplashService.deviceId,
          'gaid': SplashService.gaid,
        };

        await SecurityService.post(
          '${AppConst.serverBaseUrl}/api/save-user-details',
          userId: user.uid,
          deviceId: SplashService.deviceId,
          token: token,
          body: guestInput,
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
         // debugPrint('MongoDB Guest Sync Error: $e');
      }

      AnalyticsService.logSignup(user.uid);

      if (context.mounted) {
        AutoRouter.of(context).replace(DashboardScreenRoute(userId: user.uid));
      }
    } catch (e) {
       // debugPrint(e.toString());
      if (!context.mounted) return;
      CustomToast.showToast(context);
    }
  }

  static Future<void> connectGoogleAccount(BuildContext context) async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser == null || !currentUser.isAnonymous) {
        if (!context.mounted) return;
        CustomToast.showToast(context, msg: 'no-guest-session');
        return;
      }

      await _googleSignIn.initialize();
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.authenticate();
      } catch (_) {
        account = null;
      }

      if (account == null) {
        // User cancelled or error
        return;
      }

      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        if (!context.mounted) return;
        CustomToast.showToast(context);
        return;
      }

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      await currentUser.linkWithCredential(credential);

      await _collection.doc(currentUser.uid).update({
        'name': account.displayName ?? 'User',
        'email': account.email,
        'photoUrl': account.photoUrl ?? '',
        'isGuest': false,
      });

      if (!context.mounted) return;
      CustomToast.showToast(context, msg: 'google-account-success');
    } on FirebaseAuthException catch (e) {
       // debugPrint('FirebaseAuthException: ${e.code}');
      if (e.code == 'credential-already-in-use') {
        if (!context.mounted) return;
        CustomToast.showToast(context, msg: 'google-account-duplicate');
      } else {
        if (!context.mounted) return;
        CustomToast.showToast(context);
      }
    } catch (e) {
       // debugPrint('Google Sign-in Error: $e');
      if (!context.mounted) return;
      CustomToast.showToast(context);
    }
  }

  static Future<void> signOut(BuildContext context) async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await SecurityService.clearSecureKeys();
    if (!context.mounted) return;
    RestartApp.rebirth(context);
  }
}
