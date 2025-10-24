// theme_selector_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'theme_provider.dart';

class ThemeSelectorBottomSheet extends StatefulWidget {
  const ThemeSelectorBottomSheet({super.key});

  @override
  State<ThemeSelectorBottomSheet> createState() => _ThemeSelectorBottomSheetState();
}

class _ThemeSelectorBottomSheetState extends State<ThemeSelectorBottomSheet> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.8,
      decoration: BoxDecoration(
        color: themeProvider.getSurfaceColor(),
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
                  color: themeProvider.getSecondaryTextColor().withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: themeProvider.getPrimaryTextColor()),
                ),
                const SizedBox(width: 16),
                Text(
                  'Theme Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.getPrimaryTextColor(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildTab('Light Themes', 0, themeProvider),
                _buildTab('Dark Themes', 1, themeProvider),
                _buildTab('Custom', 2, themeProvider),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildThemesTab(ThemeManager.lightThemes, themeProvider),
                _buildThemesTab(ThemeManager.darkThemes, themeProvider),
                _buildCustomThemesTab(themeProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index, ThemeProvider themeProvider) {
    return Expanded(
      child: TextButton(
        onPressed: () => setState(() => _currentTab = index),
        style: TextButton.styleFrom(
          foregroundColor: _currentTab == index ? themeProvider.getPrimaryColor() : themeProvider.getSecondaryTextColor(),
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

  Widget _buildThemesTab(List<AppTheme> themes, ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentTab == 0 ? 'Light Themes' : 'Dark Themes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: themeProvider.getPrimaryTextColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentTab == 0
                ? 'Bright themes for daytime use'
                : 'Dark themes for comfortable nighttime use',
            style: TextStyle(
              color: themeProvider.getSecondaryTextColor(),
              fontSize: 14,
            ),
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
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              return _buildThemeCard(theme, themeProvider, false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomThemesTab(ThemeProvider themeProvider) {
    return FutureBuilder<List<AppTheme>>(
      future: themeProvider.getCustomThemes(),
      builder: (context, snapshot) {
        final customThemes = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                onPressed: () => _showCustomThemeCreator(),
                icon: Icon(Icons.add, color: themeProvider.getOnPrimaryTextColor()),
                label: Text('Create New Theme', style: TextStyle(color: themeProvider.getOnPrimaryTextColor())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.getPrimaryColor(),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
            Expanded(
              child: customThemes.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.palette, size: 64, color: themeProvider.getSecondaryTextColor()),
                    const SizedBox(height: 16),
                    Text(
                      'No custom themes yet',
                      style: TextStyle(color: themeProvider.getSecondaryTextColor()),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your own unique theme combination',
                      style: TextStyle(color: themeProvider.getSecondaryTextColor(), fontSize: 12),
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

  Widget _buildThemeCard(AppTheme theme, ThemeProvider themeProvider, bool isCustom) {
    final colors = ThemeManager.hexToColors(theme.backgroundGradient);
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (int i = 0; i < colors.length && i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors[i],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                        ),
                    ],
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
        ],
      ),
    );
  }

  void _showCustomThemeCreator() {
    // You can implement custom theme creation dialog here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Custom Theme Creator', style: TextStyle(color: Provider.of<ThemeProvider>(context).getPrimaryTextColor())),
        content: Text('Custom theme creation will be implemented here', style: TextStyle(color: Provider.of<ThemeProvider>(context).getSecondaryTextColor())),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Provider.of<ThemeProvider>(context).getPrimaryColor())),
          ),
        ],
      ),
    );
  }
}