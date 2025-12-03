import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import '../../../modules/analytics/models/analytics_models.dart';
import '../../../modules/analytics/models/report_models.dart';
import '../../utils/logger.dart';


/// Analytics-specific local storage operations
class AnalyticsStorage {
  static final AnalyticsStorage _instance = AnalyticsStorage._internal();
  factory AnalyticsStorage() => _instance;
  AnalyticsStorage._internal();

  final Logger _logger = Logger('AnalyticsStorage');
  final _lock = Lock();

  // Storage keys
  static const String _reportsKey = 'analytics_reports';
  static const String _metricsCacheKey = 'analytics_metrics_cache';
  static const String _queryHistoryKey = 'analytics_query_history';
  static const String _exportHistoryKey = 'analytics_export_history';
  static const String _lastSyncKey = 'analytics_last_sync';
  static const String _settingsKey = 'analytics_settings';

  /// Initialize storage
  Future<void> initialize() async {
    try {
      _logger.debug('Analytics storage initialized');
    } catch (e) {
      _logger.error('Failed to initialize analytics storage', error: e);
      rethrow;
    }
  }

  /// Save generated report
  Future<void> saveReport(BaseReport report) async {
    await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final reportsJson = prefs.getString(_reportsKey);
        final List<Map<String, dynamic>> reports = reportsJson != null
            ? List<Map<String, dynamic>>.from(json.decode(reportsJson))
            : [];

        // Convert report to map
        final reportMap = report.toMap();
        reportMap['_type'] = report.runtimeType.toString();
        reportMap['_savedAt'] = DateTime.now().toIso8601String();

        // Add or update report
        final existingIndex = reports.indexWhere((r) => r['id'] == report.id);
        if (existingIndex != -1) {
          reports[existingIndex] = reportMap;
        } else {
          reports.insert(0, reportMap);
        }

        // Limit to 50 reports
        final limitedReports = reports.length > 50
            ? reports.sublist(0, 50)
            : reports;

        await prefs.setString(_reportsKey, json.encode(limitedReports));

        _logger.debug(
          'Report saved: ${report.name}',
          extra: {'reportId': report.id},
        );
      } catch (e) {
        _logger.error('Failed to save report', error: e);
        throw Exception('Failed to save report locally: $e');
      }
    });
  }

  /// Get saved reports
  Future<List<BaseReport>> getSavedReports({int limit = 20}) async {
    return await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final reportsJson = prefs.getString(_reportsKey);

        if (reportsJson == null) return [];

        final List<Map<String, dynamic>> reports = List<Map<String, dynamic>>.from(
          json.decode(reportsJson),
        );

        final List<BaseReport> parsedReports = [];

        for (final reportMap in reports) {
          try {
            final type = reportMap['_type']?.toString() ?? '';
            BaseReport report;

            if (type.contains('SalesReport')) {
              report = SalesReport.fromMap(reportMap);
            } else if (type.contains('InventoryReport')) {
              report = InventoryReport.fromMap(reportMap);
            } else {
              // Generic report
              report = SalesReport.fromMap(reportMap);
            }

            parsedReports.add(report);
          } catch (e) {
            _logger.warning('Failed to parse saved report', error: e);
          }
        }

        return parsedReports.take(limit).toList();
      } catch (e) {
        _logger.error('Failed to get saved reports', error: e);
        return [];
      }
    });
  }

  /// Delete saved report
  Future<void> deleteReport(String reportId) async {
    await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final reportsJson = prefs.getString(_reportsKey);

        if (reportsJson == null) return;

        final List<Map<String, dynamic>> reports = List<Map<String, dynamic>>.from(
          json.decode(reportsJson),
        );

        reports.removeWhere((report) => report['id'] == reportId);

        await prefs.setString(_reportsKey, json.encode(reports));

        _logger.debug('Report deleted', extra: {'reportId': reportId});
      } catch (e) {
        _logger.error('Failed to delete report', error: e);
      }
    });
  }

  /// Cache performance metrics
  Future<void> cacheMetrics(
      String cacheKey,
      PerformanceMetrics metrics,
      ) async {
    await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cacheJson = prefs.getString(_metricsCacheKey);
        final Map<String, dynamic> cache = cacheJson != null
            ? Map<String, dynamic>.from(json.decode(cacheJson))
            : {};

        cache[cacheKey] = {
          'metrics': metrics.toMap(),
          'cachedAt': DateTime.now().toIso8601String(),
        };

        // Limit cache size
        if (cache.length > 100) {
          final oldestKey = cache.keys.first;
          cache.remove(oldestKey);
        }

        await prefs.setString(_metricsCacheKey, json.encode(cache));

        _logger.debug('Metrics cached', extra: {'cacheKey': cacheKey});
      } catch (e) {
        _logger.warning('Failed to cache metrics', error: e);
      }
    });
  }

  /// Get cached metrics
  Future<PerformanceMetrics?> getCachedMetrics(String cacheKey) async {
    return await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cacheJson = prefs.getString(_metricsCacheKey);

        if (cacheJson == null) return null;

        final cache = Map<String, dynamic>.from(json.decode(cacheJson));
        final cachedData = cache[cacheKey];

        if (cachedData == null) return null;

        final cachedAt = DateTime.parse(cachedData['cachedAt']);
        final cacheAge = DateTime.now().difference(cachedAt);

        // Use cache if less than 10 minutes old
        if (cacheAge < Duration(minutes: 10)) {
          final metrics = PerformanceMetrics.fromMap(cachedData['metrics']);
          _logger.debug('Using cached metrics', extra: {'cacheKey': cacheKey});
          return metrics;
        } else {
          // Remove expired cache
          cache.remove(cacheKey);
          await prefs.setString(_metricsCacheKey, json.encode(cache));
          return null;
        }
      } catch (e) {
        _logger.warning('Failed to get cached metrics', error: e);
        return null;
      }
    });
  }

  /// Save query history
  Future<void> saveQueryHistory(AnalyticsQuery query) async {
    await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final historyJson = prefs.getString(_queryHistoryKey);
        final List<Map<String, dynamic>> history = historyJson != null
            ? List<Map<String, dynamic>>.from(json.decode(historyJson))
            : [];

        final queryMap = query.toMap();
        queryMap['_usedAt'] = DateTime.now().toIso8601String();

        // Remove duplicate
        history.removeWhere((q) => _queriesEqual(q, queryMap));

        // Add to beginning
        history.insert(0, queryMap);

        // Limit to 50 queries
        final limitedHistory = history.length > 50
            ? history.sublist(0, 50)
            : history;

        await prefs.setString(_queryHistoryKey, json.encode(limitedHistory));

        _logger.debug('Query history saved');
      } catch (e) {
        _logger.warning('Failed to save query history', error: e);
      }
    });
  }

  /// Get query history
  Future<List<AnalyticsQuery>> getQueryHistory({int limit = 10}) async {
    return await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final historyJson = prefs.getString(_queryHistoryKey);

        if (historyJson == null) return [];

        final List<Map<String, dynamic>> history = List<Map<String, dynamic>>.from(
          json.decode(historyJson),
        );

        final queries = <AnalyticsQuery>[];

        for (final queryMap in history.take(limit)) {
          try {
            final query = AnalyticsQuery.fromMap(queryMap);
            queries.add(query);
          } catch (e) {
            _logger.warning('Failed to parse query from history', error: e);
          }
        }

        return queries;
      } catch (e) {
        _logger.error('Failed to get query history', error: e);
        return [];
      }
    });
  }

  /// Save export history
  Future<void> saveExportHistory(Map<String, dynamic> exportRecord) async {
    await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final historyJson = prefs.getString(_exportHistoryKey);
        final List<Map<String, dynamic>> history = historyJson != null
            ? List<Map<String, dynamic>>.from(json.decode(historyJson))
            : [];

        exportRecord['_exportedAt'] = DateTime.now().toIso8601String();
        history.insert(0, exportRecord);

        // Limit to 100 exports
        final limitedHistory = history.length > 100
            ? history.sublist(0, 100)
            : history;

        await prefs.setString(_exportHistoryKey, json.encode(limitedHistory));

        _logger.debug('Export history saved');
      } catch (e) {
        _logger.warning('Failed to save export history', error: e);
      }
    });
  }

  /// Get export history
  Future<List<Map<String, dynamic>>> getExportHistory({int limit = 20}) async {
    return await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final historyJson = prefs.getString(_exportHistoryKey);

        if (historyJson == null) return [];

        final List<Map<String, dynamic>> history = List<Map<String, dynamic>>.from(
          json.decode(historyJson),
        );

        return history.take(limit).toList();
      } catch (e) {
        _logger.error('Failed to get export history', error: e);
        return [];
      }
    });
  }

  /// Update last sync timestamp
  Future<void> updateLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastSyncKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      _logger.warning('Failed to update last sync', error: e);
    }
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString(_lastSyncKey);
      return lastSync != null ? DateTime.parse(lastSync) : null;
    } catch (e) {
      _logger.warning('Failed to get last sync', error: e);
      return null;
    }
  }

  /// Save analytics settings
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(settings));
      _logger.debug('Analytics settings saved');
    } catch (e) {
      _logger.error('Failed to save settings', error: e);
    }
  }

  /// Get analytics settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      return settingsJson != null
          ? Map<String, dynamic>.from(json.decode(settingsJson))
          : {};
    } catch (e) {
      _logger.error('Failed to get settings', error: e);
      return {};
    }
  }

  /// Clear all analytics data
  Future<void> clearAllData() async {
    await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_reportsKey);
        await prefs.remove(_metricsCacheKey);
        await prefs.remove(_queryHistoryKey);
        await prefs.remove(_exportHistoryKey);
        await prefs.remove(_lastSyncKey);

        _logger.info('All analytics data cleared');
      } catch (e) {
        _logger.error('Failed to clear analytics data', error: e);
      }
    });
  }

  /// Helper method to check if queries are equal
  bool _queriesEqual(Map<String, dynamic> q1, Map<String, dynamic> q2) {
    try {
      return q1['startDate'] == q2['startDate'] &&
          q1['endDate'] == q2['endDate'] &&
          q1['reportType'] == q2['reportType'];
    } catch (e) {
      return false;
    }
  }

  /// Get orders for a specific period (for offline analytics)
  Future<List<Map<String, dynamic>>> getOrdersForPeriod(
      DateTime startDate,
      DateTime endDate, {
        List<String>? categories,
      }) async {
    // This would need integration with your existing LocalDatabase
    // Placeholder implementation
    _logger.debug(
      'Getting orders for period',
      extra: {'start': startDate, 'end': endDate},
    );
    return [];
  }

  /// Get all products (for offline analytics)
  Future<List<Map<String, dynamic>>> getAllProducts() async {
    // Placeholder - integrate with your LocalDatabase
    return [];
  }

  /// Get customers for period (for offline analytics)
  Future<List<Map<String, dynamic>>> getCustomersForPeriod(
      DateTime startDate,
      DateTime endDate,
      ) async {
    // Placeholder - integrate with your LocalDatabase
    return [];
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    return await _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();

        final reportsJson = prefs.getString(_reportsKey);
        final cacheJson = prefs.getString(_metricsCacheKey);
        final queryJson = prefs.getString(_queryHistoryKey);
        final exportJson = prefs.getString(_exportHistoryKey);

        return {
          'reportsCount': reportsJson != null
              ? List.from(json.decode(reportsJson)).length
              : 0,
          'cacheEntries': cacheJson != null
              ? Map.from(json.decode(cacheJson)).length
              : 0,
          'queryHistoryCount': queryJson != null
              ? List.from(json.decode(queryJson)).length
              : 0,
          'exportHistoryCount': exportJson != null
              ? List.from(json.decode(exportJson)).length
              : 0,
          'lastSync': await getLastSync(),
        };
      } catch (e) {
        _logger.error('Failed to get storage stats', error: e);
        return {'error': e.toString()};
      }
    });
  }
}