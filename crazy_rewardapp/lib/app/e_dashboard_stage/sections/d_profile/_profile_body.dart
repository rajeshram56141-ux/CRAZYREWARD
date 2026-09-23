// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../services/launch_url.dart';
import '../../../../services/security_service.dart';
import '../../../../utils/constant/constant.dart';
import '../../../../utils/routes/routes_import.gr.dart';
import '../../../../utils/helper/helper.dart';
import '../../../../widgets/common/custom_toast.dart';
import '../../../../widgets/common/custom_status_popup.dart';
import '../../../../widgets/common/internet_image.dart';
import '../../../b_splash_stage/splash_service.dart';
import '../../../d_authentication_stage/authentication_service.dart';
import '../a_home/wallet/model/redeem_history_model.dart';
import '../a_home/wallet/provider/redeem_history_provider.dart';

class ProfileBody extends HookConsumerWidget {
  const ProfileBody({
    super.key,
    required this.coins,
    required this.gems,
    required this.email,
    required this.name,
    required this.userId,
    required this.photoUrl,
    required this.referralCode,
    this.currentIndex,
  });

  final String userId;
  final String email;
  final String name;
  final double coins;
  final int gems;
  final String photoUrl;
  final String referralCode;
  final ValueNotifier<int>? currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final displayName = name.isNotEmpty ? name : 'Guest User';
    final displayEmail = email.isNotEmpty ? email : 'Guest Account';

    // Fetch user's total successful redeems only (failed/pending are excluded) to determine their badge tier
    final redeemHistoryAsync = ref.watch(payoutHistoryProvider(userId));
    final int redeemCount = redeemHistoryAsync.value
            ?.where((p) => p.status == PayoutStatus.successful)
            .length ??
        0;
    final badge = ProfileBadgeHelper.getBadge(redeemCount);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Solid White Background
            Positioned.fill(
              child: Container(
                color: Colors.white,
              ),
            ),

            // 2. Main Scrollable Content
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  child: Column(
                    children: [
                      SizedBox(height: topPadding > 0 ? topPadding + 28.h : 40.h),

                      // -------------------------------------------------------------
                      // 1. TOP EXECUTIVE PROFILE CARD (MATCHING LUXURY OBSIDIAN & SILVER THEME)
                      // -------------------------------------------------------------
                      SizedBox(
                        width: double.infinity,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            // Main Executive White Profile Card
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top: 44.w),
                              padding: EdgeInsets.fromLTRB(18.w, 54.w, 18.w, 18.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28.r),
                                border: Border.all(
                                  color: const Color(0xFFF1F5F9),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // User Display Name & Email Header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF26262B),
                                                fontSize: 20.sp,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              displayEmail,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF64748B),
                                                fontSize: 12.5.sp,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(width: 8.w),

                                      // User ID Pill (Dark Obsidian, Tap to Copy)
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          Clipboard.setData(ClipboardData(text: userId));
                                          CustomToast.showToast(context, msg: 'copied-to-clipboard');
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E1B2E),
                                            borderRadius: BorderRadius.circular(12.r),
                                            border: Border.all(
                                              color: const Color(0xFF2E2E36),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.15),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'ID: ',
                                                style: GoogleFonts.poppins(
                                                  color: const Color(0xFF9E9EA7),
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                userId.length > 8 ? '${userId.substring(0, 8)}...' : userId,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              Icon(
                                                Icons.copy_rounded,
                                                color: const Color(0xFF9E9EA7),
                                                size: 11.sp,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 18.h),

                                  // 3-Column Stats Card (Total Coins | Total Gems | Badge Tier)
                                  Container(
                                    padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // 1. Total Coins
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => AutoRouter.of(context).push(
                                              RedeemScreenRoute(
                                                userId: userId,
                                                country: '',
                                                isGuest: false,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      'assets/icons/coin.png',
                                                      width: 20.w,
                                                      height: 20.w,
                                                      fit: BoxFit.contain,
                                                    ),
                                                    SizedBox(width: 5.w),
                                                    Flexible(
                                                      child: Text(
                                                        coins.formatK(),
                                                        style: GoogleFonts.poppins(
                                                          color: const Color(0xFF26262B),
                                                          fontSize: 16.sp,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: -0.3,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  'Total Coins',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.poppins(
                                                    color: const Color(0xFF64748B),
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Vertical Divider 1
                                        Container(
                                          height: 28.h,
                                          width: 1.2,
                                          color: const Color(0xFFE2E8F0),
                                        ),

                                        // 2. Total Gems
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => AutoRouter.of(context).push(
                                              SuperOfferScreenRoute(userId: userId),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      'assets/icons/gems.png',
                                                      width: 19.w,
                                                      height: 19.w,
                                                      fit: BoxFit.contain,
                                                    ),
                                                    SizedBox(width: 5.w),
                                                    Flexible(
                                                      child: Text(
                                                        '$gems',
                                                        style: GoogleFonts.poppins(
                                                          color: const Color(0xFF38BDF8),
                                                          fontSize: 16.sp,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: -0.3,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  'Total Gems',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.poppins(
                                                    color: const Color(0xFF64748B),
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Vertical Divider 2
                                        Container(
                                          height: 28.h,
                                          width: 1.2,
                                          color: const Color(0xFFE2E8F0),
                                        ),

                                        // 3. Badge Tier (Interactive)
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              _showBadgeInfoDialog(context, badge, redeemCount);
                                            },
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      badge.iconPath,
                                                      width: 20.w,
                                                      height: 20.w,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (_, __, ___) => Image.asset(
                                                        'assets/icons/bronze.png',
                                                        width: 20.w,
                                                        height: 20.w,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                    SizedBox(width: 5.w),
                                                    Flexible(
                                                      child: Text(
                                                        badge.title,
                                                        style: GoogleFonts.poppins(
                                                          color: const Color(0xFF26262B),
                                                          fontSize: 15.sp,
                                                          fontWeight: FontWeight.w800,
                                                          letterSpacing: -0.2,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 2.h),
                                                Text(
                                                  'Badge Tier',
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.poppins(
                                                    color: const Color(0xFF64748B),
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 14.h),

                                  // Promo Code Banner (Dark Obsidian with Silver-Chrome Action Pill)
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF222226),
                                          Color(0xFF131316),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(18.r),
                                      border: Border.all(
                                        color: const Color(0xFF2E2E36),
                                        width: 1.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.14),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Left Ticket Icon Container
                                        Container(
                                          width: 34.w,
                                          height: 34.w,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E1B2E),
                                            borderRadius: BorderRadius.circular(10.r),
                                            border: Border.all(
                                              color: const Color(0xFF383842),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.confirmation_number_rounded,
                                            color: Colors.white,
                                            size: 19.sp,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),

                                        // Center Column
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Have a Promo Code?',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 1.h),
                                              Text(
                                                'Unlock exciting rewards',
                                                style: GoogleFonts.poppins(
                                                  color: const Color(0xFF9E9EA7),
                                                  fontSize: 10.5.sp,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        SizedBox(width: 6.w),

                                        // Right Silver-Chrome Pill Button "Apply Code"
                                        GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            AutoRouter.of(context).push(const PromoCodeScreenRoute());
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Colors.white,
                                                  Color(0xFFE5E7EB),
                                                  Color(0xFFB0B5C2),
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                              borderRadius: BorderRadius.circular(14.r),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.20),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              'Apply Code',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF16161A),
                                                fontSize: 11.5.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Top Centered Overlapping Avatar
                            Positioned(
                              top: 0,
                              child: SizedBox(
                                width: 92.w,
                                height: 92.w,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 88.w,
                                      height: 88.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 4.w,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: photoUrl.isNotEmpty
                                            ? AvatarInternetImage(
                                                url: photoUrl,
                                                size: 80.w,
                                                borderWidth: 0,
                                                borderColor: Colors.transparent,
                                              )
                                            : Image.asset(
                                                'assets/icons/DIAMONDPANDA_LOGO.png',
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: const Color(0xFF1E1B2E),
                                                  child: Icon(
                                                    Icons.person_rounded,
                                                    color: Colors.white,
                                                    size: 40.sp,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),

                                    // Google Icon Badge (Bottom-Right)
                                    Positioned(
                                      right: 2.w,
                                      bottom: 2.h,
                                      child: Container(
                                        width: 26.w,
                                        height: 26.w,
                                        padding: EdgeInsets.all(4.5.w),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          border: Border.all(
                                            color: const Color(0xFFF1F5F9),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Image.asset(
                                          'assets/icons/google.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // -------------------------------------------------------------
                      // 2. SECTION 1: OPTIONS
                      // -------------------------------------------------------------
                      _buildModernMenuTile(
                        icon: Icons.card_giftcard_rounded,
                        title: 'Redeem',
                        onTap: () => AutoRouter.of(context).push(
                          RedeemScreenRoute(
                            userId: userId,
                            country: '',
                            isGuest: false,
                          ),
                        ),
                      ),
                      _buildModernMenuTile(
                        icon: Icons.receipt_long_rounded,
                        title: 'History',
                        onTap: () => AutoRouter.of(context).push(
                          RedeemHistoryScreenRoute(userId: userId),
                        ),
                      ),
                      _buildModernMenuTile(
                        icon: Icons.history_rounded,
                        title: 'Task History',
                        onTap: () => AutoRouter.of(context).push(
                          TaskHistoryScreenRoute(userId: userId),
                        ),
                      ),
                      _buildModernMenuTile(
                        icon: Icons.language_rounded,
                        title: 'App Language',
                        onTap: () => AutoRouter.of(context).push(
                          const ChangeLanguageScreenRoute(),
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // -------------------------------------------------------------
                      // 3. SECTION 2: SUPPORT & HELP
                      // -------------------------------------------------------------
                      _buildSectionHeader(
                        title: 'SUPPORT & HELP',
                        icon: Icons.support_agent_rounded,
                      ),
                      SizedBox(height: 10.h),

                      _buildModernMenuTile(
                        icon: Icons.headphones_rounded,
                        title: 'Help & Support',
                        onTap: () => AutoRouter.of(context).push(
                          ContactSupportScreenRoute(
                            userId: userId,
                            email: email,
                          ),
                        ),
                      ),
                      _buildModernMenuTile(
                        icon: Icons.design_services_rounded,
                        title: 'Service Requests',
                        onTap: () => AutoRouter.of(context).push(
                          ServicesScreenRoute(
                            userId: userId,
                            email: email,
                          ),
                        ),
                      ),
                      _buildModernMenuTile(
                        icon: Icons.menu_book_rounded,
                        title: 'How To Use',
                        onTap: () => AutoRouter.of(context).push(
                          const HowToUseScreenRoute(),
                        ),
                      ),

                      _buildModernMenuTile(
                        icon: Icons.description_rounded,
                        title: 'Terms & Conditions',
                        onTap: () => LaunchUrl.inWeb(
                          url: SplashService.urlConfig.termsOfService,
                          context: context,
                        ),
                      ),
                      _buildModernMenuTile(
                        icon: Icons.security_rounded,
                        title: 'Privacy Policy',
                        onTap: () => LaunchUrl.inWeb(
                          url: SplashService.urlConfig.privacyPolicy,
                          context: context,
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // -------------------------------------------------------------
                      // 4. SECTION 3: ACCOUNT ACTIONS
                      // -------------------------------------------------------------
                      _buildSectionHeader(
                        title: 'ACCOUNT ACTIONS',
                        icon: Icons.manage_accounts_rounded,
                      ),
                      SizedBox(height: 10.h),

                      _buildModernMenuTile(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        isDestructive: false,
                        onTap: () async {
                          final bool confirmed = await CustomStatusPopup.showConfirmLogout(context: context);
                          if (confirmed && context.mounted) {
                            await AuthenticationService.signOut(context);
                          }
                        },
                      ),
                      _buildModernMenuTile(
                        icon: Icons.delete_outline_rounded,
                        title: 'Delete Account',
                        isDestructive: true,
                        onTap: () async {
                          final bool confirmed = await CustomStatusPopup.showConfirmDeleteAccount(context: context);
                          if (confirmed) {
                            try {
                              final firebaseUser = FirebaseAuth.instance.currentUser;
                              final token = await firebaseUser?.getIdToken() ?? '';
                              final deleteInput = {
                                'userId': firebaseUser?.uid ?? '',
                              };

                              await http.post(
                                Uri.parse('${AppConst.serverBaseUrl}/api/user/delete-account'),
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Authorization': 'Bearer $token',
                                  'user-id': firebaseUser?.uid ?? '',
                                  'device-id': SplashService.deviceId,
                                },
                                body: jsonEncode({
                                  'payload': SecurityService.encryptPayload(
                                    deleteInput,
                                    userId: firebaseUser?.uid ?? '',
                                    deviceId: SplashService.deviceId,
                                  ),
                                }),
                              );

                              if (!context.mounted) return;
                              await AuthenticationService.signOut(context);

                              if (!context.mounted) return;
                              CustomToast.showToast(context, msg: 'account-deletion-success');
                            } catch (e) {
                              if (!context.mounted) return;
                              CustomToast.showToast(context, msg: 'account-deletion-failed');
                            }
                          }
                        },
                      ),

                      SizedBox(height: 110.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // SECTION HEADER
  // -------------------------------------------------------------
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF26262B), size: 16.sp),
          SizedBox(width: 6.w),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFF26262B),
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MENU ITEM (LEFT DARK OBSIDIAN SQUIRCLE + RIGHT WHITE CAPSULE)
  // -------------------------------------------------------------
  Widget _buildModernMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Row(
          children: [
            // Left Dark Obsidian Squircle Icon Container
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: isDestructive ? const Color(0xFFFEF2F2) : const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isDestructive ? const Color(0xFFFECDD3) : const Color(0xFF2E2E36),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDestructive ? 0.04 : 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: isDestructive ? const Color(0xFFEF4444) : Colors.white,
                size: 20.sp,
              ),
            ),

            SizedBox(width: 10.w),

            // Right White Capsule Button with Chevron
            Expanded(
              child: Container(
                height: 44.w,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFFF1F5F9),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF26262B),
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: const Color(0xFF94A3B8),
                      size: 13.sp,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// BADGE MODEL & TIER HELPER (BRONZE, SILVER, GOLD, PLATINUM, DIAMOND)
// -------------------------------------------------------------
class ProfileBadgeInfo {
  final String title;
  final String iconPath;
  final int minRedeems;
  final int nextTarget;
  final String description;
  final Color glowColor;

  const ProfileBadgeInfo({
    required this.title,
    required this.iconPath,
    required this.minRedeems,
    required this.nextTarget,
    required this.description,
    required this.glowColor,
  });
}

class ProfileBadgeHelper {
  static const List<ProfileBadgeInfo> allTiers = [
    ProfileBadgeInfo(
      title: 'Bronze',
      iconPath: 'assets/icons/bronze.png',
      minRedeems: 0,
      nextTarget: 5,
      description: 'Starting Badge (0 - 4 Redeems)',
      glowColor: Color(0xFFCD7F32),
    ),
    ProfileBadgeInfo(
      title: 'Silver',
      iconPath: 'assets/icons/silver.png',
      minRedeems: 5,
      nextTarget: 10,
      description: 'Active Member (5 - 9 Redeems)',
      glowColor: Color(0xFFCBD5E1),
    ),
    ProfileBadgeInfo(
      title: 'Gold',
      iconPath: 'assets/icons/gold.png',
      minRedeems: 10,
      nextTarget: 20,
      description: 'Pro Member (10 - 19 Redeems)',
      glowColor: Color(0xFFFBBF24),
    ),
    ProfileBadgeInfo(
      title: 'Platinum',
      iconPath: 'assets/icons/platinum.png',
      minRedeems: 20,
      nextTarget: 50,
      description: 'Master Member (20 - 49 Redeems)',
      glowColor: Color(0xFFE2E8F0),
    ),
    ProfileBadgeInfo(
      title: 'Diamond',
      iconPath: 'assets/icons/diamond.png',
      minRedeems: 50,
      nextTarget: 50,
      description: 'Elite Top Tier (50+ Redeems)',
      glowColor: Color(0xFF38BDF8),
    ),
  ];

  static ProfileBadgeInfo getBadge(int redeemCount) {
    if (redeemCount >= 50) {
      return allTiers[4]; // Diamond
    } else if (redeemCount >= 20) {
      return allTiers[3]; // Platinum
    } else if (redeemCount >= 10) {
      return allTiers[2]; // Gold
    } else if (redeemCount >= 5) {
      return allTiers[1]; // Silver
    } else {
      return allTiers[0]; // Bronze
    }
  }
}

// -------------------------------------------------------------
// BADGE INFO POPUP DIALOG (LUXURY OBSIDIAN & SILVER THEME)
// -------------------------------------------------------------
void _showBadgeInfoDialog(BuildContext context, ProfileBadgeInfo currentBadge, int redeemCount) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.military_tech_rounded, color: const Color(0xFFF59E0B), size: 24.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'REDEEM BADGE TIERS',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF26262B),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Current Tier Showcase Card (Dark Obsidian)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF222226),
                      Color(0xFF131316),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: const Color(0xFF2E2E36),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E1B2E),
                        border: Border.all(
                          color: const Color(0xFF383842),
                          width: 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        currentBadge.iconPath,
                        width: 36.w,
                        height: 36.w,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/bronze.png',
                          width: 36.w,
                          height: 36.w,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${currentBadge.title} Badge',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.50),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF10B981),
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            'Successful Redeems: $redeemCount',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFE2E8F0),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (currentBadge.title != 'Diamond') ...[
                            SizedBox(height: 2.h),
                            Text(
                              '${currentBadge.nextTarget - redeemCount > 0 ? currentBadge.nextTarget - redeemCount : 0} more successful redeems to unlock next tier',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF9E9EA7),
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // All 5 Tiers List
              ...ProfileBadgeHelper.allTiers.map((tier) {
                final bool isCurrent = tier.title == currentBadge.title;
                final bool isUnlocked = redeemCount >= tier.minRedeems;

                return Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFFFFFBEB)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        tier.iconPath,
                        width: 28.w,
                        height: 28.w,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/bronze.png',
                          width: 28.w,
                          height: 28.w,
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${tier.title} Badge',
                              style: GoogleFonts.poppins(
                                color: isCurrent
                                    ? const Color(0xFFD97706)
                                    : (isUnlocked ? const Color(0xFF26262B) : const Color(0xFF94A3B8)),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              tier.description,
                              style: GoogleFonts.poppins(
                                color: isCurrent
                                    ? const Color(0xFFB45309)
                                    : (isUnlocked ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Icon(Icons.check_circle_rounded, color: const Color(0xFFD97706), size: 19.sp)
                      else if (isUnlocked)
                        Icon(Icons.lock_open_rounded, color: const Color(0xFF94A3B8), size: 16.sp)
                      else
                        Icon(Icons.lock_rounded, color: const Color(0xFFCBD5E1), size: 16.sp),
                    ],
                  ),
                );
              }),

              SizedBox(height: 16.h),

              // Silver-Chrome Gradient "Got It" Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  height: 48.h,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF26262B),
                        Color(0xFF18181B),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: const Color(0xFF3F3F46),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'Got It',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
