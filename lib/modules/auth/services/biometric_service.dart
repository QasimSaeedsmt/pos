import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error checking biometric support: ${e.message}');
      }
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error checking biometric availability: ${e.message}');
      }
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error getting available biometrics: ${e.message}');
      }
      return [];
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        sensitiveTransaction: true,
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Biometric authentication failed: ${e.message}');
      }
      return false;
    }
  }

  Future<bool> testBiometricAuthentication() async {
    try {
      final isSupported = await isBiometricSupported();
      if (!isSupported) return false;

      final canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      return await authenticate(reason: 'Test your biometric authentication');
    } catch (e) {
      if (kDebugMode) {
        print('Biometric test error: $e');
      }
      return false;
    }
  }
}