import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import '../../../../core/utils/isolate_handler.dart';
import '../../../../core/utils/logger.dart';
import '../models/analytics_models.dart';

/// Service for processing large datasets using isolates with smart strategies
class DataProcessor {
  static final DataProcessor _instance = DataProcessor._internal();
  factory DataProcessor() => _instance;
  DataProcessor._internal();

  final Logger _logger = Logger('DataProcessor');
  final IsolateHandler _isolateHandler = IsolateHandler();
  bool _isIsolateInitialized = false;

  // Cache for processed data
  final _dataCache = <String, Map<String, dynamic>>{};
  final _processingQueue = <String, Completer<Map<String, dynamic>>>{};
  final _lock = Lock();

  /// Initialize data processor with isolate
  Future<void> initialize() async {
    try {
      await _isolateHandler.initialize(_dataWorkerEntryPoint);
      _isIsolateInitialized = true;
      _logger.info('Data processor initialized with isolate support');
    } catch (e) {
      _logger.warning('Failed to initialize isolate, using main thread: $e');
    }
  }
  void _dataWorkerEntryPoint(SendPort mainSendPort) {
    final port = ReceivePort();
    mainSendPort.send(port.sendPort);

    port.listen((message) async {
      final Map<String, dynamic> data = message['data'];
      final SendPort replyTo = message['replyTo'];

      try {
        final result = await _dataWorker(data); // call your original async worker
        replyTo.send(result);
      } catch (e) {
        replyTo.send({'error': e.toString()});
      }
    });
  }

  /// Static worker function for isolate (must be top-level or static)
  static Future<Map<String, dynamic>> _dataWorker(Map<String, dynamic> data) async {
    try {
      final action = data['action'] as String;
      final payload = data['payload'] as Map<String, dynamic>;

      switch (action) {
        case 'aggregate_sales':
          return await _aggregateSalesInIsolate(payload);
        case 'process_large_dataset':
          return await _processLargeDatasetInIsolate(payload);
        case 'calculate_metrics':
          return await _calculateMetricsInIsolate(payload);
        default:
          return {'error': 'Unknown action: $action'};
      }
    } catch (e) {
      return {'error': 'Isolate worker error: $e'};
    }
  }

  /// Process data with smart strategy (isolate or main thread)
  Future<Map<String, dynamic>> processData({
    required String operation,
    required Map<String, dynamic> data,
    AnalyticsQuery? query,
  }) async {
    final cacheKey = _generateCacheKey(operation, data, query);

    // Check cache first
    final cachedResult = await _checkCache(cacheKey);
    if (cachedResult != null) {
      _logger.debug('Using cached result for $operation');
      return cachedResult;
    }

    // Check if already processing
    if (_processingQueue.containsKey(cacheKey)) {
      _logger.debug('Already processing $operation, waiting for result');
      return await _processingQueue[cacheKey]!.future;
    }

    final completer = Completer<Map<String, dynamic>>();
    _processingQueue[cacheKey] = completer;

    try {
      final result = await _processWithSmartStrategy(
        operation: operation,
        data: data,
        query: query,
        cacheKey: cacheKey,
      );

      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _processingQueue.remove(cacheKey);
    }
  }

  /// Process with smart strategy based on data size and complexity
  Future<Map<String, dynamic>> _processWithSmartStrategy({
    required String operation,
    required Map<String, dynamic> data,
    required String cacheKey,
    AnalyticsQuery? query,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Estimate data size
      final dataSize = _estimateDataSize(data);
      final isLargeDataset = dataSize > 5 * 1024 * 1024; // 5MB threshold

      Map<String, dynamic> result;

      if (isLargeDataset && _isIsolateInitialized) {
        _logger.debug('Processing large dataset ($dataSize bytes) in isolate');
        result = await _processInIsolate(operation, data);
      } else {
        _logger.debug('Processing dataset ($dataSize bytes) in main thread');
        result = await _processInMainThread(operation, data, query);
      }

      // Cache the result
      await _updateCache(cacheKey, result);

      _logger.debug(
        'Processing completed in ${stopwatch.elapsedMilliseconds}ms',
        extra: {
          'operation': operation,
          'dataSize': dataSize,
          'usedIsolate': isLargeDataset && _isIsolateInitialized,
        },
      );

      return result;
    } catch (e, stackTrace) {
      _logger.error(
        'Error in data processing',
        error: e,
        stackTrace: stackTrace,
        extra: {'operation': operation, 'dataSize': _estimateDataSize(data)},
      );

      // Return fallback result
      return _getFallbackResult(operation);
    }
  }

  /// Estimate data size in bytes
  int _estimateDataSize(Map<String, dynamic> data) {
    try {
      final jsonString = json.encode(data);
      return utf8.encode(jsonString).length;
    } catch (e) {
      return 0;
    }
  }

  /// Process in isolate
  Future<Map<String, dynamic>> _processInIsolate(
      String operation,
      Map<String, dynamic> data,
      ) async {
    try {
      final result = await _isolateHandler.sendMessage({
        'action': operation,
        'payload': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (result.containsKey('error')) {
        throw Exception('Isolate error: ${result['error']}');
      }

      return result;
    } catch (e) {
      _logger.warning('Isolate processing failed, falling back to main thread: $e');
      return await _processInMainThread(operation, data, null);
    }
  }

  /// Process in main thread
  Future<Map<String, dynamic>> _processInMainThread(
      String operation,
      Map<String, dynamic> data,
      AnalyticsQuery? query,
      ) async {
    switch (operation) {
      case 'aggregate_sales':
        return await _aggregateSales(data);
      case 'calculate_metrics':
        return await _calculateMetrics(data, query);
      case 'process_large_dataset':
        return await _processLargeDataset(data);
      default:
        throw Exception('Unknown operation: $operation');
    }
  }

  /// Aggregate sales data
  Future<Map<String, dynamic>> _aggregateSales(Map<String, dynamic> data) async {
    final orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
    final products = List<Map<String, dynamic>>.from(data['products'] ?? []);

    if (orders.isEmpty) {
      return {
        'totalSales': 0.0,
        'transactionCount': 0,
        'averageOrderValue': 0.0,
        'byCategory': [],
        'byHour': List.filled(24, 0.0),
        'byDay': List.filled(7, 0.0),
      };
    }

    // Create product lookup for efficient category access
    final productMap = <String, Map<String, dynamic>>{};
    for (final product in products) {
      final id = product['id']?.toString();
      if (id != null) {
        productMap[id] = product;
      }
    }

    // Initialize aggregates
    double totalSales = 0.0;
    int transactionCount = 0;
    final categorySales = <String, double>{};
    final hourSales = List<double>.filled(24, 0.0);
    final daySales = List<double>.filled(7, 0.0);

    // Process orders
    for (final order in orders) {
      final orderTotal = order['total']?.toDouble() ?? 0.0;
      final orderDate = DateTime.parse(order['dateCreated']);
      final lineItems = order['line_items'] as List<dynamic>? ?? [];

      totalSales += orderTotal;
      transactionCount++;

      // Aggregate by hour
      final hour = orderDate.hour;
      hourSales[hour] += orderTotal;

      // Aggregate by day (0 = Sunday)
      final day = orderDate.weekday % 7;
      daySales[day] += orderTotal;

      // Aggregate by category through line items
      for (final item in lineItems) {
        final productId = item['productId']?.toString();
        if (productId != null) {
          final product = productMap[productId];
          final category = product?['categoryId']?.toString() ?? 'uncategorized';
          final itemTotal = item['subtotal']?.toDouble() ?? 0.0;

          categorySales[category] = (categorySales[category] ?? 0.0) + itemTotal;
        }
      }
    }

    // Convert category sales to list format
    final categoryList = categorySales.entries.map((entry) {
      final categoryId = entry.key;
      final categoryName = _getCategoryName(categoryId, products);
      final percentage = totalSales > 0 ? (entry.value / totalSales * 100) : 0.0;

      return {
        'categoryId': categoryId,
        'categoryName': categoryName,
        'totalSales': entry.value,
        'percentage': percentage,
      };
    }).toList();

    // Sort categories by sales (descending)
    categoryList.sort((a, b) => (b['totalSales'] as double).compareTo(a['totalSales'] as double));

    return {
      'totalSales': totalSales,
      'transactionCount': transactionCount,
      'averageOrderValue': transactionCount > 0 ? totalSales / transactionCount : 0.0,
      'byCategory': categoryList,
      'byHour': hourSales,
      'byDay': daySales,
      'processingTime': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Calculate various metrics
  Future<Map<String, dynamic>> _calculateMetrics(
      Map<String, dynamic> data,
      AnalyticsQuery? query,
      ) async {
    final orders = List<Map<String, dynamic>>.from(data['orders'] ?? []);
    final products = List<Map<String, dynamic>>.from(data['products'] ?? []);
    final customers = List<Map<String, dynamic>>.from(data['customers'] ?? []);

    if (orders.isEmpty) {
      return _getEmptyMetrics();
    }

    // Calculate basic metrics
    final basicMetrics = await _calculateBasicMetrics(orders);

    // Calculate customer metrics
    final customerMetrics = await _calculateCustomerMetrics(orders, customers);

    // Calculate product metrics
    final productMetrics = await _calculateProductMetrics(orders, products);

    // Calculate time-based metrics
    final timeMetrics = await _calculateTimeMetrics(orders, query);

    return {
      ...basicMetrics,
      ...customerMetrics,
      ...productMetrics,
      ...timeMetrics,
      'processedAt': DateTime.now().toIso8601String(),
      'dataPoints': orders.length,
    };
  }

  /// Calculate basic sales metrics
  Future<Map<String, dynamic>> _calculateBasicMetrics(
      List<Map<String, dynamic>> orders,
      ) async {
    double totalRevenue = 0.0;
    int totalOrders = 0;
    int totalItems = 0;
    final paymentMethods = <String, int>{};
    final orderValues = <double>[];

    for (final order in orders) {
      final orderTotal = order['total']?.toDouble() ?? 0.0;
      final paymentMethod = order['paymentMethod']?.toString() ?? 'unknown';
      final lineItems = order['line_items'] as List<dynamic>? ?? [];

      totalRevenue += orderTotal;
      totalOrders++;
      orderValues.add(orderTotal);

      // Count payment methods
      paymentMethods[paymentMethod] = (paymentMethods[paymentMethod] ?? 0) + 1;

      // Count items

      for (final item in lineItems) {
        final quantity = item['quantity'];
        totalItems += (quantity is num ? quantity.toInt() : 0);
      }
    }

    // Calculate statistical metrics
    orderValues.sort();
    final medianOrderValue = _calculateMedian(orderValues);
    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    // Calculate standard deviation
    final variance = orderValues.fold(0.0, (sum, value) {
      final diff = value - avgOrderValue;
      return sum + diff * diff;
    }) / orderValues.length;
    final stdDev = sqrt(variance);

    return {
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
      'totalItems': totalItems,
      'averageOrderValue': avgOrderValue,
      'medianOrderValue': medianOrderValue,
      'orderValueStdDev': stdDev,
      'paymentMethodDistribution': paymentMethods,
      'minOrderValue': orderValues.isNotEmpty ? orderValues.first : 0.0,
      'maxOrderValue': orderValues.isNotEmpty ? orderValues.last : 0.0,
    };
  }

  /// Calculate customer-related metrics
  Future<Map<String, dynamic>> _calculateCustomerMetrics(
      List<Map<String, dynamic>> orders,
      List<Map<String, dynamic>> customers,
      ) async {
    final customerOrders = <String, List<double>>{};
    final customerLastSeen = <String, DateTime>{};

    for (final order in orders) {
      final customerId = order['customerId']?.toString();
      if (customerId != null && customerId.isNotEmpty) {
        final orderTotal = order['total']?.toDouble() ?? 0.0;
        final orderDate = DateTime.parse(order['dateCreated']);

        customerOrders.putIfAbsent(customerId, () => []).add(orderTotal);

        // Update last seen date
        final currentLastSeen = customerLastSeen[customerId];
        if (currentLastSeen == null || orderDate.isAfter(currentLastSeen)) {
          customerLastSeen[customerId] = orderDate;
        }
      }
    }

    final uniqueCustomers = customerOrders.keys.length;
    final repeatCustomers = customerOrders.values.where((orders) => orders.length > 1).length;

    // Calculate average orders per customer
    final totalOrdersFromCustomers = customerOrders.values.fold(
        0, (sum, orders) => sum + orders.length);
    final avgOrdersPerCustomer = uniqueCustomers > 0
        ? totalOrdersFromCustomers / uniqueCustomers
        : 0.0;

    // Calculate customer lifetime value
    double totalCustomerValue = 0.0;
    for (final orders in customerOrders.values) {
      totalCustomerValue += orders.reduce((a, b) => a + b);
    }
    final avgCustomerLifetimeValue = uniqueCustomers > 0
        ? totalCustomerValue / uniqueCustomers
        : 0.0;

    return {
      'uniqueCustomers': uniqueCustomers,
      'repeatCustomers': repeatCustomers,
      'newCustomers': uniqueCustomers - repeatCustomers,
      'repeatPurchaseRate': uniqueCustomers > 0 ? repeatCustomers / uniqueCustomers * 100 : 0.0,
      'avgOrdersPerCustomer': avgOrdersPerCustomer,
      'avgCustomerLifetimeValue': avgCustomerLifetimeValue,
      'customerRetentionRate': 0.0, // Would need historical data
    };
  }

  /// Calculate product-related metrics
  Future<Map<String, dynamic>> _calculateProductMetrics(
      List<Map<String, dynamic>> orders,
      List<Map<String, dynamic>> products,
      ) async {
    final productSales = <String, Map<String, dynamic>>{};
    final categorySales = <String, double>{};

    for (final order in orders) {
      final lineItems = order['line_items'] as List<dynamic>? ?? [];
      for (final item in lineItems) {
        final productId = item['productId']?.toString();
        if (productId == null) continue;

        final product = products.firstWhere(
              (p) => p['id'] == productId,
          orElse: () => {},
        );

        final categoryId = product['categoryId']?.toString() ?? 'uncategorized';
        final quantity = item['quantity']?.toInt() ?? 0;
        final revenue = item['subtotal']?.toDouble() ?? 0.0;

        // Update product sales
        if (!productSales.containsKey(productId)) {
          productSales[productId] = {
            'productId': productId,
            'productName': product['name'] ?? 'Unknown',
            'quantitySold': 0,
            'revenue': 0.0,
            'categoryId': categoryId,
          };
        }

        final salesData = productSales[productId]!;
        salesData['quantitySold'] = (salesData['quantitySold'] as int) + quantity;
        salesData['revenue'] = (salesData['revenue'] as double) + revenue;

        // Update category sales
        categorySales[categoryId] = (categorySales[categoryId] ?? 0.0) + revenue;
      }
    }

    // Calculate top products
    final productList = productSales.values.toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    final topProducts = productList.take(10).toList();

    // Calculate category distribution
    final totalCategorySales = categorySales.values.fold(0.0, (a, b) => a + b);
    final categoryDistribution = categorySales.entries.map((entry) {
      final percentage = totalCategorySales > 0
          ? (entry.value / totalCategorySales * 100)
          : 0.0;

      return {
        'categoryId': entry.key,
        'totalSales': entry.value,
        'percentage': percentage,
      };
    }).toList()
      ..sort((a, b) => (b['totalSales'] as double).compareTo(a['totalSales'] as double));

    return {
      'totalProductsSold': productSales.length,
      'topProducts': topProducts,
      'categoryDistribution': categoryDistribution,
      'productSales': productList,
    };
  }

  /// Calculate time-based metrics
  Future<Map<String, dynamic>> _calculateTimeMetrics(
      List<Map<String, dynamic>> orders,
      AnalyticsQuery? query,
      ) async {
    if (orders.isEmpty || query == null) {
      return {
        'salesTrend': [],
        'peakHours': [],
        'busiestDays': [],
      };
    }

    // Group orders by date
    final dailySales = <DateTime, Map<String, dynamic>>{};
    final hourlySales = List<double>.filled(24, 0.0);
    final dailyCounts = List<int>.filled(7, 0);

    // Initialize date range
    var currentDate = query.startDate;
    while (currentDate.isBefore(query.endDate) ||
        currentDate.isAtSameMomentAs(query.endDate)) {
      final dateKey = DateTime(currentDate.year, currentDate.month, currentDate.day);
      dailySales[dateKey] = {
        'date': dateKey,
        'sales': 0.0,
        'orders': 0,
      };
      currentDate = currentDate.add(Duration(days: 1));
    }

    // Aggregate sales by time
    for (final order in orders) {
      final orderDate = DateTime.parse(order['dateCreated']);
      final dateKey = DateTime(orderDate.year, orderDate.month, orderDate.day);
      final orderTotal = order['total']?.toDouble() ?? 0.0;

      // Daily sales
      if (dailySales.containsKey(dateKey)) {
        final dailyData = dailySales[dateKey]!;
        dailyData['sales'] = (dailyData['sales'] as double) + orderTotal;
        dailyData['orders'] = (dailyData['orders'] as int) + 1;
      }

      // Hourly sales
      final hour = orderDate.hour;
      hourlySales[hour] += orderTotal;

      // Daily counts (by day of week)
      final dayOfWeek = orderDate.weekday % 7;
      dailyCounts[dayOfWeek]++;
    }

    // Convert to trend data
    final salesTrend = dailySales.values
        .map((data) => {
      'date': (data['date'] as DateTime).toIso8601String(),
      'sales': data['sales'],
      'orders': data['orders'],
    })
        .toList()
      ..sort((a, b) => a['date'].compareTo(b['date']));

    // Find peak hours
    final peakHours = hourlySales.asMap().entries.map((entry) {
      return {
        'hour': entry.key,
        'sales': entry.value,
      };
    }).toList()
      ..sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));

    // Find busiest days
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final busiestDays = dailyCounts.asMap().entries.map((entry) {
      return {
        'day': dayNames[entry.key],
        'dayIndex': entry.key,
        'orders': entry.value,
      };
    }).toList()
      ..sort((a, b) => (b['orders'] as int).compareTo(a['orders'] as int));

    return {
      'salesTrend': salesTrend,
      'peakHours': peakHours.take(5).toList(),
      'busiestDays': busiestDays.take(3).toList(),
      'hourlyDistribution': hourlySales,
      'dailyDistribution': dailyCounts,
    };
  }

  /// Process large dataset with optimization
  Future<Map<String, dynamic>> _processLargeDataset(Map<String, dynamic> data) async {
    // This is a simplified implementation
    // In production, implement chunked processing and streaming

    final dataset = List<Map<String, dynamic>>.from(data['dataset'] ?? []);
    final operation = data['operation'] as String? ?? 'analyze';

    if (dataset.isEmpty) {
      return {'error': 'Empty dataset', 'operation': operation};
    }

    // Process in chunks to avoid memory issues
    const chunkSize = 1000;
    final chunks = <List<Map<String, dynamic>>>[];

    for (var i = 0; i < dataset.length; i += chunkSize) {
      final end = i + chunkSize < dataset.length ? i + chunkSize : dataset.length;
      chunks.add(dataset.sublist(i, end));
    }

    final results = <Map<String, dynamic>>[];
    for (final chunk in chunks) {
      final result = await _processChunk(chunk, operation);
      results.add(result);
    }

    // Merge results
    return _mergeChunkResults(results, operation);
  }

  /// Process a chunk of data
  Future<Map<String, dynamic>> _processChunk(
      List<Map<String, dynamic>> chunk,
      String operation,
      ) async {
    // Implement chunk-specific processing logic
    switch (operation) {
      case 'sum':
        final sum = chunk.fold(0.0, (total, item) {
          final value = item['value']?.toDouble() ?? 0.0;
          return total + value;
        });
        return {'sum': sum, 'count': chunk.length};

      case 'average':
        final sum = chunk.fold(0.0, (total, item) {
          final value = item['value']?.toDouble() ?? 0.0;
          return total + value;
        });
        return {'sum': sum, 'count': chunk.length, 'average': sum / chunk.length};

      default:
        return {'count': chunk.length, 'processed': true};
    }
  }

  /// Merge results from chunked processing
  Map<String, dynamic> _mergeChunkResults(
      List<Map<String, dynamic>> results,
      String operation,
      ) {
    switch (operation) {
      case 'sum':
        final totalSum = results.fold(0.0, (sum, result) => sum + (result['sum'] ?? 0.0));
        final totalCount = results.fold<int>(
          0,
              (count, result) => count + ((result['count'] as num?)?.toInt() ?? 0),
        );
        return {
          'totalSum': totalSum,
          'totalCount': totalCount,
          'chunksProcessed': results.length,
        };

      case 'average':
        final totalSum = results.fold(0.0, (sum, result) => sum + (result['sum'] ?? 0.0));
        final totalCount = results.fold<int>(
          0,
              (count, result) => count + ((result['count'] as num?)?.toInt() ?? 0),
        );
        final average = totalCount > 0 ? totalSum / totalCount : 0.0;
        return {
          'totalSum': totalSum,
          'totalCount': totalCount,
          'average': average,
          'chunksProcessed': results.length,
        };

      default:
        final totalCount = results.fold<int>(
          0,
              (count, result) => count + ((result['count'] as num?)?.toInt() ?? 0),
        );
        return {
          'totalCount': totalCount,
          'chunksProcessed': results.length,
          'operation': operation,
        };
    }
  }

  /// Static method for isolate sales aggregation
  static Future<Map<String, dynamic>> _aggregateSalesInIsolate(
      Map<String, dynamic> payload) async {
    // Simplified implementation for isolate
    final orders = List<Map<String, dynamic>>.from(payload['orders'] ?? []);

    double totalSales = 0.0;
    for (final order in orders) {
      totalSales += order['total']?.toDouble() ?? 0.0;
    }

    return {
      'totalSales': totalSales,
      'transactionCount': orders.length,
      'processedInIsolate': true,
    };
  }

  /// Static method for isolate metrics calculation
  static Future<Map<String, dynamic>> _calculateMetricsInIsolate(
      Map<String, dynamic> payload) async {
    // Simplified implementation for isolate
    final orders = List<Map<String, dynamic>>.from(payload['orders'] ?? []);

    return {
      'totalRevenue': orders.fold(0.0, (sum, order) => sum + (order['total']?.toDouble() ?? 0.0)),
      'totalOrders': orders.length,
      'processedInIsolate': true,
    };
  }

  /// Static method for isolate large dataset processing
  static Future<Map<String, dynamic>> _processLargeDatasetInIsolate(
      Map<String, dynamic> payload) async {
    // Simplified implementation for isolate
    final dataset = List<Map<String, dynamic>>.from(payload['dataset'] ?? []);

    return {
      'processedItems': dataset.length,
      'processedInIsolate': true,
    };
  }

  /// Helper method to get category name
  String _getCategoryName(String categoryId, List<Map<String, dynamic>> products) {
    if (categoryId == 'uncategorized') return 'Uncategorized';

    // Find category in products
    for (final product in products) {
      if (product['categoryId'] == categoryId) {
        return product['categoryName']?.toString() ?? 'Unknown Category';
      }
    }

    return 'Unknown Category';
  }

  /// Calculate median value
  double _calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;

    values.sort();
    final middle = values.length ~/ 2;

    if (values.length % 2 == 1) {
      return values[middle];
    } else {
      return (values[middle - 1] + values[middle]) / 2.0;
    }
  }

  /// Generate cache key
  String _generateCacheKey(
      String operation,
      Map<String, dynamic> data,
      AnalyticsQuery? query,
      ) {
    final dataHash = _generateDataHash(data);
    final queryHash = query?.toJson() ?? '';
    return '${operation}_${dataHash}_$queryHash';
  }

  /// Generate hash for data
  String _generateDataHash(Map<String, dynamic> data) {
    try {
      final jsonString = json.encode(data);
      return _hashString(jsonString);
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Simple string hash
  String _hashString(String input) {
    var hash = 0;
    for (var i = 0; i < input.length; i++) {
      final char = input.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return hash.toString();
  }

  /// Check cache for result
  Future<Map<String, dynamic>?> _checkCache(String key) async {
    Map<String, dynamic>? result;

    await _lock.synchronized(() async {
      final cached = _dataCache[key];
      if (cached != null) {
        final cachedAt = DateTime.parse(cached['cachedAt']);
        final cacheAge = DateTime.now().difference(cachedAt);
        if (cacheAge < Duration(minutes: 10)) {
          result = cached['result'] as Map<String, dynamic>?;
        } else {
          _dataCache.remove(key);
        }
      }

      return; // explicitly return void
    });

    return result;
  }

  /// Update cache with new result
  Future<void> _updateCache(String key, Map<String, dynamic> result) async {
    await _lock.synchronized(() async {
      _dataCache[key] = {
        'result': result,
        'cachedAt': DateTime.now().toIso8601String(),
      };

      // Limit cache size
      if (_dataCache.length > 100) {
        final oldestKey = _dataCache.keys.first;
        _dataCache.remove(oldestKey);
      }

      return; // explicitly return void
    });
  }

  /// Get fallback result for error scenarios
  Map<String, dynamic> _getFallbackResult(String operation) {
    switch (operation) {
      case 'aggregate_sales':
        return {
          'totalSales': 0.0,
          'transactionCount': 0,
          'averageOrderValue': 0.0,
          'error': 'Processing failed, using fallback',
        };
      case 'calculate_metrics':
        return _getEmptyMetrics();
      default:
        return {'error': 'Processing failed for operation: $operation'};
    }
  }

  /// Get empty metrics structure
  Map<String, dynamic> _getEmptyMetrics() {
    return {
      'totalRevenue': 0.0,
      'totalOrders': 0,
      'totalItems': 0,
      'averageOrderValue': 0.0,
      'uniqueCustomers': 0,
      'error': 'No data available',
      'processedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Clear cache
  void clearCache() {
    _dataCache.clear();
    _logger.info('Data processor cache cleared');
  }

  /// Dispose resources
  Future<void> dispose() async {
    clearCache();
    if (_isIsolateInitialized) {
      await _isolateHandler.dispose();
      _isIsolateInitialized = false;
    }
    _logger.info('Data processor disposed');
  }
}

/// Simple lock implementation for synchronization
class Lock {
  Future<void> _lock = Future.value();
  Future<void> get lock => _lock;

  Future<void> synchronized(Future<void> Function() callback) async {
    final previous = _lock;
    final completer = Completer<void>();
    _lock = completer.future;

    await previous;
    try {
      await callback();
    } finally {
      completer.complete();
    }
  }
}