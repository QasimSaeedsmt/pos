import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class VibrationProvider extends ChangeNotifier {
  bool _vibrationEnabled = true;
  bool _incrementHapticEnabled = true;
  bool _hasVibrator = true;

  VibrationProvider() {
    _initializeVibrator();
    _loadPreferences();
  }

  bool get vibrationEnabled => _vibrationEnabled;
  bool get incrementHapticEnabled => _incrementHapticEnabled;
  bool get hasVibrator => _hasVibrator;

  Future<void> _initializeVibrator() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        _hasVibrator = true;
      } else {
        _hasVibrator = false;
        debugPrint('Device does not have a vibrator');
      }
    } catch (e) {
      _hasVibrator = false;
      debugPrint('Error checking vibrator: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    _incrementHapticEnabled = prefs.getBool('increment_haptic_enabled') ?? true;
    notifyListeners();
  }

  Future<void> toggleVibration(bool value) async {
    _vibrationEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', value);

    // Test vibration when enabling
    if (value && _hasVibrator) {
      _simpleVibrate();
    }

    notifyListeners();
  }

  Future<void> toggleIncrementHaptic(bool value) async {
    _incrementHapticEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('increment_haptic_enabled', value);

    // Test vibration when enabling
    if (value && _vibrationEnabled && _hasVibrator) {
      vibrateForIncrement();
    }

    notifyListeners();
  }

  Future<void> vibrate({int duration = 100}) async {
    if (_vibrationEnabled && _hasVibrator) {
      try {
        await Vibration.vibrate(duration: duration);
      } catch (e) {
        debugPrint('Vibration failed: $e');
        // Fallback to haptic feedback
        await SystemSound.play(SystemSoundType.click);
      }
    }
  }

  Future<void> vibrateForIncrement() async {
    if (_incrementHapticEnabled && _vibrationEnabled && _hasVibrator) {
      try {
        // Short, crisp vibration for increment
        await Vibration.vibrate(duration: 30);
      } catch (e) {
        debugPrint('Increment vibration failed: $e');
        await SystemSound.play(SystemSoundType.click);
      }
    }
  }

  Future<void> vibrateSuccess() async {
    if (_vibrationEnabled && _hasVibrator) {
      try {
        // Success pattern: short-long-short
        await Vibration.vibrate(pattern: [0, 50, 100, 50]);
      } catch (e) {
        debugPrint('Success vibration failed: $e');
        await SystemSound.play(SystemSoundType.click);
      }
    }
  }

  Future<void> vibrateError() async {
    if (_vibrationEnabled && _hasVibrator) {
      try {
        // Error pattern: three quick vibrations
        await Vibration.vibrate(pattern: [0, 100, 100, 100, 100, 100]);
      } catch (e) {
        debugPrint('Error vibration failed: $e');
        await SystemSound.play(SystemSoundType.alert);
      }
    }
  }

  Future<void> vibrateScan() async {
    if (_vibrationEnabled && _hasVibrator) {
      try {
        // Scan pattern: quick vibration
        await Vibration.vibrate(duration: 50);
      } catch (e) {
        debugPrint('Scan vibration failed: $e');
        await SystemSound.play(SystemSoundType.click);
      }
    }
  }

  // Simple vibration method (private)
  Future<void> _simpleVibrate({int duration = 50}) async {
    try {
      await Vibration.vibrate(duration: duration);
    } catch (e) {
      debugPrint('Simple vibration error: $e');
    }
  }
}