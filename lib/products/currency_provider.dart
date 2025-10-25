import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mpcm/main.dart';

import '../features/auth/auth_base.dart';
import '../modules/auth/providers/auth_provider.dart';

class CurrencyService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _currency = "USD";
  bool _isLoading = false;
  String? _error;

  // Getters
  String get currency => _currency;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static const String defaultCurrency = 'USD';

  Future<void> loadCurrency(String tenantId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .get();

      if (doc.exists) {
        _currency = doc.data()?['currency'] ?? defaultCurrency;
      } else {
        _currency = defaultCurrency;
        _error = 'Tenant not found';
      }
    } catch (e) {
      _currency = defaultCurrency;
      _error = 'Failed to load currency: $e';
      print('Error loading currency: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCurrency(MyAuthProvider authProvider ,String newCurrency) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestore
          .collection('tenants')
          .doc(authProvider.currentUser?.tenantId)
          .update({
        'currency': newCurrency,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _currency = newCurrency;
    } catch (e) {
      _error = 'Failed to update currency: $e';
      print('Error updating currency: $e');
      rethrow; // Let the caller handle the error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}