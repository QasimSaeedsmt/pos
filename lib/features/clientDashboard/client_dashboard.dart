import 'dart:async';
import 'dart:io';
import 'dart:math';


import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:synchronized/synchronized.dart';

import '../../analytics_screen.dart';

import '../../constants.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../theme_utils.dart';
import '../cartBase/cart_base.dart';
import '../connectivityBase/local_db_base.dart';
import '../customerBase/customer_base.dart';
import '../customerBase/customer_management_screen.dart';
import '../main_navigation/main_navigation_base.dart';
import '../orderBase/order_base.dart';

import '../product_addition_restock_base/product_addition_restock_base.dart' hide EnhancedPOSService;
import '../product_selling/product_selling_base.dart';
import '../returnBase/return_base.dart';
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

class FirestoreServices {
  String? _currentTenantId;

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
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
  static final FirestoreServices _instance = FirestoreServices._internal();
  // Add to FirestoreService class
  // In FirestoreService class - REPLACE the existing return methods with these:
  // In FirestoreService - UPDATE the createReturn method to handle no-order returns:
  // In FirestoreService class, add these methods:
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

  Future<void> updateCategory(Category category) async {
    try {
      final categoryData = category.toFirestore();
      await categoriesRef.doc(category.id).update(categoryData);
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await categoriesRef.doc(categoryId).delete();
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  // Enhanced return operations with offline support
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
            print(
              'Product ${item.productId} not found in database, skipping stock update',
            );
          }
        } catch (e) {
          print('Error updating stock for product ${item.productId}: $e');
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
          print('Error updating order status: $e');
        }
      }

      return returnRequest;
    } catch (e) {
      print('Failed to create return: $e');
      throw Exception('Failed to create return: $e');
    }
  }

  Future<void> updateReturnStatus(
      String returnId,
      String status, {
        String? processedBy,
      }) async {
    try {
      final updateData = {
        'status': status,
        'dateUpdated': FieldValue.serverTimestamp(),
      };

      if (processedBy != null) {
        updateData['processedBy'] = processedBy;
      }

      await returnsRef.doc(returnId).update(updateData);
    } catch (e) {
      print('Error updating return status: $e');
      throw Exception('Failed to update return status: $e');
    }
  }

  Future<List<ReturnRequest>> getReturnsByOrder(String orderId) async {
    try {
      final snapshot = await returnsRef
          .where('orderId', isEqualTo: orderId)
          .orderBy('dateCreated', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return ReturnRequest.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error getting returns by order: $e');
      return [];
    }
  }

  Stream<List<ReturnRequest>> getReturnsStream() {
    return returnsRef
        .orderBy('dateCreated', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
        return ReturnRequest.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList(),
    );
  }

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
      print('Error getting all returns: $e');
      return [];
    }
  }

  Future<bool> syncPendingReturn(Map<String, dynamic> pendingReturn) async {
    try {
      final returnRequest = ReturnRequest.fromLocalMap(pendingReturn);

      // Create the return in Firestore
      await createReturn(returnRequest);

      return true;
    } catch (e) {
      print('Failed to sync pending return: $e');
      return false;
    }
  }

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
      print('Error searching orders: $e');
      return [];
    }
  }

  Future<AppOrder?> getOrderById(String orderId) async {
    try {
      final doc = await ordersRef.doc(orderId).get();
      if (doc.exists) {
        return AppOrder.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }
  // In FirestoreService class - REPLACE the existing return methods with these:

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
      print('Error getting recent orders: $e');
      return [];
    }
  }

  factory FirestoreServices() => _instance;
  FirestoreServices._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Customer operations
  Stream<List<Customer>> getCustomersStream() {
    return customersRef
        .orderBy('firstName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => Customer.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList(),
    );
  }

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

  Future<void> updateCustomerStats(String customerId, double orderTotal) async {
    try {
      await customersRef.doc(customerId).update({
        'orderCount': FieldValue.increment(1),
        'totalSpent': FieldValue.increment(orderTotal),
        'dateModified': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to update customer stats: $e');
    }
  }

  // Enhanced order creation with customer support
  Future<AppOrder> createOrderWithCustomer(
      List<CartItem> cartItems,
      CustomerSelection customerSelection,
      ) async {
    try {
      final orderRef = ordersRef.doc();
      final orderData = {
        'id': orderRef.id,
        'number': _generateOrderNumber(),
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

      // Add customer information if available
      if (customerSelection.hasCustomer) {
        orderData['customerId'] = customerSelection.customer!.id;
        orderData['customer'] = {
          'firstName': customerSelection.customer!.firstName,
          'lastName': customerSelection.customer!.lastName,
          'email': customerSelection.customer!.email,
          'phone': customerSelection.customer!.phone,
          'company': customerSelection.customer!.company,
        };
      }

      await orderRef.set(orderData);

      // Update stock quantities
      for (final item in cartItems) {
        await productsRef.doc(item.product.id).update({
          'stockQuantity': FieldValue.increment(-item.quantity),
        });
      }

      // Update customer stats if customer is associated
      if (customerSelection.hasCustomer) {
        await updateCustomerStats(
          customerSelection.customer!.id,
          cartItems.fold(0.0, (sum, item) => sum + item.subtotal),
        );
      }

      return AppOrder.fromFirestore(orderData, orderRef.id);
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  // Product operations
  Stream<List<Product>> getProductsStream() {
    return productsRef
        .where('status', isEqualTo: 'publish')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => Product.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList(),
    );
  }

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

  Future<Product?> getProductById(String id) async {
    final doc = await productsRef.doc(id).get();
    if (doc.exists) {
      return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  Future<Product?> getProductBySku(String sku) async {
    final snapshot = await productsRef
        .where('sku', isEqualTo: sku)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

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
      productData['imageUrls'] = imageUrls;
      if (imageUrls.isNotEmpty) {
        productData['imageUrl'] = imageUrls.first;
      }

      productData['searchKeywords'] = _generateSearchKeywords(product);

      await productsRef.doc(product.id).set(productData);
      return product.id;
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

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

  Future<void> deleteProduct(String productId) async {
    try {
      await productsRef.doc(productId).update({'status': 'trash'});
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

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
      print('Image upload failed: $e');
      return null;
    }
  }

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

  // Order operations
  Future<AppOrder> createOrder(List<CartItem> cartItems) async {
    try {
      final orderRef = ordersRef.doc();
      final orderData = {
        'id': orderRef.id,
        'number': _generateOrderNumber(),
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

  String _generateOrderNumber() {
    final now = DateTime.now();
    return 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch}';
  }

  // Category operations
  Stream<List<Category>> getCategoriesStream() {
    return categoriesRef
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => Category.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        ),
      )
          .toList(),
    );
  }

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
  Future<bool> testConnection() async {
    try {
      await productsRef.limit(1).get();
      return true;
    } catch (e) {
      return false;
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
  List<AppOrder> _recentOrders = [];
  List<Product> _lowStockProducts = [];
  List<RevenueDataPoint> _revenueData = [];
  List<TopSellingProduct> _topSellingProducts = [];
  List<Customer> _recentCustomers = [];

  bool _isLoading = true;
  bool _isOnline = true;
  bool _isRefreshing = false;
  bool _isOfflineMode = false;
  String _selectedPeriod = 'today';

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

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isRefreshing = true;
    });

    try {
      // Get auth provider from context to ensure we have the current user
      final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated. Please log in again.');
      }

      final tenantId = currentUser.tenantId;
      if (tenantId.isEmpty || tenantId == 'super_admin') {
        throw Exception('Invalid tenant ID: $tenantId. User may be a super admin or not assigned to a tenant.');
      }

      print('Loading dashboard for tenant: $tenantId, user: ${currentUser.email}');

      // First, check if we actually have network connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasNetwork = connectivityResult != ConnectivityResult.none;

      if (!hasNetwork) {
        print('No network connectivity - loading offline data');
        await _loadOfflineData(tenantId);
        _isOfflineMode = true;
        return;
      }

      // Check if we have recent cached data first (but don't use it if we're refreshing)
      if (!_isRefreshing) {
        final cachedData = await _localDb.getDashboardData(tenantId);
        if (cachedData != null) {
          print('Loading dashboard from cache while checking online data');
          _loadCachedData(cachedData);
        }
      }

      // Try to load online data with proper error handling
      bool onlineSuccess = false;
      try {
        await _loadOnlineData(tenantId);
        onlineSuccess = true;
        _isOfflineMode = false;
      } catch (onlineError) {
        print('Online data loading failed: $onlineError');
        onlineSuccess = false;
      }

      // If online failed, try offline data
      if (!onlineSuccess) {
        print('Falling back to offline data');
        await _loadOfflineData(tenantId);
        _isOfflineMode = true;

        // Only show offline warning if we actually failed to get online data
        if (mounted && hasNetwork) { // We have network but online loading failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi_off, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Showing offline data. Some features may be limited.'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange[700],
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

    } catch (e) {
      print('Error loading dashboard data: $e');

      // Final fallback - try to generate data from local database
      try {
        final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
        final tenantId = authProvider.currentUser?.tenantId;
        if (tenantId != null) {
          await _loadOfflineData(tenantId);
          _isOfflineMode = true;
        } else {
          throw e;
        }
      } catch (fallbackError) {
        print('Fallback data loading also failed: $fallbackError');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isRefreshing = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadDashboardData,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }
  void _loadCachedData(OfflineDashboardData cachedData) {
    if (mounted) {
      setState(() {
        _stats = cachedData.stats;
        _recentOrders = cachedData.recentOrders ?? [];
        _lowStockProducts = cachedData.lowStockProducts ?? [];
        _revenueData = cachedData.revenueData ?? [];
        _topSellingProducts = cachedData.topSellingProducts ?? [];
        _recentCustomers = cachedData.recentCustomers ?? [];
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }
  Future<void> _loadOnlineData(String tenantId) async {
    // Verify tenant exists and is active
    final tenantDoc = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .get();

    if (!tenantDoc.exists) {
      throw Exception('Tenant not found in database. ID: $tenantId');
    }

    final tenantData = tenantDoc.data();
    if (tenantData != null && (tenantData['isActive'] == false)) {
      throw Exception('Tenant account is inactive. Please contact administrator.');
    }

    _firestore.setTenantId(tenantId);
    _posService.setTenantContext(tenantId);

    // Load all data with timeout protection
    final results = await Future.wait([
      _fetchDashboardStats(tenantId).timeout(Duration(seconds: 30)),
      _fetchRecentOrders(tenantId).timeout(Duration(seconds: 20)),
      _fetchLowStockProducts(tenantId).timeout(Duration(seconds: 20)),
      _fetchRevenueData(tenantId).timeout(Duration(seconds: 25)),
      _fetchTopSellingProducts(tenantId).timeout(Duration(seconds: 25)),
      _fetchRecentCustomers(tenantId).timeout(Duration(seconds: 20)),
    ], eagerError: true).catchError((error) {
      throw Exception('Data loading timeout: $error');
    });

    if (mounted) {
      setState(() {
        _stats = results[0] as DashboardStats;
        _recentOrders = results[1] as List<AppOrder>;
        _lowStockProducts = results[2] as List<Product>;
        _revenueData = results[3] as List<RevenueDataPoint>;
        _topSellingProducts = results[4] as List<TopSellingProduct>;
        _recentCustomers = results[5] as List<Customer>;
        _isLoading = false;
        _isRefreshing = false;
      });
    }

    // Cache the data for offline use
    final offlineData = OfflineDashboardData(
      stats: _stats,
      recentOrders: _recentOrders,
      lowStockProducts: _lowStockProducts,
      revenueData: _revenueData,
      topSellingProducts: _topSellingProducts,
      recentCustomers: _recentCustomers,
      lastUpdated: DateTime.now(),
      tenantId: tenantId,
    );

    await _localDb.saveDashboardData(offlineData);
  }

  Future<void> _loadOfflineData(String tenantId) async {
    print('Loading dashboard data from offline sources');

    // Generate data from local database
    final results = await Future.wait([
      _localDb.generateOfflineStats(),
      _localDb.getPendingOrders().then((orders) => orders.take(5).map((order) {
        final orderData = order['order_data'] as Map<String, dynamic>;
        return AppOrder.fromFirestore(orderData, order['id'].toString());
      }).toList()),
      _localDb.getLowStockProducts().then((products) => products.take(3).toList()),
      _localDb.generateRevenueData(),
      _localDb.generateTopSellingProducts(),
      _localDb.getRecentCustomers(limit: 5),
    ]);

    if (mounted) {
      setState(() {
        _stats = results[0] as DashboardStats;
        _recentOrders = results[1] as List<AppOrder>;
        _lowStockProducts = results[2] as List<Product>;
        _revenueData = results[3] as List<RevenueDataPoint>;
        _topSellingProducts = results[4] as List<TopSellingProduct>;
        _recentCustomers = results[5] as List<Customer>;
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
                    ? Colors.orange[400]!.withOpacity(0.3)
                    : Colors.green[400]!.withOpacity(0.3),
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
      print('Error in _fetchDashboardStats: $e');
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
      print('Error fetching recent orders: $e');
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
      print('Error fetching low stock products: $e');
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
      print('Error generating revenue data: $e');
      return [];
    }
  }

  Future<List<TopSellingProduct>> _fetchTopSellingProducts(String tenantId) async {
    _firestore.setTenantId(tenantId);

    try {
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final ordersSnapshot = await _firestore.ordersRef
          .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final productSales = <String, TopSellingProduct>{};
      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        final lineItems = orderData['lineItems'] as List<dynamic>? ?? [];

        for (final item in lineItems) {
          final itemMap = item as Map<String, dynamic>;
          final productId = itemMap['productId']?.toString() ?? '';
          final productName = itemMap['productName']?.toString() ?? 'Unknown Product';
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
              String? imageUrl;
              try {
                final productDoc = await _firestore.productsRef.doc(productId).get();
                if (productDoc.exists) {
                  final productData = productDoc.data() as Map<String, dynamic>?;
                  imageUrl = productData?['imageUrl']?.toString();
                }
              } catch (e) {
                print('Error fetching product image: $e');
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
    } catch (e) {
      print('Error fetching top selling products: $e');
      return [];
    }
  }

  Future<List<Customer>> _fetchRecentCustomers(String tenantId) async {
    try {
      _posService.setTenantContext(tenantId);
      final customers = await _posService.getAllCustomers();
      return customers.take(5).toList();
    } catch (e) {
      print('Error fetching recent customers: $e');
      return [];
    }
  }


  void _showPeriodSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Time Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildPeriodOption('Today', 'today'),
            _buildPeriodOption('This Week', 'week'),
            _buildPeriodOption('This Month', 'month'),
            _buildPeriodOption('This Year', 'year'),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodOption(String label, String value) {
    return ListTile(
      leading: Icon(Icons.calendar_today, color: Colors.blue),
      title: Text(label),
      trailing: _selectedPeriod == value
          ? Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        setState(() => _selectedPeriod = value);
        Navigator.pop(context);
        _loadDashboardData();
      },
    );
  }


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
                  _buildActivitySection(),
                  SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _validateTenantAccess() async {
    final user = _authProvider.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }

    final tenantId = user.tenantId;
    if (tenantId.isEmpty) {
      throw Exception('User ${user.uid} has no tenant ID assigned');
    }

    final tenantDoc = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .get();

    if (!tenantDoc.exists) {
      throw Exception('Tenant $tenantId does not exist in database');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('tenants')
        .doc(tenantId)
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      throw Exception('User ${user.uid} not found in tenant $tenantId');
    }

    print('Tenant validation successful: $tenantId');
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dashboard Error'),
        content: Text('Failed to load dashboard data: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadDashboardData();
            },
            child: Text('Retry'),
          ),
        ],
      ),
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
        color: Colors.white.withOpacity(0.1),
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

            _buildLowStockAlert(),

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
                  color: Colors.black.withOpacity(0.05),
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


  Widget _buildLowStockAlert() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                'Low Stock Alert',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              if (_lowStockProducts.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_lowStockProducts.length} items',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          _lowStockProducts.isEmpty
              ? _buildNoLowStock()
              : Column(
            children: _lowStockProducts
                .map((product) => _LowStockItem(product: product))
                .toList(),
          ),


          ],
      ),
    );
  }

  Widget _buildNoLowStock() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.green[300]),
          SizedBox(height: 8),
          Text(
            'All products are well stocked',
            style: TextStyle(
              color: Colors.green[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildActivitySection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          children: [
            _buildRecentOrders(),
            SizedBox(height: 16),
            _buildTopProducts(),
            SizedBox(height: 16),

            _buildRecentCustomers()
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Spacer(),
              Text(
                '${_recentOrders.length} orders',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 16),
          _recentOrders.isEmpty
              ? _buildNoRecentActivity()
              : Column(
            children: _recentOrders
                .map((appOrder) => _RecentOrderItem(order: appOrder))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Selling Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _topSellingProducts.isEmpty
              ? _buildNoTopProducts()
              : Column(
            children: _topSellingProducts
                .map((product) => _TopProductItem(product: product))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCustomers() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Customers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          _recentCustomers.isEmpty
              ? _buildNoRecentCustomers()
              : ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 200, // Add a maximum height constraint
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _recentCustomers.length,
              itemBuilder: (context, index) {
                final customer = _recentCustomers[index];
                return _RecentCustomerItem(customer: customer);
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildNoRecentActivity() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text(
            'No recent transactions',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTopProducts() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.star_outline, size: 48, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text(
            'No sales data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecentCustomers() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
          SizedBox(height: 8),
          Text('No customers', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
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
            color: Colors.white.withOpacity(0.2),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend >= 0 ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        trend >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 12,
                        color: trend >= 0 ? Colors.green[600] : Colors.red[600],
                      ),
                      SizedBox(width: 2),
                      Text(
                        '${trend.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: trend >= 0
                              ? Colors.green[600]
                              : Colors.red[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }
}
class _RecentCustomerItem extends StatelessWidget {
  final Customer customer;

  const _RecentCustomerItem({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.person, size: 20, color: Colors.blue),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.fullName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  customer.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _TopProductItem extends StatelessWidget {
  final TopSellingProduct product;

  const _TopProductItem({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              image: product.imageUrl != null
                  ? DecorationImage(
                image: NetworkImage(product.imageUrl!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: product.imageUrl == null
                ? Center(
              child: Icon(
                Icons.shopping_bag,
                size: 20,
                color: Colors.grey,
              ),
            )
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${product.totalSold} sold • ${Constants.CURRENCY_NAME}${product.totalRevenue.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _LowStockItem extends StatelessWidget {
  final Product product;

  const _LowStockItem({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              image: product.imageUrl != null
                  ? DecorationImage(
                image: NetworkImage(product.imageUrl!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: product.imageUrl == null
                ? Center(
              child: Icon(
                Icons.inventory_2,
                size: 20,
                color: Colors.orange,
              ),
            )
                : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Only ${product.stockQuantity} left',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, size: 18, color: Colors.orange[700]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RestockProductScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
class _RecentOrderItem extends StatelessWidget {
  final AppOrder order;

  const _RecentOrderItem({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.receipt, size: 20, color: Colors.green[600]),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.number}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${order.lineItems.length} items • ${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(order.dateCreated),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
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

class TopSellingProduct {
  final String productId;
  final String productName;
  final int totalSold;
  final double totalRevenue;
  final String? imageUrl;

  TopSellingProduct({
    required this.productId,
    required this.productName,
    required this.totalSold,
    required this.totalRevenue,
    this.imageUrl,
  });
}
