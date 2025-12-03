import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../core/models/app_order_model.dart';
import '../../core/models/cart_item_model.dart';
import '../../core/models/category_model.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/product_model.dart';
import '../clientDashboard/client_dashboard.dart';
import '../customerBase/customer_base.dart';
import '../returnBase/return_base.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static const String _dashboardDataKey = 'dashboard_data';
  static const String _dashboardCacheTimestampKey = 'dashboard_cache_timestamp';
  static const Duration _dashboardCacheDuration = Duration(hours: 1);
  // Add these category constants and methods
  static const String _categoriesKey = 'categories';
  static const String _categoriesTimestampKey = 'categories_cache_timestamp';

  // Category operations
  Future<List<Category>> getAllCategories() async {
    try {
      final prefs = await _prefs;
      final categoriesJson = prefs.getString(_categoriesKey);

      if (categoriesJson == null) return [];

      final List<dynamic> jsonList = json.decode(categoriesJson);
      return jsonList.map((json) {
        final data = Map<String, dynamic>.from(json);
        final id = data['id']?.toString() ?? '';
        return Category.fromFirestore(data, id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting local categories: $e');
      return [];
    }
  }

  Future<String> saveCategory(Category category) async {
    try {
      final prefs = await _prefs;
      final existingCategories = await getAllCategories();

      // Check if category already exists (for update)
      final categoryIndex = existingCategories.indexWhere((cat) => cat.id == category.id);
      final List<Category> updatedCategories;

      if (categoryIndex != -1) {
        // Update existing category
        updatedCategories = List.from(existingCategories);
        updatedCategories[categoryIndex] = category;
      } else {
        // Add new category
        updatedCategories = [...existingCategories, category];
      }

      // Save back to shared preferences
      final categoriesJson = updatedCategories.map((cat) {
        final data = cat.toFirestore();
        data['id'] = cat.id; // Ensure ID is included
        return data;
      }).toList();

      await prefs.setString(_categoriesKey, json.encode(categoriesJson));
      await prefs.setInt(
        _categoriesTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      return category.id;
    } catch (e) {
      debugPrint('Error saving category locally: $e');
      throw Exception('Failed to save category locally: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      final prefs = await _prefs;
      final existingCategories = await getAllCategories();

      // Remove the category
      final updatedCategories = existingCategories
          .where((cat) => cat.id != categoryId)
          .toList();

      // Save back to shared preferences
      final categoriesJson = updatedCategories.map((cat) {
        final data = cat.toFirestore();
        data['id'] = cat.id;
        return data;
      }).toList();

      await prefs.setString(_categoriesKey, json.encode(categoriesJson));
      await prefs.setInt(
        _categoriesTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Error deleting category locally: $e');
      throw Exception('Failed to delete category locally: $e');
    }
  }

  Stream<List<Category>> getCategoriesStream() {
    // Create a stream that emits categories when they change
    return Stream.periodic(Duration(seconds: 2)).asyncMap((_) => getAllCategories());
  }

  Future<Category?> getCategoryById(String categoryId) async {
    final categories = await getAllCategories();
    try {
      return categories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveCategories(List<Category> categories) async {
    try {
      final prefs = await _prefs;

      // Save categories
      final categoriesJson = categories.map((cat) {
        final data = cat.toFirestore();
        data['id'] = cat.id;
        return data;
      }).toList();

      await prefs.setString(_categoriesKey, json.encode(categoriesJson));
      await prefs.setInt(
        _categoriesTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('Saved ${categories.length} categories to local storage');
    } catch (e) {
      debugPrint('Error saving categories locally: $e');
      throw Exception('Failed to save categories locally: $e');
    }
  }

  Future<void> clearCategories() async {
    final prefs = await _prefs;
    await prefs.remove(_categoriesKey);
    await prefs.remove(_categoriesTimestampKey);
  }
  // Dashboard operations
  Future<void> saveDashboardData(OfflineDashboardData data) async {
    final prefs = await _prefs;
    final dashboardData = data.toJson();
    await prefs.setString(_dashboardDataKey, json.encode(dashboardData));
    await prefs.setInt(
      _dashboardCacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

// In LocalDatabase class - ADD optimized methods
  Future<OfflineDashboardData?> getDashboardData(String tenantId) async {
    final prefs = await _prefs;
    final dashboardDataJson = prefs.getString(_dashboardDataKey);
    final timestamp = prefs.getInt(_dashboardCacheTimestampKey);

    if (dashboardDataJson == null || timestamp == null) {
      return null;
    }

    try {
      final Map<String, dynamic> jsonData = json.decode(dashboardDataJson);
      final data = OfflineDashboardData.fromJson(jsonData);

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

// ADD quick offline stats generation
  Future<DashboardStats> getQuickOfflineStats() async {
    final pendingOrders = await getPendingOrders();
    final products = await getAllProducts();

    double totalRevenue = 0.0;
    for (final order in pendingOrders) {
      final orderData = order['order_data'] as Map<String, dynamic>;
      totalRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
    }

    return DashboardStats(
      totalRevenue: totalRevenue,
      todayRevenue: totalRevenue, // Simplified for quick load
      totalSales: pendingOrders.length,
      todaySales: pendingOrders.length,
      totalProducts: products.length,
      lowStockProducts: products.where((p) => p.stockQuantity <= 10).length,
      totalCustomers: 0, // Simplified
      todayCustomers: 0,
      averageOrderValue: pendingOrders.isNotEmpty ? totalRevenue / pendingOrders.length : 0,
      conversionRate: 0,
      revenueGrowth: 0,
      salesGrowth: 0,
      todayReturns: 0,
      totalReturns: 0,
    );
  }
  Future<void> clearDashboardData() async {
    final prefs = await _prefs;
    await prefs.remove(_dashboardDataKey);
    await prefs.remove(_dashboardCacheTimestampKey);
  }

  // Helper method to check if we have recent dashboard data
  Future<bool> hasRecentDashboardData(String tenantId) async {
    final data = await getDashboardData(tenantId);
    return data != null;
  }

  // Enhanced product operations for dashboard
  Future<List<Product>> getLowStockProducts() async {
    final products = await getAllProducts();
    return products
        .where((product) => product.stockQuantity <= 10)
        .toList();
  }

  // Enhanced customer operations for dashboard
  Future<List<Customer>> getRecentCustomers({int limit = 5}) async {
    final customers = await getCustomers();
    customers.sort((a, b) => (b.dateCreated ?? DateTime(0)).compareTo(a.dateCreated ?? DateTime(0)));
    return customers.take(limit).toList();
  }

  // Generate revenue data from offline orders
  Future<List<RevenueDataPoint>> generateRevenueData() async {
    final pendingOrders = await getPendingOrders();
    final now = DateTime.now();
    final List<RevenueDataPoint> revenueData = [];

    // Generate last 7 days data
    for (int i = 6; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      double dayRevenue = 0.0;
      int dayOrders = 0;

      // Calculate revenue from pending orders for this day
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

  // Generate top selling products from offline orders
  Future<List<TopSellingProduct>> generateTopSellingProducts() async {
    final pendingOrders = await getPendingOrders();
    final productSales = <String, TopSellingProduct>{};

    for (final order in pendingOrders) {
      final orderData = order['order_data'] as Map<String, dynamic>;
      final lineItems = orderData['line_items'] as List<dynamic>? ?? [];

      for (final item in lineItems) {
        final itemMap = item as Map<String, dynamic>;
        final productId = itemMap['product_id']?.toString() ?? '';
        final productName = itemMap['product_name']?.toString() ?? 'Unknown Product';
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
        final price = (itemMap['price'] as num?)?.toDouble() ?? 0.0;

        if (productId.isNotEmpty) {
          if (productSales.containsKey(productId)) {
            final existing = productSales[productId]!;
            productSales[productId] = TopSellingProduct(
              productId: productId,
              productName: productName,
              totalSold: existing.totalSold + quantity,
              totalRevenue: existing.totalRevenue + (price * quantity),
              imageUrl: existing.imageUrl,
            );
          } else {
            // Try to get product image from cached products
            String? imageUrl;
            try {
              final product = await getProductById(productId);
              imageUrl = product?.imageUrl;
            } catch (e) {
              debugPrint('Error getting product image: $e');
            }

            productSales[productId] = TopSellingProduct(
              productId: productId,
              productName: productName,
              totalSold: quantity,
              totalRevenue: price * quantity,
              imageUrl: imageUrl,
            );
          }
        }
      }
    }

    final sortedList = productSales.values.toList();
    sortedList.sort((a, b) => b.totalSold.compareTo(a.totalSold));
    return sortedList.take(5).toList();
  }

  // Generate dashboard stats from offline data
  Future<DashboardStats> generateOfflineStats() async {
    final pendingOrders = await getPendingOrders();
    final products = await getAllProducts();
    final customers = await getCustomers();
    final pendingReturns = await getPendingReturns();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Calculate today's orders and revenue
    double todayRevenue = 0.0;
    int todaySales = 0;
    final todayCustomerIds = <String>{};

    for (final order in pendingOrders) {
      final orderDate = DateTime.parse(order['created_at']);
      if (orderDate.isAfter(todayStart)) {
        final orderData = order['order_data'] as Map<String, dynamic>;
        todayRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
        todaySales++;

        // Track today's customers
        final customerData = order['customer_data'] as Map<String, dynamic>?;
        if (customerData != null && customerData['customerId'] != null) {
          todayCustomerIds.add(customerData['customerId'].toString());
        }
      }
    }

    // Calculate total revenue and sales
    double totalRevenue = 0.0;
    for (final order in pendingOrders) {
      final orderData = order['order_data'] as Map<String, dynamic>;
      totalRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
    }

    // Calculate low stock products
    final lowStockProducts = products.where((p) => p.stockQuantity <= 10).length;

    // Calculate derived metrics
    final averageOrderValue = pendingOrders.isNotEmpty
        ? totalRevenue / pendingOrders.length
        : 0.0;
    final conversionRate = customers.isNotEmpty
        ? (pendingOrders.length / customers.length * 100).clamp(0.0, 100.0)
        : 0.0;

    // Calculate today's returns
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
      revenueGrowth: 0.0, // Can't calculate growth offline
      salesGrowth: 0.0,   // Can't calculate growth offline
      todayReturns: todayReturns,
      totalReturns: pendingReturns.length,
    );
  }
  static const String _pendingReturnsKey = 'pending_returns';
  static const String _syncedReturnsKey = 'synced_returns';

  static const String productsKey = 'cached_products';
  static const String _cartKey = 'cart_items';
  static const String _pendingOrdersKey = 'pending_orders';
  static const String _pendingRestocksKey = 'pending_restocks';
  static const String _cacheTimestampKey = 'cache_timestamp';

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();
  static const String _customersKey = 'cached_customers';

  // Return operations
  Future<int> savePendingReturn(ReturnRequest returnRequest) async {
    final prefs = await _prefs;
    final pendingReturnsJson = prefs.getString(_pendingReturnsKey);
    final List<dynamic> pendingReturns = pendingReturnsJson != null
        ? json.decode(pendingReturnsJson)
        : [];

    final returnId = pendingReturns.length + 1;
    final offlineId = 'offline_return_${DateTime.now().millisecondsSinceEpoch}';

    final returnData = returnRequest.toLocalMap();
    returnData['local_id'] = returnId;
    returnData['offline_id'] = offlineId;
    returnData['sync_status'] = 'pending';
    returnData['sync_attempts'] = 0;
    returnData['created_at'] = DateTime.now().toIso8601String();

    pendingReturns.add(returnData);
    await prefs.setString(_pendingReturnsKey, json.encode(pendingReturns));

    return returnId;
  }

  Future<List<Map<String, dynamic>>> getPendingReturns() async {
    final prefs = await _prefs;
    final pendingReturnsJson = prefs.getString(_pendingReturnsKey);

    if (pendingReturnsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(pendingReturnsJson);
      return jsonList
          .where((ret) => ret['sync_status'] == 'pending')
          .map((ret) => Map<String, dynamic>.from(ret))
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
    final prefs = await _prefs;
    final pendingReturnsJson = prefs.getString(_pendingReturnsKey);

    if (pendingReturnsJson == null) return;

    try {
      final List<dynamic> pendingReturns = json.decode(pendingReturnsJson);
      for (var i = 0; i < pendingReturns.length; i++) {
        if (pendingReturns[i]['local_id'] == returnId) {
          pendingReturns[i]['sync_status'] = status;
          pendingReturns[i]['sync_attempts'] = attempts;
          pendingReturns[i]['last_sync_attempt'] = DateTime.now()
              .toIso8601String();
          break;
        }
      }
      await prefs.setString(_pendingReturnsKey, json.encode(pendingReturns));
    } catch (e) {
      debugPrint('Error updating pending return: $e');
    }
  }

  Future<void> deletePendingReturn(int returnId) async {
    final prefs = await _prefs;
    final pendingReturnsJson = prefs.getString(_pendingReturnsKey);

    if (pendingReturnsJson == null) return;

    try {
      final List<dynamic> pendingReturns = json.decode(pendingReturnsJson);
      pendingReturns.removeWhere((ret) => ret['local_id'] == returnId);
      await prefs.setString(_pendingReturnsKey, json.encode(pendingReturns));
    } catch (e) {
      debugPrint('Error deleting pending return: $e');
    }
  }

  Future<void> saveSyncedReturn(ReturnRequest returnRequest) async {
    final prefs = await _prefs;
    final syncedReturnsJson = prefs.getString(_syncedReturnsKey);
    final List<dynamic> syncedReturns = syncedReturnsJson != null
        ? json.decode(syncedReturnsJson)
        : [];

    final returnData = returnRequest.toLocalMap();
    returnData['synced_at'] = DateTime.now().toIso8601String();

    syncedReturns.add(returnData);
    await prefs.setString(_syncedReturnsKey, json.encode(syncedReturns));
  }

  Future<List<ReturnRequest>> getSyncedReturns() async {
    final prefs = await _prefs;
    final syncedReturnsJson = prefs.getString(_syncedReturnsKey);

    if (syncedReturnsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(syncedReturnsJson);
      return jsonList
          .map(
            (json) =>
            ReturnRequest.fromLocalMap(Map<String, dynamic>.from(json)),
      )
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

    // Sort by date created (newest first)
    allReturns.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));

    return allReturns;
  }

  // Customer operations
  Future<void> saveCustomers(List<Customer> customers) async {
    final prefs = await _prefs;
    final customersJson = customers
        .map((customer) => customer.toFirestore())
        .toList();
    await prefs.setString(_customersKey, json.encode(customersJson));
  }

  Future<List<Customer>> getCustomers() async {
    final prefs = await _prefs;
    final customersJson = prefs.getString(_customersKey);

    if (customersJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(customersJson);
      return jsonList.map((json) {
        final id = json['id']?.toString() ?? '';
        return Customer.fromFirestore(json, id);
      }).toList();
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
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);
    final List<dynamic> pendingOrders = pendingOrdersJson != null
        ? json.decode(pendingOrdersJson)
        : [];

    final orderId = pendingOrders.length + 1;

    // Calculate enhanced pricing data
    final subtotal = cartItems.fold(
      0.0,
          (sum, item) => sum + item.baseSubtotal,
    );
    final itemDiscounts = cartItems.fold(
      0.0,
          (sum, item) => sum + item.discountAmount,
    );

    // Extract cart-level discounts from additionalData
    final cartDiscount = additionalData?['cartData']?['cartDiscount'] ?? 0.0;
    final cartDiscountPercent =
        additionalData?['cartData']?['cartDiscountPercent'] ?? 0.0;
    final cartDiscountAmount =
        cartDiscount + (subtotal * cartDiscountPercent / 100);

    final totalDiscount = itemDiscounts + cartDiscountAmount;
    final taxableAmount = subtotal - totalDiscount;

    // Extract tax rate from additionalData or use default
    final taxRate = additionalData?['cartData']?['taxRate'] ?? 0.0;
    final taxAmount = taxableAmount * taxRate / 100;

    // Extract additional charges
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
            'base_price': item.product.price, // Original price
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
        'total': finalTotal, // Use the calculated final total
        'original_total': subtotal, // Original total without any discounts
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
      'version': '2.0', // Version to identify enhanced order format
    };

    // Add additional data if provided
    if (additionalData != null) {
      orderData['additional_data'] = additionalData;
    }

    pendingOrders.add(orderData);
    await prefs.setString(_pendingOrdersKey, json.encode(pendingOrders));

    debugPrint(
      'Saved enhanced pending order #$orderId with total: ${Constants.CURRENCY_NAME}$finalTotal',
    );

    return orderId;
  } // Product operations

  // In LocalDatabase class - REPLACE the saveProducts method
  Future<void> saveProducts(List<Product> products) async {
    final prefs = await _prefs;
    debugPrint('💾 Saving ${products.length} products to local storage');

    // Get existing products first
    final existingProductsJson = prefs.getString(productsKey);
    final Map<String, Product> existingProductsMap = {};

    if (existingProductsJson != null) {
      try {
        final List<dynamic> existingJsonList = json.decode(existingProductsJson);
        for (var json in existingJsonList) {
          final id = json['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            existingProductsMap[id] = Product.fromFirestore(json, id);
          }
        }
        debugPrint('📁 Found ${existingProductsMap.length} existing products in cache');
      } catch (e) {
        debugPrint('❌ Error loading existing products for merge: $e');
      }
    }

    // Merge new products with existing ones - UPDATE EXISTING, ADD NEW
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

    // Convert back to list and save
    final mergedProducts = existingProductsMap.values.toList();
    final productsJson = mergedProducts.map((p) {
      final data = p.toFirestore();
      data['id'] = p.id; // Ensure ID is included
      return data;
    }).toList();

    await prefs.setString(productsKey, json.encode(productsJson));
    await prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );

    debugPrint('✅ Successfully saved ${mergedProducts.length} products to local storage');
  }
  // In LocalDatabase class - ADD this method
  Future<List<Product>> getAllProducts() async {
    final prefs = await _prefs;
    final productsJson = prefs.getString(productsKey);

    if (productsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(productsJson);
      return jsonList.map((json) {
        final id = json['id']?.toString() ?? '';
        return Product.fromFirestore(json, id);
      }).toList();
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
    final prefs = await _prefs;
    final productsJson = prefs.getString(productsKey);

    if (productsJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(productsJson);
      var products = jsonList.map((json) {
        final id = json['id']?.toString() ?? '';
        return Product.fromFirestore(json, id);
      }).toList();

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
    final products = await getProducts();
    try {
      return products.firstWhere((product) => product.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<Product?> getProductBySku(String sku) async {
    final products = await getProducts();
    try {
      return products.firstWhere((product) => product.sku == sku);
    } catch (e) {
      return null;
    }
  }

  // Cart operations
  Future<void> saveCartItems(List<CartItem> items) async {
    final prefs = await _prefs;
    final cartJson = items.map((item) {
      final productData = item.product.toFirestore();
      productData['id'] = item.product.id;
      return {'product': productData, 'quantity': item.quantity};
    }).toList();
    await prefs.setString(_cartKey, json.encode(cartJson));
  }

  Future<List<CartItem>> getCartItems() async {
    final prefs = await _prefs;
    final cartJson = prefs.getString(_cartKey);

    if (cartJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(cartJson);
      return jsonList.map((json) {
        final productData = json['product'] as Map<String, dynamic>;
        final productId = productData['id']?.toString() ?? '';
        final product = Product.fromFirestore(productData, productId);
        return CartItem(product: product, quantity: json['quantity']);
      }).toList();
    } catch (e) {
      debugPrint('Error loading cart: $e');
      return [];
    }
  }

  Future<void> clearCart() async {
    final prefs = await _prefs;
    await prefs.remove(_cartKey);
  }

  // Pending orders operations
  Future<int> savePendingOrder(List<CartItem> cartItems) async {
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);
    final List<dynamic> pendingOrders = pendingOrdersJson != null
        ? json.decode(pendingOrdersJson)
        : [];

    final orderId = pendingOrders.length + 1;

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
          },
        )
            .toList(),
        'total': cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
      },
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'sync_attempts': 0,
    };

    pendingOrders.add(orderData);
    await prefs.setString(_pendingOrdersKey, json.encode(pendingOrders));

    return orderId;
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);

    if (pendingOrdersJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(pendingOrdersJson);
      return jsonList
          .where((order) => order['sync_status'] == 'pending')
          .map((order) => Map<String, dynamic>.from(order))
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
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);

    if (pendingOrdersJson == null) return;

    try {
      final List<dynamic> pendingOrders = json.decode(pendingOrdersJson);
      for (var i = 0; i < pendingOrders.length; i++) {
        if (pendingOrders[i]['id'] == orderId) {
          pendingOrders[i]['sync_status'] = status;
          pendingOrders[i]['sync_attempts'] = attempts;
          pendingOrders[i]['last_sync_attempt'] = DateTime.now()
              .toIso8601String();
          break;
        }
      }
      await prefs.setString(_pendingOrdersKey, json.encode(pendingOrders));
    } catch (e) {
      debugPrint('Error updating pending order: $e');
    }
  }

  Future<void> deletePendingOrder(int orderId) async {
    final prefs = await _prefs;
    final pendingOrdersJson = prefs.getString(_pendingOrdersKey);

    if (pendingOrdersJson == null) return;

    try {
      final List<dynamic> pendingOrders = json.decode(pendingOrdersJson);
      pendingOrders.removeWhere((order) => order['id'] == orderId);
      await prefs.setString(_pendingOrdersKey, json.encode(pendingOrders));
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
    final prefs = await _prefs;
    final pendingRestocksJson = prefs.getString(_pendingRestocksKey);
    final List<dynamic> pendingRestocks = pendingRestocksJson != null
        ? json.decode(pendingRestocksJson)
        : [];

    final restockId = pendingRestocks.length + 1;

    final restockData = {
      'id': restockId,
      'productId': productId,
      'quantity': quantity,
      'barcode': barcode,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
      'sync_attempts': 0,
    };

    pendingRestocks.add(restockData);
    await prefs.setString(_pendingRestocksKey, json.encode(pendingRestocks));

    return restockId;
  }

  Future<List<Map<String, dynamic>>> getPendingRestocks() async {
    final prefs = await _prefs;
    final pendingRestocksJson = prefs.getString(_pendingRestocksKey);

    if (pendingRestocksJson == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(pendingRestocksJson);
      return jsonList
          .where((restock) => restock['sync_status'] == 'pending')
          .map((restock) => Map<String, dynamic>.from(restock))
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
    final prefs = await _prefs;
    final pendingRestocksJson = prefs.getString(_pendingRestocksKey);

    if (pendingRestocksJson == null) return;

    try {
      final List<dynamic> pendingRestocks = json.decode(pendingRestocksJson);
      for (var i = 0; i < pendingRestocks.length; i++) {
        if (pendingRestocks[i]['id'] == restockId) {
          pendingRestocks[i]['sync_status'] = status;
          pendingRestocks[i]['sync_attempts'] = attempts;
          pendingRestocks[i]['last_sync_attempt'] = DateTime.now()
              .toIso8601String();
          break;
        }
      }
      await prefs.setString(_pendingRestocksKey, json.encode(pendingRestocks));
    } catch (e) {
      debugPrint('Error updating pending restock: $e');
    }
  }

  Future<void> deletePendingRestock(int restockId) async {
    final prefs = await _prefs;
    final pendingRestocksJson = prefs.getString(_pendingRestocksKey);

    if (pendingRestocksJson == null) return;

    try {
      final List<dynamic> pendingRestocks = json.decode(pendingRestocksJson);
      pendingRestocks.removeWhere((restock) => restock['id'] == restockId);
      await prefs.setString(_pendingRestocksKey, json.encode(pendingRestocks));
    } catch (e) {
      debugPrint('Error deleting pending restock: $e');
    }
  }
}
class OfflineDashboardData {
  final DashboardStats stats;
  final List<AppOrder> recentOrders;
  final List<Product> lowStockProducts;
  final List<RevenueDataPoint> revenueData;
  final List<TopSellingProduct> topSellingProducts;
  final List<Customer> recentCustomers;
  final DateTime lastUpdated;
  final String tenantId;

  OfflineDashboardData({
    required this.stats,
    required this.recentOrders,
    required this.lowStockProducts,
    required this.revenueData,
    required this.topSellingProducts,
    required this.recentCustomers,
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
      'lowStockProducts': lowStockProducts.map((product) => product.toFirestore()).toList(),
      'revenueData': revenueData.map((point) => {
        'date': point.date.toIso8601String(),
        'revenue': point.revenue,
        'orders': point.orders,
      }).toList(),
      'topSellingProducts': topSellingProducts.map((product) => {
        'productId': product.productId,
        'productName': product.productName,
        'totalSold': product.totalSold,
        'totalRevenue': product.totalRevenue,
        'imageUrl': product.imageUrl,
      }).toList(),
      'recentCustomers': recentCustomers.map((customer) => customer.toFirestore()).toList(),
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
      recentOrders: (json['recentOrders'] as List<dynamic>).map((orderJson) {
        return AppOrder.fromFirestore(Map<String, dynamic>.from(orderJson), '');
      }).toList(),
      lowStockProducts: (json['lowStockProducts'] as List<dynamic>).map((productJson) {
        final id = productJson['id']?.toString() ?? '';
        return Product.fromFirestore(Map<String, dynamic>.from(productJson), id);
      }).toList(),
      revenueData: (json['revenueData'] as List<dynamic>).map((pointJson) {
        return RevenueDataPoint(
          date: DateTime.parse(pointJson['date']),
          revenue: pointJson['revenue'] ?? 0.0,
          orders: pointJson['orders'] ?? 0,
        );
      }).toList(),
      topSellingProducts: (json['topSellingProducts'] as List<dynamic>).map((productJson) {
        return TopSellingProduct(
          productId: productJson['productId'] ?? '',
          productName: productJson['productName'] ?? '',
          totalSold: productJson['totalSold'] ?? 0,
          totalRevenue: productJson['totalRevenue'] ?? 0.0,
          imageUrl: productJson['imageUrl'],
        );
      }).toList(),
      recentCustomers: (json['recentCustomers'] as List<dynamic>).map((customerJson) {
        final id = customerJson['id']?.toString() ?? '';
        return Customer.fromFirestore(Map<String, dynamic>.from(customerJson), id);
      }).toList(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      tenantId: json['tenantId'] ?? '',
    );
  }
}
