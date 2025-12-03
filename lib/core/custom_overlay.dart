// widgets/custom_overlay.dart
import 'package:flutter/material.dart';

class CustomOverlay extends StatefulWidget {
  final String message;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration duration;
  final OverlayPosition position;
  final VoidCallback? onDismiss;
  final bool showShadow;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const CustomOverlay({
    super.key,
    required this.message,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.duration = const Duration(seconds: 2),
    this.position = OverlayPosition.top,
    this.onDismiss,
    this.showShadow = true,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  });

  @override
  State<CustomOverlay> createState() => _CustomOverlayState();
}

class _CustomOverlayState extends State<CustomOverlay> {
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
              child: Row(
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
                  Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.textColor ?? theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
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

enum OverlayPosition { top, center, bottom }