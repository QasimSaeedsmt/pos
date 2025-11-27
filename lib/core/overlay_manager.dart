// utils/overlay_manager.dart
import 'package:flutter/material.dart';
import 'custom_overlay.dart';

class OverlayManager {
  static void showToast({
    required BuildContext context,
    required String message,
    Widget? icon,

    Duration duration = const Duration(seconds: 2),
    OverlayPosition position = OverlayPosition.top,
    Color? backgroundColor,
    Color? textColor,
  }) {
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => CustomOverlay(
        message: message,
        icon: icon,
        duration: duration,
        position: OverlayPosition.bottom,
        backgroundColor: backgroundColor,
        textColor: textColor,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  static void showExitConfirmation(BuildContext context) {
    showToast(
      context: context,
      message: 'Press back again to exit',
      icon: const Icon(Icons.touch_app_rounded),
      duration: const Duration(seconds: 2),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    showToast(
      context: context,
      message: message,
      position: OverlayPosition.bottom,
      icon: const Icon(Icons.check_circle_rounded),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    );
  }

  static void showError(BuildContext context, String message) {
    showToast(
      context: context,
      message: message,
      icon: const Icon(Icons.error_rounded),
      backgroundColor: Colors.red,
      textColor: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  static void showWarning(BuildContext context, String message) {
    showToast(
      context: context,
      message: message,
      icon: const Icon(Icons.warning_rounded),
      backgroundColor: Colors.orange,
      textColor: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}