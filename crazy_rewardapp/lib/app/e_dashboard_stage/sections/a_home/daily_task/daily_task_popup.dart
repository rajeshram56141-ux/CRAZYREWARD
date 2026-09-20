import 'package:flutter/material.dart';
import '../../../../../widgets/common/custom_status_popup.dart';

class DailyTaskPopup {
  /// 1. Task Not Completed / Failed Dialog
  static Future<void> showTaskNotCompleted({
    required BuildContext context,
    required String message,
    VoidCallback? onDismiss,
  }) =>
      CustomStatusPopup.showFailed(
        context: context,
        tag: 'Oops!',
        title: 'Event Incomplete!',
        message: message.isNotEmpty
            ? message
            : 'Please complete the required event steps before proceeding.',
        primaryButtonText: 'CONTINUE',
        onPrimaryTap: onDismiss,
        onClose: onDismiss,
      );

  /// 2. Task Completed / Success Dialog
  static Future<void> showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) =>
      CustomStatusPopup.showSuccess(
        context: context,
        tag: 'Congratulations',
        title: title.isNotEmpty ? title : 'Task Completed!',
        message: message.isNotEmpty
            ? message
            : 'You have successfully completed this task. Your reward has been credited!',
        primaryButtonText: 'AWESOME!',
        onPrimaryTap: onDismiss,
        onClose: onDismiss,
      );

  /// 3. App Not Installed Dialog
  static Future<void> showAppNotInstalled({
    required BuildContext context,
    required String message,
    VoidCallback? onDismiss,
  }) =>
      CustomStatusPopup.showFailed(
        context: context,
        tag: 'App Required',
        title: 'App Not Installed!',
        message: message.isNotEmpty
            ? message
            : 'The required app is not installed on your device. Please install the app to complete this task.',
        primaryButtonText: 'OK, GOT IT',
        onPrimaryTap: onDismiss,
        onClose: onDismiss,
      );

  /// 4. App Usage Permission Dialog (Global CustomStatusPopup)
  static Future<bool> showUsagePermission({
    required BuildContext context,
    required VoidCallback onAllow,
    VoidCallback? onDeny,
  }) =>
      CustomStatusPopup.showUsagePermission(
        context: context,
        onAllow: onAllow,
        onDeny: onDeny,
      );
}
