// dashboard_repository.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/product_model.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/app_order_model.dart';
import '../../core/models/return_request.dart';
import '../connectivityBase/local_db_base.dart';
import 'dashboard_models.dart';

class DashboardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  final LocalDatabase _localDb = LocalDatabase();

  static const String _dashboardBox = 'dashboard_cache_box';
  static const String _dashboardCacheKey = 'dashboard_cache_data';
  static const int _cacheDurationHours = 1;

  DashboardRepository() {
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    if (!Hive.isAdapterRegistered(50)) {
      Hive.registerAdapter(DashboardCacheAdapter());
    }
    if (!Hive.isAdapterRegistered(51)) {
      Hive.registerAdapter(DashboardStatsAdapter());
    }
    if (!Hive.isAdapterRegistered(52)) {
      Hive.registerAdapter(RevenueDataPointAdapter());
    }
    if (!Hive.isAdapterRegistered(53)) {
      Hive.registerAdapter(ProductPerformanceAdapter());
    }

    if (!Hive.isBoxOpen(_dashboardBox)) {
      await Hive.openBox<DashboardCache>(_dashboardBox);
    }
  }

  // ========== OFFLINE-FIRST DASHBOARD LOADING ==========
  Future<DashboardCache> loadDashboardData(String tenantId) async {
    try {
      // Check connectivity[citation:1][citation:3][citation:7]
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      // 1. Always try to load from cache first (offline-first approach)[citation:7]
      final cachedData = await _loadCachedData(tenantId);

      if (cachedData != null && !_isCacheExpired(cachedData.lastUpdated)) {
        debugPrint('✅ Loading dashboard from cache');
        return cachedData;
      }

      // 2. If online, fetch fresh data and update cache[citation:1][citation:5]
      if (isOnline) {
        debugPrint('🔄 Fetching fresh dashboard data from Firestore');
        try {
          final freshData = await _fetchFreshData(tenantId);
          await _saveToCache(freshData);
          return freshData;
        } catch (e) {
          debugPrint('❌ Online fetch failed: $e');
          // Fallback to cache even if expired
          if (cachedData != null) {
            debugPrint('⚠️ Using expired cache as fallback');
            return cachedData;
          }
        }
      }

      // 3. If offline and no cache, generate from local data
      if (cachedData == null) {
        debugPrint('📱 Generating dashboard from local data');
        return await _generateFromLocalData(tenantId);
      }

      return cachedData;
    } catch (e) {
      debugPrint('❌ Error loading dashboard: $e');
      // Ultimate fallback
      return await _createEmptyDashboard(tenantId);
    }
  }

  // ========== CACHE MANAGEMENT ==========
  Future<DashboardCache?> _loadCachedData(String tenantId) async {
    try {
      final box = Hive.box<DashboardCache>(_dashboardBox);
      final cacheKey = '${tenantId}_$_dashboardCacheKey';
      final cached = box.get(cacheKey);

      if (cached != null && cached.tenantId == tenantId) {
        return cached;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading cache: $e');
      return null;
    }
  }

  Future<void> _saveToCache(DashboardCache data) async {
    try {
      final box = Hive.box<DashboardCache>(_dashboardBox);
      final cacheKey = '${data.tenantId}_$_dashboardCacheKey';
      await box.put(cacheKey, data);
      debugPrint('💾 Saved dashboard to cache');
    } catch (e) {
      debugPrint('Error saving to cache: $e');
    }
  }

  bool _isCacheExpired(DateTime lastUpdated) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    return difference.inHours >= _cacheDurationHours;
  }

  // ========== FRESH DATA FETCHING ==========
  Future<DashboardCache> _fetchFreshData(String tenantId) async {
    debugPrint('🔄 Starting fresh data fetch for tenant: $tenantId');

    // Parallel fetching for performance[citation:1]
    final futures = [
      _fetchDashboardStats(tenantId),
      _fetchRevenueData(tenantId),
      _fetchProductPerformance(tenantId),
    ];

    final results = await Future.wait(futures);

    return DashboardCache(
      tenantId: tenantId,
      stats: results[0] as DashboardStats,
      revenueData: results[1] as List<RevenueDataPoint>,
      productPerformance: results[2] as List<ProductPerformance>,
      lastUpdated: DateTime.now(),
      cacheKey: '${tenantId}_$_dashboardCacheKey',
    );
  }

  Future<DashboardStats> _fetchDashboardStats(String tenantId) async {
    try {
      // Wrap in try-catch to suppress all Firestore errors
      return await _fetchDashboardStatsInternal(tenantId);
    } catch (e) {
      // COMPLETELY SUPPRESS FIRESTORE ERRORS
      debugPrint('📱 Dashboard stats fetch failed (offline?): $e');
      // Return empty stats instead of throwing
      return DashboardStats.empty();
    }
  }
  Future<DashboardStats> _fetchDashboardStatsInternal(String tenantId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = todayEnd.subtract(const Duration(days: 1));

    try {
      // ================= HELPER =================
      Future<QuerySnapshot<Map<String, dynamic>>> emptySnapshot(
          Query<Map<String, dynamic>> query,
          ) async {
        return query.limit(0).get();
      }

      // ================= SNAPSHOTS =================
      QuerySnapshot<Map<String, dynamic>> todayOrdersSnapshot;
      QuerySnapshot<Map<String, dynamic>> yesterdayOrdersSnapshot;
      QuerySnapshot<Map<String, dynamic>> allOrdersSnapshot;
      QuerySnapshot<Map<String, dynamic>> productsSnapshot;
      QuerySnapshot<Map<String, dynamic>> customersSnapshot;
      QuerySnapshot<Map<String, dynamic>> todayReturnsSnapshot;
      QuerySnapshot<Map<String, dynamic>> allReturnsSnapshot;
      QuerySnapshot<Map<String, dynamic>> lowStockProductsSnapshot;

      // ================= QUERIES =================
      try {
        todayOrdersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .where('dateCreated',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('dateCreated',
            isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
            .get();
      } catch (e) {
        todayOrdersSnapshot = await emptySnapshot(
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('orders'),
        );
        debugPrint('⚠️ Today orders query failed: $e');
      }

      try {
        yesterdayOrdersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .where('dateCreated',
            isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart))
            .where('dateCreated',
            isLessThanOrEqualTo: Timestamp.fromDate(yesterdayEnd))
            .get();
      } catch (e) {
        yesterdayOrdersSnapshot = await emptySnapshot(
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('orders'),
        );
        debugPrint('⚠️ Yesterday orders query failed: $e');
      }

      try {
        allOrdersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .get();
      } catch (e) {
        allOrdersSnapshot = await emptySnapshot(
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('orders'),
        );
        debugPrint('⚠️ All orders query failed: $e');
      }

      try {
        productsSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .where('status', isEqualTo: 'publish')
            .get();
      } catch (e) {
        productsSnapshot = await emptySnapshot(
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('products'),
        );
        debugPrint('⚠️ Products query failed: $e');
      }

      try {
        customersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('customers')
            .get();
      } catch (e) {
        customersSnapshot = await emptySnapshot(
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('customers'),
        );
        debugPrint('⚠️ Customers query failed: $e');
      }

      try {
        todayReturnsSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('returns')
            .where('dateCreated',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .get();
      } catch (e) {
        todayReturnsSnapshot = await emptySnapshot(
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('returns'),
        );
        debugPrint('⚠️ Today returns query failed: $e');
      }

      try {
        allReturnsSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('returns')
            .get();
      } catch (e) {
        allReturnsSnapshot = await emptySnapshot(
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('returns'),
        );
        debugPrint('⚠️ All returns query failed: $e');
      }

      try {
        lowStockProductsSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .where('status', isEqualTo: 'publish')
            .where('stockQuantity', isLessThanOrEqualTo: 10)
            .get();
      } catch (e) {
        lowStockProductsSnapshot = await emptySnapshot(
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('products'),
        );
        debugPrint('⚠️ Low stock products query failed: $e');
      }

      // ================= CALCULATIONS =================

      double todayRevenue = 0.0;
      final todayCustomerIds = <String>{};

      for (final order in todayOrdersSnapshot.docs) {
        final data = order.data();
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ??
            0.0;
        todayRevenue += total;

        final customerId = data['customerId']?.toString();
        if (customerId != null && customerId.isNotEmpty && customerId != 'null') {
          todayCustomerIds.add(customerId);
        }
      }

      double yesterdayRevenue = 0.0;
      for (final order in yesterdayOrdersSnapshot.docs) {
        final data = order.data();
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ??
            0.0;
        yesterdayRevenue += total;
      }

      double totalRevenue = 0.0;
      for (final order in allOrdersSnapshot.docs) {
        final data = order.data();
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ??
            0.0;
        totalRevenue += total;
      }

      double inventoryValue = 0.0;
      final lowStockProductsCount = lowStockProductsSnapshot.docs.length;

      for (final product in productsSnapshot.docs) {
        final data = product.data();
        final stockQuantity =
            _safeGetInt(data, 'stockQuantity') ?? _safeGetInt(data, 'stock') ?? 0;
        final price = _safeGetDouble(data, 'price') ?? 0.0;
        final purchasePrice =
            _safeGetDouble(data, 'purchasePrice') ?? (price * 0.7);

        inventoryValue += stockQuantity * purchasePrice;
      }

      final localDb = LocalDatabase();
      final pendingOrders = await localDb.getPendingOrders();
      final pendingReturns = await localDb.getPendingReturns();

      final averageOrderValue = allOrdersSnapshot.docs.isNotEmpty
          ? totalRevenue / allOrdersSnapshot.docs.length
          : 0.0;

      final conversionRate = customersSnapshot.docs.isNotEmpty
          ? (allOrdersSnapshot.docs.length /
          customersSnapshot.docs.length *
          100)
          .clamp(0.0, 100.0)
          : 0.0;

      double revenueGrowth = 0.0;
      if (yesterdayRevenue > 0) {
        revenueGrowth =
            ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100;
      } else if (todayRevenue > 0) {
        revenueGrowth = 100.0;
      }

      double salesGrowth = 0.0;
      final yesterdaySales = yesterdayOrdersSnapshot.docs.length;
      final todaySales = todayOrdersSnapshot.docs.length;

      if (yesterdaySales > 0) {
        salesGrowth =
            ((todaySales - yesterdaySales) / yesterdaySales.toDouble()) * 100;
      } else if (todaySales > 0) {
        salesGrowth = 100.0;
      }

      return DashboardStats(
        totalRevenue: totalRevenue,
        todayRevenue: todayRevenue,
        totalSales: allOrdersSnapshot.docs.length,
        todaySales: todayOrdersSnapshot.docs.length,
        totalProducts: productsSnapshot.docs.length,
        lowStockProducts: lowStockProductsCount,
        totalCustomers: customersSnapshot.docs.length,
        todayCustomers: todayCustomerIds.length,
        averageOrderValue: averageOrderValue,
        conversionRate: conversionRate,
        revenueGrowth: revenueGrowth,
        salesGrowth: salesGrowth,
        todayReturns: todayReturnsSnapshot.docs.length,
        totalReturns: allReturnsSnapshot.docs.length,
        inventoryValue: inventoryValue,
        pendingOrders: pendingOrders.length,
        pendingReturns: pendingReturns.length,
      );
    } catch (e) {
      debugPrint('❌ Internal stats calculation error: $e');
      return DashboardStats.empty();
    }
  }

// Helper to create empty snapshot when queries fail
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _createEmptyQuerySnapshot() {
    return const [];
  }

// Safe data extraction methods (complete implementation)
  double? _safeGetDouble(Map<String, dynamic> data, String key) {
    try {
      final value = data[key];
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  int? _safeGetInt(Map<String, dynamic> data, String key) {
    try {
      final value = data[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<List<RevenueDataPoint>> _fetchRevenueData(String tenantId) async {
    try {
      final now = DateTime.now();
      final List<RevenueDataPoint> revenueData = [];

      for (int i = 6; i >= 0; i--) {
        final date = DateTime(now.year, now.month, now.day - i);
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

        final ordersSnapshot = await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();

        double dayRevenue = 0;
        int dayOrders = 0;
        final dayCustomerIds = <String>{};

        for (final order in ordersSnapshot.docs) {
          final data = order.data() as Map<String, dynamic>;
          final total = (data['total'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ?? 0;
          dayRevenue += total;
          dayOrders++;

          final customerId = data['customerId']?.toString();
          if (customerId != null && customerId.isNotEmpty) {
            dayCustomerIds.add(customerId);
          }
        }

        final averageOrderValue = dayOrders > 0 ? dayRevenue / dayOrders : 0;

        revenueData.add(RevenueDataPoint(
          date: date,
          revenue: dayRevenue,
          orders: dayOrders,
          customers: dayCustomerIds.length,
          averageOrderValue: averageOrderValue.toDouble(),
        ));
      }

      return revenueData;
    } catch (e) {
      debugPrint('❌ Error fetching revenue data: $e');
      return List.generate(7, (index) {
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        return RevenueDataPoint.empty();
      });
    }
  }

  Future<List<ProductPerformance>> _fetchProductPerformance(String tenantId) async {
    try {
      // Get all products
      final productsSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('products')
          .where('status', isEqualTo: 'publish')
          .get();

      // Get recent orders to calculate sales
      final ordersSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .where('dateCreated', isGreaterThanOrEqualTo:
      Timestamp.fromDate(DateTime.now().subtract(Duration(days: 30))))
          .get();

      // Calculate product performance
      final productSales = <String, Map<String, dynamic>>{};

      for (final order in ordersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final lineItems = data['lineItems'] as List<dynamic>? ?? [];

        for (final item in lineItems) {
          final itemData = item as Map<String, dynamic>;
          final productId = itemData['productId']?.toString();

          if (productId != null) {
            if (!productSales.containsKey(productId)) {
              productSales[productId] = {
                'quantity': 0,
                'revenue': 0.0,
              };
            }

            final quantity = (itemData['quantity'] as num?)?.toInt() ?? 0;
            final price = (itemData['price'] as num?)?.toDouble() ?? 0;
            final subtotal = (itemData['subtotal'] as num?)?.toDouble() ??
                quantity * price;

            productSales[productId]!['quantity'] += quantity;
            productSales[productId]!['revenue'] += subtotal;
          }
        }
      }

      // Create performance list
      final performanceList = <ProductPerformance>[];

      for (final product in productsSnapshot.docs) {
        final data = product.data() as Map<String, dynamic>;
        final productId = product.id;
        final productName = data['name']?.toString() ?? 'Unknown';
        final sku = data['sku']?.toString() ?? '';
        final stockQuantity = (data['stockQuantity'] as num?)?.toInt() ?? 0;
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        final purchasePrice = (data['purchasePrice'] as num?)?.toDouble() ?? price * 0.7;

        final salesData = productSales[productId];
        final quantitySold = salesData?['quantity'] as int? ?? 0;
        final revenue = salesData?['revenue'] as double? ?? 0.0;

        final profitMargin = revenue > 0 ?
        ((revenue - (quantitySold * purchasePrice)) / revenue * 100) : 0;
        final stockValue = stockQuantity * purchasePrice;

        performanceList.add(ProductPerformance(
          productId: productId,
          productName: productName,
          sku: sku,
          quantitySold: quantitySold,
          revenue: revenue,
          profitMargin: profitMargin.toDouble(),
          stockQuantity: stockQuantity,
          stockValue: stockValue,
        ));
      }

      // Sort by revenue descending
      performanceList.sort((a, b) => b.revenue.compareTo(a.revenue));

      // Take top 10
      return performanceList.take(10).toList();
    } catch (e) {
      debugPrint('❌ Error fetching product performance: $e');
      return [];
    }
  }

  // ========== LOCAL DATA GENERATION (OFFLINE MODE) ==========
  Future<DashboardCache> _generateFromLocalData(String tenantId) async {
    try {
      debugPrint('📱 Generating dashboard from local data for offline mode');

      // Get data from local database
      final futures = await Future.wait([
        _localDb.getAllProducts(),
        _localDb.getCustomers(),
        _localDb.getPendingOrders(),
        _localDb.getPendingReturns(),
      ]);

      final products = futures[0] as List<Product>;
      final customers = futures[1] as List<Customer>;
      final pendingOrders = futures[2] as List<Map<String, dynamic>>;
      final pendingReturns = futures[3] as List<Map<String, dynamic>>;

      // Generate stats from local data
      final stats = await _generateLocalStats(
          products,
          customers,
          pendingOrders,
          pendingReturns
      );

      // Generate revenue data from local pending orders
      final revenueData = await _generateLocalRevenueData(pendingOrders);

      // Generate product performance from local products
      final productPerformance = await _generateLocalProductPerformance(
          products,
          pendingOrders
      );

      return DashboardCache(
        tenantId: tenantId,
        stats: stats,
        revenueData: revenueData,
        productPerformance: productPerformance,
        lastUpdated: DateTime.now(),
        cacheKey: '${tenantId}_$_dashboardCacheKey',
      );
    } catch (e) {
      debugPrint('❌ Error generating local dashboard: $e');
      return _createEmptyDashboard(tenantId);
    }
  }

  Future<DashboardStats> _generateLocalStats(
      List<Product> products,
      List<Customer> customers,
      List<Map<String, dynamic>> pendingOrders,
      List<Map<String, dynamic>> pendingReturns,
      ) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Calculate totals from pending orders
    double totalRevenue = 0;
    double todayRevenue = 0;
    int todaySales = 0;
    final todayCustomerIds = <String>{};

    for (final order in pendingOrders) {
      final orderData = order['order_data'] as Map<String, dynamic>;
      final total = (orderData['total'] as num?)?.toDouble() ?? 0;
      totalRevenue += total;

      final createdAt = DateTime.parse(order['created_at'] as String);
      if (createdAt.isAfter(todayStart)) {
        todayRevenue += total;
        todaySales++;

        final customerData = order['customer_data'] as Map<String, dynamic>?;
        if (customerData != null) {
          final customerId = customerData['customerId']?.toString();
          if (customerId != null) {
            todayCustomerIds.add(customerId);
          }
        }
      }
    }

    // Calculate inventory value
    double inventoryValue = 0;
    int lowStockProducts = 0;

    for (final product in products) {
      final stockValue = product.stockQuantity * (product.purchasePrice ?? product.price * 0.7);
      inventoryValue += stockValue;

      if (product.stockQuantity <= 10) {
        lowStockProducts++;
      }
    }

    return DashboardStats(
      totalRevenue: totalRevenue,
      todayRevenue: todayRevenue,
      totalSales: pendingOrders.length,
      todaySales: todaySales,
      totalProducts: products.length,
      lowStockProducts: lowStockProducts,
      totalCustomers: customers.length,
      todayCustomers: todayCustomerIds.length,
      averageOrderValue: pendingOrders.isNotEmpty ?
      totalRevenue / pendingOrders.length : 0,
      conversionRate: customers.isNotEmpty ?
      (pendingOrders.length / customers.length * 100).clamp(0.0, 100.0) : 0,
      revenueGrowth: 0,
      salesGrowth: 0,
      todayReturns: pendingReturns.where((returnReq) {
        final returnDate = DateTime.parse(returnReq['created_at'] as String);
        return returnDate.isAfter(todayStart);
      }).length,
      totalReturns: pendingReturns.length,
      inventoryValue: inventoryValue,
      pendingOrders: pendingOrders.length,
      pendingReturns: pendingReturns.length,
    );
  }

  Future<List<RevenueDataPoint>> _generateLocalRevenueData(
      List<Map<String, dynamic>> pendingOrders,
      ) async {
    final now = DateTime.now();
    final List<RevenueDataPoint> revenueData = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      double dayRevenue = 0;
      int dayOrders = 0;
      final dayCustomerIds = <String>{};

      for (final order in pendingOrders) {
        final orderDate = DateTime.parse(order['created_at'] as String);
        if (orderDate.year == date.year &&
            orderDate.month == date.month &&
            orderDate.day == date.day) {
          final orderData = order['order_data'] as Map<String, dynamic>;
          final total = (orderData['total'] as num?)?.toDouble() ?? 0;
          dayRevenue += total;
          dayOrders++;

          final customerData = order['customer_data'] as Map<String, dynamic>?;
          if (customerData != null) {
            final customerId = customerData['customerId']?.toString();
            if (customerId != null) {
              dayCustomerIds.add(customerId);
            }
          }
        }
      }

      final averageOrderValue = dayOrders > 0 ? dayRevenue / dayOrders : 0;

      revenueData.add(RevenueDataPoint(
        date: date,
        revenue: dayRevenue,
        orders: dayOrders,
        customers: dayCustomerIds.length,
        averageOrderValue: averageOrderValue.toDouble(),
      ));
    }

    return revenueData;
  }

  Future<List<ProductPerformance>> _generateLocalProductPerformance(
      List<Product> products,
      List<Map<String, dynamic>> pendingOrders,
      ) async {
    final productSales = <String, Map<String, dynamic>>{};

    // Calculate sales from pending orders
    for (final order in pendingOrders) {
      final orderData = order['order_data'] as Map<String, dynamic>;
      final lineItems = orderData['line_items'] as List<dynamic>? ?? [];

      for (final item in lineItems) {
        final productId = item['product_id']?.toString();
        if (productId != null) {
          if (!productSales.containsKey(productId)) {
            productSales[productId] = {
              'quantity': 0,
              'revenue': 0.0,
            };
          }

          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          final subtotal = (item['subtotal'] as num?)?.toDouble() ??
              (item['final_subtotal'] as num?)?.toDouble() ??
              quantity * price;

          productSales[productId]!['quantity'] += quantity;
          productSales[productId]!['revenue'] += subtotal;
        }
      }
    }

    // Create performance list
    final performanceList = <ProductPerformance>[];

    for (final product in products) {
      final salesData = productSales[product.id];
      final quantitySold = salesData?['quantity'] as int? ?? 0;
      final revenue = salesData?['revenue'] as double? ?? 0.0;
      final purchasePrice = product.purchasePrice ?? product.price * 0.7;

      final profitMargin = revenue > 0 ?
      ((revenue - (quantitySold * purchasePrice)) / revenue * 100) : 0;
      final stockValue = product.stockQuantity * purchasePrice;

      performanceList.add(ProductPerformance(
        productId: product.id,
        productName: product.name,
        sku: product.sku,
        quantitySold: quantitySold,
        revenue: revenue,
        profitMargin: profitMargin.toDouble(),
        stockQuantity: product.stockQuantity,
        stockValue: stockValue,
      ));
    }

    // Sort by revenue descending and take top 10
    performanceList.sort((a, b) => b.revenue.compareTo(a.revenue));
    return performanceList.take(10).toList();
  }

  Future<DashboardCache> _createEmptyDashboard(String tenantId) {
    return Future.value(DashboardCache(
      tenantId: tenantId,
      stats: DashboardStats.empty(),
      revenueData: List.generate(7, (index) {
        final date = DateTime.now().subtract(Duration(days: 6 - index));
        return RevenueDataPoint.empty();
      }),
      productPerformance: [],
      lastUpdated: DateTime.now(),
      cacheKey: '${tenantId}_$_dashboardCacheKey',
    ));
  }

  // ========== PUBLIC METHODS ==========
  Future<void> refreshDashboard(String tenantId) async {
    try {
      final freshData = await _fetchFreshData(tenantId);
      await _saveToCache(freshData);
      debugPrint('✅ Dashboard refreshed successfully');
    } catch (e) {
      debugPrint('❌ Error refreshing dashboard: $e');
      rethrow;
    }
  }

  Future<void> clearCache(String tenantId) async {
    try {
      final box = Hive.box<DashboardCache>(_dashboardBox);
      final cacheKey = '${tenantId}_$_dashboardCacheKey';
      await box.delete(cacheKey);
      debugPrint('🗑️ Dashboard cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  Future<void> close() async {
    try {
      if (Hive.isBoxOpen(_dashboardBox)) {
        await Hive.box<DashboardCache>(_dashboardBox).close();
      }
    } catch (e) {
      debugPrint('Error closing dashboard box: $e');
    }
  }
}