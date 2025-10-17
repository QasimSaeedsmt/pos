import 'package:flutter/foundation.dart';

import 'app.dart';

class POSServiceProvider extends ChangeNotifier {
  final EnhancedPOSService _posService = EnhancedPOSService();

  EnhancedPOSService get posService => _posService;

  void setTenantContext(String tenantId) {
    _posService.setTenantContext(tenantId);
    notifyListeners();
  }
}