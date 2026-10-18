import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SnackBarHelper {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 10,
          left: 16,
          right: 16,
          top: 10,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 10,
          left: 16,
          right: 16,
          top: 10,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 10,
          left: 16,
          right: 16,
          top: 10,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 10,
          left: 16,
          right: 16,
          top: 10,
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(
          bottom: 10,
          left: 16,
          right: 16,
          top: 10,
        ),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}
