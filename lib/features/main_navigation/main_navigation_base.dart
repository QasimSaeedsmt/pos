
import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import '../../analytics_screen.dart';
import '../../constants.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/auth/screens/settings_screen.dart';
import '../../printing/printing_setting_screen.dart';
import '../../sales/sales_management_screen.dart';
import '../cartBase/cart_base.dart';
import '../clientDashboard/client_dashboard.dart';
import '../connectivityBase/local_db_base.dart';
import '../customerBase/customer_base.dart';
import '../orderBase/order_base.dart';
import '../product_addition_restock_base/product_addition_restock_base.dart';
import '../product_selling/product_selling_base.dart';
import '../profile.dart';
import '../returnBase/return_base.dart';
import '../ticketing/ticketing.dart';
import '../users/users_base.dart';
class NavigationService {
  String? _currentTenantId;

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }

  CollectionReference get productsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('products');

  CollectionReference get customersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('customers');


  static final NavigationService _instance = NavigationService._internal();

  factory NavigationService() => _instance;
  NavigationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Customer>> searchCustomers(String query) async {
    if (query.isEmpty) return [];

    final snapshot = await customersRef
        .where('searchKeywords', arrayContains: query.toLowerCase())
        .limit(20)
        .get();

    return snapshot.docs
        .map(
          (doc) => Customer.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      ),
    )
        .toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final doc = await customersRef.doc(id).get();
    if (doc.exists) {
      return Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<Customer?> getCustomerByEmail(String email) async {
    final snapshot = await customersRef
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<String> addCustomer(Customer customer) async {
    try {
      final customerData = customer.toFirestore();
      final docRef = customersRef.doc();
      await docRef.set(customerData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add customer: $e');
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      final customerData = customer.toFirestore();
      await customersRef.doc(customer.id).update(customerData);
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }


  // Future<bool> testConnection() async {
  //   try {
  //     await productsRef.limit(1).get();
  //     return true;
  //   } catch (e) {
  //     return false;
  //   }
  // }
}
class EnhancedPOSService {
  final FirestoreServices _firestore = FirestoreServices();

  void setTenantContext(String tenantId) {
    _firestore.setTenantId(tenantId);
  }

  Future<OrderCreationResult> createOrderWithCustomer(
      List<CartItem> cartItems,
      CustomerSelection customerSelection, {
        Map<String, dynamic>? additionalData,
      }) async {
    if (_isOnline) {
      try {
        final order = await _firestore.createOrderWithCustomer(
          cartItems,
          customerSelection,
        );

        // Apply additional data if provided
        if (additionalData != null) {
          await _firestore.ordersRef.doc(order.id).update({
            'additionalData': additionalData,
            'dateModified': FieldValue.serverTimestamp(),
          });
        }

        return OrderCreationResult.success(order);
      } catch (e) {
        print('Online order creation failed, saving locally: $e');
        return await _createOfflineOrderWithCustomer(
          cartItems,
          customerSelection,
          additionalData: additionalData,
        );
      }
    } else {
      return await _createOfflineOrderWithCustomer(
        cartItems,
        customerSelection,
        additionalData: additionalData,
      );
    }
  }

  Future<OrderCreationResult> _createOfflineOrderWithCustomer(
      List<CartItem> cartItems,
      CustomerSelection customerSelection, {
        Map<String, dynamic>? additionalData,
      }) async {
    try {
      // Update local stock quantities
      for (final item in cartItems) {
        await _updateLocalProductStock(item.product.id, -item.quantity);
      }

      final pendingOrderId = await _localDb.savePendingOrderWithCustomer(
        cartItems,
        customerSelection,
        additionalData: additionalData,
      );
      await _localDb.clearCart();
      return OrderCreationResult.offline(pendingOrderId);
    } catch (e) {
      return OrderCreationResult.error('Failed to save order locally: $e');
    }
  }

  // Get invoice settings
  Future<Map<String, dynamic>> getInvoiceSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'defaultTemplate':
      prefs.getString('default_invoice_template') ?? 'traditional',
      'taxRate': prefs.getDouble('tax_rate') ?? 0.0,
      'discountRate': prefs.getDouble('discount_rate') ?? 0.0,
      'autoPrint': prefs.getBool('auto_print') ?? false,
      'includeCustomerDetails':
      prefs.getBool('include_customer_details') ?? true,
      'defaultNotes':
      prefs.getString('default_notes') ?? 'Thank you for your business!',
    };
  }

  // Get business info
  Future<Map<String, dynamic>> getBusinessInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('business_name') ?? 'Your Business Name',
      'address': prefs.getString('business_address') ?? '',
      'phone': prefs.getString('business_phone') ?? '',
      'email': prefs.getString('business_email') ?? '',
      'website': prefs.getString('business_website') ?? '',
      'tagline': prefs.getString('business_tagline') ?? '',
      'taxNumber': prefs.getString('business_tax_number') ?? '',
    };
  }

  static final EnhancedPOSService _instance = EnhancedPOSService._internal();
  factory EnhancedPOSService() => _instance;
  EnhancedPOSService._internal();
  // In EnhancedPOSService class - REPLACE the existing return methods with these:
  // Enhanced Return operations with offline support
  Future<ReturnCreationResult> createReturn(ReturnRequest returnRequest) async {
    if (_isOnline) {
      try {
        final createdReturn = await _firestore.createReturn(returnRequest);
        // Save to local cache for offline access
        await _localDb.saveSyncedReturn(createdReturn);
        return ReturnCreationResult.success(createdReturn);
      } catch (e) {
        print('Online return creation failed, saving locally: $e');
        return await _createOfflineReturn(returnRequest);
      }
    } else {
      return await _createOfflineReturn(returnRequest);
    }
  }

  Future<ReturnCreationResult> _createOfflineReturn(
      ReturnRequest returnRequest,
      ) async {
    try {
      // Update local stock quantities for consistency
      for (final item in returnRequest.items) {
        await _updateLocalProductStock(item.productId, item.quantity);
      }

      final pendingReturnId = await _localDb.savePendingReturn(returnRequest);
      return ReturnCreationResult.offline(pendingReturnId.toString());
    } catch (e) {
      return ReturnCreationResult.error('Failed to save return locally: $e');
    }
  }

  Future<List<ReturnRequest>> getReturnsByOrder(String orderId) async {
    if (_isOnline) {
      try {
        final returns = await _firestore.getReturnsByOrder(orderId);
        // Cache the returns locally
        for (final returnReq in returns) {
          await _localDb.saveSyncedReturn(returnReq);
        }
        return returns;
      } catch (e) {
        print('Online fetch failed, using local data: $e');
        // Fall back to local data
        final allReturns = await _localDb.getAllReturns();
        return allReturns.where((ret) => ret.orderId == orderId).toList();
      }
    } else {
      final allReturns = await _localDb.getAllReturns();
      return allReturns.where((ret) => ret.orderId == orderId).toList();
    }
  }

  Stream<List<ReturnRequest>> getReturnsStream() {
    if (_isOnline) {
      return _firestore.getReturnsStream();
    } else {
      // Return a stream from local data
      return Stream.fromFuture(_localDb.getAllReturns());
    }
  }

  Future<List<ReturnRequest>> getAllReturns({int limit = 50}) async {
    if (_isOnline) {
      try {
        final returns = await _firestore.getAllReturns(limit: limit);
        // Cache returns locally
        for (final returnReq in returns) {
          await _localDb.saveSyncedReturn(returnReq);
        }
        return returns;
      } catch (e) {
        print('Online fetch failed, using local data: $e');
        return await _localDb.getAllReturns();
      }
    } else {
      return await _localDb.getAllReturns();
    }
  }

  Future<void> updateReturnStatus(
      String returnId,
      String status, {
        String? processedBy,
      }) async {
    if (_isOnline) {
      try {
        await _firestore.updateReturnStatus(
          returnId,
          status,
          processedBy: processedBy,
        );
      } catch (e) {
        print('Online status update failed: $e');
        throw Exception('Failed to update return status online: $e');
      }
    } else {
      throw Exception('Cannot update return status while offline');
    }
  }

  // Enhanced sync method to include returns
  Future<void> _syncPendingReturns() async {
    final pendingReturns = await _localDb.getPendingReturns();

    if (pendingReturns.isEmpty) {
      print('No pending returns to sync');
      return;
    }

    print('Syncing ${pendingReturns.length} pending returns...');

    for (final pendingReturn in pendingReturns) {
      try {
        final success = await _firestore.syncPendingReturn(pendingReturn);

        if (success) {
          await _localDb.deletePendingReturn(pendingReturn['local_id']);
          print(
            'Successfully synced pending return ${pendingReturn['local_id']}',
          );
        } else {
          await _localDb.updatePendingReturnStatus(
            pendingReturn['local_id'],
            'failed',
          );
          print('Failed to sync pending return ${pendingReturn['local_id']}');
        }
      } catch (e) {
        print('Error syncing pending return ${pendingReturn['local_id']}: $e');
        final attempts = (pendingReturn['sync_attempts'] as int? ?? 0) + 1;

        if (attempts >= 3) {
          await _localDb.updatePendingReturnStatus(
            pendingReturn['local_id'],
            'failed',
            attempts: attempts,
          );
        } else {
          await _localDb.updatePendingReturnStatus(
            pendingReturn['local_id'],
            'pending',
            attempts: attempts,
          );
        }
      }
    }
  }

  // Update the main sync method to include returns
  Future<void> _triggerSync() async {
    await _syncLock.synchronized(() async {
      try {
        await _syncPendingOrders();
        await _syncPendingRestocks();
        await _syncPendingReturns(); // Add this line
        await _syncProducts();
      } catch (e) {
        print('Sync error: $e');
      }
    });
  }
  // Enhanced Return operations

  // Add to EnhancedPOSService class
  Future<List<AppOrder>> searchOrders(String query) async {
    return await _firestore.searchOrders(query);
  }

  Future<AppOrder?> getOrderById(String orderId) async {
    return await _firestore.getOrderById(orderId);
  }

  Future<List<AppOrder>> getRecentOrders({int limit = 50}) async {
    return await _firestore.getRecentOrders(limit: limit);
  }

  // Customer management methods
  Future<List<Customer>> searchCustomers(String query) async {
    return await _firestore.searchCustomers(query);
  }

  Future<List<Customer>> getAllCustomers() async {
    try {
      if (_isOnline) {
        // Get all customers from Firestore
        final snapshot = await _firestore.customersRef
            .orderBy('firstName')
            .get();

        final customers = snapshot.docs
            .map(
              (doc) => Customer.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
            .toList();

        // Save to local cache for offline use
        await _localDb.saveCustomers(customers);
        return customers;
      } else {
        // Get customers from local database when offline
        return await _localDb.getCustomers();
      }
    } catch (e) {
      print('Error getting all customers: $e');
      // Fallback to local data if online fetch fails
      return await _localDb.getCustomers();
    }
  }

  Future<Customer?> getCustomerById(String id) async {
    return await _firestore.getCustomerById(id);
  }

  Future<Customer?> getCustomerByEmail(String email) async {
    return await _firestore.getCustomerByEmail(email);
  }

  Future<String> addCustomer(Customer customer) async {
    return await _firestore.addCustomer(customer);
  }

  Future<void> updateCustomer(Customer customer) async {
    await _firestore.updateCustomer(customer);
  }

  // Enhanced order creation

  final LocalDatabase _localDb = LocalDatabase();
  final Connectivity _connectivity = Connectivity();
  final Lock _syncLock = Lock();

  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void initialize() {
    _startConnectivityListener();
    _checkInitialConnection();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  // In EnhancedPOSService class - ADD this method
  Future<void> refreshLocalCache() async {
    if (_isOnline) {
      try {
        // Clear existing cache and fetch fresh data
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(LocalDatabase.productsKey);

        // Fetch fresh products
        await _syncProducts();
      } catch (e) {
        print('Error refreshing local cache: $e');
      }
    }
  }

  Future<void> _startConnectivityListener() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        List<ConnectivityResult> resultList,
        ) {
      final wasOnline = _isOnline;
      _isOnline = resultList.any((res) => res != ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        _triggerSync();
        refreshLocalCache(); // Add this line
      }
    });
  }

  Future<void> _checkInitialConnection() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    if (_isOnline) {
      _triggerSync();
    }
  }

  Stream<List<Product>> getProductsStream() {
    if (_isOnline) {
      return _firestore.getProductsStream();
    } else {
      return Stream.value([]);
    }
  }

  Future<List<Product>> fetchProducts({
    int limit = 50,
    String? lastDocumentId,
    String searchQuery = '',
    bool inStockOnly = false,
    double minPrice = 0,
    double maxPrice = double.infinity,
  }) async {
    if (_isOnline) {
      try {
        final products = await _firestore.getProducts(
          limit: limit,
          lastDocumentId: lastDocumentId,
          searchQuery: searchQuery,
          inStockOnly: inStockOnly,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );
        await _localDb.saveProducts(products);
        return products;
      } catch (e) {
        print('Online fetch failed, using local data: $e');
        return await _localDb.getProducts(
          limit: limit,
          searchQuery: searchQuery,
          inStockOnly: inStockOnly,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );
      }
    } else {
      return await _localDb.getProducts(
        limit: limit,
        searchQuery: searchQuery,
        inStockOnly: inStockOnly,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    if (_isOnline) {
      try {
        final products = await _firestore.searchProducts(query);
        if (products.isNotEmpty) {
          await _localDb.saveProducts(products);
        }
        return products;
      } catch (e) {
        print('Online search failed, using local data: $e');
        return await _localDb.getProducts(searchQuery: query);
      }
    } else {
      return await _localDb.getProducts(searchQuery: query);
    }
  }

  Future<List<Product>> searchProductsBySKU(String sku) async {
    final localProduct = await _localDb.getProductBySku(sku);
    if (localProduct != null) {
      return [localProduct];
    }

    if (_isOnline) {
      try {
        final products = await _firestore.searchProductsBySKU(sku);
        if (products.isNotEmpty) {
          await _localDb.saveProducts(products);
        }
        return products;
      } catch (e) {
        print('Online SKU search failed: $e');
        return [];
      }
    } else {
      return [];
    }
  }

  Future<OrderCreationResult> createOrder(List<CartItem> cartItems) async {
    if (_isOnline) {
      try {
        final order = await _firestore.createOrder(cartItems);
        return OrderCreationResult.success(order);
      } catch (e) {
        print('Online order creation failed, saving locally: $e');
        return await _createOfflineOrder(cartItems);
      }
    } else {
      return await _createOfflineOrder(cartItems);
    }
  }

  Future<OrderCreationResult> _createOfflineOrder(
      List<CartItem> cartItems,
      ) async {
    try {
      // Update local stock quantities first for offline consistency
      for (final item in cartItems) {
        await _updateLocalProductStock(item.product.id, -item.quantity);
      }

      final pendingOrderId = await _localDb.savePendingOrder(cartItems);
      await _localDb.clearCart();
      return OrderCreationResult.offline(pendingOrderId);
    } catch (e) {
      return OrderCreationResult.error('Failed to save order locally: $e');
    }
  }

  Future<void> _syncPendingOrders() async {
    final pendingOrders = await _localDb.getPendingOrders();

    if (pendingOrders.isEmpty) {
      print('No pending orders to sync');
      return;
    }

    print('Syncing ${pendingOrders.length} pending orders...');

    for (final order in pendingOrders) {
      try {
        final orderData = order['order_data'] as Map<String, dynamic>;
        final lineItems = (orderData['line_items'] as List).map((item) {
          return CartItem(
            product: Product(
              id: item['product_id'].toString(),
              name: item['product_name']?.toString() ?? '',
              sku: item['product_sku']?.toString() ?? '',
              price: (item['price'] as num).toDouble(),
              stockQuantity: 0,
              inStock: true,
              stockStatus: 'instock',
            ),
            quantity: item['quantity'],
          );
        }).toList();

        final createdOrder = await _firestore.createOrder(lineItems);
        await _localDb.deletePendingOrder(order['id']);

        print(
          'Successfully synced pending order ${order['id']} as order ${createdOrder.id}',
        );
      } catch (e) {
        print('Failed to sync pending order ${order['id']}: $e');
        final attempts = (order['sync_attempts'] as int? ?? 0) + 1;

        if (attempts >= 3) {
          await _localDb.updatePendingOrderStatus(
            order['id'],
            'failed',
            attempts: attempts,
          );
        } else {
          await _localDb.updatePendingOrderStatus(
            order['id'],
            'pending',
            attempts: attempts,
          );
        }
      }
    }
  }

  Future<void> _syncPendingRestocks() async {
    final pendingRestocks = await _localDb.getPendingRestocks();

    if (pendingRestocks.isEmpty) {
      print('No pending restocks to sync');
      return;
    }

    print('Syncing ${pendingRestocks.length} pending restocks...');

    for (final restock in pendingRestocks) {
      try {
        await _firestore.restockProduct(
          restock['productId'].toString(),
          restock['quantity'] as int,
          barcode: restock['barcode']?.toString(),
        );
        await _localDb.deletePendingRestock(restock['id']);
        print(
          'Successfully synced restock for product ${restock['productId']}',
        );
      } catch (e) {
        print('Failed to sync restock ${restock['id']}: $e');
        final attempts = (restock['sync_attempts'] as int? ?? 0) + 1;

        if (attempts >= 3) {
          await _localDb.updatePendingRestockStatus(
            restock['id'],
            'failed',
            attempts: attempts,
          );
        } else {
          await _localDb.updatePendingRestockStatus(
            restock['id'],
            'pending',
            attempts: attempts,
          );
        }
      }
    }
  }

  Future<void> _syncProducts() async {
    try {
      final products = await _firestore.getProducts(limit: 50);
      await _localDb.saveProducts(products);
      print('Successfully synced ${products.length} products');
    } catch (e) {
      print('Product sync failed: $e');
    }
  }

  Future<void> manualSync() async {
    if (_isOnline) {
      await _triggerSync();
    }
  }

  // Product management methods
  Future<String> addProduct(Product product, List<XFile>? images) async {
    return await _firestore.addProduct(product, images);
  }

  Future<void> updateProduct(Product product, List<XFile>? newImages) async {
    await _firestore.updateProduct(product, newImages);
  }

  Future<void> deleteProduct(String productId) async {
    await _firestore.deleteProduct(productId);
  }

  Future<void> restockProduct(
      String productId,
      int quantity, {
        String? barcode,
      }) async {
    if (_isOnline) {
      try {
        await _firestore.restockProduct(productId, quantity, barcode: barcode);
        // Update local cache after successful online restock
        await _syncLocalProductAfterRestock(productId, quantity);
      } catch (e) {
        // Fallback to offline mode
        await _savePendingRestock(productId, quantity, barcode);
        throw Exception('Online restock failed. Saved offline: $e');
      }
    } else {
      // Save restock operation for later sync
      await _savePendingRestock(productId, quantity, barcode);
    }
  }

  Future<void> _savePendingRestock(
      String productId,
      int quantity,
      String? barcode,
      ) async {
    await _localDb.savePendingRestock(productId, quantity, barcode);
    // Also update local product cache immediately for offline use
    await _updateLocalProductStock(productId, quantity);
  }

  // In EnhancedPOSService class - ENHANCE the _updateLocalProductStock method
  Future<void> _updateLocalProductStock(String productId, int quantity) async {
    final products = await _localDb.getProducts(limit: 0); // Get all products
    final productIndex = products.indexWhere((p) => p.id == productId);

    if (productIndex != -1) {
      final product = products[productIndex];
      final updatedProduct = Product(
        id: product.id,
        name: product.name,
        sku: product.sku,
        price: product.price,
        regularPrice: product.regularPrice,
        salePrice: product.salePrice,
        imageUrl: product.imageUrl,
        imageUrls: product.imageUrls,
        stockQuantity: product.stockQuantity + quantity,
        inStock: (product.stockQuantity + quantity) > 0,
        stockStatus: (product.stockQuantity + quantity) > 0
            ? 'instock'
            : 'outofstock',
        description: product.description,
        shortDescription: product.shortDescription,
        categories: product.categories,
        attributes: product.attributes,
        metaData: product.metaData,
        dateCreated: product.dateCreated,
        dateModified: DateTime.now(),
        purchasable: product.purchasable,
        type: product.type,
        status: product.status,
        featured: product.featured,
        permalink: product.permalink,
        averageRating: product.averageRating,
        ratingCount: product.ratingCount,
        parentId: product.parentId,
        variations: product.variations,
        weight: product.weight,
        dimensions: product.dimensions,
      );

      // Save only the updated product - the saveProducts method will now merge it
      await _localDb.saveProducts([updatedProduct]);
    }
  }

  Future<void> _syncLocalProductAfterRestock(
      String productId,
      int quantity,
      ) async {
    await _updateLocalProductStock(productId, quantity);
  }

  Stream<List<Category>> getCategoriesStream() {
    return _firestore.getCategoriesStream();
  }

  Future<List<Category>> getCategories() async {
    return await _firestore.getCategories();
  }

  Future<String> addCategory(Category category) async {
    return await _firestore.addCategory(category);
  }

  bool get isOnline => _isOnline;

  Stream<bool> get onlineStatusStream =>
      _connectivity.onConnectivityChanged.map(
            (List<ConnectivityResult> resultList) =>
            resultList.any((res) => res != ConnectivityResult.none),
      );

  Future<bool> testConnection() async {
    return _firestore.testConnection();
  }
}

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  _MainNavScreenState createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;
  final EnhancedCartManager _cartManager = EnhancedCartManager();
  final EnhancedPOSService _posService = EnhancedPOSService();
  bool _isTestingConnection = false;
  String _connectionStatus = '';
  bool _isOnline = false;
  int _cartItemCount = 0;
  final _firestore = NavigationService();
  final List<Widget> _clientAdminScreens = [];
  final List<Widget> _clientSalesManagerScreens = [];
  final List<Widget> _clientCashierScreens = [];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final tenantId = authProvider.currentUser?.tenantId;

    if (tenantId != null && tenantId != 'super_admin') {
      _posService.setTenantContext(tenantId);
      print('Tenant context set: $tenantId'); // Add this for debugging
    }

    _posService.initialize();
    await _cartManager.initialize();

    // Listen to cart item count changes
    _cartManager.itemCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _cartItemCount = count;
        });
      }
    });

    _posService.onlineStatusStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          _connectionStatus = isOnline
              ? 'Online - Connected'
              : 'Offline - Working Locally';
        });
      }
    });

    await _testConnection();

    _clientAdminScreens.addAll([
      ModernDashboardScreen(),

      ProductSellingScreen(cartManager: _cartManager),
      CartScreen(cartManager: _cartManager),
      AnalyticsDashboardScreen(),
      ProductManagementScreen(),
      CategoryManagementScreen(),

      ReturnsManagementScreen(), // Add this line

      SettingsScreen(),
      EnhancedUsersScreen(),
      ClientTicketsScreen(),

      ProfileScreen(),
    ]);
    setState(() {});

    _clientSalesManagerScreens.addAll([
      ModernDashboardScreen(),

      ProductSellingScreen(cartManager: _cartManager),
      CartScreen(cartManager: _cartManager),
      // AnalyticsDashboardScreen(),
      ProductManagementScreen(),
      CategoryManagementScreen(),

      ReturnsManagementScreen(), // Add this line
      // SettingsScreen(),
      // UsersScreen(),
      ClientTicketsScreen(),

      ProfileScreen(),
    ]);
    setState(() {});
    _clientCashierScreens.addAll([
      ModernDashboardScreen(),

      ProductSellingScreen(cartManager: _cartManager),
      CartScreen(cartManager: _cartManager),

      // AnalyticsDashboardScreen(),
      // ProductManagementScreen(),
      ReturnsManagementScreen(), // Add this line
      // SettingsScreen(),
      // UsersScreen(),
      ClientTicketsScreen(),

      ProfileScreen(),
    ]);
    setState(() {});
  }

  // Customer management methods
  Future<List<Customer>> searchCustomers(String query) async {
    return await _firestore.searchCustomers(query);
  }

  Future<Customer?> getCustomerById(String id) async {
    return await _firestore.getCustomerById(id);
  }

  Future<Customer?> getCustomerByEmail(String email) async {
    return await _firestore.getCustomerByEmail(email);
  }

  Future<String> addCustomer(Customer customer) async {
    return await _firestore.addCustomer(customer);
  }

  Future<void> updateCustomer(Customer customer) async {
    await _firestore.updateCustomer(customer);
  }

  // Enhanced order creation
  // Future<OrderCreationResult> createOrderWithCustomer(
  //     List<CartItem> cartItems,
  //     CustomerSelection customerSelection,
  //     ) async {
  //   if (_isOnline) {
  //     try {
  //       final order = await _firestore.createOrderWithCustomer(
  //         cartItems,
  //         customerSelection,
  //       );
  //       return OrderCreationResult.success(order);
  //     } catch (e) {
  //       print('Online order creation failed, saving locally: $e');
  //       return await _createOfflineOrderWithCustomer(
  //         cartItems,
  //         customerSelection,
  //       );
  //     }
  //   } else {
  //     return await _createOfflineOrderWithCustomer(
  //       cartItems,
  //       customerSelection,
  //     );
  //   }
  // }

  // Future<OrderCreationResult> _createOfflineOrderWithCustomer(
  //     List<CartItem> cartItems,
  //     CustomerSelection customerSelection,
  //     ) async {
  //   try {
  //     // Update local stock quantities
  //     for (final item in cartItems) {
  //       await _updateLocalProductStock(item.product.id, -item.quantity);
  //     }
  //
  //     final pendingOrderId = await _localDb.savePendingOrderWithCustomer(
  //       cartItems,
  //       customerSelection,
  //     );
  //     await _localDb.clearCart();
  //     return OrderCreationResult.offline(pendingOrderId);
  //   } catch (e) {
  //     return OrderCreationResult.error('Failed to save order locally: $e');
  //   }
  // }

  // In EnhancedPOSService class - ENHANCE the _updateLocalProductStock method
  // Future<void> _updateLocalProductStock(String productId, int quantity) async {
  //   final products = await _localDb.getProducts(limit: 0); // Get all products
  //   final productIndex = products.indexWhere((p) => p.id == productId);
  //
  //   if (productIndex != -1) {
  //     final product = products[productIndex];
  //     final updatedProduct = Product(
  //       id: product.id,
  //       name: product.name,
  //       sku: product.sku,
  //       price: product.price,
  //       regularPrice: product.regularPrice,
  //       salePrice: product.salePrice,
  //       imageUrl: product.imageUrl,
  //       imageUrls: product.imageUrls,
  //       stockQuantity: product.stockQuantity + quantity,
  //       inStock: (product.stockQuantity + quantity) > 0,
  //       stockStatus: (product.stockQuantity + quantity) > 0
  //           ? 'instock'
  //           : 'outofstock',
  //       description: product.description,
  //       shortDescription: product.shortDescription,
  //       categories: product.categories,
  //       attributes: product.attributes,
  //       metaData: product.metaData,
  //       dateCreated: product.dateCreated,
  //       dateModified: DateTime.now(),
  //       purchasable: product.purchasable,
  //       type: product.type,
  //       status: product.status,
  //       featured: product.featured,
  //       permalink: product.permalink,
  //       averageRating: product.averageRating,
  //       ratingCount: product.ratingCount,
  //       parentId: product.parentId,
  //       variations: product.variations,
  //       weight: product.weight,
  //       dimensions: product.dimensions,
  //     );
  //
  //     // Save only the updated product - the saveProducts method will now merge it
  //     await _localDb.saveProducts([updatedProduct]);
  //   }
  // }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      final success = await _posService.testConnection();
      setState(() {
        _connectionStatus = success
            ? 'Online - Connected'
            : 'Offline - Working Locally';
        _isOnline = success;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Offline - ${e.toString()}';
        _isOnline = false;
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _manualSync() async {
    if (_isOnline) {
      setState(() {
        _isTestingConnection = true;
        _connectionStatus = 'Syncing...';
      });

      await _posService.manualSync();

      setState(() {
        _isTestingConnection = false;
        _connectionStatus = 'Sync completed';
      });

      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _connectionStatus = _isOnline
                ? 'Online - Connected'
                : 'Offline - Working Locally';
          });
        }
      });
    }
  }

  final GlobalKey<LiquidPullToRefreshState> _refreshIndicatorKey =
  GlobalKey<LiquidPullToRefreshState>();
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _manualSync(); // Your existing sync method
    setState(() => _isRefreshing = false);
  }

  // Helper method to wrap screens with scrollability
  Widget _buildRefreshableScreen(Widget screen) {
    return LiquidPullToRefresh(
      key: _refreshIndicatorKey,
      onRefresh: _handleRefresh,
      color: Colors.blue[700]!,
      backgroundColor: Colors.white,
      height: 100,
      animSpeedFactor: 2,
      showChildOpacityTransition: false,
      child: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(), // Important!
        slivers: [SliverFillRemaining(hasScrollBody: false, child: screen)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    final user = authProvider.currentUser;
    final tenantId = user?.tenantId ?? 'No Tenant ID';
    return Scaffold(
      appBar: AppBar(
        actions: [

          // if (_isTestingConnection)
          //   Padding(
          //     padding: EdgeInsets.only(right: 16),
          //     child: Center(
          //       child: CircularProgressIndicator(color: Colors.white),
          //     ),
          //   )
          // else if (_isOnline)
          //   IconButton(
          //     icon: AnimatedContainer(
          //       duration: Duration(milliseconds: 300),
          //       padding: EdgeInsets.all(8),
          //       decoration: BoxDecoration(
          //         gradient: _isRefreshing
          //             ? LinearGradient(colors: [Colors.purple, Colors.blue])
          //             : LinearGradient(
          //           colors: [Colors.blue.shade400, Colors.cyan.shade400],
          //         ),
          //         shape: BoxShape.circle,
          //         boxShadow: [
          //           BoxShadow(
          //             color: Colors.blue.withOpacity(_isRefreshing ? 0.8 : 0.4),
          //             blurRadius: _isRefreshing ? 12 : 8,
          //             spreadRadius: _isRefreshing ? 2 : 1,
          //           ),
          //         ],
          //       ),
          //       child: AnimatedRotation(
          //         duration: Duration(milliseconds: 500),
          //         turns: _isRefreshing ? 1 : 0,
          //         child: Icon(
          //           _isRefreshing ? Icons.downloading : Icons.sync,
          //           color: Colors.white,
          //           size: 20,
          //         ),
          //       ),
          //     ),
          //     onPressed: _isRefreshing ? null : _handleRefresh,
          //     tooltip: 'Smart Sync',
          //   )
          // else
          //   IconButton(
          //     icon: Container(
          //       padding: EdgeInsets.all(8),
          //       decoration: BoxDecoration(
          //         color: Colors.orange[400],
          //         shape: BoxShape.circle,
          //       ),
          //       child: Icon(Icons.cloud_off, color: Colors.white, size: 20),
          //     ),
          //     onPressed: _testConnection,
          //     tooltip: 'Check Connection',
          //   ),


          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EnhancedProfileScreen(),
                ),
              );
            },
          ),
        ],
        flexibleSpace: Container(),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authProvider.currentTenant?.businessName ??
                  'Your Business (Tenant: ${tenantId.substring(0, min(8, tenantId.length))}...)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_connectionStatus.isNotEmpty)
              Text(
                _connectionStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: _isOnline ? Colors.green[200] : Colors.orange[200],
                ),
              ),
          ],
        ),
        backgroundColor: _isOnline ? Colors.blue[700] : Colors.orange[700],
        elevation: 0,
      ),
      body: _clientAdminScreens.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _isOnline
          ? _buildRefreshableScreen(_clientAdminScreens[_currentIndex])
          : _clientAdminScreens[_currentIndex],
      bottomNavigationBar: authProvider.currentUser!.canManageProducts
          ? BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex < 5
            ? _currentIndex
            : 4, // Ensure index is within bounds
        onTap: (index) {
          if (index == 4) {
            // More option
            _showMoreMenu(context, authProvider);
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: _buildCartIcon(),
            activeIcon: _buildCartIcon(isActive: true),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      )
          : authProvider.currentUser!.canManageUsers
          ? BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex < 5
            ? _currentIndex
            : 4, // Ensure index is within bounds
        onTap: (index) {
          if (index == 4) {
            // More option
            _showMoreMenu(context, authProvider);
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: _buildCartIcon(),
            activeIcon: _buildCartIcon(isActive: true),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      )
          : BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex < 5
            ? _currentIndex
            : 3, // Ensure index is within bounds
        onTap: (index) {
          if (index == 3) {
            // More option
            _showMoreMenu(context, authProvider);
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: _buildCartIcon(),
            activeIcon: _buildCartIcon(isActive: true),
            label: 'Cart',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }

  // Helper method for cart icon with badge
  Widget _buildCartIcon({bool isActive = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined),
        if (_cartItemCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                '$_cartItemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // More menu dialog
  void _showMoreMenu(BuildContext context, MyAuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (authProvider.currentUser!.canManageProducts ||
                  authProvider.currentUser!.canManageUsers)
                ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Manage Inventory'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(
                          () => _currentIndex =
                      authProvider.currentUser!.canManageUsers ? 4 : 4,
                    );

                    // Navigate to manage screen
                  },
                ),
              if (authProvider.currentUser!.canManageProducts ||
                  authProvider.currentUser!.canManageUsers)
                ListTile(
                  leading: Icon(Icons.inventory_2_outlined),
                  title: Text('Product Category'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(
                          () => _currentIndex =
                      authProvider.currentUser!.canManageUsers ? 5 : 5,
                    );

                    // Navigate to manage screen
                  },
                ),
              ListTile(
                leading: Icon(Icons.assignment_return_outlined),
                title: Text('Returns'),
                onTap: () {
                  Navigator.pop(context);
                  setState(
                        () => _currentIndex =
                    authProvider.currentUser!.canManageUsers ? 6 : 6,
                  );

                  // Navigate to returns screen
                },
              ),
              if (authProvider.currentUser!.canManageUsers)
                ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(
                          () => _currentIndex =
                      authProvider.currentUser!.canManageUsers ? 7 : 6,
                    );

                    // Navigate to settings screen
                  },
                ),
              if (authProvider.currentUser!.canManageUsers)
                ListTile(
                  leading: Icon(Icons.people),
                  title: Text('Users'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(
                          () => _currentIndex =
                      authProvider.currentUser!.canManageUsers ? 8 : 7,
                    );

                    // Navigate to users screen
                  },
                ),
              ListTile(
                leading: Icon(Icons.report_problem),
                title: Text('Ticket'),
                onTap: () {
                  Navigator.pop(context);
                  setState(
                        () => _currentIndex =
                    authProvider.currentUser!.canManageUsers ? 9 : 9,
                  );
                  // Navigate to profile screen
                },
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  setState(
                        () => _currentIndex =
                    authProvider.currentUser!.canManageUsers ? 10 : 10,
                  );
                  // Navigate to profile screen
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _posService.dispose();
    _cartManager.dispose();
    super.dispose();
  }
}
