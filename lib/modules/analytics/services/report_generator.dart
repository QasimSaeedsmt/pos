import 'package:intl/intl.dart';

import '../models/analytics_models.dart';
import '../models/report_models.dart';
import '../../../../core/utils/logger.dart';

/// Service for generating various types of reports with optimization
class ReportGenerator {
  static final ReportGenerator _instance = ReportGenerator._internal();
  factory ReportGenerator() => _instance;
  ReportGenerator._internal();

  final Logger _logger = Logger('ReportGenerator');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');

  /// Generate comprehensive sales report
  Future<SalesReport> generateSalesReport({
    required AnalyticsQuery query,
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> customers,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info('Generating sales report for ${orders.length} orders');

      // Validate input data
      if (orders.isEmpty) {
        _logger.warning('No orders found for the specified period');
        return SalesReport.empty;
      }

      // Pre-process data for efficiency
      final processedData = await _preprocessSalesData(
        orders,
        products,
        customers,
      );

      // Calculate metrics in parallel where possible
      final metricsFutures = [
        _calculateTotalSales(processedData['orders']),
        _calculateSalesByCategory(processedData['orders'], processedData['products']),
        _calculateSalesByTime(processedData['orders']),
        _calculateTopProducts(processedData['orders'], processedData['products']),
        _calculateSalesTrends(processedData['orders'], query.startDate, query.endDate),
      ];

      final results = (await Future.wait(metricsFutures)) as List<Map<String, dynamic>>;

      // Compile the report
      final report = SalesReport(
        id: 'sales_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Sales Report ${_formatDateRange(query)}',
        generatedAt: DateTime.now(),
        query: query,
        data: {
          'processingTime': stopwatch.elapsedMilliseconds,
          'dataPoints': orders.length,
          'generatedBy': 'ReportGenerator',
        },
        totalSales: results[0] as double,
        averageSaleValue: _calculateAverageSaleValue(orders),
        numberOfTransactions: orders.length,
        salesByCategory: results[1] as List<SalesByCategory>,
        salesByHour: results[2]['byHour'] as List<SalesByHour>,
        salesByDay: results[2]['byDay'] as List<SalesByDay>,
        topProducts: results[3] as List<TopSellingProduct>,
        salesTrends: results[4] as List<SalesTrend>,
      );

      _logger.info(
        'Sales report generated in ${stopwatch.elapsedMilliseconds}ms',
        extra: {
          'orders': orders.length,
          'totalSales': report.totalSales,
          'transactions': report.numberOfTransactions,
        },
      );

      return report;
    } catch (e, stackTrace) {
      _logger.error(
        'Error generating sales report',
        error: e,
        stackTrace: stackTrace,
        extra: {'query': query.toMap()},
      );
      return SalesReport.empty;
    }
  }

  /// Pre-process data for efficient calculations
  Future<Map<String, dynamic>> _preprocessSalesData(
      List<Map<String, dynamic>> orders,
      List<Map<String, dynamic>> products,
      List<Map<String, dynamic>> customers,
      ) async {
    final stopwatch = Stopwatch()..start();

    // Create product lookup map for O(1) access
    final productMap = <String, Map<String, dynamic>>{};
    for (final product in products) {
      final id = product['id']?.toString();
      if (id != null) {
        productMap[id] = product;
      }
    }

    // Create customer lookup map
    final customerMap = <String, Map<String, dynamic>>{};
    for (final customer in customers) {
      final id = customer['id']?.toString();
      if (id != null) {
        customerMap[id] = customer;
      }
    }

    // Process orders to extract relevant data
    final processedOrders = <Map<String, dynamic>>[];
    for (final order in orders) {
      try {
        final processedOrder = _processOrder(order, productMap, customerMap);
        processedOrders.add(processedOrder);
      } catch (e) {
        _logger.warning('Error processing order: $e', extra: {'orderId': order['id']});
      }
    }

    _logger.debug(
      'Data preprocessed in ${stopwatch.elapsedMilliseconds}ms',
      extra: {
        'orders': processedOrders.length,
        'products': productMap.length,
        'customers': customerMap.length,
      },
    );

    return {
      'orders': processedOrders,
      'products': productMap,
      'customers': customerMap,
    };
  }

  /// Process individual order data
  Map<String, dynamic> _processOrder(
      Map<String, dynamic> order,
      Map<String, dynamic> productMap,
      Map<String, dynamic> customerMap,
      ) {
    final lineItems = order['line_items'] as List<dynamic>? ?? [];
    final processedItems = <Map<String, dynamic>>[];

    double orderTotal = 0.0;
    int itemCount = 0;

    for (final item in lineItems) {
      try {
        final productId = item['productId']?.toString();
        if (productId == null) continue;

        final product = productMap[productId];
        final quantity = ((item['quantity'] as num?)?.toInt()) ?? 0;
        final price = item['price']?.toDouble() ?? 0.0;
        final subtotal = item['subtotal']?.toDouble() ?? (quantity * price);

        final processedItem = {
          'productId': productId,
          'productName': product?['name'] ?? item['productName'] ?? 'Unknown',
          'sku': product?['sku'] ?? '',
          'categoryId': product?['categoryId']?.toString() ?? '',
          'categoryName': product?['categoryName']?.toString() ?? 'Uncategorized',
          'quantity': quantity,
          'price': price,
          'subtotal': subtotal,
          'cost': product?['cost']?.toDouble() ?? 0.0,
        };

        processedItems.add(processedItem);
        orderTotal += subtotal;
        itemCount += quantity;
      } catch (e) {
        _logger.warning('Error processing line item: $e');
      }
    }

    // Get customer info
    final customerId = order['customerId']?.toString();
    Map<String, dynamic>? customerInfo;
    if (customerId != null && customerMap.containsKey(customerId)) {
      customerInfo = customerMap[customerId];
    }

    return {
      'id': order['id'],
      'date': DateTime.parse(order['dateCreated']),
      'total': orderTotal,
      'itemCount': itemCount,
      'customerId': customerId,
      'customerName': customerInfo?['fullName'] ?? 'Walk-in',
      'paymentMethod': order['paymentMethod'] ?? 'cash',
      'items': processedItems,
      'rawData': order, // Keep raw data for reference
    };
  }

  /// Calculate total sales
  Future<double> _calculateTotalSales(List<Map<String, dynamic>> orders) async {
    double total = 0.0;

    for (final order in orders) {
      final value = order['total'];
      if (value is num) {
        total += value.toDouble(); // convert int or double to double
      }
    }

    return total;
  }

  /// Calculate sales by category
  Future<List<SalesByCategory>> _calculateSalesByCategory(
      List<Map<String, dynamic>> orders,
      Map<String, dynamic> productMap,
      ) async {
    final categorySales = <String, Map<String, dynamic>>{};
    double totalSales = 0.0;

    for (final order in orders) {
      final items = order['items'] as List<Map<String, dynamic>>;
      for (final item in items) {
        final categoryId = item['categoryId']?.toString() ?? 'uncategorized';
        final categoryName = item['categoryName'] ?? 'Uncategorized';
        final subtotal = item['subtotal'] as double;
        final quantity = item['quantity'] as int;

        totalSales += subtotal;

        if (!categorySales.containsKey(categoryId)) {
          categorySales[categoryId] = {
            'categoryId': categoryId,
            'categoryName': categoryName,
            'totalSales': 0.0,
            'itemsSold': 0,
          };
        }

        final category = categorySales[categoryId]!;
        category['totalSales'] = (category['totalSales'] as double) + subtotal;
        category['itemsSold'] = (category['itemsSold'] as int) + quantity;
      }
    }

    // Convert to SalesByCategory objects with percentages
    return categorySales.values.map((data) {
      final percentage = totalSales > 0
          ? (data['totalSales'] as double) / totalSales * 100
          : 0.0;

      return SalesByCategory(
        categoryId: data['categoryId'],
        categoryName: data['categoryName'],
        totalSales: data['totalSales'],
        itemsSold: data['itemsSold'],
        percentageOfTotal: percentage,
      );
    }).toList();
  }

  /// Calculate sales by time (hour and day)
  Future<Map<String, dynamic>> _calculateSalesByTime(
      List<Map<String, dynamic>> orders,
      ) async {
    final salesByHour = List<double>.filled(24, 0.0);
    final transactionsByHour = List<int>.filled(24, 0);
    final salesByDay = List<double>.filled(7, 0.0);
    final transactionsByDay = List<int>.filled(7, 0);

    for (final order in orders) {
      final date = order['date'] as DateTime;
      final total = order['total'] as double;

      // By hour
      final hour = date.hour;
      salesByHour[hour] += total;
      transactionsByHour[hour]++;

      // By day (0 = Sunday)
      final day = date.weekday % 7;
      salesByDay[day] += total;
      transactionsByDay[day]++;
    }

    // Convert to model objects
    final hourModels = List<SalesByHour>.generate(24, (hour) {
      return SalesByHour(
        hour: hour,
        totalSales: salesByHour[hour],
        numberOfTransactions: transactionsByHour[hour],
      );
    });

    final dayModels = List<SalesByDay>.generate(7, (dayIndex) {
      final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return SalesByDay(
        dayName: dayNames[dayIndex],
        dayIndex: dayIndex,
        totalSales: salesByDay[dayIndex],
        numberOfTransactions: transactionsByDay[dayIndex],
      );
    });

    return {
      'byHour': hourModels,
      'byDay': dayModels,
    };
  }

  /// Calculate top selling products
  Future<List<TopSellingProduct>> _calculateTopProducts(
      List<Map<String, dynamic>> orders,
      Map<String, dynamic> productMap,
      ) async {
    final productSales = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      final items = order['items'] as List<Map<String, dynamic>>;
      for (final item in items) {
        final productId = item['productId'];
        final productName = item['productName'];
        final sku = item['sku'];
        final quantity = item['quantity'] as int;
        final revenue = item['subtotal'] as double;
        final cost = item['cost'] as double;

        if (!productSales.containsKey(productId)) {
          productSales[productId] = {
            'productId': productId,
            'productName': productName,
            'sku': sku,
            'quantitySold': 0,
            'totalRevenue': 0.0,
            'totalCost': 0.0,
          };
        }

        final product = productSales[productId]!;
        product['quantitySold'] = (product['quantitySold'] as int) + quantity;
        product['totalRevenue'] = (product['totalRevenue'] as double) + revenue;
        product['totalCost'] = (product['totalCost'] as double) + (cost * quantity);
      }
    }

    // Convert to TopSellingProduct objects
    final products = productSales.values.map((data) {
      final revenue = data['totalRevenue'] as double;
      final cost = data['totalCost'] as double;
      final profitMargin = revenue > 0 ? (revenue - cost) / revenue * 100 : 0.0;

      return TopSellingProduct(
        productId: data['productId'],
        productName: data['productName'],
        productSku: data['sku'],
        quantitySold: data['quantitySold'],
        totalRevenue: revenue,
        profitMargin: profitMargin,
      );
    }).toList();

    // Sort by quantity sold and take top 10
    products.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
    return products.take(10).toList();
  }

  /// Calculate sales trends over time
  Future<List<SalesTrend>> _calculateSalesTrends(
      List<Map<String, dynamic>> orders,
      DateTime startDate,
      DateTime endDate,
      ) async {
    final trends = <DateTime, Map<String, dynamic>>{};

    // Initialize all dates in range
    var currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      final dateKey = DateTime(currentDate.year, currentDate.month, currentDate.day);
      trends[dateKey] = {
        'date': dateKey,
        'salesAmount': 0.0,
        'transactionCount': 0,
      };
      currentDate = currentDate.add(Duration(days: 1));
    }

    // Aggregate sales by date
    for (final order in orders) {
      final orderDate = order['date'] as DateTime;
      final dateKey = DateTime(orderDate.year, orderDate.month, orderDate.day);
      final total = order['total'] as double;

      if (trends.containsKey(dateKey)) {
        final trend = trends[dateKey]!;
        trend['salesAmount'] = (trend['salesAmount'] as double) + total;
        trend['transactionCount'] = (trend['transactionCount'] as int) + 1;
      }
    }

    // Convert to SalesTrend objects and sort by date
    return trends.values
        .map((data) => SalesTrend(
      date: data['date'],
      salesAmount: data['salesAmount'],
      transactionCount: data['transactionCount'],
    ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Calculate average sale value
  double _calculateAverageSaleValue(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) return 0.0;
    final total = orders.fold(0.0, (sum, order) => sum + (order['total'] as double));
    return total / orders.length;
  }

  /// Format date range for report title
  String _formatDateRange(AnalyticsQuery query) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return '${dateFormat.format(query.startDate)} - ${dateFormat.format(query.endDate)}';
  }

  /// Generate inventory report
  Future<InventoryReport> generateInventoryReport({
    required AnalyticsQuery query,
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> salesData,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info('Generating inventory report for ${products.length} products');

      if (products.isEmpty) {
        return InventoryReport.empty;
      }

      // Calculate inventory metrics
      final inventoryValue = _calculateInventoryValue(products);
      final lowStockItems = _countLowStockItems(products);
      final outOfStockItems = _countOutOfStockItems(products);

      // Identify slow/fast moving items
      final movementAnalysis = await _analyzeInventoryMovement(
        products,
        salesData,
        query.startDate,
        query.endDate,
      );

      // Calculate turnover rate
      final turnoverRate = _calculateTurnoverRate(
        inventoryValue,
        movementAnalysis['totalCostOfGoodsSold'] ?? 0.0,
      );

      final report = InventoryReport(
        id: 'inventory_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Inventory Report ${_formatDateRange(query)}',
        generatedAt: DateTime.now(),
        query: query,
        data: {
          'processingTime': stopwatch.elapsedMilliseconds,
          'totalProducts': products.length,
        },
        totalInventoryValue: inventoryValue,
        lowStockItems: lowStockItems,
        outOfStockItems: outOfStockItems,
        slowMovingItems: movementAnalysis['slowMoving'] ?? [],
        fastMovingItems: movementAnalysis['fastMoving'] ?? [],
        inventoryTurnoverRate: turnoverRate,
      );

      _logger.info(
        'Inventory report generated in ${stopwatch.elapsedMilliseconds}ms',
        extra: {
          'products': products.length,
          'inventoryValue': inventoryValue,
          'lowStock': lowStockItems,
        },
      );

      return report;
    } catch (e, stackTrace) {
      _logger.error(
        'Error generating inventory report',
        error: e,
        stackTrace: stackTrace,
      );
      return InventoryReport.empty;
    }
  }

  /// Calculate total inventory value
  double _calculateInventoryValue(List<Map<String, dynamic>> products) {
    return products.fold(0.0, (sum, product) {
      final stock = product['stockQuantity']?.toInt() ?? 0;
      final cost = product['cost']?.toDouble() ?? 0.0;
      return sum + (stock * cost);
    });
  }

  /// Count low stock items
  int _countLowStockItems(List<Map<String, dynamic>> products) {
    return products.where((product) {
      final stock = product['stockQuantity']?.toInt() ?? 0;
      final minStock = product['minStockLevel']?.toInt() ?? 0;
      return stock > 0 && stock <= minStock;
    }).length;
  }

  /// Count out of stock items
  int _countOutOfStockItems(List<Map<String, dynamic>> products) {
    return products.where((product) {
      final stock = product['stockQuantity']?.toInt() ?? 0;
      return stock == 0;
    }).length;
  }

  /// Analyze inventory movement
  Future<Map<String, dynamic>> _analyzeInventoryMovement(
      List<Map<String, dynamic>> products,
      List<Map<String, dynamic>> salesData,
      DateTime startDate,
      DateTime endDate,
      ) async {
    final productSales = <String, Map<String, dynamic>>{};

    // Aggregate sales by product
    for (final order in salesData) {
      final items = order['items'] as List<Map<String, dynamic>>? ?? [];
      for (final item in items) {
        final productId = item['productId']?.toString();
        if (productId == null) continue;

        final quantity = item['quantity']?.toInt() ?? 0;
        final revenue = item['subtotal']?.toDouble() ?? 0.0;
        final cost = item['cost']?.toDouble() ?? 0.0;

        if (!productSales.containsKey(productId)) {
          productSales[productId] = {
            'quantitySold': 0,
            'revenue': 0.0,
            'cost': 0.0,
            'product': products.firstWhere(
                  (p) => p['id'] == productId,
              orElse: () => {},
            ),
          };
        }

        final sales = productSales[productId]!;
        sales['quantitySold'] = (sales['quantitySold'] as int) + quantity;
        sales['revenue'] = (sales['revenue'] as double) + revenue;
        sales['cost'] = (sales['cost'] as double) + (cost * quantity);
      }
    }

    // Calculate days in stock and categorize
    final daysInPeriod = endDate.difference(startDate).inDays;
    final slowMoving = <InventoryItem>[];
    final fastMoving = <InventoryItem>[];
    double totalCostOfGoodsSold = 0.0;

    for (final product in products) {
      final productId = product['id']?.toString();
      final sales = productSales[productId] ?? {};

      final currentStock = product['stockQuantity']?.toInt() ?? 0;
      final quantitySold = sales['quantitySold'] as int? ?? 0;
      final avgDailySales = daysInPeriod > 0 ? quantitySold / daysInPeriod : 0;

      // Calculate days in stock
      final daysInStock = avgDailySales > 0
          ? currentStock / avgDailySales
          : (currentStock > 0 ? double.infinity : 0);

      // Calculate stock value
      final unitCost = product['cost']?.toDouble() ?? 0.0;
      final stockValue = currentStock * unitCost;

      final inventoryItem = InventoryItem(
        productId: productId ?? '',
        productName: product['name'] ?? 'Unknown',
        sku: product['sku'] ?? '',
        currentStock: currentStock,
        minStockLevel: product['minStockLevel']?.toInt() ?? 0,
        maxStockLevel: product['maxStockLevel']?.toInt() ?? 0,
        unitCost: unitCost,
        retailPrice: product['price']?.toDouble() ?? 0.0,
        daysInStock: daysInStock.toInt(),
        stockValue: stockValue,
      );

      totalCostOfGoodsSold += (sales['cost'] as double? ?? 0.0);

      // Categorize as slow or fast moving
      if (avgDailySales > 0 && daysInStock > 30) {
        slowMoving.add(inventoryItem);
      } else if (avgDailySales > 5) {
        fastMoving.add(inventoryItem);
      }
    }

    return {
      'slowMoving': slowMoving,
      'fastMoving': fastMoving,
      'totalCostOfGoodsSold': totalCostOfGoodsSold,
    };
  }

  /// Calculate inventory turnover rate
  double _calculateTurnoverRate(double avgInventoryValue, double costOfGoodsSold) {
    return avgInventoryValue > 0 ? costOfGoodsSold / avgInventoryValue : 0.0;
  }

  /// Generate customer analytics report
  Future<Map<String, dynamic>> generateCustomerAnalytics({
    required AnalyticsQuery query,
    required List<Map<String, dynamic>> customers,
    required List<Map<String, dynamic>> orders,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info('Generating customer analytics for ${customers.length} customers');

      // Segment customers
      final segments = _segmentCustomers(customers, orders);

      // Calculate customer metrics
      final metrics = _calculateCustomerMetrics(customers, orders);

      // Identify top customers
      final topCustomers = _identifyTopCustomers(customers, orders);

      // Calculate retention metrics
      final retention = _calculateRetentionMetrics(customers, orders, query);

      final report = {
        'id': 'customer_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Customer Analytics ${_formatDateRange(query)}',
        'generatedAt': DateTime.now(),
        'query': query.toMap(),
        'processingTime': stopwatch.elapsedMilliseconds,
        'segments': segments,
        'metrics': metrics,
        'topCustomers': topCustomers,
        'retention': retention,
      };

      _logger.info(
        'Customer analytics generated in ${stopwatch.elapsedMilliseconds}ms',
        extra: {
          'customers': customers.length,
          'segments': segments.length,
          'topCustomers': topCustomers.length,
        },
      );

      return report;
    } catch (e, stackTrace) {
      _logger.error(
        'Error generating customer analytics',
        error: e,
        stackTrace: stackTrace,
      );
      return {'error': e.toString()};
    }
  }

  /// Segment customers based on behavior
  Map<String, dynamic> _segmentCustomers(
      List<Map<String, dynamic>> customers,
      List<Map<String, dynamic>> orders,
      ) {
    // Group orders by customer
    final customerOrders = <String, List<Map<String, dynamic>>>{};
    for (final order in orders) {
      final customerId = order['customerId']?.toString();
      if (customerId != null) {
        customerOrders.putIfAbsent(customerId, () => []).add(order);
      }
    }

    final segments = {
      'highValue': <Map<String, dynamic>>[],
      'mediumValue': <Map<String, dynamic>>[],
      'lowValue': <Map<String, dynamic>>[],
      'inactive': <Map<String, dynamic>>[],
    };

    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));

    for (final customer in customers) {
      final customerId = customer['id']?.toString();
      final orders = customerOrders[customerId] ?? [];

      // Calculate customer metrics
      double totalSpent = 0.0;
      int orderCount = 0;
      DateTime? lastOrderDate;

      for (final order in orders) {
        totalSpent += order['total']?.toDouble() ?? 0.0;
        orderCount++;

        final orderDate = DateTime.parse(order['dateCreated']);
        if (lastOrderDate == null || orderDate.isAfter(lastOrderDate)) {
          lastOrderDate = orderDate;
        }
      }

      // Determine segment
      final isInactive = lastOrderDate == null ||
          lastOrderDate.isBefore(thirtyDaysAgo);

      if (isInactive) {
        segments['inactive']!.add({
          'customer': customer,
          'totalSpent': totalSpent,
          'orderCount': orderCount,
          'lastOrder': lastOrderDate,
        });
      } else if (totalSpent > 1000) {
        segments['highValue']!.add({
          'customer': customer,
          'totalSpent': totalSpent,
          'orderCount': orderCount,
          'lastOrder': lastOrderDate,
        });
      } else if (totalSpent > 100) {
        segments['mediumValue']!.add({
          'customer': customer,
          'totalSpent': totalSpent,
          'orderCount': orderCount,
          'lastOrder': lastOrderDate,
        });
      } else {
        segments['lowValue']!.add({
          'customer': customer,
          'totalSpent': totalSpent,
          'orderCount': orderCount,
          'lastOrder': lastOrderDate,
        });
      }
    }

    return segments;
  }

  /// Calculate customer metrics
  Map<String, dynamic> _calculateCustomerMetrics(
      List<Map<String, dynamic>> customers,
      List<Map<String, dynamic>> orders,
      ) {
    if (customers.isEmpty) {
      return {
        'totalCustomers': 0,
        'activeCustomers': 0,
        'avgOrderValue': 0.0,
        'avgOrdersPerCustomer': 0.0,
        'customerLifetimeValue': 0.0,
      };
    }

    // Group orders by customer
    final customerOrderCount = <String, int>{};
    final customerSpending = <String, double>{};

    for (final order in orders) {
      final customerId = order['customerId']?.toString();
      if (customerId != null) {
        customerOrderCount[customerId] =
            (customerOrderCount[customerId] ?? 0) + 1;
        customerSpending[customerId] =
            (customerSpending[customerId] ?? 0.0) + (order['total']?.toDouble() ?? 0.0);
      }
    }

    final activeCustomers = customerOrderCount.keys.length;
    final totalOrders = orders.length;
    final totalRevenue = orders.fold(
        0.0, (sum, order) => sum + (order['total']?.toDouble() ?? 0.0));

    final avgOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    final avgOrdersPerCustomer = activeCustomers > 0 ? totalOrders / activeCustomers : 0.0;

    // Calculate average customer lifetime value
    double totalLifetimeValue = 0.0;
    for (final spending in customerSpending.values) {
      totalLifetimeValue += spending;
    }
    final customerLifetimeValue = activeCustomers > 0
        ? totalLifetimeValue / activeCustomers
        : 0.0;

    return {
      'totalCustomers': customers.length,
      'activeCustomers': activeCustomers,
      'inactiveCustomers': customers.length - activeCustomers,
      'avgOrderValue': avgOrderValue,
      'avgOrdersPerCustomer': avgOrdersPerCustomer,
      'customerLifetimeValue': customerLifetimeValue,
      'totalRevenue': totalRevenue,
      'totalOrders': totalOrders,
    };
  }

  /// Identify top customers
  List<Map<String, dynamic>> _identifyTopCustomers(
      List<Map<String, dynamic>> customers,
      List<Map<String, dynamic>> orders,
      ) {
    final customerSpending = <String, Map<String, dynamic>>{};

    // Calculate spending per customer
    for (final order in orders) {
      final customerId = order['customerId']?.toString();
      if (customerId != null) {
        final customer = customers.firstWhere(
              (c) => c['id'] == customerId,
          orElse: () => {},
        );

        if (!customerSpending.containsKey(customerId)) {
          customerSpending[customerId] = {
            'customer': customer,
            'totalSpent': 0.0,
            'orderCount': 0,
            'lastOrderDate': null,
          };
        }

        final data = customerSpending[customerId]!;
        data['totalSpent'] = (data['totalSpent'] as double) +
            (order['total']?.toDouble() ?? 0.0);
        data['orderCount'] = (data['orderCount'] as int) + 1;

        final orderDate = DateTime.parse(order['dateCreated']);
        if (data['lastOrderDate'] == null ||
            orderDate.isAfter(data['lastOrderDate'] as DateTime)) {
          data['lastOrderDate'] = orderDate;
        }
      }
    }

    // Sort by total spent and take top 20
    final sortedCustomers = customerSpending.values.toList()
      ..sort((a, b) => (b['totalSpent'] as double).compareTo(a['totalSpent'] as double));

    return sortedCustomers.take(20).toList();
  }

  /// Calculate customer retention metrics
  Map<String, dynamic> _calculateRetentionMetrics(
      List<Map<String, dynamic>> customers,
      List<Map<String, dynamic>> orders,
      AnalyticsQuery query,
      ) {
    // This is a simplified retention calculation
    // In production, you'd want more sophisticated cohort analysis

    final periodStart = query.startDate;
    final periodEnd = query.endDate;

    // Find customers who made purchases before the period
    final previousCustomers = <String>{};
    // Find customers who made purchases during the period
    final currentCustomers = <String>{};

    for (final order in orders) {
      final customerId = order['customerId']?.toString();
      if (customerId == null) continue;

      final orderDate = DateTime.parse(order['dateCreated']);
      if (orderDate.isBefore(periodStart)) {
        previousCustomers.add(customerId);
      } else if (!orderDate.isBefore(periodStart) && !orderDate.isAfter(periodEnd)) {
        currentCustomers.add(customerId);
      }
    }

    // Calculate retention rate
    final retainedCustomers = currentCustomers.where((id) => previousCustomers.contains(id)).length;
    final retentionRate = previousCustomers.isNotEmpty
        ? retainedCustomers / previousCustomers.length * 100
        : 0.0;

    // Calculate churn rate
    final churnRate = 100 - retentionRate;

    // Calculate new customer acquisition
    final newCustomers = currentCustomers.where((id) => !previousCustomers.contains(id)).length;

    return {
      'previousCustomers': previousCustomers.length,
      'currentCustomers': currentCustomers.length,
      'retainedCustomers': retainedCustomers,
      'newCustomers': newCustomers,
      'retentionRate': retentionRate,
      'churnRate': churnRate,
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
    };
  }
}