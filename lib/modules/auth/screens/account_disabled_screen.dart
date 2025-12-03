import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme_provider.dart';
import '../constants/auth_constants.dart';
import '../providers/auth_provider.dart';
import '../constants/auth_strings.dart';
import '../constants/auth_measurements.dart';

class AccountDisabledScreen extends StatelessWidget {
  const AccountDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final gradientColors = themeProvider.getCurrentGradientColors();
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = themeProvider.useSystemTheme
        ? brightness == Brightness.dark
        : themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.all(AuthMeasurements.screenPadding),
            child: Card(
              elevation: AuthMeasurements.elevationCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusXXLarge),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AuthMeasurements.cardPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: AuthMeasurements.iconSizeLarge,
                      color: Colors.red,
                    ),
                    const SizedBox(height: AuthMeasurements.spacingXLarge),
                    Text(
                      AuthStrings.accountDisabled,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: AuthMeasurements.spacingMedium),
                    Text(
                      AuthStrings.accountDisabledMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: AuthMeasurements.spacingXXXLarge),
                    SizedBox(
                      width: double.infinity,
                      height: AuthMeasurements.buttonHeight,
                      child: ElevatedButton(
                        onPressed: () => authProvider.logout(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AuthConstants.primaryColor),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusLarge),
                          ),
                        ),
                        child: const Text(
                          AuthStrings.returnToLogin,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}