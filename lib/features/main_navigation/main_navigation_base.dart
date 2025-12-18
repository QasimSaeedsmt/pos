import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:mpcm/features/customerBase/customer_management_screen.dart';
import 'package:mpcm/features/scanning/smart_scan_models.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import '../../analytics_screen.dart';
import '../../constants.dart';
import '../../core/models/app_order_model.dart';
import '../../core/models/cart_item_model.dart';
import '../../core/models/category_model.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/return_request.dart';
import '../../core/overlay_manager.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/auth/screens/settings_screen.dart';
import '../../theme_utils.dart';
import '../cartBase/cart_base.dart';
import '../clientDashboard/client_dashboard.dart';
import '../connectivityBase/local_db_base.dart';
import '../credit/credit collection_screen.dart';
import '../credit/credit_analytics_screen.dart';
import '../credit/customer_communication_screen.dart';
import '../credit/credit_sale_model.dart';
import '../credit/credit_service.dart';
import '../customerBase/customer_base.dart';
import '../expense_management.dart';
import '../invoiceBase/invoice_archieve_screen.dart';
import '../product_addition_restock_base/product_addition_restock_base.dart';
import '../product_selling/product_selling_base.dart';
import '../profile.dart';
import '../returnBase/return_base.dart';
import '../scanning/action_sheets.dart';
import '../ticketing/ticketing.dart';
import '../users/users_base.dart';

class EnhancedPOSService {
  final FirestoreServices _firestoreServices = FirestoreServices();
  final LocalDatabase _localDb = LocalDatabase();
  final Connectivity _connectivity = Connectivity();
  final Lock _syncLock = Lock();

  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ///working
  Future<void> restockProductWithWAC(
      String productId,
      int quantity,
      double purchasePrice, {
        String? supplier,
        String? batchNumber,
        String? notes,
      }) async {
    try {
      // 1. Get current product
      final productDoc = await _firestoreServices.productsRef
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        throw Exception('Product not found');
      }

      final currentProduct = Product.fromFirestore(
        productDoc.data() as Map<String, dynamic>,
        productDoc.id,
      );

      // 2. Calculate new weighted average cost
      final double newWeightedAverageCost = _calculateWeightedAverage(
        oldQuantity: currentProduct.stockQuantity,
        oldCost: currentProduct.purchasePrice ?? 0.0,
        newQuantity: quantity,
        newCost: purchasePrice,
      );

      // 3. Calculate new total cost value
      final double newTotalCostValue =
          (currentProduct.totalCostValue) + (quantity * purchasePrice);

      // 4. Update product with new WAC values
      final updatedProduct = currentProduct.copyWith(
        stockQuantity: currentProduct.stockQuantity + quantity,
        inStock: true,
        stockStatus: 'instock',
        purchasePrice: newWeightedAverageCost,
        totalCostValue: newTotalCostValue,
        totalUnitsPurchased: currentProduct.totalUnitsPurchased + quantity,
        lastRestockDate: DateTime.now(),
        dateModified: DateTime.now(),
      );

      // 5. Save updated product
      await _firestoreServices
          .productsRef
          .doc(productId)
          .update(updatedProduct.toFirestore());

      // 6. Create purchase record
      final purchaseRecord = PurchaseRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productId: productId,
        productName: currentProduct.name,
        productSku: currentProduct.sku,
        quantity: quantity,
        purchasePrice: purchasePrice,
        totalCost: quantity * purchasePrice,
        purchaseDate: DateTime.now(),
        supplier: supplier,
        batchNumber: batchNumber,
        notes: notes,
      );

      await _firestoreServices
          .purchaseRecordRef
          .doc(purchaseRecord.id)
          .set(purchaseRecord.toFirestore());

      debugPrint('✅ WAC Updated: ${currentProduct.name}');
      debugPrint('📦 Old Stock: ${currentProduct.stockQuantity}');
      debugPrint('📦 New Stock: ${updatedProduct.stockQuantity}');
      debugPrint('💰 Old Cost: ${currentProduct.purchasePrice?.toStringAsFixed(2)}');
      debugPrint('💰 New WAC: ${newWeightedAverageCost.toStringAsFixed(2)}');
      debugPrint('💵 Total Cost Value: ${newTotalCostValue.toStringAsFixed(2)}');

    } catch (e) {
      debugPrint('❌ Error in restockProductWithWAC: $e');
      throw Exception('Failed to restock product: $e');
    }
  }

  ///working
  double _calculateWeightedAverage({
    required int oldQuantity,
    required double oldCost,
    required int newQuantity,
    required double newCost,
  }) {
    if (oldQuantity + newQuantity == 0) return newCost;

    final totalOldValue = oldQuantity * oldCost;
    final totalNewValue = newQuantity * newCost;
    final totalQuantity = oldQuantity + newQuantity;

    return (totalOldValue + totalNewValue) / totalQuantity;
  }

  ///working
  Future<List<PurchaseRecord>> getPurchaseHistory(String productId) async {


    try {
      final snapshot = await _firestoreServices
          .purchaseRecordRef
          .where('productId', isEqualTo: productId)
          .orderBy('purchaseDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return PurchaseRecord.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting purchase history: $e');
      return [];
    }
  }

  ///working
  Future<List<Category>> getCategories() async {
    try {
      List<Category> categories;

      if (_isOnline) {
        debugPrint('🔄 Fetching categories from Firestore...');
        categories = await _firestoreServices.getCategories();

        // Always sync Firestore categories to local database for offline access
        await _localDb.saveCategories(categories);
        debugPrint('✅ Synced ${categories.length} categories to local storage');
      } else {
        debugPrint('📱 Fetching categories from local database (offline mode)...');
        categories = await _localDb.getAllCategories();
        debugPrint('✅ Found ${categories.length} categories in local storage');
      }

      return categories;
    } catch (e) {
      debugPrint('❌ Error in getCategories: $e');

      // Comprehensive fallback strategy
      try {
        final localCategories = await _localDb.getAllCategories();
        debugPrint('🔄 Using fallback local categories: ${localCategories.length} found');
        return localCategories;
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  ///working
  Future<String> addCategory(Category category) async {
    try {
      String categoryId;

      if (_isOnline) {
        debugPrint('🔄 Adding category to Firestore: ${category.name}');
        categoryId = await _firestoreServices.addCategory(category);

        // Update the category with the Firestore ID
        final updatedCategory = category.copyWith(id: categoryId);

        // Save to local database for offline access
        await _localDb.saveCategory(updatedCategory);
        debugPrint('✅ Category added to Firestore with ID: $categoryId and saved locally');

        return categoryId;
      } else {
        // Generate a local ID for offline use
        categoryId = 'local_${DateTime.now().millisecondsSinceEpoch}';
        final localCategory = category.copyWith(id: categoryId);

        // Save to local database only
        await _localDb.saveCategory(localCategory);
        debugPrint('✅ Category saved locally with ID: $categoryId (offline mode)');

        return categoryId;
      }
    } catch (e) {
      debugPrint('❌ Error adding category: $e');

      // Robust fallback: always try to save locally
      try {
        final localId = 'local_fallback_${DateTime.now().millisecondsSinceEpoch}';
        final localCategory = category.copyWith(id: localId);
        await _localDb.saveCategory(localCategory);
        debugPrint('✅ Category saved locally as fallback with ID: $localId');
        return localId;
      } catch (localError) {
        debugPrint('❌ Local save also failed: $localError');
        rethrow;
      }
    }
  }

  ///working
  Future<void> updateCategory(Category category) async {
    try {
      if (_isOnline) {
        debugPrint('🔄 Updating category in Firestore: ${category.name} (${category.id})');
        await _firestoreServices.updateCategory(category);
      }

      // Always update local database for consistency (online or offline)
      await _localDb.saveCategory(category);
      debugPrint('✅ Category updated locally: ${category.name}');

    } catch (e) {
      debugPrint('❌ Error updating category: $e');

      // Fallback: update local database even if online fails
      try {
        await _localDb.saveCategory(category);
        debugPrint('✅ Category updated locally as fallback: ${category.name}');
      } catch (localError) {
        debugPrint('❌ Local update also failed: $localError');
        rethrow;
      }
    }
  }

  ///working
  Future<void> deleteCategory(String categoryId) async {
    try {
      if (_isOnline) {
        debugPrint('🔄 Deleting category from Firestore: $categoryId');
        await _firestoreServices.deleteCategory(categoryId);
      }

      // Always update local database for consistency
      await _localDb.deleteCategory(categoryId);
      debugPrint('✅ Category deleted locally: $categoryId');

    } catch (e) {
      debugPrint('❌ Error deleting category: $e');

      // Fallback: delete from local database even if online fails
      try {
        await _localDb.deleteCategory(categoryId);
        debugPrint('✅ Category deleted locally as fallback: $categoryId');
      } catch (localError) {
        debugPrint('❌ Local delete also failed: $localError');
        rethrow;
      }
    }
  }

  ///working
  Future<void> _syncPendingCategories() async {
    if (!_isOnline) {
      debugPrint('📱 Skipping category sync - offline');
      return;
    }

    try {
      final localCategories = await _localDb.getAllCategories();
      final localOnlyCategories = localCategories.where((cat) => cat.id.startsWith('local_')).toList();

      if (localOnlyCategories.isEmpty) {
        debugPrint('✅ No local-only categories to sync');
        return;
      }

      debugPrint('🔄 Syncing ${localOnlyCategories.length} local categories to Firestore...');

      for (final localCategory in localOnlyCategories) {
        try {
          // Add to Firestore and get the real ID
          final firestoreId = await _firestoreServices.addCategory(localCategory);

          // Update local category with Firestore ID
          final updatedCategory = localCategory.copyWith(id: firestoreId);
          await _localDb.saveCategory(updatedCategory);

          debugPrint('✅ Synced local category "${localCategory.name}" to Firestore with ID: $firestoreId');
        } catch (e) {
          debugPrint('❌ Failed to sync local category "${localCategory.name}": $e');
          // Continue with other categories even if one fails
        }
      }
    } catch (e) {
      debugPrint('❌ Error syncing pending categories: $e');
    }
  }

  void setTenantContext(String tenantId) {
    _firestoreServices.setTenantId(tenantId);
  }

  ///working
  Map<String, dynamic> _createEnhancedCartData(
      List<CartItem> cartItems,
      Map<String, dynamic>? additionalData, {
        double? cartDiscount,
        double? cartDiscountPercent,
        double? taxRate,
      }) {
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

  ///working
  Future<OrderCreationResult> createOrderWithEnhancedData(
      List<CartItem> cartItems,
      CustomerSelection customerSelection, {
        Map<String, dynamic>? additionalData,
        EnhancedCartManager? cartManager,
        CreditSaleData? creditSaleData,
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

        // Add credit sale data if provided
        if (creditSaleData != null) {
          enhancedData['creditSaleData'] = creditSaleData.toMap();

          // Update customer credit balance if this is a credit sale
          if (creditSaleData.isCreditSale && customerSelection.hasCustomer) {
            await _updateCustomerCreditBalance(
              customerSelection.customer!,
              creditSaleData,
            );
          }
        }

        final order = await _firestoreServices.createOrderWithEnhancedData(
          cartItems,
          customerSelection,
          enhancedData,
        );

        return OrderCreationResult.success(order);
      } else {
        // Enhanced offline order creation with credit support
        return await _createOfflineOrderWithCustomer(
          cartItems,
          customerSelection,
          additionalData: additionalData,
          creditSaleData: creditSaleData,
        );
      }
    } catch (e) {
      debugPrint('Enhanced order creation failed: $e');
      return OrderCreationResult.error('Failed to create order: $e');
    }
  }

  ///working
  Future<void> _updateCustomerCreditBalance(
      Customer customer,
      CreditSaleData creditSaleData,
      ) async {
    try {
      final newBalance = customer.currentBalance + creditSaleData.creditAmount;
      final updatedCustomer = customer.copyWithCredit(
        currentBalance: newBalance,
        totalCreditGiven: customer.totalCreditGiven + creditSaleData.creditAmount,
        lastCreditDate: DateTime.now(),
      );

      await updateCustomer(updatedCustomer);
    } catch (e) {
      debugPrint('Error updating customer credit balance: $e');
      throw Exception('Failed to update customer credit: $e');
    }
  }
  
  ///working
  Future<OrderCreationResult> _createOfflineOrderWithCustomer(
      List<CartItem> cartItems,
      CustomerSelection customerSelection, {
        Map<String, dynamic>? additionalData,
        CreditSaleData? creditSaleData,
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

      // Handle credit sale data if provided
      if (creditSaleData != null && creditSaleData.isCreditSale && customerSelection.hasCustomer) {
        // Update local customer credit balance
        await _updateCustomerCreditBalance(
          customerSelection.customer!,
          creditSaleData,
        );
      }

      await _localDb.clearCart();
      return OrderCreationResult.offline(pendingOrderId);
    } catch (e) {
      // print("Dagha chal de $e");
      return OrderCreationResult.error('Failed to save order locally: $e');
    }
  }

  // Get invoice settings
  ///working
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
  ///working
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

  // Enhanced Return operations with offline support
  ///working
  Future<ReturnCreationResult> createReturn(ReturnRequest returnRequest) async {
    if (_isOnline) {
      try {
        final createdReturn = await _firestoreServices.createReturn(returnRequest);
        // Save to local cache for offline access
        await _localDb.saveSyncedReturn(createdReturn);
        return ReturnCreationResult.success(createdReturn);
      } catch (e) {
        debugPrint('Online return creation failed, saving locally: $e');
        return await _createOfflineReturn(returnRequest);
      }
    } else {
      return await _createOfflineReturn(returnRequest);
    }
  }

  ///working
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
  
  ///working
  Future<List<ReturnRequest>> getAllReturns({int limit = 50}) async {
    if (_isOnline) {
      try {
        final returns = await _firestoreServices.getAllReturns(limit: limit);
        // Cache returns locally
        for (final returnReq in returns) {
          await _localDb.saveSyncedReturn(returnReq);
        }
        return returns;
      } catch (e) {
        debugPrint('Online fetch failed, using local data: $e');
        return await _localDb.getAllReturns();
      }
    } else {
      return await _localDb.getAllReturns();
    }
  }
  
  ///working
  Future<void> _syncPendingReturns() async {
    final pendingReturns = await _localDb.getPendingReturns();

    if (pendingReturns.isEmpty) {
      debugPrint('No pending returns to sync');
      return;
    }

    debugPrint('Syncing ${pendingReturns.length} pending returns...');

    for (final pendingReturn in pendingReturns) {
      try {
        final success = await _firestoreServices.syncPendingReturn(pendingReturn);

        if (success) {
          await _localDb.deletePendingReturn(pendingReturn['local_id']);
          debugPrint(
            'Successfully synced pending return ${pendingReturn['local_id']}',
          );
        } else {
          await _localDb.updatePendingReturnStatus(
            pendingReturn['local_id'],
            'failed',
          );
          debugPrint('Failed to sync pending return ${pendingReturn['local_id']}');
        }
      } catch (e) {
        debugPrint('Error syncing pending return ${pendingReturn['local_id']}: $e');
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
  ///working
  Future<void> _triggerSync() async {
    await _syncLock.synchronized(() async {
      try {
        debugPrint('🔄 Starting full sync...');
        await _syncPendingOrders();
        await _syncPendingRestocks();
        await _syncPendingReturns();
        await _syncPendingCategories();
        await _syncProducts();
        debugPrint('✅ Full sync completed successfully');
      } catch (e) {
        debugPrint('❌ Sync error: $e');
      }
    });
  }

  // Add to EnhancedPOSService class
  ///working
  Future<List<AppOrder>> searchOrders(String query) async {
    return await _firestoreServices.searchOrders(query);
  }

  ///working
  Future<AppOrder?> getOrderById(String orderId) async {
    return await _firestoreServices.getOrderById(orderId);
  }

  ///working
  Future<List<AppOrder>> getRecentOrders({int limit = 50}) async {
    return await _firestoreServices.getRecentOrders(limit: limit);
  }

  ///working
  Future<List<Customer>> searchCustomers(String query) async {
    return await _firestoreServices.searchCustomers(query);
  }

  ///working
  Future<List<Customer>> getAllCustomers() async {
    try {
      if (_isOnline) {
        // Get all customers from Firestore
        final snapshot = await _firestoreServices.customersRef
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
      debugPrint('Error getting all customers: $e');
      // Fallback to local data if online fetch fails
      return await _localDb.getCustomers();
    }
  }

  ///working
Future<Customer?> getCustomerById(String id) async {
    return await _firestoreServices.getCustomerById(id);
  }
  
  ///working
  Future<String> addCustomer(Customer customer) async {
    return await _firestoreServices.addCustomer(customer);
  }

  ///working
  Future<void> updateCustomer(Customer customer) async {
    await _firestoreServices.updateCustomer(customer);
  }

  void initialize() {
    _startConnectivityListener();
    _checkInitialConnection();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  ///working
  Future<void> refreshLocalCache() async {
    if (_isOnline) {
      try {
        // Clear existing cache and fetch fresh data
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(LocalDatabase.productsBox);

        // Fetch fresh products
        await _syncProducts();
      } catch (e) {
        debugPrint('Error refreshing local cache: $e');
      }
    }
  }

  ///working
  Future<void> _startConnectivityListener() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        List<ConnectivityResult> resultList,
        ) {
      final wasOnline = _isOnline;
      _isOnline = resultList.any((res) => res != ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        _triggerSync();
        refreshLocalCache();
      }
    });
  }

  ///working
  Future<void> _checkInitialConnection() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    if (_isOnline) {
      _triggerSync();
    }
  }
  
  ///working
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
        final products = await _firestoreServices.getProducts(
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
        debugPrint('Online fetch failed, using local data: $e');
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

  ///working
  Future<List<Product>> searchProducts(String query) async {
    if (_isOnline) {
      try {
        final products = await _firestoreServices.searchProducts(query);
        if (products.isNotEmpty) {
          await _localDb.saveProducts(products);
        }
        return products;
      } catch (e) {
        debugPrint('Online search failed, using local data: $e');
        return await _localDb.getProducts(searchQuery: query);
      }
    } else {
      return await _localDb.getProducts(searchQuery: query);
    }
  }

  ///working
  Future<List<Product>> searchProductsBySKU(String sku) async {
    final localProduct = await _localDb.getProductBySku(sku);
    if (localProduct != null) {
      return [localProduct];
    }

    if (_isOnline) {
      try {
        final products = await _firestoreServices.searchProductsBySKU(sku);
        if (products.isNotEmpty) {
          await _localDb.saveProducts(products);
        }
        return products;
      } catch (e) {
        debugPrint('Online SKU search failed: $e');
        return [];
      }
    } else {
      return [];
    }
  }
  
  ///working
  Future<void> _syncPendingOrders() async {
    final pendingOrders = await _localDb.getPendingOrders();

    if (pendingOrders.isEmpty) {
      debugPrint('No pending orders to sync');
      return;
    }

    debugPrint('Syncing ${pendingOrders.length} pending orders...');

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

        final createdOrder = await _firestoreServices.createOrder(lineItems);
        await _localDb.deletePendingOrder(order['id']);

        debugPrint(
          'Successfully synced pending order ${order['id']} as order ${createdOrder.id}',
        );
      } catch (e) {
        debugPrint('Failed to sync pending order ${order['id']}: $e');
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

  ///working
  Future<void> _syncPendingRestocks() async {
    final pendingRestocks = await _localDb.getPendingRestocks();

    if (pendingRestocks.isEmpty) {
      debugPrint('No pending restocks to sync');
      return;
    }

    debugPrint('Syncing ${pendingRestocks.length} pending restocks...');

    for (final restock in pendingRestocks) {
      try {
        await _firestoreServices.restockProduct(
          restock['productId'].toString(),
          restock['quantity'] as int,
          barcode: restock['barcode']?.toString(),
        );
        await _localDb.deletePendingRestock(restock['id']);
        debugPrint(
          'Successfully synced restock for product ${restock['productId']}',
        );
      } catch (e) {
        debugPrint('Failed to sync restock ${restock['id']}: $e');
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

  ///working
  Future<void> _syncProducts() async {
    try {
      final products = await _firestoreServices.getProducts(limit: 50);
      await _localDb.saveProducts(products);
      debugPrint('Successfully synced ${products.length} products');
    } catch (e) {
      debugPrint('Product sync failed: $e');
    }
  }

  ///working
  Future<void> manualSync() async {
    if (_isOnline) {
      await _triggerSync();
    }
  }

  // Product management methods
  ///working
  Future<String> addProduct(Product product, List<XFile>? images) async {
    return await _firestoreServices.addProduct(product, images);
  }

  ///working
  Future<void> updateProduct(Product product, List<XFile>? newImages) async {
    await _firestoreServices.updateProduct(product, newImages);
  }

  ///working
  Future<void> deleteProduct(String productId) async {
    await _firestoreServices.deleteProduct(productId);
  }

  ///working
  Future<void> restockProduct(
      String productId,
      int quantity, {
        String? barcode,
      }) async {
    if (_isOnline) {
      try {
        await _firestoreServices.restockProduct(productId, quantity, barcode: barcode);
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

  ///working
  Future<void> _savePendingRestock(
      String productId,
      int quantity,
      String? barcode,
      ) async {
    await _localDb.savePendingRestock(productId, quantity, barcode);
    // Also update local product cache immediately for offline use
    await _updateLocalProductStock(productId, quantity);
  }

  ///working
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

  ///working
  Future<void> _syncLocalProductAfterRestock(
      String productId,
      int quantity,
      ) async {
    await _updateLocalProductStock(productId, quantity);
  }

  bool get isOnline => _isOnline;

  ///working
  Stream<bool> get onlineStatusStream =>
      _connectivity.onConnectivityChanged.map(
            (List<ConnectivityResult> resultList) =>
            resultList.any((res) => res != ConnectivityResult.none),
      );

  ///working
  Future<bool> testConnection() async {
    return _firestoreServices.testConnection();
  }
}

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  _MainNavScreenState createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  final CreditService _creditService = CreditService();
  int _currentIndex = 0;
  final EnhancedCartManager _cartManager = EnhancedCartManager();
  final EnhancedPOSService _posService = EnhancedPOSService();
  bool _isTestingConnection = false;
  String _connectionStatus = '';

  bool _isOnline = false;
  int _cartItemCount = 0;
  final List<Widget> _clientAdminScreens = [];
  final List<Widget> _clientSalesManagerScreens = [];
  final List<Widget> _clientCashierScreens = [];
  AnalyticsService _analyticsService = AnalyticsService();
  final GlobalKey<LiquidPullToRefreshState> _refreshIndicatorKey = GlobalKey<LiquidPullToRefreshState>();
  bool _isRefreshing = false;

  // FIXED: Proper callback methods
  void _handleMenuNavigation(int index) {
    if (mounted) {
      Navigator.pop(context); // Close the menu
      setState(() => _currentIndex = index);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      OverlayManager.showToast(
        context: context,
        message: message,
        duration: Duration(seconds: 2),
      );
    }
  }
  void navigateToInvoices(){
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrdersManagementScreen(),
      ),
    );
  }
  void _handleQuickAction(String action) {
    switch (action) {
      case 'scan':
        showModalBottomSheet(
          context: context,
          builder: (context) => SmartQRScannerWidget(showInDashboard: true),
        );
        break;
      case 'invoices':
        navigateToInvoices();
        break;
      case 'credit':
        _handleMenuNavigation(13); // Navigate to Credit Management
        break;
      case 'reports':
        _showSnackBar('Reports feature coming soon');
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

// UPDATE the initialize method
  Future<void> _initializeApp() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final tenantId = authProvider.currentUser?.tenantId;
    _analyticsService = AnalyticsService();

    if (tenantId != null && tenantId != 'super_admin') {
      _posService.setTenantContext(tenantId);
      _creditService.setTenantId(tenantId);
      debugPrint('Tenant context set: $tenantId');
    }

    if (tenantId != null) {
      _analyticsService.setTenantId(tenantId);
    }

    _initializeScreens(authProvider);
    _posService.initialize();
    await _cartManager.initialize();

    // Check connectivity immediately
    await _checkInitialConnectivity();

    // Then setup listener for changes
    _setupConnectivityListener();

    // Listen to cart item count changes
    _cartManager.itemCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _cartItemCount = count;
        });
      }
    });

    await _testConnection();
  }
  void _initializeScreens(MyAuthProvider authProvider) {
    final user = authProvider.currentUser;

    // Clear existing screens first
    _clientAdminScreens.clear();
    _clientSalesManagerScreens.clear();
    _clientCashierScreens.clear();

    // Admin Screens - Full access (13 screens)
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
      ExpenseManagementScreen(analyticsService: _analyticsService),
      // Credit Management Screens
      CustomerCommunicationScreen(
        creditService: _creditService,
        posService: _posService,
      ),
      CreditCollectionScreen(creditService: _creditService),
      CreditAnalyticsScreen(creditService: _creditService),
    ]);

    // Sales Manager Screens - Limited access (8 screens)
    _clientSalesManagerScreens.addAll([
      ModernDashboardScreen(),
      ProductSellingScreen(cartManager: _cartManager),
      CartScreen(cartManager: _cartManager),
      AnalyticsDashboardScreen(),
      ProductManagementScreen(),
      CategoryManagementScreen(),
      ReturnsManagementScreen(),
      ModernCustomerManagementScreen(posService: _posService),
      // Credit screens accessible only through More menu
    ]);

    // Cashier Screens - Basic access (6 screens)
    _clientCashierScreens.addAll([
      ModernDashboardScreen(),
      ProductSellingScreen(cartManager: _cartManager),
      CartScreen(cartManager: _cartManager),
      ReturnsManagementScreen(),
      ProfileScreen(),
      // Limited access screens
    ]);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _testConnection() async {
    if (!mounted) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = 'Testing connection...';
    });

    try {
      final success = await _posService.testConnection();
      if (mounted) {
        setState(() {
          _connectionStatus = success
              ? 'Online - Connected'
              : 'Offline - Working Locally';
          _isOnline = success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = 'Offline - ${e.toString()}';
          _isOnline = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _manualSync() async {
    if (_isOnline && mounted) {
      setState(() {
        _isTestingConnection = true;
        _connectionStatus = 'Syncing data...';
      });

      try {
        await _posService.manualSync();
        await _refreshCreditData();

        if (mounted) {
          setState(() {
            _isTestingConnection = false;
            _connectionStatus = 'Sync completed ✅';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isTestingConnection = false;
            _connectionStatus = 'Sync failed ❌';
          });
        }
      }

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

  Future<void> _refreshCreditData() async {
    try {
      await _creditService.getAllCreditCustomers();
    } catch (e) {
      debugPrint('Error refreshing credit data: $e');
    }
  }

  Future<void> _handleRefresh() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }
    await _manualSync();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Widget _buildRefreshableScreen(Widget screen) {
    return LiquidPullToRefresh(
      key: _refreshIndicatorKey,
      onRefresh: _handleRefresh,
      color: ThemeUtils.primary(context),
      backgroundColor: Colors.white,
      height: 100,
      animSpeedFactor: 2,
      showChildOpacityTransition: false,
      child: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [SliverFillRemaining(hasScrollBody: false, child: screen)],
      ),
    );
  }

  // FIXED: Navigation handlers
  void _handleBottomNavigationTap(int index, MyAuthProvider authProvider) {
    if (index == 4) {
      _showMoreMenu(context, authProvider);
    } else {
      // Handle credit screen access
      if (index >= 13 && index <= 15) {
        final feature = index == 13 ? 'credit_overview' :
        index == 14 ? 'credit_recovery' : 'credit_analytics';
        _handleCreditFeatureAccess(feature, authProvider);
      }
      if (mounted) {
        setState(() => _currentIndex = index);
      }
    }
  }

  void _handleCreditFeatureAccess(String feature, MyAuthProvider authProvider) {
    final user = authProvider.currentUser;

    if (feature == 'credit_analytics' && !user!.canManageUsers) {
      _showAccessDeniedDialog(
        title: 'Advanced Analytics Access',
        message: 'Credit analytics are available to administrators only.',
      );
      return;
    }

    if (feature == 'credit_recovery' && !(user!.canManageUsers || user.canManageProducts)) {
      _showAccessDeniedDialog(
        title: 'Credit Recovery Access',
        message: 'Credit recovery features are available to managers and administrators.',
      );
      return;
    }
  }

  void _showAccessDeniedDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // FIXED: Cart icon with badge
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

  // FIXED: More icon with credit alerts
  Widget _buildMoreIcon() {
    return FutureBuilder<CreditStats>(
      future: _getCreditStats(),
      builder: (context, snapshot) {
        final creditStats = snapshot.data ?? CreditStats.zero();
        final hasOverdue = creditStats.overdueAmount > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.more_horiz),
            if (hasOverdue)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                  child: Text(
                    '!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
// In MainNavScreen class - REPLACE the existing connectivity setup
  void _setupConnectivityListener() {
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
  }

// ADD this method to check initial connectivity immediately
  Future<void> _checkInitialConnectivity() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    final isOnline = result != ConnectivityResult.none;

    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _connectionStatus = isOnline
            ? 'Online - Connected'
            : 'Offline - Working Locally';
      });
    }
  }

  // FIXED: Add the missing _showMoreMenu method
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
            index: user!.canManageUsers ? 10 : 4, // Different index for different roles
          ),
          MenuItem(
            icon: Icons.assignment_return_outlined,
            title: 'Returns',
            description: 'Process product returns',
            color: Colors.orange,
            index: user.canManageUsers ? 6 : 3, // Different index for different roles
          ),
          MenuItem(
            icon: Icons.group_outlined,
            title: 'Customers',
            description: 'Manage customer database',
            color: Colors.teal,
            index: user.canManageUsers ? 11 : 5, // Different index for different roles
          ),
          MenuItem(
            icon: Icons.report_problem_outlined,
            title: 'Support Tickets',
            description: 'Get technical assistance',
            color: Colors.red,
            index: user.canManageUsers ? 9 : 6, // Different index for different roles
          ),
        ],
      ),

      // Credit Management Section - Role-based access
      if (user.canManageUsers || user.canManageProducts)
        MenuSection(
          title: 'Credit Management',
          items: [
            MenuItem(
              icon: Icons.credit_card_outlined,
              title: 'Customer Communication',
              description: 'Communicate with Customers',
              color: Colors.purple,
              index: user.canManageUsers ? 13 : 7,
            ),
            if (user.canManageUsers || user.canManageProducts)
              MenuItem(
                icon: Icons.payment_outlined,
                title: 'Credit Collection',
                description: 'Track and collect overdue payments',
                color: Colors.deepOrange,
                index: user.canManageUsers ? 14 : 8,
              ),
            if (user.canManageUsers)
              MenuItem(
                icon: Icons.analytics_outlined,
                title: 'Credit Analytics',
                description: 'Advanced credit insights and reports',
                color: Colors.indigo,
                index: 15,
              ),
          ],
        ),

      // Business Management - Admin & Sales Manager
      if (user.canManageUsers || user.canManageProducts)
        MenuSection(
          title: 'Business Management',
          items: [
            if (user.canManageUsers)
              MenuItem(
                icon: Icons.receipt_long_outlined,
                title: 'Expense Management',
                description: 'Track business expenses',
                color: Colors.purple,
                index: 12,
              ),
            MenuItem(

              icon: Icons.inventory_2_outlined,
              title: 'Inventory',
              description: 'Manage product stock',
              color: Colors.green,
              index: user.canManageUsers ? 4 : 9,
            ),
            MenuItem(
              icon: Icons.category_outlined,
              title: 'Categories',
              description: 'Organize product categories',
              color: Colors.indigo,
              index: user.canManageUsers ? 5 : 10,
            ),
          ],
        ),

      // Administration - Admin only
      if (user.canManageUsers)
        MenuSection(
          title: 'Administration',
          items: [
            MenuItem(
              icon: Icons.people_outlined,
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
                ThemeUtils.surface(context).withValues(alpha: 0.95),
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
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
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
                              style: ThemeUtils.headlineMedium(context).copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Quick access to all features',
                              style: ThemeUtils.bodySmall(context).copyWith(
                                color: ThemeUtils.textSecondary(context).withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ThemeUtils.primary(context).withValues(alpha: 0.1),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.close_rounded, color: ThemeUtils.primary(context)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // User info card
                FutureBuilder<CreditStats>(
                  future: _getCreditStats(),
                  builder: (context, snapshot) {
                    final creditStats = snapshot.data ?? CreditStats.zero();

                    return Container(
                      margin: EdgeInsets.all(16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ThemeUtils.primary(context).withValues(alpha: 0.1),
                            ThemeUtils.primary(context).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ThemeUtils.primary(context).withValues(alpha: 0.2),
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
                                  style: ThemeUtils.bodyLarge(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _getUserRole(user),
                                  style: ThemeUtils.bodySmall(context).copyWith(
                                    color: ThemeUtils.primary(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (creditStats.totalOutstanding > 0) ...[
                                  SizedBox(height: 4),
                                  Text(
                                    '${Constants.CURRENCY_NAME}${creditStats.totalOutstanding.toStringAsFixed(0)} Credit Outstanding',
                                    style: ThemeUtils.bodySmall(context).copyWith(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isOnline ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
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
                                      style: ThemeUtils.bodySmall(context).copyWith(
                                        color: _isOnline ? Colors.green : Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (creditStats.overdueAmount > 0) ...[
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '${Constants.CURRENCY_NAME}${creditStats.overdueAmount.toStringAsFixed(0)} Overdue',
                                    style: ThemeUtils.bodySmall(context).copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Quick Actions
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Quick Actions',
                        style: ThemeUtils.bodyLarge(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: ThemeUtils.textSecondary(context),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 80,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildQuickActionChip(
                            icon: Icons.qr_code_scanner,
                            label: 'Scan',
                            onTap: () => _handleQuickAction('scan'),
                          ),
                          _buildQuickActionChip(
                            icon: Icons.receipt,
                            label: 'Invoices',
                            onTap: () => _handleQuickAction('invoices'),
                          ),
                          _buildQuickActionChip(
                            icon: Icons.credit_card,
                            label: 'Credit',
                            onTap: () => _handleQuickAction('credit'),
                          ),
                          _buildQuickActionChip(
                            icon: Icons.analytics,
                            label: 'Reports',
                            onTap: () => _handleQuickAction('reports'),
                          ),
                          _buildQuickActionChip(
                            icon: Icons.sync,
                            label: 'Sync',
                            onTap: _manualSync,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Menu Sections
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      ...menuSections.map((section) => SliverList(
                        delegate: SliverChildListDelegate([
                          SizedBox(height: 16),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              section.title,
                              style: ThemeUtils.bodyLarge(context).copyWith(
                                fontWeight: FontWeight.w600,
                                color: ThemeUtils.textSecondary(context),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          ...section.items.map((item) => _buildModernMenuItem(
                            item: item,
                            onTap: () => _handleMenuItemTap(item, authProvider),
                          )),
                        ]),
                      )),
                      SliverToBoxAdapter(child: SizedBox(height: 30)),
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

  void _handleMenuItemTap(MenuItem item, MyAuthProvider authProvider) {
    // Handle role-based access for credit features
    final user = authProvider.currentUser;

    if (item.index == 14 && !(user!.canManageUsers || user.canManageProducts)) {
      _showAccessDeniedDialog(
        title: 'Credit Recovery Access',
        message: 'Credit recovery features are available to managers and administrators.',
      );
      return;
    }

    if (item.index == 15 && !user!.canManageUsers) {
      _showAccessDeniedDialog(
        title: 'Advanced Analytics Access',
        message: 'Credit analytics are available to administrators only.',
      );
      return;
    }

    _handleMenuNavigation(item.index);
  }

  Widget _buildQuickActionChip({
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
              color: ThemeUtils.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ThemeUtils.primary(context).withValues(alpha: 0.2),
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
                  style: ThemeUtils.bodySmall(context).copyWith(
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

  Widget _buildModernMenuItem({
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
              color: ThemeUtils.card(context)[0].withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ThemeUtils.card(context)[1].withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.color.withValues(alpha: 0.2),
                        item.color.withValues(alpha: 0.1),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: ThemeUtils.bodyLarge(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        item.description,
                        style: ThemeUtils.bodySmall(context).copyWith(
                          color: ThemeUtils.textSecondary(context).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: ThemeUtils.textSecondary(context).withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getUserRole(AppUser user) {
    if (user.canManageUsers) return 'Administrator';
    if (user.canManageProducts) return 'Sales Manager';
    return 'Cashier';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final user = authProvider.currentUser;
    final tenantId = user?.tenantId ?? 'No Tenant ID';

    // Get the appropriate screen list based on user role
    List<Widget> currentScreens = _clientAdminScreens;
    if (user!.canManageProducts && !user.canManageUsers) {
      currentScreens = _clientSalesManagerScreens;
    } else if (!user.canManageProducts && !user.canManageUsers) {
      currentScreens = _clientCashierScreens;
    }

    // Ensure current index is within bounds
    if (_currentIndex >= currentScreens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12,bottom: 12),
            child: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllInOnePOSScreen(cartManager: _cartManager),
                  ),
                );
              },
              backgroundColor: Theme.of(context).highlightColor,
              foregroundColor: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              icon: const Icon(Icons.rocket_launch_rounded, size: 20),
              label: const Text(
                "QUICK SALE",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
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
                color: ThemeUtils.textOnPrimary(context),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_connectionStatus.isNotEmpty)
              Text(
                _isOnline ? 'Online - Connected' : 'Offline - Working Locally',
                style: TextStyle(
                  fontSize: 12,
                  color: ThemeUtils.textOnPrimary(context),
                ),
              ),          ],
        ),
        backgroundColor: _isOnline ? ThemeUtils.primary(context) : ThemeUtils.secondary(context),
        elevation: 0,
      ),
      body: currentScreens.isEmpty
          ? Center(child: CircularProgressIndicator())
          : _isOnline
          ? _buildRefreshableScreen(currentScreens[_currentIndex])
          : currentScreens[_currentIndex],
      bottomNavigationBar: _buildBottomNavigationBar(authProvider, currentScreens.length),
    );
  }

  Widget _buildBottomNavigationBar(MyAuthProvider authProvider, int screenCount) {
    final user = authProvider.currentUser!;

    // Determine which navigation bar to show based on user role
    if (user.canManageUsers) {
      return _buildAdminNavigationBar(authProvider);
    } else if (user.canManageProducts) {
      return _buildManagerNavigationBar(authProvider);
    } else {
      return _buildCashierNavigationBar(authProvider);
    }
  }

  Widget _buildAdminNavigationBar(MyAuthProvider authProvider) {
    return BottomNavigationBar(
      selectedItemColor: ThemeUtils.primary(context),
      unselectedItemColor: ThemeUtils.accentColor(context),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex < 5 ? _currentIndex : 4,
      onTap: (index) => _handleBottomNavigationTap(index, authProvider),
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
          icon: _buildMoreIcon(),
          activeIcon: _buildMoreIcon(),
          label: 'More',
        ),
      ],
    );
  }

  Widget _buildManagerNavigationBar(MyAuthProvider authProvider) {
    return BottomNavigationBar(
      selectedItemColor: ThemeUtils.primary(context),
      unselectedItemColor: ThemeUtils.accentColor(context),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex < 4 ? _currentIndex : 3,
      onTap: (index) => _handleBottomNavigationTap(index, authProvider),
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
          icon: _buildMoreIcon(),
          activeIcon: _buildMoreIcon(),
          label: 'More',
        ),
      ],
    );
  }

  Widget _buildCashierNavigationBar(MyAuthProvider authProvider) {
    return BottomNavigationBar(
      selectedItemColor: ThemeUtils.primary(context),
      unselectedItemColor: ThemeUtils.accentColor(context),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex < 3 ? _currentIndex : 2,
      onTap: (index) {
        if (index == 3) {
          _showMoreMenu(context, authProvider);
        } else {
          if (mounted) {
            setState(() => _currentIndex = index);
          }
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
          icon: _buildMoreIcon(),
          activeIcon: _buildMoreIcon(),
          label: 'More',
        ),
      ],
    );
  }

  @override
  void dispose() {
    _posService.dispose();
    _cartManager.dispose();
    super.dispose();
  }
}

// FIXED: Add the missing CreditStats class and method
class CreditStats {
  final double totalOutstanding;
  final double overdueAmount;
  final int overdueCustomers;

  const CreditStats({
    required this.totalOutstanding,
    required this.overdueAmount,
    required this.overdueCustomers,
  });

  factory CreditStats.zero() {
    return CreditStats(
      totalOutstanding: 0.0,
      overdueAmount: 0.0,
      overdueCustomers: 0,
    );
  }
}

Future<CreditStats> _getCreditStats() async {
  CreditService creditService = CreditService();
  try {
    final creditCustomers = await creditService.getAllCreditCustomers();
    final totalOutstanding = creditCustomers.fold(0.0, (sum, customer) => sum + customer.currentBalance);
    final overdueAmount = creditCustomers.fold(0.0, (sum, customer) => sum + customer.overdueAmount);
    final overdueCustomers = creditCustomers.where((customer) => customer.overdueCount > 0).length;

    return CreditStats(
      totalOutstanding: totalOutstanding,
      overdueAmount: overdueAmount,
      overdueCustomers: overdueCustomers,
    );
  } catch (e) {
    debugPrint('Error fetching credit stats: $e');
    return CreditStats.zero();
  }
}

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

class ScreenSelectionProvider extends ChangeNotifier{
  Widget _currentScreen = ModernDashboardScreen();
  Widget get  currentScreen => _currentScreen;

  selectScreen(Widget selectedScreen){
    _currentScreen = selectedScreen ;
    notifyListeners();
  }
}