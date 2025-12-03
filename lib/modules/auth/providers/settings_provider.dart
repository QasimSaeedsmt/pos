import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/biometric_service.dart';

class SettingsProvider with ChangeNotifier {
  final BiometricService _biometricService = BiometricService();

  List<BiometricType> _availableBiometrics = [];
  bool _loading = false;

  List<BiometricType> get availableBiometrics => _availableBiometrics;
  bool get loading => _loading;

  SettingsProvider() {
    _checkAvailableBiometrics();
  }

  Future<void> _checkAvailableBiometrics() async {
    try {
      _availableBiometrics = await _biometricService.getAvailableBiometrics();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking available biometrics: $e');
      }
    }
  }

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  Future<bool> testBiometricAuth() async {
    setLoading(true);
    final result = await _biometricService.testBiometricAuthentication();
    setLoading(false);
    return result;
  }

  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scan';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
    }
  }

  IconData getBiometricIcon(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return Icons.face_retouching_natural;
      case BiometricType.fingerprint:
        return Icons.fingerprint;
      case BiometricType.iris:
        return Icons.remove_red_eye;
      default:
        return Icons.security;
    }
  }
}