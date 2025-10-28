// app.dart - Complete Multi-Tenant SaaS System
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mpcm/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'checkou_screen.dart';
import 'features/users/users_base.dart';
import 'firebase_options.dart';
import 'modules/auth/models/activity_type.dart';
import 'modules/auth/models/tenant_model.dart';
import 'modules/auth/providers/auth_provider.dart';
import 'modules/auth/providers/settings_provider.dart';
import 'modules/auth/screens/auth_wrapper.dart';
import 'modules/auth/services/offline_storage_service.dart';
import 'modules/auth/widgets/app_lifecycle_wrapper.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      // For production builds, use:
      androidProvider: AndroidProvider.playIntegrity,
      // iOS: default provider is DeviceCheck (no need to specify)
    );
    final sharedPreferences = await SharedPreferences.getInstance();
    final offlineStorageService = OfflineStorageService(sharedPreferences);
    // Initialize Hive for offline storage
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);
    await Hive.openBox('app_cache');
    await Hive.openBox('offline_data');

    runApp(MultiProvider(
        providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),

  ChangeNotifierProvider(create: (_) => MyAuthProvider(offlineStorageService)),
          ChangeNotifierProvider(create: (_) => TenantProvider()),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider()..loadSavedTheme(),
          ),
        ],child: MultiTenantSaaSApp()));
  } catch (e) {
    print('Firebase initialization error: $e');
    runApp(ErrorApp(error: e));
  }
}

class ErrorApp extends StatelessWidget {
  final dynamic error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 20),
                Text(
                  'Initialization Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Failed to initialize app: $error',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                ElevatedButton(onPressed: () => main(), child: Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================
// FIREBASE SERVICE LAYER
// =============================
class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  // Add to FirebaseService class
  static Stream<QuerySnapshot> getSalesStream(
    String tenantId, {
    int limit = 100,
  }) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('sales')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  static Stream<QuerySnapshot> getSalesByDateRange(
    String tenantId, {
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<Map<String, dynamic>> getSalesStats(String tenantId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get today's sales
      final todaySales = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .where('createdAt', isGreaterThanOrEqualTo: todayStart)
          .where('createdAt', isLessThanOrEqualTo: todayEnd)
          .get();

      // Get all sales for total stats
      final allSales = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .get();

      double todayRevenue = 0;
      int todaySalesCount = todaySales.docs.length;

      for (final doc in todaySales.docs) {
        final data = doc.data();
        todayRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
      }

      double totalRevenue = 0;
      int totalSalesCount = allSales.docs.length;

      for (final doc in allSales.docs) {
        final data = doc.data();
        totalRevenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
      }

      return {
        'todayRevenue': todayRevenue,
        'todaySalesCount': todaySalesCount,
        'totalRevenue': totalRevenue,
        'totalSalesCount': totalSalesCount,
        'averageOrderValue': totalSalesCount > 0
            ? totalRevenue / totalSalesCount
            : 0,
      };
    } catch (e) {
      print('Error getting sales stats: $e');
      return {
        'todayRevenue': 0.0,
        'todaySalesCount': 0,
        'totalRevenue': 0.0,
        'totalSalesCount': 0,
        'averageOrderValue': 0.0,
      };
    }
  }

  // In FirebaseService class - Fix the loginWithActivity method
  static Future<UserCredential> loginWithActivity({
    required String email,
    required String password,
    String ipAddress = '',
    String userAgent = '',
  }) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update last login
    await _updateLastLogin(userCredential.user!.uid);

    // Log login activity
    final userDoc = await _getUserDocument(userCredential.user!.uid);
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      await TenantUsersService.logUserActivity(
        tenantId: userData['tenantId']?.toString() ?? 'unknown_tenant',
        userId: userCredential.user!.uid,
        userEmail: email,
        userDisplayName:
            userData['displayName']?.toString() ?? email.split('@').first,
        action: ActivityType.user_login,
        description: 'User logged in successfully',
        metadata: {'loginMethod': 'email_password', 'ipAddress': ipAddress},
        ipAddress: ipAddress,
        userAgent: userAgent,
      );
    }

    return userCredential;
  }

  // Fix the _updateLastLogin method
  static Future<void> _updateLastLogin(String uid) async {
    final userDoc = await _getUserDocument(uid);
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final tenantId = userData['tenantId']?.toString() ?? 'unknown_tenant';
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(uid)
          .update({'lastLogin': FieldValue.serverTimestamp()});
    }
  }

  // Fix the createSaleWithUserTracking method
  static Future<void> createSaleWithUserTracking({
    required String tenantId,
    required String cashierId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double taxAmount,
    required String paymentMethod,
    String? customerEmail,
    String? customerName,
  }) async {
    return await _handleFirebaseCall(() async {
      final saleRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .doc();

      // Get cashier details
      final cashierDoc = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(cashierId)
          .get();

      final cashierData = cashierDoc.data() ?? {};

      // Start a batch write for transaction
      final batch = _firestore.batch();

      // Create enhanced sale document
      batch.set(saleRef, {
        'id': saleRef.id,
        'cashierId': cashierId,
        'cashierName':
            cashierData['displayName']?.toString() ?? 'Unknown Cashier',
        'cashierEmail': cashierData['email']?.toString() ?? 'unknown@email.com',
        'items': items,
        'totalAmount': totalAmount,
        'taxAmount': taxAmount,
        'paymentMethod': paymentMethod,
        'customerEmail': customerEmail,
        'customerName': customerName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // Update product stock
      for (final item in items) {
        final productRef = _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .doc(item['productId']?.toString() ?? '');

        batch.update(productRef, {
          'stock': FieldValue.increment(-(item['quantity'] as int? ?? 0)),
        });
      }

      // Create notification for new sale
      batch.set(
        _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('notifications')
            .doc(),
        {
          'type': 'new_sale',
          'title': 'New Sale Completed',
          'message':
              'Sale #${saleRef.id} for \$${totalAmount.toStringAsFixed(2)}',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      // Log sale activity
      await TenantUsersService.logUserActivity(
        tenantId: tenantId,
        userId: cashierId,
        userEmail: cashierData['email']?.toString() ?? 'unknown@email.com',
        userDisplayName:
            cashierData['displayName']?.toString() ?? 'Unknown User',
        action: ActivityType.sale_created,
        description:
            'Sale #${saleRef.id} completed for \$${totalAmount.toStringAsFixed(2)}',
        metadata: {
          'saleId': saleRef.id,
          'totalAmount': totalAmount,
          'itemsCount': items.length,
          'paymentMethod': paymentMethod,
        },
      );

      return;
    });
  }

  // In FirebaseService class - Fix the _logUserActivity method calls

  // Enhanced Login with Activity Tracking - FIXED

  // Update User Status with Activity Logging - FIXED


  // Enhanced User Creation


  static Future<DocumentSnapshot> _getUserDocument(String uid) async {
    // Search across all tenants for the user
    final tenantsSnapshot = await _firestore
        .collection('tenants')
        .where('isActive', isEqualTo: true)
        .get();

    for (final tenantDoc in tenantsSnapshot.docs) {
      final userDoc = await _firestore
          .collection('tenants')
          .doc(tenantDoc.id)
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        return userDoc;
      }
    }

    throw Exception('User document not found');
  }

  // Get User Activities

  // Existing methods remain the same but enhanced with activity logging...
  static Future<void> createTenant({
    required String tenantId,
    required String businessName,
    required String adminEmail,
    required String adminPassword,
    required String subscriptionPlan,
  }) async {
    return await _handleFirebaseCall(() async {
      // Validate inputs
      if (adminPassword.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      if (!_isEmailValid(adminEmail)) {
        throw 'Please enter a valid email address';
      }

      // Create tenant document
      await _firestore.collection('tenants').doc(tenantId).set({
        'businessName': businessName,
        'subscriptionPlan': subscriptionPlan,
        'subscriptionExpiry': _calculateExpiryDate(subscriptionPlan),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'branding': {
          'primaryColor': '#2196F3',
          'secondaryColor': '#FF9800',
          'logoUrl': '',
          'currency': 'USD',
          'taxRate': 0.0,
        },
      });

      // Create admin user using the enhanced method
      await TenantUsersService.createUserWithDetails(
        tenantId: tenantId,
        email: adminEmail,
        password: adminPassword,
        displayName: 'Admin',
        role: 'clientAdmin',
        createdBy: 'system',
      );

      return;
    });
  }

  // ... Rest of the existing FirebaseService methods remain the same

  static DateTime _calculateExpiryDate(String plan) {
    final now = DateTime.now();
    switch (plan) {
      case 'monthly':
        return now.add(Duration(days: 30));
      case 'yearly':
        return now.add(Duration(days: 365));
      default:
        return now.add(Duration(days: 30));
    }
  }

  static bool _isEmailValid(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    return regex.hasMatch(email);
  }

  static Future<T> _handleFirebaseCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }

  static String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }

  static String _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied. Please check your permissions.';
      case 'not-found':
        return 'Requested data not found.';
      case 'already-exists':
        return 'Item already exists.';
      case 'resource-exhausted':
        return 'Quota exceeded. Please try again later.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please check your connection.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  static Future<void> _cacheOfflineData(
    String type,
    Map<String, dynamic> data,
  ) async {
    final offlineBox = Hive.box('offline_data');
    final pendingSync =
        offlineBox.get('pending_sync', defaultValue: []) as List;
    pendingSync.add({'type': type, 'data': data, 'timestamp': DateTime.now()});
    await offlineBox.put('pending_sync', pendingSync);
  }

  // Add to FirebaseService class
  static Future<void> createUserInTenant({
    required String tenantId,
    required String email,
    required String password,
    required String role,
    required String createdBy,
  }) async {
    return await _handleFirebaseCall(() async {
      // Validate password length
      if (password.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      try {
        // Create user in Firebase Auth
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: email.trim(),
              password: password,
            );

        // Create user document in tenant's users collection
        await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'email': email.trim(),
              'role': role,
              'createdBy': createdBy,
              'createdAt': FieldValue.serverTimestamp(),
              'isActive': true,
              'tenantId': tenantId,
              'lastLogin': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        // If user creation fails in Firestore, delete the auth user
        if (_auth.currentUser != null &&
            _auth.currentUser!.email == email.trim()) {
          await _auth.currentUser!.delete();
        }
        rethrow;
      }

      return;
    });
  }

  // Add to FirebaseService class

  // Enhanced error handling wrapper

  // Tenant management
  // Update the createTenant method in FirebaseService

  // Product management
  static Future<void> addProduct({
    required String tenantId,
    required String name,
    required double price,
    required int stock,
    required String category,
    String? description,
  }) async {
    return await _handleFirebaseCall(() async {
      final productRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('products')
          .doc();

      await productRef.set({
        'id': productRef.id,
        'name': name,
        'price': price,
        'stock': stock,
        'category': category,
        'description': description ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lowStockAlert': stock <= 10,
      });

      // Check for low stock and trigger notification
      if (stock <= 10) {
        await _createLowStockNotification(tenantId, name, stock);
      }

      return;
    });
  }

  static Future<void> _createLowStockNotification(
    String tenantId,
    String productName,
    int stock,
  ) async {
    await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('notifications')
        .add({
          'type': 'low_stock',
          'title': 'Low Stock Alert',
          'message': '$productName is running low. Current stock: $stock',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // Sales management
  static Future<void> createSale({
    required String tenantId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double taxAmount,
    required String paymentMethod,
  }) async {
    return await _handleFirebaseCall(() async {
      final saleRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .doc();

      // Start a batch write for transaction
      final batch = _firestore.batch();

      // Create sale document
      batch.set(saleRef, {
        'id': saleRef.id,
        'items': items,
        'totalAmount': totalAmount,
        'taxAmount': taxAmount,
        'paymentMethod': paymentMethod,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      // Update product stock
      for (final item in items) {
        final productRef = _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .doc(item['productId']);

        batch.update(productRef, {
          'stock': FieldValue.increment(-(item['quantity'] as int)),
        });
      }

      // Create notification for new sale
      batch.set(
        _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('notifications')
            .doc(),
        {
          'type': 'new_sale',
          'title': 'New Sale Completed',
          'message':
              'Sale #${saleRef.id} for \$${totalAmount.toStringAsFixed(2)}',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      // Cache offline data
      await _cacheOfflineData('sales', {
        'tenantId': tenantId,
        'saleId': saleRef.id,
        'totalAmount': totalAmount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      return;
    });
  }

  // Ticket system



  // User management

  static Stream<QuerySnapshot> getSalesAnalytics(
    String tenantId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('sales')
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .snapshots();
  }

  static Future<Map<String, dynamic>> getDashboardStats(String tenantId) async {
    return await _handleFirebaseCall(() async {
      final salesSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('sales')
          .where(
            'createdAt',
            isGreaterThan: DateTime.now().subtract(Duration(days: 30)),
          )
          .get();

      final productsSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('products')
          .get();

      final totalRevenue = salesSnapshot.docs.fold(0.0, (sum, doc) {
        final data = doc.data();
        return sum + (data['totalAmount'] as double);
      });

      final totalSales = salesSnapshot.docs.length;
      final lowStockProducts = productsSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['lowStockAlert'] == true;
      }).length;

      return {
        'totalRevenue': totalRevenue,
        'totalSales': totalSales,
        'lowStockProducts': lowStockProducts,
        'totalProducts': productsSnapshot.docs.length,
      };
    });
  }

  // Offline data synchronization

  static Future<void> syncOfflineData(String tenantId) async {
    final offlineBox = Hive.box('offline_data');
    final pendingSync =
        offlineBox.get('pending_sync', defaultValue: []) as List;

    for (final syncItem in pendingSync) {
      try {
        if (syncItem['type'] == 'sales') {
          // Recreate sale with offline data
          await createSale(
            tenantId: tenantId,
            items: [], // You'd reconstruct from cached data
            totalAmount: syncItem['data']['totalAmount'],
            taxAmount: 0.0,
            paymentMethod: 'cash',
          );
        }
      } catch (e) {
        // If sync fails, keep in pending for next attempt
        continue;
      }
    }

    // Clear successfully synced data
    await offlineBox.put('pending_sync', []);
  }
}

// =============================
// ENUMS AND MODELS
// =============================


// =============================
// PROVIDERS (STATE MANAGEMENT)
// =============================
// =============================
// ENHANCED AUTH PROVIDER
// =============================
// Enhanced AuthProvider with proper casting


// =============================
// WIDGETS - CORE UI COMPONENTS
// =============================

class MultiTenantSaaSApp extends StatelessWidget {
  const MultiTenantSaaSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return
      // 👇 Use Builder to get a new context with access to the providers
       Builder(
        builder: (context) {
          final themeProvider = context.watch<ThemeProvider>();

          return MaterialApp(
            title: 'Multi-Tenant SaaS',
            theme: ThemeData(
              useMaterial3: true,
              brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
              primaryColor: themeProvider.getPrimaryColor(),
              colorScheme: ColorScheme.fromSeed(
                seedColor: themeProvider.getPrimaryColor(),
                brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
              ),
              scaffoldBackgroundColor: themeProvider.getBackgroundColor(),
              cardColor: themeProvider.getSurfaceColor(),
              textTheme: TextTheme(
                bodyLarge: TextStyle(color: themeProvider.getPrimaryTextColor()),
                bodyMedium: TextStyle(color: themeProvider.getSecondaryTextColor()),
              ),
            ),
            home: AppLifecycleWrapper(child: const AuthWrapper()),
            debugShowCheckedModeBanner: false,
          );
        },
          );
  }
}

class ClientSignupScreen extends StatefulWidget {
  const ClientSignupScreen({super.key});

  @override
  _ClientSignupScreenState createState() => _ClientSignupScreenState();
}

class _ClientSignupScreenState extends State<ClientSignupScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // Form data
  String _businessName = '';
  String _adminEmail = '';
  String _adminPassword = '';
  String _subscriptionPlan = 'monthly';
  final List<Map<String, dynamic>> _initialProducts = [];
  final List<Map<String, dynamic>> _initialUsers = [];

  final List<Widget> _steps = [];

  @override
  void initState() {
    super.initState();
    _steps.addAll([
      _BusinessInfoStep(_updateBusinessInfo),
      _AdminAccountStep(_updateAdminAccount),
      _SubscriptionStep(_updateSubscription),
      // _InitialSetupStep(_updateInitialSetup),
      _ConfirmationStep(_completeSignup),
    ]);
  }

  void _updateBusinessInfo(String businessName) {
    setState(() => _businessName = businessName);
    _nextStep();
  }

  void _updateAdminAccount(String email, String password) {
    setState(() {
      _adminEmail = email;
      _adminPassword = password;
    });
    _nextStep();
  }

  void _updateSubscription(String plan) {
    setState(() => _subscriptionPlan = plan);
    _nextStep();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeSignup(BuildContext context) async {
    try {
      final tenantId =
          '${_businessName.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseService.createTenant(
        tenantId: tenantId,
        businessName: _businessName,
        adminEmail: _adminEmail,
        adminPassword: _adminPassword,
        subscriptionPlan: _subscriptionPlan,
      );

      // Add initial products
      for (final product in _initialProducts) {
        await FirebaseService.addProduct(
          tenantId: tenantId,
          name: product['name'],
          price: product['price'],
          stock: product['stock'],
          category: product['category'],
        );
      }

      // Add initial users
      // for (final user in _initialUsers) {
      //   await TenantUsersService.createUserWithDetails(
      //     tenantId: tenantId,
      //     email: user['email'],
      //     password: 'temp123', // In production, generate secure temp password
      //     role: user['role'],
      //     createdBy: 'system',
      //   );
      // }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tenant created successfully! You can now login.'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating tenant: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Client Signup'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentStep + 1) / _steps.length),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: NeverScrollableScrollPhysics(),
              children: _steps,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessInfoStep extends StatefulWidget {
  final Function(String) onComplete;
  const _BusinessInfoStep(this.onComplete);

  @override
  __BusinessInfoStepState createState() => __BusinessInfoStepState();
}

class __BusinessInfoStepState extends State<_BusinessInfoStep> {
  final _businessNameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 80, color: Colors.blue),
          SizedBox(height: 20),
          Text(
            'Business Information',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Tell us about your business',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),
          TextField(
            onChanged: (v) {
              setState(() {});
            },
            controller: _businessNameController,
            decoration: InputDecoration(
              labelText: 'Business Name',
              prefixIcon: Icon(Icons.business_center),
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: _businessNameController.text.isEmpty
                ? null
                : () {
                    widget.onComplete(_businessNameController.text);
                  },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _AdminAccountStep extends StatefulWidget {
  final Function(String, String) onComplete;
  const _AdminAccountStep(this.onComplete);

  @override
  __AdminAccountStepState createState() => __AdminAccountStepState();
}

class __AdminAccountStepState extends State<_AdminAccountStep> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.admin_panel_settings, size: 80, color: Colors.green),
          SizedBox(height: 20),
          Text(
            'Admin Account',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Create your administrator account',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Admin Email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          SizedBox(height: 20),
          TextField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: _canProceed()
                ? () {
                    widget.onComplete(
                      _emailController.text,
                      _passwordController.text,
                    );
                  }
                : null,
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    return _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text &&
        _passwordController.text.length >= 6;
  }
}

class _SubscriptionStep extends StatefulWidget {
  final Function(String) onComplete;
  const _SubscriptionStep(this.onComplete);

  @override
  __SubscriptionStepState createState() => __SubscriptionStepState();
}

class __SubscriptionStepState extends State<_SubscriptionStep> {
  String _selectedPlan = 'monthly';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card, size: 80, color: Colors.orange),
          SizedBox(height: 20),
          Text(
            'Subscription Plan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Choose your subscription plan',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),

          _buildPlanCard(
            'Monthly',
            '\$29/month',
            'monthly',
            Icons.calendar_today,
          ),
          SizedBox(height: 15),
          _buildPlanCard(
            'Yearly',
            '\$299/year',
            'yearly',
            Icons.calendar_view_month,
          ),
          SizedBox(height: 15),
          _buildPlanCard(
            'Custom',
            'Contact sales',
            'custom',
            Icons.business_center,
          ),

          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => widget.onComplete(_selectedPlan),
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    String title,
    String price,
    String plan,
    IconData icon,
  ) {
    return Card(
      color: _selectedPlan == plan ? Colors.blue[50] : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: _selectedPlan == plan ? Colors.blue : Colors.grey,
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(price),
        trailing: _selectedPlan == plan
            ? Icon(Icons.check_circle, color: Colors.blue)
            : null,
        onTap: () => setState(() => _selectedPlan = plan),
      ),
    );
  }
}

class _ConfirmationStep extends StatelessWidget {
  final Function(BuildContext) onComplete;
  const _ConfirmationStep(this.onComplete);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green),
          SizedBox(height: 20),
          Text(
            'Ready to Go!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Your tenant will be created with the selected configuration.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => onComplete(context),
            child: Text('Create Tenant'),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final tenant = authProvider.currentTenant;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.business, size: 40),
                  ),
                  SizedBox(height: 16),
                  Text(
                    tenant!.businessName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Subscription: ${tenant.subscriptionPlan}'),
                  Text(
                    'Expires: ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry)}',
                  ),
                  SizedBox(height: 16),
                  tenant.isSubscriptionActive
                      ? Chip(
                          label: Text(
                            'Active',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                        )
                      : Chip(
                          label: Text(
                            'Expired',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red,
                        ),
                ],
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () {
              final authProvider = Provider.of<MyAuthProvider>(
                context,
                listen: false,
              );
              authProvider.logout();
            },
            child: Text("Logout"),
          ),
          SizedBox(height: 20),

          // Expanded(
          //   child: ListView(
          //     children: [
          //       ListTile(
          //         leading: Icon(Icons.support),
          //         title: Text('Support Tickets'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => TicketsScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.settings),
          //         title: Text('Branding & Settings'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => BrandingScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.analytics),
          //         title: Text('Analytics & Reports'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => AnalyticsScreen()),
          //         ),
          //       ),
          //       ListTile(
          //         leading: Icon(Icons.notifications),
          //         title: Text('Notifications'),
          //         onTap: () => Navigator.push(
          //           context,
          //           MaterialPageRoute(builder: (_) => NotificationsScreen()),
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}

class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});

  @override
  _BrandingScreenState createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  final _currencyController = TextEditingController();
  final _taxRateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    final authProvider = context.read<MyAuthProvider>();
    final branding = authProvider.currentTenant?.branding ?? {};

    _primaryColorController.text = branding['primaryColor'] ?? '#2196F3';
    _secondaryColorController.text = branding['secondaryColor'] ?? '#FF9800';
    _currencyController.text = branding['currency'] ?? 'USD';
    _taxRateController.text = (branding['taxRate'] ?? 0.0).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Branding & Settings')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _primaryColorController,
              decoration: InputDecoration(
                labelText: 'Primary Color (Hex)',
                hintText: '#2196F3',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _secondaryColorController,
              decoration: InputDecoration(
                labelText: 'Secondary Color (Hex)',
                hintText: '#FF9800',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _currencyController,
              decoration: InputDecoration(
                labelText: 'Currency',
                hintText: 'USD',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _taxRateController,
              decoration: InputDecoration(
                labelText: 'Tax Rate (%)',
                hintText: '0.0',
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveSettings,
              child: Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() {
    final authProvider = context.read<MyAuthProvider>();

    FirebaseFirestore.instance
        .collection('tenants')
        .doc(authProvider.currentUser!.tenantId)
        .update({
          'branding': {
            'primaryColor': _primaryColorController.text,
            'secondaryColor': _secondaryColorController.text,
            'currency': _currencyController.text,
            'taxRate': double.parse(_taxRateController.text),
          },
        });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Settings updated successfully')));
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Analytics & Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseService.getSalesAnalytics(
          authProvider.currentUser!.tenantId,
          DateTime.now().subtract(Duration(days: 30)),
          DateTime.now(),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final sales = snapshot.data!.docs;
          final salesData = _prepareSalesData(sales);

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Sales Analytics - Last 30 Days',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(),
                    series: <CartesianSeries>[
                      LineSeries<Map<String, dynamic>, String>(
                        dataSource: salesData,
                        xValueMapper: (data, _) => data['date'],
                        yValueMapper: (data, _) => data['amount'],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _prepareSalesData(
    List<QueryDocumentSnapshot> sales,
  ) {
    final Map<String, double> dailySales = {};

    for (final sale in sales) {
      final data = sale.data() as Map<String, dynamic>;
      final date = DateFormat(
        'MMM dd',
      ).format((data['createdAt'] as Timestamp).toDate());
      final amount = data['totalAmount'] as double;

      dailySales[date] = (dailySales[date] ?? 0.0) + amount;
    }

    return dailySales.entries
        .map((e) => {'date': e.key, 'amount': e.value})
        .toList();
  }
}

class SystemAnalyticsScreen extends StatelessWidget {
  const SystemAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'System Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <CartesianSeries>[
                  ColumnSeries<Map<String, dynamic>, String>(
                    dataSource: _prepareTenantData(tenantProvider.tenants),
                    xValueMapper: (data, _) => data['name'],
                    yValueMapper: (data, _) => data['value'],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _prepareTenantData(List<Tenant> tenants) {
    return tenants
        .map(
          (tenant) => {
            'name': tenant.businessName.length > 10
                ? '${tenant.businessName.substring(0, 10)}...'
                : tenant.businessName,
            'value': tenant.isSubscriptionActive ? 1 : 0,
          },
        )
        .toList();
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tenants')
            .doc(authProvider.currentUser!.tenantId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification =
                  notifications[index].data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: _getNotificationIcon(notification['type']),
                  title: Text(notification['title']),
                  subtitle: Text(notification['message']),
                  trailing: notification['isRead']
                      ? null
                      : Chip(
                          label: Text(
                            'New',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.blue,
                        ),
                  onTap: () => _markAsRead(notifications[index].id, context),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Icon _getNotificationIcon(String type) {
    switch (type) {
      case 'low_stock':
        return Icon(Icons.warning, color: Colors.orange);
      case 'new_sale':
        return Icon(Icons.attach_money, color: Colors.green);
      case 'subscription_expired':
        return Icon(Icons.error, color: Colors.red);
      case 'subscription_reminder':
        return Icon(Icons.notifications, color: Colors.blue);
      default:
        return Icon(Icons.notifications);
    }
  }

  void _markAsRead(String notificationId, BuildContext context) {
    final authProvider = context.read<MyAuthProvider>();

    FirebaseFirestore.instance
        .collection('tenants')
        .doc(authProvider.currentUser!.tenantId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}

// =============================
// UTILITY FUNCTIONS
// =============================
// class AppUtils {
//   static String formatCurrency(double amount, String currency) {
//     return '$currency ${amount.toStringAsFixed(2)}';
//   }
//
//   static String formatDate(DateTime date) {
//     return DateFormat('MMM dd, yyyy').format(date);
//   }
//
//   static String formatDateTime(DateTime date) {
//     return DateFormat('MMM dd, yyyy HH:mm').format(date);
//   }
//
//   static bool isEmailValid(String email) {
//     final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
//     return regex.hasMatch(email);
//   }
//
//   static Future<bool> checkConnectivity() async {
//     try {
//       final result = await InternetAddress.lookup('google.com');
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } on SocketException catch (_) {
//       return false;
//     }
//   }
// }

// =============================
// OFFLINE SUPPORT & CACHING
// =============================
class OfflineManager {
  static final Box _cache = Hive.box('app_cache');
  static final Box _offlineData = Hive.box('offline_data');

  static Future<void> cacheData(String key, dynamic data) async {
    await _cache.put(key, {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static dynamic getCachedData(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) {
    final cached = _cache.get(key);
    if (cached != null) {
      final timestamp = cached['timestamp'] as int;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
      if (age < maxAge) {
        return cached['data'];
      }
    }
    return null;
  }

  static Future<void> queueOfflineAction(
    String action,
    Map<String, dynamic> data,
  ) async {
    final pending =
        _offlineData.get('pending_actions', defaultValue: []) as List;
    pending.add({'action': action, 'data': data, 'timestamp': DateTime.now()});
    await _offlineData.put('pending_actions', pending);
  }

  static Future<void> processPendingActions(String tenantId) async {
    final pending =
        _offlineData.get('pending_actions', defaultValue: []) as List;
    final failed = [];

    for (final action in pending) {
      try {
        switch (action['action']) {
          case 'create_sale':
            await FirebaseService.createSale(
              tenantId: tenantId,
              items: action['data']['items'],
              totalAmount: action['data']['totalAmount'],
              taxAmount: action['data']['taxAmount'],
              paymentMethod: action['data']['paymentMethod'],
            );
            break;
          case 'update_product':
            // Implement product update
            break;
        }
      } catch (e) {
        failed.add(action);
      }
    }

    await _offlineData.put('pending_actions', failed);
  }
}

// =============================
// ERROR BOUNDARY & EXCEPTION HANDLING
// =============================
class ErrorHandler {
  static String handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'not-found':
        return 'The requested data was not found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'resource-exhausted':
        return 'Service quota exceeded. Please try again later.';
      case 'failed-precondition':
        return 'Operation failed due to precondition not met.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please check your connection.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      default:
        return 'An unexpected error occurred: ${e.message}';
    }
  }

  static String handleNetworkError() {
    return 'Network connection lost. Please check your internet connection.';
  }

  static String handleGenericError(dynamic error) {
    return 'An unexpected error occurred. Please try again.';
  }
}

class ErrorBoundary extends StatelessWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ErrorWidgetBuilder(child: child);
  }
}

class ErrorWidgetBuilder extends StatefulWidget {
  final Widget child;
  const ErrorWidgetBuilder({super.key, required this.child});

  @override
  _ErrorWidgetBuilderState createState() => _ErrorWidgetBuilderState();
}

class _ErrorWidgetBuilderState extends State<ErrorWidgetBuilder> {
  bool hasError = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 20),
              Text('Something went wrong', style: TextStyle(fontSize: 18)),
              SizedBox(height: 10),
              Text(errorMessage, textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() {
                  hasError = false;
                  errorMessage = '';
                }),
                child: Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

// =============================
// APP CONFIGURATION
// =============================
class AppConfig {
  static const String appName = 'Multi-Tenant SaaS';
  static const String version = '1.0.0';
  static const bool isDebug = true;

  // Firebase collections
  static const String tenantsCollection = 'tenants';
  static const String superAdminsCollection = 'super_admins';
  static const String ticketsCollection = 'tickets';

  // Subscription plans
  static const Map<String, double> subscriptionPlans = {
    'monthly': 29.0,
    'yearly': 299.0,
  };

  // Default settings
  static const Map<String, dynamic> defaultBranding = {
    'primaryColor': '#2196F3',
    'secondaryColor': '#FF9800',
    'currency': 'USD',
    'taxRate': 0.0,
  };
}
