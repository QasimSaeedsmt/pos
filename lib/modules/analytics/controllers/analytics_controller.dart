import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/utils/logger.dart';
import '../models/analytics_models.dart';
import '../models/report_models.dart';
import '../services/analytics_service.dart';
import '../services/report_generator.dart';
import '../services/data_processor.dart';

/// Controller for analytics module with state management
class AnalyticsController extends ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();
  final ReportGenerator _reportGenerator = ReportGenerator();
  final DataProcessor _dataProcessor = DataProcessor();
  final Logger _logger = Logger('AnalyticsController');

  // State variables
  PerformanceMetrics _metrics = PerformanceMetrics.empty;
  SalesReport? _currentSalesReport;
  InventoryReport? _currentInventoryReport;
  AnalyticsQuery _currentQuery = AnalyticsQuery(
    startDate: DateTime.now().subtract(Duration(days: 30)),
    endDate: DateTime.now(),
    reportType: 'sales',
  );

  bool _isLoading = false;
  bool _isGeneratingReport = false;
  bool _isExporting = false;
  bool _isOnline = true;
  String? _error;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Getters
  PerformanceMetrics get metrics => _metrics;
  SalesReport? get currentSalesReport => _currentSalesReport;
  InventoryReport? get currentInventoryReport => _currentInventoryReport;
  AnalyticsQuery get currentQuery => _currentQuery;
  bool get isLoading => _isLoading;
  bool get isGeneratingReport => _isGeneratingReport;
  bool get isExporting => _isExporting;
  bool get isOnline => _isOnline;
  String? get error => _error;

  /// Initialize controller
  Future<void> initialize() async {
    try {
      _logger.info('Initializing analytics controller');

      // Initialize services
      await _analyticsService.initialize();
      await _dataProcessor.initialize();

      // Set up connectivity listener
      _setupConnectivityListener();

      // Load initial data
      await loadMetrics();

      _logger.info('Analytics controller initialized successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize analytics controller',
        error: e,
        stackTrace: stackTrace,
      );
      _setError('Failed to initialize: $e');
    }
  }

  /// Set up connectivity monitoring
  void _setupConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
          final result = results.isNotEmpty ? results.first : ConnectivityResult.none;

          final wasOnline = _isOnline;
          _isOnline = result != ConnectivityResult.none;

          if (wasOnline != _isOnline) {
            _logger.info('Connectivity changed: ${_isOnline ? 'Online' : 'Offline'}');
            notifyListeners();

            if (_isOnline) {
              _refreshOnReconnect();
            }
          }
        });
  }


  /// Refresh data when reconnecting
  void _refreshOnReconnect() {
    if (!_isLoading) {
      loadMetrics();
    }
  }

  /// Update current query
  void updateQuery(AnalyticsQuery query) {
    _currentQuery = query;
    _logger.debug('Query updated', extra: query.toMap());
    notifyListeners();
  }

  /// Load performance metrics
  Future<void> loadMetrics() async {
    if (_isLoading) return;

    _setLoading(true);
    _clearError();

    try {
      _logger.debug('Loading performance metrics', extra: _currentQuery.toMap());

      final metrics = await _analyticsService.getPerformanceMetrics(_currentQuery);
      _metrics = metrics;

      _logger.info('Metrics loaded successfully', extra: {
        'totalRevenue': metrics.totalRevenue,
        'totalOrders': metrics.totalOrders,
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to load metrics',
        error: e,
        stackTrace: stackTrace,
      );
      _setError('Failed to load metrics: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Generate sales report
  Future<void> generateSalesReport() async {
    if (_isGeneratingReport) return;

    _setGeneratingReport(true);
    _clearError();

    try {
      _logger.info('Generating sales report', extra: _currentQuery.toMap());

      final report = await _analyticsService.generateSalesReport(_currentQuery);
      _currentSalesReport = report;

      _logger.info('Sales report generated', extra: {
        'reportName': report.name,
        'totalSales': report.totalSales,
        'transactions': report.numberOfTransactions,
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to generate sales report',
        error: e,
        stackTrace: stackTrace,
      );
      _setError('Failed to generate report: $e');
    } finally {
      _setGeneratingReport(false);
    }
  }

  /// Generate inventory report
  Future<void> generateInventoryReport() async {
    if (_isGeneratingReport) return;

    _setGeneratingReport(true);
    _clearError();

    try {
      _logger.info('Generating inventory report', extra: _currentQuery.toMap());

      // This would need actual implementation with inventory data
      // For now, create a placeholder
      _currentInventoryReport = InventoryReport.empty;

      _logger.info('Inventory report generated (placeholder)');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to generate inventory report',
        error: e,
        stackTrace: stackTrace,
      );
      _setError('Failed to generate inventory report: $e');
    } finally {
      _setGeneratingReport(false);
    }
  }

  /// Process large dataset
  Future<Map<String, dynamic>> processLargeDataset(
      String operation,
      Map<String, dynamic> data,
      ) async {
    _setLoading(true);
    _clearError();

    try {
      _logger.debug('Processing large dataset', extra: {
        'operation': operation,
        'dataSize': data.length,
      });

      final result = await _dataProcessor.processData(
        operation: operation,
        data: data,
        query: _currentQuery,
      );

      _logger.info('Dataset processed successfully', extra: {
        'operation': operation,
        'resultSize': result.length,
      });

      return result;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to process dataset',
        error: e,
        stackTrace: stackTrace,
        extra: {'operation': operation},
      );
      _setError('Processing failed: $e');
      return {'error': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  /// Clear current reports
  void clearReports() {
    _currentSalesReport = null;
    _currentInventoryReport = null;
    _logger.debug('Reports cleared');
    notifyListeners();
  }

  /// Clear cache
  Future<void> clearCache() async {
    try {
      _analyticsService.clearCache();
      _dataProcessor.clearCache();
      _logger.info('Cache cleared');
    } catch (e) {
      _logger.error('Failed to clear cache', error: e);
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set report generation state
  void _setGeneratingReport(bool generating) {
    _isGeneratingReport = generating;
    notifyListeners();
  }

  /// Set exporting state
  void setExporting(bool exporting) {
    _isExporting = exporting;
    notifyListeners();
  }

  /// Set error
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error
  void _clearError() {
    _error = null;
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _analyticsService.dispose();
    _dataProcessor.dispose();
    super.dispose();
    _logger.info('Analytics controller disposed');
  }
}