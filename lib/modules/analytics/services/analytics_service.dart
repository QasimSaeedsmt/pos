import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/utils/isolate_handler.dart';
import '../../../core/localStorage/modules/analytics_storage.dart';
import '../models/analytics_models.dart';
import '../models/report_models.dart';

/// Main analytics service that coordinates data processing, offline storage,
/// and heavy computation tasks with isolates
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final AnalyticsStorage _storage = AnalyticsStorage();
  final IsolateHandler _isolateHandler = IsolateHandler();
  bool _isIsolateInitialized = false;

  // Cache for performance optimization
  final Map<String, PerformanceMetrics> _metricsCache = {};
  final Map<String, BaseReport> _reportCache = {};
  DateTime? _lastCacheUpdate;

  /// Initialize the analytics service
  Future<void> initialize() async {
    try {
      await _storage.initialize();
      await _initializeIsolate();
      debugPrint('Analytics service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing analytics service: $e');
      rethrow;
    }
  }

  /// Initialize persistent isolate for heavy computations
  Future<void> _initializeIsolate() async {
    if (_isIsolateInitialized) return;

    try {
      await _isolateHandler.initialize(_analyticsWorkerEntryPoint);

      _isIsolateInitialized = true;
      debugPrint('Analytics isolate initialized');
    } catch (e) {
      debugPrint('Failed to initialize analytics isolate: $e');
      // Fallback to main thread processing
    }
  }

  /// Worker function for isolate (must be static or top-level)
  void _analyticsWorkerEntryPoint(SendPort mainSendPort) {
    // Create a port for receiving messages from the main isolate
    final port = ReceivePort();
    mainSendPort.send(port.sendPort); // send this port back to the main isolate

    port.listen((message) async {
      // message should contain:
      // 'data': Map<String, dynamic>
      // 'replyTo': SendPort
      final Map<String, dynamic> data = message['data'];
      final SendPort replyTo = message['replyTo'];

      try {
        final query = AnalyticsQuery.fromMap(data['query']);
        final orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
        final products = List<Map<String, dynamic>>.from(data['products'] ?? []);
        final customers = List<Map<String, dynamic>>.from(data['customers'] ?? []);

        // Your heavy computations
        final metrics = _calculateMetricsInIsolate(orders, query);
        final report = _generateReportInIsolate(orders, products, customers, query);

        replyTo.send({
          'success': true,
          'metrics': metrics.toMap(),
          'report': report,
          'processedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        replyTo.send({
          'success': false,
          'error': e.toString(),
          'fallbackMetrics': PerformanceMetrics.empty.toMap(),
        });
      }
    });
  }

  /// Calculate performance metrics with smart fallback strategy
  Future<PerformanceMetrics> getPerformanceMetrics(AnalyticsQuery query) async {
    // Check cache first
    final cacheKey = _generateCacheKey(query);
    if (_shouldUseCache(cacheKey)) {
      final cached = _metricsCache[cacheKey];
      if (cached != null) {
        debugPrint('Using cached metrics for $cacheKey');
        return cached;
      }
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity != ConnectivityResult.none;

    try {
      if (isOnline && _isIsolateInitialized) {
        // Use isolate for heavy computation
        final result = await _processWithIsolate(query);
        if (result['success'] == true) {
          final metrics = PerformanceMetrics.fromMap(result['metrics']);
          _updateCache(cacheKey, metrics);
          return metrics;
        }
      }

      // Fallback to local computation
      debugPrint('Using fallback computation for metrics');
      return await _calculateMetricsLocally(query);
    } catch (e) {
      debugPrint('Error calculating metrics: $e');
      return PerformanceMetrics.empty;
    }
  }

  /// Process analytics with isolate
  Future<Map<String, dynamic>> _processWithIsolate(
      AnalyticsQuery query) async {
    try {
      // Gather data for processing
      final data = await _gatherDataForProcessing(query);

      // Estimate data size for smart strategy
      final estimatedSize = utf8.encode(json.encode(data)).length;
      if (estimatedSize > 10 * 1024 * 1024) { // 10MB threshold
        debugPrint('Large dataset detected ($estimatedSize bytes), using chunked processing');
        return await _processInChunks(query, data);
      }

      // Process in isolate
      final result = await _isolateHandler.sendMessage({
        'action': 'process_analytics',
        'query': query.toMap(),
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      return result;
    } catch (e) {
      debugPrint('Isolate processing failed: $e');
      throw Exception('Analytics processing failed: $e');
    }
  }

  /// Gather data for processing with efficient queries
  Future<Map<String, dynamic>> _gatherDataForProcessing(
      AnalyticsQuery query) async {
    final stopwatch = Stopwatch()..start();

    // Gather data in parallel with timeouts
    final ordersFuture = _storage.getOrdersForPeriod(
      query.startDate,
      query.endDate,
      categories: query.productCategories,
    ).timeout(Duration(seconds: 10));

    final productsFuture = _storage.getAllProducts().timeout(Duration(seconds: 5));
    final customersFuture = _storage.getCustomersForPeriod(
      query.startDate,
      query.endDate,
    ).timeout(Duration(seconds: 5));

    try {
      final results = await Future.wait([
        ordersFuture,
        productsFuture,
        customersFuture,
      ], eagerError: true);

      debugPrint('Data gathered in ${stopwatch.elapsedMilliseconds}ms');
      return {
        'orders': results[0],
        'products': results[1],
        'customers': results[2],
      };
    } catch (e) {
      debugPrint('Error gathering data: $e');
      return {'orders': [], 'products': [], 'customers': []};
    }
  }

  /// Process large datasets in chunks
  Future<Map<String, dynamic>> _processInChunks(
      AnalyticsQuery query,
      Map<String, dynamic> data,
      ) async {
    final orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
    const chunkSize = 1000; // Process 1000 orders at a time
    final chunks = <List<Map<String, dynamic>>>[];

    for (var i = 0; i < orders.length; i += chunkSize) {
      chunks.add(orders.sublist(i, i + chunkSize > orders.length ? orders.length : i + chunkSize));
    }

    final results = <Map<String, dynamic>>[];
    for (var chunk in chunks) {
      final result = await _isolateHandler.sendMessage({
        'action': 'process_chunk',
        'query': query.toMap(),
        'orders': chunk,
        'products': data['products'],
        'customers': data['customers'],
        'chunkIndex': chunks.indexOf(chunk),
      });

      if (result['success'] == true) {
        results.add(result);
      }
    }

    // Merge chunk results
    return _mergeChunkResults(results);
  }

  /// Merge results from chunked processing
  Map<String, dynamic> _mergeChunkResults(List<Map<String, dynamic>> chunks) {
    if (chunks.isEmpty) {
      return {'success': false, 'error': 'No chunks processed'};
    }

    // Simplified merging logic - extend this based on your needs
    final totalRevenue = chunks.fold(0.0, (sum, chunk) =>
    sum + (chunk['metrics']['totalRevenue'] ?? 0.0));
    final totalOrders = chunks.fold<int>(
      0,
          (sum, chunk) =>
      sum + ((chunk['metrics']['totalOrders'] as num?)?.toInt() ?? 0),
    );


    return {
      'success': true,
      'metrics': {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        // Add other merged metrics
      },
    };
  }

  /// Calculate metrics locally (fallback method)
  Future<PerformanceMetrics> _calculateMetricsLocally(
      AnalyticsQuery query) async {
    final stopwatch = Stopwatch()..start();

    try {
      final orders = await _storage.getOrdersForPeriod(
        query.startDate,
        query.endDate,
        categories: query.productCategories,
      );

      if (orders.isEmpty) {
        return PerformanceMetrics.empty;
      }

      // Calculate metrics
      double totalRevenue = 0.0;
      int totalOrders = 0;
      int itemsSold = 0;
      final customerIds = <String>{};

      for (final order in orders) {
        totalRevenue += order['total']?.toDouble() ?? 0.0;
        totalOrders++;

        // Extract line items
        final lineItems = order['line_items'] as List<dynamic>? ?? [];
        for (final item in lineItems) {
          final quantity = item['quantity'];
          if (quantity != null) {
            itemsSold += (quantity as num).toInt(); // cast dynamic → num → int
          }
        }

        // Track unique customers
        final customerId = order['customerId']?.toString();
        if (customerId != null && customerId.isNotEmpty) {
          customerIds.add(customerId);
        }
      }

      final averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

      // Get customer count for conversion rate
      final customers = await _storage.getCustomersForPeriod(
        query.startDate,
        query.endDate,
      );
      final conversionRate = customers.isNotEmpty
          ? (customerIds.length / customers.length) * 100
          : 0.0;

      debugPrint('Local metrics calculation took ${stopwatch.elapsedMilliseconds}ms');

      return PerformanceMetrics(
        totalRevenue: totalRevenue,
        averageOrderValue: averageOrderValue,
        totalOrders: totalOrders,
        uniqueCustomers: customerIds.length,
        conversionRate: conversionRate,
        revenueGrowth: 0.0, // Would need historical data
        itemsSold: itemsSold,
        profitMargin: 0.0, // Would need cost data
      );
    } catch (e) {
      debugPrint('Error in local metrics calculation: $e');
      return PerformanceMetrics.empty;
    }
  }

  /// Generate sales report with smart processing
  Future<SalesReport> generateSalesReport(AnalyticsQuery query) async {
    final cacheKey = 'sales_report_${_generateCacheKey(query)}';

    // Check cache
    if (_shouldUseCache(cacheKey)) {
      final cached = _reportCache[cacheKey];
      if (cached is SalesReport) {
        return cached;
      }
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = connectivity != ConnectivityResult.none;

    try {
      SalesReport report;

      if (isOnline && _isIsolateInitialized && query.reportType == 'sales') {
        // Use isolate for complex report generation
        final data = await _gatherDataForProcessing(query);
        final orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);

        if (orders.length > 500) {
          // Large dataset, use isolate
          final result = await _isolateHandler.sendMessage({
            'action': 'generate_sales_report',
            'query': query.toMap(),
            'orders': orders,
            'products': data['products'],
          });

          if (result['success'] == true) {
            report = SalesReport.fromMap(result['report']);
          } else {
            throw Exception('Isolate report generation failed');
          }
        } else {
          // Small dataset, generate locally
          report = await _generateSalesReportLocally(query, orders);
        }
      } else {
        // Offline or simple report
        final orders = await _storage.getOrdersForPeriod(
          query.startDate,
          query.endDate,
          categories: query.productCategories,
        );
        report = await _generateSalesReportLocally(query, orders);
      }

      // Cache the report
      _updateCache(cacheKey, report);

      // Save to local storage
      await _storage.saveReport(report);

      return report;
    } catch (e) {
      debugPrint('Error generating sales report: $e');
      return SalesReport.empty;
    }
  }

  /// Generate sales report locally
  Future<SalesReport> _generateSalesReportLocally(
      AnalyticsQuery query,
      List<Map<String, dynamic>> orders,
      ) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Calculate basic metrics
      double totalSales = 0.0;
      int transactionCount = 0;
      final salesByCategory = <String, SalesByCategory>{};
      final salesByHour = List<double>.filled(24, 0.0);
      final salesByDay = List<double>.filled(7, 0.0);
      final productSales = <String, TopSellingProduct>{};
      final salesTrends = <SalesTrend>[];

      for (final order in orders) {
        final orderDate = DateTime.parse(order['dateCreated']);
        final orderTotal = order['total']?.toDouble() ?? 0.0;

        totalSales += orderTotal;
        transactionCount++;

        // Sales by hour
        final hour = orderDate.hour;
        salesByHour[hour] += orderTotal;

        // Sales by day (0 = Sunday, 6 = Saturday)
        final day = orderDate.weekday % 7;
        salesByDay[day] += orderTotal;

        // Process line items
        final lineItems = order['line_items'] as List<dynamic>? ?? [];
        for (final item in lineItems) {
          final productId = item['productId']?.toString() ?? '';
          final productName = item['productName']?.toString() ?? '';
          final quantity = item['quantity']?.toInt() ?? 0;
          final price = item['price']?.toDouble() ?? 0.0;
          final subtotal = item['subtotal']?.toDouble() ?? 0.0;

          // Update product sales
          if (productSales.containsKey(productId)) {
            final existing = productSales[productId]!;
            productSales[productId] = TopSellingProduct(
              productId: productId,
              productName: productName,
              productSku: existing.productSku,
              quantitySold: (existing.quantitySold + quantity).toInt(),
              totalRevenue: existing.totalRevenue + subtotal,
              profitMargin: existing.profitMargin,
            );
          } else {
            productSales[productId] = TopSellingProduct(
              productId: productId,
              productName: productName,
              productSku: item['productSku']?.toString() ?? '',
              quantitySold: quantity,
              totalRevenue: subtotal,
              profitMargin: 0.0, // Would need cost data
            );
          }

          // TODO: Process categories - need category data
        }

        // Add to sales trends (daily)
        final existingTrend = salesTrends.firstWhere(
              (trend) => trend.date.day == orderDate.day &&
              trend.date.month == orderDate.month &&
              trend.date.year == orderDate.year,
          orElse: () => SalesTrend(
            date: DateTime(orderDate.year, orderDate.month, orderDate.day),
            salesAmount: 0.0,
            transactionCount: 0,
          ),
        );

        final trendIndex = salesTrends.indexOf(existingTrend);
        if (trendIndex != -1) {
          salesTrends[trendIndex] = SalesTrend(
            date: existingTrend.date,
            salesAmount: existingTrend.salesAmount + orderTotal,
            transactionCount: existingTrend.transactionCount + 1,
          );
        } else {
          salesTrends.add(SalesTrend(
            date: DateTime(orderDate.year, orderDate.month, orderDate.day),
            salesAmount: orderTotal,
            transactionCount: 1,
          ));
        }
      }

      // Convert maps to lists
      final topProductsList = productSales.values.toList()
        ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold))
        ..take(10);

      // Convert sales by hour/day to models
      final salesByHourList = salesByHour.asMap().entries.map((entry) =>
          SalesByHour(
            hour: entry.key,
            totalSales: entry.value,
            numberOfTransactions: 0, // Would need to track this separately
          )).toList();

      final salesByDayList = salesByDay.asMap().entries.map((entry) {
        final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        return SalesByDay(
          dayName: dayNames[entry.key],
          dayIndex: entry.key,
          totalSales: entry.value,
          numberOfTransactions: 0,
        );
      }).toList();

      debugPrint('Local report generation took ${stopwatch.elapsedMilliseconds}ms');

      return SalesReport(
        id: 'report_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Sales Report ${query.startDate.month}/${query.startDate.year}',
        generatedAt: DateTime.now(),
        query: query,
        data: {
          'processedLocally': true,
          'processingTimeMs': stopwatch.elapsedMilliseconds,
        },
        totalSales: totalSales,
        averageSaleValue: transactionCount > 0 ? totalSales / transactionCount : 0.0,
        numberOfTransactions: transactionCount,
        salesByCategory: salesByCategory.values.toList(),
        salesByHour: salesByHourList,
        salesByDay: salesByDayList,
        topProducts: topProductsList,
        salesTrends: salesTrends,
      );
    } catch (e) {
      debugPrint('Error in local report generation: $e');
      return SalesReport.empty;
    }
  }

  /// Static method for isolate calculations
  static PerformanceMetrics _calculateMetricsInIsolate(
      List<Map<String, dynamic>> orders,
      AnalyticsQuery query,
      ) {
    // Simplified calculation for isolate
    double totalRevenue = 0.0;
    int totalOrders = 0;

    for (final order in orders) {
      totalRevenue += order['total']?.toDouble() ?? 0.0;
      totalOrders++;
    }

    return PerformanceMetrics(
      totalRevenue: totalRevenue,
      averageOrderValue: totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
      totalOrders: totalOrders,
      uniqueCustomers: 0,
      conversionRate: 0.0,
      revenueGrowth: 0.0,
      itemsSold: 0,
      profitMargin: 0.0,
    );
  }

  /// Static method for isolate report generation
  static Map<String, dynamic> _generateReportInIsolate(
      List<Map<String, dynamic>> orders,
      List<Map<String, dynamic>> products,
      List<Map<String, dynamic>> customers,
      AnalyticsQuery query,
      ) {
    // Simplified report generation for isolate
    return {
      'type': 'sales',
      'totalRevenue': 0.0,
      'items': [],
    };
  }

  /// Generate cache key from query
  String _generateCacheKey(AnalyticsQuery query) {
    return '${query.startDate.toIso8601String()}_${query.endDate.toIso8601String()}_${query.reportType}';
  }

  /// Check if cache should be used
  bool _shouldUseCache(String cacheKey) {
    if (_lastCacheUpdate == null) return false;

    final cacheAge = DateTime.now().difference(_lastCacheUpdate!);
    return cacheAge < Duration(minutes: 5) && _metricsCache.containsKey(cacheKey);
  }

  /// Update cache with new data
  void _updateCache(String key, dynamic data) {
    if (data is PerformanceMetrics) {
      _metricsCache[key] = data;
    } else if (data is BaseReport) {
      _reportCache[key] = data;
    }
    _lastCacheUpdate = DateTime.now();
  }

  /// Clear cache
  void clearCache() {
    _metricsCache.clear();
    _reportCache.clear();
    _lastCacheUpdate = null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    clearCache();
    if (_isIsolateInitialized) {
      await _isolateHandler.dispose();
      _isIsolateInitialized = false;
    }
    debugPrint('Analytics service disposed');
  }
}