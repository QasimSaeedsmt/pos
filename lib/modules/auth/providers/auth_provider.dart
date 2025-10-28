import 'package:flutter/foundation.dart';
import '../../../features/users/users_base.dart';
import '../models/activity_type.dart';
import '../models/user_model.dart';
import '../models/tenant_model.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/offline_storage_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_activity_repository.dart';

class MyAuthProvider with ChangeNotifier {
  AppUser? _currentUser;
  Tenant? _currentTenant;
  bool _isLoading = false;
  String? _error;
  bool _isOfflineMode = false;

  // Forgot password state
  bool _isSendingResetEmail = false;
  bool _isResettingPassword = false;
  bool _isVerifyingCode = false;
  String? _resetError;
  String? _resetSuccess;
  String? _resetEmail;

  // static final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  final OfflineStorageService _storageService;

  MyAuthProvider(OfflineStorageService storageService) : _storageService = storageService {
    _initializeAuthState();
  }

  AppUser? get currentUser => _currentUser;
  Tenant? get currentTenant => _currentTenant;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOfflineMode => _isOfflineMode;
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

  Future<void> _initializeAuthState() async {
    // Try online authentication first
    final firebaseUser = AuthService.currentUser;
    if (firebaseUser != null && _storageService.keepMeLoggedIn) {
      await _loadUserData(firebaseUser.uid);
    } else if (_storageService.offlineUserId != null && _storageService.isOfflineSessionValid()) {
      _isOfflineMode = true;
      await _loadOfflineUserData();
    }
    notifyListeners();
  }

  Future<void> login(String email, String password, {bool fromBiometric = false}) async {
    try {
      _isLoading = true;
      _error = null;
      _isOfflineMode = false;
      notifyListeners();

      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }

      final credential = await AuthService.loginWithEmailAndPassword(email, password);
      await _loadUserData(credential.user!.uid);

      if (_currentUser != null && _currentTenant != null) {
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
          action: fromBiometric ? ActivityType.user_login : ActivityType.user_login,
          description: fromBiometric
              ? 'User logged in using biometrics'
              : 'User logged in successfully',
          metadata: {
            'loginMethod': fromBiometric ? 'biometric' : 'email_password',
          },
        );
      }
    } catch (e) {
      _error = e.toString();

      // Fallback to offline mode if network error and offline session exists
      if (_isNetworkError(e) &&
          _storageService.offlineUserId != null &&
          _storageService.isOfflineSessionValid()) {
        _isOfflineMode = true;
        await _loadOfflineUserData();
        if (_currentUser != null) return;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isNetworkError(dynamic e) {
    return e.toString().toLowerCase().contains('network') ||
        e.toString().toLowerCase().contains('socket') ||
        e.toString().toLowerCase().contains('connection');
  }

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
    } catch (e) {
      _error = 'Failed to load user data: $e';

      // Fallback to offline data
      if (_storageService.offlineUserId != null && _storageService.isOfflineSessionValid()) {
        _isOfflineMode = true;
        await _loadOfflineUserData();
        if (_currentUser != null) return;
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
    } catch (e) {
      print('Error loading offline user data: $e');
      await _storageService.clearOfflineSession();
    }
  }

  Future<void> logout() async {
    if (_currentUser != null && !_currentUser!.isSuperAdmin && !_isOfflineMode) {
      await UserActivityRepository.logUserActivity(
        tenantId: _currentUser!.tenantId,
        userId: _currentUser!.uid,
        userEmail: _currentUser!.email,
        userDisplayName: _currentUser!.displayName,
        action: ActivityType.user_logout,
        description: 'User logged out',
      );
    }

    await AuthService.logout();
    await _storageService.clearOfflineSession();

    _currentUser = null;
    _currentTenant = null;
    _error = null;
    _isOfflineMode = false;

    await _storageService.setLastUnlockTime(DateTime.now());
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _isSendingResetEmail = true;
      _resetError = null;
      _resetSuccess = null;
      _resetEmail = email;
      notifyListeners();

      await AuthRepository.sendPasswordResetEmail(email);
      _resetSuccess = 'Password reset email sent! Check your inbox for the reset link.';

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

      _resetSuccess = 'Password reset successfully! You can now login with your new password.';

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

  Future<void> _updateLastUnlockTime() async {
    await _storageService.setLastUnlockTime(DateTime.now());
    notifyListeners();
  }

  Future<bool> isAppLockRequired() async {
    if (!appLockEnabled) return false;

    final lastUnlock = _storageService.lastUnlockTime;
    if (lastUnlock == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastUnlock);
    final timeout = _storageService.lockTimeout;

    return difference.inSeconds > timeout;
  }

  Future<bool> authenticateForAppUnlock() async {
    final success = await _biometricService.authenticate(
        reason: 'Authenticate to unlock the app'
    );

    if (success) {
      await _updateLastUnlockTime();
    }

    return success;
  }

  Future<bool> testBiometricAuthentication() async {
    return await _biometricService.testBiometricAuthentication();
  }

  Future<void> setLockTimeout(int seconds) async {
    await _storageService.setLockTimeout(seconds);
    notifyListeners();
  }
}