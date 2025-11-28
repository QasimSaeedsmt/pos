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

  // NEW: Show warning overlay with action button
  static void showWarningOverlay({
    required BuildContext context,
    required String message,
    Widget? icon,
    Duration duration = const Duration(seconds: 4),
    Color? backgroundColor,
    Color? textColor,
    OverlayAction? action,
  }) {
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => CustomOverlayWithAction(
        message: message,
        icon: icon ?? const Icon(Icons.warning_rounded),
        duration: duration,
        position: OverlayPosition.bottom,
        backgroundColor: backgroundColor ?? Colors.orange,
        textColor: textColor ?? Colors.white,
        action: action,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }
}

// NEW: Overlay action class
class OverlayAction {
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const OverlayAction({
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  });
}

// NEW: Custom overlay with action button
class CustomOverlayWithAction extends StatefulWidget {
  final String message;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration duration;
  final OverlayPosition position;
  final VoidCallback? onDismiss;
  final OverlayAction? action;
  final bool showShadow;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const CustomOverlayWithAction({
    super.key,
    required this.message,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.duration = const Duration(seconds: 4),
    this.position = OverlayPosition.top,
    this.onDismiss,
    this.action,
    this.showShadow = true,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  @override
  State<CustomOverlayWithAction> createState() => _CustomOverlayWithActionState();
}

class _CustomOverlayWithActionState extends State<CustomOverlayWithAction> {
  @override
  void initState() {
    super.initState();
    if (widget.duration != Duration.zero) {
      Future.delayed(widget.duration, () {
        if (mounted) {
          widget.onDismiss?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned(
      top: _getTopPosition(),
      bottom: _getBottomPosition(),
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: _getAlignment(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? theme.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: widget.showShadow ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        IconTheme(
                          data: IconThemeData(
                            color: widget.textColor ?? theme.colorScheme.onInverseSurface,
                            size: 20,
                          ),
                          child: widget.icon!,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.textColor ?? theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.action != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.action!.onPressed();
                          widget.onDismiss?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.action!.backgroundColor ?? Colors.white,
                          foregroundColor: widget.action!.textColor ?? Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          widget.action!.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Alignment _getAlignment() {
    switch (widget.position) {
      case OverlayPosition.top:
        return Alignment.topCenter;
      case OverlayPosition.center:
        return Alignment.center;
      case OverlayPosition.bottom:
        return Alignment.bottomCenter;
    }
  }

  double? _getTopPosition() {
    if (widget.position == OverlayPosition.top) {
      return MediaQuery.of(context).viewPadding.top + 80;
    }
    return null;
  }

  double? _getBottomPosition() {
    if (widget.position == OverlayPosition.bottom) {
      return MediaQuery.of(context).viewPadding.bottom + 80;
    }
    return null;
  }
}