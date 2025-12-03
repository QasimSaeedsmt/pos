import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/logger.dart';
import '../models/analytics_models.dart';
import '../models/report_models.dart';
import '../models/export_models.dart';
import '../services/report_generator.dart';
import '../services/export_service.dart';

/// Controller for report generation and export operations
class ReportController extends ChangeNotifier {
  final ReportGenerator _reportGenerator = ReportGenerator();
  final ExportService _exportService = ExportService();
  final Logger _logger = Logger('ReportController');

  // State variables
  List<BaseReport> _savedReports = [];
  List<ExportResult> _exportHistory = [];
  ExportConfig _exportConfig = ExportConfig(
    format: ExportFormat.csv,
    includeCharts: true,
    includeRawData: false,
  );

  bool _isGenerating = false;
  bool _isExporting = false;
  bool _isLoadingHistory = false;
  String? _error;
  StreamController<double>? _progressController;

  // Getters
  List<BaseReport> get savedReports => _savedReports;
  List<ExportResult> get exportHistory => _exportHistory;
  ExportConfig get exportConfig => _exportConfig;
  bool get isGenerating => _isGenerating;
  bool get isExporting => _isExporting;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;
  Stream<double>? get progressStream => _progressController?.stream;

  /// Initialize controller
  Future<void> initialize() async {
    try {
      _logger.info('Initializing report controller');
      await _loadSavedReports();
      await _loadExportHistory();
      _logger.info('Report controller initialized');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize report controller',
        error: e,
        stackTrace: stackTrace,
      );
      _setError('Initialization failed: $e');
    }
  }

  /// Load saved reports from storage
  Future<void> _loadSavedReports() async {
    _setLoadingHistory(true);
    _clearError();

    try {
      // In production, load from local storage or database
      // This is a placeholder implementation
      await Future.delayed(Duration(milliseconds: 500));

      _logger.debug('Loaded ${_savedReports.length} saved reports');
    } catch (e) {
      _logger.error('Failed to load saved reports', error: e);
      _setError('Failed to load reports: $e');
    } finally {
      _setLoadingHistory(false);
    }
  }

  /// Load export history
  Future<void> _loadExportHistory() async {
    try {
      // In production, load from local storage
      // This is a placeholder
      await Future.delayed(Duration(milliseconds: 300));
      _logger.debug('Export history loaded');
    } catch (e) {
      _logger.warning('Failed to load export history', error: e);
    }
  }

  /// Generate a new report
  Future<BaseReport?> generateReport({
    required String reportType,
    required AnalyticsQuery query,
    required Map<String, dynamic> data,
  }) async {
    if (_isGenerating) return null;

    _setGenerating(true);
    _clearError();
    _startProgressTracking();

    try {
      _logger.info('Generating $reportType report', extra: query.toMap());

      BaseReport report;

      switch (reportType) {
        case 'sales':
          report = await _generateSalesReport(query, data);
          break;
        case 'inventory':
          report = await _generateInventoryReport(query, data);
          break;
        case 'customer':
          report = await _generateCustomerReport(query, data);
          break;
        default:
          throw Exception('Unknown report type: $reportType');
      }

      // Save report
      await _saveReport(report);

      _logger.info(
        'Report generated successfully',
        extra: {'reportName': report.name, 'type': reportType},
      );

      return report;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to generate report',
        error: e,
        stackTrace: stackTrace,
        extra: {'reportType': reportType},
      );
      _setError('Report generation failed: $e');
      return null;
    } finally {
      _setGenerating(false);
      _stopProgressTracking();
    }
  }

  /// Generate sales report
  Future<SalesReport> _generateSalesReport(
      AnalyticsQuery query,
      Map<String, dynamic> data,
      ) async {
    _updateProgress(0.2);

    final orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
    final products = List<Map<String, dynamic>>.from(data['products'] ?? []);
    final customers = List<Map<String, dynamic>>.from(data['customers'] ?? []);

    _updateProgress(0.4);

    final report = await _reportGenerator.generateSalesReport(
      query: query,
      orders: orders,
      products: products,
      customers: customers,
    );

    _updateProgress(0.8);

    return report;
  }

  /// Generate inventory report
  Future<InventoryReport> _generateInventoryReport(
      AnalyticsQuery query,
      Map<String, dynamic> data,
      ) async {
    _updateProgress(0.2);

    final products = List<Map<String, dynamic>>.from(data['products'] ?? []);
    final salesData = List<Map<String, dynamic>>.from(data['salesData'] ?? []);

    _updateProgress(0.4);

    final report = await _reportGenerator.generateInventoryReport(
      query: query,
      products: products,
      salesData: salesData,
    );

    _updateProgress(0.8);

    return report;
  }

  /// Generate customer report
  Future<BaseReport> _generateCustomerReport(
      AnalyticsQuery query,
      Map<String, dynamic> data,
      ) async {
    // Placeholder implementation
    return SalesReport.empty;
  }

  /// Export report
  Future<ExportResult> exportReport({
    required BaseReport report,
    ExportConfig? config,
    String? customFileName,
  }) async {
    if (_isExporting) {
      return ExportResult(
        success: false,
        error: 'Already exporting',
        format: ExportFormat.csv,
        exportedAt: DateTime.now(),
      );
    }

    _setExporting(true);
    _clearError();
    _startProgressTracking();

    try {
      _logger.info(
        'Exporting report: ${report.name}',
        extra: {'format': (config ?? _exportConfig).format.name},
      );

      final exportConfig = config ?? _exportConfig;
      _updateProgress(0.3);

      final result = await _exportService.exportReport(
        report: report,
        config: exportConfig,
        customFileName: customFileName,
      );

      _updateProgress(0.7);

      if (result.success) {
        // Add to export history
        _exportHistory.insert(0, result);
        _saveExportHistory();

        _logger.info(
          'Export completed successfully',
          extra: {
            'fileName': result.fileName,
            'fileSize': result.fileSize,
          },
        );
      } else {
        _logger.error('Export failed', extra: {'error': result.error});
      }

      _updateProgress(1.0);

      return result;
    } catch (e, stackTrace) {
      _logger.error(
        'Export failed with error',
        error: e,
        stackTrace: stackTrace,
      );
      return ExportResult(
        success: false,
        error: e.toString(),
        format: _exportConfig.format,
        exportedAt: DateTime.now(),
      );
    } finally {
      _setExporting(false);
      _stopProgressTracking();
    }
  }

  /// Update export configuration
  void updateExportConfig(ExportConfig config) {
    _exportConfig = config;
    _logger.debug('Export config updated', extra: config.toMap());
    notifyListeners();
  }

  /// Save report to local storage
  Future<void> _saveReport(BaseReport report) async {
    try {
      // In production, save to local database
      _savedReports.insert(0, report);

      // Limit saved reports to 50
      if (_savedReports.length > 50) {
        _savedReports = _savedReports.sublist(0, 50);
      }

      _logger.debug('Report saved locally', extra: {'reportName': report.name});
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to save report', error: e);
    }
  }

  /// Save export history
  Future<void> _saveExportHistory() async {
    try {
      // In production, save to local storage
      // Limit history to 100 entries
      if (_exportHistory.length > 100) {
        _exportHistory = _exportHistory.sublist(0, 100);
      }

      _logger.debug('Export history saved', extra: {'entries': _exportHistory.length});
    } catch (e) {
      _logger.warning('Failed to save export history', error: e);
    }
  }

  /// Delete saved report
  Future<void> deleteReport(String reportId) async {
    try {
      final initialLength = _savedReports.length;
      _savedReports.removeWhere((report) => report.id == reportId);

      if (_savedReports.length < initialLength) {
        _logger.info('Report deleted', extra: {'reportId': reportId});
        notifyListeners();
      }
    } catch (e) {
      _logger.error('Failed to delete report', error: e);
      _setError('Failed to delete report: $e');
    }
  }

  /// Clear export history
  Future<void> clearExportHistory() async {
    try {
      _exportHistory.clear();
      _logger.info('Export history cleared');
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to clear export history', error: e);
    }
  }

  /// Clean up old exports
  Future<void> cleanupOldExports() async {
    try {
      await _exportService.cleanupOldExports();
      _logger.info('Old exports cleaned up');
    } catch (e) {
      _logger.warning('Failed to cleanup old exports', error: e);
    }
  }

  /// Start progress tracking
  void _startProgressTracking() {
    _progressController = StreamController<double>.broadcast();
    _progressController!.add(0.0);
  }

  /// Update progress
  void _updateProgress(double progress) {
    _progressController?.add(progress.clamp(0.0, 1.0));
  }

  /// Stop progress tracking
  void _stopProgressTracking() {
    _progressController?.close();
    _progressController = null;
  }

  /// Set generating state
  void _setGenerating(bool generating) {
    _isGenerating = generating;
    notifyListeners();
  }

  /// Set exporting state
  void _setExporting(bool exporting) {
    _isExporting = exporting;
    notifyListeners();
  }

  /// Set loading history state
  void _setLoadingHistory(bool loading) {
    _isLoadingHistory = loading;
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
    _stopProgressTracking();
    _progressController?.close();
    super.dispose();
    _logger.info('Report controller disposed');
  }
}