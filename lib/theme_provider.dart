// theme_provider.dart
import 'package:flutter/material.dart';
import 'app_theme.dart';


class ThemeProvider with ChangeNotifier {
  final GradientThemeManager _themeManager = GradientThemeManager();
  GradientTheme? _currentTheme;
  bool _isDarkMode = false;
  bool _useSystemTheme = false;

  GradientTheme? get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  bool get useSystemTheme => _useSystemTheme;

  Future<void> loadSavedTheme() async {
    _currentTheme = await _themeManager.getSelectedTheme();
    _isDarkMode = await _themeManager.getDarkModePreference();
    notifyListeners();
  }

  Future<void> setTheme(GradientTheme theme) async {
    _currentTheme = theme;
    if (!_useSystemTheme) {
      _isDarkMode = theme.isDark;
      await _themeManager.saveDarkModePreference(_isDarkMode);
    }
    await _themeManager.saveSelectedTheme(theme);
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    _useSystemTheme = false;
    await _themeManager.saveDarkModePreference(isDark);
    notifyListeners();
  }

  Future<void> setUseSystemTheme(bool useSystem) async {
    _useSystemTheme = useSystem;
    if (useSystem) {
      // System theme will be handled by the UI
      await _themeManager.saveDarkModePreference(false);
    }
    notifyListeners();
  }

  Future<void> addCustomTheme(GradientTheme theme) async {
    await _themeManager.saveCustomTheme(theme);
    notifyListeners();
  }

  Future<void> updateCustomTheme(GradientTheme oldTheme, GradientTheme newTheme) async {
    await _themeManager.deleteCustomTheme(oldTheme);
    await _themeManager.saveCustomTheme(newTheme);
    if (_currentTheme?.name == oldTheme.name) {
      await setTheme(newTheme);
    }
  }

  Future<void> deleteCustomTheme(GradientTheme theme) async {
    await _themeManager.deleteCustomTheme(theme);
    notifyListeners();
  }

  Future<List<GradientTheme>> getAvailableThemes() async {
    final defaultThemes = GradientThemeManager.defaultThemes;
    final customThemes = await _themeManager.getCustomThemes();
    return [...defaultThemes, ...customThemes];
  }

  List<Color> getCurrentGradientColors() {
    if (_currentTheme != null) {
      return _themeManager.hexToColors(_currentTheme!.colors);
    }
    return _themeManager.hexToColors(GradientThemeManager.defaultThemes.first.colors);
  }

  String colorToHex(Color color) {
    return _themeManager.colorToHex(color);
  }
}