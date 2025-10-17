// theme_selector_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'custom_theme_creation.dart';
import 'theme_provider.dart';


class ThemeSelectorBottomSheet extends StatefulWidget {
  const ThemeSelectorBottomSheet({super.key});

  @override
  State<ThemeSelectorBottomSheet> createState() => _ThemeSelectorBottomSheetState();
}

class _ThemeSelectorBottomSheetState extends State<ThemeSelectorBottomSheet> {
  int _currentTab = 0;

  void _showCustomThemeCreator([GradientTheme? existingTheme]) {
    showDialog(
      context: context,
      builder: (context) => CustomThemeCreator(existingTheme: existingTheme),
    );
  }

  void _deleteCustomTheme(GradientTheme theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Theme'),
        content: Text('Are you sure you want to delete "${theme.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).deleteCustomTheme(theme);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Theme Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildTab('Gradients', 0),
                _buildTab('Appearance', 1),
                _buildTab('Custom', 2),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildGradientsTab(themeProvider),
                _buildAppearanceTab(themeProvider),
                _buildCustomThemesTab(themeProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    return Expanded(
      child: TextButton(
        onPressed: () => setState(() => _currentTab = index),
        style: TextButton.styleFrom(
          foregroundColor: _currentTab == index ? Theme.of(context).primaryColor : Colors.grey,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: _currentTab == index ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientsTab(ThemeProvider themeProvider) {
    return FutureBuilder<List<GradientTheme>>(
      future: themeProvider.getAvailableThemes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final themes = snapshot.data ?? [];
        final defaultThemes = themes.where((t) => GradientThemeManager.defaultThemes.any((dt) => dt.name == t.name)).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Default Gradients',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: defaultThemes.length,
                itemBuilder: (context, index) {
                  final theme = defaultThemes[index];
                  return _buildThemeCard(theme, themeProvider, false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppearanceTab(ThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme Mode',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.phone_iphone),
                    title: const Text('System Default'),
                    trailing: Radio<bool>(
                      value: true,
                      groupValue: themeProvider.useSystemTheme,
                      onChanged: (value) => themeProvider.setUseSystemTheme(true),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.light_mode),
                    title: const Text('Light Mode'),
                    trailing: Radio<bool>(
                      value: false,
                      groupValue: themeProvider.useSystemTheme,
                      onChanged: (value) {
                        themeProvider.setUseSystemTheme(false);
                        themeProvider.setDarkMode(false);
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dark_mode),
                    title: const Text('Dark Mode'),
                    trailing: Radio<bool>(
                      value: false,
                      groupValue: themeProvider.useSystemTheme,
                      onChanged: (value) {
                        themeProvider.setUseSystemTheme(false);
                        themeProvider.setDarkMode(true);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomThemesTab(ThemeProvider themeProvider) {
    return FutureBuilder<List<GradientTheme>>(
      future: themeProvider.getAvailableThemes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final themes = snapshot.data ?? [];
        final customThemes = themes.where((t) => !GradientThemeManager.defaultThemes.any((dt) => dt.name == t.name)).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: () => _showCustomThemeCreator(),
                icon: const Icon(Icons.add),
                label: const Text('Create New Theme'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            Expanded(
              child: customThemes.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.palette, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No custom themes yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: customThemes.length,
                itemBuilder: (context, index) {
                  final theme = customThemes[index];
                  return _buildThemeCard(theme, themeProvider, true);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeCard(GradientTheme theme, ThemeProvider themeProvider, bool isCustom) {
    final colors = GradientThemeManager().hexToColors(theme.colors);
    final isSelected = themeProvider.currentTheme?.name == theme.name;

    return GestureDetector(
      onTap: () => themeProvider.setTheme(theme),
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(
                color: Colors.white,
                width: 3,
              )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    theme.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    theme.isDark ? 'Dark' : 'Light',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            const Positioned(
              top: 12,
              right: 12,
              child: Icon(Icons.check, color: Colors.white, size: 20),
            ),
          if (isCustom)
            Positioned(
              top: 8,
              left: 8,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _showCustomThemeCreator(theme),
                    icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: () => _deleteCustomTheme(theme),
                    icon: const Icon(Icons.delete, color: Colors.white, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}