// theme_provider.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider with ChangeNotifier {
  AppTheme? _currentTheme;
  bool _isDarkMode = false;
  bool _useSystemTheme = false;

  AppTheme? get currentTheme => _currentTheme;
  bool get isDarkMode => _isDarkMode;
  bool get useSystemTheme => _useSystemTheme;

  ThemeProvider() {
    _initializeTheme();
  }

  Future<void> _initializeTheme() async {
    await loadSavedTheme();
  }

  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();

    // Load dark mode preference
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    _useSystemTheme = prefs.getBool('use_system_theme') ?? false;

    // Load saved theme
    final themeJson = prefs.getString('selected_theme');
    if (themeJson != null) {
      try {
        _currentTheme = AppTheme.fromJson(jsonDecode(themeJson));
      } catch (e) {
       debugPrint('Error loading saved theme: $e');
      }
    }

    // If no theme saved or error, use default
    _currentTheme ??= _isDarkMode ? ThemeManager.darkThemes.first : ThemeManager.lightThemes.first;

    notifyListeners();
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    _isDarkMode = theme.isDark;
    _useSystemTheme = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_theme', jsonEncode(theme.toJson()));
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setBool('use_system_theme', false);

    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    _useSystemTheme = false;

    // Find a theme with matching characteristics but correct dark mode
    if (_currentTheme != null) {
      final allThemes = await getAvailableThemes();
      final baseName = _currentTheme!.name.replaceAll(' Dark', '').replaceAll(' Light', '');
      final matchingTheme = allThemes.firstWhere(
            (theme) => theme.name.replaceAll(' Dark', '').replaceAll(' Light', '') == baseName &&
            theme.isDark == isDark,
        orElse: () => isDark ? ThemeManager.darkThemes.first : ThemeManager.lightThemes.first,
      );
      _currentTheme = matchingTheme;
    } else {
      _currentTheme = isDark ? ThemeManager.darkThemes.first : ThemeManager.lightThemes.first;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', isDark);
    await prefs.setBool('use_system_theme', false);
    await prefs.setString('selected_theme', jsonEncode(_currentTheme!.toJson()));

    notifyListeners();
  }

  Future<void> setUseSystemTheme(bool useSystem) async {
    _useSystemTheme = useSystem;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_system_theme', useSystem);
    notifyListeners();
  }

  Future<void> addCustomTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final customThemes = await getCustomThemes();

    // Remove existing theme with same name
    final updatedThemes = customThemes.where((t) => t.name != theme.name).toList();
    updatedThemes.add(theme);

    final themesJson = updatedThemes.map((t) => t.toJson()).toList();
    await prefs.setString('custom_themes', jsonEncode(themesJson));

    notifyListeners();
  }

  Future<void> updateCustomTheme(AppTheme oldTheme, AppTheme newTheme) async {
    await deleteCustomTheme(oldTheme);
    await addCustomTheme(newTheme);

    if (_currentTheme?.name == oldTheme.name) {
      await setTheme(newTheme);
    }

    notifyListeners();
  }

  Future<void> deleteCustomTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    final customThemes = await getCustomThemes();

    final updatedThemes = customThemes.where((t) => t.name != theme.name).toList();
    final themesJson = updatedThemes.map((t) => t.toJson()).toList();

    await prefs.setString('custom_themes', jsonEncode(themesJson));

    if (_currentTheme?.name == theme.name) {
      await setTheme(_isDarkMode ? ThemeManager.darkThemes.first : ThemeManager.lightThemes.first);
    }

    notifyListeners();
  }

  Future<List<AppTheme>> getAvailableThemes() async {
    final customThemes = await getCustomThemes();
    return [...ThemeManager.defaultThemes, ...customThemes];
  }

  Future<List<AppTheme>> getCustomThemes() async {
    final prefs = await SharedPreferences.getInstance();
    final themesJson = prefs.getString('custom_themes');

    if (themesJson != null) {
      try {
        final List<dynamic> themesList = jsonDecode(themesJson);
        return themesList.map((themeJson) => AppTheme.fromJson(themeJson)).toList();
      } catch (e) {
       debugPrint('Error parsing custom themes: $e');
      }
    }

    return [];
  }

  // Gradient getters
  List<Color> getBackgroundGradient() {
    return _currentTheme != null
        ? ThemeManager.hexToColors(_currentTheme!.backgroundGradient)
        : ThemeManager.hexToColors(ThemeManager.lightThemes.first.backgroundGradient);
  }

  List<Color> getButtonGradient() {
    return _currentTheme != null
        ? ThemeManager.hexToColors(_currentTheme!.buttonGradient)
        : ThemeManager.hexToColors(ThemeManager.lightThemes.first.buttonGradient);
  }

  List<Color> getCardGradient() {
    return _currentTheme != null
        ? ThemeManager.hexToColors(_currentTheme!.cardGradient)
        : ThemeManager.hexToColors(ThemeManager.lightThemes.first.cardGradient);
  }

  List<Color> getAppBarGradient() {
    return _currentTheme != null
        ? ThemeManager.hexToColors(_currentTheme!.appBarGradient)
        : ThemeManager.hexToColors(ThemeManager.lightThemes.first.appBarGradient);
  }

  List<Color> getAccentGradient() {
    return _currentTheme != null
        ? ThemeManager.hexToColors(_currentTheme!.accentGradient)
        : ThemeManager.hexToColors(ThemeManager.lightThemes.first.accentGradient);
  }

  // Color getters
  Color getPrimaryColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.primaryColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.primaryColor);

  Color getSecondaryColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.secondaryColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.secondaryColor);

  Color getAccentColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.accentColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.accentColor);

  Color getSurfaceColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.surfaceColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.surfaceColor);

  Color getBackgroundColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.backgroundColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.backgroundColor);

  // Text color getters
  Color getPrimaryTextColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.primaryTextColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.primaryTextColor);

  Color getSecondaryTextColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.secondaryTextColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.secondaryTextColor);

  Color getAccentTextColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.accentTextColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.accentTextColor);

  Color getOnPrimaryTextColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.onPrimaryTextColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.onPrimaryTextColor);

  // Status color getters
  Color getErrorColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.errorColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.errorColor);

  Color getSuccessColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.successColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.successColor);

  Color getWarningColor() => _currentTheme != null
      ? ThemeManager.hexToColor(_currentTheme!.warningColor)
      : ThemeManager.hexToColor(ThemeManager.lightThemes.first.warningColor);

  // Styling getters
  double getBorderRadius() => _currentTheme?.borderRadius ?? 12.0;
  double getButtonElevation() => _currentTheme?.buttonElevation ?? 4.0;
  double getCardElevation() => _currentTheme?.cardElevation ?? 2.0;

  // For backward compatibility
  List<Color> getCurrentGradientColors() => getBackgroundGradient();
}