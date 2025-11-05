import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../features/main_navigation/main_navigation_base.dart';
import '../../../features/super_admin/super_admin_base.dart';
import '../constants/auth_measurements.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'account_disabled_screen.dart';
import 'app_lock_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  static final Future<bool> _superAdminFuture = AuthRepository.checkSuperAdminExists();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: true);

    return FutureBuilder<bool>(
      future: _superAdminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // if (snapshot.hasData && snapshot.data == false) {
        //   return const SuperAdminSetupScreen();
        // }

        if (snapshot.hasError) {
          debugPrint('Error loading super admin state: ${snapshot.error}');
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, userSnapshot) {
            final user = authProvider.currentUser;

            if (userSnapshot.connectionState == ConnectionState.waiting ||
                authProvider.isLoading) {
              return const SplashScreen();
            }

            if ((userSnapshot.hasData && user != null) ||
                (authProvider.isOfflineMode && user != null)) {
              if (!user.isActive) return const AccountDisabledScreen();

              if (authProvider.isOfflineMode) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.orange[300]),
                          const SizedBox(width: AuthMeasurements.spacingSmall),
                          const Expanded(
                            child: Text(
                              'Offline Mode - Limited functionality',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange[800],
                      duration: const Duration(seconds: 3),
                    ),
                  );
                });
              }

              return FutureBuilder<bool>(
                future: _shouldShowAppLock(authProvider),
                builder: (context, lockSnapshot) {
                  if (lockSnapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }

                  final shouldShowAppLock = lockSnapshot.data ?? false;

                  if (shouldShowAppLock) {
                    return const AppLockScreen();
                  }

                  return user.isSuperAdmin
                      ? const SuperAdminDashboard()
                      : const MainNavScreen();
                },
              );
            }

            return const LoginScreen();
          },
        );
      },
    );
  }

  Future<bool> _shouldShowAppLock(MyAuthProvider authProvider) async {
    if (!authProvider.appLockEnabled || authProvider.currentUser == null) {
      return false;
    }

    try {
      final isLockRequired = await authProvider.isAppLockRequired();
      return isLockRequired;
    } catch (e) {
      debugPrint('Error checking app lock: $e');
      return true;
    }
  }
}