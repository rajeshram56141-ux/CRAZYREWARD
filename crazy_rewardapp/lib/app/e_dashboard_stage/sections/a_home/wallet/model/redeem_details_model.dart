import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../utils/helper/helper.dart';
import '../../../../../../widgets/common/custom_toast.dart';
import 'wallet_catalog_model.dart';

enum PaymentField { email, upiId, name }
typedef RedeemField = PaymentField;

class RedeemDetails {
  final String? email;
  final String? upiId;
  final String? name;
  final Map<String, dynamic> customFields;

  const RedeemDetails({this.name, this.email, this.upiId, this.customFields = const {}});

  Map<String, dynamic> toSnapshot(WalletMethod method) => {
    for (final key in method.validators)
      key: switch (key) {
        'email' => email,
        'upiId' => upiId,
        'name' => name,
        _ => customFields[key],
      },
  };

  factory RedeemDetails.fromSnapshot(Map<String, dynamic> json) =>
      RedeemDetails(
        email: json['email'],
        upiId: json['upiId'],
        name: json['name'],
        customFields: json,
      );

  bool hasRequiredFields(WalletMethod method) => method.validators.every((f) {
    switch (f) {
      case 'email':
        return email != null && email!.isNotEmpty;
      case 'upiId':
        return upiId != null && upiId!.isNotEmpty;
      case 'name':
        return name != null && name!.isNotEmpty;
      default:
        final val = customFields[f];
        return val != null && val.toString().trim().isNotEmpty;
    }
  });

  Widget toWidgetFromMap(
    BuildContext context, {
    Color? labelColor,
    Color? valueColor,
    Color? iconColor,
  }) {
    final widgets = <Widget>[];
    void add(String label, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        final String displayLabel = label.tr() == label
            ? label.replaceAll('_', ' ').replaceAll('-', ' ').caps()
            : label.tr();

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: 10,
              children: [
                Text(
                  '$displayLabel :',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(
                        color: labelColor ?? Colors.white70,
                      ),
                ),
                Expanded(
                  child: Row(
                    spacing: 5,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value.trim(),
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: valueColor ?? Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value.trim()));
                          CustomToast.showToast(
                            context,
                            msg: 'copied-to-clipboard',
                          );
                        },
                        child: Icon(
                          Icons.copy_outlined,
                          size: 15,
                          color: iconColor,
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

    add('email', email);
    add('upi-id', upiId);
    add('name', name);

    customFields.forEach((key, value) {
      if (key != 'email' && key != 'upiId' && key != 'upi-id' && key != 'name') {
        add(key, value?.toString());
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets.isNotEmpty ? widgets : [const SizedBox.shrink()],
    );
  }
}

// Backward compatibility alias
typedef PaymentDetails = RedeemDetails;
