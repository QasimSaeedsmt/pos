import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import '../../constants.dart';
import '../../core/models/app_order_model.dart';
import '../../core/models/cart_item_model.dart';
import '../../core/models/category_model.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/return_request.dart';
import '../clientDashboard/client_dashboard.dart';
import '../customerBase/customer_base.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();
  Future<void> deleteCustomer(String customerId) async {
    final box = await _customersBoxInstance;

    try {
      await box.delete(customerId);
      debugPrint('Customer deleted from local storage: $customerId');
    } catch (e) {
      debugPrint('Error deleting customer from local storage: $e');
      throw Exception('Failed to delete customer locally: $e');
    }
  }
  // Hive box names
  static const String _pendingReturnsBox = 'pending_returns_box';
  static const String _syncedReturnsBox = 'synced_returns_box';
  static const String productsBox = 'cached_products_box';
  static const String _cartBox = 'cart_items_box';
  static const String _pendingOrdersBox = 'pending_orders_box';
  static const String _pendingRestocksBox = 'pending_restocks_box';
  static const String _cacheTimestampBox = 'cache_timestamp_box';
  static const String _customersBox = 'cached_customers_box';
  static const String _dashboardDataBox = 'dashboard_data_box';
  static const String _dashboardCacheTimestampBox = 'dashboard_cache_timestamp_box';
  static const String _categoriesBox = 'categories_box';
  static const String _categoriesTimestampBox = 'categories_cache_timestamp_box';

  // Key constants (for values within boxes)
  static const String _cacheTimestampKey = 'cache_timestamp_key';
  static const String _dashboardDataKey = 'dashboard_data_key';
  static const String _dashboardCacheTimestampKey = 'dashboard_cache_timestamp_key';
  static const String _categoriesTimestampKey = 'categories_cache_timestamp_key';

  // Track initialization state
  bool _isInitialized = false;

  // Initialize Hive - Call this once at app startup
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDir.path);

      // Register Hive adapters
      Hive.registerAdapter(CartItemAdapter());
      Hive.registerAdapter(ProductAdapter());
      Hive.registerAdapter(CategoryAdapter());
      Hive.registerAdapter(CustomerAdapter());
      // Hive.registerAdapter(PendingOrderAdapter());
      Hive.registerAdapter(ReturnRequestAdapter());
      Hive.registerAdapter(AppOrderAdapter());
      // Register any other adapters you need for your models

      _isInitialized = true;
      debugPrint('✅ Hive initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Hive: $e');
      rethrow;
    }
  }

  // Helper methods to open boxes lazily
  Future<Box<Map<String, dynamic>>> get _pendingReturnsBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_pendingReturnsBox)) {
      return await Hive.openBox<Map<String, dynamic>>(_pendingReturnsBox);
    }
    return Hive.box<Map<String, dynamic>>(_pendingReturnsBox);
  }

  Future<Box<Map<String, dynamic>>> get _syncedReturnsBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_syncedReturnsBox)) {
      return await Hive.openBox<Map<String, dynamic>>(_syncedReturnsBox);
    }
    return Hive.box<Map<String, dynamic>>(_syncedReturnsBox);
  }

  Future<Box<Product>> get _productsBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(productsBox)) {
      return await Hive.openBox<Product>(productsBox);
    }
    return Hive.box<Product>(productsBox);
  }

  Future<Box<CartItem>> get _cartBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_cartBox)) {
      return await Hive.openBox<CartItem>(_cartBox);
    }
    return Hive.box<CartItem>(_cartBox);
  }

  Future<Box<Map<String, dynamic>>> get _pendingOrdersBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_pendingOrdersBox)) {
      return await Hive.openBox<Map<String, dynamic>>(_pendingOrdersBox);
    }
    return Hive.box<Map<String, dynamic>>(_pendingOrdersBox);
  }

  Future<Box<Map<String, dynamic>>> get _pendingRestocksBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_pendingRestocksBox)) {
      return await Hive.openBox<Map<String, dynamic>>(_pendingRestocksBox);
    }
    return Hive.box<Map<String, dynamic>>(_pendingRestocksBox);
  }

  Future<Box<int>> get _cacheTimestampBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_cacheTimestampBox)) {
      return await Hive.openBox<int>(_cacheTimestampBox);
    }
    return Hive.box<int>(_cacheTimestampBox);
  }

  Future<Box<Customer>> get _customersBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_customersBox)) {
      return await Hive.openBox<Customer>(_customersBox);
    }
    return Hive.box<Customer>(_customersBox);
  }

  Future<Box<Map<String, dynamic>>> get dashboardDataBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_dashboardDataBox)) {
      return await Hive.openBox<Map<String, dynamic>>(_dashboardDataBox);
    }
    return Hive.box<Map<String, dynamic>>(_dashboardDataBox);
  }

  Future<Box<int>> get dashboardCacheTimestampBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_dashboardCacheTimestampBox)) {
      return await Hive.openBox<int>(_dashboardCacheTimestampBox);
    }
    return Hive.box<int>(_dashboardCacheTimestampBox);
  }

  Future<Box<Category>> get _categoriesBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_categoriesBox)) {
      return await Hive.openBox<Category>(_categoriesBox);
    }
    return Hive.box<Category>(_categoriesBox);
  }

  Future<Box<int>> get _categoriesTimestampBoxInstance async {
    await _ensureInitialized();
    if (!Hive.isBoxOpen(_categoriesTimestampBox)) {
      return await Hive.openBox<int>(_categoriesTimestampBox);
    }
    return Hive.box<int>(_categoriesTimestampBox);
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }

  // Initialize all boxes at once (optional - for startup optimization)
  Future<void> openAllBoxes() async {
    await _ensureInitialized();

    try {
      await Future.wait([
        _pendingReturnsBoxInstance,
        _syncedReturnsBoxInstance,
        _productsBoxInstance,
        _cartBoxInstance,
        _pendingOrdersBoxInstance,
        _pendingRestocksBoxInstance,
        _cacheTimestampBoxInstance,
        _customersBoxInstance,
        dashboardDataBoxInstance,
        dashboardCacheTimestampBoxInstance,
        _categoriesBoxInstance,
        _categoriesTimestampBoxInstance,
      ]);
      debugPrint('✅ All Hive boxes opened successfully');
    } catch (e) {
      debugPrint('❌ Error opening Hive boxes: $e');
      rethrow;
    }
  }

  // Category operations
  Future<List<Category>> getAllCategories() async {
    try {
      final box = await _categoriesBoxInstance;
      return box.values.toList();
    } catch (e) {
      debugPrint('Error getting local categories: $e');
      return [];
    }
  }
// ========== SYNC STATUS METHODS ==========

  Future<List<Map<String, dynamic>>> getSyncableItems() async {
    final List<Map<String, dynamic>> allItems = [];

    // Get all pending items
    final pendingOrders = await getPendingOrders();
    final pendingReturns = await getPendingReturns();
    final pendingRestocks = await getPendingRestocks();

    allItems.addAll(pendingOrders.map((order) => {
      ...order,
      'type': 'order',
    }));

    allItems.addAll(pendingReturns.map((returnReq) => {
      ...returnReq,
      'type': 'return',
    }));

    allItems.addAll(pendingRestocks.map((restock) => {
      ...restock,
      'type': 'restock',
    }));

    return allItems;
  }

  Future<int> getPendingSyncCount() async {
    final pendingOrders = await getPendingOrders();
    final pendingReturns = await getPendingReturns();
    final pendingRestocks = await getPendingRestocks();

    return pendingOrders.length + pendingReturns.length + pendingRestocks.length;
  }

  Future<void> resetFailedSyncs() async {
    // Reset failed sync attempts for retry
    final pendingOrders = await getPendingOrders();
    final pendingReturns = await getPendingReturns();
    final pendingRestocks = await getPendingRestocks();

    for (final order in pendingOrders) {
      if (order['sync_status'] == 'failed') {
        await updatePendingOrderStatus(
          order['id'] as int,
          'pending',
          attempts: 0,
        );
      }
    }

    for (final returnReq in pendingReturns) {
      if (returnReq['sync_status'] == 'failed') {
        await updatePendingReturnStatus(
          returnReq['local_id'] as int,
          'pending',
          attempts: 0,
        );
      }
    }

    for (final restock in pendingRestocks) {
      if (restock['sync_status'] == 'failed') {
        await updatePendingRestockStatus(
          restock['id'] as int,
          'pending',
          attempts: 0,
        );
      }
    }
  }
  Future<String> saveCategory(Category category) async {
    try {
      final box = await _categoriesBoxInstance;
      final timestampBox = await _categoriesTimestampBoxInstance;

      await box.put(category.id, category);
      await timestampBox.put(_categoriesTimestampKey, DateTime.now().millisecondsSinceEpoch);

      return category.id;
    } catch (e) {
      debugPrint('Error saving category locally: $e');
      throw Exception('Failed to save category locally: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      final box = await _categoriesBoxInstance;
      final timestampBox = await _categoriesTimestampBoxInstance;

      await box.delete(categoryId);
      await timestampBox.put(_categoriesTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error deleting category locally: $e');
      throw Exception('Failed to delete category locally: $e');
    }
  }

  Future<void> saveCategories(List<Category> categories) async {
    try {
      final box = await _categoriesBoxInstance;
      final timestampBox = await _categoriesTimestampBoxInstance;

      // Clear existing categories
      await box.clear();

      // Add all categories
      final Map<String, Category> categoryMap = {};
      for (final category in categories) {
        categoryMap[category.id] = category;
      }
      await box.putAll(categoryMap);

      await timestampBox.put(_categoriesTimestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('Saved ${categories.length} categories to local storage');
    } catch (e) {
      debugPrint('Error saving categories locally: $e');
      throw Exception('Failed to save categories locally: $e');
    }
  }

  Future<void> saveDashboardData(OfflineDashboardData data) async {
    final box = await dashboardDataBoxInstance;
    final timestampBox = await dashboardCacheTimestampBoxInstance;

    final dashboardData = data.toJson();
    await box.put(_dashboardDataKey, dashboardData);
    await timestampBox.put(_dashboardCacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<OfflineDashboardData?> getDashboardData(String tenantId) async {
    final box = await dashboardDataBoxInstance;
    final timestampBox = await dashboardCacheTimestampBoxInstance;

    final dashboardData = box.get(_dashboardDataKey);
    final timestamp = timestampBox.get(_dashboardCacheTimestampKey);

    if (dashboardData == null || timestamp == null) {
      return null;
    }

    try {
      final data = OfflineDashboardData.fromJson(dashboardData);

      // Return data if it's for the current tenant (no expiry check for offline)
      if (data.tenantId == tenantId) {
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading cached dashboard data: $e');
      return null;
    }
  }

  Future<List<RevenueDataPoint>> generateRevenueData() async {
    final pendingOrders = await getPendingOrders();
    final now = DateTime.now();
    final List<RevenueDataPoint> revenueData = [];

    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      double dayRevenue = 0.0;
      int dayOrders = 0;

      for (final order in pendingOrders) {
        final orderDate = DateTime.parse(order['created_at']);
        if (orderDate.year == date.year &&
            orderDate.month == date.month &&
            orderDate.day == date.day) {
          final orderData = order['order_data'] as Map<String, dynamic>;
          dayRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
          dayOrders++;
        }
      }

      revenueData.add(RevenueDataPoint(
        date: date,
        revenue: dayRevenue,
        orders: dayOrders,
      ));
    }

    return revenueData;
  }


  Future<DashboardStats> generateOfflineStats() async {
    final pendingOrders = await getPendingOrders();
    final products = await getAllProducts();
    final customers = await getCustomers();
    final pendingReturns = await getPendingReturns();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    double todayRevenue = 0.0;
    int todaySales = 0;
    final todayCustomerIds = <String>{};

    for (final order in pendingOrders) {
      final orderDate = DateTime.parse(order['created_at']);
      if (orderDate.isAfter(todayStart)) {
        final orderData = order['order_data'] as Map<String, dynamic>;
        todayRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
        todaySales++;

        final customerData = order['customer_data'] as Map<String, dynamic>?;
        if (customerData != null && customerData['customerId'] != null) {
          todayCustomerIds.add(customerData['customerId'].toString());
        }
      }
    }

    double totalRevenue = 0.0;
    for (final order in pendingOrders) {
      final orderData = order['order_data'] as Map<String, dynamic>;
      totalRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
    }

    final lowStockProducts = products.where((p) => p.stockQuantity <= 10).length;

    final averageOrderValue = pendingOrders.isNotEmpty
        ? totalRevenue / pendingOrders.length
        : 0.0;
    final conversionRate = customers.isNotEmpty
        ? (pendingOrders.length / customers.length * 100).clamp(0.0, 100.0)
        : 0.0;

    final todayReturns = pendingReturns.where((returnReq) {
      final returnDate = DateTime.parse(returnReq['created_at'] ?? '');
      return returnDate.isAfter(todayStart);
    }).length;

    return DashboardStats(
      totalRevenue: totalRevenue,
      todayRevenue: todayRevenue,
      totalSales: pendingOrders.length,
      todaySales: todaySales,
      totalProducts: products.length,
      lowStockProducts: lowStockProducts,
      totalCustomers: customers.length,
      todayCustomers: todayCustomerIds.length,
      averageOrderValue: averageOrderValue,
      conversionRate: conversionRate,
      revenueGrowth: 0.0,
      salesGrowth: 0.0,
      todayReturns: todayReturns,
      totalReturns: pendingReturns.length,
    );
  }

  // Return operations
  Future<int> savePendingReturn(ReturnRequest returnRequest) async {
    final box = await _pendingReturnsBoxInstance;

    final returnId = box.length + 1;
    final offlineId = 'offline_return_${DateTime.now().millisecondsSinceEpoch}';

    final returnData = returnRequest.toLocalMap();
    returnData['local_id'] = returnId;
    returnData['offline_id'] = offlineId;
    returnData['sync_status'] = 'pending';
    returnData['sync_attempts'] = 0;
    returnData['created_at'] = DateTime.now().toIso8601String();

    await box.put(returnId.toString(), returnData);

    return returnId;
  }

  Future<List<Map<String, dynamic>>> getPendingReturns() async {
    final box = await _pendingReturnsBoxInstance;

    try {
      final allReturns = box.values.toList();
      return allReturns
          .where((ret) => ret['sync_status'] == 'pending')
          .toList();
    } catch (e) {
      debugPrint('Error loading pending returns: $e');
      return [];
    }
  }

  Future<void> updatePendingReturnStatus(
      int returnId,
      String status, {
        int attempts = 0,
      }) async {
    final box = await _pendingReturnsBoxInstance;

    try {
      final returnData = box.get(returnId.toString());
      if (returnData != null) {
        returnData['sync_status'] = status;
        returnData['sync_attempts'] = attempts;
        returnData['last_sync_attempt'] = DateTime.now().toIso8601String();
        await box.put(returnId.toString(), returnData);
      }
    } catch (e) {
      debugPrint('Error updating pending return: $e');
    }
  }

  Future<void> deletePendingReturn(int returnId) async {
    final box = await _pendingReturnsBoxInstance;

    try {
      await box.delete(returnId.toString());
    } catch (e) {
      debugPrint('Error deleting pending return: $e');
    }
  }

  Future<void> saveSyncedReturn(ReturnRequest returnRequest) async {
    final box = await _syncedReturnsBoxInstance;

    final returnData = returnRequest.toLocalMap();
    returnData['synced_at'] = DateTime.now().toIso8601String();

    await box.put(returnRequest.id, returnData);
  }

  Future<List<ReturnRequest>> getSyncedReturns() async {
    final box = await _syncedReturnsBoxInstance;

    try {
      final allReturns = box.values.toList();
      return allReturns
          .map((json) => ReturnRequest.fromLocalMap(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading synced returns: $e');
      return [];
    }
  }

  Future<List<ReturnRequest>> getAllReturns() async {
    final pending = await getPendingReturns();
    final synced = await getSyncedReturns();

    final allReturns = [
      ...pending.map((p) => ReturnRequest.fromLocalMap(p)),
      ...synced,
    ];

    allReturns.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

    return allReturns;
  }

  // Customer operations
  Future<void> saveCustomers(List<Customer> customers) async {
    final box = await _customersBoxInstance;

    // Clear existing customers
    await box.clear();

    // Add all customers
    final Map<String, Customer> customerMap = {};
    for (final customer in customers) {
      customerMap[customer.id] = customer;
    }
    await box.putAll(customerMap);
  }

  Future<List<Customer>> getCustomers() async {
    final box = await _customersBoxInstance;

    try {
      return box.values.toList();
    } catch (e) {
      debugPrint('Error loading cached customers: $e');
      return [];
    }
  }

  Future<int> savePendingOrderWithCustomer(
      List<CartItem> cartItems,
      CustomerSelection customerSelection, {
        Map<String, dynamic>? additionalData,
      }) async {
    final box = await _pendingOrdersBoxInstance;

    final orderId = box.length + 1;

    // Calculate enhanced pricing data
    final subtotal = cartItems.fold(
      0.0,
          (sum, item) => sum + item.baseSubtotal,
    );
    final itemDiscounts = cartItems.fold(
      0.0,
          (sum, item) => sum + item.discountAmount,
    );

    final cartDiscount = additionalData?['cartData']?['cartDiscount'] ?? 0.0;
    final cartDiscountPercent =
        additionalData?['cartData']?['cartDiscountPercent'] ?? 0.0;
    final cartDiscountAmount =
        cartDiscount + (subtotal * cartDiscountPercent / 100);

    final totalDiscount = itemDiscounts + cartDiscountAmount;
    final taxableAmount = subtotal - totalDiscount;

    final taxRate = additionalData?['cartData']?['taxRate'] ?? 0.0;
    final taxAmount = taxableAmount * taxRate / 100;

    final additionalDiscount = additionalData?['additionalDiscount'] ?? 0.0;
    final shippingAmount = additionalData?['shippingAmount'] ?? 0.0;
    final tipAmount = additionalData?['tipAmount'] ?? 0.0;

    final finalTotal =
        taxableAmount +
            taxAmount +
            shippingAmount +
            tipAmount -
            additionalDiscount;

    final orderData = {
      'id': orderId,
      'order_data': {
        'line_items': cartItems
            .map(
              (item) => {
            'product_id': item.product.id,
            'product_name': item.product.name,
            'product_sku': item.product.sku,
            'quantity': item.quantity,
            'price': item.product.price,
            'base_price': item.product.price,
            'manual_discount': item.manualDiscount,
            'manual_discount_percent': item.manualDiscountPercent,
            'discount_amount': item.discountAmount,
            'base_subtotal': item.baseSubtotal,
            'final_subtotal': item.subtotal,
            'has_manual_discount': item.hasManualDiscount,
          },
        )
            .toList(),
        'pricing_breakdown': {
          'subtotal': subtotal,
          'item_discounts': itemDiscounts,
          'cart_discount': cartDiscount,
          'cart_discount_percent': cartDiscountPercent,
          'cart_discount_amount': cartDiscountAmount,
          'additional_discount': additionalDiscount,
          'total_discount': totalDiscount + additionalDiscount,
          'taxable_amount': taxableAmount - additionalDiscount,
          'tax_rate': taxRate,
          'tax_amount': taxAmount,
          'shipping_amount': shippingAmount,
          'tip_amount': tipAmount,
          'final_total': finalTotal,
        },
        'total': finalTotal,
        'original_total': subtotal,
      },
      'customer_data': customerSelection.hasCustomer
          ? {
        'customerId': customerSelection.customer!.id,
        'firstName': customerSelection.customer!.firstName,
        'lastName': customerSelection.customer!.lastName,
        'email': customerSelection.customer!.email,
        'phone': customerSelection.customer!.phone,
        'company': customerSelection.customer!.company,
      }
          : null,
      'payment_data': {
        'method': additionalData?['paymentMethod'] ?? 'cash',
        'amount_paid': finalTotal,
        'status': 'completed',
      },
      'discount_summary': {
        'applied_discounts': cartItems
            .where((item) => item.hasManualDiscount)
            .map(
              (item) => {
            'product_id': item.product.id,
            'product_name': item.product.name,
            'discount_type': item.manualDiscount != null
                ? 'amount'
                : 'percent',
            'discount_value':
            item.manualDiscount ?? item.manualDiscountPercent,
            'discount_amount': item.discountAmount,
          },
        )
            .toList(),
        'cart_level_discount': {
          'type': cartDiscount > 0 ? 'amount' : 'percent',
          'value': cartDiscount > 0 ? cartDiscount : cartDiscountPercent,
          'amount': cartDiscountAmount,
        },
        'additional_discount': additionalDiscount,
      },
      'settings_used': {
        'tax_rate': taxRate,
        'default_discount_rate':
        additionalData?['invoiceSettings']?['discountRate'] ?? 0.0,
        'business_info_used': additionalData?['businessInfo'] != null,
      },
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'sync_attempts': 0,
      'version': '2.0',
    };

    if (additionalData != null) {
      orderData['additional_data'] = additionalData;
    }

    await box.put(orderId.toString(), orderData);

    debugPrint(
      'Saved enhanced pending order #$orderId with total: ${Constants.CURRENCY_NAME}$finalTotal',
    );

    return orderId;
  }

  Future<void> saveProducts(List<Product> products) async {
    final box = await _productsBoxInstance;
    final timestampBox = await _cacheTimestampBoxInstance;

    debugPrint('💾 Saving ${products.length} products to local storage');

    // Get existing products
    final existingProducts = box.values.toList();
    final Map<String, Product> existingProductsMap = {};

    for (final product in existingProducts) {
      existingProductsMap[product.id] = product;
    }

    debugPrint('📁 Found ${existingProductsMap.length} existing products in cache');

    // Merge new products with existing ones
    int updatedCount = 0;
    int addedCount = 0;

    for (final product in products) {
      if (existingProductsMap.containsKey(product.id)) {
        existingProductsMap[product.id] = product;
        updatedCount++;
      } else {
        existingProductsMap[product.id] = product;
        addedCount++;
      }
    }

    debugPrint('🔄 Merge result: $addedCount added, $updatedCount updated');

    // Clear and add all merged products
    await box.clear();
    await box.putAll(existingProductsMap);

    await timestampBox.put(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);

    debugPrint('✅ Successfully saved ${existingProductsMap.length} products to local storage');
  }

  Future<List<Product>> getAllProducts() async {
    final box = await _productsBoxInstance;

    try {
      return box.values.toList();
    } catch (e) {
      debugPrint('Error loading all cached products: $e');
      return [];
    }
  }

  Future<List<Product>> getProducts({
    int limit = 50,
    int offset = 0,
    String searchQuery = '',
    bool inStockOnly = false,
    double minPrice = 0,
    double maxPrice = double.infinity,
  }) async {
    final box = await _productsBoxInstance;

    try {
      var products = box.values.toList();

      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        products = products
            .where(
              (product) =>
          product.name.toLowerCase().contains(lowerQuery) ||
              (product.sku.toLowerCase().contains(lowerQuery)),
        )
            .toList();
      }

      if (inStockOnly) {
        products = products.where((product) => product.inStock).toList();
      }

      if (minPrice > 0) {
        products = products
            .where((product) => product.price >= minPrice)
            .toList();
      }

      if (maxPrice < double.infinity) {
        products = products
            .where((product) => product.price <= maxPrice)
            .toList();
      }

      products.sort((a, b) => a.name.compareTo(b.name));
      final start = offset;
      final end = (offset + limit) > products.length
          ? products.length
          : (offset + limit);

      return products.sublist(start, end);
    } catch (e) {
      debugPrint('Error loading cached products: $e');
      return [];
    }
  }

  Future<Product?> getProductById(String id) async {
    final box = await _productsBoxInstance;

    try {
      return box.get(id);
    } catch (e) {
      debugPrint('Error getting product by ID: $e');
      return null;
    }
  }

  Future<Product?> getProductBySku(String sku) async {
    final products = await getAllProducts();
    try {
      return products.firstWhere((product) => product.sku == sku);
    } catch (e) {
      return null;
    }
  }

  // Cart operations
  Future<void> saveCartItems(List<CartItem> items) async {
    final box = await _cartBoxInstance;

    // Clear existing cart
    await box.clear();

    // Add all items with index as key
    for (int i = 0; i < items.length; i++) {
      await box.put(i.toString(), items[i]);
    }
  }

  Future<List<CartItem>> getCartItems() async {
    final box = await _cartBoxInstance;

    try {
      return box.values.toList();
    } catch (e) {
      debugPrint('Error loading cart: $e');
      return [];
    }
  }

  Future<void> clearCart() async {
    final box = await _cartBoxInstance;
    await box.clear();
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final box = await _pendingOrdersBoxInstance;

    try {
      final allOrders = box.values.toList();
      return allOrders
          .where((order) => order['sync_status'] == 'pending')
          .toList();
    } catch (e) {
      debugPrint('Error loading pending orders: $e');
      return [];
    }
  }

  Future<void> updatePendingOrderStatus(
      int orderId,
      String status, {
        int attempts = 0,
      }) async {
    final box = await _pendingOrdersBoxInstance;

    try {
      final orderData = box.get(orderId.toString());
      if (orderData != null) {
        orderData['sync_status'] = status;
        orderData['sync_attempts'] = attempts;
        orderData['last_sync_attempt'] = DateTime.now().toIso8601String();
        await box.put(orderId.toString(), orderData);
      }
    } catch (e) {
      debugPrint('Error updating pending order: $e');
    }
  }

  Future<void> deletePendingOrder(int orderId) async {
    final box = await _pendingOrdersBoxInstance;

    try {
      await box.delete(orderId.toString());
    } catch (e) {
      debugPrint('Error deleting pending order: $e');
    }
  }

  // Pending restocks operations
  Future<int> savePendingRestock(
      String productId,
      int quantity,
      String? barcode,
      ) async {
    final box = await _pendingRestocksBoxInstance;

    final restockId = box.length + 1;

    final restockData = {
      'id': restockId,
      'productId': productId,
      'quantity': quantity,
      'barcode': barcode,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'sync_attempts': 0,
    };

    await box.put(restockId.toString(), restockData);

    return restockId;
  }

  Future<List<Map<String, dynamic>>> getPendingRestocks() async {
    final box = await _pendingRestocksBoxInstance;

    try {
      final allRestocks = box.values.toList();
      return allRestocks
          .where((restock) => restock['sync_status'] == 'pending')
          .toList();
    } catch (e) {
      debugPrint('Error loading pending restocks: $e');
      return [];
    }
  }

  Future<void> updatePendingRestockStatus(
      int restockId,
      String status, {
        int attempts = 0,
      }) async {
    final box = await _pendingRestocksBoxInstance;

    try {
      final restockData = box.get(restockId.toString());
      if (restockData != null) {
        restockData['sync_status'] = status;
        restockData['sync_attempts'] = attempts;
        restockData['last_sync_attempt'] = DateTime.now().toIso8601String();
        await box.put(restockId.toString(), restockData);
      }
    } catch (e) {
      debugPrint('Error updating pending restock: $e');
    }
  }

  Future<void> deletePendingRestock(int restockId) async {
    final box = await _pendingRestocksBoxInstance;

    try {
      await box.delete(restockId.toString());
    } catch (e) {
      debugPrint('Error deleting pending restock: $e');
    }
  }

  // Cleanup method
  Future<void> close() async {
    try {
      if (Hive.isBoxOpen(_pendingReturnsBox)) await Hive.box<Map<String, dynamic>>(_pendingReturnsBox).close();
      if (Hive.isBoxOpen(_syncedReturnsBox)) await Hive.box<Map<String, dynamic>>(_syncedReturnsBox).close();
      if (Hive.isBoxOpen(productsBox)) await Hive.box<Product>(productsBox).close();
      if (Hive.isBoxOpen(_cartBox)) await Hive.box<CartItem>(_cartBox).close();
      if (Hive.isBoxOpen(_pendingOrdersBox)) await Hive.box<Map<String, dynamic>>(_pendingOrdersBox).close();
      if (Hive.isBoxOpen(_pendingRestocksBox)) await Hive.box<Map<String, dynamic>>(_pendingRestocksBox).close();
      if (Hive.isBoxOpen(_cacheTimestampBox)) await Hive.box<int>(_cacheTimestampBox).close();
      if (Hive.isBoxOpen(_customersBox)) await Hive.box<Customer>(_customersBox).close();
      if (Hive.isBoxOpen(_dashboardDataBox)) await Hive.box<Map<String, dynamic>>(_dashboardDataBox).close();
      if (Hive.isBoxOpen(_dashboardCacheTimestampBox)) await Hive.box<int>(_dashboardCacheTimestampBox).close();
      if (Hive.isBoxOpen(_categoriesBox)) await Hive.box<Category>(_categoriesBox).close();
      if (Hive.isBoxOpen(_categoriesTimestampBox)) await Hive.box<int>(_categoriesTimestampBox).close();

      debugPrint('✅ All Hive boxes closed');
    } catch (e) {
      debugPrint('❌ Error closing Hive boxes: $e');
    }
  }
}class OfflineDashboardData {
  final DashboardStats stats;
  final List<RevenueDataPoint> revenueData;
  final DateTime lastUpdated;
  final String tenantId;

  OfflineDashboardData({
    required this.stats,
    required this.revenueData,
    required this.lastUpdated,
    required this.tenantId,
  });

  Map<String, dynamic> toJson() {
    return {
      'stats': {
        'totalRevenue': stats.totalRevenue,
        'todayRevenue': stats.todayRevenue,
        'totalSales': stats.totalSales,
        'todaySales': stats.todaySales,
        'totalProducts': stats.totalProducts,
        'lowStockProducts': stats.lowStockProducts,
        'totalCustomers': stats.totalCustomers,
        'todayCustomers': stats.todayCustomers,
        'averageOrderValue': stats.averageOrderValue,
        'conversionRate': stats.conversionRate,
        'revenueGrowth': stats.revenueGrowth,
        'salesGrowth': stats.salesGrowth,
        'todayReturns': stats.todayReturns,
        'totalReturns': stats.totalReturns,
      },
      // 'recentOrders': recentOrders.map((order) => order.toFirestore()).toList(),
      'revenueData': revenueData.map((point) => {
        'date': point.date.toIso8601String(),
        'revenue': point.revenue,
        'orders': point.orders,
      }).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'tenantId': tenantId,
    };
  }

  factory OfflineDashboardData.fromJson(Map<String, dynamic> json) {
    return OfflineDashboardData(
      stats: DashboardStats(
        totalRevenue: json['stats']['totalRevenue'] ?? 0.0,
        todayRevenue: json['stats']['todayRevenue'] ?? 0.0,
        totalSales: json['stats']['totalSales'] ?? 0,
        todaySales: json['stats']['todaySales'] ?? 0,
        totalProducts: json['stats']['totalProducts'] ?? 0,
        lowStockProducts: json['stats']['lowStockProducts'] ?? 0,
        totalCustomers: json['stats']['totalCustomers'] ?? 0,
        todayCustomers: json['stats']['todayCustomers'] ?? 0,
        averageOrderValue: json['stats']['averageOrderValue'] ?? 0.0,
        conversionRate: json['stats']['conversionRate'] ?? 0.0,
        revenueGrowth: json['stats']['revenueGrowth'] ?? 0.0,
        salesGrowth: json['stats']['salesGrowth'] ?? 0.0,
        todayReturns: json['stats']['todayReturns'] ?? 0,
        totalReturns: json['stats']['totalReturns'] ?? 0,
      ),

      revenueData: (json['revenueData'] as List<dynamic>).map((pointJson) {
        return RevenueDataPoint(
          date: DateTime.parse(pointJson['date']),
          revenue: pointJson['revenue'] ?? 0.0,
          orders: pointJson['orders'] ?? 0,
        );
      }).toList(),

      lastUpdated: DateTime.parse(json['lastUpdated']),
      tenantId: json['tenantId'] ?? '',
    );
  }
}
