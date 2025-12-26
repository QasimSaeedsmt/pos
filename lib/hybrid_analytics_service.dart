// hybrid_analytics_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'analytics_screen.dart';
import 'analytics_hive_database.dart';
import '../core/models/app_order_model.dart';
import '../core/models/customer_model.dart';
import '../core/models/product_model.dart';
import '../core/models/category_model.dart';

class HybridAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveAnalyticsDatabase _hiveDb = HiveAnalyticsDatabase();
  final Connectivity _connectivity = Connectivity();
  String? _currentTenantId;

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
    _hiveDb.setTenantId(tenantId);
  }

  // Initialize database
  Future<void> initialize() async {
    await _hiveDb.initialize(tenantId: _currentTenantId);
  }

  // Check connectivity
  Future<bool> get isOnline async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Collection references
  CollectionReference get ordersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('orders');

  CollectionReference get customersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('customers');

  CollectionReference get productsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('products');

  CollectionReference get categoriesRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('categories');

  CollectionReference get expensesRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('expenses');

  // ========== DATA SYNC METHODS ==========
  Future<void> syncAllData() async {
    if (!await isOnline) return;

    try {
      debugPrint('🔄 Starting data sync for tenant: $_currentTenantId');

      // Sync in parallel for better performance
      await Future.wait([
        _syncOrders(),
        _syncCustomers(),
        _syncProducts(),
        _syncCategories(),
        _syncExpenses(),
        _syncPendingOperations(),
      ]);

      debugPrint('✅ Data sync completed successfully');
    } catch (e) {
      debugPrint('❌ Error during data sync: $e');
    }
  }

  Future<void> _syncOrders() async {
    try {
      final lastSync = await _hiveDb.getLastSync('orders');
      Query query = ordersRef.orderBy('dateCreated', descending: true).limit(1000);

      if (lastSync != null) {
        query = query.where('dateCreated', isGreaterThan: lastSync);
      }

      final snapshot = await query.get();
      final orders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppOrder.fromFirestore(data, doc.id);
      }).toList();

      await _hiveDb.saveOrders(orders);
      debugPrint('📊 Synced ${orders.length} orders');
    } catch (e) {
      debugPrint('❌ Error syncing orders: $e');
    }
  }

  Future<void> _syncCustomers() async {
    try {
      final snapshot = await customersRef.limit(1000).get();
      final customers = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Customer.fromFirestore(data, doc.id);
      }).toList();

      await _hiveDb.saveCustomers(customers);
      debugPrint('👥 Synced ${customers.length} customers');
    } catch (e) {
      debugPrint('❌ Error syncing customers: $e');
    }
  }

  Future<void> _syncProducts() async {
    try {
      final snapshot = await productsRef.where('status', isEqualTo: 'publish').limit(1000).get();
      final products = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromFirestore(data, doc.id);
      }).toList();

      await _hiveDb.saveProducts(products);
      debugPrint('📦 Synced ${products.length} products');
    } catch (e) {
      debugPrint('❌ Error syncing products: $e');
    }
  }

  Future<void> _syncCategories() async {
    try {
      final snapshot = await categoriesRef.orderBy('name').limit(100).get();
      final categories = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Category.fromFirestore(data, doc.id);
      }).toList();

      await _hiveDb.saveCategories(categories);
      debugPrint('🏷️ Synced ${categories.length} categories');
    } catch (e) {
      debugPrint('❌ Error syncing categories: $e');
    }
  }

  Future<void> _syncExpenses() async {
    try {
      final snapshot = await expensesRef.orderBy('date', descending: true).limit(1000).get();
      final expenses = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return BusinessExpense.fromFirestore(data, doc.id);
      }).toList();

      // Save expenses to local database
      for (var expense in expenses) {
        await _hiveDb.saveExpense(expense);
      }
      debugPrint('💰 Synced ${expenses.length} expenses');
    } catch (e) {
      debugPrint('❌ Error syncing expenses: $e');
    }
  }

  Future<void> _syncPendingOperations() async {
    try {
      final pendingSyncs = await _hiveDb.getPendingSyncs();

      for (var sync in pendingSyncs) {
        await _processPendingSync(sync);
      }

      debugPrint('🔄 Processed ${pendingSyncs.length} pending operations');
    } catch (e) {
      debugPrint('❌ Error syncing pending operations: $e');
    }
  }

  Future<void> _processPendingSync(Map<String, dynamic> syncData) async {
    try {
      final type = syncData['type'] as String;
      final data = syncData['data'];
      final syncKey = '${syncData['tenantId']}_${syncData['timestamp']}_$type';

      switch (type) {
        case 'add_expense':
          final expense = BusinessExpense.fromFirestore(data as Map<String, dynamic>, '');
          await expensesRef.doc(expense.id).set(expense.toFirestore());
          break;

        case 'delete_expense':
          await expensesRef.doc(data as String).delete();
          break;
      }

      // Remove from pending after successful sync
      await _hiveDb.removePendingSync(syncKey);
    } catch (e) {
      debugPrint('❌ Error processing pending sync: $e');
    }
  }

  // ========== EXPENSE MANAGEMENT ==========
  Future<void> addBusinessExpense(BusinessExpense expense) async {
    try {
      if (await isOnline) {
        // Add directly to Firestore
        await expensesRef.doc(expense.id).set(expense.toFirestore());
        debugPrint('✅ Expense added online: ${expense.description}');
      } else {
        // Save to pending sync
        await _hiveDb.addPendingSync('add_expense', expense.toFirestore());
        debugPrint('📝 Expense saved offline: ${expense.description}');
      }

      // Always save to local database for immediate access
      await _hiveDb.saveExpense(expense);

    } catch (e) {
      debugPrint('❌ Error adding expense: $e');
      throw Exception('Failed to add expense: $e');
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      if (await isOnline) {
        // Delete directly from Firestore
        await expensesRef.doc(expenseId).delete();
        debugPrint('✅ Expense deleted online: $expenseId');
      } else {
        // Save to pending sync
        await _hiveDb.addPendingSync('delete_expense', expenseId);
        debugPrint('📝 Expense deletion saved offline: $expenseId');
      }

      // Always delete from local database
      await _hiveDb.deleteExpense(expenseId);

    } catch (e) {
      debugPrint('❌ Error deleting expense: $e');
      throw Exception('Failed to delete expense: $e');
    }
  }

  Future<List<BusinessExpense>> getBusinessExpenses(TimePeriod period) async {
    try {
      // Try to get from cache first
      final cacheKey = 'expenses_${period.label}_${period.startDate}_${period.endDate}';
      final cached = await _hiveDb.getCachedAnalytics(cacheKey, 'expenses');

      if (cached != null && await isOnline) {
        // Return cached data if online (cache is fresh)
        final List<dynamic> cachedList = cached['data'];
        return cachedList.map((item) => BusinessExpense.fromFirestore(
            Map<String, dynamic>.from(item),
            item['id'] as String
        )).toList();
      }

      List<BusinessExpense> expenses;

      if (await isOnline) {
        // Get from Firestore
        final expensesSnapshot = await expensesRef
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(period.startDate))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(period.endDate))
            .orderBy('date', descending: true)
            .get();

        expenses = expensesSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return BusinessExpense.fromFirestore(data, doc.id);
        }).toList();

        // Save to cache
        final dataToCache = expenses.map((e) => e.toFirestore()).toList();
        await _hiveDb.cacheAnalytics(cacheKey, 'expenses', {
          'data': dataToCache,
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Also save to local database
        for (var expense in expenses) {
          await _hiveDb.saveExpense(expense);
        }

      } else {
        // Get from local database
        expenses = await _hiveDb.getExpenses(period.startDate, period.endDate);
        debugPrint('📱 Using offline expenses: ${expenses.length} records');
      }

      return expenses;

    } catch (e) {
      debugPrint('❌ Error getting expenses: $e');
      // Fallback to local database
      return await _hiveDb.getExpenses(period.startDate, period.endDate);
    }
  }

  // ========== ANALYTICS METHODS ==========
  Future<ProfitLossAnalytics> getProfitLossAnalytics(TimePeriod period) async {
    try {
      // Try to get from cache first
      final cacheKey = 'profitloss_${period.label}_${period.startDate}_${period.endDate}';
      final cached = await _hiveDb.getCachedAnalytics(cacheKey, 'profitloss');

      if (cached != null && await isOnline) {
        debugPrint('📊 Using cached profit/loss analytics');
        return _deserializeProfitLossAnalytics(cached);
      }

      // Get data based on connectivity
      final List<AppOrder> orders;

      if (await isOnline) {
        // Get from Firestore
        final ordersSnapshot = await ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
            .where('dateCreated', isLessThanOrEqualTo: period.endDate)
            .get();

        orders = ordersSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return AppOrder.fromFirestore(data, doc.id);
        }).toList();

        // Save orders to local database for offline access
        await _hiveDb.saveOrders(orders);

      } else {
        // Get from local database
        orders = await _hiveDb.getOrders(period.startDate, period.endDate);
        debugPrint('📱 Using offline orders for profit/loss: ${orders.length} orders');
      }

      // Get expenses
      final expenses = await getBusinessExpenses(period);

      // Calculate analytics
      final analytics = await _calculateProfitLossAnalytics(orders, expenses, period);

      // Cache the result if online
      if (await isOnline) {
        await _hiveDb.cacheAnalytics(cacheKey, 'profitloss', _serializeProfitLossAnalytics(analytics));
      }

      return analytics;

    } catch (e) {
      debugPrint('❌ Error in getProfitLossAnalytics: $e');
      // Return empty analytics in case of error
      return ProfitLossAnalytics(
        totalRevenue: 0.0,
        totalCostOfGoodsSold: 0.0,
        grossProfit: 0.0,
        grossProfitMargin: 0.0,
        operatingExpenses: 0.0,
        netProfit: 0.0,
        netProfitMargin: 0.0,
        topProfitableProducts: [],
        topProfitableCategories: [],
        profitByDay: {},
        profitByHour: {},
        businessExpenses: [],
        expensesByCategory: {},
        totalExpenses: 0.0,
      );
    }
  }

  Future<SalesAnalytics> getSalesAnalytics(TimePeriod period) async {
    try {
      // Try to get from cache
      final cacheKey = 'sales_${period.label}_${period.startDate}_${period.endDate}';
      final cached = await _hiveDb.getCachedAnalytics(cacheKey, 'sales');

      if (cached != null && await isOnline) {
        debugPrint('📊 Using cached sales analytics');
        return _deserializeSalesAnalytics(cached);
      }

      // Get orders
      final List<AppOrder> orders;

      if (await isOnline) {
        // Get from Firestore
        final ordersSnapshot = await ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
            .where('dateCreated', isLessThanOrEqualTo: period.endDate)
            .get();

        orders = ordersSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return AppOrder.fromFirestore(data, doc.id);
        }).toList();

        await _hiveDb.saveOrders(orders);

      } else {
        orders = await _hiveDb.getOrders(period.startDate, period.endDate);
        debugPrint('📱 Using offline orders for sales analytics: ${orders.length} orders');
      }

      // Calculate sales analytics
      final analytics = await _calculateSalesAnalytics(orders);

      // Cache if online
      if (await isOnline) {
        await _hiveDb.cacheAnalytics(cacheKey, 'sales', _serializeSalesAnalytics(analytics));
      }

      return analytics;

    } catch (e) {
      debugPrint('❌ Error in getSalesAnalytics: $e');
      return SalesAnalytics(
        totalSales: 0.0,
        totalOrders: 0,
        totalItemsSold: 0,
        averageOrderValue: 0.0,
        salesByHour: {},
        salesByDay: {},
        topProducts: [],
        topCategories: [],
        subtotalAmount: 0.0,
        totalDiscounts: 0.0,
        itemDiscounts: 0.0,
        cartDiscounts: 0.0,
        additionalDiscounts: 0.0,
        taxAmount: 0.0,
        shippingAmount: 0.0,
        tipAmount: 0.0,
        taxableAmount: 0.0,
        discountTypes: {},
        paymentMethodDistribution: {},
      );
    }
  }

  Future<CustomerAnalytics> getCustomerAnalytics(TimePeriod period) async {
    try {
      final cacheKey = 'customers_${period.label}_${period.startDate}_${period.endDate}';
      final cached = await _hiveDb.getCachedAnalytics(cacheKey, 'customers');

      if (cached != null && await isOnline) {
        debugPrint('📊 Using cached customer analytics');
        return _deserializeCustomerAnalytics(cached);
      }

      // Get customers and orders
      final List<Customer> customers;
      final List<AppOrder> orders;

      if (await isOnline) {
        // Get customers from Firestore
        final customersSnapshot = await customersRef.get();
        customers = customersSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Customer.fromFirestore(data, doc.id);
        }).toList();

        await _hiveDb.saveCustomers(customers);

        // Get orders from Firestore
        final ordersSnapshot = await ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
            .where('dateCreated', isLessThanOrEqualTo: period.endDate)
            .get();

        orders = ordersSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return AppOrder.fromFirestore(data, doc.id);
        }).toList();

        await _hiveDb.saveOrders(orders);

      } else {
        customers = await _hiveDb.getCustomers();
        orders = await _hiveDb.getOrders(period.startDate, period.endDate);
        debugPrint('📱 Using offline data: ${customers.length} customers, ${orders.length} orders');
      }

      // Calculate customer analytics
      final analytics = await _calculateCustomerAnalytics(customers, orders, period);

      // Cache if online
      if (await isOnline) {
        await _hiveDb.cacheAnalytics(cacheKey, 'customers', _serializeCustomerAnalytics(analytics));
      }

      return analytics;

    } catch (e) {
      debugPrint('❌ Error in getCustomerAnalytics: $e');
      return CustomerAnalytics(
        totalCustomers: 0,
        newCustomers: 0,
        averageOrderValue: 0.0,
        repeatCustomerRate: 0.0,
        customerGrowth: 0.0,
        customerSegmentation: [],
        topCustomers: [],
        acquisitionData: [],
        retentionMetrics: null,
        locationData: [],
      );
    }
  }

  // ========== CALCULATION METHODS ==========
  Future<ProfitLossAnalytics> _calculateProfitLossAnalytics(
      List<AppOrder> orders,
      List<BusinessExpense> expenses,
      TimePeriod period,
      ) async {
    // Your existing calculation logic from AnalyticsService
    // This is the same logic, just using local data

    double totalNetRevenue = 0.0;
    double totalCostOfGoodsSold = 0.0;

    for (final order in orders) {
      totalNetRevenue += order.total;

      // Calculate COGS
      for (final item in order.lineItems) {
        final itemMap = item as Map<String, dynamic>;
        final productId = itemMap['productId']?.toString() ??
            itemMap['product_id']?.toString() ?? 'unknown';
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 1;

        final product = await _getProductById(productId);
        if (product != null) {
          final costPerUnit = product.purchasePrice ?? (product.price * 0.7);
          totalCostOfGoodsSold += quantity * costPerUnit;
        }
      }
    }

    final grossProfit = totalNetRevenue - totalCostOfGoodsSold;
    final grossProfitMargin = totalNetRevenue > 0 ? (grossProfit / totalNetRevenue) * 100 : 0.0;

    final totalExpenses = expenses.fold(0.0, (sum, expense) => sum + expense.amount);
    final netProfit = grossProfit - totalExpenses;
    final netProfitMargin = totalNetRevenue > 0 ? (netProfit / totalNetRevenue) * 100 : 0.0;

    final expensesByCategory = <String, double>{};
    for (final expense in expenses) {
      expensesByCategory[expense.category] =
          (expensesByCategory[expense.category] ?? 0.0) + expense.amount;
    }

    return ProfitLossAnalytics(
      totalRevenue: totalNetRevenue,
      totalCostOfGoodsSold: totalCostOfGoodsSold,
      grossProfit: grossProfit,
      grossProfitMargin: grossProfitMargin,
      operatingExpenses: totalExpenses,
      netProfit: netProfit,
      netProfitMargin: netProfitMargin,
      topProfitableProducts: await _getTopProfitableProducts(orders),
      topProfitableCategories: await _getTopProfitableCategories(orders),
      profitByDay: _calculateProfitByDay(orders),
      profitByHour: _calculateProfitByHour(orders),
      businessExpenses: expenses,
      expensesByCategory: expensesByCategory,
      totalExpenses: totalExpenses,
    );
  }

  Future<SalesAnalytics> _calculateSalesAnalytics(List<AppOrder> orders) async {
    // Your existing sales calculation logic
    double totalSales = 0.0;
    int totalItemsSold = 0;
    final salesByHour = <String, double>{};
    final salesByDay = <String, double>{};

    for (var hour = 0; hour < 24; hour++) {
      salesByHour['${hour.toString().padLeft(2, '0')}:00'] = 0.0;
    }

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (final day in days) {
      salesByDay[day] = 0.0;
    }

    for (final order in orders) {
      totalSales += order.total;

      for (final item in order.lineItems) {
        final itemMap = item as Map<String, dynamic>;
        totalItemsSold += (itemMap['quantity'] as num?)?.toInt() ?? 1;
      }

      final hour = order.dateCreated.hour;
      final hourKey = '${hour.toString().padLeft(2, '0')}:00';
      salesByHour[hourKey] = salesByHour[hourKey]! + order.total;

      final dayName = DateFormat('E').format(order.dateCreated);
      salesByDay[dayName] = (salesByDay[dayName] ?? 0) + order.total;
    }

    final averageOrderValue = orders.isNotEmpty ? totalSales / orders.length : 0.0;

    return SalesAnalytics(
      totalSales: totalSales,
      totalOrders: orders.length,
      totalItemsSold: totalItemsSold,
      averageOrderValue: averageOrderValue,
      salesByHour: salesByHour,
      salesByDay: salesByDay,
      topProducts: await _getTopProducts(orders, totalSales),
      topCategories: await _getTopCategories(orders),
      // ... other fields
      subtotalAmount: 0.0,
      totalDiscounts: 0.0,
      itemDiscounts: 0.0,
      cartDiscounts: 0.0,
      additionalDiscounts: 0.0,
      taxAmount: 0.0,
      shippingAmount: 0.0,
      tipAmount: 0.0,
      taxableAmount: 0.0,
      discountTypes: {},
      paymentMethodDistribution: {},
    );
  }

  Future<CustomerAnalytics> _calculateCustomerAnalytics(
      List<Customer> customers,
      List<AppOrder> orders,
      TimePeriod period,
      ) async {
    // Your existing customer analytics logic
    final totalCustomers = customers.length;
    final newCustomers = customers.where((c) {
      return c.dateCreated != null &&
          c.dateCreated!.isAfter(period.startDate);
    }).length;

    final segmentation = _calculateCustomerSegmentation(customers);
    final topCustomers = await _getTopCustomers(customers);

    return CustomerAnalytics(
      totalCustomers: totalCustomers,
      newCustomers: newCustomers,
      averageOrderValue: await _calculateAverageOrderValue(orders),
      repeatCustomerRate: await _calculateRepeatCustomerRate(customers),
      customerGrowth: 0.0, // Calculate based on previous period
      customerSegmentation: segmentation,
      topCustomers: topCustomers,
      acquisitionData: [],
      retentionMetrics: null,
      locationData: [],
    );
  }

  // ========== HELPER METHODS ==========
  Future<Product?> _getProductById(String productId) async {
    if (await isOnline) {
      try {
        final doc = await productsRef.doc(productId).get();
        if (doc.exists) {
          return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        }
      } catch (e) {
        debugPrint('Error getting product online: $e');
      }
    }

    // Fallback to local database
    return await _hiveDb.getProductById(productId);
  }

  List<CustomerSegment> _calculateCustomerSegmentation(List<Customer> customers) {
    final total = customers.length;
    if (total == 0) return [];

    final vipCount = customers.where((c) => c.totalSpent > 1000).length;
    final regularCount = customers.where((c) => c.totalSpent > 100 && c.totalSpent <= 1000).length;
    final newCount = customers.where((c) => c.orderCount <= 1).length;
    final atRiskCount = customers.where((c) =>
    c.dateModified != null &&
        DateTime.now().difference(c.dateModified!).inDays > 90).length;

    return [
      CustomerSegment(segment: 'VIP', count: vipCount, percentage: (vipCount / total) * 100),
      CustomerSegment(segment: 'Regular', count: regularCount, percentage: (regularCount / total) * 100),
      CustomerSegment(segment: 'New', count: newCount, percentage: (newCount / total) * 100),
      CustomerSegment(segment: 'At Risk', count: atRiskCount, percentage: (atRiskCount / total) * 100),
    ];
  }

  Future<List<TopCustomer>> _getTopCustomers(List<Customer> customers) async {
    // Sort by total spent
    customers.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));

    return customers.take(10).map((customer) {
      String tier = 'Bronze';
      if (customer.totalSpent > 1000) {
        tier = 'Platinum';
      } else if (customer.totalSpent > 500) {
        tier = 'Gold';
      } else if (customer.totalSpent > 100) {
        tier = 'Silver';
      }

      return TopCustomer(
        customerId: customer.id,
        customerName: customer.fullName,
        email: customer.email,
        totalOrders: customer.orderCount,
        totalSpent: customer.totalSpent,
        lastOrderDate: customer.dateModified ?? customer.dateCreated ?? DateTime.now(),
        tier: tier,
      );
    }).toList();
  }

  Future<double> _calculateAverageOrderValue(List<AppOrder> orders) async {
    if (orders.isEmpty) return 0.0;
    final total = orders.fold(0.0, (sum, order) => sum + order.total);
    return total / orders.length;
  }

  Future<double> _calculateRepeatCustomerRate(List<Customer> customers) async {
    if (customers.isEmpty) return 0.0;
    final repeatCustomers = customers.where((c) => c.orderCount > 1).length;
    return (repeatCustomers / customers.length) * 100;
  }

  Future<List<ProductPerformance>> _getTopProducts(List<AppOrder> orders, double totalSales) async {
    final productSales = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      for (final item in order.lineItems) {
        final itemMap = item as Map<String, dynamic>;
        final productId = itemMap['productId']?.toString() ??
            itemMap['product_id']?.toString() ?? 'unknown';
        final quantity = (itemMap['quantity'] as int?) ?? 1;
        final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;
        final revenue = quantity * price;

        if (!productSales.containsKey(productId)) {
          final product = await _getProductById(productId);
          productSales[productId] = {
            'product': product,
            'quantity': 0,
            'revenue': 0.0,
            'discountAmount': 0.0,
            'netRevenue': 0.0,
          };
        }

        productSales[productId]!['quantity'] += quantity;
        productSales[productId]!['revenue'] += revenue;
      }
    }

    final performances = productSales.values
        .where((data) => data['product'] != null)
        .map((data) => ProductPerformance(
      product: data['product'] as Product,
      quantitySold: data['quantity'] as int,
      revenue: data['revenue'] as double,
      percentage: totalSales > 0 ? (data['revenue'] as double) / totalSales * 100 : 0,
      discountAmount: data['discountAmount'] as double,
      netRevenue: data['netRevenue'] as double,
    ))
        .toList();

    performances.sort((a, b) => b.revenue.compareTo(a.revenue));
    return performances.take(10).toList();
  }

  Future<List<CategoryPerformance>> _getTopCategories(List<AppOrder> orders) async {
    final categorySales = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      for (final item in order.lineItems) {
        if (item is! Map<String, dynamic>) continue;

        final productId = item['productId']?.toString() ??
            item['product_id']?.toString() ?? 'unknown';

        final product = await _getProductById(productId);
        if (product == null) continue;

        final category = product.categories.isNotEmpty ? product.categories.first :
        Category(id: 'uncategorized', name: 'Uncategorized', slug: '', count: 0);

        final quantity = (item['quantity'] ?? 0) as int;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final revenue = quantity * price;

        categorySales.putIfAbsent(category.id, () {
          return {
            'category': category,
            'quantity': 0,
            'revenue': 0.0,
            'discountAmount': 0.0,
          };
        });

        categorySales[category.id]!['quantity'] += quantity;
        categorySales[category.id]!['revenue'] += revenue;
      }
    }

    final totalRevenue = categorySales.values.fold(0.0, (sum, data) => sum + (data['revenue'] as double));

    return categorySales.values.map((data) => CategoryPerformance(
      category: data['category'] as Category,
      quantitySold: data['quantity'] as int,
      revenue: data['revenue'] as double,
      percentage: totalRevenue > 0 ? (data['revenue'] as double) / totalRevenue * 100 : 0,
      discountAmount: data['discountAmount'] as double,
    )).toList();
  }

  Future<List<ProductProfitability>> _getTopProfitableProducts(List<AppOrder> orders) async {
    final productProfitability = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      for (final item in order.lineItems) {
        final itemMap = item as Map<String, dynamic>;
        final productId = itemMap['productId']?.toString() ??
            itemMap['product_id']?.toString() ?? 'unknown';
        final quantity = (itemMap['quantity'] as int?) ?? 1;
        final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;

        final product = await _getProductById(productId);
        if (product == null) continue;

        final revenue = quantity * price;
        final costPerUnit = product.purchasePrice ?? (product.price * 0.7);
        final costOfGoodsSold = quantity * costPerUnit;
        final grossProfit = revenue - costOfGoodsSold;

        if (!productProfitability.containsKey(productId)) {
          productProfitability[productId] = {
            'product': product,
            'quantity': 0,
            'revenue': 0.0,
            'costOfGoodsSold': 0.0,
            'grossProfit': 0.0,
          };
        }

        productProfitability[productId]!['quantity'] += quantity;
        productProfitability[productId]!['revenue'] += revenue;
        productProfitability[productId]!['costOfGoodsSold'] += costOfGoodsSold;
        productProfitability[productId]!['grossProfit'] += grossProfit;
      }
    }

    final profitabilities = productProfitability.values
        .where((data) => data['product'] != null)
        .map((data) {
      final revenue = data['revenue'] as double;
      final grossProfit = data['grossProfit'] as double;
      final profitMargin = revenue > 0 ? (grossProfit / revenue) * 100 : 0.0;

      return ProductProfitability(
        product: data['product'] as Product,
        quantitySold: data['quantity'] as int,
        revenue: revenue,
        costOfGoodsSold: data['costOfGoodsSold'] as double,
        grossProfit: grossProfit,
        profitMargin: profitMargin,
      );
    })
        .toList();

    profitabilities.sort((a, b) => b.grossProfit.compareTo(a.grossProfit));
    return profitabilities.take(10).toList();
  }

  Future<List<CategoryProfitability>> _getTopProfitableCategories(List<AppOrder> orders) async {
    final categoryProfitability = <String, Map<String, dynamic>>{};

    for (final order in orders) {
      for (final item in order.lineItems) {
        if (item is! Map<String, dynamic>) continue;

        final productId = item['productId']?.toString() ??
            item['product_id']?.toString() ?? 'unknown';

        final product = await _getProductById(productId);
        if (product == null) continue;

        final category = product.categories.isNotEmpty ? product.categories.first :
        Category(id: 'uncategorized', name: 'Uncategorized', slug: '', count: 0);

        final quantity = (item['quantity'] ?? 0) as int;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;

        final revenue = quantity * price;
        final costPerUnit = product.purchasePrice ?? (product.price * 0.7);
        final costOfGoodsSold = quantity * costPerUnit;
        final grossProfit = revenue - costOfGoodsSold;

        categoryProfitability.putIfAbsent(category.id, () {
          return {
            'category': category,
            'quantity': 0,
            'revenue': 0.0,
            'costOfGoodsSold': 0.0,
            'grossProfit': 0.0,
          };
        });

        categoryProfitability[category.id]!['quantity'] += quantity;
        categoryProfitability[category.id]!['revenue'] += revenue;
        categoryProfitability[category.id]!['costOfGoodsSold'] += costOfGoodsSold;
        categoryProfitability[category.id]!['grossProfit'] += grossProfit;
      }
    }

    return categoryProfitability.values.map((data) {
      final revenue = data['revenue'] as double;
      final grossProfit = data['grossProfit'] as double;
      final profitMargin = revenue > 0 ? (grossProfit / revenue) * 100 : 0.0;

      return CategoryProfitability(
        category: data['category'] as Category,
        quantitySold: data['quantity'] as int,
        revenue: revenue,
        costOfGoodsSold: data['costOfGoodsSold'] as double,
        grossProfit: grossProfit,
        profitMargin: profitMargin,
      );
    }).toList();
  }

  Map<String, double> _calculateProfitByDay(List<AppOrder> orders) {
    final profitByDay = <String, double>{};
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final day in days) {
      profitByDay[day] = 0.0;
    }

    for (final order in orders) {
      final dayName = DateFormat('E').format(order.dateCreated);
      // Simplified profit calculation (revenue - estimated 30% cost)
      final estimatedProfit = order.total * 0.7;
      profitByDay[dayName] = (profitByDay[dayName] ?? 0) + estimatedProfit;
    }

    return profitByDay;
  }

  Map<String, double> _calculateProfitByHour(List<AppOrder> orders) {
    final profitByHour = <String, double>{};

    for (var hour = 0; hour < 24; hour++) {
      profitByHour['${hour.toString().padLeft(2, '0')}:00'] = 0.0;
    }

    for (final order in orders) {
      final hour = order.dateCreated.hour;
      final hourKey = '${hour.toString().padLeft(2, '0')}:00';
      final estimatedProfit = order.total * 0.7;
      profitByHour[hourKey] = profitByHour[hourKey]! + estimatedProfit;
    }

    return profitByHour;
  }

  // ========== SERIALIZATION METHODS ==========
  Map<String, dynamic> _serializeProfitLossAnalytics(ProfitLossAnalytics analytics) {
    return {
      'totalRevenue': analytics.totalRevenue,
      'totalCostOfGoodsSold': analytics.totalCostOfGoodsSold,
      'grossProfit': analytics.grossProfit,
      'grossProfitMargin': analytics.grossProfitMargin,
      'operatingExpenses': analytics.operatingExpenses,
      'netProfit': analytics.netProfit,
      'netProfitMargin': analytics.netProfitMargin,
      'profitByDay': analytics.profitByDay,
      'profitByHour': analytics.profitByHour,
      'expensesByCategory': analytics.expensesByCategory,
      'totalExpenses': analytics.totalExpenses,
      'businessExpenses': analytics.businessExpenses.map((e) => e.toFirestore()).toList(),
    };
  }

  ProfitLossAnalytics _deserializeProfitLossAnalytics(Map<String, dynamic> data) {
    final expenses = (data['businessExpenses'] as List)
        .map((e) => BusinessExpense.fromFirestore(e as Map<String, dynamic>, e['id'] as String))
        .toList();

    return ProfitLossAnalytics(
      totalRevenue: data['totalRevenue'] as double,
      totalCostOfGoodsSold: data['totalCostOfGoodsSold'] as double,
      grossProfit: data['grossProfit'] as double,
      grossProfitMargin: data['grossProfitMargin'] as double,
      operatingExpenses: data['operatingExpenses'] as double,
      netProfit: data['netProfit'] as double,
      netProfitMargin: data['netProfitMargin'] as double,
      topProfitableProducts: [],
      topProfitableCategories: [],
      profitByDay: Map<String, double>.from(data['profitByDay'] as Map),
      profitByHour: Map<String, double>.from(data['profitByHour'] as Map),
      businessExpenses: expenses,
      expensesByCategory: Map<String, double>.from(data['expensesByCategory'] as Map),
      totalExpenses: data['totalExpenses'] as double,
    );
  }

  Map<String, dynamic> _serializeSalesAnalytics(SalesAnalytics analytics) {
    return {
      'totalSales': analytics.totalSales,
      'totalOrders': analytics.totalOrders,
      'totalItemsSold': analytics.totalItemsSold,
      'averageOrderValue': analytics.averageOrderValue,
      'salesByHour': analytics.salesByHour,
      'salesByDay': analytics.salesByDay,
      'subtotalAmount': analytics.subtotalAmount,
      'totalDiscounts': analytics.totalDiscounts,
      'itemDiscounts': analytics.itemDiscounts,
      'cartDiscounts': analytics.cartDiscounts,
      'additionalDiscounts': analytics.additionalDiscounts,
      'taxAmount': analytics.taxAmount,
      'shippingAmount': analytics.shippingAmount,
      'tipAmount': analytics.tipAmount,
      'taxableAmount': analytics.taxableAmount,
      'discountTypes': analytics.discountTypes,
      'paymentMethodDistribution': analytics.paymentMethodDistribution,
    };
  }

  SalesAnalytics _deserializeSalesAnalytics(Map<String, dynamic> data) {
    return SalesAnalytics(
      totalSales: data['totalSales'] as double,
      totalOrders: data['totalOrders'] as int,
      totalItemsSold: data['totalItemsSold'] as int,
      averageOrderValue: data['averageOrderValue'] as double,
      salesByHour: Map<String, double>.from(data['salesByHour'] as Map),
      salesByDay: Map<String, double>.from(data['salesByDay'] as Map),
      topProducts: [],
      topCategories: [],
      subtotalAmount: data['subtotalAmount'] as double,
      totalDiscounts: data['totalDiscounts'] as double,
      itemDiscounts: data['itemDiscounts'] as double,
      cartDiscounts: data['cartDiscounts'] as double,
      additionalDiscounts: data['additionalDiscounts'] as double,
      taxAmount: data['taxAmount'] as double,
      shippingAmount: data['shippingAmount'] as double,
      tipAmount: data['tipAmount'] as double,
      taxableAmount: data['taxableAmount'] as double,
      discountTypes: Map<String, double>.from(data['discountTypes'] as Map),
      paymentMethodDistribution: Map<String, double>.from(data['paymentMethodDistribution'] as Map),
    );
  }

  Map<String, dynamic> _serializeCustomerAnalytics(CustomerAnalytics analytics) {
    return {
      'totalCustomers': analytics.totalCustomers,
      'newCustomers': analytics.newCustomers,
      'averageOrderValue': analytics.averageOrderValue,
      'repeatCustomerRate': analytics.repeatCustomerRate,
      'customerGrowth': analytics.customerGrowth,
      'customerSegmentation': analytics.customerSegmentation.map((segment) => {
        'segment': segment.segment,
        'count': segment.count,
        'percentage': segment.percentage,
      }).toList(),
      'topCustomers': analytics.topCustomers.map((customer) => {
        'customerId': customer.customerId,
        'customerName': customer.customerName,
        'email': customer.email,
        'totalOrders': customer.totalOrders,
        'totalSpent': customer.totalSpent,
        'lastOrderDate': customer.lastOrderDate.toIso8601String(),
        'tier': customer.tier,
      }).toList(),
    };
  }

  CustomerAnalytics _deserializeCustomerAnalytics(Map<String, dynamic> data) {
    return CustomerAnalytics(
      totalCustomers: data['totalCustomers'] as int,
      newCustomers: data['newCustomers'] as int,
      averageOrderValue: data['averageOrderValue'] as double?,
      repeatCustomerRate: data['repeatCustomerRate'] as double?,
      customerGrowth: data['customerGrowth'] as double,
      customerSegmentation: (data['customerSegmentation'] as List)
          .map((segment) => CustomerSegment(
        segment: segment['segment'] as String,
        count: segment['count'] as int,
        percentage: segment['percentage'] as double,
      ))
          .toList(),
      topCustomers: (data['topCustomers'] as List)
          .map((customer) => TopCustomer(
        customerId: customer['customerId'] as String,
        customerName: customer['customerName'] as String,
        email: customer['email'] as String,
        totalOrders: customer['totalOrders'] as int,
        totalSpent: customer['totalSpent'] as double,
        lastOrderDate: DateTime.parse(customer['lastOrderDate'] as String),
        tier: customer['tier'] as String,
      ))
          .toList(),
      acquisitionData: [],
      retentionMetrics: null,
      locationData: [],
    );
  }

  // ========== OTHER ANALYTICS METHODS ==========
  Future<FinancialBreakdown> getFinancialBreakdown(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);
    return FinancialBreakdown(
      subtotal: analytics.subtotalAmount,
      discounts: analytics.totalDiscounts,
      taxes: analytics.taxAmount,
      shipping: analytics.shippingAmount,
      tips: analytics.tipAmount,
      total: analytics.totalSales,
    );
  }

  Future<DiscountAnalytics> getDiscountAnalytics(TimePeriod period) async {
    final orders = await _hiveDb.getOrders(period.startDate, period.endDate);

    double totalDiscounts = 0.0;
    for (final order in orders) {
      totalDiscounts += order.calculateTotalDiscount();
    }

    return DiscountAnalytics(
      totalDiscounts: totalDiscounts,
      averageDiscountPerOrder: orders.isNotEmpty ? totalDiscounts / orders.length : 0.0,
      discountRate: 0.0, // Calculate based on subtotal
      discountByType: {},
      highestDiscountOrders: [],
    );
  }

  Future<TaxAnalytics> getTaxAnalytics(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);
    return TaxAnalytics(
      totalTaxCollected: analytics.taxAmount,
      averageTaxPerOrder: analytics.totalOrders > 0 ? analytics.taxAmount / analytics.totalOrders : 0.0,
      effectiveTaxRate: analytics.taxableAmount > 0 ? (analytics.taxAmount / analytics.taxableAmount) * 100 : 0.0,
      taxByType: {},
    );
  }

  Future<List<AppOrder>> getRecentOrders({int limit = 10}) async {
    final orders = await _hiveDb.getOrders(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now(),
    );

    orders.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    return orders.take(limit).toList();
  }

  Future<Map<String, dynamic>> getCashSummary(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);
    final financial = await getFinancialBreakdown(period);

    return {
      'totalCash': analytics.totalSales,
      'cashOrders': analytics.totalOrders,
      'averageTransaction': analytics.averageOrderValue,
      'peakHour': _findPeakHour(analytics.salesByHour),
      'subtotal': financial.subtotal,
      'discounts': financial.discounts,
      'taxes': financial.taxes,
      'shipping': financial.shipping,
      'tips': financial.tips,
    };
  }

  String _findPeakHour(Map<String, double> salesByHour) {
    if (salesByHour.isEmpty) return 'N/A';
    var peakHour = salesByHour.entries.first;
    for (final entry in salesByHour.entries) {
      if (entry.value > peakHour.value) {
        peakHour = entry;
      }
    }
    return peakHour.key;
  }

  // Cleanup
  Future<void> dispose() async {
    await _hiveDb.close();
  }
}