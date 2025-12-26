import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mpcm/core/models/category_model.dart' show Category;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../constants.dart';
import '../../core/models/app_order_model.dart';
import '../../core/models/cart_item_model.dart';
import '../../core/models/customer_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/return_request.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../theme_utils.dart';
import '../connectivityBase/local_db_base.dart' hide CustomerSelection;
import '../customerBase/customer_base.dart';
import '../main_navigation/main_navigation_base.dart';


class OrderCreationResult {
  final bool success;
  final AppOrder? order;
  final int? pendingOrderId;
  final String? error;

  OrderCreationResult.success(this.order)
      : success = true,
        pendingOrderId = null,
        error = null;

  OrderCreationResult.offline(this.pendingOrderId)
      : success = true,
        order = null,
        error = null;

  OrderCreationResult.error(this.error)
      : success = false,
        order = null,
        pendingOrderId = null;

  bool get isOffline => pendingOrderId != null;
}


// Business Settings Model
class BusinessSettings {
  final String id;
  final String businessName;
  final String businessCode;
  final DateTime dateCreated;
  final DateTime dateModified;

  BusinessSettings({
    required this.id,
    required this.businessName,
    required this.businessCode,
    required this.dateCreated,
    required this.dateModified,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'businessName': businessName,
      'businessCode': businessCode,
      'dateCreated': Timestamp.fromDate(dateCreated),
      'dateModified': Timestamp.fromDate(dateModified),
    };
  }

  static BusinessSettings fromFirestore(Map<String, dynamic> data, String id) {
    return BusinessSettings(
      id: id,
      businessName: data['businessName'] ?? '',
      businessCode: data['businessCode'] ?? 'POS',
      dateCreated: (data['dateCreated'] as Timestamp).toDate(),
      dateModified: (data['dateModified'] as Timestamp).toDate(),
    );
  }

  static BusinessSettings createDefault() {
    final now = DateTime.now();
    return BusinessSettings(
      id: 'business_settings',
      businessName: '',
      businessCode: 'POS',
      dateCreated: now,
      dateModified: now,
    );
  }
}

// Sequence Counter Model
class SequenceCounter {
  final String id;
  final String type; // 'order' or 'invoice'
  final int lastSequence;
  final int year; // For order sequences (0 for invoice)
  final DateTime lastUpdated;

  SequenceCounter({
    required this.id,
    required this.type,
    required this.lastSequence,
    required this.year,
    required this.lastUpdated,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type,
      'lastSequence': lastSequence,
      'year': year,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  static SequenceCounter fromFirestore(Map<String, dynamic> data, String id) {
    return SequenceCounter(
      id: id,
      type: data['type'],
      lastSequence: data['lastSequence'],
      year: data['year'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }
}

class FirestoreServices {
  String? _currentTenantId;

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }
// ========== COMPLETE SYNC METHODS FOR PENDING DATA ==========

  /// Sync a full pending order with all enhanced data
  Future<AppOrder> syncFullPendingOrder(Map<String, dynamic> pendingOrder) async {
    try {
      debugPrint('🔄 Syncing full pending order #${pendingOrder['id']}');

      // Extract all data from pending order
      final orderId = pendingOrder['id'] as int;
      final orderData = pendingOrder['order_data'] as Map<String, dynamic>;
      final customerData = pendingOrder['customer_data'] as Map<String, dynamic>?;
      final paymentData = pendingOrder['payment_data'] as Map<String, dynamic>;
      final discountSummary = pendingOrder['discount_summary'] as Map<String, dynamic>?;
      final settingsUsed = pendingOrder['settings_used'] as Map<String, dynamic>?;
      final additionalData = pendingOrder['additional_data'] as Map<String, dynamic>?;
      final String createdAt = pendingOrder['created_at'] as String;

      // Use the original order number from pending data or generate new
      String orderNumber;
      if (orderData.containsKey('number')) {
        orderNumber = orderData['number'] as String;
      } else {
        orderNumber = await generateOrderNumber();
      }

      // Convert line items back to CartItem format for stock updates
      final lineItems = orderData['line_items'] as List<dynamic>;
      final cartItems = lineItems.map((item) {
        final itemMap = item as Map<String, dynamic>;

        // Create a minimal Product for CartItem
        final product = Product(
          id: itemMap['product_id'] as String,
          name: itemMap['product_name'] as String,
          sku: itemMap['product_sku'] as String? ?? '',
          price: (itemMap['price'] as num).toDouble(),
          regularPrice: (itemMap['price'] as num).toDouble(),
          salePrice: (itemMap['price'] as num).toDouble(),
          stockQuantity: 0, // Will be updated separately
          inStock: true,
          stockStatus: 'instock',
          purchasable: true,
          status: 'publish',
          dateCreated: DateTime.now(),
          dateModified: DateTime.now(),
          imageUrl: null,
          imageUrls: [],
          description: '',
          shortDescription: '',
          categories: [],
          attributes: [],
          metaData: {},
          type: 'simple',
          featured: false,
          permalink: '',
          averageRating: 0,
          ratingCount: 0,
          parentId: '',
          variations: [],
          weight: null,
          dimensions: null,
        );

        return CartItem(
          product: product,
          quantity: (itemMap['quantity'] as num).toInt(),
          manualDiscount: (itemMap['manual_discount'] as num?)?.toDouble(),
          manualDiscountPercent: (itemMap['manual_discount_percent'] as num?)?.toDouble(),
        );
      }).toList();

      // Prepare customer selection
      CustomerSelection customerSelection;
      if (customerData != null && customerData['customerId'] != null) {
        final customer = Customer(
          id: customerData['customerId'] as String,
          firstName: customerData['firstName'] as String,
          lastName: customerData['lastName'] as String? ?? '',
          email: customerData['email'] as String? ?? '',
          phone: customerData['phone'] as String? ?? '',
          company: customerData['company'] as String?,
          address1: customerData['address1'] as String?,
          address2: customerData['address2'] as String?,
          city: customerData['city'] as String?,
          state: customerData['state'] as String?,
          postcode: customerData['postcode'] as String?,
          country: customerData['country'] as String?,
          currentBalance: 0.0,
          creditLimit: 0.0,
          totalCreditGiven: 0.0,
          totalCreditPaid: 0.0,
          metaData: {},
          creditTerms: {},
          overdueAmount: 0.0,
          overdueCount: 0,
        );
        customerSelection = CustomerSelection(customer: customer);
      } else {
        customerSelection = CustomerSelection();
      }

      // Prepare enhanced data
      final enhancedData = <String, dynamic>{
        'cartData': {
          'subtotal': orderData['pricing_breakdown']?['subtotal'] ?? 0.0,
          'item_discounts': orderData['pricing_breakdown']?['item_discounts'] ?? 0.0,
          'cart_discount': orderData['pricing_breakdown']?['cart_discount'] ?? 0.0,
          'cart_discount_percent': orderData['pricing_breakdown']?['cart_discount_percent'] ?? 0.0,
          'cart_discount_amount': orderData['pricing_breakdown']?['cart_discount_amount'] ?? 0.0,
          'total_discount': orderData['pricing_breakdown']?['total_discount'] ?? 0.0,
          'taxable_amount': orderData['pricing_breakdown']?['taxable_amount'] ?? 0.0,
          'tax_rate': orderData['pricing_breakdown']?['tax_rate'] ?? 0.0,
          'tax_amount': orderData['pricing_breakdown']?['tax_amount'] ?? 0.0,
          'shipping_amount': orderData['pricing_breakdown']?['shipping_amount'] ?? 0.0,
          'tip_amount': orderData['pricing_breakdown']?['tip_amount'] ?? 0.0,
          'totalAmount': orderData['total'] ?? orderData['pricing_breakdown']?['final_total'] ?? 0.0,
        },
        'paymentMethod': paymentData['method'] ?? 'cash',
        'additionalDiscount': orderData['pricing_breakdown']?['additional_discount'] ?? 0.0,
        'shippingAmount': orderData['pricing_breakdown']?['shipping_amount'] ?? 0.0,
        'tipAmount': orderData['pricing_breakdown']?['tip_amount'] ?? 0.0,
      };

      // Add discount summary if available
      if (discountSummary != null) {
        enhancedData['discountSummary'] = discountSummary;
      }

      // Add settings used if available
      if (settingsUsed != null) {
        enhancedData['invoiceSettings'] = {
          'discountRate': settingsUsed['default_discount_rate'] ?? 0.0,
        };
        // if (settingsUsed['business_info_used'] == true) {
        //   enhancedData['businessInfo'] = await getBusinessInfo();
        // }
      }

      // Add credit sale data if present
      if (additionalData != null && additionalData['isCreditSale'] == true) {
        enhancedData['isCreditSale'] = true;
        enhancedData['creditAmount'] = additionalData['creditAmount'];
        enhancedData['paidAmount'] = additionalData['paidAmount'];
        enhancedData['previousBalance'] = additionalData['previousBalance'];
        enhancedData['newBalance'] = additionalData['newBalance'];
        enhancedData['notes'] = additionalData['notes'];
        enhancedData['creditTerms'] = additionalData['creditTerms'];
      }

      // Use the existing order creation method
      final createdOrder = await createOrderWithEnhancedData(
        cartItems,
        customerSelection,
        enhancedData,
      );

      debugPrint('✅ Successfully synced pending order #$orderId as ${createdOrder.id}');
      return createdOrder;

    } catch (e) {
      debugPrint('❌ Error syncing full pending order: $e');
      rethrow;
    }
  }

  /// Sync a pending return with all its data
  Future<ReturnRequest> syncFullPendingReturn(Map<String, dynamic> pendingReturn) async {
    try {
      debugPrint('🔄 Syncing pending return #${pendingReturn['local_id']}');

      // Extract all return data
      final returnRequest = ReturnRequest.fromLocalMap(pendingReturn);

      // Create the return in Firestore
      await createReturn(returnRequest);

      debugPrint('✅ Successfully synced pending return #${pendingReturn['local_id']}');
      return returnRequest;

    } catch (e) {
      debugPrint('❌ Error syncing pending return: $e');
      rethrow;
    }
  }

  /// Sync a pending restock operation
  Future<void> syncFullPendingRestock(Map<String, dynamic> pendingRestock) async {
    try {
      debugPrint('🔄 Syncing pending restock #${pendingRestock['id']}');

      final productId = pendingRestock['productId'] as String;
      final quantity = pendingRestock['quantity'] as int;
      final barcode = pendingRestock['barcode'] as String?;

      // Restock the product
      await restockProduct(productId, quantity, barcode: barcode);

      debugPrint('✅ Successfully synced restock for product $productId');

    } catch (e) {
      debugPrint('❌ Error syncing pending restock: $e');
      rethrow;
    }
  }

  /// Sync a pending category
  Future<void> syncFullPendingCategory(Map<String, dynamic> pendingCategory) async {
    try {
      debugPrint('🔄 Syncing pending category: ${pendingCategory['name']}');

      final category = Category(
        id: pendingCategory['id'] as String,
        name: pendingCategory['name'] as String,
        slug: pendingCategory['slug'] as String,
        description: pendingCategory['description'] as String?,
        // parentId: pendingCategory['parentId'] as String?,
        count: pendingCategory['count'] as int? ?? 0,
        // display: pendingCategory['display'] as String? ?? 'default',
        imageUrl: pendingCategory['imageUrl'] as String?,
        // dateCreated: DateTime.parse(pendingCategory['dateCreated'] as String),
        // dateModified: DateTime.parse(pendingCategory['dateModified'] as String),
      );

      // Check if category already exists
      final existingDoc = await categoriesRef.doc(category.id).get();

      if (existingDoc.exists) {
        // Update existing category
        await updateCategory(category);
      } else {
        // Add new category
        await addCategory(category);
      }

      debugPrint('✅ Successfully synced category: ${category.name}');

    } catch (e) {
      debugPrint('❌ Error syncing pending category: $e');
      rethrow;
    }
  }
  // Updated collection references with tenant isolation
  CollectionReference get productsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('products');

  CollectionReference get ordersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('orders');

  CollectionReference get categoriesRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('categories');

  CollectionReference get pendingOrdersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('pending_orders');

  CollectionReference get customersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('customers');

  CollectionReference get returnsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('returns');

  CollectionReference get purchaseRecordRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('purchaseRecords');

  CollectionReference get businessSettingsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('business_settings');

  CollectionReference get sequenceCountersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('sequence_counters');

  static final FirestoreServices _instance = FirestoreServices._internal();
  factory FirestoreServices() => _instance;
  FirestoreServices._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  ///working
  Future<void> deleteCustomer(String customerId) async {
    try {
      await customersRef.doc(customerId).delete();
      debugPrint('Customer deleted successfully: $customerId');
    } catch (e) {
      debugPrint('Failed to delete customer: $e');
      throw Exception('Failed to delete customer: $e');
    }
  }
  ///working
  Future<BusinessSettings> getBusinessSettings() async {
    try {
      final doc = await businessSettingsRef.doc('business_settings').get();
      if (doc.exists) {
        return BusinessSettings.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      } else {
        // Create default settings if not exists
        final defaultSettings = BusinessSettings.createDefault();
        await businessSettingsRef.doc('business_settings').set(defaultSettings.toFirestore());
        return defaultSettings;
      }
    } catch (e) {
      debugPrint('Error getting business settings: $e');
      return BusinessSettings.createDefault();
    }
  }

  // Atomic Sequence Generation with Transactions
  ///working
  Future<int> _getNextSequence(String type, {int? year}) async {
    try {
      // Use transaction for atomic increment
      return await _firestore.runTransaction((transaction) async {
        final String counterId = year != null ? '${type}_$year' : type;
        final counterRef = sequenceCountersRef.doc(counterId);

        final counterDoc = await transaction.get(counterRef);
        int nextSequence;

        if (counterDoc.exists) {
          final data = counterDoc.data() as Map<String, dynamic>;
          nextSequence = (data['lastSequence'] as int) + 1;

          transaction.update(counterRef, {
            'lastSequence': nextSequence,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          nextSequence = 1;
          final newCounter = SequenceCounter(
            id: counterId,
            type: type,
            lastSequence: nextSequence,
            year: year ?? 0,
            lastUpdated: DateTime.now(),
          );
          transaction.set(counterRef, newCounter.toFirestore());
        }

        return nextSequence;
      });
    } catch (e) {
      debugPrint('Error generating sequence: $e');
      throw Exception('Failed to generate sequence: $e');
    }
  }

  // Order Number Generation
  ///working
  Future<String> generateOrderNumber() async {
    try {
      final settings = await getBusinessSettings();
      final currentYear = DateTime.now().year;
      final sequence = await _getNextSequence('order', year: currentYear);

      return '${settings.businessCode}-ORD-$currentYear-${sequence.toString().padLeft(4, '0')}';
    } catch (e) {
      debugPrint('Error generating order number: $e');
      // Fallback with timestamp (should never happen in normal operation)
      return 'POS-ORD-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    }
  }

  ///working
  Future<String> addCategory(Category category) async {
    try {
      final categoryData = category.toFirestore();
      final docRef = categoriesRef.doc(category.id);
      await docRef.set(categoryData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add category: $e');
    }
  }

  ///working
  Future<void> updateCategory(Category category) async {
    try {
      final categoryData = category.toFirestore();
      await categoriesRef.doc(category.id).update(categoryData);
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  ///working
  Future<void> deleteCategory(String categoryId) async {
    try {
      await categoriesRef.doc(categoryId).delete();
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // Enhanced return operations with offline support
  ///working
  Future<ReturnRequest> createReturn(ReturnRequest returnRequest) async {
    try {
      final returnRef = returnsRef.doc(returnRequest.id);
      final returnData = returnRequest.toFirestore();

      await returnRef.set(returnData);

      // Restock returned items - only if product exists in database
      for (final item in returnRequest.items) {
        try {
          final productDoc = await productsRef.doc(item.productId).get();
          if (productDoc.exists) {
            await productsRef.doc(item.productId).update({
              'stockQuantity': FieldValue.increment(item.quantity),
              'dateModified': FieldValue.serverTimestamp(),
            });
          } else {
            debugPrint(
              'Product ${item.productId} not found in database, skipping stock update',
            );
          }
        } catch (e) {
          debugPrint('Error updating stock for product ${item.productId}: $e');
          // Continue with other products even if one fails
        }
      }

      // Update order status only if it's a real order (not 'no_order')
      if (returnRequest.orderId != 'no_order') {
        try {
          final orderDoc = await ordersRef.doc(returnRequest.orderId).get();
          if (orderDoc.exists) {
            await ordersRef.doc(returnRequest.orderId).update({
              'hasReturns': true,
              'dateModified': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint('Error updating order status: $e');
        }
      }

      return returnRequest;
    } catch (e) {
      debugPrint('Failed to create return: $e');
      throw Exception('Failed to create return: $e');
    }
  }

  ///working
  Future<List<ReturnRequest>> getAllReturns({int limit = 50}) async {
    try {
      final snapshot = await returnsRef
          .orderBy('dateCreated', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return ReturnRequest.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting all returns: $e');
      return [];
    }
  }

  ///working
  Future<bool> syncPendingReturn(Map<String, dynamic> pendingReturn) async {
    try {
      final returnRequest = ReturnRequest.fromLocalMap(pendingReturn);

      // Create the return in Firestore
      await createReturn(returnRequest);

      return true;
    } catch (e) {
      debugPrint('Failed to sync pending return: $e');
      return false;
    }
  }

  ///working
  Future<List<AppOrder>> searchOrders(String query) async {
    if (query.isEmpty) return [];

    try {
      final snapshot = await ordersRef
          .where('number', isGreaterThanOrEqualTo: query)
          .where('number', isLessThanOrEqualTo: '$query\uf8ff')
          .orderBy('number')
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppOrder.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error searching orders: $e');
      return [];
    }
  }

  ///working
  Future<AppOrder?> getOrderById(String orderId) async {
    try {
      final doc = await ordersRef.doc(orderId).get();
      if (doc.exists) {
        return AppOrder.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  ///working
  Future<List<AppOrder>> getRecentOrders({int limit = 50}) async {
    try {
      final snapshot = await ordersRef
          .orderBy('dateCreated', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppOrder.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting recent orders: $e');
      return [];
    }
  }

  ///working
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

  ///working
  Future<Customer?> getCustomerById(String id) async {
    final doc = await customersRef.doc(id).get();
    if (doc.exists) {
      return Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  ///working
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

  ///working
  Future<void> updateCustomer(Customer customer) async {
    try {
      final customerData = customer.toFirestore();
      await customersRef.doc(customer.id).update(customerData);
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }

  ///working
  Future<void> updateCustomerStats(String customerId, double orderTotal) async {
    try {
      await customersRef.doc(customerId).update({
        'orderCount': FieldValue.increment(1),
        'totalSpent': FieldValue.increment(orderTotal),
        'dateModified': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update customer stats: $e');
    }
  }

  ///working
  Future<AppOrder> createOrderWithEnhancedData(
      List<CartItem> cartItems,
      CustomerSelection customerSelection,
      Map<String, dynamic> enhancedData,
      ) async {
    try {
      final orderRef = ordersRef.doc();
      final orderNumber = await generateOrderNumber(); // Use new numbering system

      // Calculate totals
      double subtotal = cartItems.fold(0.0, (sum, item) => sum + item.baseSubtotal);
      double totalAmount = cartItems.fold(0.0, (sum, item) => sum + item.subtotal);

      // Use enhanced data if provided for more accurate totals
      final cartData = enhancedData['cartData'] as Map<String, dynamic>?;
      if (cartData != null) {
        subtotal = cartData['subtotal'] ?? subtotal;
        totalAmount = cartData['totalAmount'] ?? totalAmount;
      }

      // Prepare customer data for order level storage
      Map<String, dynamic>? customerOrderData;
      String? customerId;
      String? customerName;

      if (customerSelection.hasCustomer) {
        final customer = customerSelection.customer!;
        customerId = customer.id;
        customerName = customer.fullName;

        customerOrderData = {
          'id': customer.id,
          'firstName': customer.firstName,
          'lastName': customer.lastName,
          'email': customer.email,
          'phone': customer.phone,
          'company': customer.company,
          'address1': customer.address1,
          'address2': customer.address2,
          'city': customer.city,
          'state': customer.state,
          'postcode': customer.postcode,
          'country': customer.country,
        };
      } else {
        customerName = 'Walk-in Customer';
      }

      final orderData = {
        'id': orderRef.id,
        'number': orderNumber, // Use generated order number
        'status': 'completed',
        'dateCreated': FieldValue.serverTimestamp(),
        'total': totalAmount,
        'subtotal': subtotal,
        'lineItems': cartItems.map((item) {
          final itemData = {
            'productId': item.product.id,
            'productName': item.product.name,
            'quantity': item.quantity,
            'price': item.product.price,
            'subtotal': item.subtotal,
            'baseSubtotal': item.baseSubtotal,
            'hasManualDiscount': item.hasManualDiscount,
          };

          // Add discount information if available
          if (item.hasManualDiscount) {
            itemData['manualDiscount'] = item.manualDiscount ?? 0.0;
            itemData['manualDiscountPercent'] = item.manualDiscountPercent ?? 0.0;
            itemData['discountAmount'] = item.discountAmount;
          }

          return itemData;
        }).toList(),
        'paymentMethod': enhancedData['paymentMethod'] ?? 'cash',
        'paymentStatus': 'paid',

        // Store customer data at ORDER LEVEL (not in line items)
        'customerId': customerId,
        'customerName': customerName,
        'customerEmail': customerSelection.hasCustomer ? customerSelection.customer!.email : null,
        'customerPhone': customerSelection.hasCustomer ? customerSelection.customer!.phone : null,
        'customerAddress': customerSelection.hasCustomer ? _formatCustomerAddress(customerSelection.customer!) : null,
        'customer': customerOrderData,

        // Enhanced data for detailed reporting
        'enhancedData': enhancedData,
      };

      // Add pricing breakdown if available in enhanced data
      if (cartData != null) {
        orderData['pricingBreakdown'] = {
          'itemDiscounts': cartData['item_discounts'] ?? 0.0,
          'cartDiscount': cartData['cart_discount'] ?? 0.0,
          'cartDiscountPercent': cartData['cart_discount_percent'] ?? 0.0,
          'cartDiscountAmount': cartData['cart_discount_amount'] ?? 0.0,
          'additionalDiscount': enhancedData['additionalDiscount'] ?? 0.0,
          'shippingAmount': enhancedData['shippingAmount'] ?? 0.0,
          'tipAmount': enhancedData['tipAmount'] ?? 0.0,
          'taxRate': cartData['tax_rate'] ?? 0.0,
          'taxAmount': cartData['tax_amount'] ?? 0.0,
          'totalDiscount': cartData['total_discount'] ?? 0.0,
          'finalTotal': cartData['totalAmount'] ?? totalAmount,
        };
      }

      await orderRef.set(orderData);

      // Update stock quantities
      for (final item in cartItems) {
        await productsRef.doc(item.product.id).update({
          'stockQuantity': FieldValue.increment(-item.quantity),
          'dateModified': FieldValue.serverTimestamp(),
        });
      }

      // Update customer stats if customer is associated
      if (customerSelection.hasCustomer) {
        await updateCustomerStats(
          customerSelection.customer!.id,
          totalAmount,
        );
      }

      final createdOrder = AppOrder.fromFirestore(orderData, orderRef.id);

      // Debug: debugPrint customer data to verify it's stored correctly
      createdOrder.printCustomerData();

      return createdOrder;
    } catch (e) {
      debugPrint('Error creating order with enhanced data: $e');
      throw Exception('Failed to create order: $e');
    }
  }

  ///working
  String? _formatCustomerAddress(Customer customer) {
    final addressParts = [
      customer.address1,
      customer.city,
      customer.state,
      customer.postcode,
      customer.country,
    ].where((part) => part != null && part.isNotEmpty).toList();

    return addressParts.isNotEmpty ? addressParts.join(', ') : null;
  }

  ///working
  Future<List<Product>> getProducts({
    int limit = 50,
    String? lastDocumentId,
    String searchQuery = '',
    bool inStockOnly = false,
    double minPrice = 0,
    double maxPrice = double.infinity,
  }) async {
    Query query = productsRef
        .where('status', isEqualTo: 'publish')
        .orderBy('name')
        .limit(limit);

    if (lastDocumentId != null) {
      final lastDoc = await productsRef.doc(lastDocumentId).get();
      query = query.startAfterDocument(lastDoc);
    }

    if (searchQuery.isNotEmpty) {
      query = query.where(
        'searchKeywords',
        arrayContains: searchQuery.toLowerCase(),
      );
    }

    if (inStockOnly) {
      query = query.where('inStock', isEqualTo: true);
    }

    if (minPrice > 0) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }

    if (maxPrice < double.infinity) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
          Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
    )
        .toList();
  }

  ///working
  Future<Product?> getProductById(String id) async {
    final doc = await productsRef.doc(id).get();
    if (doc.exists) {
      return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  ///working
  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    final snapshot = await productsRef
        .where('searchKeywords', arrayContains: query.toLowerCase())
        .where('status', isEqualTo: 'publish')
        .limit(20)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
          Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
    )
        .toList();
  }

  ///working
  Future<List<Product>> searchProductsBySKU(String sku) async {
    final snapshot = await productsRef
        .where('sku', isEqualTo: sku)
        .where('status', isEqualTo: 'publish')
        .limit(1)
        .get();

    return snapshot.docs
        .map(
          (doc) =>
          Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id),
    )
        .toList();
  }

  // Product management
  ///working
  Future<String> addProduct(Product product, List<XFile>? images) async {
    try {
      List<String> imageUrls = [];
      if (images != null && images.isNotEmpty) {
        for (final image in images) {
          final url = await _uploadImage(image, product.id);
          if (url != null) {
            imageUrls.add(url);
          }
        }
      }

      final productData = product.toFirestore();

      // Ensure image URLs are properly set
      productData['imageUrls'] = imageUrls;
      if (imageUrls.isNotEmpty) {
        productData['imageUrl'] = imageUrls.first;
      }

      // Add timestamp if not present
      if (productData['dateCreated'] == null) {
        productData['dateCreated'] = FieldValue.serverTimestamp();
      }
      productData['dateModified'] = FieldValue.serverTimestamp();

      await productsRef.doc(product.id).set(productData);

      // Also save to local database immediately
      final LocalDatabase localDb = LocalDatabase();
      await localDb.saveProducts([product.copyWith(
        imageUrls: imageUrls,
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
      )]);

      return product.id;
    } catch (e) {
      debugPrint('Error adding product: $e');
      throw Exception('Failed to add product: $e');
    }
  }

  ///working
  Future<void> updateProduct(Product product, List<XFile>? newImages) async {
    try {
      List<String> imageUrls = List.from(product.imageUrls);
      if (newImages != null && newImages.isNotEmpty) {
        for (final image in newImages) {
          final url = await _uploadImage(image, product.id);
          if (url != null) {
            imageUrls.add(url);
          }
        }
      }

      final productData = product.toFirestore();
      productData['imageUrls'] = imageUrls;
      if (imageUrls.isNotEmpty && product.imageUrl == null) {
        productData['imageUrl'] = imageUrls.first;
      }
      productData['searchKeywords'] = _generateSearchKeywords(product);

      await productsRef.doc(product.id).update(productData);
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  ///working
  Future<void> deleteProduct(String productId) async {
    try {
      final snapshot = await productsRef.doc(productId).get();

      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>?;

      if (data != null) {
        await productsRef
            .doc('trash')
            .collection('deleted_products')
            .doc(productId)
            .set({
          ...data,
          'deletedAt': FieldValue.serverTimestamp(),
          'originalId': productId,
        });
      }

      await productsRef.doc(productId).delete();

    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }



  ///working
  Future<void> restockProduct(
      String productId,
      int quantity, {
        String? barcode,
      }) async {
    try {
      await productsRef.doc(productId).update({
        'stockQuantity': FieldValue.increment(quantity),
        'inStock': true,
        'stockStatus': 'instock',
        'lastRestocked': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to restock product: $e');
    }
  }

  ///working
  Future<String?> _uploadImage(XFile image, String productId) async {
    try {
      final File file = File(image.path);
      final String fileName =
          '${productId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('products/$fileName');

      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Image upload failed: $e');
      return null;
    }
  }

  ///working
  List<String> _generateSearchKeywords(Product product) {
    final keywords = <String>[];

    keywords.addAll(product.name.toLowerCase().split(' '));

    if (product.sku.isNotEmpty) {
      keywords.add(product.sku.toLowerCase());
    }

    for (final category in product.categories) {
      keywords.addAll(category.name.toLowerCase().split(' '));
    }

    return keywords.where((k) => k.length > 1).toSet().toList();
  }

  // Order operations - UPDATED WITH NEW NUMBERING
  ///working
  Future<List<Category>> getCategories() async {
    final snapshot = await categoriesRef.orderBy('name').get();
    return snapshot.docs
        .map(
          (doc) => Category.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      ),
    )
        .toList();
  }

  // Test connection
  ///working
  Future<bool> testConnection() async {
    try {
      await productsRef.limit(1).get();
      return true;
    } catch (e) {
      return false;
    }
  }


  ///working
  Future<AppOrder> createOrder(List<CartItem> cartItems) async {
    try {
      final orderRef = ordersRef.doc();
      final orderNumber = await generateOrderNumber(); // Use new numbering system

      final orderData = {
        'id': orderRef.id,
        'number': orderNumber, // Use generated order number
        'status': 'completed',
        'dateCreated': FieldValue.serverTimestamp(),
        'total': cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
        'lineItems': cartItems
            .map(
              (item) => {
            'productId': item.product.id,
            'productName': item.product.name,
            'quantity': item.quantity,
            'price': item.product.price,
            'subtotal': item.subtotal,
          },
        )
            .toList(),
        'paymentMethod': 'cash',
        'paymentStatus': 'paid',
      };

      await orderRef.set(orderData);

      for (final item in cartItems) {
        await productsRef.doc(item.product.id).update({
          'stockQuantity': FieldValue.increment(-item.quantity),
        });
      }

      return AppOrder.fromFirestore(orderData, orderRef.id);
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

}
class ModernDashboardScreen extends StatefulWidget {
  const ModernDashboardScreen({super.key});

  @override
  _ModernDashboardScreenState createState() => _ModernDashboardScreenState();
}
class _ModernDashboardScreenState extends State<ModernDashboardScreen>
    with SingleTickerProviderStateMixin {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final FirestoreServices _firestore = FirestoreServices();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final LocalDatabase _localDb = LocalDatabase();

  // Real data variables
  DashboardStats _stats = DashboardStats.empty();
  List<RevenueDataPoint> _revenueData = [];

  bool _isLoading = true;
  bool _isOnline = true;
  bool _isRefreshing = false;
  bool _isOfflineMode = false;
  final String _selectedPeriod = 'today';

  // Get auth provider from context
  MyAuthProvider get _authProvider {
    return Provider.of<MyAuthProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadDashboardData();
    _setupConnectivityListener();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

// In ModernDashboardScreen - REPLACE the _loadDashboardData method
  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isRefreshing = true;
    });

    try {
      final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final tenantId = currentUser.tenantId;
      if (tenantId.isEmpty || tenantId == 'super_admin') {
        throw Exception('Invalid tenant ID');
      }

      debugPrint('Loading dashboard for tenant: $tenantId');

      // Check connectivity FIRST
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasNetwork = connectivityResult != ConnectivityResult.none;

      setState(() {
        _isOnline = hasNetwork;
        _isOfflineMode = !hasNetwork;
      });

      // If offline, load cached data immediately
      if (!hasNetwork) {
        debugPrint('No network - loading offline data immediately');
        await _loadOfflineData(tenantId);
        return;
      }

      // If online, try to load fresh data with timeout
      try {
        await _loadOnlineData(tenantId).timeout(Duration(seconds: 10));
      } catch (onlineError) {
        debugPrint('Online load failed or timed out: $onlineError');
        // Fallback to offline data
        await _loadOfflineData(tenantId);
        _isOfflineMode = true;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Using offline data - connection issue'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

    } catch (e) {
      debugPrint('Error in dashboard load: $e');

      // Final fallback - try basic offline data
      try {
        final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
        final tenantId = authProvider.currentUser?.tenantId;
        if (tenantId != null) {
          await _loadBasicOfflineData();
        }
      } catch (fallbackError) {
        debugPrint('All data loading failed: $fallbackError');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

// ADD this method for basic offline data fallback
  Future<void> _loadBasicOfflineData() async {
    debugPrint('Loading basic offline data as final fallback');

    // Create minimal dashboard data
    final basicStats = DashboardStats.empty();
    final basicRevenueData = List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      return RevenueDataPoint(date: date, revenue: 0.0, orders: 0);
    });

    if (mounted) {
      setState(() {
        _stats = basicStats;
        _revenueData = basicRevenueData;
        _isLoading = false;
        _isRefreshing = false;
        _isOfflineMode = true;
      });
    }
  }




  void _loadCachedData(OfflineDashboardData cachedData) {
    if (mounted) {
      setState(() {
        _stats = cachedData.stats;
        _revenueData = cachedData.revenueData;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }
// In ModernDashboardScreen - REPLACE the _loadOnlineData method
  Future<void> _loadOnlineData(String tenantId) async {
    debugPrint('🔄 Loading optimized online data...');

    // Check for recent cached data first (even when online)
    final cachedData = await _localDb.getDashboardData(tenantId);
    if (cachedData != null && !_isRefreshing) {
      debugPrint('📁 Loading from cache first for faster display');
      _loadCachedData(cachedData);
    }

    _firestore.setTenantId(tenantId);
    _posService.setTenantContext(tenantId);

    // Load data in parallel with error handling for each
    final futures = [
      _fetchDashboardStats(tenantId),
      _fetchRecentOrders(tenantId),
      _fetchLowStockProducts(tenantId),
      _fetchRevenueData(tenantId),
      _fetchRecentCustomers(tenantId),
    ];

    final results = await Future.wait(futures.map((future) =>
        future.catchError((e) {
          debugPrint('Partial data load error: $e');
          return _getFallbackForType(future);
        })
    ), eagerError: false);

    if (mounted) {
      setState(() {
        _stats = results[0] as DashboardStats;
        _revenueData = results[3] as List<RevenueDataPoint>;
        _isLoading = false;
        _isRefreshing = false;
        _isOfflineMode = false;
      });
    }

    // Cache the successful data
    final offlineData = OfflineDashboardData(
      stats: _stats,
      revenueData: _revenueData,
      lastUpdated: DateTime.now(),
      tenantId: tenantId,
    );

    await _localDb.saveDashboardData(offlineData);
    debugPrint('✅ Dashboard data loaded and cached');
  }

// ADD this helper method for fallback data
  dynamic _getFallbackForType(Future future) {
    if (future == _fetchDashboardStats) return DashboardStats.empty();
    if (future == _fetchRecentOrders) return [];
    if (future == _fetchLowStockProducts) return [];
    if (future == _fetchRevenueData) return [];
    if (future == _fetchRecentCustomers) return [];
    return null;
  }
  Future<void> _loadOfflineData(String tenantId) async {
    debugPrint('Loading dashboard data from offline sources');

    // Generate data from local database
    final results = await Future.wait([
      _localDb.generateOfflineStats(),
      _localDb.getPendingOrders().then((orders) => orders.take(5).map((order) {
        final orderData = order['order_data'] as Map<String, dynamic>;
        return AppOrder.fromFirestore(orderData, order['id'].toString());
      }).toList()),
      _localDb.generateRevenueData(),
    ]);

    if (mounted) {
      setState(() {
        _stats = results[0] as DashboardStats;
        _revenueData = results[3] as List<RevenueDataPoint>;
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }
  void _setupConnectivityListener() {
    _posService.onlineStatusStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);

        // If we come back online and were in offline mode, refresh data
        if (isOnline && _isOfflineMode) {
          _loadDashboardData();
        }
      }
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    await _loadDashboardData();
  }

  // Update your _buildStatusIndicator to show offline mode
  Widget _buildStatusIndicator() {
    return StreamBuilder<bool>(
      stream: _posService.onlineStatusStream,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        // Only show as offline if we're actually in offline mode
        final showAsOffline = _isOfflineMode;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: showAsOffline ? Colors.orange[400] : Colors.green[400],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: showAsOffline
                    ? Colors.orange[400]!.withValues(alpha: 0.3)
                    : Colors.green[400]!.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6),
              Text(
                showAsOffline ? 'Offline Mode' : 'Live Data',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showAsOffline) ...[
                SizedBox(width: 4),
                Icon(Icons.wifi_off, size: 12, color: Colors.white),
              ],
            ],
          ),
        );
      },
    );
  }
  // Update your _buildLoadingState to show offline status
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                _isOfflineMode ? Colors.orange[700]! : Colors.blue[700]!,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            _isOfflineMode
                ? 'Loading Offline Dashboard Data...'
                : 'Loading Dashboard Data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _isOfflineMode
                ? 'Using locally stored data'
                : 'Fetching from your database',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          if (_isOfflineMode) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange[700]),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Future<DashboardStats> _fetchDashboardStats(String tenantId) async {
    _firestore.setTenantId(tenantId);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final yesterdayStart = todayStart.subtract(Duration(days: 1));
    final yesterdayEnd = todayEnd.subtract(Duration(days: 1));

    try {
      // Fetch all required data
      final futures = await Future.wait([
        _firestore.ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
            .get(),
        _firestore.ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(yesterdayEnd))
            .get(),
        _firestore.ordersRef.get(),
        _firestore.productsRef.where('status', isEqualTo: 'publish').get(),
        _firestore.customersRef.get(),
        _firestore.returnsRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .get(),
        _firestore.returnsRef.get(),
      ]);

      final todayOrdersSnapshot = futures[0];
      final yesterdayOrdersSnapshot = futures[1];
      final allOrdersSnapshot = futures[2];
      final productsSnapshot = futures[3];
      final customersSnapshot = futures[4];
      final todayReturnsSnapshot = futures[5];
      final allReturnsSnapshot = futures[6];

      // Calculate today's revenue with null safety
      double todayRevenue = 0.0;
      for (final order in todayOrdersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ?? 0.0;
        todayRevenue += total;
      }

      // Calculate yesterday's revenue
      double yesterdayRevenue = 0.0;
      for (final order in yesterdayOrdersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ?? 0.0;
        yesterdayRevenue += total;
      }

      // Calculate total revenue
      double totalRevenue = 0.0;
      for (final order in allOrdersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final total = _safeGetDouble(data, 'total') ??
            _safeGetDouble(data, 'totalAmount') ?? 0.0;
        totalRevenue += total;
      }

      // Calculate low stock products with null safety
      int lowStockCount = 0;
      for (final product in productsSnapshot.docs) {
        final data = product.data() as Map<String, dynamic>;
        final stockQuantity = _safeGetInt(data, 'stockQuantity') ??
            _safeGetInt(data, 'stock') ?? 0;
        if (stockQuantity <= 10) {
          lowStockCount++;
        }
      }

      // Today's unique customers with null safety
      final todayCustomerIds = <String>{};
      for (final order in todayOrdersSnapshot.docs) {
        final data = order.data() as Map<String, dynamic>;
        final customerId = data['customerId']?.toString();
        if (customerId != null && customerId.isNotEmpty && customerId != 'null') {
          todayCustomerIds.add(customerId);
        }
      }

      // Calculate derived metrics
      final averageOrderValue = allOrdersSnapshot.docs.isNotEmpty
          ? totalRevenue / allOrdersSnapshot.docs.length
          : 0.0;
      final conversionRate = customersSnapshot.docs.isNotEmpty
          ? (allOrdersSnapshot.docs.length / customersSnapshot.docs.length * 100).clamp(0.0, 100.0)
          : 0.0;

      final revenueGrowth = _calculateGrowthPercentage(todayRevenue, yesterdayRevenue);
      final salesGrowth = _calculateGrowthPercentage(
          todayOrdersSnapshot.docs.length.toDouble(),
          yesterdayOrdersSnapshot.docs.length.toDouble()
      );

      return DashboardStats(
        totalRevenue: totalRevenue,
        todayRevenue: todayRevenue,
        totalSales: allOrdersSnapshot.docs.length,
        todaySales: todayOrdersSnapshot.docs.length,
        totalProducts: productsSnapshot.docs.length,
        lowStockProducts: lowStockCount,
        totalCustomers: customersSnapshot.docs.length,
        todayCustomers: todayCustomerIds.length,
        averageOrderValue: averageOrderValue,
        conversionRate: conversionRate,
        revenueGrowth: revenueGrowth,
        salesGrowth: salesGrowth,
        todayReturns: todayReturnsSnapshot.docs.length,
        totalReturns: allReturnsSnapshot.docs.length,
      );
    } catch (e) {
      debugPrint('Error in _fetchDashboardStats: $e');
      return DashboardStats.empty();
    }
  }

// Helper methods for safe data extraction
  double? _safeGetDouble(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _safeGetInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
  double _calculateGrowthPercentage(double today, double yesterday) {
    if (yesterday == 0) return today > 0 ? 100.0 : 0.0;
    return ((today - yesterday) / yesterday * 100);
  }

  Future<List<AppOrder>> _fetchRecentOrders(String tenantId) async {
    try {
      _firestore.setTenantId(tenantId);

      final ordersSnapshot = await _firestore.ordersRef
          .orderBy('dateCreated', descending: true)
          .limit(5)
          .get();

      return ordersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppOrder.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching recent orders: $e');
      return [];
    }
  }

  Future<List<Product>> _fetchLowStockProducts(String tenantId) async {
    try {
      _firestore.setTenantId(tenantId);

      final productsSnapshot = await _firestore.productsRef
          .where('status', isEqualTo: 'publish')
          .where('stockQuantity', isLessThanOrEqualTo: 10)
          .orderBy('stockQuantity')
          .limit(3)
          .get();

      return productsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching low stock products: $e');
      return [];
    }
  }

  Future<List<RevenueDataPoint>> _fetchRevenueData(String tenantId) async {
    _firestore.setTenantId(tenantId);

    final now = DateTime.now();
    final List<RevenueDataPoint> revenueData = [];

    try {
      for (int i = 6; i >= 0; i--) {
        final date = DateTime(now.year, now.month, now.day - i);
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

        final ordersSnapshot = await _firestore.ordersRef
            .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('dateCreated', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();

        double dayRevenue = 0.0;
        int dayOrders = 0;

        for (final order in ordersSnapshot.docs) {
          final data = order.data() as Map<String, dynamic>;
          final total = (data['total'] as num?)?.toDouble() ??
              (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          dayRevenue += total;
          dayOrders++;
        }

        revenueData.add(
          RevenueDataPoint(date: date, revenue: dayRevenue, orders: dayOrders),
        );
      }

      return revenueData;
    } catch (e) {
      debugPrint('Error generating revenue data: $e');
      return [];
    }
  }


  Future<List<Customer>> _fetchRecentCustomers(String tenantId) async {
    try {
      _posService.setTenantContext(tenantId);
      final customers = await _posService.getAllCustomers();
      return customers.take(5).toList();
    } catch (e) {
      debugPrint('Error fetching recent customers: $e');
      return [];
    }
  }


  // void _showPeriodSelector() {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (context) => Container(
  //       padding: EdgeInsets.all(20),
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text(
  //             'Select Time Period',
  //             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  //           ),
  //           SizedBox(height: 16),
  //           _buildPeriodOption('Today', 'today'),
  //           _buildPeriodOption('This Week', 'week'),
  //           _buildPeriodOption('This Month', 'month'),
  //           _buildPeriodOption('This Year', 'year'),
  //           SizedBox(height: 16),
  //           OutlinedButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: Text('Cancel'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildPeriodOption(String label, String value) {
  //   return ListTile(
  //     leading: Icon(Icons.calendar_today, color: Colors.blue),
  //     title: Text(label),
  //     trailing: _selectedPeriod == value
  //         ? Icon(Icons.check, color: Colors.blue)
  //         : null,
  //     onTap: () {
  //       setState(() => _selectedPeriod = value);
  //       Navigator.pop(context);
  //       _loadDashboardData();
  //     },
  //   );
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading ? _buildLoadingState() : _buildDashboard(),
    );
  }



  Widget _buildDashboard() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  _buildHeader(),
                  _buildStatsGrid(),
                  _buildMainContent(),
                  SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }





  SliverToBoxAdapter _buildHeader() {
    final user = _authProvider.currentUser;
    final tenantId = user?.tenantId ?? 'No Tenant ID';
    final auth = FirebaseAuth.instance;
    EnhancedPOSService posService = EnhancedPOSService();

    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ThemeUtils.appBar(context),
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(ThemeUtils.radius(context)),
            bottomRight: Radius.circular(ThemeUtils.radius(context)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [


                      Text(
                        'Good ${_getGreeting()},',
                        style: ThemeUtils.bodyLarge(context).copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.currentUser?.displayName ??
                            'Your Business (Tenant: ${tenantId.substring(0, min(8, tenantId.length))}...)',
                        style: ThemeUtils.headlineLarge(context).copyWith(
                          color: ThemeUtils.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time Business Overview',
                        style: ThemeUtils.bodyMedium(context).copyWith(color: Colors.white),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 4),
                        Text(
                          'User: ${user?.uid.substring(0, 8)}... | Tenant: $tenantId',
                          style: ThemeUtils.bodySmall(context).copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    _buildStatusIndicator(),
                    const SizedBox(height: 8),
                    if (_isRefreshing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          // match app bar text contrast color
                          color: Colors.white, // or ThemeUtils.textOnPrimary(context)
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: ThemeUtils.textSecondary(context),
                        ),
                        onPressed: _refreshData,
                        tooltip: 'Refresh Data',
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildQuickStatsBar(),
          ],
        ),
      ),
    );
  }



  Widget _buildQuickStatsBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickStatItem(
            value: _stats.todaySales.toString(),
            label: 'Today Sales',
            icon: Icons.shopping_cart,
          ),
          _QuickStatItem(
            value: '${Constants.CURRENCY_NAME}${_stats.todayRevenue.toStringAsFixed(0)}',
            label: "Today's Revenue",
            icon: Icons.attach_money,
          ),
          _QuickStatItem(
            value: _stats.todayCustomers.toString(),
            label: 'Today Customers',
            icon: Icons.people,
          ),
          _QuickStatItem(
            value: _stats.todayReturns.toString(),
            label: 'Today Returns',
            icon: Icons.assignment_return,
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildStatsGrid() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _StatCard(
              title: 'Total Revenue',
              value: '${Constants.CURRENCY_NAME}${_stats.totalRevenue.toStringAsFixed(0)}',
              subtitle: '${Constants.CURRENCY_NAME}${_stats.todayRevenue.toStringAsFixed(0)} today',
              icon: Icons.attach_money,
              color: Colors.green,
              trend: _stats.revenueGrowth,
            ),
            _StatCard(
              title: 'Total Sales',
              value: _stats.totalSales.toString(),
              subtitle: '${_stats.todaySales} today',
              icon: Icons.shopping_cart,
              color: Colors.blue,
              trend: _stats.salesGrowth,
            ),
            _StatCard(
              title: 'Average Order',
              value: '${Constants.CURRENCY_NAME}${_stats.averageOrderValue.toStringAsFixed(0)}',
              subtitle: 'Per transaction',
              icon: Icons.trending_up,
              color: Colors.purple,
              trend: 0.0,
            ),
            _StatCard(
              title: 'Conversion Rate',
              value: '${_stats.conversionRate.toStringAsFixed(1)}%',
              subtitle: 'Customer conversion',
              icon: Icons.people,
              color: Colors.orange,
              trend: 0.0,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildMainContent() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _buildRevenueChart(),
            SizedBox(height: 20),

            // SizedBox(width: 16),
            SizedBox(height: 20),


          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    final weeklyGrowth = _calculateWeeklyGrowth();

    return LayoutBuilder(
      builder: (context, constraints) {
        double containerWidth = constraints.maxWidth;
        double containerPadding = containerWidth * 0.05;
        double titleFontSize = containerWidth * 0.045;
        double growthFontSize = containerWidth * 0.03;

        return SizedBox(
          height: 300, // FIXED height for scrollable parents
          child: Container(
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Revenue Overview (Last 7 Days)',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: containerWidth * 0.02,
                        vertical: containerWidth * 0.01,
                      ),
                      decoration: BoxDecoration(
                        color: weeklyGrowth >= 0
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${weeklyGrowth >= 0 ? '+' : ''}${weeklyGrowth.toStringAsFixed(1)}% this week',
                        style: TextStyle(
                          color: weeklyGrowth >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                          fontSize: growthFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: containerPadding * 0.8),
                SizedBox(
                  height: 180, // fixed chart height
                  child: SfCartesianChart(
                    margin: EdgeInsets.zero,
                    plotAreaBorderWidth: 0,
                    primaryXAxis: CategoryAxis(
                      majorGridLines: MajorGridLines(width: 0),
                      labelStyle: TextStyle(fontSize: titleFontSize * 0.6),
                    ),
                    primaryYAxis: NumericAxis(
                      numberFormat: NumberFormat.compactCurrency(
                        symbol: Constants.CURRENCY_NAME,
                      ),
                      majorGridLines: MajorGridLines(
                        width: 1,
                        color: Colors.grey[100],
                      ),
                      labelStyle: TextStyle(fontSize: titleFontSize * 0.6),
                    ),
                    series: <CartesianSeries>[
                      ColumnSeries<RevenueDataPoint, String>(
                        dataSource: _revenueData,
                        xValueMapper: (RevenueDataPoint data, _) =>
                            DateFormat('E').format(data.date),
                        yValueMapper: (RevenueDataPoint data, _) => data.revenue,
                        color: Colors.blueAccent.shade400,
                        width: 0.6,
                        borderRadius: BorderRadius.circular(6),
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

  double _calculateWeeklyGrowth() {
    if (_revenueData.length < 2) return 0.0;

    final firstHalf = _revenueData
        .take(3)
        .fold(0.0, (sum, data) => sum + data.revenue);
    final secondHalf = _revenueData
        .skip(3)
        .fold(0.0, (sum, data) => sum + data.revenue);

    if (firstHalf == 0) return secondHalf > 0 ? 100.0 : 0.0;
    return ((secondHalf - firstHalf) / firstHalf * 100);
  }



  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}


class DashboardStats {
  final double totalRevenue;
  final double todayRevenue;
  final int totalSales;
  final int todaySales;
  final int totalProducts;
  final int lowStockProducts;
  final int totalCustomers;
  final int todayCustomers;
  final double averageOrderValue;
  final double conversionRate;
  final double revenueGrowth;
  final double salesGrowth;
  final int todayReturns;
  final int totalReturns;

  const DashboardStats({
    required this.totalRevenue,
    required this.todayRevenue,
    required this.totalSales,
    required this.todaySales,
    required this.totalProducts,
    required this.lowStockProducts,
    required this.totalCustomers,
    required this.todayCustomers,
    required this.averageOrderValue,
    required this.conversionRate,
    required this.revenueGrowth,
    required this.salesGrowth,
    required this.todayReturns,
    required this.totalReturns,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalRevenue: 0,
      todayRevenue: 0,
      totalSales: 0,
      todaySales: 0,
      totalProducts: 0,
      lowStockProducts: 0,
      totalCustomers: 0,
      todayCustomers: 0,
      averageOrderValue: 0,
      conversionRate: 0,
      revenueGrowth: 0,
      salesGrowth: 0,
      todayReturns: 0,
      totalReturns: 0,
    );
  }
}
class _QuickStatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _QuickStatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double trend;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ───────────────── TOP ROW ─────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: maxWidth * 0.10,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: trend >= 0
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trend >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: maxWidth * 0.05,
                          color: trend >= 0
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints:
                          BoxConstraints(maxWidth: maxWidth * 0.25),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${trend.abs().toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// ───────────────── VALUE (BULLETPROOF) ─────────────────
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxWidth * 0.22,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              /// ───────────────── TITLE ─────────────────
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 4),

              /// ───────────────── SUBTITLE ─────────────────
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle,
                    maxLines: 2,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RevenueDataPoint {
  final DateTime date;
  final double revenue;
  final int orders;

  RevenueDataPoint({
    required this.date,
    required this.revenue,
    required this.orders,
  });
}

