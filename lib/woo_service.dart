// enhanced_woocommerce_service.dart

import 'app.dart';

class EnhancedWooCommerceService {
  // static final EnhancedWooCommerceService _instance = EnhancedWooCommerceService._internal();
  // factory EnhancedWooCommerceService() => _instance;
  // EnhancedWooCommerceService._internal();
  //
  // final WooCommerceService _wooService = WooCommerceService();
  // final LocalDatabase _localDb = LocalDatabase();
  // final Connectivity _connectivity = Connectivity();
  // final Lock _syncLock = Lock();
  //
  // bool _isOnline = false;
  // StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  //
  // void initialize() {
  //   _startConnectivityListener();
  //   _checkInitialConnection();
  // }
  //
  // void dispose() {
  //   _connectivitySubscription?.cancel();
  // }
  //
  // Future<void> _startConnectivityListener() async {
  //   _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
  //     final wasOnline = _isOnline;
  //     _isOnline = result != ConnectivityResult.none;
  //
  //     if (!wasOnline && _isOnline) {
  //       _triggerSync();
  //     }
  //   });
  // }
  //
  // Future<void> _checkInitialConnection() async {
  //   final result = await _connectivity.checkConnectivity();
  //   _isOnline = result != ConnectivityResult.none;
  //   if (_isOnline) {
  //     _triggerSync();
  //   }
  // }
  //
  // Future<void> _triggerSync() async {
  //   await _syncLock.synchronized(() async {
  //     try {
  //       await _syncPendingOrders();
  //       await _syncProducts();
  //       await _syncQueueOperations();
  //     } catch (e) {
  //       print('Sync error: $e');
  //     }
  //   });
  // }
  //
  // // Enhanced product fetching with offline support
  // Future<List<Product>> fetchProducts({int page = 1, int perPage = 20}) async {
  //   if (_isOnline) {
  //     try {
  //       final products = await _wooService.fetchProducts(page: page, perPage: perPage);
  //       await _localDb.saveProducts(products);
  //       return products;
  //     } catch (e) {
  //       print('Online fetch failed, using local data: $e');
  //       return await _localDb.getProducts(limit: perPage, offset: (page - 1) * perPage);
  //     }
  //   } else {
  //     return await _localDb.getProducts(limit: perPage, offset: (page - 1) * perPage);
  //   }
  // }
  //
  // Future<List<Product>> searchProducts(String query) async {
  //   if (_isOnline) {
  //     try {
  //       final products = await _wooService.searchProducts(query);
  //       if (products.isNotEmpty) {
  //         await _localDb.saveProducts(products);
  //       }
  //       return products;
  //     } catch (e) {
  //       print('Online search failed, using local data: $e');
  //       return await _localDb.getProducts(searchQuery: query);
  //     }
  //   } else {
  //     return await _localDb.getProducts(searchQuery: query);
  //   }
  // }
  //
  // Future<List<Product>> searchProductsBySKU(String sku) async {
  //   // Always check local first for immediate response
  //   final localProduct = await _localDb.getProductBySku(sku);
  //   if (localProduct != null) {
  //     return [localProduct];
  //   }
  //
  //   if (_isOnline) {
  //     try {
  //       final products = await _wooService.searchProductsBySKU(sku);
  //       if (products.isNotEmpty) {
  //         await _localDb.saveProducts(products);
  //       }
  //       return products;
  //     } catch (e) {
  //       print('Online SKU search failed: $e');
  //       return [];
  //     }
  //   } else {
  //     return [];
  //   }
  // }
  //
  // // Enhanced order creation with offline support
  // Future<OrderCreationResult> createOrder(List<CartItem> cartItems) async {
  //   if (_isOnline) {
  //     try {
  //       final order = await _wooService.createOrder(cartItems);
  //       return OrderCreationResult.success(order);
  //     } catch (e) {
  //       print('Online order creation failed, saving locally: $e');
  //       return await _createOfflineOrder(cartItems);
  //     }
  //   } else {
  //     return await _createOfflineOrder(cartItems);
  //   }
  // }
  //
  // Future<OrderCreationResult> _createOfflineOrder(List<CartItem> cartItems) async {
  //   try {
  //     final pendingOrderId = await _localDb.savePendingOrder(cartItems);
  //     await _localDb.clearCart();
  //
  //     return OrderCreationResult.offline(pendingOrderId);
  //   } catch (e) {
  //     return OrderCreationResult.error('Failed to save order locally: $e');
  //   }
  // }
  //
  // // Sync methods
  // Future<void> _syncPendingOrders() async {
  //   final pendingOrders = await _localDb.getPendingOrders();
  //
  //   for (final order in pendingOrders) {
  //     try {
  //       final orderData = order['order_data'] as Map<String, dynamic>;
  //       final lineItems = (orderData['line_items'] as List).map((item) {
  //         return CartItem(
  //           product: Product(id: item['product_id'], name: '', sku: '', price: item['price'], stockQuantity: 0, inStock: true, stockStatus: ''),
  //           quantity: item['quantity'],
  //         );
  //       }).toList();
  //
  //       final createdOrder = await _wooService.createOrder(lineItems);
  //       await _localDb.deletePendingOrder(order['id']);
  //
  //       print('Successfully synced pending order ${order['id']} as order ${createdOrder.id}');
  //     } catch (e) {
  //       print('Failed to sync pending order ${order['id']}: $e');
  //       final attempts = order['sync_attempts'] + 1;
  //       if (attempts >= 3) {
  //         await _localDb.updatePendingOrderStatus(order['id'], 'failed', attempts: attempts);
  //       } else {
  //         await _localDb.updatePendingOrderStatus(order['id'], 'pending', attempts: attempts);
  //       }
  //     }
  //   }
  // }
  //
  // Future<void> _syncProducts() async {
  //   try {
  //     // Sync recent products to keep local database updated
  //     final products = await _wooService.fetchProducts(page: 1, perPage: 50);
  //     await _localDb.saveProducts(products);
  //   } catch (e) {
  //     print('Product sync failed: $e');
  //   }
  // }
  //
  // Future<void> _syncQueueOperations() async {
  //   final pendingOperations = await _localDb.getPendingSyncOperations();
  //
  //   for (final operation in pendingOperations) {
  //     try {
  //       // Handle different operation types
  //       switch (operation['operation_type']) {
  //         case 'update_product':
  //         // Implement product update sync logic
  //           break;
  //         case 'update_stock':
  //         // Implement stock update sync logic
  //           break;
  //       }
  //
  //       await _localDb.deleteSyncOperation(operation['id']);
  //     } catch (e) {
  //       print('Failed to sync operation ${operation['id']}: $e');
  //       final attempts = operation['sync_attempts'] + 1;
  //       if (attempts >= 3) {
  //         await _localDb.updateSyncOperationStatus(operation['id'], 'failed', attempts: attempts);
  //       } else {
  //         await _localDb.updateSyncOperationStatus(operation['id'], 'pending', attempts: attempts);
  //       }
  //     }
  //   }
  // }
  //
  // // Manual sync trigger
  // Future<void> manualSync() async {
  //   if (_isOnline) {
  //     await _triggerSync();
  //   }
  // }
  //
  // bool get isOnline => _isOnline;
  //
  // Stream<bool> get onlineStatusStream => _connectivity.onConnectivityChanged
  //     .map((result) => result != ConnectivityResult.none);
}

class OrderCreationResult {
  final bool success;
  final Order? order;
  final int? pendingOrderId;
  final String? error;

  OrderCreationResult.success(this.order)
      : success = true, pendingOrderId = null, error = null;

  OrderCreationResult.offline(this.pendingOrderId)
      : success = true, order = null, error = null;

  OrderCreationResult.error(this.error)
      : success = false, order = null, pendingOrderId = null;

  bool get isOffline => pendingOrderId != null;
}