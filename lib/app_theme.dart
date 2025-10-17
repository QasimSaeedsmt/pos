// gradient_theme_manager.dart
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GradientTheme {
  final String name;
  final List<String> colors;
  final bool isDark;

  GradientTheme({
    required this.name,
    required this.colors,
    required this.isDark,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'colors': colors,
      'isDark': isDark,
    };
  }

  factory GradientTheme.fromJson(Map<String, dynamic> json) {
    return GradientTheme(
      name: json['name'],
      colors: List<String>.from(json['colors']),
      isDark: json['isDark'],
    );
  }

  GradientTheme copyWith({
    String? name,
    List<String>? colors,
    bool? isDark,
  }) {
    return GradientTheme(
      name: name ?? this.name,
      colors: colors ?? this.colors,
      isDark: isDark ?? this.isDark,
    );
  }
}

class GradientThemeManager {
  static const String _selectedThemeKey = 'selected_gradient_theme';
  static const String _customThemesKey = 'custom_gradient_themes';
  static const String _darkModeKey = 'dark_mode_preference';

  static final List<GradientTheme> defaultThemes = [
    GradientTheme(
      name: 'Ocean Blue',
      colors: ['#667EEA', '#764BA2'],
      isDark: false,
    ),
    GradientTheme(
      name: 'Deep Space',
      colors: ['#0F2027', '#203A43', '#2C5364'],
      isDark: true,
    ),
    GradientTheme(
      name: 'Sunset',
      colors: ['#FF6B6B', '#FFE66D'],
      isDark: false,
    ),
    GradientTheme(
      name: 'Forest',
      colors: ['#56ab2f', '#a8e063'],
      isDark: false,
    ),
    GradientTheme(
      name: 'Royal',
      colors: ['#141E30', '#243B55'],
      isDark: true,
    ),
    GradientTheme(
      name: 'Neon',
      colors: ['#834d9b', '#d04ed6'],
      isDark: true,
    ),
    GradientTheme(
      name: 'Sunrise',
      colors: ['#FF512F', '#F09819'],
      isDark: false,
    ),
    GradientTheme(
      name: 'Mint',
      colors: ['#11998e', '#38ef7d'],
      isDark: false,
    ),
  ];

  Future<void> saveSelectedTheme(GradientTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedThemeKey, json.encode(theme.toJson()));
  }

  Future<GradientTheme?> getSelectedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeJson = prefs.getString(_selectedThemeKey);

    if (themeJson != null) {
      try {
        final map = json.decode(themeJson);
        return GradientTheme.fromJson(Map<String, dynamic>.from(map));
      } catch (e) {
        print('Error parsing theme: $e');
      }
    }

    return defaultThemes.first;
  }

  Future<void> saveCustomTheme(GradientTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final customThemesJson = prefs.getStringList(_customThemesKey) ?? [];

    // Check if theme with same name exists
    final updatedThemes = customThemesJson.where((jsonString) {
      try {
        final map = json.decode(jsonString);
        return GradientTheme.fromJson(Map<String, dynamic>.from(map)).name != theme.name;
      } catch (e) {
        return true;
      }
    }).toList();

    updatedThemes.add(json.encode(theme.toJson()));
    await prefs.setStringList(_customThemesKey, updatedThemes);
  }

  Future<List<GradientTheme>> getCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final customThemesJson = prefs.getStringList(_customThemesKey) ?? [];

    return customThemesJson.map((jsonString) {
      try {
        final map = json.decode(jsonString);
        return GradientTheme.fromJson(Map<String, dynamic>.from(map));
      } catch (e) {
        return null;
      }
    }).where((theme) => theme != null).cast<GradientTheme>().toList();
  }

  Future<void> deleteCustomTheme(GradientTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final customThemesJson = prefs.getStringList(_customThemesKey) ?? [];

    final updatedThemes = customThemesJson.where((jsonString) {
      try {
        final map = json.decode(jsonString);
        return GradientTheme.fromJson(Map<String, dynamic>.from(map)).name != theme.name;
      } catch (e) {
        return true;
      }
    }).toList();

    await prefs.setStringList(_customThemesKey, updatedThemes);
  }

  Future<void> saveDarkModePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDark);
  }

  Future<bool> getDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  List<Color> hexToColors(List<String> hexColors) {
    return hexColors.map((hex) {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    }).toList();
  }

  String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}