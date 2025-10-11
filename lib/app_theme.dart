// app_theme.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static final AppTheme _instance = AppTheme._internal();
  factory AppTheme() => _instance;
  AppTheme._internal();

  // Theme settings with defaults
  String themeMode = 'system';
  String primaryColor = 'blue';
  String accentColor = 'teal';
  bool enableGradient = true;
  bool enableAnimations = true;
  double fontSizeScale = 1.0;
  String fontFamily = 'Roboto';
  bool compactMode = false;
  String buttonStyle = 'rounded';

  // Color palettes
  final Map<String, List<Color>> colorPalettes = {
    'blue': [Color(0xFF2196F3), Color(0xFF21CBF3), Color(0xFF1976D2)],
    'purple': [Color(0xFF9C27B0), Color(0xFFBA68C8), Color(0xFF7B1FA2)],
    'teal': [Color(0xFF009688), Color(0xFF4DB6AC), Color(0xFF00796B)],
    'orange': [Color(0xFFFF9800), Color(0xFFFFB74D), Color(0xFFF57C00)],
    'green': [Color(0xFF4CAF50), Color(0xFF81C784), Color(0xFF388E3C)],
    'indigo': [Color(0xFF3F51B5), Color(0xFF7986CB), Color(0xFF303F9F)],
    'pink': [Color(0xFFE91E63), Color(0xFFF06292), Color(0xFFC2185B)],
    'deep_orange': [Color(0xFFFF5722), Color(0xFFFF8A65), Color(0xFFD84315)],
  };

  final Map<String, List<Color>> gradientPalettes = {
    'blue': [Color(0xFF2196F3), Color(0xFF21CBF3)],
    'purple': [Color(0xFF9C27B0), Color(0xFF673AB7)],
    'teal': [Color(0xFF009688), Color(0xFF4CAF50)],
    'sunset': [Color(0xFFFF9800), Color(0xFFE91E63)],
    'ocean': [Color(0xFF00BCD4), Color(0xFF3F51B5)],
    'forest': [Color(0xFF4CAF50), Color(0xFF2E7D32)],
    'royal': [Color(0xFF3F51B5), Color(0xFF9C27B0)],
    'fire': [Color(0xFFFF5722), Color(0xFFFF9800)],
  };

  // Load settings from shared preferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = prefs.getString('theme_mode') ?? 'system';
    primaryColor = prefs.getString('primary_color') ?? 'blue';
    accentColor = prefs.getString('accent_color') ?? 'teal';
    enableGradient = prefs.getBool('enable_gradient') ?? true;
    enableAnimations = prefs.getBool('enable_animations') ?? true;
    fontSizeScale = prefs.getDouble('font_size_scale') ?? 1.0;
    fontFamily = prefs.getString('font_family') ?? 'Roboto';
    compactMode = prefs.getBool('compact_mode') ?? false;
    buttonStyle = prefs.getString('button_style') ?? 'rounded';
  }

  // Get current primary color
  Color get primaryColorValue => colorPalettes[primaryColor]?.first ?? Color(0xFF2196F3);

  // Get current accent color
  Color get accentColorValue => colorPalettes[accentColor]?.first ?? Color(0xFF009688);

  // Get gradient colors
  List<Color> get gradientColors => gradientPalettes[accentColor] ?? gradientPalettes['blue']!;

  // Create theme data based on settings
  ThemeData getThemeData(BuildContext context) {
    final brightness = _getBrightness(context);

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
    );

    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColorValue,
        brightness: brightness,
        primary: primaryColorValue,
        secondary: accentColorValue,
      ),
      textTheme: _buildTextTheme(baseTheme.textTheme),
      cardTheme: _buildCardTheme(),
      buttonTheme: _buildButtonTheme(baseTheme.buttonTheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      appBarTheme: _buildAppBarTheme(brightness),
      floatingActionButtonTheme: _buildFloatingActionButtonTheme(baseTheme.floatingActionButtonTheme),
    );
  }

  Brightness _getBrightness(BuildContext context) {
    switch (themeMode) {
      case 'light':
        return Brightness.light;
      case 'dark':
        return Brightness.dark;
      case 'system':
      default:
        return MediaQuery.of(context).platformBrightness;
    }
  }

  TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      bodyLarge: base.bodyLarge?.copyWith(fontSize: (base.bodyLarge?.fontSize ?? 16) * fontSizeScale),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: (base.bodyMedium?.fontSize ?? 14) * fontSizeScale),
      titleLarge: base.titleLarge?.copyWith(fontSize: (base.titleLarge?.fontSize ?? 22) * fontSizeScale),
      titleMedium: base.titleMedium?.copyWith(fontSize: (base.titleMedium?.fontSize ?? 16) * fontSizeScale),
      titleSmall: base.titleSmall?.copyWith(fontSize: (base.titleSmall?.fontSize ?? 14) * fontSizeScale),
      labelLarge: base.labelLarge?.copyWith(fontSize: (base.labelLarge?.fontSize ?? 14) * fontSizeScale),
      labelMedium: base.labelMedium?.copyWith(fontSize: (base.labelMedium?.fontSize ?? 12) * fontSizeScale),
      labelSmall: base.labelSmall?.copyWith(fontSize: (base.labelSmall?.fontSize ?? 11) * fontSizeScale),
    );
  }
  CardThemeData _buildCardTheme() {
    return CardThemeData(
      margin: compactMode ? EdgeInsets.all(4) : EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }


  ButtonThemeData _buildButtonTheme(ButtonThemeData base) {
    return base.copyWith(
      padding: compactMode
          ? EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      buttonColor: primaryColorValue,
      shape: _getButtonShape(),
    );
  }

  ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColorValue,
        foregroundColor: Colors.white,
        padding: compactMode
            ? EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: _getButtonShape(),
        elevation: 2,
        textStyle: TextStyle(
          fontSize: 14 * fontSizeScale,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColorValue,
        side: BorderSide(color: primaryColorValue),
        padding: compactMode
            ? EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: _getButtonShape(),
        textStyle: TextStyle(
          fontSize: 14 * fontSizeScale,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryColorValue, width: 2),
      ),
      contentPadding: compactMode
          ? EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  AppBarTheme _buildAppBarTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return AppBarTheme(
      backgroundColor: enableGradient && !isDark
          ? null
          : isDark
          ? Colors.grey[900]
          : primaryColorValue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18 * fontSizeScale,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  FloatingActionButtonThemeData _buildFloatingActionButtonTheme(FloatingActionButtonThemeData base) {
    return base.copyWith(
      backgroundColor: primaryColorValue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  RoundedRectangleBorder _getButtonShape() {
    switch (buttonStyle) {
      case 'square':
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
      case 'outlined':
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
      case 'rounded':
      default:
        return RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    }
  }

  // Helper method to create gradient decoration
  BoxDecoration getGradientDecoration() {
    return enableGradient
        ? BoxDecoration(
      gradient: LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    )
        : BoxDecoration(color: primaryColorValue);
  }

  // Helper method to create gradient app bar decoration
  BoxDecoration getAppBarGradient() {
    return enableGradient
        ? BoxDecoration(
      gradient: LinearGradient(
        colors: gradientColors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    )
        : BoxDecoration();
  }
}
