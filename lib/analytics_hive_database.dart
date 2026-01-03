// analytics_hive_database.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_screen.dart';
import 'core/models/app_order_model.dart';
import 'core/models/category_model.dart';
import 'core/models/customer_model.dart';
import 'core/models/product_model.dart';

// Analytics-specific Hive boxes
enum AnalyticsBox {
  orders('analytics_orders'),
  customers('analytics_customers'),
  products('analytics_products'),
  categories('analytics_categories'),
  expenses('analytics_expenses'),
  analyticsCache('analytics_cache'),
  pendingSync('analytics_pending_sync');

  final String name;
  const AnalyticsBox(this.name);
}

class HiveAnalyticsDatabase {
  static HiveAnalyticsDatabase? _instance;
  factory HiveAnalyticsDatabase() => _instance ??= HiveAnalyticsDatabase._internal();
  HiveAnalyticsDatabase._internal();

  bool _isInitialized = false;
  String? _currentTenantId;
  final Map<String, Box> _openBoxes = {};

  Future<void> initialize({String? tenantId}) async {
    if (_isInitialized) return;

    // Initialize Hive with proper path
    await _initHive();

    // Open all analytics boxes
    await _openAllBoxes();

    _currentTenantId = tenantId;
    _isInitialized = true;
  }

  Future<void> _initHive() async {
    try {
      // Check if Hive is already initialized by trying to open a box
      try {
        // Try to access a box to see if Hive is initialized
        if (!Hive.isBoxOpen(AnalyticsBox.orders.name)) {
          // Hive needs initialization
          await Hive.initFlutter();
        }
      } catch (e) {
        // If accessing box fails, Hive is not initialized
        await Hive.initFlutter();
      }

      await _registerAdapters();
    } catch (e) {
      // If initFlutter fails, try with path provider
      try {
        final appDocumentDir = await getApplicationDocumentsDirectory();
        Hive.init(appDocumentDir.path);
        await _registerAdapters();
      } catch (e2) {
        throw Exception('Failed to initialize Hive: $e2');
      }
    }
  }

  Future<void> _openAllBoxes() async {
    for (var box in AnalyticsBox.values) {
      if (!Hive.isBoxOpen(box.name)) {
        final openedBox = await Hive.openBox(box.name);
        _openBoxes[box.name] = openedBox;
      } else {
        _openBoxes[box.name] = Hive.box(box.name);
      }
    }
  }

  Future<void> _registerAdapters() async {
    // Register AppOrder adapter if not already registered
    try {
      if (!Hive.isAdapterRegistered(9)) {
        Hive.registerAdapter(AppOrderAdapter());
      }

      if (!Hive.isAdapterRegistered(13)) {
        Hive.registerAdapter(CustomerAdapter());
      }

      if (!Hive.isAdapterRegistered(14)) {
        Hive.registerAdapter(ProductAdapter());
      }

      if (!Hive.isAdapterRegistered(12)) {
        Hive.registerAdapter(CategoryAdapter());
      }

      // Register BusinessExpense adapter
      if (!Hive.isAdapterRegistered(100)) {
        Hive.registerAdapter(BusinessExpenseAdapter());
      }
    } catch (e) {
      // Adapters might already be registered
    }
  }

  // Helper to get box with safety check
  Box _getBox(AnalyticsBox boxType) {
    if (!_isInitialized) {
      throw Exception('HiveAnalyticsDatabase not initialized. Call initialize() first.');
    }

    final box = _openBoxes[boxType.name];
    if (box == null || !box.isOpen) {
      throw Exception('Box ${boxType.name} is not open');
    }

    return box;
  }

  // Set current tenant context
  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }

  // Helper method to get tenant-specific key
  String _getTenantKey(String key) {
    return _currentTenantId != null ? '${_currentTenantId}_$key' : key;
  }

  // ========== ORDER OPERATIONS ==========
  Future<void> saveOrders(List<AppOrder> orders) async {
    final box = _getBox(AnalyticsBox.orders);

    for (var order in orders) {
      final tenantKey = _getTenantKey(order.id);
      await box.put(tenantKey, order);
    }

    // Update last sync timestamp
    await _updateLastSync('orders');
  }

  Future<List<AppOrder>> getOrders(DateTime startDate, DateTime endDate) async {
    final box = _getBox(AnalyticsBox.orders);

    // If no tenant ID is set, return empty
    if (_currentTenantId == null) return [];

    final allOrders = box.values.cast<AppOrder>().toList();
    final filteredOrders = allOrders.where((order) {
      // Filter by tenant
      if (!order.id.startsWith(_currentTenantId!)) return false;

      // Filter by date range
      return order.dateCreated.isAfter(startDate.subtract(const Duration(days: 1))) &&
          order.dateCreated.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    return filteredOrders;
  }

  Future<AppOrder?> getOrderById(String orderId) async {
    final box = _getBox(AnalyticsBox.orders);
    final tenantKey = _getTenantKey(orderId);
    return box.get(tenantKey);
  }

  // ========== CUSTOMER OPERATIONS ==========
  Future<void> saveCustomers(List<Customer> customers) async {
    final box = _getBox(AnalyticsBox.customers);

    for (var customer in customers) {
      final tenantKey = _getTenantKey(customer.id);
      await box.put(tenantKey, customer);
    }

    await _updateLastSync('customers');
  }

  Future<List<Customer>> getCustomers() async {
    final box = _getBox(AnalyticsBox.customers);

    if (_currentTenantId == null) return [];

    return box.values.cast<Customer>().where((customer) => customer.id.startsWith(_currentTenantId!)).toList();
  }

  Future<Customer?> getCustomerById(String customerId) async {
    final box = _getBox(AnalyticsBox.customers);
    final tenantKey = _getTenantKey(customerId);
    return box.get(tenantKey);
  }

  // ========== PRODUCT OPERATIONS ==========
  Future<void> saveProducts(List<Product> products) async {
    final box = _getBox(AnalyticsBox.products);

    for (var product in products) {
      final tenantKey = _getTenantKey(product.id);
      await box.put(tenantKey, product);
    }

    await _updateLastSync('products');
  }

  Future<List<Product>> getProducts() async {
    final box = _getBox(AnalyticsBox.products);

    if (_currentTenantId == null) return [];

    return box.values.cast<Product>().where((product) => product.id.startsWith(_currentTenantId!)).toList();
  }

  Future<Product?> getProductById(String productId) async {
    final box = _getBox(AnalyticsBox.products);
    final tenantKey = _getTenantKey(productId);
    return box.get(tenantKey);
  }

  // ========== CATEGORY OPERATIONS ==========
  Future<void> saveCategories(List<Category> categories) async {
    final box = _getBox(AnalyticsBox.categories);

    for (var category in categories) {
      final tenantKey = _getTenantKey(category.id);
      await box.put(tenantKey, category);
    }

    await _updateLastSync('categories');
  }

  Future<List<Category>> getCategories() async {
    final box = _getBox(AnalyticsBox.categories);

    if (_currentTenantId == null) return [];

    return box.values.cast<Category>().where((category) => category.id.startsWith(_currentTenantId!)).toList();
  }

  // ========== EXPENSE OPERATIONS ==========
  Future<void> saveExpense(BusinessExpense expense) async {
    final box = _getBox(AnalyticsBox.expenses);
    final tenantKey = _getTenantKey(expense.id);
    await box.put(tenantKey, expense);
    await _updateLastSync('expenses');
  }

  Future<void> deleteExpense(String expenseId) async {
    final box = _getBox(AnalyticsBox.expenses);
    final tenantKey = _getTenantKey(expenseId);
    await box.delete(tenantKey);
  }

  Future<List<BusinessExpense>> getExpenses(DateTime startDate, DateTime endDate) async {
    final box = _getBox(AnalyticsBox.expenses);

    if (_currentTenantId == null) return [];

    final allExpenses = box.values.cast<BusinessExpense>().toList();
    final filteredExpenses = allExpenses.where((expense) {
      // Filter by tenant
      if (!expense.id.startsWith(_currentTenantId!)) return false;

      // Filter by date range
      return expense.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    return filteredExpenses;
  }

  Future<Map<String, double>> getExpensesByCategory(DateTime startDate, DateTime endDate) async {
    final expenses = await getExpenses(startDate, endDate);
    final expensesByCategory = <String, double>{};

    for (final expense in expenses) {
      final category = expense.category;
      expensesByCategory[category] = (expensesByCategory[category] ?? 0.0) + expense.amount;
    }

    return expensesByCategory;
  }

  // ========== ANALYTICS CACHING ==========
  Future<void> cacheAnalytics(String periodKey, String analyticsType, dynamic data) async {
    final box = _getBox(AnalyticsBox.analyticsCache);
    final cacheKey = '${_currentTenantId}_${analyticsType}_$periodKey';
    await box.put(cacheKey, jsonEncode(data));

    // Store cache timestamp
    final timestampKey = '${cacheKey}_timestamp';
    await box.put(timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<dynamic> getCachedAnalytics(String periodKey, String analyticsType) async {
    final box = _getBox(AnalyticsBox.analyticsCache);
    final cacheKey = '${_currentTenantId}_${analyticsType}_$periodKey';
    final cachedData = box.get(cacheKey);

    if (cachedData != null) {
      // Check if cache is still valid (5 minutes)
      final timestampKey = '${cacheKey}_timestamp';
      final timestamp = box.get(timestampKey, defaultValue: 0);
      final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;

      if (cacheAge < 5 * 60 * 1000) { // 5 minutes in milliseconds
        return jsonDecode(cachedData);
      }
    }

    return null;
  }

  Future<void> clearAnalyticsCache() async {
    final box = _getBox(AnalyticsBox.analyticsCache);

    // Clear only current tenant's cache
    final keysToRemove = box.keys
        .where((key) => key.toString().startsWith(_currentTenantId ?? ''))
        .toList();

    for (var key in keysToRemove) {
      await box.delete(key);
    }
  }

  // ========== PENDING SYNC OPERATIONS ==========
  Future<void> addPendingSync(String operationType, dynamic data) async {
    final box = _getBox(AnalyticsBox.pendingSync);
    final syncKey = '${_currentTenantId}_${DateTime.now().millisecondsSinceEpoch}_$operationType';
    await box.put(syncKey, jsonEncode({
      'type': operationType,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'tenantId': _currentTenantId,
    }));
  }

  Future<List<Map<String, dynamic>>> getPendingSyncs() async {
    final box = _getBox(AnalyticsBox.pendingSync);

    return box.values
        .where((value) {
      try {
        final data = jsonDecode(value as String);
        return data['tenantId'] == _currentTenantId;
      } catch (e) {
        return false;
      }
    })
        .map((value) => jsonDecode(value as String) as Map<String, dynamic>)
        .toList();
  }

  Future<void> removePendingSync(String syncKey) async {
    final box = _getBox(AnalyticsBox.pendingSync);
    await box.delete(syncKey);
  }

  // ========== SYNC STATUS ==========
  Future<void> _updateLastSync(String dataType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_currentTenantId}_lastSync_$dataType';
    await prefs.setString(key, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSync(String dataType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_currentTenantId}_lastSync_$dataType';
    final dateString = prefs.getString(key);

    if (dateString != null) {
      return DateTime.tryParse(dateString);
    }

    return null;
  }

  Future<bool> needsSync(String dataType, {Duration maxAge = const Duration(hours: 1)}) async {
    final lastSync = await getLastSync(dataType);

    if (lastSync == null) return true;

    final age = DateTime.now().difference(lastSync);
    return age > maxAge;
  }

  // ========== UTILITY METHODS ==========
  Future<void> clearAllData() async {
    for (var box in AnalyticsBox.values) {
      await _getBox(box).clear();
    }

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.contains(_currentTenantId ?? ''));
    for (var key in keys) {
      await prefs.remove(key);
    }
  }

  Future<int> getDataCount(String dataType) async {
    final box = switch (dataType) {
      'orders' => _getBox(AnalyticsBox.orders),
      'customers' => _getBox(AnalyticsBox.customers),
      'products' => _getBox(AnalyticsBox.products),
      'categories' => _getBox(AnalyticsBox.categories),
      'expenses' => _getBox(AnalyticsBox.expenses),
      _ => _getBox(AnalyticsBox.orders),
    };

    if (_currentTenantId == null) return 0;

    return box.values
        .where((item) {
      if (item is AppOrder) return item.id.startsWith(_currentTenantId!);
      if (item is Customer) return item.id.startsWith(_currentTenantId!);
      if (item is Product) return item.id.startsWith(_currentTenantId!);
      if (item is Category) return item.id.startsWith(_currentTenantId!);
      if (item is BusinessExpense) return item.id.startsWith(_currentTenantId!);
      return false;
    })
        .length;
  }

  // Generate unique ID for local data
  String generateLocalId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'local_${_currentTenantId}_${timestamp}_$random';
  }

  // Close all boxes
  Future<void> close() async {
    for (var box in _openBoxes.values) {
      await box.close();
    }
    _openBoxes.clear();
    _isInitialized = false;
  }

  // Check if database is ready
  bool get isReady => _isInitialized;
}

// BusinessExpense Hive Adapter
class BusinessExpenseAdapter extends TypeAdapter<BusinessExpense> {
  @override
  final int typeId = 100; // Unique ID for BusinessExpense

  @override
  BusinessExpense read(BinaryReader reader) {
    final id = reader.readString();
    final category = reader.readString();
    final description = reader.readString();
    final amount = reader.readDouble();
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final notes = reader.readString();

    return BusinessExpense(
      id: id,
      category: category,
      description: description,
      amount: amount,
      date: date,
      notes: notes,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessExpense obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.category);
    writer.writeString(obj.description);
    writer.writeDouble(obj.amount);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeString(obj.notes ?? '');
  }
}
