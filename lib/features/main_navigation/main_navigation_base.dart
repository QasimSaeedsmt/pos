
import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:mpcm/features/customerBase/customer_management_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

import '../../analytics_screen.dart';
import '../../constants.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/auth/screens/settings_screen.dart';
import '../../printing/printing_setting_screen.dart';
import '../../sales/sales_management_screen.dart';
import '../../theme_utils.dart';
import '../cartBase/cart_base.dart';
import '../clientDashboard/client_dashboard.dart';
import '../connectivityBase/local_db_base.dart';
import '../customerBase/customer_base.dart';
import '../expense_management.dart';
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

  // Enhanced category methods with complete integration
  Future<List<Category>> getCategories() async {
    try {
      List<Category> categories;

      if (_isOnline) {
        print('🔄 Fetching categories from Firestore...');
        categories = await _firestore.getCategories();

        // Always sync Firestore categories to local database for offline access
        await _localDb.saveCategories(categories);
        print('✅ Synced ${categories.length} categories to local storage');
      } else {
        print('📱 Fetching categories from local database (offline mode)...');
        categories = await _localDb.getAllCategories();
        print('✅ Found ${categories.length} categories in local storage');
      }

      return categories;
    } catch (e) {
      print('❌ Error in getCategories: $e');

      // Comprehensive fallback strategy
      try {
        final localCategories = await _localDb.getAllCategories();
        print('🔄 Using fallback local categories: ${localCategories.length} found');
        return localCategories;
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        _showErrorSnackBar('Failed to load categories: $e');
        return [];
      }
    }
  }

  Future<String> addCategory(Category category) async {
    try {
      String categoryId;

      if (_isOnline) {
        print('🔄 Adding category to Firestore: ${category.name}');
        categoryId = await _firestore.addCategory(category);

        // Update the category with the Firestore ID
        final updatedCategory = category.copyWith(id: categoryId);

        // Save to local database for offline access
        await _localDb.saveCategory(updatedCategory);
        print('✅ Category added to Firestore with ID: $categoryId and saved locally');

        return categoryId;
      } else {
        // Generate a local ID for offline use
        categoryId = 'local_${DateTime.now().millisecondsSinceEpoch}';
        final localCategory = category.copyWith(id: categoryId);

        // Save to local database only
        await _localDb.saveCategory(localCategory);
        print('✅ Category saved locally with ID: $categoryId (offline mode)');

        return categoryId;
      }
    } catch (e) {
      print('❌ Error adding category: $e');

      // Robust fallback: always try to save locally
      try {
        final localId = 'local_fallback_${DateTime.now().millisecondsSinceEpoch}';
        final localCategory = category.copyWith(id: localId);
        await _localDb.saveCategory(localCategory);
        print('✅ Category saved locally as fallback with ID: $localId');
        return localId;
      } catch (localError) {
        print('❌ Local save also failed: $localError');
        _showErrorSnackBar('Failed to add category: $e');
        rethrow;
      }
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      if (_isOnline) {
        print('🔄 Updating category in Firestore: ${category.name} (${category.id})');
        await _firestore.updateCategory(category);
      }

      // Always update local database for consistency (online or offline)
      await _localDb.saveCategory(category);
      print('✅ Category updated locally: ${category.name}');

    } catch (e) {
      print('❌ Error updating category: $e');

      // Fallback: update local database even if online fails
      try {
        await _localDb.saveCategory(category);
        print('✅ Category updated locally as fallback: ${category.name}');

        if (_isOnline) {
          // If online failed but we're online, show error but don't throw
          _showErrorSnackBar('Failed to sync category update online: $e');
        }
      } catch (localError) {
        print('❌ Local update also failed: $localError');
        _showErrorSnackBar('Failed to update category: $e');
        rethrow;
      }
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      if (_isOnline) {
        print('🔄 Deleting category from Firestore: $categoryId');
        await _firestore.deleteCategory(categoryId);
      }

      // Always update local database for consistency
      await _localDb.deleteCategory(categoryId);
      print('✅ Category deleted locally: $categoryId');

    } catch (e) {
      print('❌ Error deleting category: $e');

      // Fallback: delete from local database even if online fails
      try {
        await _localDb.deleteCategory(categoryId);
        print('✅ Category deleted locally as fallback: $categoryId');

        if (_isOnline) {
          _showErrorSnackBar('Failed to sync category deletion online: $e');
        }
      } catch (localError) {
        print('❌ Local delete also failed: $localError');
        _showErrorSnackBar('Failed to delete category: $e');
        rethrow;
      }
    }
  }

  Stream<List<Category>> getCategoriesStream() {
    if (_isOnline) {
      return _firestore.getCategoriesStream().asyncMap((categories) async {
        // Sync Firestore categories to local database when they update
        await _localDb.saveCategories(categories);
        return categories;
      }).handleError((error) {
        print('❌ Categories stream error: $error');
        // Fallback to local data when stream fails
        return _localDb.getAllCategories();
      });
    } else {
      return _localDb.getCategoriesStream();
    }
  }

  // Enhanced sync method for categories
  Future<void> _syncPendingCategories() async {
    if (!_isOnline) {
      print('📱 Skipping category sync - offline');
      return;
    }

    try {
      final localCategories = await _localDb.getAllCategories();
      final localOnlyCategories = localCategories.where((cat) => cat.id.startsWith('local_')).toList();

      if (localOnlyCategories.isEmpty) {
        print('✅ No local-only categories to sync');
        return;
      }

      print('🔄 Syncing ${localOnlyCategories.length} local categories to Firestore...');

      for (final localCategory in localOnlyCategories) {
        try {
          // Add to Firestore and get the real ID
          final firestoreId = await _firestore.addCategory(localCategory);

          // Update local category with Firestore ID
          final updatedCategory = localCategory.copyWith(id: firestoreId);
          await _localDb.saveCategory(updatedCategory);

          print('✅ Synced local category "${localCategory.name}" to Firestore with ID: $firestoreId');
        } catch (e) {
          print('❌ Failed to sync local category "${localCategory.name}": $e');
          // Continue with other categories even if one fails
        }
      }
    } catch (e) {
      print('❌ Error syncing pending categories: $e');
    }
  }

  // Update the main sync method to include categories
  Future<void> _triggerSync() async {
    await _syncLock.synchronized(() async {
      try {
        print('🔄 Starting full sync...');
        await _syncPendingOrders();
        await _syncPendingRestocks();
        await _syncPendingReturns();
        await _syncPendingCategories(); // Add this line
        await _syncProducts();
        print('✅ Full sync completed successfully');
      } catch (e) {
        print('❌ Sync error: $e');
      }
    });
  }

  // Helper method to show error messages
  void _showErrorSnackBar(String message) {
    // This would typically use a ScaffoldMessenger, but we can't access context here
    print('💬 Error Snackbar: $message');
  }
  void setTenantContext(String tenantId) {
    _firestore.setTenantId(tenantId);
  }
// Add these to your FirestoreServices class

  // ... existing properties and methods ...

  // Categories collection reference
  CollectionReference get categoriesRef => FirebaseFirestore.instance.collection('categories');
// In EnhancedPOSService class - ADD this corrected method
  Map<String, dynamic> _createEnhancedCartData(
      List<CartItem> cartItems,
      Map<String, dynamic>? additionalData,
      {double? cartDiscount,
        double? cartDiscountPercent,
        double? taxRate}
      ) {
    // Calculate basic totals
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.baseSubtotal);
    final itemDiscounts = cartItems.fold(0.0, (sum, item) => sum + item.discountAmount);

    // Use provided cart discounts or get from additionalData
    final effectiveCartDiscount = cartDiscount ?? additionalData?['cartData']?['cartDiscount'] ?? 0.0;
    final effectiveCartDiscountPercent = cartDiscountPercent ?? additionalData?['cartData']?['cartDiscountPercent'] ?? 0.0;
    final cartDiscountAmount = effectiveCartDiscount + (subtotal * effectiveCartDiscountPercent / 100);

    final totalDiscount = itemDiscounts + cartDiscountAmount;
    final taxableAmount = subtotal - totalDiscount;

    // Use provided tax rate or get from additionalData
    final effectiveTaxRate = taxRate ?? additionalData?['cartData']?['taxRate'] ?? 0.0;
    final taxAmount = taxableAmount * effectiveTaxRate / 100;

    // Extract additional charges
    final additionalDiscount = additionalData?['additionalDiscount'] ?? 0.0;
    final shippingAmount = additionalData?['shippingAmount'] ?? 0.0;
    final tipAmount = additionalData?['tipAmount'] ?? 0.0;

    final finalTotal = taxableAmount + taxAmount + shippingAmount + tipAmount - additionalDiscount;

    return {
      'items': cartItems.map((item) => {
        'productId': item.product.id,
        'productName': item.product.name,
        'quantity': item.quantity,
        'price': item.product.price,
        'base_price': item.product.price,
        'manual_discount': item.manualDiscount,
        'manual_discount_percent': item.manualDiscountPercent,
        'discount_amount': item.discountAmount,
        'base_subtotal': item.baseSubtotal,
        'final_subtotal': item.subtotal,
        'has_manual_discount': item.hasManualDiscount,
      }).toList(),
      'subtotal': subtotal,
      'item_discounts': itemDiscounts,
      'cart_discount': effectiveCartDiscount,
      'cart_discount_percent': effectiveCartDiscountPercent,
      'cart_discount_amount': cartDiscountAmount,
      'additional_discount': additionalDiscount,
      'total_discount': totalDiscount + additionalDiscount,
      'taxable_amount': taxableAmount - additionalDiscount,
      'tax_rate': effectiveTaxRate,
      'tax_amount': taxAmount,
      'shipping_amount': shippingAmount,
      'tip_amount': tipAmount,
      'totalAmount': finalTotal,
      'pricing_breakdown': {
        'gross_amount': subtotal,
        'total_savings': totalDiscount + additionalDiscount,
        'net_amount': taxableAmount - additionalDiscount,
        'tax_amount': taxAmount,
        'shipping_amount': shippingAmount,
        'tip_amount': tipAmount,
        'final_total': finalTotal,
      },
    };
  }
// In EnhancedPOSService class - ADD this method

// In EnhancedPOSService class - ADD this method
// In EnhancedPOSService class - UPDATE the createOrderWithEnhancedData method
  Future<OrderCreationResult> createOrderWithEnhancedData(
      List<CartItem> cartItems,
      CustomerSelection customerSelection, {
        Map<String, dynamic>? additionalData,
        EnhancedCartManager? cartManager, // Optional cart manager for discount data
      }) async {
    try {
      if (_isOnline) {
        // Extract discount data from cart manager if provided
        double? cartDiscount;
        double? cartDiscountPercent;
        double? taxRate;

        if (cartManager != null) {
          cartDiscount = cartManager.cartDiscount;
          cartDiscountPercent = cartManager.cartDiscountPercent;
          taxRate = cartManager.taxRate;
        }

        // Create enhanced order data with all discount information
        final enhancedData = _createEnhancedCartData(
          cartItems,
          additionalData,
          cartDiscount: cartDiscount,
          cartDiscountPercent: cartDiscountPercent,
          taxRate: taxRate,
        );

        // Add additional charges/discounts
        enhancedData['additionalDiscount'] = additionalData?['additionalDiscount'] ?? 0.0;
        enhancedData['shippingAmount'] = additionalData?['shippingAmount'] ?? 0.0;
        enhancedData['tipAmount'] = additionalData?['tipAmount'] ?? 0.0;
        enhancedData['paymentMethod'] = additionalData?['paymentMethod'] ?? 'cash';
        enhancedData['finalTotal'] = additionalData?['finalTotal'] ?? enhancedData['totalAmount'];

        final order = await _firestore.createOrderWithEnhancedData(
          cartItems,
          customerSelection,
          enhancedData,
        );

        return OrderCreationResult.success(order);
      } else {
        // Use existing offline method which already handles enhanced data
        return await _createOfflineOrderWithCustomer(
          cartItems,
          customerSelection,
          additionalData: additionalData,
        );
      }
    } catch (e) {
      print('Enhanced order creation failed: $e');

      // Fallback to basic order creation
      try {
        if (_isOnline) {
          final order = await _firestore.createOrderWithCustomer(cartItems, customerSelection);
          return OrderCreationResult.success(order);
        } else {
          return await _createOfflineOrderWithCustomer(
            cartItems,
            customerSelection,
            additionalData: additionalData,
          );
        }
      } catch (fallbackError) {
        print('Fallback order creation also failed: $fallbackError');
        return OrderCreationResult.error('Failed to create order: $fallbackError');
      }
    }
  }
// Update the existing createOrderWithCustomer to use enhanced data
  Future<OrderCreationResult> createOrderWithCustomer(
      List<CartItem> cartItems,
      CustomerSelection customerSelection, {
        Map<String, dynamic>? additionalData,
      }) async {
    // Use the enhanced method by default
    return await createOrderWithEnhancedData(
      cartItems,
      customerSelection,
      additionalData: additionalData,
    );
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
  AnalyticsService _analyticsService = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final tenantId = authProvider.currentUser?.tenantId;
    _analyticsService = AnalyticsService();

    if (tenantId != null && tenantId != 'super_admin') {
      _posService.setTenantContext(tenantId);
      print('Tenant context set: $tenantId'); // Add this for debugging
    }
    _analyticsService.setTenantId(tenantId!); // Make sure AnalyticsService has this method

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

      ReturnsManagementScreen(),

      SettingsScreen(),
      EnhancedUsersScreen(),
      ClientTicketsScreen(),

      ProfileScreen(),
      ModernCustomerManagementScreen(posService: _posService),
      ExpenseManagementScreen(analyticsService: _analyticsService), // Add this line

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
      ModernCustomerManagementScreen(posService: _posService),
      ExpenseManagementScreen(analyticsService: _analyticsService), // Add this line



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
      color: ThemeUtils.primary(context)!,
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


          // IconButton(
          //   icon: Icon(Icons.person),
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (context) => EnhancedProfileScreen(),
          //       ),
          //     );
          //   },
          // ),
        ],
        flexibleSpace: Container(),

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authProvider.currentTenant?.businessName ??
                  'Your Business (Tenant: ${tenantId.substring(0, min(8, tenantId.length))}...)',
              style: TextStyle(
                color: ThemeUtils.textOnPrimary(context),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_connectionStatus.isNotEmpty)
              Text(
                _connectionStatus,
                style: TextStyle(
                  fontSize: 12,
                  color: _isOnline ? ThemeUtils.textOnPrimary(context) : ThemeUtils.textOnPrimary(context),
                ),
              ),
          ],
        ),
        backgroundColor: _isOnline ? ThemeUtils.primary(context) : ThemeUtils.secondary(context),
        elevation: 0,
      ),
      body: _clientAdminScreens.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _isOnline
          ? _buildRefreshableScreen(_clientAdminScreens[_currentIndex])
          : _clientAdminScreens[_currentIndex],
      bottomNavigationBar: authProvider.currentUser!.canManageProducts
          ? BottomNavigationBar(
        selectedItemColor: ThemeUtils.primary(context),
        unselectedItemColor: ThemeUtils.accentColor(context),
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
// More menu dialog
  void _showMoreMenu(BuildContext context, MyAuthProvider authProvider) {
    final user = authProvider.currentUser;

    // Define menu sections based on user roles
    final List<MenuSection> menuSections = [
      // Core Features - Available to all users
      MenuSection(
        title: 'Core Features',
        items: [
          MenuItem(
            icon: Icons.person_outline,
            title: 'Profile',
            description: 'Manage your account settings',
            color: Colors.blue,
            index: 10,
          ),
          MenuItem(
            icon: Icons.assignment_return_outlined,
            title: 'Returns',
            description: 'Process product returns',
            color: Colors.orange,
            index: 6,
          ),
          MenuItem(
            icon: Icons.group_outlined,
            title: 'Customers',
            description: 'Manage customer database',
            color: Colors.teal,
            index: 11,
          ),
          MenuItem(
            icon: Icons.report_problem_outlined,
            title: 'Support Tickets',
            description: 'Get technical assistance',
            color: Colors.red,
            index: 9,
          ),
        ],
      ),

      // Business Management - Admin & Sales Manager
      if (user!.canManageUsers || user.canManageProducts)
        MenuSection(
          title: 'Business Management',
          items: [
            if (user.canManageUsers || user.canManageProducts)
              MenuItem(
                icon: Icons.receipt_long_outlined,
                title: 'Expense Management',
                description: 'Track business expenses',
                color: Colors.purple,
                index: 12,
              ),
            if (user.canManageProducts || user.canManageUsers)
              MenuItem(
                icon: Icons.inventory_2_outlined,
                title: 'Inventory',
                description: 'Manage product stock',
                color: Colors.green,
                index: 4,
              ),
            if (user.canManageProducts || user.canManageUsers)
              MenuItem(
                icon: Icons.category_outlined,
                title: 'Categories',
                description: 'Organize product categories',
                color: Colors.indigo,
                index: 5,
              ),
          ],
        ),

      // Administration - Admin only
      if (user.canManageUsers)
        MenuSection(
          title: 'Administration',
          items: [
            MenuItem(
              icon: Icons.people_outline,
              title: 'Users',
              description: 'Manage team members',
              color: Colors.deepOrange,
              index: 8,
            ),
            MenuItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              description: 'System configuration',
              color: Colors.grey,
              index: 7,
            ),
          ],
        ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ThemeUtils.surface(context),
                ThemeUtils.surface(context).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with blur effect
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'More Options',
                              style: ThemeUtils.headlineMedium(context)?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Quick access to all features',
                              style: ThemeUtils.bodySmall(context)?.copyWith(
                                color: ThemeUtils.textSecondary(context).withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThemeUtils.primary(context)!.withOpacity(0.1),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: ThemeUtils.primary(context)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // User info card
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeUtils.primary(context)!.withOpacity(0.1),
                        ThemeUtils.primary(context)!.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ThemeUtils.primary(context)!.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: ThemeUtils.accent(context),
                          ),
                        ),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'User',
                              style: ThemeUtils.bodyLarge(context)?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _getUserRole(user),
                              style: ThemeUtils.bodySmall(context)?.copyWith(
                                color: ThemeUtils.primary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isOnline ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isOnline ? Colors.green : Colors.orange,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              _isOnline ? 'Online' : 'Offline',
                              style: ThemeUtils.bodySmall(context)?.copyWith(
                                color: _isOnline ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu sections
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Quick Actions
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'Quick Actions',
                            style: ThemeUtils.bodyLarge(context)?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: ThemeUtils.textSecondary(context),
                            ),
                          ),
                        ),
                      ),

                      // Quick action chips
                      SliverToBoxAdapter(
                        child: Container(
                          height: 80,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              _buildQuickActionChip(
                                context,
                                icon: Icons.qr_code_scanner,
                                label: 'Scan',
                                onTap: () => _handleQuickAction('scan'),
                              ),
                              _buildQuickActionChip(
                                context,
                                icon: Icons.receipt,
                                label: 'Invoices',
                                onTap: () => _handleQuickAction('invoices'),
                              ),
                              _buildQuickActionChip(
                                context,
                                icon: Icons.analytics,
                                label: 'Reports',
                                onTap: () => _handleQuickAction('reports'),
                              ),
                              _buildQuickActionChip(
                                context,
                                icon: Icons.sync,
                                label: 'Sync',
                                onTap: _manualSync,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Main menu sections
                      ...menuSections.map((section) => SliverList(
                        delegate: SliverChildListDelegate([
                          SizedBox(height: 16),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              section.title,
                              style: ThemeUtils.bodyLarge(context)?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: ThemeUtils.textSecondary(context),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          ...section.items.map((item) => _buildModernMenuItem(
                            context,
                            item: item,
                            onTap: () {
                              Navigator.pop(context);
                              setState(() => _currentIndex = item.index);
                            },
                          )),
                        ]),
                      )),

                      // Bottom spacing
                      SliverToBoxAdapter(
                        child: SizedBox(height: 30),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
// Helper method to build consistent menu items
  Widget _buildMoreMenuItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        String? subtitle,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeUtils.card(context)[0],
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ThemeUtils.primary(context)!.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          ),
          child: Icon(icon, color: ThemeUtils.primary(context), size: 20),
        ),
        title: Text(
          title,
          style: ThemeUtils.bodyLarge(context)?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null ? Text(
          subtitle,
          style: ThemeUtils.bodySmall(context)?.copyWith(
            color: ThemeUtils.textSecondary(context),
          ),
        ) : null,
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: ThemeUtils.textSecondary(context),
        ),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
  @override
  void dispose() {
    _posService.dispose();
    _cartManager.dispose();
    super.dispose();
  }
}
// Supporting classes and methods
class MenuSection {
  final String title;
  final List<MenuItem> items;

  MenuSection({required this.title, required this.items});
}

class MenuItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final int index;

  MenuItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.index,
  });
}

String _getUserRole(AppUser user) {
  if (user.canManageUsers) return 'Administrator';
  if (user.canManageProducts) return 'Sales Manager';
  return 'Cashier';
}

Widget _buildModernMenuItem(
    BuildContext context, {
      required MenuItem item,
      required VoidCallback onTap,
    }) {
  return Container(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ThemeUtils.card(context)[0].withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ThemeUtils.card(context)[1].withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              // Icon with gradient background
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      item.color.withOpacity(0.2),
                      item.color.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 24,
                ),
              ),
              SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: ThemeUtils.bodyLarge(context)?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      item.description,
                      style: ThemeUtils.bodySmall(context)?.copyWith(
                        color: ThemeUtils.textSecondary(context).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Chevron icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: ThemeUtils.textSecondary(context).withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildQuickActionChip(
    BuildContext context, {
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
  return Container(
    margin: EdgeInsets.only(right: 12),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: ThemeUtils.primary(context)!.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ThemeUtils.primary(context)!.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: ThemeUtils.primary(context),
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: ThemeUtils.bodySmall(context)?.copyWith(
                  color: ThemeUtils.primary(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _handleQuickAction(String action) {
  switch (action) {
    case 'scan':
    // Implement scan functionality
      break;
    case 'invoices':
    // Implement invoices functionality
      break;
    case 'reports':
    // Implement reports functionality
      break;
  }
}