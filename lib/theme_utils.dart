// theme_utils.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ThemeUtils {
  // Quick access to theme provider
  static ThemeProvider of(BuildContext context) {
    return Provider.of<ThemeProvider>(context, listen: false);
  }

  // Gradient shortcuts
  static List<Color> background(BuildContext context) => of(context).getBackgroundGradient();
  static List<Color> button(BuildContext context) => of(context).getButtonGradient();
  static List<Color> card(BuildContext context) => of(context).getCardGradient();
  static List<Color> appBar(BuildContext context) => of(context).getAppBarGradient();
  static List<Color> accent(BuildContext context) => of(context).getAccentGradient();

  // Color shortcuts
  static Color primary(BuildContext context) => of(context).getPrimaryColor();
  static Color secondary(BuildContext context) => of(context).getSecondaryColor();
  static Color accentColor(BuildContext context) => of(context).getAccentColor();
  static Color surface(BuildContext context) => of(context).getSurfaceColor();
  static Color backgroundSolid(BuildContext context) => of(context).getBackgroundColor();

  // Text color shortcuts
  static Color textPrimary(BuildContext context) => of(context).getPrimaryTextColor();
  static Color textSecondary(BuildContext context) => of(context).getSecondaryTextColor();
  static Color textAccent(BuildContext context) => of(context).getAccentTextColor();
  static Color textOnPrimary(BuildContext context) => of(context).getOnPrimaryTextColor();

  // Status color shortcuts
  static Color error(BuildContext context) => of(context).getErrorColor();
  static Color success(BuildContext context) => of(context).getSuccessColor();
  static Color warning(BuildContext context) => of(context).getWarningColor();

  // Styling shortcuts
  static double radius(BuildContext context) => of(context).getBorderRadius();
  static double buttonElevation(BuildContext context) => of(context).getButtonElevation();
  static double cardElevation(BuildContext context) => of(context).getCardElevation();

  // Pre-styled containers
  static BoxDecoration gradientBackground(BuildContext context) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: background(context),
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: card(context),
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: cardElevation(context) * 2,
          offset: Offset(0, cardElevation(context)),
        ),
      ],
    );
  }

  static BoxDecoration buttonDecoration(BuildContext context) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: button(context),
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(radius(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: buttonElevation(context),
          offset: Offset(0, buttonElevation(context) / 2),
        ),
      ],
    );
  }

  // Text styles
  static TextStyle headlineLarge(BuildContext context) {
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: textPrimary(context),
    );
  }

  static TextStyle headlineMedium(BuildContext context) {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary(context),
    );
  }

  static TextStyle bodyLarge(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      color: textPrimary(context),
    );
  }

  static TextStyle bodyMedium(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      color: textSecondary(context),
    );
  }

  static TextStyle bodySmall(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      color: textSecondary(context),
    );
  }

  static TextStyle buttonText(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textOnPrimary(context),
    );
  }
}