import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: Colors.blue[700],
      primarySwatch: Colors.blue,
      colorScheme: ColorScheme.light(
        primary: Colors.blue[700]!,
        secondary: Colors.cyan[400]!,
        surface: Colors.grey[50]!,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  static LinearGradient get primaryGradient => LinearGradient(
    colors: [Colors.blue.shade400, Colors.cyan.shade400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get secondaryGradient => LinearGradient(
    colors: [Colors.purple, Colors.blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color get successColor => Colors.green;
  static Color get warningColor => Colors.orange;
  static Color get errorColor => Colors.red;
  static Color get infoColor => Colors.blue;
}