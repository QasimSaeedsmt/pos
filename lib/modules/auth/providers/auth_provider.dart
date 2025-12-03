import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../features/users/users_base.dart';
import '../models/activity_type.dart';
import '../models/tenant_model.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/offline_storage_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_activity_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class MyAuthProvider with ChangeNotifier {
  AppUser? _currentUser;
  Tenant? _currentTenant;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineMode = false;
  bool _isSubscriptionExpired = false;
  SubscriptionState _subscriptionState = SubscriptionState.unknown;
  bool _showSubscriptionWarning = false;

  // Forgot password state
  bool _isSendingResetEmail = false;
  bool _isResettingPassword = false;
  bool _isVerifyingCode = false;
  String? _resetError;
  String? _resetSuccess;
  String? _resetEmail;

  final BiometricService _biometricService = BiometricService();
  final OfflineStorageService _storageService;

  MyAuthProvider(OfflineStorageService storageService)
      : _storageService = storageService {
    _initializeAuthState();
  }

  // -------------------- Getters --------------------
  AppUser? get currentUser => _currentUser;
  Tenant? get currentTenant => _currentTenant;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOfflineMode => _isOfflineMode;
  bool get isSubscriptionExpired => _isSubscriptionExpired;
  bool get keepMeLoggedIn => _storageService.keepMeLoggedIn;
  bool get fingerprintEnabled => _storageService.fingerprintEnabled;
  bool get appLockEnabled => _storageService.appLockEnabled;
  DateTime? get lastUnlockTime => _storageService.lastUnlockTime;
  bool get isSendingResetEmail => _isSendingResetEmail;
  bool get isResettingPassword => _isResettingPassword;
  bool get isVerifyingCode => _isVerifyingCode;
  String? get resetError => _resetError;
  String? get resetSuccess => _resetSuccess;
  String? get resetEmail => _resetEmail;
  SubscriptionState get subscriptionState => _subscriptionState;
  bool get showSubscriptionWarning => _showSubscriptionWarning;

  // -------------------- Initialization --------------------
  Future<void> _initializeAuthState() async {
    final firebaseUser = AuthService.currentUser;
    if (firebaseUser != null && _storageService.keepMeLoggedIn) {
      await _loadUserData(firebaseUser.uid);
    } else if (_storageService.offlineUserId != null &&
        _storageService.isOfflineSessionValid()) {
      _isOfflineMode = true;
      await _loadOfflineUserData();
    }
    notifyListeners();
  }

  // -------------------- Subscription Management --------------------
  Future<SubscriptionState> _checkSubscriptionState() async {
    if (_currentUser == null || _currentTenant == null) {
      return SubscriptionState.unknown;
    }

    if (_currentUser!.isSuperAdmin) {
      return SubscriptionState.active;
    }

    if (!_currentTenant!.isActive) {
      return SubscriptionState.tenantInactive;
    }

    if (_currentTenant!.isSubscriptionExpired) {
      return SubscriptionState.expired;
    }

    if (_currentTenant!.daysUntilExpiry <= 7) {
      return SubscriptionState.expiringSoon;
    }

    return SubscriptionState.active;
  }

  Future<void> _handleExpiredSubscription() async {
    // CRITICAL: Clear all session data
    await _storageService.clearOfflineSession();

    if (_currentUser != null && !_currentUser!.isSuperAdmin) {
      try {
        await UserActivityRepository.logUserActivity(
          tenantId: _currentUser!.tenantId,
          userId: _currentUser!.uid,
          userEmail: _currentUser!.email,
          userDisplayName: _currentUser!.displayName,
          action: ActivityType.subscription_expired,
          description: 'Login blocked due to expired subscription',
          metadata: {
            'expiryDate': _currentTenant!.subscriptionExpiry.toIso8601String(),
            'daysExpired': DateTime.now().difference(_currentTenant!.subscriptionExpiry).inDays.toString(),
          },
        );
      } catch (e) {
       debugPrint('Failed to log subscription expiry: $e');
      }
    }

    // CRITICAL: Logout from Firebase but keep user info for display
    await AuthService.logout();
  }

  // -------------------- Network Detection --------------------
  bool _isNetworkError(dynamic e) {
    final errorString = e.toString().toLowerCase();

    // More precise network error detection
    return e is SocketException ||
        e is TimeoutException ||
        e is HttpException ||
        e is WebSocketException ||
        (errorString.contains('network') && errorString.contains('error')) ||
        (errorString.contains('connection') && errorString.contains('failed')) ||
        (errorString.contains('socket') && errorString.contains('exception')) ||
        errorString.contains('internet') ||
        errorString.contains('unreachable') ||
        errorString.contains('no route to host') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection reset') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('software caused connection abort');
  }

  Future<bool> _isActuallyOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Additional verification - try to reach a reliable endpoint
      final response = await http.get(
        Uri.parse('https://www.gstatic.com/generate_204'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // -------------------- Login --------------------
  Future<void> login(String email, String password,
      {bool fromBiometric = false}) async {
    try {
      _isLoading = true;
      _error = null;
      _isOfflineMode = false;
      _isSubscriptionExpired = false;
      _subscriptionState = SubscriptionState.unknown;
      _showSubscriptionWarning = false;

      // CRITICAL: Clear previous user data at the start of login
      _currentUser = null;
      _currentTenant = null;

      notifyListeners();

      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }

      final credential =
      await AuthService.loginWithEmailAndPassword(email, password);

      await _loadUserData(credential.user!.uid);

      _subscriptionState = await _checkSubscriptionState();

      switch (_subscriptionState) {
        case SubscriptionState.expired:
          _isSubscriptionExpired = true;
          await _handleExpiredSubscription();

          // CRITICAL: Clear user data when subscription is expired
          _currentUser = null;
          _currentTenant = null;
          await _storageService.clearOfflineSession();

          notifyListeners();
          return;

        case SubscriptionState.tenantInactive:
        // CRITICAL: Clear user data when tenant is inactive
          _currentUser = null;
          _currentTenant = null;
          await _storageService.clearOfflineSession();
          await AuthService.logout();
          throw 'This business account is no longer active. Please contact support.';

        case SubscriptionState.expiringSoon:
          _showSubscriptionWarning = true;
          break;

        case SubscriptionState.active:
          break;

        case SubscriptionState.unknown:
          throw 'Unable to verify subscription status. Please try again.';
      }

      // Only save offline session if subscription is valid
      if (_currentUser != null && _currentTenant != null &&
          _subscriptionState != SubscriptionState.expired &&
          _subscriptionState != SubscriptionState.tenantInactive) {

        final userData = {
          'uid': _currentUser!.uid,
          'email': _currentUser!.email,
          'displayName': _currentUser!.displayName,
          'role': _currentUser!.role.toString(),
          'tenantId': _currentUser!.tenantId,
          'isActive': _currentUser!.isActive,
          'createdAt': _currentUser!.createdAt.toIso8601String(),
          'createdBy': _currentUser!.createdBy,
          'lastLogin': DateTime.now().toIso8601String(),
        };

        final tenantData = {
          'id': _currentTenant!.id,
          'businessName': _currentTenant!.businessName,
          'subscriptionPlan': _currentTenant!.subscriptionPlan,
          'subscriptionExpiry': _currentTenant!.subscriptionExpiry.toIso8601String(),
          'isActive': _currentTenant!.isActive,
          'branding': _currentTenant!.branding,
        };

        await _storageService.saveOfflineSession(
          userId: _currentUser!.uid,
          userData: userData,
          tenantData: tenantData,
        );
      }

      if (appLockEnabled) {
        await _updateLastUnlockTime();
      }

      if (_currentUser != null && !_currentUser!.isSuperAdmin) {
        await UserActivityRepository.logUserActivity(
          tenantId: _currentUser!.tenantId,
          userId: _currentUser!.uid,
          userEmail: _currentUser!.email,
          userDisplayName: _currentUser!.displayName,
          action: ActivityType.user_login,
          description: fromBiometric
              ? 'User logged in using biometrics'
              : 'User logged in successfully',
          metadata: {'loginMethod': fromBiometric ? 'biometric' : 'email_password'},
        );
      }
    } catch (e) {
      _error = e.toString();

      // Enhanced offline mode detection
      final isActuallyOffline = !await _isActuallyOnline();
      final hasValidOfflineSession = _storageService.offlineUserId != null &&
          _storageService.isOfflineSessionValid();

     debugPrint("🔄 Login error: $e");
     debugPrint("📶 Actual offline status: $isActuallyOffline");
     debugPrint("💾 Valid offline session: $hasValidOfflineSession");

      // Only go to offline mode if we're actually offline AND have valid session
      if (isActuallyOffline && hasValidOfflineSession && _isNetworkError(e)) {
        _isOfflineMode = true;
        await _loadOfflineUserData();

        _subscriptionState = await _checkSubscriptionState();

        if (_subscriptionState == SubscriptionState.expired ||
            _subscriptionState == SubscriptionState.tenantInactive) {
          _isSubscriptionExpired = true;
          _currentUser = null;
          _currentTenant = null;
          await _storageService.clearOfflineSession();
          _error = 'Offline access blocked: ${_subscriptionState == SubscriptionState.expired ? 'subscription expired' : 'account inactive'}.';
          return;
        }

       debugPrint("✅ Successfully fell back to offline mode");
      } else {
        // If we're online but login failed, don't show offline mode
        _isOfflineMode = false;
       debugPrint("❌ Not falling back to offline mode - either online or no valid session");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool get isTenantSubscriptionActive {
    if (_currentTenant == null) return false;
    if (_currentUser != null && _currentUser!.isSuperAdmin) return true;
    return _currentTenant!.isSubscriptionActive;
  }

  // -------------------- Load user data --------------------
  Future<void> _loadUserData(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await AuthRepository.loadUserData(uid);

      if (_currentUser != null) {
        _currentTenant = await AuthRepository.loadTenantData(_currentUser!.tenantId);
      }

      if (_currentUser == null) {
        throw Exception('User not found in any active tenant.');
      }

      if (!_currentUser!.isSuperAdmin && _currentTenant != null) {
        _subscriptionState = await _checkSubscriptionState();

        // CRITICAL: Throw exception if subscription is expired or inactive
        if (_subscriptionState == SubscriptionState.tenantInactive) {
          _currentUser = null;
          _currentTenant = null;
          throw 'This business account is no longer active.';
        }

        if (_subscriptionState == SubscriptionState.expired) {
          _currentUser = null;
          _currentTenant = null;
          throw 'Your subscription has expired. Please contact your admin or visit vetsall.co.uk.';
        }
      }
    } catch (e) {
      _error = 'Failed to load user data: $e';

      if (_storageService.offlineUserId != null &&
          _storageService.isOfflineSessionValid()) {
        _isOfflineMode = true;
        await _loadOfflineUserData();
        if (_currentUser != null) {
          _subscriptionState = await _checkSubscriptionState();
          if (_subscriptionState != SubscriptionState.expired &&
              _subscriptionState != SubscriptionState.tenantInactive) {
            return;
          }
        }
      }

      await logout();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadOfflineUserData() async {
    final userData = _storageService.offlineUserData;
    final tenantData = _storageService.offlineTenantData;

    if (userData == null || tenantData == null) return;

    try {
      _currentUser = AppUser(
        uid: userData['uid'] ?? '',
        email: userData['email'] ?? 'unknown@email.com',
        displayName: userData['displayName'] ?? 'Offline User',
        role: UserRole.values.firstWhere(
              (e) => e.toString() == userData['role'],
          orElse: () => UserRole.cashier,
        ),
        tenantId: userData['tenantId'] ?? 'offline',
        isActive: userData['isActive'] ?? true,
        createdAt: userData['createdAt'] != null
            ? DateTime.parse(userData['createdAt'])
            : DateTime.now(),
        createdBy: userData['createdBy'] ?? 'system',
        lastLogin: userData['lastLogin'] != null
            ? DateTime.parse(userData['lastLogin'])
            : DateTime.now(),
        profile: userData['profile'] is Map
            ? Map<String, dynamic>.from(userData['profile'])
            : {},
        permissions: userData['permissions'] is List
            ? List<String>.from(userData['permissions'])
            : [],
      );

      _currentTenant = Tenant(
        id: tenantData['id'] ?? 'offline',
        businessName: tenantData['businessName'] ?? 'Offline Business',
        subscriptionPlan: tenantData['subscriptionPlan'] ?? 'monthly',
        subscriptionExpiry: tenantData['subscriptionExpiry'] != null
            ? DateTime.parse(tenantData['subscriptionExpiry'])
            : DateTime.now().add(Duration(days: 30)),
        isActive: tenantData['isActive'] ?? true,
        branding: tenantData['branding'] is Map
            ? Map<String, dynamic>.from(tenantData['branding'])
            : {},
      );

      _subscriptionState = await _checkSubscriptionState();

      if (_subscriptionState == SubscriptionState.expired ||
          _subscriptionState == SubscriptionState.tenantInactive) {
        _isSubscriptionExpired = true;
        _error = 'Offline access blocked: '
            '${_subscriptionState == SubscriptionState.expired ? "subscription expired" : "account inactive"}.';
      }
    } catch (e) {
     debugPrint('Error loading offline user data: $e');
      await _storageService.clearOfflineSession();
      _currentUser = null;
      _currentTenant = null;
      _subscriptionState = SubscriptionState.unknown;
      _error = 'Failed to load offline session. Please login again.';
    }
    notifyListeners();
  }

  // -------------------- Logout --------------------
  Future<void> logout() async {
    try {
      // Store user data before clearing for logging
      final user = _currentUser;
      final tenantId = user?.tenantId;
      final isSuperAdmin = user?.isSuperAdmin ?? false;
      final isOffline = _isOfflineMode;

      // Clear state first to avoid any null issues
      await AuthService.logout();
      await _storageService.clearOfflineSession();

      // Log user activity if conditions are met
      if (user != null && !isSuperAdmin && !isOffline) {
        try {
          await UserActivityRepository.logUserActivity(
            tenantId: tenantId ?? 'unknown',
            userId: user.uid,
            userEmail: user.email,
            userDisplayName: user.displayName,
            action: ActivityType.user_logout,
            description: 'User logged out',
          );
        } catch (e) {
         debugPrint('Failed to log logout activity: $e');
          // Don't rethrow - logging failure shouldn't prevent logout
        }
      }

      // Clear all state variables
      _currentUser = null;
      _currentTenant = null;
      _error = null;
      _isOfflineMode = false;
      _isSubscriptionExpired = false;
      _subscriptionState = SubscriptionState.unknown;
      _showSubscriptionWarning = false;

      await _storageService.setLastUnlockTime(DateTime.now());

    } catch (e) {
     debugPrint('Error during logout: $e');
      // Ensure state is cleared even if there's an error
      _currentUser = null;
      _currentTenant = null;
      _error = 'Logout completed with minor issues';
      _isOfflineMode = false;
      _isSubscriptionExpired = false;
      _subscriptionState = SubscriptionState.unknown;
      _showSubscriptionWarning = false;

      await _storageService.clearOfflineSession();
      await _storageService.setLastUnlockTime(DateTime.now());
    } finally {
      notifyListeners();
    }
  }

  // -------------------- App Lock / Biometric --------------------
  Future<void> _updateLastUnlockTime() async {
    await _storageService.setLastUnlockTime(DateTime.now());
    notifyListeners();
  }

  Future<bool> isAppLockRequired() async {
    if (!appLockEnabled) return false;
    final lastUnlock = _storageService.lastUnlockTime;
    if (lastUnlock == null) return true;
    final difference = DateTime.now().difference(lastUnlock);
    return difference.inSeconds > _storageService.lockTimeout;
  }

  Future<bool> authenticateForAppUnlock() async {
    final success =
    await _biometricService.authenticate(reason: 'Authenticate to unlock the app');
    if (success) await _updateLastUnlockTime();
    return success;
  }

  Future<bool> testBiometricAuthentication() async {
    return await _biometricService.testBiometricAuthentication();
  }

  Future<void> setLockTimeout(int seconds) async {
    await _storageService.setLockTimeout(seconds);
    notifyListeners();
  }

  // -------------------- Keep me logged in --------------------
  Future<void> setKeepMeLoggedIn(bool value) async {
    await _storageService.setKeepMeLoggedIn(value);
    notifyListeners();
  }

  Future<void> setKeepMeLoggedInSilent(bool value) async {
    await _storageService.setKeepMeLoggedIn(value);
  }

  Future<void> setFingerprintEnabled(bool value) async {
    await _storageService.setFingerprintEnabled(value);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool value) async {
    await _storageService.setAppLockEnabled(value);
    if (!value) {
      await _storageService.setLastUnlockTime(DateTime.now());
    }
    notifyListeners();
  }

  // -------------------- Forgot Password --------------------
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _isSendingResetEmail = true;
      _resetError = null;
      _resetSuccess = null;
      _resetEmail = email;
      notifyListeners();

      await AuthRepository.sendPasswordResetEmail(email);
      _resetSuccess = 'Password reset email sent! Check your inbox.';

      if (_currentUser != null && !_currentUser!.isSuperAdmin) {
        await UserActivityRepository.logUserActivity(
          tenantId: _currentUser!.tenantId,
          userId: _currentUser!.uid,
          userEmail: _currentUser!.email,
          userDisplayName: _currentUser!.displayName,
          action: ActivityType.user_password_changed,
          description: 'User requested password reset',
          metadata: {'targetEmail': email},
        );
      }
    } catch (e) {
      _resetError = e.toString();
    } finally {
      _isSendingResetEmail = false;
      notifyListeners();
    }
  }

  Future<bool> verifyResetCode(String code) async {
    try {
      _isVerifyingCode = true;
      _resetError = null;
      notifyListeners();

      await AuthRepository.verifyPasswordResetCode(code);
      return true;
    } catch (e) {
      _resetError = e.toString();
      return false;
    } finally {
      _isVerifyingCode = false;
      notifyListeners();
    }
  }

  Future<void> resetPasswordWithCode({
    required String code,
    required String newPassword,
  }) async {
    try {
      _isResettingPassword = true;
      _resetError = null;
      _resetSuccess = null;
      notifyListeners();

      await AuthRepository.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );

      _resetSuccess =
      'Password reset successfully! You can now login with your new password.';

      Future.delayed(Duration(seconds: 3), () {
        clearResetState();
      });
    } catch (e) {
      _resetError = e.toString();
    } finally {
      _isResettingPassword = false;
      notifyListeners();
    }
  }

  void clearResetState() {
    _resetError = null;
    _resetSuccess = null;
    _resetEmail = null;
    _isSendingResetEmail = false;
    _isResettingPassword = false;
    _isVerifyingCode = false;
    notifyListeners();
  }

  void dismissSubscriptionWarning() {
    _showSubscriptionWarning = false;
    notifyListeners();
  }
}