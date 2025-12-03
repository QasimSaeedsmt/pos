import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/main_navigation/main_navigation_base.dart';
import '../../../features/super_admin/super_admin_base.dart';
import '../../../theme_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/auth_strings.dart';
import '../constants/auth_measurements.dart';
import '../constants/auth_constants.dart';
import 'login_screen.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isAuthenticating = false;
  bool _showFallbackButton = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AuthConstants.animationDuration),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
    _triggerBiometricAuth();
  }

  Future<void> _triggerBiometricAuth() async {
    await Future.delayed(const Duration(milliseconds: AuthConstants.autoAuthDelay));

    if (!mounted) return;

    setState(() {
      _isAuthenticating = true;
    });

    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final success = await authProvider.authenticateForAppUnlock();

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    if (success) {
      await _onAuthenticationSuccess();
    } else {
      setState(() {
        _showFallbackButton = true;
      });
    }
  }

  Future<void> _onAuthenticationSuccess() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (!mounted) return;

    if (user != null) {
      if (user.isSuperAdmin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SuperAdminDashboard()),
              (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavScreen()),
              (route) => false,
        );
      }
    }
  }

  Future<void> _tryAgain() async {
    setState(() {
      _isAuthenticating = true;
      _showFallbackButton = false;
    });

    await _triggerBiometricAuth();
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    await authProvider.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final gradientColors = themeProvider.getCurrentGradientColors();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(AuthMeasurements.spacingXXLarge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: AuthMeasurements.iconSizeLarge,
                    height: AuthMeasurements.iconSizeLarge,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusXLarge),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(AuthMeasurements.opacityLow),
                          blurRadius: AuthMeasurements.elevationHigh,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: AuthMeasurements.spacingHuge),
                  Text(
                    AuthStrings.appLocked,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(AuthConstants.textPrimaryDark),
                    ),
                  ),
                  const SizedBox(height: AuthMeasurements.spacingLarge),
                  Text(
                    AuthStrings.authenticateToContinue,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : const Color(AuthConstants.textSecondaryColor),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AuthMeasurements.spacingHuge),
                  Container(
                    width: AuthMeasurements.iconSizeLarge,
                    height: AuthMeasurements.iconSizeLarge,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(AuthConstants.darkSurfaceColor) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(AuthMeasurements.opacityLow),
                          blurRadius: AuthMeasurements.elevationMedium,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _isAuthenticating
                        ? const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(AuthConstants.primaryColor),
                      ),
                    )
                        : Icon(
                      Icons.fingerprint_rounded,
                      size: AuthMeasurements.iconSizeMedium,
                      color: const Color(AuthConstants.primaryColor),
                    ),
                  ),
                  const SizedBox(height: AuthMeasurements.spacingXXLarge),
                  Text(
                    _isAuthenticating
                        ? AuthStrings.authenticating
                        : AuthStrings.touchFingerprint,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(AuthConstants.textSecondaryColor),
                    ),
                  ),
                  const SizedBox(height: AuthMeasurements.spacingHuge),
                  if (_showFallbackButton) ...[
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: AuthMeasurements.buttonHeight,
                          child: ElevatedButton(
                            onPressed: _isAuthenticating ? null : _tryAgain,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(AuthConstants.primaryColor),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusMedium),
                              ),
                              elevation: AuthMeasurements.elevationLow,
                            ),
                            child: _isAuthenticating
                                ? const SizedBox(
                              width: AuthMeasurements.iconSizeSmall,
                              height: AuthMeasurements.iconSizeSmall,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Text(
                              AuthStrings.tryAgain,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AuthMeasurements.spacingLarge),
                        SizedBox(
                          width: double.infinity,
                          height: AuthMeasurements.buttonHeight,
                          child: OutlinedButton(
                            onPressed: _logout,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white70
                                  : const Color(AuthConstants.textSecondaryColor),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white30
                                    : const Color(0xFFCBD5E0),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusMedium),
                              ),
                            ),
                            child: const Text(
                              AuthStrings.useDifferentAccount,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (!_isAuthenticating) ...[
                    SizedBox(
                      width: double.infinity,
                      height: AuthMeasurements.buttonHeight,
                      child: ElevatedButton(
                        onPressed: _tryAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(AuthConstants.primaryColor),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusMedium),
                          ),
                          elevation: AuthMeasurements.elevationLow,
                        ),
                        child: const Text(
                          AuthStrings.authenticateNow,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}