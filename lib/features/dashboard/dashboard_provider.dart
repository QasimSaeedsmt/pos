// dashboard_provider.dart
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dashboard_models.dart';
import 'dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repository;
  final Connectivity _connectivity;

  DashboardCache? _dashboardData;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isOnline = true;
  String? _error;

  DashboardCache? get dashboardData => _dashboardData;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isOnline => _isOnline;
  String? get error => _error;

  DashboardProvider({
    required DashboardRepository repository,
    required Connectivity connectivity,
  }) : _repository = repository, _connectivity = connectivity {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (!wasOnline && _isOnline && _dashboardData != null) {
        // Auto-refresh when coming back online
        _refreshData(_dashboardData!.tenantId);
      }

      notifyListeners();
    });
  }

  Future<void> loadDashboard(String tenantId) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check initial connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;

      // Load dashboard data with offline-first strategy[citation:1][citation:7]
      _dashboardData = await _repository.loadDashboardData(tenantId);

      _isLoading = false;
      notifyListeners();

      // If online, refresh in background for fresh data
      if (_isOnline) {
        _refreshDataInBackground(tenantId);
      }
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to load dashboard: ${e.toString()}';
      notifyListeners();
      debugPrint('❌ Error loading dashboard: $e');
    }
  }

  Future<void> refreshDashboard(String tenantId) async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      // Force refresh from network if online
      if (_isOnline) {
        await _repository.refreshDashboard(tenantId);
        _dashboardData = await _repository.loadDashboardData(tenantId);
      } else {
        // If offline, reload from cache
        _dashboardData = await _repository.loadDashboardData(tenantId);
      }

      _isRefreshing = false;
      notifyListeners();
    } catch (e) {
      _isRefreshing = false;
      _error = 'Failed to refresh: ${e.toString()}';
      notifyListeners();
      debugPrint('❌ Error refreshing dashboard: $e');
    }
  }

  Future<void> _refreshData(String tenantId) async {
    try {
      await _repository.refreshDashboard(tenantId);
      final updatedData = await _repository.loadDashboardData(tenantId);

      if (updatedData.lastUpdated.isAfter(_dashboardData?.lastUpdated ?? DateTime(0))) {
        _dashboardData = updatedData;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    }
  }

  Future<void> _refreshDataInBackground(String tenantId) async {
    // Debounce background refresh to avoid too many calls
    await Future.delayed(Duration(seconds: 2));
    _refreshData(tenantId);
  }

  Future<void> clearCache(String tenantId) async {
    await _repository.clearCache(tenantId);
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}