// app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final bool isDark;

  // Multiple gradient sets for different UI elements
  final List<String> backgroundGradient;
  final List<String> buttonGradient;
  final List<String> cardGradient;
  final List<String> appBarGradient;
  final List<String> accentGradient;

  // Core color palette
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String surfaceColor;
  final String backgroundColor;
  final String errorColor;
  final String successColor;
  final String warningColor;

  // Text colors
  final String primaryTextColor;
  final String secondaryTextColor;
  final String accentTextColor;
  final String disabledTextColor;
  final String onPrimaryTextColor;

  // Additional styling
  final double borderRadius;
  final double buttonElevation;
  final double cardElevation;

  const AppTheme({
    required this.name,
    required this.isDark,
    required this.backgroundGradient,
    required this.buttonGradient,
    required this.cardGradient,
    required this.appBarGradient,
    required this.accentGradient,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.surfaceColor,
    required this.backgroundColor,
    required this.errorColor,
    required this.successColor,
    required this.warningColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.accentTextColor,
    required this.disabledTextColor,
    required this.onPrimaryTextColor,
    this.borderRadius = 12.0,
    this.buttonElevation = 4.0,
    this.cardElevation = 2.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isDark': isDark,
      'backgroundGradient': backgroundGradient,
      'buttonGradient': buttonGradient,
      'cardGradient': cardGradient,
      'appBarGradient': appBarGradient,
      'accentGradient': accentGradient,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'accentColor': accentColor,
      'surfaceColor': surfaceColor,
      'backgroundColor': backgroundColor,
      'errorColor': errorColor,
      'successColor': successColor,
      'warningColor': warningColor,
      'primaryTextColor': primaryTextColor,
      'secondaryTextColor': secondaryTextColor,
      'accentTextColor': accentTextColor,
      'disabledTextColor': disabledTextColor,
      'onPrimaryTextColor': onPrimaryTextColor,
      'borderRadius': borderRadius,
      'buttonElevation': buttonElevation,
      'cardElevation': cardElevation,
    };
  }

  factory AppTheme.fromJson(Map<String, dynamic> json) {
    return AppTheme(
      name: json['name'] ?? 'Unknown',
      isDark: json['isDark'] ?? false,
      backgroundGradient: List<String>.from(json['backgroundGradient'] ?? ['#667eea', '#764ba2']),
      buttonGradient: List<String>.from(json['buttonGradient'] ?? ['#667eea', '#764ba2']),
      cardGradient: List<String>.from(json['cardGradient'] ?? ['#FFFFFF', '#F5F5F5']),
      appBarGradient: List<String>.from(json['appBarGradient'] ?? ['#667eea', '#764ba2']),
      accentGradient: List<String>.from(json['accentGradient'] ?? ['#f093fb', '#f5576c']),
      primaryColor: json['primaryColor'] ?? '#667eea',
      secondaryColor: json['secondaryColor'] ?? '#764ba2',
      accentColor: json['accentColor'] ?? '#f093fb',
      surfaceColor: json['surfaceColor'] ?? '#FFFFFF',
      backgroundColor: json['backgroundColor'] ?? '#F5F5F5',
      errorColor: json['errorColor'] ?? '#FF5252',
      successColor: json['successColor'] ?? '#4CAF50',
      warningColor: json['warningColor'] ?? '#FF9800',
      primaryTextColor: json['primaryTextColor'] ?? '#2D3748',
      secondaryTextColor: json['secondaryTextColor'] ?? '#718096',
      accentTextColor: json['accentTextColor'] ?? '#667eea',
      disabledTextColor: json['disabledTextColor'] ?? '#A0AEC0',
      onPrimaryTextColor: json['onPrimaryTextColor'] ?? '#FFFFFF',
      borderRadius: (json['borderRadius'] ?? 12.0).toDouble(),
      buttonElevation: (json['buttonElevation'] ?? 4.0).toDouble(),
      cardElevation: (json['cardElevation'] ?? 2.0).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AppTheme &&
              runtimeType == other.runtimeType &&
              name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class ThemeManager {
  // Light Themes
  static final List<AppTheme> lightThemes = [
    AppTheme(
      name: 'Ocean Blue Light',
      isDark: false,
      backgroundGradient: ['#667eea', '#764ba2'],
      buttonGradient: ['#667eea', '#764ba2'],
      cardGradient: ['#FFFFFF', '#F7FAFC'],
      appBarGradient: ['#667eea', '#764ba2'],
      accentGradient: ['#f093fb', '#f5576c'],
      primaryColor: '#667eea',
      secondaryColor: '#764ba2',
      accentColor: '#f093fb',
      surfaceColor: '#FFFFFF',
      backgroundColor: '#F7FAFC',
      errorColor: '#E53E3E',
      successColor: '#38A169',
      warningColor: '#DD6B20',
      primaryTextColor: '#2D3748',
      secondaryTextColor: '#718096',
      accentTextColor: '#667eea',
      disabledTextColor: '#A0AEC0',
      onPrimaryTextColor: '#FFFFFF',
    ),
    AppTheme(
      name: 'Sunset Light',
      isDark: false,
      backgroundGradient: ['#FF9A9E', '#FAD0C4'],
      buttonGradient: ['#FF9A9E', '#FAD0C4'],
      cardGradient: ['#FFFFFF', '#FFF5F5'],
      appBarGradient: ['#FF9A9E', '#FAD0C4'],
      accentGradient: ['#A8EDEA', '#FEE140'],
      primaryColor: '#FF9A9E',
      secondaryColor: '#FAD0C4',
      accentColor: '#A8EDEA',
      surfaceColor: '#FFFFFF',
      backgroundColor: '#FFF5F5',
      errorColor: '#E53E3E',
      successColor: '#38A169',
      warningColor: '#DD6B20',
      primaryTextColor: '#2D3748',
      secondaryTextColor: '#718096',
      accentTextColor: '#FF9A9E',
      disabledTextColor: '#A0AEC0',
      onPrimaryTextColor: '#FFFFFF',
    ),
    AppTheme(
      name: 'Mint Fresh Light',
      isDark: false,
      backgroundGradient: ['#4facfe', '#00f2fe'],
      buttonGradient: ['#4facfe', '#00f2fe'],
      cardGradient: ['#FFFFFF', '#F0FDF4'],
      appBarGradient: ['#4facfe', '#00f2fe'],
      accentGradient: ['#43e97b', '#38f9d7'],
      primaryColor: '#4facfe',
      secondaryColor: '#00f2fe',
      accentColor: '#43e97b',
      surfaceColor: '#FFFFFF',
      backgroundColor: '#F0FDF4',
      errorColor: '#E53E3E',
      successColor: '#38A169',
      warningColor: '#DD6B20',
      primaryTextColor: '#2D3748',
      secondaryTextColor: '#718096',
      accentTextColor: '#4facfe',
      disabledTextColor: '#A0AEC0',
      onPrimaryTextColor: '#FFFFFF',
    ),
  ];

  // Dark Themes
  static final List<AppTheme> darkThemes = [
    AppTheme(
      name: 'Deep Ocean Dark',
      isDark: true,
      backgroundGradient: ['#0f0c29', '#302b63', '#24243e'],
      buttonGradient: ['#667eea', '#764ba2'],
      cardGradient: ['#2D3748', '#4A5568'],
      appBarGradient: ['#667eea', '#764ba2'],
      accentGradient: ['#f093fb', '#f5576c'],
      primaryColor: '#667eea',
      secondaryColor: '#764ba2',
      accentColor: '#f093fb',
      surfaceColor: '#2D3748',
      backgroundColor: '#1A202C',
      errorColor: '#FC8181',
      successColor: '#68D391',
      warningColor: '#F6AD55',
      primaryTextColor: '#FFFFFF',
      secondaryTextColor: '#E2E8F0',
      accentTextColor: '#f093fb',
      disabledTextColor: '#718096',
      onPrimaryTextColor: '#FFFFFF',
    ),
    AppTheme(
      name: 'Cyber Punk Dark',
      isDark: true,
      backgroundGradient: ['#0f0c29', '#302b63', '#24243e'],
      buttonGradient: ['#ff057c', '#8d0b93'],
      cardGradient: ['#2D1B69', '#3A2C7D'],
      appBarGradient: ['#ff057c', '#8d0b93'],
      accentGradient: ['#321575', '#8d0b93'],
      primaryColor: '#ff057c',
      secondaryColor: '#8d0b93',
      accentColor: '#321575',
      surfaceColor: '#2D1B69',
      backgroundColor: '#1A103C',
      errorColor: '#FF6B6B',
      successColor: '#51CF66',
      warningColor: '#FFA94D',
      primaryTextColor: '#FFFFFF',
      secondaryTextColor: '#E2E8F0',
      accentTextColor: '#ff057c',
      disabledTextColor: '#718096',
      onPrimaryTextColor: '#FFFFFF',
    ),
    AppTheme(
      name: 'Midnight Blue Dark',
      isDark: true,
      backgroundGradient: ['#0c0c6d', '#1a1a1a'],
      buttonGradient: ['#3498db', '#2c3e50'],
      cardGradient: ['#2C3E50', '#34495E'],
      appBarGradient: ['#3498db', '#2c3e50'],
      accentGradient: ['#2980b9', '#8e44ad'],
      primaryColor: '#3498db',
      secondaryColor: '#2c3e50',
      accentColor: '#2980b9',
      surfaceColor: '#2C3E50',
      backgroundColor: '#1A202C',
      errorColor: '#E74C3C',
      successColor: '#27AE60',
      warningColor: '#F39C12',
      primaryTextColor: '#FFFFFF',
      secondaryTextColor: '#BDC3C7',
      accentTextColor: '#3498db',
      disabledTextColor: '#7F8C8D',
      onPrimaryTextColor: '#FFFFFF',
    ),
  ];

  // Get all default themes
  static List<AppTheme> get defaultThemes {
    return [...lightThemes, ...darkThemes];
  }

  // Color conversion methods
  static List<Color> hexToColors(List<String> hexColors) {
    return hexColors.map((hex) {
      final hexCode = hex.replaceAll('#', '');
      return Color(int.parse('FF$hexCode', radix: 16));
    }).toList();
  }

  static Color hexToColor(String hexColor) {
    final hexCode = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}