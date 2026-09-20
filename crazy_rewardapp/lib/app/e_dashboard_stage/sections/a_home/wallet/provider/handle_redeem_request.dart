// ignore_for_file: unused_import, deprecated_member_use, depend_on_referenced_packages
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../../../../services/analytics_service.dart';
import '../../../../../../services/cloud_functions.dart';
import '../../../../../../services/launch_url.dart';
import '../../../../../../services/local_storage.dart';
import '../../../../../../utils/helper/helper.dart';
import '../../../../../../utils/routes/routes_import.gr.dart';
import '../../../../../../utils/theme/theme.dart';
import '../../../../../../widgets/common/custom_toast.dart';
import '../../../../../../widgets/common/custom_loading.dart';
import '../../../../../../widgets/common/internet_image.dart';
import '../../../../../../services/security_service.dart';
import '../../../../../../utils/constant/constant.dart';
import '../../../../../b_splash_stage/splash_service.dart';
import '../../../../provider/dashboard_provider.dart';
import '../model/wallet_catalog_model.dart';
import '../../../../../../widgets/common/custom_status_popup.dart';

class RedeemRequest {
  static Future<void> handle({
    required BuildContext context,
    required double availableCoins,
    required String userId,
    required WalletMethod paymentMethod,
    required WalletDenomination denomination,
    required bool isGuest,
    Rect? originRect,
  }) async {
    final bool hasInsufficient = isGuest || availableCoins < denomination.coins;

    // If user has sufficient balance and is not a guest, ensure account details (mobile number) are completed first!
    if (!hasInsufficient && !isGuest) {
      final userProfile = await DashboardService.fetchUserProfile(userId);
      if (userProfile == null || userProfile.mobileNo.trim().isEmpty) {
        if (!context.mounted) return;
        final bool? detailsSaved = await showGeneralDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          barrierColor: Colors.black.withValues(alpha: 0.78),
          transitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (ctx, anim1, anim2) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              child: _WithdrawAccountDetailsPopup(
                userId: userId,
                currentName: userProfile?.name ?? '',
              ),
            );
          },
          transitionBuilder: (ctx, anim, secondaryAnim, child) {
            return ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: anim, child: child),
            );
          },
        );

        // If user canceled or didn't save, do not proceed to redeem
        if (detailsSaved != true) {
          return;
        }
      }
    }

    if (!context.mounted) return;

    // Calculate alignment relative to screen from originRect for the emerging expansion animation
    final screenSize = MediaQuery.of(context).size;
    final Alignment originAlignment;
    if (originRect != null && screenSize.width > 0 && screenSize.height > 0) {
      final originCenter = originRect.center;
      final alignX = (originCenter.dx / screenSize.width) * 2 - 1.0;
      final alignY = (originCenter.dy / screenSize.height) * 2 - 1.0;
      originAlignment = Alignment(alignX.clamp(-1.0, 1.0), alignY.clamp(-1.0, 1.0));
    } else {
      originAlignment = Alignment.center;
    }

    final Widget dialogContent = hasInsufficient
        ? _InsufficientBalanceSheet(
            amount: denomination.amount,
            coins: denomination.coins,
            availableCoins: availableCoins,
            symbol: paymentMethod.symbol,
            image: paymentMethod.image,
            methodName: paymentMethod.title,
            message: isGuest
                ? 'guest-mode-restriction'
                : 'insufficient-coins-message',
          )
        : RedeemPopup(
            userId: userId,
            paymentMethod: paymentMethod,
            denomination: denomination,
            availableCoins: availableCoins,
          );

    final bool? result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (ctx, anim1, anim2) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
          child: dialogContent,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInBack,
        );

        return ScaleTransition(
          alignment: originAlignment,
          scale: Tween<double>(begin: 0.12, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: anim,
              curve: const Interval(0.0, 0.60, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );

    if (result == true) {
      if (context.mounted) {
        AutoRouter.of(
          context,
        ).push(RedeemHistoryScreenRoute(userId: userId));

        if (!LocalStorage.hasUserRated()) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              CustomToast.showRatingDialog(context);
            }
          });
        }
      }
    }
  }
}

// Backward compatibility alias
typedef PaymentRequest = RedeemRequest;

// ---------------------------------------------------------------------------
// REDEEM POPUP (MODERN DARK CYBER VOUCHER MODAL)
// ---------------------------------------------------------------------------
class RedeemPopup extends HookWidget {
  const RedeemPopup({
    super.key,
    required this.userId,
    required this.paymentMethod,
    required this.denomination,
    required this.availableCoins,
  });

  final String userId;
  final WalletMethod paymentMethod;
  final WalletDenomination denomination;
  final double availableCoins;

  @override
  Widget build(BuildContext context) {
    final formKey = useMemoized(() => GlobalKey<FormState>());

    final controllers = useMemoized(() {
      final map = <String, TextEditingController>{};
      for (final field in paymentMethod.validators) {
        if (field.toLowerCase().contains('email')) {
          map[field] = TextEditingController(
            text: FirebaseAuth.instance.currentUser?.email ?? '',
          );
        } else {
          map[field] = TextEditingController();
        }
      }
      return map;
    });

    useEffect(() {
      return () {
        for (final con in controllers.values) {
          con.dispose();
        }
      };
    }, []);

    final statusMessage = useState<String?>(null);
    final isSuccess = useState(false);
    final isTaskIncomplete = useState(false);
    final isLoading = useState(false);
    final returnedRedeemCode = useState<String?>(null);

    String cleanKey(String k) {
      return k.contains(':') ? k.split(':')[0] : k;
    }

    IconData getPrefixIcon(String key) {
      final k = cleanKey(key).toLowerCase();
      if (k.contains('name')) {
        return Icons.person_rounded;
      } else if (k.contains('email')) {
        return Icons.alternate_email_rounded;
      } else if (k.contains('upi')) {
        return Icons.account_balance_wallet_rounded;
      } else if (k.contains('phone') || k.contains('mobile') || k.contains('number')) {
        return Icons.phone_android_rounded;
      } else if (k.contains('op') || k.contains('operator') || k.contains('sim')) {
        return Icons.sim_card_rounded;
      } else if (k.contains('state') || k.contains('circle') || k.contains('region')) {
        return Icons.location_on_rounded;
      }
      return Icons.edit_note_rounded;
    }

    String getFieldLabel(String key) {
      final k = cleanKey(key).toLowerCase();
      if (k.contains('email')) {
        return 'EMAIL ADDRESS';
      } else if (k.contains('upi')) {
        return 'UPI ID / VPA';
      } else if (k.contains('name')) {
        return 'FULL NAME';
      } else if (k.contains('mobile') || k.contains('phone') || k.contains('number')) {
        return 'MOBILE NUMBER';
      } else if (k.contains('opcode') || k.contains('operator')) {
        return 'OPERATOR';
      } else if (k.contains('state') || k.contains('circle')) {
        return 'TELECOM CIRCLE / STATE';
      }
      final clean = cleanKey(key);
      return clean.replaceAll('_', ' ').replaceAll('-', ' ').toUpperCase();
    }

    String getHintText(String key) {
      final clean = cleanKey(key);
      if (paymentMethod.hints.containsKey(clean) &&
          paymentMethod.hints[clean]!.isNotEmpty) {
        return paymentMethod.hints[clean]!;
      }
      final k = clean.toLowerCase();
      if (k.contains('email')) {
        return 'enter-email'.tr();
      } else if (k.contains('upi')) {
        return 'enter-upi'.tr();
      } else if (k.contains('name')) {
        return 'enter-name'.tr();
      } else if (k.contains('mobile') || k.contains('phone') || k.contains('number')) {
        return 'Enter 10-digit mobile number';
      } else if (k.contains('opcode') || k.contains('operator')) {
        return 'Select Operator';
      } else if (k.contains('state') || k.contains('circle')) {
        return 'Select Telecom Circle';
      }
      return 'Enter ${clean.replaceAll('_', ' ').replaceAll('-', ' ').caps()}';
    }

    String? Function(String?)? getValidator(String key) {
      final clean = cleanKey(key);
      final k = clean.toLowerCase();
      if (k.contains('email')) {
        return emailValidator;
      } else if (k.contains('upi')) {
        return upiValidator;
      } else if (k.contains('name')) {
        return nameValidator;
      } else if (k.contains('mobile') || k.contains('phone') || k.contains('number')) {
        return (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Mobile number is required';
          }
          final trimmed = value.trim();
          if (!RegExp(r'^\d{10,12}$').hasMatch(trimmed)) {
            return 'Enter a valid 10-digit mobile number';
          }
          return null;
        };
      }
      return (value) {
        if (value == null || value.trim().isEmpty) {
          return '${getHintText(key)} is required';
        }
        return null;
      };
    }

    TextInputType getKeyboardType(String key) {
      final k = cleanKey(key).toLowerCase();
      if (k.contains('email')) {
        return TextInputType.emailAddress;
      } else if (k.contains('phone') || k.contains('mobile') || k.contains('number')) {
        return TextInputType.phone;
      }
      return TextInputType.text;
    }

    Widget buildLabeledField(String key) {
      final controller = controllers[key];
      if (controller == null) return const SizedBox.shrink();

      return Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Field Label
            Padding(
              padding: EdgeInsets.only(left: 2.w, bottom: 6.h),
              child: Text(
                getFieldLabel(key),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF1E1B4B),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Field Input Box
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: key.contains(':')
                  ? DropdownButtonFormField<String>(
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      value: controller.text.isNotEmpty &&
                              key.split(':')[1].split('|').map((e) => e.trim()).toList().contains(controller.text)
                          ? controller.text
                          : null,
                      hint: Text(
                        getHintText(key),
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      icon: const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Color(0xFFAB31DE),
                      ),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: getHintText(key),
                        hintStyle: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          getPrefixIcon(key),
                          color: const Color(0xFFAB31DE),
                          size: 20.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10.h,
                          horizontal: 16.w,
                        ),
                        errorStyle: GoogleFonts.outfit(
                          color: const Color(0xFFEF4444),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      items: key
                          .split(':')[1]
                          .split('|')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .map((opt) {
                        return DropdownMenuItem<String>(
                          value: opt,
                          child: Text(
                            opt,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF1E1B4B),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          controller.text = val;
                        }
                      },
                      validator: getValidator(key),
                    )
                  : TextFormField(
                      controller: controller,
                      keyboardType: getKeyboardType(key),
                      cursorColor: const Color(0xFFAB31DE),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: getHintText(key),
                        hintStyle: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          getPrefixIcon(key),
                          color: const Color(0xFFAB31DE),
                          size: 20.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 14.h,
                          horizontal: 16.w,
                        ),
                        errorStyle: GoogleFonts.outfit(
                          color: const Color(0xFFEF4444),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      validator: getValidator(key),
                    ),
            ),
          ],
        ),
      );
    }

    if (statusMessage.value != null) {
      final detail = controllers.entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => e.value.text.trim())
          .firstOrNull;

      return _RedeemResultView(
        userId: userId,
        isSuccess: isSuccess.value,
        isTaskIncomplete: isTaskIncomplete.value,
        isAutoPay: paymentMethod.autoPayment,
        message: statusMessage.value!,
        redeemCode: returnedRedeemCode.value,
        accountDetail: detail,
        paymentMethodTitle: paymentMethod.title,
        paymentMethodImage: paymentMethod.image,
        onContinue: () => Navigator.pop(context, isSuccess.value),
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28.r),
            child: Stack(
              children: [
                // Form Content
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 38.h, 20.w, 20.h),
                  child: Form(
                    key: formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Premium Voucher Card Header
                        _VoucherReceiptCard(
                          paymentMethod: paymentMethod,
                          denomination: denomination,
                        ),

                        SizedBox(height: 18.h),

                        // Input Fields with clean labels
                        for (final field in paymentMethod.validators)
                          buildLabeledField(field),

                        SizedBox(height: 10.h),

                        // Confirm Button
                        _PopScaleButton(
                          onTap: isLoading.value
                              ? () {}
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }

                                  isLoading.value = true;

                                  try {
                                    final paymentDetailMap = {
                                      for (final field in paymentMethod.validators)
                                        field.contains(':')
                                            ? field.split(':')[0].trim()
                                            : field.trim(): controllers[field]?.text.trim() ?? '',
                                    };

                                    final response = await CloudFunctions.requestPayout(
                                      id: denomination.id,
                                      coinsRequired: denomination.coins,
                                      amount: denomination.amount,
                                      paymentMethod: paymentMethod.id,
                                      paymentDetail: paymentDetailMap,
                                    );

                                    if (response['response'] == 'success' || response['success'] == true) {
                                      isSuccess.value = true;
                                      AnalyticsService.logPayoutRequested(
                                        amount: denomination.amount,
                                        coins: denomination.coins,
                                        paymentMethod: paymentMethod.id,
                                        status: (response['status'] ?? response['payout']?['status'] ?? response['data']?['status'])?.toString(),
                                      );
                                      Map<String, dynamic>? payoutMap;
                                      if (response['payout'] is Map) {
                                        payoutMap = Map<String, dynamic>.from(response['payout'] as Map);
                                      } else if (response['data'] is Map) {
                                        payoutMap = Map<String, dynamic>.from(response['data'] as Map);
                                      }

                                      final dynamic foundCode = response['redeemCode'] ??
                                          response['giftCode'] ??
                                          response['gift_code'] ??
                                          response['code'] ??
                                          response['voucherCode'] ??
                                          response['pin'] ??
                                          response['giftPin'] ??
                                          payoutMap?['redeemCode'] ??
                                          payoutMap?['giftCode'] ??
                                          payoutMap?['gift_code'] ??
                                          payoutMap?['code'] ??
                                          payoutMap?['voucherCode'] ??
                                          payoutMap?['pin'] ??
                                          payoutMap?['giftPin'];

                                      if (foundCode != null &&
                                          foundCode.toString().trim().isNotEmpty &&
                                          foundCode.toString().trim().toLowerCase() != 'null' &&
                                          foundCode.toString().trim().toLowerCase() != 'n/a') {
                                        returnedRedeemCode.value = foundCode.toString().trim();
                                      }

                                      final apiStatus = (response['status'] ?? payoutMap?['status'])?.toString();
                                      if (apiStatus == 'inprogress') {
                                        statusMessage.value = 'withdraw-processing'.tr();
                                      } else {
                                        statusMessage.value =
                                            'withdraw-success-message'.tr();
                                      }
                                    } else {
                                      final errReason = response['message']?.toString() ??
                                          response['error']?.toString() ??
                                          response['reason']?.toString();
                                      final bool isCheck = response['isRedeemCheck'] == true ||
                                          response['taskKey'] != null ||
                                          (errReason != null &&
                                              (errReason.toLowerCase().contains('remaining') ||
                                               errReason.toLowerCase().contains('complete ')));
                                      isTaskIncomplete.value = isCheck;
                                      statusMessage.value = (errReason != null && errReason.isNotEmpty)
                                          ? errReason
                                          : 'The redeem couldn’t be completed. Please try again later.';
                                    }
                                  } catch (e) {
                                    final errStr = e.toString();
                                    statusMessage.value = errStr.contains('Exception:')
                                        ? errStr.replaceAll('Exception:', '').trim()
                                        : 'The redeem couldn’t be completed. Please try again later.';
                                  } finally {
                                    isLoading.value = false;
                                  }
                                },
                          child: Container(
                            width: double.infinity,
                            height: 48.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE39FFF),
                                  Color(0xFFAB31DE),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: isLoading.value
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'CONFIRM REDEEM',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),

                        SizedBox(height: 4.h),
                      ],
                    ),
                  ),
                ),

                // Top Right Close (X) Button
                Positioned(
                  top: 10.h,
                  right: 10.w,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20.sp,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Backward compatibility alias
typedef WithdrawPopup = RedeemPopup;

// ---------------------------------------------------------------------------
// VOUCHER RECEIPT CARD COMPONENT
// ---------------------------------------------------------------------------
class _VoucherReceiptCard extends StatelessWidget {
  const _VoucherReceiptCard({
    required this.paymentMethod,
    required this.denomination,
  });

  final WalletMethod paymentMethod;
  final WalletDenomination denomination;

  @override
  Widget build(BuildContext context) {
    final String formattedCoins = denomination.coins
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InternetImage(
                  url: paymentMethod.image,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      paymentMethod.title,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (denomination.subtitle != null && denomination.subtitle!.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        denomination.subtitle!,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOU WILL GET',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF94A3B8),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${paymentMethod.symbol}${denomination.amount}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/coin.png',
                        height: 16.h,
                        width: 16.h,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        formattedCoins,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// INSUFFICIENT BALANCE BOTTOM SHEET (MODERN DARK WARNING MODAL)
// ---------------------------------------------------------------------------
class _InsufficientBalanceSheet extends StatelessWidget {
  const _InsufficientBalanceSheet({
    required this.image,
    required this.symbol,
    required this.amount,
    required this.coins,
    required this.availableCoins,
    required this.methodName,
    required this.message,
  });

  final String image;
  final String symbol;
  final int amount;
  final int coins;
  final double availableCoins;
  final String methodName;
  final String message;

  @override
  Widget build(BuildContext context) {
    final int missingCoins = (coins - availableCoins).toInt().clamp(0, coins);

    final String formattedCoins = coins.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final String formattedMissing = missingCoins.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: Stack(
          children: [
            // Top Right Close (X) Button
            Positioned(
              top: 14.h,
              right: 14.w,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 32.w,
                  height: 32.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20.sp,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 20.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Icon Aura
                  Container(
                    width: 80.w,
                    height: 80.w,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFEF2F2),
                    ),
                    padding: EdgeInsets.all(8.w),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFEE2E2),
                      ),
                      child: Icon(
                        Icons.priority_high_rounded,
                        color: const Color(0xFFEF4444),
                        size: 38.sp,
                      ),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  Text(
                    'Insufficient Coins',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1E1B4B),
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    missingCoins > 0
                        ? 'You need $formattedMissing more coins to redeem this voucher. Play games or complete tasks to earn more!'
                        : message.tr(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 18.h),

                  // Voucher Card
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFFF1F5F9),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38.w,
                          height: 38.w,
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: InternetImage(
                            url: image,
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              methodName,
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1E1B4B),
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$symbol$amount',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFAB31DE),
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/icons/coin.png',
                                height: 15.h,
                                width: 15.h,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                formattedCoins,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFAB31DE),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Button
                  _PopScaleButton(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      height: 46.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Text(
                        'GOT IT',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14.5.sp,
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
    );
  }
}

// ---------------------------------------------------------------------------
// REDEEM RESULT VIEW (MATCHING USER SUCCESS POPUP MOCKUP)
// ---------------------------------------------------------------------------
class _RedeemResultView extends StatelessWidget {
  const _RedeemResultView({
    required this.isSuccess,
    this.isTaskIncomplete = false,
    this.isAutoPay = false,
    required this.message,
    required this.onContinue,
    this.userId,
    this.redeemCode,
    this.accountDetail,
    this.paymentMethodTitle,
    this.paymentMethodImage,
  });

  final bool isSuccess;
  final bool isTaskIncomplete;
  final bool isAutoPay;
  final String message;
  final VoidCallback onContinue;
  final String? userId;
  final String? redeemCode;
  final String? accountDetail;
  final String? paymentMethodTitle;
  final String? paymentMethodImage;

  @override
  Widget build(BuildContext context) {
    final titleLower = (paymentMethodTitle ?? '').toLowerCase();
    final bool isVoucher = titleLower.contains('gift') ||
        titleLower.contains('card') ||
        titleLower.contains('voucher') ||
        titleLower.contains('play') ||
        titleLower.contains('amazon') ||
        (redeemCode != null && redeemCode!.isNotEmpty);

    final hasCode = redeemCode != null &&
        redeemCode!.trim().isNotEmpty &&
        redeemCode!.trim().toLowerCase() != 'null' &&
        redeemCode!.toLowerCase() != 'n/a';
    final String cleanCode = hasCode ? redeemCode!.trim() : '';

    final bool isGooglePlay = titleLower.contains('google') ||
        titleLower.contains('play') ||
        cleanCode.startsWith('http');

    final bool isManualSuccess = isSuccess && !hasCode && !isAutoPay;

    final String mainTitle;
    if (isSuccess) {
      if (isManualSuccess) {
        mainTitle = 'Redeem Success';
      } else {
        mainTitle = isVoucher ? 'Voucher Purchased!' : 'Redeem Successful!';
      }
    } else if (isTaskIncomplete) {
      mainTitle = 'Task Inprogress';
    } else {
      mainTitle = 'Redeem Failed!';
    }

    Widget? customBody;
    String? primaryButtonText;
    VoidCallback? onPrimaryTap;
    String? secondaryButtonText;
    VoidCallback? onSecondaryTap;

    if (isManualSuccess) {
      primaryButtonText = 'DONE';
      onPrimaryTap = onContinue;
    } else if (isSuccess && cleanCode.isNotEmpty) {
      customBody = GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: cleanCode));
          HapticFeedback.lightImpact();

          if (isGooglePlay) {
            CustomToast.showToast(
              context,
              msg: 'Code Copied! Opening Google Play...',
            );
            LaunchUrl.inWeb(
              url: 'https://play.google.com/redeem?code=${Uri.encodeComponent(cleanCode)}',
              context: context,
            );
          } else {
            CustomToast.showToast(
              context,
              msg: 'copied-to-clipboard'.tr(),
            );
          }
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFFF1F5F9),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Method Icon Badge
                  Container(
                    width: 32.w,
                    height: 32.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: (paymentMethodImage != null && paymentMethodImage!.isNotEmpty)
                        ? InternetImage(
                            url: paymentMethodImage!,
                            fit: BoxFit.contain,
                          )
                        : Icon(
                            Icons.confirmation_number_rounded,
                            color: const Color(0xFFAB31DE),
                            size: 16.sp,
                          ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      paymentMethodTitle ?? 'Voucher Code',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        color: const Color(0xFFAB31DE),
                        size: 14.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        isGooglePlay ? 'Copy & Redeem' : 'Copy',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFAB31DE),
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: SelectableText(
                  cleanCode,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFAB31DE),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
      primaryButtonText = 'DONE';
      onPrimaryTap = onContinue;
    } else {
      primaryButtonText = isSuccess
          ? 'DONE'
          : (isTaskIncomplete ? 'COMPLETE TASK' : 'TRY LATER');
      onPrimaryTap = onContinue;
    }

    final String? popupMessage;
    if (cleanCode.isNotEmpty) {
      popupMessage = null;
    } else if (isManualSuccess) {
      popupMessage =
          'Your redeem request has been successfully submitted. Please wait up to 24 hours.';
    } else if (message.isNotEmpty) {
      popupMessage = message;
    } else {
      popupMessage = isSuccess
          ? 'Your redeem request has been successfully submitted. Please wait up to 24 hours.'
          : 'The redeem couldn’t be completed. Please try again later.';
    }

    Widget? centerIcon;
    Color? primaryButtonColor;
    StatusPopupType popupType =
        isSuccess ? StatusPopupType.success : StatusPopupType.failed;
    String popupTag = isSuccess ? 'Congratulations' : 'Oops!';

    if (isTaskIncomplete) {
      popupType = StatusPopupType.warning;
      popupTag = 'Notice';
      primaryButtonColor = const Color(0xFFD97706);
      centerIcon = Center(
        child: Container(
          width: 80.w,
          height: 80.w,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFFBEB),
          ),
          padding: EdgeInsets.all(8.w),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFEF3C7),
            ),
            child: Icon(
              Icons.priority_high_rounded,
              color: const Color(0xFFD97706),
              size: 38.sp,
            ),
          ),
        ),
      );
    }

    return CustomStatusPopup(
      type: popupType,
      isSuccess: isTaskIncomplete ? null : isSuccess,
      tag: popupTag,
      title: mainTitle,
      message: popupMessage,
      centerIcon: centerIcon,
      primaryButtonColor: primaryButtonColor,
      customBody: customBody,
      primaryButtonText: primaryButtonText,
      onPrimaryTap: onPrimaryTap,
      secondaryButtonText: secondaryButtonText,
      onSecondaryTap: onSecondaryTap,
      onClose: onContinue,
    );
  }
}

class _PopScaleButton extends StatefulWidget {
  const _PopScaleButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_PopScaleButton> createState() => _PopScaleButtonState();
}

class _PopScaleButtonState extends State<_PopScaleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MANDATORY WITHDRAWAL ACCOUNT DETAILS POPUP (FIRST-TIME REDEMPTION)
// ---------------------------------------------------------------------------
class _WithdrawAccountDetailsPopup extends ConsumerStatefulWidget {
  const _WithdrawAccountDetailsPopup({
    required this.userId,
    required this.currentName,
  });

  final String userId;
  final String currentName;

  @override
  ConsumerState<_WithdrawAccountDetailsPopup> createState() => _WithdrawAccountDetailsPopupState();
}

class _WithdrawAccountDetailsPopupState extends ConsumerState<_WithdrawAccountDetailsPopup> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  String _selectedGender = 'Male';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _mobileController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final String name = _nameController.text.trim();
    final String rawMobile = _mobileController.text.trim();

    if (name.isEmpty || name.length < 3) {
      CustomToast.showToast(context, msg: 'Please enter a valid name (at least 3 characters)');
      return;
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(rawMobile)) {
      CustomToast.showToast(context, msg: 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken() ?? '';
      final fullMobile = '+91$rawMobile';

      final detailsInput = {
        'name': name,
        'email': user?.email ?? '',
        'photoUrl': user?.photoURL ?? '',
        'mobileNo': fullMobile,
        'gender': _selectedGender,
        'country': 'IN',
        'deviceId': SplashService.deviceId,
        'gaid': SplashService.gaid,
      };

      final res = await SecurityService.post(
        AppConst.saveUserDetailsApi,
        userId: widget.userId,
        deviceId: SplashService.deviceId,
        token: token,
        body: detailsInput,
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        ref.invalidate(DashboardService.userDataProvider(widget.userId));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          CustomToast.showToast(context, msg: 'Failed to save account details. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.showToast(context, msg: 'Network error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 360.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 22.h),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Icon & Title
                    Row(
                      children: [
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                            ),
                            borderRadius: BorderRadius.circular(14.r),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAB31DE).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 24.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Verification',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF1E1B4B),
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Required once to enable payouts',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 18.h),
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    SizedBox(height: 16.h),

                    // 1. Full Name Label & Field
                    Text(
                      'FULL NAME',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        hintStyle: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                          color: const Color(0xFFAB31DE),
                          size: 19.sp,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAF5FF),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFFE9D5FF), width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFFE9D5FF), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFFAB31DE), width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Name is required';
                        if (val.trim().length < 3) return 'Name must be at least 3 characters';
                        return null;
                      },
                    ),

                    SizedBox(height: 14.h),

                    // 2. Mobile Number Label & Field
                    Text(
                      'MOBILE NUMBER',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E1B4B),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                      decoration: InputDecoration(
                        hintText: '10-digit mobile number',
                        hintStyle: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13.sp,
                          letterSpacing: 0,
                        ),
                        prefixIcon: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          margin: EdgeInsets.only(right: 8.w),
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🇮🇳 +91',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF1E1B4B),
                                  fontSize: 13.5.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAF5FF),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFFE9D5FF), width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFFE9D5FF), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: const BorderSide(color: Color(0xFFAB31DE), width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Mobile number is required';
                        if (!RegExp(r'^[6-9]\d{9}$').hasMatch(val.trim())) {
                          return 'Enter valid 10-digit number';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 14.h),

                    // 3. Gender Label & Selector
                    Text(
                      'GENDER',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        _buildGenderChip('Male', Icons.male_rounded),
                        SizedBox(width: 12.w),
                        _buildGenderChip('Female', Icons.female_rounded),
                      ],
                    ),

                    SizedBox(height: 22.h),

                    // 4. Save & Continue Button
                    GestureDetector(
                      onTap: _isLoading ? null : _submit,
                      child: Container(
                        width: double.infinity,
                        height: 48.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE39FFF), Color(0xFFAB31DE)],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFAB31DE).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 22.w,
                                height: 22.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'SAVE & PROCEED TO REDEEM',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top Right Close Button
            Positioned(
              top: 12.h,
              right: 12.w,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(false);
                },
                child: Container(
                  width: 32.w,
                  height: 32.w,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20.sp,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderChip(String label, IconData icon) {
    final isSelected = _selectedGender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedGender = label);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF3E8FF) : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? const Color(0xFFAB31DE) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18.sp,
                color: isSelected ? const Color(0xFFAB31DE) : const Color(0xFF64748B),
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: isSelected ? const Color(0xFFAB31DE) : const Color(0xFF64748B),
                  fontSize: 13.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
