import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

class OfflineStorageService {
  static const String _offlineUserIdKey = 'offlineUserId';
  static const String _offlineLoginTimeKey = 'offlineLoginTime';
  static const String _offlineUserDataKey = 'offlineUserData';
  static const String _offlineTenantDataKey = 'offlineTenantData';
  static const String _keepMeLoggedInKey = 'keepMeLoggedIn';
  static const String _fingerprintEnabledKey = 'fingerprintEnabled';
  static const String _appLockEnabledKey = 'appLockEnabled';
  static const String _lastUnlockTimeKey = 'lastUnlockTime';
  static const String _lockTimeoutKey = 'lockTimeout';

  final SharedPreferences _prefs;

  OfflineStorageService(this._prefs);

  Future<void> saveOfflineSession({
    required String userId,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> tenantData,
  }) async {
    await _prefs.setString(_offlineUserIdKey, userId);
    await _prefs.setInt(_offlineLoginTimeKey, DateTime.now().millisecondsSinceEpoch);
    await _prefs.setString(_offlineUserDataKey, json.encode(userData));
    await _prefs.setString(_offlineTenantDataKey, json.encode(tenantData));
  }

  Future<void> clearOfflineSession() async {
    await _prefs.remove(_offlineUserIdKey);
    await _prefs.remove(_offlineLoginTimeKey);
    await _prefs.remove(_offlineUserDataKey);
    await _prefs.remove(_offlineTenantDataKey);
  }

  String? get offlineUserId => _prefs.getString(_offlineUserIdKey);
  DateTime? get offlineLoginTime {
    final timestamp = _prefs.getInt(_offlineLoginTimeKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Map<String, dynamic>? get offlineUserData {
    final dataString = _prefs.getString(_offlineUserDataKey);
    if (dataString != null) {
      try {
        return Map<String, dynamic>.from(json.decode(dataString));
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing offline user data: $e');
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? get offlineTenantData {
    final dataString = _prefs.getString(_offlineTenantDataKey);
    if (dataString != null) {
      try {
        return Map<String, dynamic>.from(json.decode(dataString));
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing offline tenant data: $e');
        }
      }
    }
    return null;
  }

  Future<void> setKeepMeLoggedIn(bool value) async {
    await _prefs.setBool(_keepMeLoggedInKey, value);
  }

  bool get keepMeLoggedIn => _prefs.getBool(_keepMeLoggedInKey) ?? false;

  Future<void> setFingerprintEnabled(bool value) async {
    await _prefs.setBool(_fingerprintEnabledKey, value);
  }

  bool get fingerprintEnabled => _prefs.getBool(_fingerprintEnabledKey) ?? false;

  Future<void> setAppLockEnabled(bool value) async {
    await _prefs.setBool(_appLockEnabledKey, value);
  }

  bool get appLockEnabled => _prefs.getBool(_appLockEnabledKey) ?? false;

  Future<void> setLastUnlockTime(DateTime time) async {
    await _prefs.setString(_lastUnlockTimeKey, time.toIso8601String());
  }

  DateTime? get lastUnlockTime {
    final timeString = _prefs.getString(_lastUnlockTimeKey);
    return timeString != null ? DateTime.parse(timeString) : null;
  }

  Future<void> setLockTimeout(int seconds) async {
    await _prefs.setInt(_lockTimeoutKey, seconds);
  }

  int get lockTimeout => _prefs.getInt(_lockTimeoutKey) ?? 30;

  bool isOfflineSessionValid() {
    if (offlineLoginTime == null) return false;
    final now = DateTime.now();
    final difference = now.difference(offlineLoginTime!);
    return difference.inHours <= 24;
  }

  Future<void> cacheOfflineData(String type, Map<String, dynamic> data) async {
    final offlineBox = Hive.box('offline_data');
    final pendingSync = offlineBox.get('pending_sync', defaultValue: []) as List;
    pendingSync.add({'type': type, 'data': data, 'timestamp': DateTime.now()});
    await offlineBox.put('pending_sync', pendingSync);
  }
}